// ABOUTME: MCPUIElementNode.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Cocoa
import Foundation
import MacMCPUtilities

/// Represents a UI element with all its accessibility properties, retrieved via MCP tools
class MCPUIElementNode {
  let identifier: String
  let role: String
  let roleDescription: String?
  let subrole: String?
  let title: String?
  let description: String?
  let value: Any?
  let valueDescription: String?
  let frame: NSRect?
  let focused: Bool
  let selected: Bool
  let expanded: Bool?
  let required: Bool?
  let childrenCount: Int
  let hasParent: Bool
  let attributes: [String: Any]
  let actions: [String]
  var children: [MCPUIElementNode]
  let index: Int
  let isEnabled: Bool
  let isClickable: Bool
  let isVisible: Bool
  let elementPath: String? // Element path segment from server
  var parentPath: String? // Path of parent element (populated during traversal)
  var fullPath: String? // Complete path including all ancestors (calculated during traversal)

  init(jsonElement: [String: Any], index: Int) {
    self.index = index

    // Extract basic properties
    identifier = jsonElement["id"] as? String ?? jsonElement["identifier"] as? String ?? "unknown"
    role = jsonElement["role"] as? String ?? "Unknown"
    roleDescription = jsonElement["roleDescription"] as? String
    subrole = jsonElement["subrole"] as? String

    // Only use title from "title" field, not from "name"
    // The "name" field is a human-readable display name that may just be the role name
    title = jsonElement["title"] as? String

    // Extract position and size
    if let frameDict = jsonElement["frame"] as? [String: Any] {
      // Extract coordinates in a flexible way to handle both numeric formats
      let x = (frameDict["x"] as? NSNumber)?.doubleValue ?? Double(frameDict["x"] as? Int ?? 0)
      let y = (frameDict["y"] as? NSNumber)?.doubleValue ?? Double(frameDict["y"] as? Int ?? 0)
      let width =
        (frameDict["width"] as? NSNumber)?.doubleValue ?? Double(frameDict["width"] as? Int ?? 0)
      let height =
        (frameDict["height"] as? NSNumber)?.doubleValue ?? Double(frameDict["height"] as? Int ?? 0)

      frame = NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    } else {
      frame = nil
    }

    // Additional text properties
    // Try to get description from multiple possible fields
    if let desc = jsonElement["elementDescription"] as? String {
      description = desc
    } else if let desc = jsonElement["description"] as? String {
      description = desc
    } else {
      description = nil
    }

    value = jsonElement["value"]
    valueDescription = jsonElement["valueDescription"] as? String

    // Extract actions first before we use them for clickable detection
    if let actionsArray = jsonElement["actions"] as? [String] {
      actions = actionsArray
    } else {
      actions = []
    }

    // State properties - improved with new InterfaceExplorerTool which provides state array
    if let stateArray = jsonElement["state"] as? [String] {
      focused = stateArray.contains("focused")
      selected = stateArray.contains("selected")
      expanded =
        stateArray.contains("expanded") ? true : (stateArray.contains("collapsed") ? false : nil)
      required =
        stateArray.contains("required") ? true : (stateArray.contains("optional") ? false : nil)

      // Update computed properties based on state array
      isEnabled = stateArray.contains("enabled")
      isVisible = stateArray.contains("visible")

      // Enhanced clickable detection from capabilities
      if let capabilities = jsonElement["capabilities"] as? [String] {
        isClickable = capabilities.contains("clickable")
      } else {
        isClickable = false
      }
    } else {
      // Fallback to legacy format for backward compatibility
      focused = jsonElement["focused"] as? Bool ?? false
      selected = jsonElement["selected"] as? Bool ?? false
      expanded = jsonElement["expanded"] as? Bool
      required = jsonElement["required"] as? Bool

      // Set computed properties using old approach
      let directEnabled = jsonElement["enabled"] as? Bool ?? false
      let indirectEnabled = !actions.isEmpty || (jsonElement["clickable"] as? Bool ?? false)
      isEnabled = directEnabled || indirectEnabled

      isClickable = jsonElement["clickable"] as? Bool ?? false || actions.contains("AXPress")

      // Determine if element is visible using old approach
      let hasSize = frame != nil && (frame!.size.width > 0 || frame!.size.height > 0)
      let isHidden = jsonElement["hidden"] as? Bool ?? false
      isVisible = hasSize && !isHidden
    }

    // Compute children count - check first for array of full elements, then for references
    if let childrenArray = jsonElement["children"] as? [[String: Any]] {
      childrenCount = childrenArray.count
      hasParent = true // If it has children, it's likely a parent
    } else {
      childrenCount = 0
      // Relationship properties (infer from JSON structure)
      hasParent = jsonElement["parent"] != nil
    }

    // Extract attributes and process them - might be in different format
    if let attrDict = jsonElement["attributes"] as? [String: Any] {
      attributes = attrDict
    } else if let attrDict = jsonElement["attributes"] as? [String: String] {
      // Convert string-to-string dictionary to string-to-any
      var convertedDict: [String: Any] = [:]
      for (key, value) in attrDict {
        convertedDict[key] = value
      }
      attributes = convertedDict
    } else {
      attributes = [:]
    }

    // Extract path information from server
    elementPath = jsonElement["path"] as? String
    parentPath = nil

    // Important: Do NOT set fullPath here
    // The fullPath will be calculated during populateChildren based on parent hierarchy
    // This ensures that paths are always walked properly from parent to child
    fullPath = nil

    // Special case for the root application element
    // We need the root to have a valid path for children to build upon
    if role == "AXApplication", elementPath != nil {
      // For root application elements, we can use the server-provided path directly
      // This forms the foundation of our path hierarchy
      fullPath = elementPath
    }

    // Initialize children as empty (will be populated by inspector)
    children = []
  }

  /// Recursively populate children from JSON
  func populateChildren(from jsonElement: [String: Any], startingIndex: Int) -> Int {
    var nextIndex = startingIndex

    // Process children array if it exists - the InterfaceExplorerTool returns children as an array
    // of objects
    if let childrenArray = jsonElement["children"] as? [[String: Any]] {
      for childJSON in childrenArray {
        let childNode = MCPUIElementNode(jsonElement: childJSON, index: nextIndex)
        nextIndex += 1

        // IMPORTANT: First add the child to our children array
        // This establishes the parent-child relationship used for path building
        children.append(childNode)

        // Before calculating paths, ensure parent relationship is set
        // The parent-child relationship is critical for building fully qualified paths
        childNode.parentPath = fullPath // Use the parent's FULL path, not just elementPath

        // Now calculate the full path based on the parent-child relationship
        childNode.calculateFullPath(parentNode: self)

        // Only after the element's own path is fully set, recursively process its children
        nextIndex = childNode.populateChildren(from: childJSON, startingIndex: nextIndex)
      }
    }

    return nextIndex
  }

  /// Set the full path for this node by walking up the parent chain
  func calculateFullPath(parentNode: MCPUIElementNode?) {
    // Log entry info
    // print( "PATH DEBUG - calculateFullPath for \(role) with title \(title ?? "nil") and
    // description \(description ?? "nil")",)
    // print("PATH DEBUG - incoming server path: \(elementPath ?? "nil")")
    // print("PATH DEBUG - parent provided: \(parentNode != nil ? "yes" : "no")")
    // print("PATH DEBUG - parent fullPath: \(parentNode?.fullPath ?? "nil")")

    // We must ALWAYS walk up the entire parent chain to construct fully qualified paths
    if let parentNode, let parentPath = parentNode.fullPath {
      // If parent has a path, we need to append our segment to it
      let segment = generatePathSegment()
      // print("PATH DEBUG - generated segment: \(segment)")

      // Ensure we separate with a slash unless parent path already ends with /
      let newPath: String =
        if parentPath.hasSuffix("/") { parentPath + segment } else { parentPath + "/" + segment }

      fullPath = newPath // print("PATH DEBUG - calculated path: \(newPath)")
    } else {
      // If we're at the root level (no parent) and we got a path from the server, use it
      if let pathFromServer = elementPath {
        fullPath =
          pathFromServer // print("PATH DEBUG - using server path as root: \(pathFromServer)")
      } else {
        // We can't generate a valid fully qualified path
        // print("ERROR: Unable to generate a fully qualified path for element: \(role)")
        // Don't set any path - leaving it nil to indicate failure
        // print("PATH DEBUG - FAILED to generate path")
      }
    }
  }

  /// Generate a path segment for this element
  func generatePathSegment() -> String {
    // Get the path provided by the MCP server directly if available
    if let elementPath, !elementPath.hasPrefix("macos://ui/"),
       // It shouldn't be a full path already
       !elementPath.contains("/")
    { // It shouldn't contain path separators
      return elementPath // Return the server-provided segment as-is
    }

    // Otherwise, create a segment for this element
    var segment = role

    // Add key attributes to identify the element
    if let title, !title.isEmpty {
      let escapedTitle = PathNormalizer.escapeAttributeValue(title)
      segment += "[@AXTitle=\"\(escapedTitle)\"]"
    }

    if let description, !description.isEmpty {
      let escapedDesc = PathNormalizer.escapeAttributeValue(description)
      segment += "[@AXDescription=\"\(escapedDesc)\"]"
    }

    if let identifier = attributes["identifier"] as? String, !identifier.isEmpty {
      segment += "[@AXIdentifier=\"\(identifier)\"]"
    }

    return segment
  }

  /// Generate a synthetic element path if one wasn't provided
  /// Used as a fallback when the element doesn't have a path attribute
  func generateSyntheticPath() -> String? {
    // Start with the parent path (if we have one) or start a new path
    var pathBase = parentPath ?? "macos://ui/"

    // Don't add a separator if we're starting a new path (macos://ui/)
    if !pathBase.hasSuffix("/"), pathBase != "macos://ui/" { pathBase += "/" }

    // Create a path segment for this element
    var segment = role

    // Add key attributes to make the path more specific
    if let title, !title.isEmpty {
      let escapedTitle = PathNormalizer.escapeAttributeValue(title)
      segment += "[@AXTitle=\"\(escapedTitle)\"]"
    }

    if let description, !description.isEmpty {
      let escapedDesc = PathNormalizer.escapeAttributeValue(description)
      segment += "[@AXDescription=\"\(escapedDesc)\"]"
    }

    if let identifier = attributes["identifier"] as? String, !identifier.isEmpty {
      segment += "[@AXIdentifier=\"\(identifier)\"]"
    }

    return pathBase + segment
  }
}
