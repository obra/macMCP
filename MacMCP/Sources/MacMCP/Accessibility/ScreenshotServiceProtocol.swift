// ABOUTME: This file defines the protocol for capturing screenshots on macOS.
// ABOUTME: It provides a common interface for screen image capture operations.

import Foundation
import AppKit

/// Result type for screenshot operations
public struct ScreenshotResult: Sendable {
    /// The screenshot data in PNG format
    public let data: Data
    
    /// The width of the screenshot in pixels
    public let width: Int
    
    /// The height of the screenshot in pixels
    public let height: Int
    
    /// The scale factor of the screenshot
    public let scale: Double
    
    /// Create a new screenshot result
    /// - Parameters:
    ///   - data: The PNG data
    ///   - width: The width in pixels
    ///   - height: The height in pixels
    ///   - scale: The scale factor
    public init(data: Data, width: Int, height: Int, scale: Double) {
        self.data = data
        self.width = width
        self.height = height
        self.scale = scale
    }
}

/// Protocol for screenshot services
public protocol ScreenshotServiceProtocol {
    /// Capture a full screen screenshot
    /// - Returns: Screenshot result
    func captureFullScreen() async throws -> ScreenshotResult
    
    /// Capture a screenshot of a specific area of the screen
    /// - Parameters:
    ///   - x: X coordinate of top-left corner
    ///   - y: Y coordinate of top-left corner
    ///   - width: Width of the area
    ///   - height: Height of the area
    /// - Returns: Screenshot result
    func captureArea(x: Int, y: Int, width: Int, height: Int) async throws -> ScreenshotResult
    
    /// Capture a screenshot of an application window
    /// - Parameter bundleIdentifier: The bundle ID of the application
    /// - Returns: Screenshot result
    func captureWindow(bundleIdentifier: String) async throws -> ScreenshotResult
    
    /// Capture a screenshot of a specific UI element using path-based identification
    /// - Parameter elementPath: The path of the UI element using ui:// notation
    /// - Returns: Screenshot result
    func captureElementByPath(elementPath: String) async throws -> ScreenshotResult
}