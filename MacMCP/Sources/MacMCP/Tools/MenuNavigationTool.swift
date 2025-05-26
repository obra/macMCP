// ABOUTME: Enhanced MenuNavigationTool with path-based menu navigation
// ABOUTME: Provides intuitive menu discovery and activation using readable paths

import Foundation
import Logging
import MCP

/// A tool for navigating and interacting with application menus using path-based addressing
public struct MenuNavigationTool: @unchecked Sendable {
  /// The name of the tool
  public let name = ToolNames.menuNavigation

  /// Description of the tool
  public let description = """
Navigate and interact with macOS application menus for accessing commands and functionality.

IMPORTANT: Menu bar actions are typically faster and more reliable than clicking UI elements directly.
Most application functions are accessible through menus, making this the preferred interaction method.

Available actions:
- showAllMenus: Recursively discover and display all menus in a compact, hierarchical format
- showMenu: Get detailed information about a specific menu and all its items
- selectMenuItem: Click/activate a menu item using its readable path

REQUIRED workflow for activating menu items:
1. First: showAllMenus with bundleId to see available menus and their paths
2. Then: selectMenuItem with bundleId and the exact menuPath from step 1

Path format examples:
- "File > New"
- "Edit > Find > Find Next"
- "Format > Font > Show Fonts"
- "Help > Search"

Menu structure hierarchy:
- Application → Top-level menus (File, Edit, View, etc.)
- Menu → Menu items (New, Open, Save, etc.)  
- Menu items → Submenus or commands

IMPORTANT: Menu paths use " > " (space-arrow-space) as separator!
- ✅ Correct: "File > Save As..."
- ❌ Incorrect: "File/Save As..." or "File→Save As..."

Use cases:
- Access app commands not available in UI
- Automate menu-driven workflows
- Discover available application functionality
- Execute keyboard shortcut equivalents programmatically

Bundle ID required for all operations to target specific application.
"""

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The menu navigation service to use
  private let menuNavigationService: any MenuNavigationServiceProtocol

  /// The accessibility service
  private let accessibilityService: any AccessibilityServiceProtocol

  /// The change detection service
  private let changeDetectionService: UIChangeDetectionServiceProtocol

  /// The interaction wrapper for change detection
  private let interactionWrapper: InteractionWithChangeDetection

  /// The logger
  private let logger: Logger

  /// Tool handler function that uses this instance's services
  public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [self] params in
      return try await self.processRequest(params)
    }
  }

  /// Create a new menu navigation tool
  /// - Parameters:
  ///   - menuNavigationService: The menu navigation service to use
  ///   - accessibilityService: The accessibility service to use
  ///   - changeDetectionService: The change detection service to use
  ///   - logger: Optional logger to use
  public init(
    menuNavigationService: any MenuNavigationServiceProtocol,
    accessibilityService: any AccessibilityServiceProtocol,
    changeDetectionService: UIChangeDetectionServiceProtocol,
    logger: Logger? = nil
  ) {
    self.menuNavigationService = menuNavigationService
    self.accessibilityService = accessibilityService
    self.changeDetectionService = changeDetectionService
    self.interactionWrapper = InteractionWithChangeDetection(changeDetectionService: changeDetectionService)
    self.logger = logger ?? Logger(label: "mcp.tool.menu_navigation")

    // Set tool annotations
    annotations = .init(
      title: "macOS Menu Navigation",
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: true
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Now create the full input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    let baseProperties: [String: Value] = [
        "action": .object([
          "type": .string("string"),
          "description": .string("Menu operation: show all menus, show specific menu, or select menu item"),
          "enum": .array([
            .string("showAllMenus"),
            .string("showMenu"),
            .string("selectMenuItem"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle identifier (required for all actions, e.g., 'com.apple.TextEdit')"),
        ]),
        "menuPath": .object([
          "type": .string("string"),
          "description": .string("Menu path for showMenu or selectMenuItem (e.g., 'File > Save As...', 'Format > Font')"),
        ]),
        "maxDepth": .object([
          "type": .string("integer"),
          "description": .string("Maximum depth to explore for showAllMenus (1-5, default: 3)"),
          "minimum": .double(1),
          "maximum": .double(5),
          "default": .double(3),
        ]),
        "format": .object([
          "type": .string("string"),
          "description": .string("Output format for showAllMenus (compact or detailed, default: compact)"),
          "enum": .array([.string("compact"), .string("detailed")]),
          "default": .string("compact"),
        ]),
        "includeSubmenus": .object([
          "type": .string("boolean"),
          "description": .string("Include submenu exploration for showMenu (default: true)"),
          "default": .bool(true),
        ])
    ]
    
    // Merge in change detection properties 
    let properties = baseProperties.merging(ChangeDetectionHelper.addChangeDetectionSchemaProperties()) { _, new in new }
    
    return .object([
      "type": .string("object"),
      "properties": .object(properties),
      "required": .array([.string("action"), .string("bundleId")]),
      "additionalProperties": .bool(false),
        "examples": .array([
          .object([
          "action": .string("showAllMenus"),
          "bundleId": .string("com.apple.TextEdit"),
        ]),
        .object([
          "action": .string("showAllMenus"),
          "bundleId": .string("com.apple.Calculator"),
          "maxDepth": .double(2),
          "format": .string("detailed"),
        ]),
        .object([
          "action": .string("showMenu"),
          "bundleId": .string("com.apple.TextEdit"),
          "menuPath": .string("File"),
        ]),
        .object([
          "action": .string("showMenu"),
          "bundleId": .string("com.apple.TextEdit"),
          "menuPath": .string("Format > Font"),
          "includeSubmenus": .bool(true),
        ]),
        .object([
          "action": .string("selectMenuItem"),
          "bundleId": .string("com.apple.TextEdit"),
          "menuPath": .string("File > Save As..."),
        ]),
      ]),
    ])
  }

  /// Process a menu navigation request
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else {
      throw MCPError.invalidParams("Parameters are required")
    }

    // Get the action
    guard let actionValue = params["action"]?.stringValue else {
      throw MCPError.invalidParams("Action is required")
    }

    // Get the bundle ID (required for all actions)
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for all menu actions")
    }

    // Delegate to appropriate handler based on action
    switch actionValue {
    case "showAllMenus":
      let maxDepth = Int(params["maxDepth"]?.doubleValue ?? 3)
      let format = params["format"]?.stringValue ?? "compact"
      return try await handleShowAllMenus(bundleId: bundleId, maxDepth: maxDepth, format: format)

    case "showMenu":
      guard let menuPath = params["menuPath"]?.stringValue else {
        throw MCPError.invalidParams("menuPath is required for showMenu")
      }
      let includeSubmenus = params["includeSubmenus"]?.boolValue ?? true
      return try await handleShowMenu(bundleId: bundleId, menuPath: menuPath, includeSubmenus: includeSubmenus)

    case "selectMenuItem":
      guard let menuPath = params["menuPath"]?.stringValue else {
        throw MCPError.invalidParams("menuPath is required for selectMenuItem")
      }
      return try await handleSelectMenuItem(bundleId: bundleId, menuPath: menuPath, params: params)

    default:
      throw MCPError.invalidParams("Invalid action: \(actionValue)")
    }
  }

  /// Handle the showAllMenus action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - maxDepth: Maximum depth to explore
  ///   - format: Output format (compact or detailed)
  /// - Returns: The tool result
  private func handleShowAllMenus(bundleId: String, maxDepth: Int, format: String) async throws -> [Tool.Content] {
    // Validate depth parameter
    let validDepth = max(1, min(5, maxDepth))
    
    logger.info("Showing all menus", metadata: [
      "bundleId": .string(bundleId),
      "maxDepth": .string("\(validDepth)"),
      "format": .string(format)
    ])
    
    do {
      // Get complete menu hierarchy
      let hierarchy = try await menuNavigationService.getCompleteMenuHierarchy(
        bundleId: bundleId,
        maxDepth: validDepth,
        useCache: true
      )
      
      // Format response based on requested format
      if format == "detailed" {
        return try formatResponse(hierarchy)
      } else {
        // Compact format - just the paths organized by menu
        let compactResult = CompactMenuHierarchyResult(
          application: hierarchy.application,
          menus: hierarchy.menus,
          totalItems: hierarchy.totalItems,
          exploredDepth: hierarchy.exploredDepth
        )
        
        return try formatResponse(compactResult)
      }
    } catch let error as MenuNavigationError {
      let helpfulMessage = """
        Failed to explore menus for application '\(bundleId)': \(error.description)
        
        Troubleshooting steps:
        1. Verify the application '\(bundleId)' is running and accessible
        2. Check that the application has accessibility permissions
        3. Ensure the application has a menu bar (some apps don't have traditional menus)
        4. Try with a lower maxDepth value if the exploration is timing out
        """
      
      throw MCPError.internalError(helpfulMessage)
    }
  }

  /// Handle the showMenu action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - menuPath: Menu path to explore
  ///   - includeSubmenus: Whether to include submenus
  /// - Returns: The tool result
  private func handleShowMenu(bundleId: String, menuPath: String, includeSubmenus: Bool) async throws -> [Tool.Content] {
    logger.info("Showing menu details", metadata: [
      "bundleId": .string(bundleId),
      "menuPath": .string(menuPath),
      "includeSubmenus": .string("\(includeSubmenus)")
    ])
    
    do {
      // Get menu details
      let menuDetails = try await menuNavigationService.getMenuDetails(
        bundleId: bundleId,
        menuPath: menuPath,
        includeSubmenus: includeSubmenus
      )
      
      // Format as detailed menu information
      let menuResult = MenuDetailsResult(
        menuPath: menuPath,
        title: menuDetails.title,
        enabled: menuDetails.enabled,
        hasSubmenu: menuDetails.hasSubmenu,
        itemCount: menuDetails.children?.count ?? 0,
        items: menuDetails.children?.map { child in
          MenuItemResult(
            path: child.path,
            title: child.title,
            enabled: child.enabled,
            shortcut: child.shortcut,
            hasSubmenu: child.hasSubmenu
          )
        } ?? []
      )
      
      return try formatResponse(menuResult)
    } catch let error as MenuNavigationError {
      // Provide path-specific error guidance
      let suggestions = await getPathSuggestions(bundleId: bundleId, invalidPath: menuPath)
      let helpfulMessage = """
        Failed to explore menu path '\(menuPath)' in application '\(bundleId)': \(error.description)
        
        \(suggestions)
        
        Troubleshooting steps:
        1. Use showAllMenus to see all available menu paths
        2. Check path format: use " > " (space-arrow-space) as separator
        3. Ensure exact title matching (case-sensitive)
        4. Try exploring the top-level menu first (e.g., just "File" instead of "File > New")
        """
      
      throw MCPError.internalError(helpfulMessage)
    }
  }

  /// Handle the selectMenuItem action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - menuPath: Menu path to activate
  ///   - params: Additional parameters for change detection
  /// - Returns: The tool result
  private func handleSelectMenuItem(bundleId: String, menuPath: String, params: [String: Value]) async throws -> [Tool.Content] {
    logger.info("Selecting menu item", metadata: [
      "bundleId": .string(bundleId),
      "menuPath": .string(menuPath)
    ])
    
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)

    do {
      // Activate the menu item with change detection
      let result = try await interactionWrapper.performWithChangeDetection(
        detectChanges: detectChanges,
        delay: delay
      ) {
        let success = try await menuNavigationService.activateMenuItemByPath(
          bundleId: bundleId,
          menuPath: menuPath
        )
        return "Menu item activated: \(menuPath) (success: \(success))"
      }

      return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
    } catch let error as MenuNavigationError {
      // Provide path-specific error guidance
      let suggestions = await getPathSuggestions(bundleId: bundleId, invalidPath: menuPath)
      let helpfulMessage = """
        Failed to activate menu item '\(menuPath)' in application '\(bundleId)': \(error.description)
        
        \(suggestions)
        
        Troubleshooting steps:
        1. Use showAllMenus to get the exact path for the menu item you want
        2. Ensure the path format is correct: "TopMenu > MenuItem" (space-arrow-space separator)
        3. Check that the menu item is currently enabled and available
        4. Verify the application is in focus and ready to receive menu commands
        """
      
      throw MCPError.internalError(helpfulMessage)
    } catch {
      // Handle other errors with context
      let contextualMessage = """
        Unexpected error during menu activation: \(error.localizedDescription)
        
        Context:
        - Application: \(bundleId)
        - Menu path: \(menuPath)
        
        This may indicate an application state change or accessibility issue.
        Try using showAllMenus to refresh the menu structure.
        """
      
      throw MCPError.internalError(contextualMessage)
    }
  }

  /// Get path suggestions for invalid paths
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - invalidPath: The invalid path that was attempted
  /// - Returns: Helpful suggestions string
  private func getPathSuggestions(bundleId: String, invalidPath: String) async -> String {
    do {
      // Try to get cached hierarchy for suggestions
      let hierarchy = try await menuNavigationService.getCompleteMenuHierarchy(
        bundleId: bundleId,
        maxDepth: 2,
        useCache: true
      )
      
      let suggestions = MenuPathResolver.suggestSimilar(invalidPath, in: hierarchy, maxSuggestions: 3)
      if !suggestions.isEmpty {
        return "Did you mean one of these paths?\n" + suggestions.map { "  - \($0)" }.joined(separator: "\n")
      } else {
        let topLevelMenus = hierarchy.topLevelMenus
        return "Available top-level menus: \(topLevelMenus.joined(separator: ", "))"
      }
    } catch {
      return "Use showAllMenus to see available menu paths."
    }
  }

  /// Format a response as JSON
  /// - Parameter data: The data to format
  /// - Returns: The formatted tool content
  private func formatResponse(_ data: some Encodable) throws -> [Tool.Content] {
    let encoder = JSONConfiguration.encoder

    do {
      let jsonData = try encoder.encode(data)
      guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw MCPError.internalError("Failed to encode response as JSON")
      }

      return [.text(jsonString)]
    } catch {
      logger.error(
        "Error encoding response as JSON",
        metadata: [
          "error": .string("\(error.localizedDescription)")
        ])
      throw MCPError.internalError(
        "Failed to encode response as JSON: \(error.localizedDescription)")
    }
  }
}

// MARK: - Response Data Structures

/// Compact representation of menu hierarchy for tool responses
private struct CompactMenuHierarchyResult: Codable {
  let application: String
  let menus: [String: [String]]
  let totalItems: Int
  let exploredDepth: Int
}

/// Detailed menu information for tool responses
private struct MenuDetailsResult: Codable {
  let menuPath: String
  let title: String
  let enabled: Bool
  let hasSubmenu: Bool
  let itemCount: Int
  let items: [MenuItemResult]
}

/// Individual menu item information for tool responses
private struct MenuItemResult: Codable {
  let path: String
  let title: String
  let enabled: Bool
  let shortcut: String?
  let hasSubmenu: Bool
}