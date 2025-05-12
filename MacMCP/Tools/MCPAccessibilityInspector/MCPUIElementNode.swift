// ABOUTME: Core data structure for representing UI elements using MCP tools
// ABOUTME: Models accessibility elements with properties from MCP UI state API

import Foundation
import Cocoa

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
    
    init(jsonElement: [String: Any], index: Int) {
        self.index = index

        // Extract basic properties
        self.identifier = jsonElement["id"] as? String ?? jsonElement["identifier"] as? String ?? "unknown"
        self.role = jsonElement["role"] as? String ?? "Unknown"
        self.roleDescription = jsonElement["roleDescription"] as? String
        self.subrole = jsonElement["subrole"] as? String
        self.title = jsonElement["title"] as? String ?? jsonElement["name"] as? String

        // Extract position and size
        if let frameDict = jsonElement["frame"] as? [String: Any] {
            // Extract coordinates in a flexible way to handle both numeric formats
            let x = (frameDict["x"] as? NSNumber)?.doubleValue ?? Double(frameDict["x"] as? Int ?? 0)
            let y = (frameDict["y"] as? NSNumber)?.doubleValue ?? Double(frameDict["y"] as? Int ?? 0)
            let width = (frameDict["width"] as? NSNumber)?.doubleValue ?? Double(frameDict["width"] as? Int ?? 0)
            let height = (frameDict["height"] as? NSNumber)?.doubleValue ?? Double(frameDict["height"] as? Int ?? 0)

            self.frame = NSRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
        } else {
            self.frame = nil
        }

        // Additional text properties
        // Try to get description from multiple possible fields
        if let desc = jsonElement["elementDescription"] as? String {
            self.description = desc
        } else if let desc = jsonElement["description"] as? String {
            self.description = desc
        } else {
            self.description = nil
        }

        self.value = jsonElement["value"]
        self.valueDescription = jsonElement["valueDescription"] as? String

        // Extract actions first before we use them for clickable detection
        if let actionsArray = jsonElement["actions"] as? [String] {
            self.actions = actionsArray
        } else {
            self.actions = []
        }

        // State properties - improved with new InterfaceExplorerTool which provides state array
        if let stateArray = jsonElement["state"] as? [String] {
            self.focused = stateArray.contains("focused")
            self.selected = stateArray.contains("selected")
            self.expanded = stateArray.contains("expanded") ? true : (stateArray.contains("collapsed") ? false : nil)
            self.required = stateArray.contains("required") ? true : (stateArray.contains("optional") ? false : nil)

            // Update computed properties based on state array
            self.isEnabled = stateArray.contains("enabled")
            self.isVisible = stateArray.contains("visible")

            // Enhanced clickable detection from capabilities
            if let capabilities = jsonElement["capabilities"] as? [String] {
                self.isClickable = capabilities.contains("clickable")
            } else {
                self.isClickable = false
            }
        } else {
            // Fallback to legacy format for backward compatibility
            self.focused = jsonElement["focused"] as? Bool ?? false
            self.selected = jsonElement["selected"] as? Bool ?? false
            self.expanded = jsonElement["expanded"] as? Bool
            self.required = jsonElement["required"] as? Bool

            // Set computed properties using old approach
            let directEnabled = jsonElement["enabled"] as? Bool ?? false
            let indirectEnabled = !self.actions.isEmpty || (jsonElement["clickable"] as? Bool ?? false)
            self.isEnabled = directEnabled || indirectEnabled

            self.isClickable = jsonElement["clickable"] as? Bool ?? false || self.actions.contains("AXPress")

            // Determine if element is visible using old approach
            let hasSize = self.frame != nil && (self.frame!.size.width > 0 || self.frame!.size.height > 0)
            let isHidden = jsonElement["hidden"] as? Bool ?? false
            self.isVisible = hasSize && !isHidden
        }

        // Compute children count - check first for array of full elements, then for references
        if let childrenArray = jsonElement["children"] as? [[String: Any]] {
            self.childrenCount = childrenArray.count
            self.hasParent = true // If it has children, it's likely a parent
        } else {
            self.childrenCount = 0
            // Relationship properties (infer from JSON structure)
            self.hasParent = jsonElement["parent"] != nil
        }

        // Extract attributes and process them - might be in different format
        if let attrDict = jsonElement["attributes"] as? [String: Any] {
            self.attributes = attrDict
        } else if let attrDict = jsonElement["attributes"] as? [String: String] {
            // Convert string-to-string dictionary to string-to-any
            var convertedDict: [String: Any] = [:]
            for (key, value) in attrDict {
                convertedDict[key] = value
            }
            self.attributes = convertedDict
        } else {
            self.attributes = [:]
        }

        // Initialize children as empty (will be populated by inspector)
        self.children = []
    }
    
    /// Recursively populate children from JSON
    func populateChildren(from jsonElement: [String: Any], startingIndex: Int) -> Int {
        var nextIndex = startingIndex

        // Process children array if it exists - the InterfaceExplorerTool returns children as an array of objects
        if let childrenArray = jsonElement["children"] as? [[String: Any]] {
            for childJSON in childrenArray {
                let childNode = MCPUIElementNode(jsonElement: childJSON, index: nextIndex)
                nextIndex += 1
                self.children.append(childNode)

                // Recursively populate grandchildren
                nextIndex = childNode.populateChildren(from: childJSON, startingIndex: nextIndex)
            }
        }

        return nextIndex
    }
}