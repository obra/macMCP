// ABOUTME: This file defines the UIElement model used to represent UI elements in the accessibility hierarchy.
// ABOUTME: It includes properties for the element's attributes, relationships, and serialization methods.

import Foundation
import AppKit
import MCP

/// AXAttribute key strings from Apple's AXConstants.h
public enum AXAttribute {
    public static let role = "AXRole"
    public static let title = "AXTitle"
    public static let description = "AXDescription"
    public static let value = "AXValue"
    public static let children = "AXChildren"
    public static let parent = "AXParent"
    public static let frame = "AXFrame"
    public static let position = "AXPosition"
    public static let size = "AXSize"
    public static let window = "AXWindow"
    public static let focused = "AXFocused"
    public static let enabled = "AXEnabled"
    public static let selected = "AXSelected"
    public static let identifier = "AXIdentifier"
    public static let actionDescription = "AXActionDescription"
    public static let help = "AXHelp"
    public static let actions = "AXActions"
    
    // Common AX roles
    public enum Role {
        public static let button = "AXButton"
        public static let checkbox = "AXCheckBox"
        public static let popUpButton = "AXPopUpButton"
        public static let radioButton = "AXRadioButton"
        public static let staticText = "AXStaticText"
        public static let textField = "AXTextField"
        public static let textArea = "AXTextArea"
        public static let menu = "AXMenu"
        public static let menuItem = "AXMenuItem"
        public static let window = "AXWindow"
        public static let application = "AXApplication"
        public static let scrollArea = "AXScrollArea"
        public static let image = "AXImage"
        public static let list = "AXList"
        public static let group = "AXGroup"
        public static let webArea = "AXWebArea"
        public static let link = "AXLink"
        public static let toolbar = "AXToolbar"
    }
    
    // Common AX actions
    public enum Action {
        public static let press = "AXPress"
        public static let increment = "AXIncrement"
        public static let decrement = "AXDecrement"
        public static let showMenu = "AXShowMenu"
        public static let pick = "AXPick"
        public static let cancel = "AXCancel"
        public static let confirm = "AXConfirm"
        public static let scrollToVisible = "AXScrollToVisible"
    }
}

/// Represents a UI element in the accessibility hierarchy
@objc public class UIElement: NSObject, Identifiable, @unchecked Sendable {
    /// Unique identifier for the element
    public let identifier: String
    
    /// The accessibility role of the element (e.g., "button", "textField", etc.)
    public let role: String
    
    /// The title or label of the element
    public let title: String?
    
    /// The current value of the element (for elements that have values)
    public let value: String?
    
    /// A description of the element (human-readable, not same as NSObject description)
    public let elementDescription: String?
    
    /// The frame of the element in screen coordinates
    public let frame: CGRect
    
    /// The parent element (if any)
    public weak var parent: UIElement?
    
    /// Child elements
    public let children: [UIElement]
    
    /// Additional attributes of the element
    public let attributes: [String: Any]
    
    /// Available actions that can be performed on this element
    public let actions: [String]
    
    /// Create a new UI element
    /// - Parameters:
    ///   - identifier: Unique identifier for the element
    ///   - role: The accessibility role
    ///   - title: The title or label (optional)
    ///   - value: The current value (optional)
    ///   - description: A description (optional)
    ///   - frame: The element's frame in screen coordinates
    ///   - parent: The parent element (optional)
    ///   - children: Child elements (default is empty)
    ///   - attributes: Additional attributes (default is empty)
    ///   - actions: Available actions (default is empty)
    public init(
        identifier: String,
        role: String,
        title: String? = nil,
        value: String? = nil,
        elementDescription: String? = nil,
        frame: CGRect,
        parent: UIElement? = nil,
        children: [UIElement] = [],
        attributes: [String: Any] = [:],
        actions: [String] = []
    ) {
        self.identifier = identifier
        self.role = role
        self.title = title
        self.value = value
        self.elementDescription = elementDescription
        self.frame = frame
        self.parent = parent
        self.children = children
        self.attributes = attributes
        self.actions = actions
    }
    
    /// Create a dictionary representation of the element
    /// - Returns: A dictionary with the element's properties
    public func toJSON() throws -> [String: Any] {
        var json: [String: Any] = [
            "identifier": identifier,
            "role": role,
        ]
        
        // Add optional fields
        if let title = title {
            json["title"] = title
        }
        
        if let value = value {
            json["value"] = value
        }
        
        if let elementDescription = elementDescription {
            json["description"] = elementDescription
        }
        
        // Add frame
        json["frame"] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        
        // Add attributes and actions
        if !attributes.isEmpty {
            json["attributes"] = attributes
        }
        
        if !actions.isEmpty {
            json["actions"] = actions
        }
        
        // Recursively add children
        if !children.isEmpty {
            let childData = try children.map { try $0.toJSON() }
            json["children"] = childData
        }
        
        return json
    }
    
    /// Convert to an MCP Value for use with tools
    /// - Returns: An MCP Value representation of the element
    public func toValue() throws -> Value {
        let json = try toJSON()
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        return try decoder.decode(Value.self, from: data)
    }
    
    // MARK: - NSObject overrides
    
    override public var description: String {
        return "\(role): \(title ?? "<no title>") [\(identifier)]"
    }
    
    // MARK: - Hashable
    
    public static func == (lhs: UIElement, rhs: UIElement) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    
    override public var hash: Int {
        return identifier.hashValue
    }
}