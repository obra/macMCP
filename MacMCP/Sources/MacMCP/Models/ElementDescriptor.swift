// ABOUTME: ElementDescriptor.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// A standardized descriptor for a UI element
public struct ElementDescriptor: Codable, Sendable, Identifiable {
  /// Unique identifier for the element (guaranteed to be stable and unique)
  public let id: String

  /// Human-readable name of the element (derived from title or description)
  public let name: String

  /// The accessibility role of the element
  public let role: String

  /// The title or label of the element (if any)
  public let title: String?

  /// The current value of the element (if applicable)
  public let value: String?

  /// Human-readable description of the element
  public let description: String?

  /// Element position and size
  public let frame: ElementFrame

  /// Whether the element is visible
  public let isVisible: Bool

  /// Whether the element is enabled
  public let isEnabled: Bool

  /// Whether the element is currently focused
  public let isFocused: Bool

  /// Whether the element is selected
  public let isSelected: Bool

  /// Available actions that can be performed on this element
  public let actions: [String]

  /// Additional attributes of the element
  public let attributes: [String: String]

  /// Whether this element has children
  public let hasChildren: Bool

  /// The count of children, if available
  public let childCount: Int?

  /// Children elements, if requested and available
  public let children: [ElementDescriptor]?

  /// Path-based identifier for the element following the ElementPath syntax
  public let path: String?

  /// Create a new element descriptor
  /// - Parameters:
  ///   - id: Unique identifier
  ///   - name: Human-readable name (optional, defaults to element title or role)
  ///   - role: Accessibility role
  ///   - title: Title or label (optional)
  ///   - value: Current value (optional)
  ///   - description: Human-readable description (optional)
  ///   - frame: Element position and size
  ///   - isVisible: Whether element is visible
  ///   - isEnabled: Whether element is enabled
  ///   - isFocused: Whether element is focused
  ///   - isSelected: Whether element is selected
  ///   - actions: Available actions
  ///   - attributes: Additional attributes
  ///   - hasChildren: Whether element has children
  ///   - childCount: Number of children (optional)
  ///   - children: Child elements (optional)
  ///   - path: Path-based identifier (optional)
  public init(
    id: String,
    name: String? = nil,
    role: String,
    title: String? = nil,
    value: String? = nil,
    description: String? = nil,
    frame: ElementFrame,
    isVisible: Bool = true,
    isEnabled: Bool = true,
    isFocused: Bool = false,
    isSelected: Bool = false,
    actions: [String] = [],
    attributes: [String: String] = [:],
    hasChildren: Bool = false,
    childCount: Int? = nil,
    children: [ElementDescriptor]? = nil,
    path: String? = nil
  ) {
    self.id = id
    // Generate a human-readable name if not provided
    if let providedName = name {
      self.name = providedName
    } else if let title, !title.isEmpty {
      self.name = title
    } else if let desc = description, !desc.isEmpty {
      self.name = desc
    } else if let val = value, !val.isEmpty {
      self.name = "\(role) with value \(val)"
    } else {
      self.name = role
    }

    self.role = role
    self.title = title
    self.value = value
    self.description = description
    self.frame = frame
    self.isVisible = isVisible
    self.isEnabled = isEnabled
    self.isFocused = isFocused
    self.isSelected = isSelected
    self.actions = actions
    self.attributes = attributes
    self.hasChildren = hasChildren
    self.childCount = childCount
    self.children = children
    self.path = path
  }

  /// Convert a UIElement to an ElementDescriptor
  /// - Parameters:
  ///   - element: The UIElement to convert
  ///   - includeChildren: Whether to include children (default false)
  ///   - includePath: Whether to include the path (default true)
  /// - Returns: An ElementDescriptor representing the element
  public static func from(
    element: UIElement,
    includeChildren: Bool = false,
    includePath: Bool = true,
  ) -> ElementDescriptor {
    // Extract attributes that we want to expose as first-class properties
    let isVisible = (element.attributes["visible"] as? Bool) ?? true
    let isEnabled = (element.attributes["enabled"] as? Bool) ?? true
    let isFocused = (element.attributes["focused"] as? Bool) ?? false
    let isSelected = (element.attributes["selected"] as? Bool) ?? false

    // Create a cleaned copy of attributes that doesn't include the first-class properties
    // and converts all values to strings for consistent serialization
    var cleanedAttributes: [String: String] = [:]
    for (key, value) in element.attributes {
      if !["visible", "enabled", "focused", "selected"].contains(key) {
        cleanedAttributes[key] = String(describing: value)
      }
    }

    // Create the frame
    let frame = ElementFrame(
      x: element.frame.origin.x,
      y: element.frame.origin.y,
      width: element.frame.size.width,
      height: element.frame.size.height,
    )

    // Handle children
    let children: [ElementDescriptor]? =
      if includeChildren, !element.children.isEmpty {
        element.children.map {
          from(element: $0, includeChildren: includeChildren, includePath: includePath)
        }
      } else {
        nil
      }

    // Generate a human-readable name for the element
    let name: String =
      if let title = element.title, !title.isEmpty {
        title
      } else if let desc = element.elementDescription, !desc.isEmpty {
        desc
      } else if let val = element.value, !val.isEmpty {
        "\(element.role) with value \(val)"
      } else {
        element.role
      }

    // Generate the path if requested
    let path: String?
    if includePath {
      do {
        path = try element.generatePath()
      } catch {
        // If path generation fails, we'll still return the descriptor without a path
        path = nil
      }
    } else {
      path = nil
    }

    // Always use the element path for uniqueness
    // This ensures uniqueness even when multiple elements have the same title
    return ElementDescriptor(
      id: element.path,
      name: name,
      role: element.role,
      title: element.title,
      value: element.value,
      description: element.elementDescription,
      frame: frame,
      isVisible: isVisible,
      isEnabled: isEnabled,
      isFocused: isFocused,
      isSelected: isSelected,
      actions: element.actions,
      attributes: cleanedAttributes,
      hasChildren: !element.children.isEmpty,
      childCount: element.children.isEmpty ? nil : element.children.count,
      children: children,
      path: path,
    )
  }

  /// Convert to MCP Value
  /// - Returns: An MCP Value representation of the descriptor
  public func toValue() throws -> Value {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    let decoder = JSONDecoder()
    return try decoder.decode(Value.self, from: data)
  }
}

/// A descriptor for element position and size
public struct ElementFrame: Codable, Sendable {
  /// X coordinate of the element's top-left corner
  public let x: CGFloat

  /// Y coordinate of the element's top-left corner
  public let y: CGFloat

  /// Width of the element
  public let width: CGFloat

  /// Height of the element
  public let height: CGFloat

  /// Create a new element frame
  /// - Parameters:
  ///   - x: X coordinate
  ///   - y: Y coordinate
  ///   - width: Width
  ///   - height: Height
  public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

/// A descriptor for an application window
public struct WindowDescriptor: Codable, Sendable, Identifiable {
  /// Unique identifier for the window
  public let id: String

  /// Human-readable name for the window
  public let name: String

  /// Window title
  public let title: String?

  /// Whether the window is the main window
  public let isMain: Bool

  /// Whether the window is minimized
  public let isMinimized: Bool

  /// Whether the window is visible
  public let isVisible: Bool

  /// Window position and size
  public let frame: ElementFrame

  /// Create a new window descriptor
  /// - Parameters:
  ///   - id: Unique identifier
  ///   - name: Human-readable name (optional)
  ///   - title: Window title (optional)
  ///   - isMain: Whether it's the main window
  ///   - isMinimized: Whether it's minimized
  ///   - isVisible: Whether it's visible
  ///   - frame: Window position and size
  public init(
    id: String,
    name: String? = nil,
    title: String? = nil,
    isMain: Bool = false,
    isMinimized: Bool = false,
    isVisible: Bool = true,
    frame: ElementFrame
  ) {
    self.id = id
    // Generate a name if not provided
    if let providedName = name {
      self.name = providedName
    } else if let title, !title.isEmpty {
      self.name = title
    } else {
      self.name = "Window \(id)"
    }
    self.title = title
    self.isMain = isMain
    self.isMinimized = isMinimized
    self.isVisible = isVisible
    self.frame = frame
  }

  /// Convert a UIElement representing a window to a WindowDescriptor
  /// - Parameter element: The UIElement to convert
  /// - Returns: A WindowDescriptor
  public static func from(element: UIElement) -> WindowDescriptor? {
    // Only convert windows
    guard element.role == AXAttribute.Role.window else { return nil }

    // Extract window-specific attributes
    let isMain = (element.attributes["main"] as? Bool) ?? false
    let isMinimized = (element.attributes["minimized"] as? Bool) ?? false
    let isVisible = (element.attributes["visible"] as? Bool) ?? true

    let frame = ElementFrame(
      x: element.frame.origin.x,
      y: element.frame.origin.y,
      width: element.frame.size.width,
      height: element.frame.size.height,
    )

    // Generate human-readable name
    let name: String =
      if let title = element.title, !title.isEmpty {
        title
      } else if let app = element.attributes["application"] as? String {
        "\(app) Window"
      } else {
        "Window"
      }

    return WindowDescriptor(
      id: element.path,
      name: name,
      title: element.title,
      isMain: isMain,
      isMinimized: isMinimized,
      isVisible: isVisible,
      frame: frame,
    )
  }

  /// Convert to MCP Value
  /// - Returns: An MCP Value representation of the descriptor
  public func toValue() throws -> Value {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    let decoder = JSONDecoder()
    return try decoder.decode(Value.self, from: data)
  }
}

/// A descriptor for a menu item
public struct MenuItemDescriptor: Codable, Sendable, Identifiable {
  /// Unique identifier for the menu item
  public let id: String

  /// Human-readable name for the menu item
  public let name: String

  /// Menu item title
  public let title: String?

  /// Whether the menu item is enabled
  public let isEnabled: Bool

  /// Whether the menu item is selected/checked
  public let isSelected: Bool

  /// Whether the menu item has a submenu
  public let hasSubmenu: Bool

  /// Submenu items, if available and requested
  public let submenuItems: [MenuItemDescriptor]?

  /// Menu item shortcut/keyboard equivalent
  public let shortcut: String?

  /// Create a new menu item descriptor
  /// - Parameters:
  ///   - id: Unique identifier
  ///   - name: Human-readable name (optional)
  ///   - title: Menu item title (optional)
  ///   - isEnabled: Whether it's enabled
  ///   - isSelected: Whether it's selected/checked
  ///   - hasSubmenu: Whether it has a submenu
  ///   - submenuItems: Submenu items (optional)
  ///   - shortcut: Keyboard shortcut (optional)
  public init(
    id: String,
    name: String? = nil,
    title: String? = nil,
    isEnabled: Bool = true,
    isSelected: Bool = false,
    hasSubmenu: Bool = false,
    submenuItems: [MenuItemDescriptor]? = nil,
    shortcut: String? = nil
  ) {
    self.id = id

    // Generate a name if not provided
    if let providedName = name {
      self.name = providedName
    } else if let title, !title.isEmpty {
      self.name = title
    } else {
      self.name = "Menu Item"
    }

    self.title = title
    self.isEnabled = isEnabled
    self.isSelected = isSelected
    self.hasSubmenu = hasSubmenu
    self.submenuItems = submenuItems
    self.shortcut = shortcut
  }

  /// Convert a UIElement representing a menu item to a MenuItemDescriptor
  /// - Parameters:
  ///   - element: The UIElement to convert
  ///   - includeSubmenu: Whether to include submenu items (default false)
  /// - Returns: A MenuItemDescriptor
  public static func from(
    element: UIElement,
    includeSubmenu: Bool = false,
  ) -> MenuItemDescriptor? {
    // More permissive approach for menu items - almost any element can be a menu item
    // We just filter out obvious containers and non-interactive elements
    let nonMenuRoles = [
      "AXWindow", "AXApplication", "AXGroup", "AXScrollArea", "AXUnknown", "AXSplitter",
    ]
    guard !nonMenuRoles.contains(element.role) else { return nil }

    // Extract menu-specific attributes
    let isEnabled = (element.attributes["enabled"] as? Bool) ?? true
    let isSelected = (element.attributes["selected"] as? Bool) ?? false

    // Check for a submenu
    let hasSubmenu = element.children.contains { $0.role == AXAttribute.Role.menu }

    // Process submenu items if requested
    let submenuItems: [MenuItemDescriptor]? =
      if includeSubmenu, hasSubmenu {
        // Find the submenu element
        if let submenu = element.children.first(where: { $0.role == AXAttribute.Role.menu }) {
          // Convert submenu items
          submenu.children.compactMap {
            from(element: $0, includeSubmenu: includeSubmenu)
          }
        } else {
          nil
        }
      } else {
        nil
      }

    // Extract keyboard shortcut if available
    let shortcut = element.attributes["keyboardShortcut"] as? String

    // Generate human-readable name - keep it simple and consistent
    var name: String
    if let title = element.title, !title.isEmpty {
      name = title
      if let shortcut, !shortcut.isEmpty {
        name += " (\(shortcut))"
      }
    } else {
      // Fallback to a generic name with the role
      name = "Menu Item (\(element.role))"
    }

    // Always use the element path as the ID
    return MenuItemDescriptor(
      id: element.path,
      name: name,
      title: element.title,
      isEnabled: isEnabled,
      isSelected: isSelected,
      hasSubmenu: hasSubmenu,
      submenuItems: submenuItems,
      shortcut: shortcut,
    )
  }

  /// Convert to MCP Value
  /// - Returns: An MCP Value representation of the descriptor
  public func toValue() throws -> Value {
    let encoder = JSONEncoder()
    let data = try encoder.encode(self)
    let decoder = JSONDecoder()
    return try decoder.decode(Value.self, from: data)
  }
}
