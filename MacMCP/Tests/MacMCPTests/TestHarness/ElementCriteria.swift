// ABOUTME: This file defines criteria for matching UI elements in test verifications.
// ABOUTME: It provides a flexible way to find elements based on various properties.

import Foundation
import CoreGraphics
@testable import MacMCP

/// Representation of a UI element from a tool response
public struct UIElementRepresentation {
    /// The element's identifier
    public let identifier: String
    
    /// The element's role (e.g., "AXButton")
    public let role: String
    
    /// The element's title (if any)
    public let title: String?
    
    /// The element's value (if any)
    public let value: String?
    
    /// The element's description (if any)
    public let description: String?
    
    /// The element's frame
    public let frame: CGRect
    
    /// The element's child elements
    public let children: [UIElementRepresentation]
    
    /// The element's capabilities
    public let capabilities: [String: Bool]
    
    /// The element's actions
    public let actions: [String]
    
    /// Create a new UI element representation
    /// - Parameters:
    ///   - identifier: The element identifier
    ///   - role: The element role
    ///   - title: The element title
    ///   - value: The element value
    ///   - description: The element description
    ///   - frame: The element frame
    ///   - children: The element's children
    ///   - capabilities: The element's capabilities
    ///   - actions: The element's available actions
    public init(
        identifier: String,
        role: String,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        frame: CGRect = CGRect.zero,
        children: [UIElementRepresentation] = [],
        capabilities: [String: Bool] = [:],
        actions: [String] = []
    ) {
        self.identifier = identifier
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.frame = frame
        self.children = children
        self.capabilities = capabilities
        self.actions = actions
    }
    
    /// Create a UI element representation from a UIElement
    /// - Parameter element: The source UIElement
    /// - Returns: A new UIElementRepresentation
    public static func from(element: UIElement) -> UIElementRepresentation {
        let rect = element.frame
        let capabilities = [
            "clickable": element.isClickable,
            "editable": element.isEditable,
            "toggleable": element.isToggleable,
            "selectable": element.isSelectable,
            "adjustable": element.isAdjustable,
            "visible": element.isVisible,
            "enabled": element.isEnabled,
            "focused": element.isFocused,
            "selected": element.isSelected
        ]
        
        return UIElementRepresentation(
            identifier: element.identifier,
            role: element.role,
            title: element.title,
            value: element.value,
            description: element.elementDescription,
            frame: rect,
            children: element.children.map { from(element: $0) },
            capabilities: capabilities,
            actions: element.actions
        )
    }
}

/// Criteria for matching UI elements
public struct ElementCriteria {
    // Base properties
    private let rolePattern: String?
    private let titlePattern: String?
    private let identifierPattern: String?
    private let valuePattern: String?
    private let descriptionPattern: String?
    
    // Capability requirements
    private let requireClickable: Bool?
    private let requireEditable: Bool?
    private let requireVisible: Bool?
    private let requireEnabled: Bool?
    private let requireFocused: Bool?
    private let requireSelected: Bool?
    
    // Position criteria
    private let position: CGPoint?
    private let area: CGRect?
    
    /// Create a new element criteria
    /// - Parameters:
    ///   - role: Pattern to match against element role
    ///   - title: Pattern to match against element title
    ///   - identifier: Pattern to match against element identifier
    ///   - value: Pattern to match against element value
    ///   - description: Pattern to match against element description
    ///   - clickable: Whether the element should be clickable
    ///   - editable: Whether the element should be editable
    ///   - visible: Whether the element should be visible
    ///   - enabled: Whether the element should be enabled
    ///   - focused: Whether the element should be focused
    ///   - selected: Whether the element should be selected
    ///   - position: Position the element should contain
    ///   - area: Area the element frame should intersect with
    public init(
        role: String? = nil,
        title: String? = nil,
        identifier: String? = nil,
        value: String? = nil,
        description: String? = nil,
        clickable: Bool? = nil,
        editable: Bool? = nil,
        visible: Bool? = nil,
        enabled: Bool? = nil,
        focused: Bool? = nil,
        selected: Bool? = nil,
        position: CGPoint? = nil,
        area: CGRect? = nil
    ) {
        self.rolePattern = role
        self.titlePattern = title
        self.identifierPattern = identifier
        self.valuePattern = value
        self.descriptionPattern = description
        self.requireClickable = clickable
        self.requireEditable = editable
        self.requireVisible = visible
        self.requireEnabled = enabled
        self.requireFocused = focused
        self.requireSelected = selected
        self.position = position
        self.area = area
    }
    
    /// Check if an element matches this criteria
    /// - Parameter element: The element to check
    /// - Returns: True if all specified criteria match
    public func matches(_ element: UIElementRepresentation) -> Bool {
        // Check role pattern
        if let rolePattern = rolePattern {
            if element.role.isEmpty {
                return false
            }
            
            guard matches(pattern: rolePattern, value: element.role) else {
                return false
            }
        }
        
        // Check title pattern
        if let titlePattern = titlePattern {
            guard let elementTitle = element.title, !elementTitle.isEmpty,
                  matches(pattern: titlePattern, value: elementTitle) else {
                return false
            }
        }
        
        // Check identifier pattern
        if let identifierPattern = identifierPattern {
            guard !element.identifier.isEmpty,
                  matches(pattern: identifierPattern, value: element.identifier) else {
                return false
            }
        }
        
        // Check value pattern
        if let valuePattern = valuePattern {
            guard let elementValue = element.value, !elementValue.isEmpty,
                  matches(pattern: valuePattern, value: elementValue) else {
                return false
            }
        }
        
        // Check description pattern
        if let descriptionPattern = descriptionPattern {
            guard let elementDescription = element.description, !elementDescription.isEmpty,
                  matches(pattern: descriptionPattern, value: elementDescription) else {
                return false
            }
        }
        
        // Check capability requirements
        if let requireClickable = requireClickable {
            guard element.capabilities["clickable"] == requireClickable else {
                return false
            }
        }
        
        if let requireEditable = requireEditable {
            guard element.capabilities["editable"] == requireEditable else {
                return false
            }
        }
        
        if let requireVisible = requireVisible {
            guard element.capabilities["visible"] == requireVisible else {
                return false
            }
        }
        
        if let requireEnabled = requireEnabled {
            guard element.capabilities["enabled"] == requireEnabled else {
                return false
            }
        }
        
        if let requireFocused = requireFocused {
            guard element.capabilities["focused"] == requireFocused else {
                return false
            }
        }
        
        if let requireSelected = requireSelected {
            guard element.capabilities["selected"] == requireSelected else {
                return false
            }
        }
        
        // Check position criteria
        if let position = position {
            guard element.frame.contains(position) else {
                return false
            }
        }
        
        // Check area criteria
        if let area = area {
            guard element.frame.intersects(area) else {
                return false
            }
        }
        
        // All specified criteria matched
        return true
    }
    
    /// Helper to match a pattern against a value
    /// - Parameters:
    ///   - pattern: The pattern to match
    ///   - value: The value to check
    /// - Returns: True if the pattern matches
    private func matches(pattern: String, value: String) -> Bool {
        if pattern.isEmpty || value.isEmpty {
            return false
        }
        
        // Check for exact match first (if pattern starts and ends with ^$)
        if pattern.hasPrefix("^") && pattern.hasSuffix("$") {
            let exactPattern = String(pattern.dropFirst().dropLast())
            return value == exactPattern
        }
        
        // Check for suffix match (if pattern starts with *)
        if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return value.hasSuffix(suffix)
        }
        
        // Check for prefix match (if pattern ends with *)
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return value.hasPrefix(prefix)
        }
        
        // Default to contains match
        return value.contains(pattern)
    }
}