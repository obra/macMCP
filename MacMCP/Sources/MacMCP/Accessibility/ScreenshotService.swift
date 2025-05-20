// ABOUTME: ScreenshotService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
import Foundation
import Logging

/// Service for capturing screenshots
public actor ScreenshotService: ScreenshotServiceProtocol {
  /// The logger
  private let logger: Logger

  /// The accessibility service for element access
  private let accessibilityService: any AccessibilityServiceProtocol

  /// A cache of UI elements by ID
  private var elementCache: [String: UIElement] = [:]

  /// Create a new screenshot service
  /// - Parameters:
  ///   - accessibilityService: The accessibility service to use
  ///   - logger: Optional logger to use
  public init(
    accessibilityService: any AccessibilityServiceProtocol,
    logger: Logger? = nil
  ) {
    self.accessibilityService = accessibilityService
    self.logger = logger ?? Logger(label: "mcp.screenshot")
  }

  /// Capture a full screen screenshot
  /// - Returns: Screenshot result
  public func captureFullScreen() async throws -> ScreenshotResult {
    logger.debug("Capturing full screen screenshot")

    guard let mainScreen = NSScreen.main else {
      logger.error("Failed to get main screen")
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1001,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to get main screen"
        ],
      )
    }

    let cgImage = try CGWindowListCreateImage(
      mainScreen.frame,
      .optionOnScreenOnly,
      kCGNullWindowID,
      .bestResolution,
    ).unwrapping(throwing: "Failed to create screen image")

    return try createScreenshotResult(from: cgImage)
  }

  /// Capture a screenshot of a specific area of the screen
  /// - Parameters:
  ///   - x: X coordinate of top-left corner
  ///   - y: Y coordinate of top-left corner
  ///   - width: Width of the area
  ///   - height: Height of the area
  /// - Returns: Screenshot result
  public func captureArea(x: Int, y: Int, width: Int, height: Int) async throws -> ScreenshotResult
  {
    logger.debug(
      "Capturing area screenshot",
      metadata: [
        "x": "\(x)", "y": "\(y)", "width": "\(width)", "height": "\(height)",
      ])

    // Sanitize input values
    // Ensure width and height are positive
    let sanitizedWidth = max(1, width)
    let sanitizedHeight = max(1, height)

    // Ensure coordinates are within screen bounds
    var sanitizedX = max(0, x)
    var sanitizedY = max(0, y)

    // Get screen dimensions
    if let mainScreen = NSScreen.main {
      let screenWidth = Int(mainScreen.frame.width)
      let screenHeight = Int(mainScreen.frame.height)

      // Keep capture area within screen bounds
      if sanitizedX + sanitizedWidth > screenWidth {
        sanitizedX = max(0, screenWidth - sanitizedWidth)
      }

      if sanitizedY + sanitizedHeight > screenHeight {
        sanitizedY = max(0, screenHeight - sanitizedHeight)
      }
    }

    if x != sanitizedX || y != sanitizedY || width != sanitizedWidth || height != sanitizedHeight {
      logger.debug(
        "Adjusted capture area to fit screen",
        metadata: [
          "original": "(\(x), \(y), \(width), \(height))",
          "adjusted": "(\(sanitizedX), \(sanitizedY), \(sanitizedWidth), \(sanitizedHeight))",
        ])
    }

    let rect = CGRect(x: sanitizedX, y: sanitizedY, width: sanitizedWidth, height: sanitizedHeight)

    // For area screenshots, we need to flip the y-coordinate
    // macOS screen coordinates have (0,0) at bottom-left, but we expose (0,0) as top-left
    let flippedRect = flipRectForScreen(rect)

    let cgImage = try CGWindowListCreateImage(
      flippedRect,
      .optionOnScreenOnly,
      kCGNullWindowID,
      .bestResolution,
    ).unwrapping(throwing: "Failed to create area image")

    return try createScreenshotResult(from: cgImage)
  }

  /// Capture a screenshot of an application window
  /// - Parameter bundleIdentifier: The bundle ID of the application
  /// - Returns: Screenshot result
  public func captureWindow(bundleIdentifier: String) async throws -> ScreenshotResult {
    logger.debug(
      "Capturing window screenshot for app",
      metadata: [
        "bundleId": "\(bundleIdentifier)"
      ])

    // Find the application by bundle ID
    guard
      let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        .first
    else {
      logger.error("Application not running", metadata: ["bundleId": "\(bundleIdentifier)"])
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1002,
        userInfo: [
          NSLocalizedDescriptionKey: "Application not running: \(bundleIdentifier)"
        ],
      )
    }

    // Get windows information
    let windowList =
      CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []

    // Find windows belonging to the target application
    let appWindows = windowList.filter { windowInfo in
      guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 else { return false }
      return ownerPID == app.processIdentifier
    }

    // If there are multiple windows, use the frontmost one
    guard let windowInfo = appWindows.first else {
      logger.error(
        "No windows found for application", metadata: ["bundleId": "\(bundleIdentifier)"])
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1003,
        userInfo: [
          NSLocalizedDescriptionKey: "No windows found for application: \(bundleIdentifier)"
        ],
      )
    }

    // Get the window ID
    guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
      logger.error("Invalid window info - no window ID")
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1004,
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid window info - no window ID"
        ],
      )
    }

    // Capture the window
    let cgImage = try CGWindowListCreateImage(
      .null,  // Use the window's bounds
      .optionIncludingWindow,
      windowID,
      [.bestResolution, .boundsIgnoreFraming],
    ).unwrapping(throwing: "Failed to create window image")

    return try createScreenshotResult(from: cgImage)
  }

  /// Capture a screenshot of a specific UI element using path-based identification
  /// - Parameter elementPath: The path of the UI element using macos://ui/ notation
  /// - Returns: Screenshot result
  public func captureElementByPath(elementPath: String) async throws -> ScreenshotResult {
    logger.debug(
      "Capturing element screenshot by path",
      metadata: [
        "elementPath": "\(elementPath)"
      ])

    // First check if the path is valid
    guard ElementPath.isElementPath(elementPath) else {
      logger.error("Invalid element path format", metadata: ["elementPath": "\(elementPath)"])
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1005,
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid element path format: \(elementPath)"
        ],
      )
    }

    // Use the path to find the element
    do {
      // Parse the path
      let parsedPath = try ElementPath.parse(elementPath)

      // Resolve the path to get the AXUIElement
      let axElement = try await parsedPath.resolve(using: accessibilityService)

      // Convert the AXUIElement to a UIElement
      let element = try AccessibilityElement.convertToUIElement(axElement)

      // Make sure the element has a valid frame
      if element.frame.size.width > 0, element.frame.size.height > 0 {
        // Get the element's frame
        let frame = element.frame

        // Add some padding around the element to avoid cutting off edges
        // A 5-pixel padding on each side ensures we capture the full element
        let paddedX = max(0, Int(frame.origin.x) - 5)
        let paddedY = max(0, Int(frame.origin.y) - 5)
        let paddedWidth = Int(frame.size.width) + 10
        let paddedHeight = Int(frame.size.height) + 10

        logger.debug(
          "Found element with path resolution",
          metadata: [
            "elementPath": "\(elementPath)",
            "frame":
              "(\(frame.origin.x), \(frame.origin.y), \(frame.size.width), \(frame.size.height))",
            "paddedFrame": "(\(paddedX), \(paddedY), \(paddedWidth), \(paddedHeight))",
          ])

        return try await captureArea(
          x: paddedX,
          y: paddedY,
          width: paddedWidth,
          height: paddedHeight,
        )
      } else {
        logger.error(
          "Element found but has invalid frame", metadata: ["elementPath": "\(elementPath)"])
        throw NSError(
          domain: "com.macos.mcp.screenshot",
          code: 1005,
          userInfo: [
            NSLocalizedDescriptionKey: "Element found but has invalid frame: \(elementPath)"
          ],
        )
      }
    } catch let pathError as ElementPathError {
      // If there's a path resolution error, we get specific information
      logger.error(
        "Path resolution error",
        metadata: [
          "elementPath": "\(elementPath)",
          "error": "\(pathError.description)",
        ])
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1005,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to resolve element path: \(pathError.description)"
        ],
      )
    } catch {
      // For other errors
      logger.error(
        "Error finding element by path",
        metadata: [
          "elementPath": "\(elementPath)",
          "error": "\(error.localizedDescription)",
        ])
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1005,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to find element by path: \(error.localizedDescription)"
        ],
      )
    }
  }

  /// Find an element by ID in the hierarchy
  /// - Parameters:
  ///   - root: The root element to search from
  ///   - id: The identifier to search for
  ///   - exact: Whether to require an exact match (default: true)
  /// - Returns: The matching element or nil if not found
  // Legacy element identifier methods have been removed

  /// Create a screenshot result from a CGImage
  private func createScreenshotResult(from cgImage: CGImage) throws -> ScreenshotResult {
    // Create a bitmap representation
    let width = cgImage.width
    let height = cgImage.height

    // Convert CGImage to NSImage
    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

    // Convert to PNG data
    guard let pngData = nsImage.pngData() else {
      logger.error("Failed to convert image to PNG data")
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1000,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to convert image to PNG data"
        ],
      )
    }

    // Return the result
    return ScreenshotResult(
      data: pngData,
      width: width,
      height: height,
      scale: nsImage.recommendedLayerContentsScale(0),
    )
  }

  /// Flip a rectangle for screen coordinates
  private func flipRectForScreen(_ rect: CGRect) -> CGRect {
    guard let mainScreen = NSScreen.main else {
      return rect
    }

    // macOS screen coordinates have (0,0) at bottom-left, but we expose (0,0) as top-left
    // So we need to flip the y-coordinate
    let screenHeight = mainScreen.frame.height
    let flippedY = screenHeight - (rect.origin.y + rect.height)

    return CGRect(
      x: rect.origin.x,
      y: flippedY,
      width: rect.width,
      height: rect.height,
    )
  }
}

// Helper extensions
extension CGImage? {
  /// Unwrap a CGImage or throw an error
  func unwrapping(throwing message: String) throws -> CGImage {
    guard let image = self else {
      throw NSError(
        domain: "com.macos.mcp.screenshot",
        code: 1000,
        userInfo: [NSLocalizedDescriptionKey: message],
      )
    }
    return image
  }
}

extension NSImage {
  /// Convert an NSImage to PNG data
  func pngData() -> Data? {
    guard let tiffData = tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      return nil
    }

    return bitmap.representation(using: .png, properties: [:])
  }
}
