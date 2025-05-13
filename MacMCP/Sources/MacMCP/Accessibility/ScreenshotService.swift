// ABOUTME: This file implements the screenshot service for capturing screen images.
// ABOUTME: It uses native macOS APIs to capture images of various UI regions.

import Foundation
import AppKit
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
                ]
            )
        }
        
        let cgImage = try CGWindowListCreateImage(
            mainScreen.frame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
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
    public func captureArea(x: Int, y: Int, width: Int, height: Int) async throws -> ScreenshotResult {
        logger.debug("Capturing area screenshot", metadata: [
            "x": "\(x)", "y": "\(y)", "width": "\(width)", "height": "\(height)"
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
            logger.debug("Adjusted capture area to fit screen", metadata: [
                "original": "(\(x), \(y), \(width), \(height))",
                "adjusted": "(\(sanitizedX), \(sanitizedY), \(sanitizedWidth), \(sanitizedHeight))"
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
            .bestResolution
        ).unwrapping(throwing: "Failed to create area image")

        return try createScreenshotResult(from: cgImage)
    }
    
    /// Capture a screenshot of an application window
    /// - Parameter bundleIdentifier: The bundle ID of the application
    /// - Returns: Screenshot result
    public func captureWindow(bundleIdentifier: String) async throws -> ScreenshotResult {
        logger.debug("Capturing window screenshot for app", metadata: [
            "bundleId": "\(bundleIdentifier)"
        ])
        
        // Find the application by bundle ID
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            logger.error("Application not running", metadata: ["bundleId": "\(bundleIdentifier)"])
            throw NSError(
                domain: "com.macos.mcp.screenshot",
                code: 1002,
                userInfo: [
                    NSLocalizedDescriptionKey: "Application not running: \(bundleIdentifier)"
                ]
            )
        }
        
        // Get windows information
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        
        // Find windows belonging to the target application
        let appWindows = windowList.filter { windowInfo in
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return ownerPID == app.processIdentifier
        }
        
        // If there are multiple windows, use the frontmost one
        guard let windowInfo = appWindows.first else {
            logger.error("No windows found for application", metadata: ["bundleId": "\(bundleIdentifier)"])
            throw NSError(
                domain: "com.macos.mcp.screenshot",
                code: 1003,
                userInfo: [
                    NSLocalizedDescriptionKey: "No windows found for application: \(bundleIdentifier)"
                ]
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
                ]
            )
        }
        
        // Capture the window
        let cgImage = try CGWindowListCreateImage(
            .null,  // Use the window's bounds
            .optionIncludingWindow,
            windowID,
            [.bestResolution, .boundsIgnoreFraming]
        ).unwrapping(throwing: "Failed to create window image")
        
        return try createScreenshotResult(from: cgImage)
    }
    
    /// Capture a screenshot of a specific UI element
    /// - Parameter elementId: The identifier of the UI element
    /// - Returns: Screenshot result
    public func captureElement(elementId: String) async throws -> ScreenshotResult {
        logger.debug("Capturing element screenshot", metadata: [
            "elementId": "\(elementId)"
        ])

        // First try to find the element in our cache
        if let element = elementCache[elementId] {
            // Only use the cached element if its frame is valid
            if element.frame.size.width > 0 && element.frame.size.height > 0 {
                logger.debug("Using cached element for screenshot", metadata: [
                    "elementId": "\(elementId)",
                    "frame": "(\(element.frame.origin.x), \(element.frame.origin.y), \(element.frame.size.width), \(element.frame.size.height))"
                ])

                return try await captureArea(
                    x: Int(element.frame.origin.x),
                    y: Int(element.frame.origin.y),
                    width: Int(element.frame.size.width),
                    height: Int(element.frame.size.height)
                )
            } else {
                // Remove invalid cached element
                elementCache.removeValue(forKey: elementId)
            }
        }

        // For most reliable element discovery, use AccessibilityService.findElement
        // Which handles menu elements, system elements, and more complex cases
        do {
            logger.debug("Using AccessibilityService.findElement method", metadata: [
                "elementId": "\(elementId)"
            ])

            let element = try await accessibilityService.findElement(identifier: elementId, in: nil)

            if let element = element, element.frame.size.width > 0 && element.frame.size.height > 0 {
                // Cache the element for future use
                elementCache[elementId] = element

                // Get the element's frame
                let frame = element.frame

                // Add some padding around the element to avoid cutting off edges
                // A 5-pixel padding on each side ensures we capture the full element
                let paddedX = max(0, Int(frame.origin.x) - 5)
                let paddedY = max(0, Int(frame.origin.y) - 5)
                let paddedWidth = Int(frame.size.width) + 10
                let paddedHeight = Int(frame.size.height) + 10

                logger.debug("Found element with AccessibilityService.findElement", metadata: [
                    "elementId": "\(elementId)",
                    "frame": "(\(frame.origin.x), \(frame.origin.y), \(frame.size.width), \(frame.size.height))",
                    "paddedFrame": "(\(paddedX), \(paddedY), \(paddedWidth), \(paddedHeight))"
                ])

                return try await captureArea(
                    x: paddedX,
                    y: paddedY,
                    width: paddedWidth,
                    height: paddedHeight
                )
            }
        } catch {
            logger.debug("Error using AccessibilityService.findElement: \(error.localizedDescription)", metadata: [
                "elementId": "\(elementId)"
            ])
            // Continue with traditional approach
        }

        // If direct approach failed, try the traditional way by searching system hierarchy
        // Using detached Task to isolate accessibilityService access
        let systemElement = try await Task.detached {
            // Capture local copies of necessary values
            let localAccessibilityService = self.accessibilityService

            return try await localAccessibilityService.getSystemUIElement(
                recursive: true,
                maxDepth: 25  // Deeper search for better results
            )
        }.value

        logger.debug("Searching system-wide hierarchy", metadata: [
            "elementId": "\(elementId)"
        ])

        // Look for element with matching ID
        if let element = findElementById(systemElement, id: elementId) {
            // Verify that the element has a valid frame
            if element.frame.size.width > 0 && element.frame.size.height > 0 {
                // Cache the element for future use
                elementCache[elementId] = element

                // Get the element's frame
                let frame = element.frame

                // Add some padding around the element to avoid cutting off edges
                // A 5-pixel padding on each side ensures we capture the full element
                let paddedX = max(0, Int(frame.origin.x) - 5)
                let paddedY = max(0, Int(frame.origin.y) - 5)
                let paddedWidth = Int(frame.size.width) + 10
                let paddedHeight = Int(frame.size.height) + 10

                logger.debug("Found element in system hierarchy", metadata: [
                    "elementId": "\(elementId)",
                    "frame": "(\(frame.origin.x), \(frame.origin.y), \(frame.size.width), \(frame.size.height))",
                    "paddedFrame": "(\(paddedX), \(paddedY), \(paddedWidth), \(paddedHeight))"
                ])

                return try await captureArea(
                    x: paddedX,
                    y: paddedY,
                    width: paddedWidth,
                    height: paddedHeight
                )
            }
        }

        logger.error("Element not found or has invalid frame", metadata: ["elementId": "\(elementId)"])
        throw NSError(
            domain: "com.macos.mcp.screenshot",
            code: 1005,
            userInfo: [
                NSLocalizedDescriptionKey: "Element not found or has invalid frame: \(elementId)"
            ]
        )
    }
    
    /// Find an element by ID in the hierarchy
    /// - Parameters:
    ///   - root: The root element to search from
    ///   - id: The identifier to search for
    ///   - exact: Whether to require an exact match (default: true)
    /// - Returns: The matching element or nil if not found
    private func findElementById(_ root: UIElement, id: String, exact: Bool = true) -> UIElement? {
        // For exact matching, just check equality
        if exact {
            if root.identifier == id {
                return root
            }
        } else {
            // For partial matching, check different patterns

            // Check if the element's ID matches or contains the target ID
            if root.identifier == id || root.identifier.contains(id) {
                return root
            }

            // For structured IDs (ui:type:hash), try to match by components
            if id.hasPrefix("ui:") && root.identifier.hasPrefix("ui:") {
                let idParts = id.split(separator: ":")
                let elementIdParts = root.identifier.split(separator: ":")

                // If there are enough parts for comparison
                if idParts.count >= 2 && elementIdParts.count >= 2 {
                    // Match by the second part (typically the role or descriptive part)
                    if idParts[1] == elementIdParts[1] {
                        return root
                    }

                    // If there's a hash part, try to match that too
                    if idParts.count > 2 && elementIdParts.count > 2 && idParts[2] == elementIdParts[2] {
                        return root
                    }
                }
            }

            // For menu items, try path-based matching
            if id.hasPrefix("ui:menu:") && root.identifier.hasPrefix("ui:menu:") {
                let idPath = id.replacingOccurrences(of: "ui:menu:", with: "")
                let elementPath = root.identifier.replacingOccurrences(of: "ui:menu:", with: "")

                // Check for path inclusion (one path contains the other)
                if idPath.contains(elementPath) || elementPath.contains(idPath) {
                    return root
                }

                // If paths have multiple parts, check if any significant part matches
                let idPathComponents = idPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
                let elementPathComponents = elementPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }

                for idComponent in idPathComponents {
                    if idComponent.count > 2 { // Only check non-trivial components
                        for elementComponent in elementPathComponents {
                            if elementComponent.count > 2 &&
                               (elementComponent.contains(idComponent) || idComponent.contains(elementComponent)) {
                                return root
                            }
                        }
                    }
                }
            }
        }

        // Recursively search children
        for child in root.children {
            if let found = findElementById(child, id: id, exact: exact) {
                return found
            }
        }

        return nil
    }
    
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
                ]
            )
        }
        
        // Return the result
        return ScreenshotResult(
            data: pngData,
            width: width,
            height: height,
            scale: nsImage.recommendedLayerContentsScale(0)
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
            height: rect.height
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
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        return image
    }
}

extension NSImage {
    /// Convert an NSImage to PNG data
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmap.representation(using: .png, properties: [:])
    }
}