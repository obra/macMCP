// ABOUTME: This file defines the UIElement model used to represent UI elements in the accessibility hierarchy.
// ABOUTME: It includes properties for the element's attributes, relationships, and serialization methods.

import Foundation
@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import MCP
import MacMCPUtilities

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
    public static let visibleCharacterRange = "AXVisibleCharacterRange"
    public static let visibleCells = "AXVisibleCells"
    public static let visibleRows = "AXVisibleRows"
    public static let visibleColumns = "AXVisibleColumns"
    public static let horizontalScrollBar = "AXHorizontalScrollBar"
    public static let verticalScrollBar = "AXVerticalScrollBar"
    public static let horizontalUnitDescription = "AXHorizontalUnitDescription"
    public static let verticalUnitDescription = "AXVerticalUnitDescription"
    public static let maximumValue = "AXMaximumValue"
    public static let minimumValue = "AXMinimumValue"
    
    // Additional position related constants
    public static let visibleArea = "AXVisibleArea" // Visible area of a scrollable view
    public static let contents = "AXContents" // Contents of a container
    public static let topLevelUIElement = "AXTopLevelUIElement" // Top level element (window)
    public static let firstVisibleRow = "AXFirstVisibleRow" // First visible row in a table
    public static let lastVisibleRow = "AXLastVisibleRow" // Last visible row in a table
    public static let visibleRange = "AXVisibleRange" // Visible range in a document
    
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

/// Source of frame coordinate information
public enum FrameSource: String, Codable {
    /// Frame information came directly from AXPosition and AXSize attributes
    case direct = "direct"
    
    /// Frame information came from the AXFrame attribute
    case attribute = "attribute"
    
    /// Frame information was calculated based on parent frame and relative position
    case calculated = "calculated"
    
    /// Frame information was inferred from other elements (e.g., siblings)
    case inferred = "inferred"
    
    /// Frame information was derived from a viewport's visible area
    case viewport = "viewport"
    
    /// Frame information was estimated or approximated
    case estimated = "estimated"
    
    /// No valid frame information available
    case unavailable = "unavailable"
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
    
    /// Normalized frame information relative to parent element (percentages)
    public let normalizedFrame: CGRect?
    
    /// Viewport-relative coordinates (if the element is in a scrollable container)
    public let viewportFrame: CGRect?
    
    /// Frame derivation method (how the frame was determined)
    public let frameSource: FrameSource
    
    /// The parent element (if any)
    public weak var parent: UIElement?
    
    /// Child elements
    public let children: [UIElement]
    
    /// Additional attributes of the element
    public let attributes: [String: Any]
    
    /// Available actions that can be performed on this element
    public let actions: [String]

    /// The underlying AXUIElement (if available)
    public var axElement: AXUIElement?
    
    /// The UI path representation of this element (if available)
    public var path: String?
    
    // MARK: - Capability Properties
    
    /// Whether the element can be clicked or pressed
    public var isClickable: Bool {
        // Elements with AXPress action are definitely clickable
        if actions.contains(AXAttribute.Action.press) {
            return true
        }
       /* 
        // For Calculator and other apps that might not correctly report actions,
        // consider button-like elements as clickable even without explicit actions
        if role == AXAttribute.Role.button || 
           role == AXAttribute.Role.checkbox || 
           role == AXAttribute.Role.radioButton || 
           role == AXAttribute.Role.menuItem || 
           role == AXAttribute.Role.popUpButton {
            // Exclude obviously disabled buttons
            if let enabled = attributes["enabled"] as? Bool, !enabled {
                return false
            }
            return true
        }
       */ 
        return false
    }
    
    /// Whether the element can be edited (e.g., text fields)
    public var isEditable: Bool {
        return role == AXAttribute.Role.textField || 
               role == AXAttribute.Role.textArea || 
               (attributes["editable"] as? Bool) == true
    }
    
    /// Whether the element can be toggled (e.g., checkboxes, radio buttons)
    public var isToggleable: Bool {
        return role == AXAttribute.Role.checkbox || 
               role == AXAttribute.Role.radioButton
    }
    
    /// Whether the element can be selected from options (e.g., dropdowns)
    public var isSelectable: Bool {
        return role == AXAttribute.Role.popUpButton || 
               role.contains("ComboBox") ||
               actions.contains(AXAttribute.Action.showMenu)
    }
    
    /// Whether the element can be incremented/decremented (e.g., sliders, steppers)
    public var isAdjustable: Bool {
        return actions.contains(AXAttribute.Action.increment) || 
               actions.contains(AXAttribute.Action.decrement) ||
               role.contains("Slider") ||
               role.contains("Stepper")
    }
    
    /// Whether the element is visible
    /// This combines explicit visibility attribute with frame-based checks
    public var isVisible: Bool {
        // Check explicit visibility attribute
        let hasVisibilityAttribute = (attributes["visible"] as? Bool) ?? true
        
        // Element explicitly marked as not visible
        if !hasVisibilityAttribute {
            return false
        }
        
        // Check if element has zero or negative size - considered not visible
        let hasZeroSize = frame.size.width <= 0 || frame.size.height <= 0
        
        // Check if element is positioned outside screen bounds (rough approximation)
        // Assumes a standard large desktop size (this is just a safety check)
        let isOffScreen = frame.origin.x < -10000 || frame.origin.y < -10000 || 
                         frame.origin.x > 10000 || frame.origin.y > 10000
        
        // Special case: if it has a frameSource that's derived, it might be calculated
        // or estimated, so trust the frame less
        let isDerivedFrame = frameSource != .direct && frameSource != .attribute
        
        // Special case: if it has a viewportFrame, it could be in a scrollable area
        let hasViewportPos = viewportFrame != nil
        
        // Element is considered visible if:
        // 1. It has visibility attribute set to true AND 
        // 2. Either:
        //    a. It has non-zero size and is on-screen, OR
        //    b. It has a derived frame (calculated/estimated), OR
        //    c. It has viewport position (might be scrolled out of view)
        return hasVisibilityAttribute && (!hasZeroSize && !isOffScreen || isDerivedFrame || hasViewportPos)
    }
    
    /// Whether the element is enabled
    public var isEnabled: Bool {
        return (attributes["enabled"] as? Bool) ?? true
    }
    
    /// Whether the element is focused
    public var isFocused: Bool {
        return (attributes["focused"] as? Bool) ?? false
    }
    
    /// Whether the element is selected
    public var isSelected: Bool {
        return (attributes["selected"] as? Bool) ?? false
    }
    
    /// Create a new UI element
    /// - Parameters:
    ///   - identifier: Unique identifier for the element
    ///   - role: The accessibility role
    ///   - title: The title or label (optional)
    ///   - value: The current value (optional)
    ///   - description: A description (optional)
    ///   - frame: The element's frame in screen coordinates
    ///   - normalizedFrame: The frame coordinates normalized relative to parent (optional)
    ///   - viewportFrame: The frame coordinates relative to a scrollable viewport (optional)
    ///   - frameSource: The method used to determine the frame
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
        normalizedFrame: CGRect? = nil,
        viewportFrame: CGRect? = nil,
        frameSource: FrameSource = .direct,
        parent: UIElement? = nil,
        children: [UIElement] = [],
        attributes: [String: Any] = [:],
        actions: [String] = [],
        axElement: AXUIElement? = nil
    ) {
        self.identifier = identifier
        self.role = role
        self.title = title
        self.value = value
        self.elementDescription = elementDescription
        self.frame = frame
        self.normalizedFrame = normalizedFrame
        self.viewportFrame = viewportFrame
        self.frameSource = frameSource
        self.parent = parent
        self.children = children
        self.attributes = attributes
        self.actions = actions
        self.axElement = axElement
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
        
        // Add frame information
        json["frame"] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height,
            "source": frameSource.rawValue
        ]
        
        // Add normalized frame if available
        if let normalizedFrame = normalizedFrame {
            json["normalizedFrame"] = [
                "x": normalizedFrame.origin.x,
                "y": normalizedFrame.origin.y,
                "width": normalizedFrame.size.width,
                "height": normalizedFrame.size.height
            ]
        }
        
        // Add viewport frame if available
        if let viewportFrame = viewportFrame {
            json["viewportFrame"] = [
                "x": viewportFrame.origin.x,
                "y": viewportFrame.origin.y,
                "width": viewportFrame.size.width,
                "height": viewportFrame.size.height
            ]
        }
        
        // Add capability flags
        json["capabilities"] = [
            "clickable": isClickable,
            "editable": isEditable,
            "toggleable": isToggleable,
            "selectable": isSelectable, 
            "adjustable": isAdjustable,
            "visible": isVisible,
            "enabled": isEnabled,
            "focused": isFocused,
            "selected": isSelected
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
    
    /// Generate a path-based identifier for this element
    /// - Parameters:
    ///   - includeValue: Whether to include the value attribute (default false since values can change)
    ///   - includeFrame: Whether to include frame information (default false)
    /// - Returns: A path string conforming to ElementPath syntax
    /// - Throws: ElementPathError if path generation fails
    public func generatePath(includeValue: Bool = false, includeFrame: Bool = false) throws -> String {
        // Start building the path with the current element
        var pathSegments: [PathSegment] = []
        
        // Build the path from root to leaf (we'll reverse at the end)
        var currentElement: UIElement? = self
        
        // Convert the current element and its ancestors to path segments
        while let element = currentElement {
            // Create a segment for this element
            var attributes: [String: String] = [:]
            
            // Add useful identifying attributes - title, description, and identifier are most stable
            if let title = element.title, !title.isEmpty {
                attributes["AXTitle"] = PathNormalizer.escapeAttributeValue(title)
            }
            
            if let desc = element.elementDescription, !desc.isEmpty {
                attributes["AXDescription"] = PathNormalizer.escapeAttributeValue(desc)
            }
            
            // Include the value if requested and available
            if includeValue, let value = element.value, !value.isEmpty {
                attributes["AXValue"] = PathNormalizer.escapeAttributeValue(value)
            }
            
            // Add custom identifier if available
            if let identifier = element.attributes["identifier"] as? String, !identifier.isEmpty {
                attributes["AXIdentifier"] = identifier
            }
            
            // For applications, include bundle identifier if available
            if element.role == "AXApplication" {
                if let bundleId = element.attributes["bundleIdentifier"] as? String, !bundleId.isEmpty {
                    attributes["bundleIdentifier"] = bundleId
                }
            }
            
            // Include frame information if requested
            if includeFrame {
                attributes["x"] = String(format: "%.0f", element.frame.origin.x)
                attributes["y"] = String(format: "%.0f", element.frame.origin.y)
                attributes["width"] = String(format: "%.0f", element.frame.size.width)
                attributes["height"] = String(format: "%.0f", element.frame.size.height)
            }
            
            // Include boolean state attributes that help identify the element
            // Only include true values as false is the default
            if element.attributes["enabled"] as? Bool == false {
                attributes["AXEnabled"] = "false"
            }
            
            if element.attributes["focused"] as? Bool == true {
                attributes["AXFocused"] = "true"
            }
            
            if element.attributes["selected"] as? Bool == true {
                attributes["AXSelected"] = "true"
            }
            
            // Create the path segment
            let segment = PathSegment(role: element.role, attributes: attributes)
            pathSegments.append(segment)
            
            // Move to parent
            currentElement = element.parent
        }
        
        // Reverse the segments to get root-to-leaf order
        pathSegments.reverse()
        
        // Create the ElementPath
        let elementPath = try ElementPath(segments: pathSegments)
        
        // Handle special case for menu paths - support legacy format
        if self.identifier.hasPrefix("ui:menu:") {
            // Return the path using the new format, but retain the menu structure
            return elementPath.toString()
        }
        
        return elementPath.toString()
    }
}
