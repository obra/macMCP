// ABOUTME: AccessibilityService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
import Logging
import MCP

/// Service for working with the macOS accessibility API
public actor AccessibilityService: AccessibilityServiceProtocol {
  /// The logger for accessibility operations
  let logger: Logger

  /// The default maximum recursion depth for element hierarchy
  public static let defaultMaxDepth = 25

  /// Initialize the accessibility service
  /// - Parameter logger: Optional logger to use (creates one if not provided)
  public init(logger: Logger? = nil) { self.logger = logger ?? Logger(label: "mcp.accessibility") }

  /// Execute a function within the actor's isolated context
  /// This method allows calling code to utilize the actor isolation to maintain Sendability
  public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
    try await operation()
  }

  /// Get the system-wide UI element structure
  /// - Parameters:
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the system-wide accessibility hierarchy
  public func getSystemUIElement(
    recursive: Bool = true, maxDepth: Int = AccessibilityService.defaultMaxDepth,
  )
    async throws -> UIElement
  {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    let systemElement = AccessibilityElement.systemWideElement()
    return try AccessibilityElement.convertToUIElement(
      systemElement, recursive: recursive, maxDepth: maxDepth, )
  }

  /// Get the UI element for a specific application
  /// - Parameters:
  ///   - bundleId: The application's bundle identifier
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the application's accessibility hierarchy
  public func getApplicationUIElement(
    bundleId: String,
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth,
  ) async throws -> UIElement {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Find the running application
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    else {
      logger.error("Application not found", metadata: ["bundleId": .string(bundleId)])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.applicationNotFound,
        userInfo: [NSLocalizedDescriptionKey: "Application with bundle ID '\(bundleId)' not found"],
      )
    }

    // Get the application element
    let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
    return try AccessibilityElement.convertToUIElement(
      appElement, recursive: recursive, maxDepth: maxDepth, )
  }

  /// Get the UI element for the currently focused application
  /// - Parameters:
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the focused application's accessibility hierarchy
  public func getFocusedApplicationUIElement(
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth,
  ) async throws -> UIElement {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Get the system-wide element and find the focused application
    let systemElement = AccessibilityElement.systemWideElement()

    var focusedAppElement: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(
      systemElement,
      kAXFocusedApplicationAttribute as CFString,
      &focusedAppElement,
    )

    if error != AXError.success || focusedAppElement == nil {
      logger.error("Failed to get focused application", metadata: ["error": .string("\(error)")])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.elementNotFound,
        userInfo: [NSLocalizedDescriptionKey: "Failed to get focused application"],
      )
    }

    return try AccessibilityElement.convertToUIElement(
      focusedAppElement as! AXUIElement,
      recursive: recursive,
      maxDepth: maxDepth,
    )
  }

  /// Get UI element at a specific screen position
  /// - Parameters:
  ///   - position: The screen coordinates to check
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement at the specified position, or nil if none exists
  public func getUIElementAtPosition(
    position: CGPoint,
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth,
  ) async throws -> UIElement? {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Get the system-wide element
    let systemElement = AccessibilityElement.systemWideElement()

    // Get the element at the position
    var elementAtPosition: AXUIElement?
    let error = AXUIElementCopyElementAtPosition(
      systemElement,
      Float(position.x),
      Float(position.y),
      &elementAtPosition,
    )

    if error != .success || elementAtPosition == nil {
      logger.debug(
        "No element found at position",
        metadata: [
          "x": .string("\(position.x)"), "y": .string("\(position.y)"),
          "error": .string("\(error)"),
        ]
      )
      return nil
    }

    return try AccessibilityElement.convertToUIElement(
      elementAtPosition!,
      recursive: recursive,
      maxDepth: maxDepth,
    )
  }

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
  public func findUIElements(
    role: String? = nil,
    title: String? = nil,
    titleContains: String? = nil,
    value: String? = nil,
    valueContains: String? = nil,
    description: String? = nil,
    descriptionContains: String? = nil,
    textContains: String? = nil,
    anyFieldContains: String? = nil,
    isInteractable: Bool? = nil,
    isEnabled: Bool? = nil,
    inMenus: Bool? = nil,
    inMainContent: Bool? = nil,
    elementTypes: [String]? = nil,
    scope: UIElementScope = .focusedApplication,
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth,
  ) async throws -> [UIElement] {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Get the root element based on scope
    let rootElement: AXUIElement
    switch scope {
    case .systemWide: rootElement = AccessibilityElement.systemWideElement()
    case .focusedApplication:
      // Get the focused application
      let systemElement = AccessibilityElement.systemWideElement()
      var focusedAppElement: CFTypeRef?
      let error = AXUIElementCopyAttributeValue(
        systemElement,
        kAXFocusedApplicationAttribute as CFString,
        &focusedAppElement,
      )

      if error != AXError.success || focusedAppElement == nil {
        logger.error("Failed to get focused application", metadata: ["error": .string("\(error)")])
        throw NSError(
          domain: "com.macos.mcp.accessibility",
          code: MacMCPErrorCode.elementNotFound,
          userInfo: [NSLocalizedDescriptionKey: "Failed to get focused application"],
        )
      }

      rootElement = focusedAppElement as! AXUIElement
    case .application(let bundleId):
      // Find the running application
      guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
      else {
        logger.error("Application not found", metadata: ["bundleId": .string(bundleId)])
        throw NSError(
          domain: "com.macos.mcp.accessibility",
          code: MacMCPErrorCode.applicationNotFound,
          userInfo: [
            NSLocalizedDescriptionKey: "Application with bundle ID '\(bundleId)' not found"
          ],
        )
      }

      rootElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
    }

    // Convert to UIElement
    let rootUIElement = try AccessibilityElement.convertToUIElement(
      rootElement,
      recursive: recursive,
      maxDepth: maxDepth,
    )

    // Create filter criteria
    let criteria = UIElement.FilterCriteria(
      role: role,
      title: title,
      titleContains: titleContains,
      value: value,
      valueContains: valueContains,
      description: description,
      descriptionContains: descriptionContains,
      textContains: textContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes ?? ["any"],
      includeHidden: true  // AccessibilityService doesn't filter by visibility
    )

    // Use UIElement's filtering infrastructure
    return rootUIElement.findMatchingDescendants(
      criteria: criteria,
      maxDepth: maxDepth,
      limit: Int.max  // No limit for AccessibilityService
    )
  }

  /// Perform a specific accessibility action on an element
  /// - Parameters:
  ///   - action: The accessibility action to perform
  ///   - elementPath: The element path
  public func performAction(action: String, onElementWithPath elementPath: String, ) async throws {
    logger.info(
      "Performing accessibility action",
      metadata: ["action": .string(action), "elementPath": .string(elementPath)],
    )

    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Use proper path-based element identification
    do {
      // Parse the path
      let parsedPath = try ElementPath.parse(elementPath)

      // Resolve the path to get the AXUIElement
      let axElement = try await run { try await parsedPath.resolve(using: self) }

      // Perform the action
      try AccessibilityElement.performAction(axElement, action: action)
      return
    } catch {
      logger.error(
        "Failed to perform action on element with path",
        metadata: [
          "elementPath": .string(elementPath), "action": .string(action),
          "error": .string("\(error)"),
        ],
      )
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.invalidElementPath,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Failed to perform action on element with path: \(error.localizedDescription)"
        ],
      )
    }
  }

  /// Navigate through menu using ElementPath URI and activate a menu item
  /// - Parameters:
  ///   - elementPath: The ElementPath URI to the menu item (e.g., "macos://ui/...")
  ///   - bundleId: The bundle identifier of the application (used for validation)
  public func navigateMenu(elementPath: String, in bundleId: String) async throws {
    // Validate that the path is an ElementPath URI
    guard elementPath.hasPrefix("macos://ui/") else {
      logger.error("Invalid element path format", metadata: ["path": "\(elementPath)"])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.invalidActionParams,
        userInfo: [
          NSLocalizedDescriptionKey: "Invalid element path format: must start with macos://ui/"
        ]
      )
    }
    // Parse the ElementPath
    let parsedPath = try ElementPath.parse(elementPath)
    // Resolve the path to get the AXUIElement
    let axElement = try await run { try await parsedPath.resolve(using: self) }
    // Perform the press action on the element
    try AccessibilityElement.performAction(axElement, action: "AXPress")
  }

  /// Find a UI element by its path using ElementPath
  /// - Parameters:
  ///   - path: The path to the element in macos://ui/ notation
  /// - Returns: The UIElement if found, nil otherwise
  public func findElementByPath(path: String) async throws -> UIElement? {
    logger.debug("Finding element by path", metadata: ["path": "\(path)"])

    // Parse and resolve the element ID (handles both opaque IDs and raw paths)
    do {
      let parsedPath = try ElementPath.parseElementId(path)
      let axElement = try await run { try await parsedPath.resolve(using: self) }
      return try AccessibilityElement.convertToUIElement(axElement)
    } catch let pathError as ElementPathError {
      // Log specific information about path resolution errors
      logger.error(
        "Path resolution error", metadata: ["path": "\(path)", "error": "\(pathError.description)"])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.elementNotFound,
        userInfo: [
          NSLocalizedDescriptionKey: "Failed to resolve element path: \(pathError.description)"
        ],
      )
    } catch {
      logger.error(
        "Error finding element by path",
        metadata: ["path": "\(path)", "error": "\(error.localizedDescription)"]
      )
      throw error
    }
  }
}
