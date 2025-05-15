// ABOUTME: This file defines utilities for normalizing UI element paths with consistent attribute handling.
// ABOUTME: It provides methods for escaping, unescaping, and normalizing path components across the codebase.

import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Utility class for normalizing element paths to ensure consistency
public class PathNormalizer {
    
    /// Standard prefixes for accessibility attributes
    private static let attributePrefixes = [
        "AX"
    ]
    
    /// Maps of common attribute names to their standardized versions
    private static let attributeNameMappings: [String: String] = [
        // Common mappings from non-prefixed to prefixed versions
        "title": "AXTitle",
        "description": "AXDescription",
        "value": "AXValue",
        "id": "AXIdentifier",
        "identifier": "AXIdentifier",
        "help": "AXHelp",
        "role": "AXRole",
        "enabled": "AXEnabled",
        "focused": "AXFocused",
        "selected": "AXSelected",
        "parent": "AXParent",
        "children": "AXChildren",
        "position": "AXPosition",
        "size": "AXSize",
        "frame": "AXFrame",
        "bundleId": "bundleIdentifier",
        "bundleID": "bundleIdentifier"
    ]
    
    /// Normalize an accessibility attribute name to ensure consistent naming
    /// - Parameter name: The attribute name to normalize
    /// - Returns: Normalized attribute name
    public static func normalizeAttributeName(_ name: String) -> String {
        // If the name is already a standard AX attribute (starts with "AX"), return as is
        if name.hasPrefix("AX") {
            return name
        }
        
        // Look up in mapping table
        if let mappedName = attributeNameMappings[name] {
            return mappedName
        }
        
        // For any other attribute, apply standard prefix if it doesn't already have one
        return "AX" + name.prefix(1).uppercased() + name.dropFirst()
    }
    
    /// Escape attribute values for inclusion in path strings
    /// - Parameter value: The attribute value to escape
    /// - Returns: Escaped attribute value
    public static func escapeAttributeValue(_ value: String) -> String {
        var result = value
        
        // Escape backslashes first (so we don't double-escape)
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        
        // Escape quotes
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        
        // Escape control characters
        result = result.replacingOccurrences(of: "\n", with: "\\n")
        result = result.replacingOccurrences(of: "\r", with: "\\r")
        result = result.replacingOccurrences(of: "\t", with: "\\t")
        
        return result
    }
    
    /// Unescape attribute values from path strings
    /// - Parameter value: The escaped attribute value
    /// - Returns: Unescaped attribute value
    public static func unescapeAttributeValue(_ value: String) -> String {
        var result = value
        
        // We need to be careful with the order of operations here
        // First, handle control character escapes
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\r", with: "\r")
        result = result.replacingOccurrences(of: "\\t", with: "\t")
        
        // Handle quote escapes
        result = result.replacingOccurrences(of: "\\\"", with: "\"")
        
        // Handle backslash escapes last
        result = result.replacingOccurrences(of: "\\\\", with: "\\")
        
        return result
    }
    
    // MARK: - For integration with ElementPath
    
    /// Normalize an existing path string
    /// - Parameter path: The path string to normalize
    /// - Returns: Normalized path string, or nil if the path is invalid
    public static func normalizePathString(_ path: String) -> String? {
        // Ensure ui:// prefix is present
        guard path.hasPrefix("ui://") else {
            return nil
        }
        
        var normalizedPath = path
        
        // Normalize all common attribute names
        for (key, value) in attributeNameMappings {
            // Use a regex pattern to catch attribute references
            let pattern = "\\[@\(key)=\"([^\"]*)\"\\]"
            let replacement = "[@\(value)=\"$1\"]"
            
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(normalizedPath.startIndex..., in: normalizedPath)
                normalizedPath = regex.stringByReplacingMatches(in: normalizedPath, range: range, withTemplate: replacement)
            }
        }
        
        return normalizedPath
    }
    
    /// Generate a normalized path string for a UIElement
    /// Used by tests - in practice, UIElement.generatePath should be used directly
    /// - Parameter element: The UIElement to generate a path for
    /// - Returns: A normalized path string containing just this element's information
    public static func generateNormalizedPath(for element: Any) -> String {
        // Get properties via reflection for testing purposes
        let mirror = Mirror(reflecting: element)
        
        // Get the role
        var role = "Unknown"
        if let roleChild = mirror.children.first(where: { $0.label == "role" }) {
            if let roleValue = roleChild.value as? String {
                role = roleValue
            }
        }
        
        var path = "ui://" + role
        
        // Add normalized attributes
        if let titleChild = mirror.children.first(where: { $0.label == "title" }) {
            if let titleValue = titleChild.value as? String, !titleValue.isEmpty {
                path += "[@AXTitle=\"\(escapeAttributeValue(titleValue))\"]"
            }
        }
        
        if let descChild = mirror.children.first(where: { $0.label == "elementDescription" }) {
            if let descValue = descChild.value as? String, !descValue.isEmpty {
                path += "[@AXDescription=\"\(escapeAttributeValue(descValue))\"]"
            }
        }
        
        if let attrChild = mirror.children.first(where: { $0.label == "attributes" }) {
            if let attributes = attrChild.value as? [String: Any],
               let identifier = attributes["identifier"] as? String, !identifier.isEmpty {
                path += "[@AXIdentifier=\"\(identifier)\"]"
            }
        }
        
        return path
    }
}