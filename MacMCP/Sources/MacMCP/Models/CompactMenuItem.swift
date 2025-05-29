// ABOUTME: Data structure representing a menu item with hierarchical path information
// ABOUTME: Supports efficient serialization and path-based navigation

import Foundation

/// Represents a menu item with its complete path and metadata
public struct CompactMenuItem: Codable, Sendable {
  /// Full path to this menu item (e.g., "File > Save As...")
  public let path: String
  /// Display title of the menu item (e.g., "Save As...")
  public let title: String
  /// Whether the menu item is currently enabled
  public let enabled: Bool
  /// Keyboard shortcut if available (e.g., "⌘S")
  public let shortcut: String?
  /// Whether this item has a submenu
  public let hasSubmenu: Bool
  /// Child menu items if this has a submenu
  public let children: [CompactMenuItem]?
  /// Internal reference for activation - opaque element identifier
  public let elementPath: String
  public init(
    path: String,
    title: String,
    enabled: Bool,
    shortcut: String? = nil,
    hasSubmenu: Bool = false,
    children: [CompactMenuItem]? = nil,
    elementPath: String
  ) {
    self.path = path
    self.title = title
    self.enabled = enabled
    self.shortcut = shortcut
    self.hasSubmenu = hasSubmenu
    self.children = children
    self.elementPath = elementPath
  }

  /// Get all descendant paths in a flat array
  public var allDescendantPaths: [String] {
    var paths = [path]
    if let children {
      for child in children {
        paths.append(contentsOf: child.allDescendantPaths)
      }
    }
    return paths
  }

  /// Find a child menu item by path
  public func findChild(withPath targetPath: String) -> CompactMenuItem? {
    if path == targetPath { return self }
    guard let children else { return nil }
    for child in children {
      if let found = child.findChild(withPath: targetPath) { return found }
    }
    return nil
  }

  /// Get the depth level of this menu item (0 for top-level)
  public var depth: Int { path.components(separatedBy: " > ").count - 1 }
}
