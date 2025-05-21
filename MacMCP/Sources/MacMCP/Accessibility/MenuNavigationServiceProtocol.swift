// ABOUTME: MenuNavigationServiceProtocol.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation

/// Protocol defining menu navigation operations
public protocol MenuNavigationServiceProtocol: Actor {
  /// Get all top-level menus for an application
  /// - Parameter bundleIdentifier: The bundle identifier of the application
  /// - Returns: An array of menu descriptors representing top-level menus
  func getApplicationMenus(bundleIdentifier: String) async throws -> [MenuItemDescriptor]

  /// Get menu items for a specific menu
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier of the application
  ///   - menuTitle: The title of the menu to get items from
  ///   - includeSubmenus: Whether to include submenus in the results
  /// - Returns: An array of menu item descriptors
  func getMenuItems(
    bundleIdentifier: String,
    menuTitle: String,
    includeSubmenus: Bool,
  ) async throws -> [MenuItemDescriptor]

  /// Activate a menu item by ElementPath URI
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier of the application
  ///   - elementPath: ElementPath URI to the menu item to activate (e.g. "macos://ui/...")
  /// - Returns: Boolean indicating success
  func activateMenuItem(
    bundleIdentifier: String,
    elementPath: String,
  ) async throws -> Bool
}
