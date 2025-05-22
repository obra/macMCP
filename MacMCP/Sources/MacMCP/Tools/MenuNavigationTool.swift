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
  public let description = "Get and interact with menus of macOS applications"

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The menu navigation service to use
  private let menuNavigationService: any MenuNavigationServiceProtocol

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
  ///   - logger: Optional logger to use
  public init(
    menuNavigationService: any MenuNavigationServiceProtocol,
    logger: Logger? = nil
  ) {
    self.menuNavigationService = menuNavigationService
    self.logger = logger ?? Logger(label: "mcp.tool.menu_navigation")

    // Set tool annotations
    annotations = .init(
      title: "Menu Navigation",
      readOnlyHint: false,
      openWorldHint: true,
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Now create the full input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "action": .object([
          "type": .string("string"),
          "description": .string(
            "The action to perform: getApplicationMenus, getMenuItems, activateMenuItem"),
          "enum": .array([
            .string("getApplicationMenus"),
            .string("getMenuItems"),
            .string("activateMenuItem"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string(
            "The bundle identifier of the application. Required for all actions."),
        ]),
        "menuTitle": .object([
          "type": .string("string"),
          "description": .string(
            "Title of the menu to get items from or navigate. Required for getMenuItems."),
        ]),
        "menuPath": .object([
          "type": .string("string"),
          "description": .string(
            "ElementPath URI to the menu item to activate in the format 'macos://ui/...'. Required for activateMenuItem."
          ),
        ]),
        "includeSubmenus": .object([
          "type": .string("boolean"),
          "description": .string(
            "Whether to include submenus in the results when getting menu items"),
          "default": .bool(false),
        ]),
      ]),
      "required": .array([.string("action"), .string("bundleId")]),
      "additionalProperties": .bool(false),
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
      guard let menuPath = params["menuPath"]?.stringValue else {
        throw MCPError.invalidParams("menuPath is required for activateMenuItem")
      }
      return try await handleActivateMenuItem(bundleId: bundleId, menuPath: menuPath)

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

  /// Handle the activateMenuItem action
  /// - Parameters:
  ///   - bundleId: The application bundle identifier
  ///   - menuPath: ElementPath URI to the menu item to activate
  /// - Returns: The tool result
  private func handleActivateMenuItem(
    bundleId: String,
    menuPath: String,
  ) async throws -> [Tool.Content] {
    // Validate the path format
    guard menuPath.hasPrefix("macos://ui/") else {
      throw MCPError.invalidParams("menuPath must be a valid ElementPath URI starting with 'macos://ui/'")
    }
    
    // Activate the menu item
    let success = try await menuNavigationService.activateMenuItem(
      bundleId: bundleId,
      elementPath: menuPath,
    )

    // Create response
    struct ActivationResult: Codable {
      let success: Bool
      let message: String
    }

    let result = ActivationResult(
      success: success,
      message: "Menu item activated: \(menuPath)",
    )

    // Return the result
    return try formatResponse(result)
  }

  /// Format a response as JSON
  /// - Parameter data: The data to format
  /// - Returns: The formatted tool content
  private func formatResponse(_ data: some Encodable) throws -> [Tool.Content] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

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
