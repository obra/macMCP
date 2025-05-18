// ABOUTME: UIElementCriteria.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import CoreGraphics
import Foundation

@testable import MacMCP

/// Criteria for matching UI elements in tests
public struct UIElementCriteria {
  // Basic properties to match
  public let role: String?
  public let title: String?
  public let path: String?
  public let value: String?
  public let description: String?

  // Content matching options
  public let titleContains: String?
  public let pathContains: String?
  public let valueContains: String?
  public let descriptionContains: String?

  // Capability requirements
  public let isClickable: Bool?
  public let isEditable: Bool?
  public let isVisible: Bool?
  public let isEnabled: Bool?

  // Position criteria
  public let position: CGPoint?
  public let area: CGRect?

  /// Create new element criteria
  /// - Parameters:
  ///   - role: Exact role to match
  ///   - title: Exact title to match
  ///   - path: Exact path to match
  ///   - value: Exact value to match
  ///   - description: Exact description to match
  ///   - titleContains: Title should contain this string
  ///   - pathContains: Path should contain this string
  ///   - valueContains: Value should contain this string
  ///   - descriptionContains: Description should contain this string
  ///   - isClickable: Element should be clickable
  ///   - isEditable: Element should be editable
  ///   - isVisible: Element should be visible
  ///   - isEnabled: Element should be enabled
  ///   - position: Position that should be within the element's frame
  ///   - area: Area that should intersect with the element's frame
  public init(
    role: String? = nil,
    title: String? = nil,
    path: String? = nil,
    value: String? = nil,
    description: String? = nil,
    titleContains: String? = nil,
    pathContains: String? = nil,
    valueContains: String? = nil,
    descriptionContains: String? = nil,
    isClickable: Bool? = nil,
    isEditable: Bool? = nil,
    isVisible: Bool? = nil,
    isEnabled: Bool? = nil,
    position: CGPoint? = nil,
    area: CGRect? = nil
  ) {
    self.role = role
    self.title = title
    self.path = path
    self.value = value
    self.description = description
    self.titleContains = titleContains
    self.pathContains = pathContains
    self.valueContains = valueContains
    self.descriptionContains = descriptionContains
    self.isClickable = isClickable
    self.isEditable = isEditable
    self.isVisible = isVisible
    self.isEnabled = isEnabled
    self.position = position
    self.area = area
  }

  /// Check if a UI element matches these criteria
  /// - Parameter element: The element to check
  /// - Returns: True if the element matches all specified criteria
  public func matches(_ element: UIElement) -> Bool {
    // Check exact matches first
    if let role, element.role != role {
      return false
    }

    if let title, element.title != title {
      return false
    }

    if let path, element.path != path {
      return false
    }

    if let value {
      if element.value == nil {
        return false
      }

      // Handle conversion to string for comparison
      let elementValueString = String(describing: element.value!)
      if elementValueString != value {
        return false
      }
    }

    if let description, element.elementDescription != description {
      return false
    }

    // Check contains matches with case-insensitive comparison
    if let titleContains {
      if element.title == nil || !(element.title!.localizedCaseInsensitiveContains(titleContains)) {
        return false
      }
    }

    if let pathContains,
      !element.path.localizedCaseInsensitiveContains(pathContains)
    {
      return false
    }

    if let valueContains {
      if element.value == nil {
        return false
      }

      // Handle conversion to string for comparison
      let elementValueString = String(describing: element.value!)
      if !elementValueString.localizedCaseInsensitiveContains(valueContains) {
        return false
      }
    }

    if let descriptionContains {
      if element
        .elementDescription == nil
        || !(element.elementDescription!.localizedCaseInsensitiveContains(descriptionContains))
      {
        return false
      }
    }

    // Check capabilities
    // Note that element.isClickable is derived from attributes in the parseUIElement method
    if let isClickable, element.isClickable != isClickable {
      return false
    }

    if let isEditable, element.isEditable != isEditable {
      return false
    }

    if let isVisible, element.isVisible != isVisible {
      return false
    }

    if let isEnabled, element.isEnabled != isEnabled {
      return false
    }

    // Check position criteria
    if let position, !element.frame.contains(position) {
      return false
    }

    if let area, !element.frame.intersects(area) {
      return false
    }

    // All specified criteria are matched
    return true
  }

  /// Create a human-readable description of these criteria
  /// - Returns: A string describing the criteria for debugging
  public var debugDescription: String {
    var parts: [String] = []

    if let role {
      parts.append("role='\(role)'")
    }

    if let title {
      parts.append("title='\(title)'")
    }

    if let path {
      parts.append("path='\(path)'")
    }

    if let value {
      parts.append("value='\(value)'")
    }

    if let description {
      parts.append("description='\(description)'")
    }

    if let titleContains {
      parts.append("titleContains='\(titleContains)'")
    }

    if let pathContains {
      parts.append("pathContains='\(pathContains)'")
    }

    if let valueContains {
      parts.append("valueContains='\(valueContains)'")
    }

    if let descriptionContains {
      parts.append("descriptionContains='\(descriptionContains)'")
    }

    if let isClickable {
      parts.append("isClickable=\(isClickable)")
    }

    if let isEditable {
      parts.append("isEditable=\(isEditable)")
    }

    if let isVisible {
      parts.append("isVisible=\(isVisible)")
    }

    if let isEnabled {
      parts.append("isEnabled=\(isEnabled)")
    }

    if let position {
      parts.append("position=(\(position.x), \(position.y))")
    }

    if let area {
      parts.append(
        "area=(\(area.origin.x), \(area.origin.y), \(area.size.width), \(area.size.height))")
    }

    return parts.joined(separator: ", ")
  }
}
