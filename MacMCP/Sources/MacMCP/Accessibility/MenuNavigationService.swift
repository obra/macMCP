// ABOUTME: MenuNavigationService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import ApplicationServices
import Foundation
import Logging

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
      "Could not find menu bar in application"
    case .menuItemsNotFound:
      "Could not find menu items in menu bar"
    case .menuItemNotFound(let item):
      "Could not find menu item: \(item)"
    case .invalidMenuPath(let path):
      "Invalid menu path: \(path)"
    case .invalidMenuItemFormat:
      "Menu items not in expected format"
    case .timeoutWaitingForMenu:
      "Timeout waiting for menu to open"
    case .navigationFailed(let path, let error):
      "Failed to navigate menu path: \(path), error: \(error)"
    }
  }
}

/// Service dedicated to menu navigation operations
public actor MenuNavigationService: MenuNavigationServiceProtocol {
  /// The accessibility service used for accessing UI elements
  private let accessibilityService: any AccessibilityServiceProtocol

  /// Cache service for menu hierarchies
  private let cacheService: any MenuCacheServiceProtocol

  /// Logger for tracking menu navigation operations
  private let logger: Logger

  /// Initialize a new menu navigation service
  /// - Parameters:
  ///   - accessibilityService: The accessibility service to use
  ///   - cacheService: Optional cache service (creates default if not provided)
  ///   - logger: Optional logger to use
  public init(
    accessibilityService: any AccessibilityServiceProtocol, 
    cacheService: (any MenuCacheServiceProtocol)? = nil,
    logger: Logger? = nil
  ) {
    self.accessibilityService = accessibilityService
    self.cacheService = cacheService ?? MenuCacheService()
    self.logger = logger ?? Logger(label: "mcp.menu_navigation")
  }

  /// Navigate to a menu item using its ElementPath URI 
  /// - Parameters:
  ///   - elementPath: The ElementPath URI to the menu item
  ///   - bundleId: The bundle identifier of the application (for validation)
  public func navigateToMenuElement(elementPath: String, in bundleId: String) async throws {
    // Validate the element path format
    guard elementPath.hasPrefix("macos://ui/") else {
      logger.error("Invalid element path format", metadata: ["path": "\(elementPath)"])
      throw MenuNavigationError.invalidMenuPath(elementPath)
    }
    
    // Parse and resolve the path
    let parsedPath = try ElementPath.parse(elementPath)
    let axElement = try await accessibilityService.run {
      try await parsedPath.resolve(using: accessibilityService)
    }
    
    // Press the menu item
    try AccessibilityElement.performAction(axElement, action: "AXPress")
  }

  /// Get all top-level menus for an application
  /// - Parameter bundleId: The bundle identifier of the application
  /// - Returns: An array of menu descriptors
  public func getApplicationMenus(bundleId: String) async throws -> [MenuItemDescriptor] {
    // Get the application element
    let appElement = try await accessibilityService.getApplicationUIElement(
      bundleId: bundleId,
      recursive: true,
      maxDepth: 3,  // We only need shallow depth for menu bar
    )

    // Find the menu bar
    guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
      logger.error(
        "Menu bar not found in application",
        metadata: [
          "bundleId": .string(bundleId)
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
  ///   - bundleId: The bundle identifier of the application
  ///   - menuTitle: The title of the menu to get items from
  ///   - includeSubmenus: Whether to include submenus in the results
  /// - Returns: An array of menu item descriptors
  public func getMenuItems(
    bundleId: String,
    menuTitle: String,
    includeSubmenus: Bool,
  ) async throws -> [MenuItemDescriptor] {
    // Get the application element
    let appElement = try await accessibilityService.getApplicationUIElement(
      bundleId: bundleId,
      recursive: true,
      maxDepth: 10,  // Need deeper traversal for menu items
    )

    // Find the menu bar
    guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
      logger.error(
        "Menu bar not found in application",
        metadata: [
          "bundleId": .string(bundleId)
        ])
      throw MenuNavigationError.menuBarNotFound
    }

    // Find the target menu in the menu bar
    guard let menuBarItem = menuBar.children.first(where: { $0.title == menuTitle }) else {
      logger.error(
        "Menu not found in menu bar",
        metadata: [
          "menuTitle": .string(menuTitle),
          "availableMenus": .string(menuBar.children.compactMap(\.title).joined(separator: ", ")),
        ])
      throw MenuNavigationError.menuItemNotFound(menuTitle)
    }

    // Check if menu is already expanded
    var menuItems: [UIElement] = []
    var needToActivateMenu = true

    // First check if the menu already has visible items (some apps show this without activation)
    if let menu = menuBarItem.children.first(where: { $0.role == "AXMenu" }),
      !menu.children.isEmpty
    {
      menuItems = menu.children
      needToActivateMenu = false
      logger.info(
        "Found menu items without activation",
        metadata: [
          "menuTitle": .string(menuTitle),
          "itemCount": .string("\(menuItems.count)"),
        ])
    }

    // If we need to activate the menu to see its items
    if needToActivateMenu {
      logger.info(
        "Activating menu to see items",
        metadata: [
          "menuTitle": .string(menuTitle)
        ])

      // We need to activate the menu before we can see its items
      try await accessibilityService.performAction(
        action: "AXPress",
        onElementWithPath: menuBarItem.path,
      )

      // Wait for the menu to open
      try await Task.sleep(nanoseconds: 300_000_000)  // 300ms

      // Get a fresh view of the application after opening the menu
      let updatedAppElement = try await accessibilityService.getApplicationUIElement(
        bundleId: bundleId,
        recursive: true,
        maxDepth: 10,
      )

      // Find the menu bar again
      guard let updatedMenuBar = updatedAppElement.children.first(where: { $0.role == "AXMenuBar" })
      else {
        throw MenuNavigationError.menuBarNotFound
      }

      // Find the menu item that should now have an open menu
      guard let updatedMenuItem = updatedMenuBar.children.first(where: { $0.title == menuTitle })
      else {
        throw MenuNavigationError.menuItemNotFound(menuTitle)
      }

      // Find the open menu
      guard let menu = updatedMenuItem.children.first(where: { $0.role == "AXMenu" }) else {
        logger.error(
          "Menu not found after activation",
          metadata: [
            "menuTitle": .string(menuTitle)
          ])
        throw MenuNavigationError.menuItemsNotFound
      }

      menuItems = menu.children

      // Always dismiss the menu by pressing Escape
      try? await accessibilityService.performAction(
        action: "AXCancel",
        onElementWithPath: updatedMenuItem.path,
      )
    }

    // Convert menu items to descriptors
    var menuItemDescriptors: [MenuItemDescriptor] = []

    for menuItem in menuItems {
      if let descriptor = createMenuItemDescriptor(from: menuItem, includeSubmenus: includeSubmenus)
      {
        menuItemDescriptors.append(descriptor)
      }
    }

    return menuItemDescriptors
  }

  /// Activate a menu item by ElementPath URI
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application
  ///   - elementPath: ElementPath URI to the menu item to activate (e.g. "macos://ui/...")
  /// - Returns: Boolean indicating success
  public func activateMenuItem(
    bundleId: String,
    elementPath: String,
  ) async throws -> Bool {
    // Delegate to our internal method
    try await navigateToMenuElement(elementPath: elementPath, in: bundleId)
    
    // If we get here, the navigation was successful
    return true
  }

  // MARK: - Enhanced Path-Based Methods

  /// Get complete menu hierarchy for an application
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application
  ///   - maxDepth: Maximum depth to explore (1-5)
  ///   - useCache: Whether to use cached hierarchy if available
  /// - Returns: Complete menu hierarchy with paths
  public func getCompleteMenuHierarchy(
    bundleId: String,
    maxDepth: Int,
    useCache: Bool
  ) async throws -> MenuHierarchy {
    // Validate depth parameter
    let validDepth = max(1, min(5, maxDepth))
    
    // Check cache first if enabled
    if useCache {
      if let cached = await cacheService.getHierarchy(for: bundleId) {
        logger.info("Using cached menu hierarchy", metadata: [
          "bundleId": .string(bundleId),
          "depth": .string("\(cached.exploredDepth)")
        ])
        return cached
      }
    }
    
    logger.info("Building complete menu hierarchy", metadata: [
      "bundleId": .string(bundleId),
      "maxDepth": .string("\(validDepth)")
    ])
    
    // Build hierarchy from scratch
    let hierarchy = try await buildMenuHierarchy(
      bundleId: bundleId,
      maxDepth: validDepth
    )
    
    // Cache the result
    await cacheService.setHierarchy(hierarchy, for: bundleId)
    
    return hierarchy
  }

  /// Get menu details for a specific menu path
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application
  ///   - menuPath: Menu path (e.g., "File", "Format > Font")
  ///   - includeSubmenus: Whether to include submenu exploration
  /// - Returns: Detailed menu information
  public func getMenuDetails(
    bundleId: String,
    menuPath: String,
    includeSubmenus: Bool
  ) async throws -> CompactMenuItem {
    guard MenuPathResolver.validatePath(menuPath) else {
      throw MenuNavigationError.invalidMenuPath(menuPath)
    }
    
    let pathComponents = MenuPathResolver.parsePath(menuPath)
    
    logger.info("Getting menu details for path", metadata: [
      "bundleId": .string(bundleId),
      "menuPath": .string(menuPath),
      "components": .string("\(pathComponents.count)")
    ])
    
    // Navigate to the menu item and build its details
    return try await navigateAndBuildMenuItem(
      bundleId: bundleId,
      pathComponents: pathComponents,
      includeSubmenus: includeSubmenus
    )
  }

  /// Activate a menu item by path
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application
  ///   - menuPath: Full menu path (e.g., "File > Save As...")
  /// - Returns: Boolean indicating success
  public func activateMenuItemByPath(
    bundleId: String,
    menuPath: String
  ) async throws -> Bool {
    guard MenuPathResolver.validatePath(menuPath) else {
      throw MenuNavigationError.invalidMenuPath(menuPath)
    }
    
    logger.info("Activating menu item by path", metadata: [
      "bundleId": .string(bundleId),
      "menuPath": .string(menuPath)
    ])
    
    // Try to resolve path using cached hierarchy first
    if let cached = await cacheService.getHierarchy(for: bundleId) {
      let matches = MenuPathResolver.findMatches(menuPath, in: cached)
      if matches.count == 1 {
        // Use cached path resolution if available
        return try await activateMenuItemByResolvedPath(
          bundleId: bundleId,
          menuPath: menuPath
        )
      } else if matches.count > 1 {
        throw MenuNavigationError.invalidMenuPath("Ambiguous path: \(menuPath)")
      }
    }
    
    // Fall back to dynamic resolution
    return try await activateMenuItemByResolvedPath(
      bundleId: bundleId,
      menuPath: menuPath
    )
  }

  // MARK: - Private Helpers

  /// Convert a UI element to a menu item descriptor
  /// - Parameters:
  ///   - element: The UI element representing a menu item
  ///   - includeSubmenus: Whether to include submenu items
  /// - Returns: A menu item descriptor, or nil if the element is not a valid menu item
  private func createMenuItemDescriptor(from element: UIElement, includeSubmenus: Bool)
    -> MenuItemDescriptor?
  {
    MenuItemDescriptor.from(element: element, includeSubmenu: includeSubmenus)
  }

  /// Build complete menu hierarchy by recursively exploring menus
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - maxDepth: Maximum depth to explore
  /// - Returns: Complete menu hierarchy
  private func buildMenuHierarchy(
    bundleId: String,
    maxDepth: Int
  ) async throws -> MenuHierarchy {
    let appElement = try await accessibilityService.getApplicationUIElement(
      bundleId: bundleId,
      recursive: true,
      maxDepth: 3
    )
    
    guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
      throw MenuNavigationError.menuBarNotFound
    }
    
    var allMenus: [String: [String]] = [:]
    var totalItems = 0
    
    // Process each top-level menu
    for menuBarItem in menuBar.children {
      guard let menuTitle = menuBarItem.title, !menuTitle.isEmpty else { continue }
      
      var menuPaths: [String] = []
      
      // Explore this menu's items
      let menuItems = try await exploreMenuItems(
        bundleId: bundleId,
        menuBarItem: menuBarItem,
        parentPath: menuTitle,
        currentDepth: 1,
        maxDepth: maxDepth
      )
      
      for item in menuItems {
        menuPaths.append(contentsOf: item.allDescendantPaths)
      }
      
      if !menuPaths.isEmpty {
        allMenus[menuTitle] = menuPaths
        totalItems += menuPaths.count
      }
    }
    
    return MenuHierarchy(
      application: bundleId,
      menus: allMenus,
      totalItems: totalItems,
      exploredDepth: maxDepth
    )
  }

  /// Recursively explore menu items using non-intrusive approach (like InterfaceExplorerTool)
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - menuBarItem: Menu bar item to explore
  ///   - parentPath: Path to this menu
  ///   - currentDepth: Current exploration depth
  ///   - maxDepth: Maximum exploration depth
  /// - Returns: Array of compact menu items
  private func exploreMenuItems(
    bundleId: String,
    menuBarItem: UIElement,
    parentPath: String,
    currentDepth: Int,
    maxDepth: Int
  ) async throws -> [CompactMenuItem] {
    guard currentDepth <= maxDepth else { return [] }
    
    // Use non-intrusive approach - get full accessibility tree like InterfaceExplorerTool does
    let appElement = try await accessibilityService.getApplicationUIElement(
      bundleId: bundleId,
      recursive: true,
      maxDepth: 15  // Deep enough to capture menu structure
    )
    
    // Find the menu bar
    guard let menuBar = appElement.children.first(where: { $0.role == "AXMenuBar" }) else {
      return []
    }
    
    // Find the specific menu bar item
    guard let targetMenuItem = menuBar.children.first(where: { $0.title == menuBarItem.title }) else {
      return []
    }
    
    // Look for menu children in the accessibility tree (without physical activation)
    let menuItems = targetMenuItem.children.filter { $0.role == "AXMenu" }
      .flatMap { $0.children }
    
    var compactItems: [CompactMenuItem] = []
    
    // Process each menu item and filter out non-actionable items
    for menuItem in menuItems {
      // Filter out separators, dividers, and other non-actionable items
      guard isActionableMenuItem(menuItem) else { continue }
      
      let itemPath = MenuPathResolver.buildPath(from: [parentPath, menuItem.title ?? ""])
      
      var children: [CompactMenuItem]? = nil
      let hasSubmenu = menuItem.children.contains { $0.role == "AXMenu" }
      
      // Recursively explore submenus if we haven't reached max depth
      if hasSubmenu && currentDepth < maxDepth {
        children = try await exploreSubmenuItems(
          bundleId: bundleId,
          menuItem: menuItem,
          parentPath: itemPath,
          currentDepth: currentDepth + 1,
          maxDepth: maxDepth
        )
      }
      
      let compactItem = CompactMenuItem(
        path: itemPath,
        title: menuItem.title ?? "",
        enabled: !(menuItem.attributes["disabled"] as? Bool ?? false),
        shortcut: extractShortcut(from: menuItem),
        hasSubmenu: hasSubmenu,
        children: children,
        elementPath: menuItem.path
      )
      
      compactItems.append(compactItem)
    }
    
    return compactItems
  }

  /// Check if a menu item is actionable (not a separator or divider)
  /// - Parameter menuItem: The menu item to check
  /// - Returns: True if the item is actionable, false if it's a separator/divider
  private func isActionableMenuItem(_ menuItem: UIElement) -> Bool {
    // Filter out separators and dividers based on role
    let nonActionableRoles = [
      "AXSeparator",
      "AXDivider",
      "AXMenuSeparator",
      "AXGroup",  // Often used for visual grouping
      "AXUnknown" // Unknown elements are usually not actionable
    ]
    
    if nonActionableRoles.contains(menuItem.role) {
      return false
    }
    
    // Filter out items with empty or separator-like titles
    if let title = menuItem.title {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      // Common separator patterns
      let separatorPatterns = [
        "",           // Empty title
        "-",          // Single dash
        "—",          // Em dash
        "–",          // En dash
        "___",        // Underscores
        "...",        // Ellipsis-only items are usually placeholders
      ]
      
      if separatorPatterns.contains(trimmedTitle) || trimmedTitle.allSatisfy({ $0 == "-" || $0 == "_" || $0 == " " }) {
        return false
      }
    }
    
    // Items without titles that aren't clearly actionable are likely separators
    if (menuItem.title?.isEmpty ?? true) && menuItem.role != "AXMenuItem" {
      return false
    }
    
    return true
  }

  /// Explore submenu items recursively using non-intrusive approach
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - menuItem: Menu item with submenu
  ///   - parentPath: Path to this submenu
  ///   - currentDepth: Current exploration depth
  ///   - maxDepth: Maximum exploration depth
  /// - Returns: Array of compact menu items
  private func exploreSubmenuItems(
    bundleId: String,
    menuItem: UIElement,
    parentPath: String,
    currentDepth: Int,
    maxDepth: Int
  ) async throws -> [CompactMenuItem] {
    guard currentDepth <= maxDepth else { return [] }
    
    // Look for submenu children in the current accessibility tree
    let submenuItems = menuItem.children.filter { $0.role == "AXMenu" }
      .flatMap { $0.children }
    
    var compactItems: [CompactMenuItem] = []
    
    // Process each submenu item and filter out non-actionable items
    for subMenuItem in submenuItems {
      guard isActionableMenuItem(subMenuItem) else { continue }
      
      let itemPath = MenuPathResolver.buildPath(from: [parentPath, subMenuItem.title ?? ""])
      
      var children: [CompactMenuItem]? = nil
      let hasSubmenu = subMenuItem.children.contains { $0.role == "AXMenu" }
      
      // Recursively explore deeper submenus if we haven't reached max depth
      if hasSubmenu && currentDepth < maxDepth {
        children = try await exploreSubmenuItems(
          bundleId: bundleId,
          menuItem: subMenuItem,
          parentPath: itemPath,
          currentDepth: currentDepth + 1,
          maxDepth: maxDepth
        )
      }
      
      let compactItem = CompactMenuItem(
        path: itemPath,
        title: subMenuItem.title ?? "",
        enabled: !(subMenuItem.attributes["disabled"] as? Bool ?? false),
        shortcut: extractShortcut(from: subMenuItem),
        hasSubmenu: hasSubmenu,
        children: children,
        elementPath: subMenuItem.path
      )
      
      compactItems.append(compactItem)
    }
    
    return compactItems
  }

  /// Navigate to a menu item and build its details
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - pathComponents: Menu path components
  ///   - includeSubmenus: Whether to include submenus
  /// - Returns: Compact menu item
  private func navigateAndBuildMenuItem(
    bundleId: String,
    pathComponents: [String],
    includeSubmenus: Bool
  ) async throws -> CompactMenuItem {
    guard !pathComponents.isEmpty else {
      throw MenuNavigationError.invalidMenuPath("Empty path")
    }
    
    // For now, use the existing getMenuItems method for the top-level menu
    // and build a CompactMenuItem from the results
    let topLevelMenu = pathComponents[0]
    let menuItems = try await getMenuItems(
      bundleId: bundleId,
      menuTitle: topLevelMenu,
      includeSubmenus: includeSubmenus
    )
    
    if pathComponents.count == 1 {
      // Return the top-level menu as a CompactMenuItem
      return CompactMenuItem(
        path: topLevelMenu,
        title: topLevelMenu,
        enabled: true,
        hasSubmenu: !menuItems.isEmpty,
        children: menuItems.map { descriptor in
          CompactMenuItem(
            path: "\(topLevelMenu) > \(descriptor.title ?? descriptor.name)",
            title: descriptor.title ?? descriptor.name,
            enabled: descriptor.isEnabled,
            shortcut: descriptor.shortcut,
            hasSubmenu: descriptor.hasSubmenu,
            elementPath: descriptor.id
          )
        },
        elementPath: topLevelMenu
      )
    } else {
      // Find the specific menu item in the hierarchy
      let targetTitle = pathComponents[1]
      guard let foundItem = menuItems.first(where: { 
        $0.title == targetTitle || $0.name == targetTitle 
      }) else {
        throw MenuNavigationError.menuItemNotFound(targetTitle)
      }
      
      return CompactMenuItem(
        path: MenuPathResolver.buildPath(from: pathComponents),
        title: foundItem.title ?? foundItem.name,
        enabled: foundItem.isEnabled,
        shortcut: foundItem.shortcut,
        hasSubmenu: foundItem.hasSubmenu,
        elementPath: foundItem.id
      )
    }
  }

  /// Activate menu item by resolved path
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - menuPath: Menu path to activate
  /// - Returns: Success boolean
  private func activateMenuItemByResolvedPath(
    bundleId: String,
    menuPath: String
  ) async throws -> Bool {
    let pathComponents = MenuPathResolver.parsePath(menuPath)
    guard pathComponents.count >= 2 else {
      throw MenuNavigationError.invalidMenuPath("Path must have at least 2 components")
    }
    
    // Use existing logic to get menu items and find the target
    let topLevelMenu = pathComponents[0]
    let menuItems = try await getMenuItems(
      bundleId: bundleId,
      menuTitle: topLevelMenu,
      includeSubmenus: false
    )
    
    let targetTitle = pathComponents[1]
    guard let targetItem = menuItems.first(where: { 
      $0.title == targetTitle || $0.name == targetTitle 
    }) else {
      throw MenuNavigationError.menuItemNotFound(targetTitle)
    }
    
    // Activate using the existing method
    return try await activateMenuItem(bundleId: bundleId, elementPath: targetItem.id)
  }

  /// Extract keyboard shortcut from menu item
  /// - Parameter element: Menu item element
  /// - Returns: Shortcut string if available
  private func extractShortcut(from element: UIElement) -> String? {
    // Look for common shortcut attributes
    if let shortcut = element.attributes["shortcut"] as? String, !shortcut.isEmpty {
      return shortcut
    }
    if let cmdChar = element.attributes["cmdChar"] as? String, !cmdChar.isEmpty {
      return "⌘\(cmdChar)"
    }
    return nil
  }
}
