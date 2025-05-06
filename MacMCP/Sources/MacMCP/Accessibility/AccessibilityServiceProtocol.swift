// ABOUTME: This file defines the protocol for accessing accessibility functionality.
// ABOUTME: This allows for easy mocking in tests and extensibility.

import Foundation

/// Protocol defining the accessibility service interface
public protocol AccessibilityServiceProtocol: Sendable {
    /// Get the system-wide UI element structure
    func getSystemUIElement(
        recursive: Bool,
        maxDepth: Int
    ) async throws -> UIElement
    
    /// Get the UI element for a specific application
    func getApplicationUIElement(
        bundleIdentifier: String,
        recursive: Bool,
        maxDepth: Int
    ) async throws -> UIElement
    
    /// Get the UI element for the currently focused application
    func getFocusedApplicationUIElement(
        recursive: Bool,
        maxDepth: Int
    ) async throws -> UIElement
    
    /// Get UI element at a specific screen position
    func getUIElementAtPosition(
        position: CGPoint,
        recursive: Bool,
        maxDepth: Int
    ) async throws -> UIElement?
    
    /// Find UI elements matching criteria
    func findUIElements(
        role: String?,
        titleContains: String?,
        scope: UIElementScope,
        recursive: Bool,
        maxDepth: Int
    ) async throws -> [UIElement]
}