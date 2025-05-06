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
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        
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
            return try await captureArea(
                x: Int(element.frame.origin.x),
                y: Int(element.frame.origin.y),
                width: Int(element.frame.size.width),
                height: Int(element.frame.size.height)
            )
        }
        
        // If not in cache, try to find it in the system-wide hierarchy
        // Using detached Task to isolate accessibilityService access
        let systemElement = try await Task.detached {
            // Capture local copies of necessary values
            let localAccessibilityService = self.accessibilityService
            
            return try await localAccessibilityService.getSystemUIElement(
                recursive: true,
                maxDepth: 20
            )
        }.value
        
        // Look for element with matching ID
        if let element = findElementById(systemElement, id: elementId) {
            // Cache the element for future use
            elementCache[elementId] = element
            
            return try await captureArea(
                x: Int(element.frame.origin.x),
                y: Int(element.frame.origin.y),
                width: Int(element.frame.size.width),
                height: Int(element.frame.size.height)
            )
        }
        
        logger.error("Element not found", metadata: ["elementId": "\(elementId)"])
        throw NSError(
            domain: "com.macos.mcp.screenshot",
            code: 1005,
            userInfo: [
                NSLocalizedDescriptionKey: "Element not found: \(elementId)"
            ]
        )
    }
    
    /// Find an element by ID in the hierarchy
    private func findElementById(_ root: UIElement, id: String) -> UIElement? {
        if root.identifier == id {
            return root
        }
        
        for child in root.children {
            if let found = findElementById(child, id: id) {
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