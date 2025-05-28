// ABOUTME: AccessibilityServiceProtocol.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation

/// Protocol defining the accessibility service interface
public protocol AccessibilityServiceProtocol: Sendable {
  /// Execute a function within the actor's isolated context
  /// This method allows calling code to utilize the actor isolation to maintain Sendability
  func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T
  /// Get the system-wide UI element structure
  func getSystemUIElement(
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> UIElement

  /// Get the UI element for a specific application
  func getApplicationUIElement(
    bundleId: String,
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> UIElement

  /// Get the UI element for the currently focused application
  func getFocusedApplicationUIElement(
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> UIElement

  /// Get UI element at a specific screen position
  func getUIElementAtPosition(
    position: CGPoint,
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> UIElement?

  /// Find UI elements matching criteria
  /// - Parameters:
  ///   - role: Optional role to match (e.g., "AXButton", "AXTextField")
  ///   - title: Optional exact title to match
  ///   - titleContains: Optional substring to match in element titles
  ///   - value: Optional exact value to match
  ///   - valueContains: Optional substring to match in element values
  ///   - description: Optional exact description to match
  ///   - descriptionContains: Optional substring to match in element descriptions
  ///   - scope: Search scope (system-wide, focused app, or specific app)
  ///   - recursive: Whether to recursively search children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: Array of matching UIElements
  func findUIElements(
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String]?,
    scope: UIElementScope,
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> [UIElement]

  /// Find a UI element by path
  func findElementByPath(
    path: String,
  ) async throws -> UIElement?

  /// Perform a specific accessibility action on an element
  /// - Parameters:
  ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
  ///   - elementPath: The element path
  func performAction(
    action: String,
    onElementWithPath elementPath: String,
  ) async throws

  /// Move a window to a new position
  func moveWindow(
    withPath path: String,
    to point: CGPoint,
  ) async throws

  /// Resize a window
  func resizeWindow(
    withPath path: String,
    to size: CGSize,
  ) async throws

  /// Minimize a window
  func minimizeWindow(
    withPath path: String,
  ) async throws

  /// Maximize (zoom) a window
  func maximizeWindow(
    withPath path: String,
  ) async throws

  /// Close a window
  func closeWindow(
    withPath path: String,
  ) async throws

  /// Activate (bring to front) a window
  func activateWindow(
    withPath path: String,
  ) async throws

  /// Set the window order (front, back, above, below)
  func setWindowOrder(
    withPath path: String,
    orderMode: WindowOrderMode,
    referenceWindowPath: String?,
  ) async throws

  /// Focus a window (give it keyboard focus)
  func focusWindow(
    withPath path: String,
  ) async throws

  /// Navigate through menu using ElementPath URI and activate a menu item
  /// - Parameters:
  ///   - elementPath: The ElementPath URI to the menu item (e.g., "macos://ui/...")
  ///   - bundleId: The bundle identifier of the application (used for validation)
  func navigateMenu(elementPath: String, in bundleId: String) async throws
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
