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

    /// Find a UI element by identifier
    func findElement(
        identifier: String,
        in bundleId: String?
    ) async throws -> UIElement?

    /// Perform a specific accessibility action on an element
    /// - Parameters:
    ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
    ///   - identifier: The element identifier
    ///   - bundleId: Optional bundle ID of the application containing the element
    func performAction(
        action: String,
        onElement identifier: String,
        in bundleId: String?
    ) async throws

    /// Move a window to a new position
    func moveWindow(
        withIdentifier identifier: String,
        to point: CGPoint
    ) async throws

    /// Resize a window
    func resizeWindow(
        withIdentifier identifier: String,
        to size: CGSize
    ) async throws

    /// Minimize a window
    func minimizeWindow(
        withIdentifier identifier: String
    ) async throws

    /// Maximize (zoom) a window
    func maximizeWindow(
        withIdentifier identifier: String
    ) async throws

    /// Close a window
    func closeWindow(
        withIdentifier identifier: String
    ) async throws

    /// Activate (bring to front) a window
    func activateWindow(
        withIdentifier identifier: String
    ) async throws

    /// Set the window order (front, back, above, below)
    func setWindowOrder(
        withIdentifier identifier: String,
        orderMode: WindowOrderMode,
        referenceWindowId: String?
    ) async throws

    /// Focus a window (give it keyboard focus)
    func focusWindow(
        withIdentifier identifier: String
    ) async throws
}

/// Window ordering modes
public enum WindowOrderMode: String, Codable, Sendable {
    /// Bring window to the front
    case front

    /// Send window to the back
    case back

    /// Position window above a reference window
    case above

    /// Position window below a reference window
    case below
}