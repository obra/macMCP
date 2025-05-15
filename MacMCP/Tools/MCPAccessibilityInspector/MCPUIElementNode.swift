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
        
        // Extract path information if available
        self.elementPath = jsonElement["path"] as? String
        self.parentPath = nil

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
                
                // Set the parent path relationship to help understand the hierarchy
                childNode.parentPath = self.elementPath
                
                // Calculate the full path for this node
                childNode.calculateFullPath(parentNode: self)
                
                // Add to children
                self.children.append(childNode)

                // Recursively populate grandchildren
                nextIndex = childNode.populateChildren(from: childJSON, startingIndex: nextIndex)
            }
        }

        return nextIndex
    }
    
    /// Calculate the full path for this node using parent's full path if available
    func calculateFullPath(parentNode: MCPUIElementNode?) {
        // Process node's path segment, removing any 'ui://' prefix if present
        var cleanSegment: String? = nil
        if let pathSegment = self.elementPath {
            // If this segment has a ui:// prefix, remove it
            if pathSegment.hasPrefix("ui://") {
                cleanSegment = String(pathSegment.dropFirst(5))
            } else {
                cleanSegment = pathSegment
            }
        }
        
        // For the root node, the full path is "ui://" + the cleaned path segment
        if parentNode == nil {
            // Root node - use "ui://" prefix with the cleaned segment
            if let segment = cleanSegment {
                self.fullPath = "ui://" + segment
            } else {
                self.fullPath = "ui://"
            }
            return
        }
        
        // If parent has a full path, combine with this node's segment
        if let parentFullPath = parentNode?.fullPath, let segment = cleanSegment {
            // Check if parent's path is the basic prefix
            if parentFullPath == "ui://" {
                // Join without adding an extra separator
                self.fullPath = parentFullPath + segment
            } else {
                // Join with separator
                self.fullPath = parentFullPath + "/" + segment
            }
            return
        }
        
        // If parent has no full path but has a path segment
        if let parentSegment = parentNode?.elementPath, let segment = cleanSegment {
            // Clean the parent segment too
            var cleanParentSegment = parentSegment
            if cleanParentSegment.hasPrefix("ui://") {
                cleanParentSegment = String(cleanParentSegment.dropFirst(5))
            }
            
            // Start with prefix
            self.fullPath = "ui://" + cleanParentSegment + "/" + segment
            return
        }
        
        // Last resort: Use the synthetic path
        self.fullPath = self.generateSyntheticPath()
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