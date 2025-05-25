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

IMPORTANT: Use InterfaceExplorerTool first to discover available menus and menu structures for applications.

Available actions:
- getApplicationMenus: List all top-level menus for an application
- getMenuItems: Get items within a specific menu (File, Edit, View, etc.)
- activateMenuItem: Click/activate a specific menu item using element ID

Common workflows:
1. Discover menus: getApplicationMenus with bundleId
2. Explore menu content: getMenuItems with menuTitle
3. Activate commands: activateMenuItem with id from previous exploration
4. Handle submenus: Use includeSubmenus for complete menu tree exploration

Menu structure hierarchy:
- Application → Top-level menus (File, Edit, View, etc.)
- Menu → Menu items (New, Open, Save, etc.)
- Menu items → Submenus or commands

Element IDs for menu items can be obtained from InterfaceExplorerTool or getMenuItems.

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
          "description": .string("Element ID to menu item for activation (required for activateMenuItem, from getMenuItems results)"),
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
          "id": .string("menu-item-uuid-example"),
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
    
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)

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
