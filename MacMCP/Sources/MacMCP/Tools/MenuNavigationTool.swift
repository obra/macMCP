// ABOUTME: This file defines a tool for working with application menus in macOS.
// ABOUTME: It provides methods to list menu items and activate menu commands.

import Foundation
import MCP
import Logging
import CoreGraphics
import ApplicationServices

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
            maxDepth: 10  // Ensure we get deep enough for menus
        )




        // Find the menu bar
        guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
            logger.error("DEBUG_MENU: CRITICAL ERROR - No AXMenuBar found in application")
            throw MCPError.internalError("Could not find menu bar in application")
        }



      
        // Find the target menu bar item by title
        guard let menuBarItem = menuBar.children.first(where: { $0.title == menuTitle }) else {
            logger.error("DEBUG_MENU: CRITICAL ERROR - No menu found with title '\(menuTitle)'", metadata: [
                "availableMenus": .string(menuBar.children.compactMap { $0.title }.joined(separator: ", "))
            ])
            throw MCPError.internalError("Could not find menu: \(menuTitle)")
        }

        // Find the menu bar element
        var menuItems: [MenuItemDescriptor] = []
        var menuLocated = false
        
        // First check if menu already exists in menuBarItem before activation
        // This is critical for apps like Calculator where menus have items before activation
        if menuBarItem.children.count > 0 {
  


            // Look for an AXMenu in the existing children
            if let existingMenu = menuBarItem.children.first(where: { $0.role == "AXMenu" }) {

              
                // Try to extract menu items even if they have zero-sized frames
                if existingMenu.children.count > 0 {
                    for (index, menuItem) in existingMenu.children.enumerated() {
                        // We'll consider all menu items as potentially valid for now
                        // as some accessibility info might be limited before menu activation
                        let isEnabled = true
                        let hasValidTitle = menuItem.title != nil && !menuItem.title!.isEmpty

                    

                        // Only include valid, enabled menu items in the result
                        if isEnabled && (hasValidTitle || menuItem.elementDescription != nil) {
          
                            if let descriptor = MenuItemDescriptor.from(
                                element: menuItem,
                                includeSubmenu: includeSubmenus
                            ) {
            
                                menuItems.append(descriptor)
                            } else {
                                logger.error("DEBUG_MENU: Failed to convert menu item to MenuItemDescriptor", metadata: [
                                    "index": .string("\(index)"),
                                    "role": .string(menuItem.role),
                                    "title": .string(menuItem.title ?? "(nil)")
                                ])
                            }
                        }
                    }

                    if !menuItems.isEmpty {
                        menuLocated = true
                        logger.info("Found valid menu items in existing tree before activation", metadata: [
                            "count": .string("\(menuItems.count)"),
                            "menuTitle": .string(menuTitle)
                        ])
                    } else {
                        logger.info("No valid enabled menu items found in existing tree")
                    }
                }
            } else {

                // Some applications might have AXMenuItems directly as children
                let menuItemChildren = menuBarItem.children.filter { $0.role == "AXMenuItem" }
                if !menuItemChildren.isEmpty {

                    for (index, menuItem) in menuItemChildren.enumerated() {
                        // We'll consider all menu items as potentially valid for now
                        let isEnabled = true
                        let hasValidTitle = menuItem.title != nil && !menuItem.title!.isEmpty

                    

                        // Only include valid, enabled menu items in the result
                        if isEnabled && (hasValidTitle || menuItem.elementDescription != nil) {
                 
                            if let descriptor = MenuItemDescriptor.from(
                                element: menuItem,
                                includeSubmenu: includeSubmenus
                            ) {
                   
                                menuItems.append(descriptor)
                            } else {
                                logger.error("DEBUG_MENU: Failed to convert direct menu item", metadata: [
                                    "index": .string("\(index)"),
                                    "role": .string(menuItem.role),
                                    "title": .string(menuItem.title ?? "(nil)")
                                ])
                            }
                        }
                    }

                    if !menuItems.isEmpty {
                        menuLocated = true
                        logger.info("Found valid direct menu items before activation", metadata: [
                            "count": .string("\(menuItems.count)"),
                            "menuTitle": .string(menuTitle)
                        ])
                    }
                }
            }
        }

        // If we didn't find items in the existing tree, activate the menu
        if !menuLocated {
            
            // For menu items, we need to first activate the menu to see its contents
            // In many applications (like Calculator), the menu items might exist in the tree
            // but with empty content until the menu is activated


            try await interactionService.performAction(
                identifier: menuBarItem.identifier,
                action: "AXPress",
                appBundleId: bundleId
            )

            // Brief pause to allow menu to open
            try await Task.sleep(for: .milliseconds(500)) // Increase wait time to 500ms

            // Get a fresh view of the application after opening the menu
            let updatedAppElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleId,
                recursive: true,
                maxDepth: 10
            )



            // Find the menu bar again
            guard let updatedMenuBar = updatedAppElement.children.first(where: { $0.role == "AXMenuBar" }) else {
                throw MCPError.internalError("Could not find menu bar after opening menu")
            }

            // Find the menu item that should now have an open menu
            guard let openMenuItem = updatedMenuBar.children.first(where: { $0.title == menuTitle }) else {
                throw MCPError.internalError("Could not find menu item after opening menu: \(menuTitle)")
            }

            // Now find the open menu (AXMenu) that should be a direct child of the menu item
            var menu = openMenuItem.children.first(where: { $0.role == "AXMenu" })

            // If still not found, check other possible menu structures
            if menu == nil {
                logger.info("Menu not found as direct child after activation, looking for alternate structure", metadata: [
                    "menuTitle": .string(menuTitle)
                ])

                // Try other potential containers or structures
                let potentialContainers = openMenuItem.children.filter {
                    ["AXGroup", "AXList", "AXScrollArea"].contains($0.role)
                }

                // Check if any of these containers have a menu
                for container in potentialContainers {
                    if let containerMenu = container.children.first(where: { $0.role == "AXMenu" }) {
                        menu = containerMenu
                        logger.info("Found menu in container", metadata: [
                            "containerRole": .string(container.role)
                        ])
                        break
                    }
                }

                // If still not found, check if menuItem itself contains menu items
                if menu == nil {
    

                    // Also check standard approach
                    if openMenuItem.children.contains(where: { $0.role == "AXMenuItem" }) {
                        menu = openMenuItem
                        logger.info("Found direct AXMenuItem children in menu bar item")
                    }
                    // Check for alternate menu item types
                    else if openMenuItem.children.contains(where: {
                        ["AXStaticText", "AXRadioButton", "AXCheckBox"].contains($0.role)
                    }) {
                        menu = openMenuItem
                        logger.info("Found menu-like items (StaticText/RadioButton/CheckBox) in menu bar item")
                    }
                    // Check if any child contains menu items even if it's not a menu
                    else {
                        for child in openMenuItem.children {
                            if child.children.contains(where: {
                                ["AXMenuItem", "AXStaticText", "AXRadioButton", "AXCheckBox"].contains($0.role)
                            }) {
                                menu = openMenuItem
                                logger.info("Found child containing menu-like items", metadata: [
                                    "childRole": .string(child.role)
                                ])
                                break
                            }
                        }
                    }
                }
            }

            // Reset menu items collection - we're starting from scratch after activation
            menuItems = []

            if let menu = menu {
                // Log menu info
                logger.info("Processing menu items", metadata: [
                    "menuRole": .string(menu.role),
                    "menuId": .string(menu.identifier),
                    "childCount": .string("\(menu.children.count)")
                ])

                // Log complete menu structure for debugging
                for (index, menuItem) in menu.children.enumerated() {
                    // Log each menu item we're processing
                    logger.debug("Processing menu item", metadata: [
                        "index": .string("\(index)"),
                        "role": .string(menuItem.role),
                        "title": .string(menuItem.title ?? "nil"),
                        "id": .string(menuItem.identifier)
                    ])

                    // Try to create a descriptor for this menu item
                    if let descriptor = MenuItemDescriptor.from(
                        element: menuItem,
                        includeSubmenu: includeSubmenus
                    ) {
                        // Log the descriptor we created
                        logger.debug("Created descriptor", metadata: [
                            "name": .string(descriptor.name),
                            "id": .string(descriptor.id)
                        ])

                        menuItems.append(descriptor)
                        menuLocated = true
                    } else {
                        logger.error("DEBUG_MENU: CRITICAL ERROR - Failed to convert post-activation menu item", metadata: [
                            "index": .string("\(index)"),
                            "role": .string(menuItem.role),
                            "title": .string(menuItem.title ?? "(nil)"),
                            "supportedRoles": .string("AXMenuItem, AXMenuBarItem, AXStaticText, AXRadioButton, AXCheckBox")
                        ])
                    }
                }
            }

            // Always dismiss the menu by clicking elsewhere to prevent it staying open
            // Log all top-level children to find something we can click on to dismiss
            var foundClickable = false

            for (_, child) in updatedAppElement.children.enumerated() {

                // Try to find any valid window or content area we can click on
                if child.role == "AXWindow" || child.role == "AXGroup" {
                    try? await interactionService.clickElement(identifier: child.identifier, appBundleId: bundleId)
                    foundClickable = true
                    break
                }
            }

            if !foundClickable {
                // If we couldn't find a window, try to find any non-menu element to click
                if let anyElement = updatedAppElement.children.first(where: {
                    $0.role != "AXMenuBar" && $0.role != "AXMenu" && $0.role != "AXMenuItem"
                }) {
                    try? await interactionService.clickElement(identifier: anyElement.identifier, appBundleId: bundleId)
                }
            }
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

        // Record actual method we used to activate the menu item
        var activationMethod = "direct" // Will be updated based on actual method used
        

        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 5  // Need deeper traversal for nested menus
        )

        // Find the menu bar element
        guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
            logger.error("Menu bar not found in application", metadata: [
                "bundleId": .string(bundleId),
                "availableRoles": .string(appElement.children.map { $0.role }.joined(separator: ", "))
            ])
            throw MCPError.internalError("Could not find menu bar in application")
        }

        // Log menu bar info
        logger.info("Found menu bar", metadata: [
            "identifier": .string(menuBar.identifier),
            "menuCount": .string("\(menuBar.children.count)"),
            "menus": .string(menuBar.children.map { $0.title ?? "unnamed" }.joined(separator: ", "))
        ])

        // Find the specified menu in the menu bar
        guard let menuBarItem = menuBar.children.first(where: { $0.title == menuTitle }) else {
            logger.error("Menu not found in menu bar", metadata: [
                "menuTitle": .string(menuTitle),
                "availableMenus": .string(menuBar.children.map { $0.title ?? "unnamed" }.joined(separator: ", "))
            ])
            throw MCPError.internalError("Could not find menu: \(menuTitle)")
        }

        // Log menu info
        logger.info("Found menu", metadata: [
            "menuTitle": .string(menuTitle),
            "identifier": .string(menuBarItem.identifier)
        ])


        // Try to find the menu without activation first for apps like Calculator
        var openMenuItem = menuBarItem
        var menu: UIElement? = nil

        // Check if we can access the menu structure without activating it
        if let existingMenu = menuBarItem.children.first(where: { $0.role == "AXMenu" }),
           !existingMenu.children.isEmpty {


            menu = existingMenu
        }

        // If we couldn't find a valid menu or it doesn't have the needed items, activate it
        if menu == nil {
    

            // Open the top-level menu using AXPress
            try await interactionService.performAction(
                identifier: menuBarItem.identifier,
                action: "AXPress",
                appBundleId: bundleId
            )

            // Brief pause to allow menu to open
            try await Task.sleep(for: .milliseconds(300))

            // Get updated application state to see the open menu
            let updatedAppElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleId,
                recursive: true,
                maxDepth: 10
            )

            // Find the menu bar again
            guard let updatedMenuBar = updatedAppElement.children.first(where: { $0.role == "AXMenuBar" }) else {
                throw MCPError.internalError("Could not find menu bar after opening menu")
            }

            // Find the menu item that should now have an open menu
            guard let updatedMenuItem = updatedMenuBar.children.first(where: { $0.title == menuTitle }) else {
                throw MCPError.internalError("Could not find menu item after opening menu: \(menuTitle)")
            }

            openMenuItem = updatedMenuItem
        }




        // Find the open menu (AXMenu) if we haven't already
        if menu == nil {
            // First, try to find AXMenu as a direct child
            menu = openMenuItem.children.first(where: { $0.role == "AXMenu" })

            // If not found, look for it in other potential containers
            if menu == nil {
                for child in openMenuItem.children {
                    // Look for containers that might hold the menu
                    if ["AXGroup", "AXScrollArea", "AXList"].contains(child.role) {
                        if let nestedMenu = child.children.first(where: { $0.role == "AXMenu" }) {
                            menu = nestedMenu
                            break
                        }
                    }
                }
            }
        }

        guard let openMenu = menu else {
            throw MCPError.internalError("Could not find open menu for: \(menuTitle)")
        }


        // Navigate through the menu hierarchy for each component in the path
        var currentMenu = openMenu

        for (index, component) in subPath.enumerated() {
  

            // Find the target menu item in the current menu - with more flexible matching
            guard let targetMenuItem = currentMenu.children.first(where: { menuItem in
                // Check against title and description
               if let title = menuItem.title {
                   if title == component {
                       return true
                   }
                   
                   // For calculator, menu items might have leading/trailing whitespace
                   let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                   if trimmedTitle == component {
                       return true
                   }
                   
                   // Try case-insensitive matching
                   if title.lowercased() == component.lowercased() {
                       return true
                   }
               }
               
               if let description = menuItem.elementDescription {
                   if description == component {
                       return true
                   }
                   
                   // For calculator, menu items might have leading/trailing whitespace
                   let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                   if trimmedDesc == component {
                       return true
                   }
               }

                // Some menu items have empty titles but valid descriptions
                if (menuItem.title == nil || menuItem.title?.isEmpty == true) && 
                   menuItem.elementDescription == component {
                    return true
                }

                // Match against partial title if needed
                if let title = menuItem.title, title.contains(component) {
                    return true
                }

                return false
            }) else {
                // Log available items to help debugging
                logger.error("Menu item not found", metadata: [
                    "targetComponent": .string(component),
                    "availableItems": .string(currentMenu.children.map { $0.title ?? $0.elementDescription ?? "unnamed" }.joined(separator: ", ")),
                    "identifierPattern": .string(currentMenu.children.map { $0.identifier }.joined(separator: ", "))
                ])

                // Try to dismiss menu by clicking on the application window
                // Get the application element first
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 2
                )

                if let window = appElement.children.first(where: { $0.role == "AXWindow" }) {
                    try await interactionService.clickElement(identifier: window.identifier, appBundleId: bundleId)
                }

                throw MCPError.internalError("Could not find menu item: \(component) in path: \(menuPath)")
            }

            // Is this the final component (the actual item we want to activate)?
            if index == subPath.count - 1 {
                // This is the target menu item, activate it directly

                // Log the menu item we found (final target)
                logger.info("Found final menu item for activation", metadata: [
                    "title": .string(targetMenuItem.title ?? "untitled"),
                    "identifier": .string(targetMenuItem.identifier),
                    "component": .string(component)
                ])

                // Check if this is a zero-sized menu item that might need special handling
                let hasZeroSize = targetMenuItem.frame.size.width == 0 && targetMenuItem.frame.size.height == 0

                // For zero-sized menu items especially in Calculator, try title-based activation
                if hasZeroSize && targetMenuItem.role == "AXMenuItem" && targetMenuItem.title != nil {
                    activationMethod = "title_based"
                    logger.info("Using title-based activation for zero-sized menu item", metadata: [
                        "title": .string(targetMenuItem.title ?? "unknown"),
                        "identifier": .string(targetMenuItem.identifier)
                    ])

                    // Add a small delay before performing action for stability
                    try await Task.sleep(for: .milliseconds(200))

                    // Perform the action using the hierarchical path-based ID
                    // This is much more reliable than position-based lookup
                    try await interactionService.performAction(
                        identifier: targetMenuItem.identifier,
                        action: "AXPress",
                        appBundleId: bundleId
                    )
                } else {
                    // For normal elements, use standard approach
                    activationMethod = "direct"
                    try await interactionService.performAction(
                        identifier: targetMenuItem.identifier,
                        action: "AXPress",
                        appBundleId: bundleId
                    )
                }

                // Add a longer delay to allow menu action to complete
                try await Task.sleep(for: .milliseconds(500))
            } else {
                // This is an intermediate menu item with a submenu, open it

                // Log the menu item we found (intermediate item)
                logger.info("Found intermediate menu item", metadata: [
                    "title": .string(targetMenuItem.title ?? "untitled"),
                    "identifier": .string(targetMenuItem.identifier),
                    "component": .string(component)
                ])

                try await interactionService.performAction(
                    identifier: targetMenuItem.identifier,
                    action: "AXPress",
                    appBundleId: bundleId
                )

                // Brief pause to allow submenu to open
                try await Task.sleep(for: .milliseconds(300))

                // Get refreshed application state
                let refreshedAppElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 10
                )

                // Find the submenu in the refreshed state
                // First, locate the menu bar again
                guard let refreshedMenuBar = refreshedAppElement.children.first(where: { $0.role == "AXMenuBar" }) else {
                    throw MCPError.internalError("Could not find menu bar after opening submenu")
                }

                // Find our current menu path by traversing the hierarchy again
                var refreshedMenu: UIElement? = nil

                // First get the top-level menu
                guard let refreshedTopMenu = refreshedMenuBar.children.first(where: { $0.title == menuTitle }) else {
                    throw MCPError.internalError("Could not find top-level menu after opening submenu")
                }

                // Get the main menu
                guard let mainMenu = refreshedTopMenu.children.first(where: { $0.role == "AXMenu" }) else {
                    throw MCPError.internalError("Could not find main menu after opening submenu")
                }

                refreshedMenu = mainMenu

                // Traverse down to the current submenu by following the path we've gone through so far
                for i in 0..<index {
                    let prevComponent = subPath[i]

                    // Find the menu item for this path component
                    guard let menuItem = refreshedMenu?.children.first(where: {
                        $0.title == prevComponent || $0.elementDescription == prevComponent
                    }) else {
                        throw MCPError.internalError("Could not find previous menu item: \(prevComponent) after refresh")
                    }

                    // Find its submenu
                    guard let submenu = menuItem.children.first(where: { $0.role == "AXMenu" }) else {
                        throw MCPError.internalError("Could not find submenu for: \(prevComponent) after refresh")
                    }

                    refreshedMenu = submenu
                }

                // Update our current menu to the refreshed submenu for the next iteration
                guard let refreshedMenu = refreshedMenu else {
                    throw MCPError.internalError("Failed to locate current submenu in refreshed state")
                }

                currentMenu = refreshedMenu
            }
        }

        // Return success message with activation method
        struct ActivationResult: Codable {
            let success: Bool
            let message: String
            let activationMethod: String
        }

        let result = ActivationResult(
            success: true,
            message: "Menu item activated: \(menuPath)",
            activationMethod: activationMethod
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
