// ABOUTME: MenuNavigationTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// A tool for navigating and interacting with application menus
public struct MenuNavigationTool: @unchecked Sendable {
  /// The name of the tool
  public let name = ToolNames.menuNavigation

  /// Description of the tool
  public let description = """
Navigate and interact with macOS application menus for accessing commands and functionality.

CRITICAL: Menu item IDs must be obtained from prior menu exploration - you cannot guess or construct them!

Available actions:
- getApplicationMenus: List all top-level menus for an application
- getMenuItems: Get items within a specific menu (File, Edit, View, etc.)
- activateMenuItem: Click/activate a specific menu item using element ID from getMenuItems

REQUIRED workflow for activating menu items:
1. First: getApplicationMenus with bundleId to see available menus
2. Second: getMenuItems with bundleId and menuTitle to get menu item IDs
3. Finally: activateMenuItem with bundleId and the exact 'id' from step 2

Menu structure hierarchy:
- Application → Top-level menus (File, Edit, View, etc.)
- Menu → Menu items (New, Open, Save, etc.)
- Menu items → Submenus or commands

IMPORTANT: Element IDs are UUIDs generated during menu exploration, not menu titles!
- ✅ Correct: Use the 'id' field from getMenuItems results
- ❌ Incorrect: Using menu names like 'New Document', 'Save', etc.

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
          "description": .string("Menu operation: list app menus, explore menu items, or activate specific menu commands"),
          "enum": .array([
            .string("getApplicationMenus"),
            .string("getMenuItems"),
            .string("activateMenuItem"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle identifier (required for all actions, e.g., 'com.apple.TextEdit')"),
        ]),
        "menuTitle": .object([
          "type": .string("string"),
          "description": .string("Top-level menu name to explore (required for getMenuItems, e.g., 'File', 'Edit', 'View')"),
        ]),
        "id": .object([
          "type": .string("string"),
          "description": .string("Element ID (UUID) obtained from getMenuItems results (required for activateMenuItem). Must be the exact 'id' field from menu exploration, not a menu title or name."),
        ]),
        "includeSubmenus": .object([
          "type": .string("boolean"),
          "description": .string("Include nested submenus in getMenuItems results (default: false for simpler output)"),
          "default": .bool(false),
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
          "action": .string("getApplicationMenus"),
          "bundleId": .string("com.apple.TextEdit"),
        ]),
        .object([
          "action": .string("getMenuItems"),
          "bundleId": .string("com.apple.TextEdit"),
          "menuTitle": .string("File"),
        ]),
        .object([
          "action": .string("getMenuItems"),
          "bundleId": .string("com.apple.TextEdit"),
          "menuTitle": .string("Format"),
          "includeSubmenus": .bool(true),
        ]),
        .object([
          "action": .string("activateMenuItem"),
          "bundleId": .string("com.apple.TextEdit"),
          "id": .string("opaque_id_B4F2A9D8-3E5C-4A1B-9F7D-2E8A1C6B0F93"),
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

    // Common parameters
    let includeSubmenus = params["includeSubmenus"]?.boolValue ?? false

    // Delegate to appropriate handler based on action
    switch actionValue {
    case "getApplicationMenus":
      return try await handleGetApplicationMenus(bundleId: bundleId)

    case "getMenuItems":
      guard let menuTitle = params["menuTitle"]?.stringValue else {
        throw MCPError.invalidParams("menuTitle is required for getMenuItems")
      }
      return try await handleGetMenuItems(
        bundleId: bundleId,
        menuTitle: menuTitle,
        includeSubmenus: includeSubmenus,
      )

    case "activateMenuItem":
      guard let menuPath = params["id"]?.stringValue else {
        throw MCPError.invalidParams("id is required for activateMenuItem")
      }
      return try await handleActivateMenuItem(bundleId: bundleId, menuPath: menuPath, params: params)

    default:
      throw MCPError.invalidParams("Invalid action: \(actionValue)")
    }
  }

  /// Handle the getApplicationMenus action
  /// - Parameter bundleId: The application bundle identifier
  /// - Returns: The tool result
  private func handleGetApplicationMenus(bundleId: String) async throws -> [Tool.Content] {
    // Get all application menus
    let menus = try await menuNavigationService.getApplicationMenus(bundleId: bundleId)

    // Return the menus
    return try formatResponse(menus)
  }

  /// Handle the getMenuItems action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - menuTitle: The title of the menu to get items from
  ///   - includeSubmenus: Whether to include submenu items
  /// - Returns: The tool result
  private func handleGetMenuItems(
    bundleId: String,
    menuTitle: String,
    includeSubmenus: Bool,
  ) async throws -> [Tool.Content] {
    // Get menu items
    let menuItems = try await menuNavigationService.getMenuItems(
      bundleId: bundleId,
      menuTitle: menuTitle,
      includeSubmenus: includeSubmenus,
    )

    // Return the menu items
    return try formatResponse(menuItems)
  }

  /// Decode element ID - handles both opaque IDs and raw paths
  private func decodeElementID(_ elementID: String) -> String {
    // Try to decode as opaque ID first, fall back to treating as raw path
    do {
      return try OpaqueIDEncoder.decode(elementID)
    } catch {
      // Not an opaque ID or decoding failed, treat as raw path
      return elementID
    }
  }

  /// Handle the activateMenuItem action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - menuPath: Element ID URI to the menu item to activate
  ///   - params: The request parameters for change detection settings
  /// - Returns: The tool result
  private func handleActivateMenuItem(
    bundleId: String,
    menuPath: String,
    params: [String: Value]
  ) async throws -> [Tool.Content] {
    // Decode the element ID (handles both opaque IDs and raw paths)
    let decodedPath = decodeElementID(menuPath)
    
    // Validate the path format before proceeding
    guard decodedPath.hasPrefix("macos://ui/") else {
      let errorMessage = """
        Invalid menu item ID format: '\(menuPath)'
        
        The ID must be a UUID obtained from previous menu exploration using:
        1. First call getApplicationMenus with bundleId: '\(bundleId)' to see available menus
        2. Then call getMenuItems with bundleId and menuTitle to see menu items
        3. Use the 'id' field from those results for activateMenuItem
        
        Example valid ID: 'opaque_id_abc123' or 'macos://ui/application[@bundleId=...]/menubar/...'
        
        If you're looking for a menu item like 'New Document', first explore the File menu:
        - Action: getMenuItems, bundleId: '\(bundleId)', menuTitle: 'File'
        """
      
      throw MCPError.invalidParams(errorMessage)
    }
    
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)

    do {
      // Activate the menu item with change detection
      let result = try await interactionWrapper.performWithChangeDetection(
        detectChanges: detectChanges,
        delay: delay
      ) {
        let success = try await menuNavigationService.activateMenuItem(
          bundleId: bundleId,
          elementPath: decodedPath,
        )
        return "Menu item activated: \(menuPath) (success: \(success))"
      }

      return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
    } catch let error as MenuNavigationError {
      // Provide more helpful error messages for menu navigation errors
      let helpfulMessage = """
        Menu navigation failed: \(error.description)
        
        Troubleshooting steps:
        1. Verify the application '\(bundleId)' is running and accessible
        2. Use getApplicationMenus to confirm the app has menus
        3. Use getMenuItems to get valid menu item IDs for the target menu
        4. Ensure the menu item ID is from recent exploration (menu structures can change)
        
        Original ID provided: '\(menuPath)'
        Decoded path: '\(decodedPath)'
        """
      
      throw MCPError.internalError(helpfulMessage)
    } catch {
      // Handle other errors with context
      let contextualMessage = """
        Unexpected error during menu activation: \(error.localizedDescription)
        
        Context:
        - Application: \(bundleId)
        - Menu item ID: \(menuPath)
        - Decoded path: \(decodedPath)
        
        This may indicate an application state change or accessibility issue.
        Try exploring the menus again to get fresh menu item IDs.
        """
      
      throw MCPError.internalError(contextualMessage)
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
