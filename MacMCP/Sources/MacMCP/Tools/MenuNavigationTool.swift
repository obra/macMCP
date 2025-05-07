// ABOUTME: This file defines a tool for working with application menus in macOS.
// ABOUTME: It provides methods to list menu items and activate menu commands.

import Foundation
import MCP
import Logging

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
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// The UI interaction service to use
    private let interactionService: any UIInteractionServiceProtocol
    
    /// Tool handler function that uses this instance's services
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
        return { [self] params in
            return try await self.processRequest(params)
        }
    }
    
    /// The logger
    private let logger: Logger
    
    /// Create a new menu navigation tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - interactionService: The UI interaction service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        interactionService: any UIInteractionServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.interactionService = interactionService
        self.logger = logger ?? Logger(label: "mcp.tool.menu_navigation")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Menu Navigation",
            readOnlyHint: false,
            openWorldHint: true
        )
        
        // Initialize inputSchema with an empty object first
        self.inputSchema = .object([:])
        
        // Now create the full input schema
        self.inputSchema = createInputSchema()
    }
    
    /// Create the input schema for the tool
    private func createInputSchema() -> Value {
        return .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("The action to perform: getApplicationMenus, getMenuItems, activateMenuItem"),
                    "enum": .array([
                        .string("getApplicationMenus"),
                        .string("getMenuItems"),
                        .string("activateMenuItem")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application. Required for all actions.")
                ]),
                "menuTitle": .object([
                    "type": .string("string"),
                    "description": .string("Title of the menu to get items from or navigate. Required for getMenuItems and activateMenuItem.")
                ]),
                "menuPath": .object([
                    "type": .string("string"),
                    "description": .string("Path to the menu item to activate, using '>' as a separator (e.g. 'File > Open'). Required for activateMenuItem.")
                ]),
                "includeSubmenus": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include submenus in the results when getting menu items"),
                    "default": .bool(false)
                ])
            ]),
            "required": .array([.string("action"), .string("bundleId")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Process a menu navigation request
    /// - Parameter params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
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
        
        switch actionValue {
        case "getApplicationMenus":
            return try await handleGetApplicationMenus(bundleId: bundleId)
            
        case "getMenuItems":
            guard let menuTitle = params["menuTitle"]?.stringValue else {
                throw MCPError.invalidParams("menuTitle is required for getMenuItems")
            }
            return try await handleGetMenuItems(bundleId: bundleId, menuTitle: menuTitle, includeSubmenus: includeSubmenus)
            
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
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 2  // Only need shallow depth for menu bar
        )
        
        // Find the menu bar element
        var menuBarItems: [MenuItemDescriptor] = []
        
        // Look for the menu bar in the children
        for child in appElement.children {
            if child.role == "AXMenuBar" {
                // Found the menu bar, now extract menu bar items
                for menuItem in child.children {
                    if let menuItemDescriptor = MenuItemDescriptor.from(element: menuItem) {
                        menuBarItems.append(menuItemDescriptor)
                    }
                }
                break
            }
        }
        
        // Return the menu bar items
        return try formatResponse(menuBarItems)
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
        includeSubmenus: Bool
    ) async throws -> [Tool.Content] {
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 4  // Need deeper traversal to access menu items
        )
        
        // Find the menu bar element
        var menuItems: [MenuItemDescriptor] = []
        var menuBarFound = false
        
        // Look for the menu bar in the children
        for child in appElement.children {
            if child.role == "AXMenuBar" {
                menuBarFound = true
                
                // Find the specified menu
                for menuBarItem in child.children {
                    if menuBarItem.title == menuTitle {
                        // Found the menu, now get its items
                        // Menu items are typically in a submenu
                        for subElement in menuBarItem.children {
                            if subElement.role == AXAttribute.Role.menu {
                                // Found the menu, get its items
                                for menuItem in subElement.children {
                                    if let menuItemDescriptor = MenuItemDescriptor.from(
                                        element: menuItem,
                                        includeSubmenu: includeSubmenus
                                    ) {
                                        menuItems.append(menuItemDescriptor)
                                    }
                                }
                            }
                        }
                        break
                    }
                }
                break
            }
        }
        
        if !menuBarFound {
            throw MCPError.internalError("Could not find menu bar in application")
        }
        
        if menuItems.isEmpty {
            logger.warning("No menu items found for menu: \(menuTitle)")
        }
        
        // Return the menu items
        return try formatResponse(menuItems)
    }
    
    /// Handle the activateMenuItem action
    /// - Parameters:
    ///   - bundleId: The application bundle identifier
    ///   - menuPath: Path to the menu item to activate (e.g., "File > Open")
    /// - Returns: The tool result
    private func handleActivateMenuItem(
        bundleId: String,
        menuPath: String
    ) async throws -> [Tool.Content] {
        // Parse the menu path
        let pathComponents = menuPath.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if pathComponents.isEmpty {
            throw MCPError.invalidParams("Invalid menu path: \(menuPath)")
        }
        
        // First component is the menu title, the rest is the submenu path
        let menuTitle = pathComponents[0]
        let subPath = Array(pathComponents.dropFirst())
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 5  // Need deeper traversal for nested menus
        )
        
        // Find the menu bar element
        var menuBarFound = false
        var foundMenuBarItem: UIElement? = nil
        
        // Look for the menu bar in the children
        for child in appElement.children {
            if child.role == "AXMenuBar" {
                menuBarFound = true
                
                // Find the specified menu
                for menuBarItem in child.children {
                    if menuBarItem.title == menuTitle {
                        foundMenuBarItem = menuBarItem
                        break
                    }
                }
                break
            }
        }
        
        if !menuBarFound {
            throw MCPError.internalError("Could not find menu bar in application")
        }
        
        if foundMenuBarItem == nil {
            throw MCPError.internalError("Could not find menu: \(menuTitle)")
        }
        
        // First, click the menu bar item to open the menu
        try await interactionService.clickElement(identifier: foundMenuBarItem!.identifier)
        
        // Brief pause to allow menu to open
        try await Task.sleep(for: .milliseconds(300))
        
        // If there are submenu components, navigate through them
        var currentMenuItem = foundMenuBarItem!
        
        for (index, component) in subPath.enumerated() {
            var found = false
            
            // If this is the last component, look for the menu item to click
            if index == subPath.count - 1 {
                // Search for the target menu item
                // Look for a direct menu item
                for childMenu in currentMenuItem.children {
                    if childMenu.role == AXAttribute.Role.menu {
                        for menuItem in childMenu.children {
                            if menuItem.title == component || menuItem.elementDescription == component {
                                // Found the target menu item, click it
                                try await interactionService.clickElement(identifier: menuItem.identifier)
                                found = true
                                break
                            }
                        }
                        
                        if found {
                            break
                        }
                    }
                }
            } else {
                // This is an intermediate component (submenu)
                // First find the menu
                for childMenu in currentMenuItem.children {
                    if childMenu.role == AXAttribute.Role.menu {
                        // Then find the submenu item
                        for menuItem in childMenu.children {
                            if menuItem.title == component || menuItem.elementDescription == component {
                                // Found the submenu item
                                currentMenuItem = menuItem
                                
                                // Click it to open the submenu
                                try await interactionService.clickElement(identifier: menuItem.identifier)
                                
                                // Brief pause to allow submenu to open
                                try await Task.sleep(for: .milliseconds(300))
                                
                                found = true
                                break
                            }
                        }
                        
                        if found {
                            break
                        }
                    }
                }
            }
            
            if !found {
                // If we didn't find the menu item, cancel the menu navigation by clicking elsewhere
                // Try to click on the application window to dismiss the menu
                if let window = appElement.children.first(where: { $0.role == AXAttribute.Role.window }) {
                    try await interactionService.clickElement(identifier: window.identifier)
                }
                
                throw MCPError.internalError("Could not find menu item: \(component) in path: \(menuPath)")
            }
        }
        
        // Return success message
        struct ActivationResult: Codable {
            let success: Bool
            let message: String
        }
        
        let result = ActivationResult(
            success: true,
            message: "Menu item activated: \(menuPath)"
        )
        
        return try formatResponse(result)
    }
    
    /// Format a response as JSON
    /// - Parameter data: The data to format
    /// - Returns: The formatted tool content
    private func formatResponse<T: Encodable>(_ data: T) throws -> [Tool.Content] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(data)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode response as JSON")
            }
            
            return [.text(jsonString)]
        } catch {
            logger.error("Error encoding response as JSON", metadata: [
                "error": "\(error.localizedDescription)"
            ])
            throw MCPError.internalError("Failed to encode response as JSON: \(error.localizedDescription)")
        }
    }
}