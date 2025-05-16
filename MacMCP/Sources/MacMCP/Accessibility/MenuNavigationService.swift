// ABOUTME: This file implements a service for navigating menus in macOS applications.
// ABOUTME: It provides a pure path-based approach to menu navigation.

import Foundation
import Logging
import ApplicationServices

/// Errors specific to menu navigation
public enum MenuNavigationError: Error, CustomStringConvertible {
    case menuBarNotFound
    case menuItemsNotFound
    case menuItemNotFound(String)
    case invalidMenuPath(String)
    case invalidMenuItemFormat
    case timeoutWaitingForMenu
    case navigationFailed(String, Error)
    
    public var description: String {
        switch self {
        case .menuBarNotFound:
            return "Could not find menu bar in application"
        case .menuItemsNotFound:
            return "Could not find menu items in menu bar"
        case .menuItemNotFound(let item):
            return "Could not find menu item: \(item)"
        case .invalidMenuPath(let path):
            return "Invalid menu path: \(path)"
        case .invalidMenuItemFormat:
            return "Menu items not in expected format"
        case .timeoutWaitingForMenu:
            return "Timeout waiting for menu to open"
        case .navigationFailed(let path, let error):
            return "Failed to navigate menu path: \(path), error: \(error)"
        }
    }
}

/// Service dedicated to menu navigation operations
public actor MenuNavigationService: MenuNavigationServiceProtocol {
    /// The accessibility service used for accessing UI elements
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// Logger for tracking menu navigation operations
    private let logger: Logger
    
    /// Initialize a new menu navigation service
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(accessibilityService: any AccessibilityServiceProtocol, logger: Logger? = nil) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.menu_navigation")
    }
    
    /// Get all top-level menus for an application
    /// - Parameter bundleIdentifier: The bundle identifier of the application
    /// - Returns: An array of menu descriptors
    public func getApplicationMenus(bundleIdentifier: String) async throws -> [MenuItemDescriptor] {
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleIdentifier,
            recursive: true,
            maxDepth: 3  // We only need shallow depth for menu bar
        )
        
        // Find the menu bar
        guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
            logger.error("Menu bar not found in application", metadata: [
                "bundleId": .string(bundleIdentifier)
            ])
            throw MenuNavigationError.menuBarNotFound
        }
        
        // Get all menu bar items and convert to descriptors
        var menus: [MenuItemDescriptor] = []
        
        for menuItem in menuBar.children {
            if let descriptor = MenuItemDescriptor.from(element: menuItem) {
                menus.append(descriptor)
            }
        }
        
        return menus
    }
    
    /// Get menu items for a specific menu
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier of the application
    ///   - menuTitle: The title of the menu to get items from
    ///   - includeSubmenus: Whether to include submenus in the results
    /// - Returns: An array of menu item descriptors
    public func getMenuItems(
        bundleIdentifier: String,
        menuTitle: String,
        includeSubmenus: Bool
    ) async throws -> [MenuItemDescriptor] {
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleIdentifier,
            recursive: true,
            maxDepth: 10  // Need deeper traversal for menu items
        )
        
        // Find the menu bar
        guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
            logger.error("Menu bar not found in application", metadata: [
                "bundleId": .string(bundleIdentifier)
            ])
            throw MenuNavigationError.menuBarNotFound
        }
        
        // Find the target menu in the menu bar
        guard let menuBarItem = menuBar.children.first(where: { $0.title == menuTitle }) else {
            logger.error("Menu not found in menu bar", metadata: [
                "menuTitle": .string(menuTitle),
                "availableMenus": .string(menuBar.children.compactMap { $0.title }.joined(separator: ", "))
            ])
            throw MenuNavigationError.menuItemNotFound(menuTitle)
        }
        
        // Check if menu is already expanded
        var menuItems: [UIElement] = []
        var needToActivateMenu = true
        
        // First check if the menu already has visible items (some apps show this without activation)
        if let menu = menuBarItem.children.first(where: { $0.role == "AXMenu" }),
           !menu.children.isEmpty {
            menuItems = menu.children
            needToActivateMenu = false
            logger.info("Found menu items without activation", metadata: [
                "menuTitle": .string(menuTitle),
                "itemCount": .string("\(menuItems.count)")
            ])
        }
        
        // If we need to activate the menu to see its items
        if needToActivateMenu {
            logger.info("Activating menu to see items", metadata: [
                "menuTitle": .string(menuTitle)
            ])
            
            // We need to activate the menu before we can see its items
            try await accessibilityService.performAction(
                action: "AXPress",
                onElementWithPath: menuBarItem.identifier
            )
            
            // Wait for the menu to open
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            // Get a fresh view of the application after opening the menu
            let updatedAppElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleIdentifier,
                recursive: true,
                maxDepth: 10
            )
            
            // Find the menu bar again
            guard let updatedMenuBar = updatedAppElement.children.first(where: { $0.role == "AXMenuBar" }) else {
                throw MenuNavigationError.menuBarNotFound
            }
            
            // Find the menu item that should now have an open menu
            guard let updatedMenuItem = updatedMenuBar.children.first(where: { $0.title == menuTitle }) else {
                throw MenuNavigationError.menuItemNotFound(menuTitle)
            }
            
            // Find the open menu
            guard let menu = updatedMenuItem.children.first(where: { $0.role == "AXMenu" }) else {
                logger.error("Menu not found after activation", metadata: [
                    "menuTitle": .string(menuTitle)
                ])
                throw MenuNavigationError.menuItemsNotFound
            }
            
            menuItems = menu.children
            
            // Always dismiss the menu by pressing Escape
            try? await accessibilityService.performAction(
                action: "AXCancel",
                onElementWithPath: updatedMenuItem.identifier
            )
        }
        
        // Convert menu items to descriptors
        var menuItemDescriptors: [MenuItemDescriptor] = []
        
        for menuItem in menuItems {
            if let descriptor = createMenuItemDescriptor(from: menuItem, includeSubmenus: includeSubmenus) {
                menuItemDescriptors.append(descriptor)
            }
        }
        
        return menuItemDescriptors
    }
    
    /// Activate a menu item by path
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier of the application
    ///   - menuPath: Path to the menu item to activate (e.g. "File > Open")
    /// - Returns: Boolean indicating success
    public func activateMenuItem(
        bundleIdentifier: String,
        menuPath: String
    ) async throws -> Bool {
        // Use the navigation method from AccessibilityService
        try await accessibilityService.navigateMenu(
            path: menuPath,
            in: bundleIdentifier
        )
        
        // If we get here, the navigation was successful
        return true
    }
    
    // MARK: - Private Helpers
    
    /// Convert a UI element to a menu item descriptor
    /// - Parameters:
    ///   - element: The UI element representing a menu item
    ///   - includeSubmenus: Whether to include submenu items
    /// - Returns: A menu item descriptor, or nil if the element is not a valid menu item
    private func createMenuItemDescriptor(from element: UIElement, includeSubmenus: Bool) -> MenuItemDescriptor? {
        return MenuItemDescriptor.from(element: element, includeSubmenu: includeSubmenus)
    }
}
