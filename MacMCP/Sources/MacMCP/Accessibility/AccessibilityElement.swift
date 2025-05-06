// ABOUTME: This file contains utilities for working with the macOS Accessibility API.
// ABOUTME: It provides methods to convert AXUIElement objects to our UIElement model.

import Foundation
import AppKit

/// Utility for working with AXUIElement objects
public class AccessibilityElement {
    /// Convert an AXUIElement to our UIElement model
    /// - Parameters:
    ///   - axElement: The AXUIElement to convert
    ///   - recursive: Whether to recursively get children
    ///   - maxDepth: Maximum depth for recursion (to prevent infinite loops)
    /// - Returns: A UIElement representation
    public static func convertToUIElement(
        _ axElement: AXUIElement,
        recursive: Bool = true,
        maxDepth: Int = 10
    ) throws -> UIElement {
        return try _convertToUIElement(axElement, recursive: recursive, maxDepth: maxDepth, depth: 0)
    }
    
    private static func _convertToUIElement(
        _ axElement: AXUIElement,
        recursive: Bool,
        maxDepth: Int,
        depth: Int,
        parent: UIElement? = nil
    ) throws -> UIElement {
        // Get basic properties
        let role = try getAttribute(axElement, attribute: AXAttribute.role) as? String ?? "unknown"
        let title = try getAttribute(axElement, attribute: AXAttribute.title) as? String
        let value = try getStringValue(for: axElement)
        let description = try getAttribute(axElement, attribute: AXAttribute.description) as? String
        
        // Try to get an identifier - first try AXIdentifier, but if that's not available
        // construct one from properties and the memory address
        let identifier: String
        if let explicitID = try getAttribute(axElement, attribute: AXAttribute.identifier) as? String {
            identifier = explicitID
        } else {
            // Create an identifier from role + title + address
            let address = UInt(bitPattern: Unmanaged.passUnretained(axElement).toOpaque())
            identifier = "\(role)_\(title ?? "untitled")_\(address)"
        }
        
        // Get frame
        let frame: CGRect
        if let axFrame = try getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
            frame = axFrame.rectValue
        } else if let position = try getAttribute(axElement, attribute: AXAttribute.position) as? NSValue,
                 let size = try getAttribute(axElement, attribute: AXAttribute.size) as? NSValue {
            frame = CGRect(origin: position.pointValue, size: size.sizeValue)
        } else {
            frame = .zero
        }
        
        // Get additional attributes
        var attributes: [String: Any] = [:]
        
        // Common boolean attributes
        if let focused = try? getAttribute(axElement, attribute: AXAttribute.focused) as? Bool {
            attributes["focused"] = focused
        }
        
        if let enabled = try? getAttribute(axElement, attribute: AXAttribute.enabled) as? Bool {
            attributes["enabled"] = enabled
        }
        
        if let selected = try? getAttribute(axElement, attribute: AXAttribute.selected) as? Bool {
            attributes["selected"] = selected
        }
        
        // Get available actions
        let actions = try getActionNames(for: axElement)
        
        // Create the element first (without children)
        let element = UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: value, 
            elementDescription: description,
            frame: frame,
            parent: parent,
            attributes: attributes,
            actions: actions
        )
        
        // Recursively get children if requested and we haven't reached max depth
        var children: [UIElement] = []
        if recursive && depth < maxDepth {
            if let axChildren = try? getAttribute(axElement, attribute: AXAttribute.children) as? [AXUIElement] {
                for axChild in axChildren {
                    let child = try _convertToUIElement(
                        axChild,
                        recursive: recursive,
                        maxDepth: maxDepth,
                        depth: depth + 1,
                        parent: element
                    )
                    children.append(child)
                }
            }
        }
        
        // Create a new element with the same properties but with children
        return UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: value,
            elementDescription: description,
            frame: frame,
            parent: parent,
            children: children,
            attributes: attributes,
            actions: actions
        )
    }
    
    /// Get an attribute from an AXUIElement
    /// - Parameters:
    ///   - element: The AXUIElement to query
    ///   - attribute: The attribute name
    /// - Returns: The attribute value or nil if not available
    public static func getAttribute(_ element: AXUIElement, attribute: String) throws -> Any? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if error == .success {
            return value
        } else if error == .attributeUnsupported || error == .noValue {
            return nil
        } else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to get attribute \(attribute)"]
            )
        }
    }
    
    /// Get the string value for an element, converting non-string values if needed
    private static func getStringValue(for element: AXUIElement) throws -> String? {
        guard let value = try getAttribute(element, attribute: AXAttribute.value) else { return nil }
        
        // Handle different types of values
        if let stringValue = value as? String {
            return stringValue
        } else if let numberValue = value as? NSNumber {
            return numberValue.stringValue
        } else if let boolValue = value as? Bool {
            return boolValue ? "true" : "false"
        } else {
            // Convert other types to a description
            return String(describing: value)
        }
    }
    
    /// Get the available action names for an element
    private static func getActionNames(for element: AXUIElement) throws -> [String] {
        guard let actionNames = try getAttribute(element, attribute: AXAttribute.actions) as? [String] else {
            return []
        }
        return actionNames
    }
    
    /// Perform an action on an element
    /// - Parameters:
    ///   - element: The element to act on
    ///   - action: The action name
    public static func performAction(_ element: AXUIElement, action: String) throws {
        let error = AXUIElementPerformAction(element, action as CFString)
        
        if error != .success {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to perform action \(action)"]
            )
        }
    }
    
    /// Set an attribute value
    /// - Parameters:
    ///   - element: The element to modify
    ///   - attribute: The attribute name
    ///   - value: The new value
    public static func setAttribute(
        _ element: AXUIElement,
        attribute: String,
        value: Any
    ) throws {
        let error = AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            value as CFTypeRef
        )
        
        if error != .success {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to set attribute \(attribute)"]
            )
        }
    }
    
    /// Get the system-wide element (root of accessibility hierarchy)
    /// - Returns: The system-wide AXUIElement
    public static func systemWideElement() -> AXUIElement {
        return AXUIElementCreateSystemWide()
    }
    
    /// Get an application element by its process ID
    /// - Parameter pid: The process ID
    /// - Returns: The application AXUIElement
    public static func applicationElement(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
}