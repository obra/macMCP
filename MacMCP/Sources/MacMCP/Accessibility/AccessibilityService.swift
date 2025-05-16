// ABOUTME: This file provides the AccessibilityService for getting UI element information.
// ABOUTME: It coordinates interactions with the macOS accessibility API.

import AppKit
import Foundation
import Logging
import MCP

/// Service for working with the macOS accessibility API
public actor AccessibilityService: AccessibilityServiceProtocol {
  /// The logger for accessibility operations
  internal let logger: Logger

  /// The default maximum recursion depth for element hierarchy
  public static let defaultMaxDepth = 25

  /// Initialize the accessibility service
  /// - Parameter logger: Optional logger to use (creates one if not provided)
  public init(logger: Logger? = nil) {
    self.logger = logger ?? Logger(label: "mcp.accessibility")
  }
  
  /// Execute a function within the actor's isolated context
  /// This method allows calling code to utilize the actor isolation to maintain Sendability
  public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
    return try await operation()
  }

  /// Get the system-wide UI element structure
  /// - Parameters:
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the system-wide accessibility hierarchy
  public func getSystemUIElement(
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth
  ) async throws -> UIElement {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    let systemElement = AccessibilityElement.systemWideElement()
    return try AccessibilityElement.convertToUIElement(
      systemElement,
      recursive: recursive,
      maxDepth: maxDepth
    )
  }

  /// Get the UI element for a specific application
  /// - Parameters:
  ///   - bundleIdentifier: The application's bundle identifier
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the application's accessibility hierarchy
  public func getApplicationUIElement(
    bundleIdentifier: String,
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth
  ) async throws -> UIElement {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Find the running application
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
      logger.error("Application not found", metadata: ["bundleId": .string(bundleIdentifier)])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.applicationNotFound,
        userInfo: [NSLocalizedDescriptionKey: "Application with bundle ID '\(bundleIdentifier)' not found"]
      )
    }

    // Get the application element
    let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
    return try AccessibilityElement.convertToUIElement(
      appElement,
      recursive: recursive,
      maxDepth: maxDepth
    )
  }

  /// Get the UI element for the currently focused application
  /// - Parameters:
  ///   - recursive: Whether to recursively get children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: A UIElement representing the focused application's accessibility hierarchy
  public func getFocusedApplicationUIElement(
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth
  ) async throws -> UIElement {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Get the system-wide element and find the focused application
    let systemElement = AccessibilityElement.systemWideElement()
    
    var focusedAppElement: AXUIElement?
    let error = AXUIElementCopyAttributeValue(
      systemElement,
      kAXFocusedApplicationAttribute as CFString,
      &focusedAppElement
    )
    
    if error != .success || focusedAppElement == nil {
      logger.error("Failed to get focused application", metadata: ["error": .string("\(error)")])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.elementNotFound,
        userInfo: [NSLocalizedDescriptionKey: "Failed to get focused application"]
      )
    }
    
    return try AccessibilityElement.convertToUIElement(
      focusedAppElement!,
      recursive: recursive,
      maxDepth: maxDepth
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
    maxDepth: Int = AccessibilityService.defaultMaxDepth
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
      &elementAtPosition
    )
    
    if error != .success || elementAtPosition == nil {
      logger.debug("No element found at position", metadata: [
        "x": .string("\(position.x)"),
        "y": .string("\(position.y)"),
        "error": .string("\(error)")
      ])
      return nil
    }
    
    return try AccessibilityElement.convertToUIElement(
      elementAtPosition!,
      recursive: recursive,
      maxDepth: maxDepth
    )
  }

  /// Find UI elements matching criteria
  /// - Parameters:
  ///   - role: Optional role to match (e.g., "AXButton", "AXTextField")
  ///   - titleContains: Optional substring to match in element titles
  ///   - scope: Search scope (system-wide, focused app, or specific app)
  ///   - recursive: Whether to recursively search children
  ///   - maxDepth: Maximum depth for recursion
  /// - Returns: Array of matching UIElements
  public func findUIElements(
    role: String? = nil,
    titleContains: String? = nil,
    scope: UIElementScope = .focusedApplication,
    recursive: Bool = true,
    maxDepth: Int = AccessibilityService.defaultMaxDepth
  ) async throws -> [UIElement] {
    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Get the root element based on scope
    let rootElement: AXUIElement
    switch scope {
    case .systemWide:
      rootElement = AccessibilityElement.systemWideElement()
    case .focusedApplication:
      // Get the focused application
      let systemElement = AccessibilityElement.systemWideElement()
      var focusedAppElement: AXUIElement?
      let error = AXUIElementCopyAttributeValue(
        systemElement,
        kAXFocusedApplicationAttribute as CFString,
        &focusedAppElement
      )
      
      if error != .success || focusedAppElement == nil {
        logger.error("Failed to get focused application", metadata: ["error": .string("\(error)")])
        throw NSError(
          domain: "com.macos.mcp.accessibility",
          code: MacMCPErrorCode.elementNotFound,
          userInfo: [NSLocalizedDescriptionKey: "Failed to get focused application"]
        )
      }
      
      rootElement = focusedAppElement!
    case .application(let bundleIdentifier):
      // Find the running application
      guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
        logger.error("Application not found", metadata: ["bundleId": .string(bundleIdentifier)])
        throw NSError(
          domain: "com.macos.mcp.accessibility",
          code: MacMCPErrorCode.applicationNotFound,
          userInfo: [NSLocalizedDescriptionKey: "Application with bundle ID '\(bundleIdentifier)' not found"]
        )
      }
      
      rootElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
    }
    
    // Convert to UIElement
    let rootUIElement = try AccessibilityElement.convertToUIElement(
      rootElement,
      recursive: recursive,
      maxDepth: maxDepth
    )
    
    // Filter elements based on criteria
    var matches: [UIElement] = []
    
    // Function to recursively find matching elements
    func findMatches(in element: UIElement) {
      var isMatch = true
      
      // Check role if specified
      if let roleToMatch = role {
        if element.role != roleToMatch {
          isMatch = false
        }
      }
      
      // Check title if specified
      if let titleSubstring = titleContains {
        if let title = element.title {
          if !title.localizedCaseInsensitiveContains(titleSubstring) {
            isMatch = false
          }
        } else {
          isMatch = false
        }
      }
      
      // Add to matches if all criteria match
      if isMatch {
        matches.append(element)
      }
      
      // Recursively check children
      for child in element.children ?? [] {
        findMatches(in: child)
      }
    }
    
    // Start the search
    findMatches(in: rootUIElement)
    
    return matches
  }

  /// Perform a specific accessibility action on an element
  /// - Parameters:
  ///   - action: The accessibility action to perform
  ///   - elementPath: The element path
  public func performAction(
    action: String,
    onElementWithPath elementPath: String
  ) async throws {
    logger.info(
      "Performing accessibility action",
      metadata: [
        "action": .string(action),
        "elementPath": .string(elementPath)
      ])

    // First check permissions
    guard AccessibilityPermissions.isAccessibilityEnabled() else {
      logger.error("Accessibility permissions not granted")
      throw AccessibilityPermissions.Error.permissionDenied
    }

    // Special handling for menu items with path-based identifiers
    if elementPath.hasPrefix("ui:menu:") && action == "AXPress" {
      logger.info(
        "Detected menu item by path-based identifier, using hierarchical navigation",
        metadata: [
          "elementPath": .string(elementPath),
          "menuPath": .string(elementPath.replacingOccurrences(of: "ui:menu:", with: "")),
        ])

      // Extract bundle ID from the path if it's a UI path
      let bundleId = extractBundleId(from: elementPath)
      if let bundleId = bundleId, 
         let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
        let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)

        try await directMenuItemActivation(
          menuIdentifier: elementPath,
          menuTitle: nil,  // We'll extract from path components
          appElement: appElement
        )

        return
      }
    }

    // Use proper path-based element identification
    do {
      // Parse the path
      let parsedPath = try ElementPath.parse(elementPath)
      
      // Resolve the path to get the AXUIElement
      let axElement = try await parsedPath.resolve(using: self)
      
      // Perform the action
      try AccessibilityElement.performAction(axElement, action: action)
      return
    } catch {
      logger.error(
        "Failed to perform action on element with path",
        metadata: [
          "elementPath": .string(elementPath),
          "action": .string(action),
          "error": .string("\(error)")
        ])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.invalidElementPath,
        userInfo: [NSLocalizedDescriptionKey: "Failed to perform action on element with path: \(error.localizedDescription)"]
      )
    }
  }
  
  /// Extract bundle ID from an element path
  private func extractBundleId(from path: String) -> String? {
    // For ui:// paths, try to extract bundleIdentifier attribute
    if path.hasPrefix("ui://") {
      if let bundleIdMatch = path.range(of: "@bundleIdentifier=\"([^\"]+)\"", options: .regularExpression) {
        let bundleIdString = String(path[bundleIdMatch])
        let bundleId = bundleIdString.replacingOccurrences(of: "@bundleIdentifier=\"", with: "").replacingOccurrences(of: "\"", with: "")
        return bundleId
      }
    }
    return nil
  }
  
  /// Navigate through menu path and activate a menu item
  /// - Parameters:
  ///   - path: The simplified menu path (e.g., "File > Open" or "View > Scientific")
  ///   - bundleId: The bundle identifier of the application
  public func navigateMenu(path: String, in bundleId: String) async throws {
    // Delegate to MenuNavigationService
    try await MenuNavigationService.shared.navigateMenu(path: path, in: bundleId, using: self)
  }

  /// Find a UI element by its path using ElementPath
  /// - Parameters:
  ///   - path: The path to the element in ui:// notation
  /// - Returns: The UIElement if found, nil otherwise
  public func findElementByPath(path: String) async throws -> UIElement? {
    logger.debug("Finding element by path", metadata: ["path": "\(path)"])
    
    // First check if the path is valid
    guard ElementPath.isElementPath(path) else {
      logger.error("Invalid element path format", metadata: ["path": "\(path)"])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.invalidActionParams,
        userInfo: [NSLocalizedDescriptionKey: "Invalid element path format: \(path)"]
      )
    }
    
    // Parse and resolve the path
    do {
      let parsedPath = try ElementPath.parse(path)
      let axElement = try await parsedPath.resolve(using: self)
      return try AccessibilityElement.convertToUIElement(axElement)
    } catch let pathError as ElementPathError {
      // Log specific information about path resolution errors
      logger.error("Path resolution error", metadata: [
        "path": "\(path)",
        "error": "\(pathError.description)"
      ])
      throw NSError(
        domain: "com.macos.mcp.accessibility",
        code: MacMCPErrorCode.elementNotFound,
        userInfo: [NSLocalizedDescriptionKey: "Failed to resolve element path: \(pathError.description)"]
      )
    } catch {
      logger.error("Error finding element by path", metadata: [
        "path": "\(path)",
        "error": "\(error.localizedDescription)"
      ])
      throw error
    }
  }
}