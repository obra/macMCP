// ABOUTME: Core data structure for representing UI elements using MCP tools
// ABOUTME: Models accessibility elements with properties from MCP UI state API

import Foundation
import Cocoa
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
        self.identifier = jsonElement["id"] as? String ?? jsonElement["identifier"] as? String ?? "unknown"
        self.role = jsonElement["role"] as? String ?? "Unknown"
        self.roleDescription = jsonElement["roleDescription"] as? String
        self.subrole = jsonElement["subrole"] as? String
        
        // Only use title from "title" field, not from "name"
        // The "name" field is a human-readable display name that may just be the role name
        self.title = jsonElement["title"] as? String

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
        
        // Extract path information from server
        self.elementPath = jsonElement["path"] as? String
        self.parentPath = nil
        
        // Important: Do NOT set fullPath here
        // The fullPath will be calculated during populateChildren based on parent hierarchy
        // This ensures that paths are always walked properly from parent to child
        self.fullPath = nil
        
        // Special case for the root application element
        // We need the root to have a valid path for children to build upon
        if self.role == "AXApplication" && self.elementPath != nil {
            // For root application elements, we can use the server-provided path directly
            // This forms the foundation of our path hierarchy
            self.fullPath = self.elementPath
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
                
                // IMPORTANT: First add the child to our children array
                // This establishes the parent-child relationship used for path building
                self.children.append(childNode)
                
                // Before calculating paths, ensure parent relationship is set
                // The parent-child relationship is critical for building fully qualified paths
                childNode.parentPath = self.fullPath  // Use the parent's FULL path, not just elementPath
                
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
        print("PATH DEBUG - calculateFullPath for \(self.role) with title \(self.title ?? "nil") and description \(self.description ?? "nil")")
        print("PATH DEBUG - incoming server path: \(self.elementPath ?? "nil")")
        print("PATH DEBUG - parent provided: \(parentNode != nil ? "yes" : "no")")
        print("PATH DEBUG - parent fullPath: \(parentNode?.fullPath ?? "nil")")
        
        // We must ALWAYS walk up the entire parent chain to construct fully qualified paths
        if let parentNode = parentNode, let parentPath = parentNode.fullPath {
            // If parent has a path, we need to append our segment to it
            let segment = self.generatePathSegment()
            print("PATH DEBUG - generated segment: \(segment)")
            
            // Ensure we separate with a slash unless parent path already ends with /
            var newPath: String
            if parentPath.hasSuffix("/") {
                newPath = parentPath + segment
            } else {
                newPath = parentPath + "/" + segment
            }
            
            self.fullPath = newPath
            print("PATH DEBUG - calculated path: \(newPath)")
        } else {
            // If we're at the root level (no parent) and we got a path from the server, use it
            if let pathFromServer = self.elementPath {
                self.fullPath = pathFromServer
                print("PATH DEBUG - using server path as root: \(pathFromServer)")
            } else {
                // We can't generate a valid fully qualified path
                print("ERROR: Unable to generate a fully qualified path for element: \(self.role)")
                // Don't set any path - leaving it nil to indicate failure
                print("PATH DEBUG - FAILED to generate path")
            }
        }
    }
    
    /// Generate a path segment for this element
    func generatePathSegment() -> String {
        // Get the path provided by the MCP server directly if available
        if let elementPath = self.elementPath, 
           !elementPath.hasPrefix("ui://"),  // It shouldn't be a full path already
           !elementPath.contains("/") {      // It shouldn't contain path separators
            return elementPath              // Return the server-provided segment as-is
        }
        
        // Otherwise, create a segment for this element
        var segment = role
        
        // Add key attributes to identify the element
        if let title = self.title, !title.isEmpty {
            let escapedTitle = PathNormalizer.escapeAttributeValue(title)
            segment += "[@AXTitle=\"\(escapedTitle)\"]"
        }
        
        if let description = self.description, !description.isEmpty {
            let escapedDesc = PathNormalizer.escapeAttributeValue(description)
            segment += "[@AXDescription=\"\(escapedDesc)\"]"
        }
        
        if let identifier = self.attributes["identifier"] as? String, !identifier.isEmpty {
            segment += "[@AXIdentifier=\"\(identifier)\"]"
        }
        
        return segment
    }
    
    /// Generate a synthetic element path if one wasn't provided
    /// Used as a fallback when the element doesn't have a path attribute
    func generateSyntheticPath() -> String? {
        // Start with the parent path (if we have one) or start a new path
        var pathBase = parentPath ?? "ui://"
        
        // Don't add a separator if we're starting a new path (ui://)
        if !pathBase.hasSuffix("/") && pathBase != "ui://" {
            pathBase += "/"
        }
        
        // Create a path segment for this element
        var segment = role
        
        // Add key attributes to make the path more specific
        if let title = self.title, !title.isEmpty {
            let escapedTitle = PathNormalizer.escapeAttributeValue(title)
            segment += "[@AXTitle=\"\(escapedTitle)\"]"
        }
        
        if let description = self.description, !description.isEmpty {
            let escapedDesc = PathNormalizer.escapeAttributeValue(description)
            segment += "[@AXDescription=\"\(escapedDesc)\"]"
        }
        
        if let identifier = self.attributes["identifier"] as? String, !identifier.isEmpty {
            segment += "[@AXIdentifier=\"\(identifier)\"]"
        }
        
        return pathBase + segment
    }
}