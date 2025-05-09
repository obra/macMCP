// ABOUTME: This file defines criteria for matching UI elements in tests.
// ABOUTME: It provides a flexible way to find UI elements based on their properties.

import Foundation
import CoreGraphics
@testable import MacMCP

/// Criteria for matching UI elements in tests
public struct UIElementCriteria {
    // Basic properties to match
    public let role: String?
    public let title: String?
    public let identifier: String?
    public let value: String?
    public let description: String?

    // Content matching options
    public let titleContains: String?
    public let identifierContains: String?
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
    ///   - identifier: Exact identifier to match
    ///   - value: Exact value to match
    ///   - description: Exact description to match
    ///   - titleContains: Title should contain this string
    ///   - identifierContains: Identifier should contain this string
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
        identifier: String? = nil,
        value: String? = nil,
        description: String? = nil,
        titleContains: String? = nil,
        identifierContains: String? = nil,
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
        self.identifier = identifier
        self.value = value
        self.description = description
        self.titleContains = titleContains
        self.identifierContains = identifierContains
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
        if let role = role, element.role != role {
            return false
        }
        
        if let title = title, element.title != title {
            return false
        }
        
        if let identifier = identifier, element.identifier != identifier {
            return false
        }
        
        if let value = value, element.value != value {
            return false
        }
        
        if let description = description, element.elementDescription != description {
            return false
        }
        
        // Check contains matches
        if let titleContains = titleContains, element.title?.contains(titleContains) != true {
            return false
        }
        
        if let identifierContains = identifierContains, !element.identifier.contains(identifierContains) {
            return false
        }
        
        if let valueContains = valueContains, element.value?.contains(valueContains) != true {
            return false
        }
        
        if let descriptionContains = descriptionContains, element.elementDescription?.contains(descriptionContains) != true {
            return false
        }
        
        // Check capabilities
        if let isClickable = isClickable, element.isClickable != isClickable {
            return false
        }
        
        if let isEditable = isEditable, element.isEditable != isEditable {
            return false
        }
        
        if let isVisible = isVisible, element.isVisible != isVisible {
            return false
        }
        
        if let isEnabled = isEnabled, element.isEnabled != isEnabled {
            return false
        }
        
        // Check position criteria
        if let position = position, !element.frame.contains(position) {
            return false
        }
        
        if let area = area, !element.frame.intersects(area) {
            return false
        }
        
        // All specified criteria are matched
        return true
    }
    
    /// Create a human-readable description of these criteria
    /// - Returns: A string describing the criteria for debugging
    public var debugDescription: String {
        var parts: [String] = []
        
        if let role = role {
            parts.append("role='\(role)'")
        }
        
        if let title = title {
            parts.append("title='\(title)'")
        }
        
        if let identifier = identifier {
            parts.append("identifier='\(identifier)'")
        }
        
        if let value = value {
            parts.append("value='\(value)'")
        }
        
        if let description = description {
            parts.append("description='\(description)'")
        }
        
        if let titleContains = titleContains {
            parts.append("titleContains='\(titleContains)'")
        }
        
        if let identifierContains = identifierContains {
            parts.append("identifierContains='\(identifierContains)'")
        }
        
        if let valueContains = valueContains {
            parts.append("valueContains='\(valueContains)'")
        }
        
        if let descriptionContains = descriptionContains {
            parts.append("descriptionContains='\(descriptionContains)'")
        }
        
        if let isClickable = isClickable {
            parts.append("isClickable=\(isClickable)")
        }
        
        if let isEditable = isEditable {
            parts.append("isEditable=\(isEditable)")
        }
        
        if let isVisible = isVisible {
            parts.append("isVisible=\(isVisible)")
        }
        
        if let isEnabled = isEnabled {
            parts.append("isEnabled=\(isEnabled)")
        }
        
        if let position = position {
            parts.append("position=(\(position.x), \(position.y))")
        }
        
        if let area = area {
            parts.append("area=(\(area.origin.x), \(area.origin.y), \(area.size.width), \(area.size.height))")
        }
        
        return parts.joined(separator: ", ")
    }
}