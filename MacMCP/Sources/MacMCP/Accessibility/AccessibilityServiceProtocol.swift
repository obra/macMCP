// ABOUTME: This file defines the protocol for accessing accessibility functionality.
// ABOUTME: This allows for easy mocking in tests and extensibility.

import Foundation

/// Protocol defining the accessibility service interface
public protocol AccessibilityServiceProtocol: Sendable {
    /// Execute a function within the actor's isolated context
    /// This method allows calling code to utilize the actor isolation to maintain Sendability
    func run<T: Sendable>(_ operation: @Sendable () throws -> T) async rethrows -> T
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

    /// Find a UI element by path
    func findElementByPath(
        path: String
    ) async throws -> UIElement?

    /// Perform a specific accessibility action on an element
    /// - Parameters:
    ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
    ///   - elementPath: The element path
    func performAction(
        action: String,
        onElementWithPath elementPath: String
    ) async throws

    /// Move a window to a new position
    func moveWindow(
        withPath path: String,
        to point: CGPoint
    ) async throws

    /// Resize a window
    func resizeWindow(
        withPath path: String,
        to size: CGSize
    ) async throws

    /// Minimize a window
    func minimizeWindow(
        withPath path: String
    ) async throws

    /// Maximize (zoom) a window
    func maximizeWindow(
        withPath path: String
    ) async throws

    /// Close a window
    func closeWindow(
        withPath path: String
    ) async throws

    /// Activate (bring to front) a window
    func activateWindow(
        withPath path: String
    ) async throws

    /// Set the window order (front, back, above, below)
    func setWindowOrder(
        withPath path: String,
        orderMode: WindowOrderMode,
        referenceWindowPath: String?
    ) async throws

    /// Focus a window (give it keyboard focus)
    func focusWindow(
        withPath path: String
    ) async throws

    /// Navigate through menu path and activate a menu item
    /// - Parameters:
    ///   - path: The simplified menu path (e.g., "File > Open" or "View > Scientific")
    ///   - bundleId: The bundle identifier of the application
    func navigateMenu(path: String, in bundleId: String) async throws
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