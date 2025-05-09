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
        self.identifier = jsonElement["identifier"] as? String ?? "unknown"
        self.role = jsonElement["role"] as? String ?? "Unknown"
        self.roleDescription = jsonElement["roleDescription"] as? String
        self.subrole = jsonElement["subrole"] as? String
        self.title = jsonElement["title"] as? String
        
        // Extract position and size
        if let frameDict = jsonElement["frame"] as? [String: Any],
           let x = frameDict["x"] as? Int,
           let y = frameDict["y"] as? Int,
           let width = frameDict["width"] as? Int,
           let height = frameDict["height"] as? Int {
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
        
        // State properties
        self.focused = jsonElement["focused"] as? Bool ?? false
        self.selected = jsonElement["selected"] as? Bool ?? false
        self.expanded = jsonElement["expanded"] as? Bool
        self.required = jsonElement["required"] as? Bool
        
        // Compute children count
        let childrenArray = jsonElement["children"] as? [[String: Any]] ?? []
        self.childrenCount = childrenArray.count
        
        // Relationship properties (infer from JSON structure)
        self.hasParent = jsonElement["parent"] != nil
        
        // Extract actions
        self.actions = jsonElement["actions"] as? [String] ?? []
        
        // Extract attributes and process them
        if let attrDict = jsonElement["attributes"] as? [String: Any] {
            self.attributes = attrDict
        } else {
            self.attributes = [:]
        }
        
        // Set computed properties
        // Consider an element enabled if it's directly marked as enabled OR it's clickable
        let directEnabled = jsonElement["enabled"] as? Bool ?? false
        let indirectEnabled = !self.actions.isEmpty || (jsonElement["clickable"] as? Bool ?? false)
        self.isEnabled = directEnabled || indirectEnabled
        self.isClickable = jsonElement["clickable"] as? Bool ?? false || self.actions.contains("AXPress")
        
        // Determine if element is visible
        let hasSize = self.frame != nil && (self.frame!.size.width > 0 || self.frame!.size.height > 0)
        let isHidden = jsonElement["hidden"] as? Bool ?? false
        self.isVisible = hasSize && !isHidden
        
        // Initialize children as empty (will be populated by inspector)
        self.children = []
    }
    
    /// Recursively populate children from JSON
    func populateChildren(from jsonElement: [String: Any], startingIndex: Int) -> Int {
        var nextIndex = startingIndex
        
        // Process children array if it exists
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