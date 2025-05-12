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

    /// The application service to use
    private let applicationService: any ApplicationServiceProtocol

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
    ///   - applicationService: The application service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        interactionService: any UIInteractionServiceProtocol,
        applicationService: any ApplicationServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.interactionService = interactionService
        self.applicationService = applicationService
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

        logger.debug("Navigating menu path", metadata: [
            "menuTitle": .string(menuTitle),
            "subPath": .string(subPath.joined(separator: " > "))
        ])

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

        // First, open the menu bar item using AXPick (more semantically correct for menus)
        try await interactionService.performAction(identifier: foundMenuBarItem!.identifier, action: "AXPick", appBundleId: bundleId)

        // Brief pause to allow menu to open
        try await Task.sleep(for: .milliseconds(300))

        // After opening the top-level menu, get a fresh view of the application to see the open menu
        let updatedAppElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 5
        )

        // Find the menu bar again with the updated state
        var updatedMenuBar: UIElement? = nil
        for child in updatedAppElement.children {
            if child.role == "AXMenuBar" {
                updatedMenuBar = child
                break
            }
        }

        if updatedMenuBar == nil {
            throw MCPError.internalError("Could not find menu bar after opening menu")
        }

        // Find the menu item that should now have an open menu
        var openMenuItem: UIElement? = nil
        for menuBarItem in updatedMenuBar!.children {
            if menuBarItem.title == menuTitle {
                openMenuItem = menuBarItem
                break
            }
        }

        if openMenuItem == nil {
            throw MCPError.internalError("Could not find menu item after opening menu: \(menuTitle)")
        }

        // Now find the menu (submenu) that should be a direct child of the menu item
        var openMenu: UIElement? = nil
        for child in openMenuItem!.children {
            if child.role == "AXMenu" {
                openMenu = child
                break
            }
        }

        if openMenu == nil {
            throw MCPError.internalError("Could not find open menu for: \(menuTitle)")
        }

        // Now we have the open menu, navigate through any submenu path if needed
        var currentMenu = openMenu!

        for (index, component) in subPath.enumerated() {
            logger.debug("Processing submenu component", metadata: [
                "index": .string("\(index)"),
                "component": .string(component)
            ])

            // Find the target menu item in the current menu
            var targetMenuItem: UIElement? = nil

            // Look through menu items for a match
            for menuItem in currentMenu.children {
                // Check both title and description for matches
                if menuItem.title == component || menuItem.elementDescription == component {
                    targetMenuItem = menuItem
                    break
                }
            }

            if targetMenuItem == nil {
                // If we couldn't find the target item, cancel the menu navigation
                logger.error("Menu item not found", metadata: [
                    "component": .string(component),
                    "availableItems": .string(currentMenu.children.map { $0.title ?? "untitled" }.joined(separator: ", "))
                ])

                // Try to click on the application window to dismiss the menu
                if let window = updatedAppElement.children.first(where: { $0.role == "AXWindow" }) {
                    try await interactionService.clickElement(identifier: window.identifier, appBundleId: bundleId)
                }

                throw MCPError.internalError("Could not find menu item: \(component) in path: \(menuPath)")
            }

            // Is this the final component (the actual item we want to activate)?
            if index == subPath.count - 1 {
                // This is the target menu item, click it
                try await interactionService.clickElement(identifier: targetMenuItem!.identifier, appBundleId: bundleId)
            } else {
                // This is an intermediate menu item (has a submenu), click it to open its submenu
                try await interactionService.clickElement(identifier: targetMenuItem!.identifier, appBundleId: bundleId)

                // Brief pause to allow submenu to open
                try await Task.sleep(for: .milliseconds(300))

                // Get updated application state
                let refreshedAppElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 5
                )

                // Find the submenu by traversing the menu hierarchy again

                // First find the menu bar
                var refreshedMenuBar: UIElement? = nil
                for child in refreshedAppElement.children {
                    if child.role == "AXMenuBar" {
                        refreshedMenuBar = child
                        break
                    }
                }

                if refreshedMenuBar == nil {
                    throw MCPError.internalError("Could not find menu bar after opening submenu")
                }

                // Find our top-level menu item
                var refreshedMenuItem: UIElement? = nil
                for menuBarItem in refreshedMenuBar!.children {
                    if menuBarItem.title == menuTitle {
                        refreshedMenuItem = menuBarItem
                        break
                    }
                }

                if refreshedMenuItem == nil {
                    throw MCPError.internalError("Could not find top-level menu after opening submenu")
                }

                // Find the primary menu under the menu item
                var primaryMenu: UIElement? = nil
                for child in refreshedMenuItem!.children {
                    if child.role == "AXMenu" {
                        primaryMenu = child
                        break
                    }
                }

                if primaryMenu == nil {
                    throw MCPError.internalError("Could not find primary menu after opening submenu")
                }

                // Now we need to traverse down to our submenu
                // We need to find where we are in the path and what's been opened so far
                var currentPath = [menuTitle]  // Start with the top level menu
                var currentSubmenu = primaryMenu!

                // Traverse the path we've followed so far
                for i in 0..<index {
                    let pathComponent = subPath[i]
                    currentPath.append(pathComponent)

                    // Try to find the menu item matching this path component
                    var menuItemForPathComponent: UIElement? = nil
                    for menuItem in currentSubmenu.children {
                        if menuItem.title == pathComponent || menuItem.elementDescription == pathComponent {
                            menuItemForPathComponent = menuItem
                            break
                        }
                    }

                    if menuItemForPathComponent == nil {
                        logger.warning("Failed to find menu item when traversing path", metadata: [
                            "pathComponent": .string(pathComponent),
                            "currentPath": .string(currentPath.joined(separator: " > "))
                        ])
                        continue
                    }

                    // Find its submenu
                    var submenuForMenuItem: UIElement? = nil
                    for child in menuItemForPathComponent!.children {
                        if child.role == "AXMenu" {
                            submenuForMenuItem = child
                            break
                        }
                    }

                    if submenuForMenuItem == nil {
                        logger.warning("Failed to find submenu when traversing path", metadata: [
                            "pathComponent": .string(pathComponent),
                            "currentPath": .string(currentPath.joined(separator: " > "))
                        ])
                        continue
                    }

                    // Update our current submenu
                    currentSubmenu = submenuForMenuItem!
                }

                // Now we should have found the correct submenu that was just opened
                // Update our current menu for the next iteration
                currentMenu = currentSubmenu
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