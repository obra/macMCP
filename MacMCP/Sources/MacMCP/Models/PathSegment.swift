// ABOUTME: PathSegment represents a single level in an element path hierarchy
// ABOUTME: Contains role, attributes, and optional index for element matching

import Foundation

/// A segment in an element path, representing a single level in the hierarchy
public struct PathSegment: Sendable {
  /// The accessibility role of the element (e.g., "AXButton")
  public let role: String

  /// Attribute constraints to filter matching elements
  public let attributes: [String: String]

  /// Optional index to select a specific element when multiple match
  public let index: Int?

  /// Create a new path segment
  /// - Parameters:
  ///   - role: Accessibility role
  ///   - attributes: Attribute constraints (default is empty)
  ///   - index: Optional index for selecting among multiple matches
  public init(role: String, attributes: [String: String] = [:], index: Int? = nil) {
    self.role = role
    self.attributes = attributes
    self.index = index
  }

  /// Generate a string representation of this segment
  /// - Returns: String representation of the path segment
  public func toString() -> String {
    var result = role

    // Add attributes if present
    for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
      // Escape quotes in the value
      let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
      result += "[@\(key)=\"\(escapedValue)\"]"
    }

    // Add index if present
    if let index {
      result += "[\(index)]"
    }

    return result
  }
}