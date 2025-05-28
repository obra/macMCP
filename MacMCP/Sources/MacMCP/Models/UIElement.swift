// ABOUTME: UIElement.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
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
  public static let visibleArea = "AXVisibleArea"  // Visible area of a scrollable view
  public static let contents = "AXContents"  // Contents of a container
  public static let topLevelUIElement = "AXTopLevelUIElement"  // Top level element (window)
  public static let firstVisibleRow = "AXFirstVisibleRow"  // First visible row in a table
  public static let lastVisibleRow = "AXLastVisibleRow"  // Last visible row in a table
  public static let visibleRange = "AXVisibleRange"  // Visible range in a document

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
  case direct

  /// Frame information came from the AXFrame attribute
  case attribute

  /// Frame information was calculated based on parent frame and relative position
  case calculated

  /// Frame information was inferred from other elements (e.g., siblings)
  case inferred

  /// Frame information was derived from a viewport's visible area
  case viewport

  /// Frame information was estimated or approximated
  case estimated

  /// No valid frame information available
  case unavailable
}

/// Represents a UI element in the accessibility hierarchy
@objc public class UIElement: NSObject, Identifiable, @unchecked Sendable {
  /// The accessibility role of the element (e.g., "button", "textField", etc.)
  public let role: String

  /// The title or label of the element
  public let title: String?

  /// The current value of the element (for elements that have values)
  public let value: String?

  /// A description of the element (human-readable, not same as NSObject description)
  public let elementDescription: String?

  /// The accessibility identifier of the element (AXIdentifier)
  public let identifier: String?

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

  /// The UI path representation of this element (XPath-inspired format)
  public var path: String

  // MARK: - Capability Properties

  /// Whether the element can be clicked or pressed
  public var isClickable: Bool {
    // Elements with AXPress action are definitely clickable
    if actions.contains(AXAttribute.Action.press) {
      return true
    }
    return false
  }

  /// Whether the element can be edited (e.g., text fields)
  public var isEditable: Bool {
    role == AXAttribute.Role.textField || role == AXAttribute.Role.textArea
      || (attributes["editable"] as? Bool) == true
  }

  /// Whether the element can be toggled (e.g., checkboxes, radio buttons)
  public var isToggleable: Bool {
    role == AXAttribute.Role.checkbox || role == AXAttribute.Role.radioButton
  }

  /// Whether the element can be selected from options (e.g., dropdowns)
  public var isSelectable: Bool {
    role == AXAttribute.Role.popUpButton || role.contains("ComboBox")
      || actions.contains(AXAttribute.Action.showMenu)
  }

  /// Whether the element can be incremented/decremented (e.g., sliders, steppers)
  public var isAdjustable: Bool {
    actions.contains(AXAttribute.Action.increment) || actions.contains(AXAttribute.Action.decrement)
      || role.contains("Slider") || role.contains("Stepper")
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
    let isOffScreen =
      frame.origin.x < -10000 || frame.origin.y < -10000 || frame.origin.x > 10000
      || frame.origin.y > 10000

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
    return hasVisibilityAttribute
      && (!hasZeroSize && !isOffScreen || isDerivedFrame || hasViewportPos)
  }

  /// Whether the element is enabled
  public var isEnabled: Bool {
    (attributes["enabled"] as? Bool) ?? true
  }

  /// Whether the element is focused
  public var isFocused: Bool {
    (attributes["focused"] as? Bool) ?? false
  }

  /// Whether the element is selected
  public var isSelected: Bool {
    (attributes["selected"] as? Bool) ?? false
  }

  /// Initialize a UIElement from a path string
  /// - Parameters:
  ///   - path: The path string to resolve (must conform to ElementPath syntax)
  ///   - accessibilityService: The AccessibilityService to use for resolution
  /// - Throws: ElementPathError if the path cannot be resolved
  public convenience init(fromPath path: String, accessibilityService: AccessibilityServiceProtocol)
    async throws
  {
    // Parse the path string into an ElementPath
    let elementPath = try ElementPath.parse(path)

    // Initialize from the parsed path
    try await self.init(fromElementPath: elementPath, accessibilityService: accessibilityService)
  }

  /// Initialize a UIElement from an ElementPath
  /// - Parameters:
  ///   - elementPath: The ElementPath to resolve
  ///   - accessibilityService: The AccessibilityService to use for resolution
  /// - Throws: ElementPathError if the path cannot be resolved
  public convenience init(
    fromElementPath elementPath: ElementPath,
    accessibilityService: AccessibilityServiceProtocol
  ) async throws {
    // Resolve the path to an AXUIElement
    let axElement = try await elementPath.resolve(using: accessibilityService)

    // Fetch all AX attributes for this element
    var attributes: [String: Any] = [:]
    var attrNamesRef: CFArray?
    if AXUIElementCopyAttributeNames(axElement, &attrNamesRef) == .success,
       let attrNames = attrNamesRef as? [String] {
      for attrName in attrNames {
        var attrValueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, attrName as CFString, &attrValueRef) == .success,
           let value = attrValueRef {
          // Try to convert value to something JSON-serializable
          if let str = value as? String {
            attributes[attrName] = str
          } else if let num = value as? NSNumber {
            attributes[attrName] = num
          } else if let bool = value as? Bool {
            attributes[attrName] = bool
          } else if let arr = value as? [Any] {
            attributes[attrName] = arr.map { "\($0)" }
          } else {
            attributes[attrName] = "\(value)"
          }
        }
      }
    }

    // Get essential properties for UIElement initialization
    var pathString = ""
    var role = ""
    var title: String?
    var value: String?
    var elementDescription: String?
    var frame = CGRect.zero
    var actions: [String] = []

    // Get the role
    var roleRef: CFTypeRef?
    let roleStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.role as CFString, &roleRef)
    if roleStatus == .success, let roleValue = roleRef as? String {
      role = roleValue
    } else {
      throw ElementPathError.segmentResolutionFailed(
        "Could not determine element role", atSegment: 0)
    }

    // Get the title if available
    var titleRef: CFTypeRef?
    let titleStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.title as CFString, &titleRef)
    if titleStatus == .success, let titleValue = titleRef as? String {
      title = titleValue
    }

    // Get the value if available
    var valueRef: CFTypeRef?
    let valueStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.value as CFString, &valueRef)
    if valueStatus == .success {
      if let stringValue = valueRef as? String {
        value = stringValue
      } else if let numberValue = valueRef as? NSNumber {
        value = numberValue.stringValue
      } else if let boolValue = valueRef as? Bool {
        value = boolValue ? "true" : "false"
      }
    }

    // Get the description if available
    var descriptionRef: CFTypeRef?
    let descriptionStatus = AXUIElementCopyAttributeValue(
      axElement,
      AXAttribute.description as CFString,
      &descriptionRef,
    )
    if descriptionStatus == .success, let descriptionValue = descriptionRef as? String {
      elementDescription = descriptionValue
    }
    // Note: AXError.attributeUnsupported (-25200) is expected for elements without descriptions
    // The system-level error logging cannot be suppressed but is normal behavior

    // Get the identifier if available
    var identifierRef: CFTypeRef?
    let identifierStatus = AXUIElementCopyAttributeValue(
      axElement,
      AXAttribute.identifier as CFString,
      &identifierRef,
    )
    let identifier: String? = identifierStatus == .success ? identifierRef as? String : nil

    // Get the frame
    var frameRef: CFTypeRef?
    let frameStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.frame as CFString, &frameRef)
    if frameStatus == .success, let frameValue = frameRef as? CGRect {
      frame = frameValue
    } else {
      // Try getting position and size separately
      var positionRef: CFTypeRef?
      let positionStatus = AXUIElementCopyAttributeValue(
        axElement,
        AXAttribute.position as CFString,
        &positionRef,
      )
      var sizeRef: CFTypeRef?
      let sizeStatus = AXUIElementCopyAttributeValue(
        axElement, AXAttribute.size as CFString, &sizeRef)

      if positionStatus == .success, let positionValue = positionRef as? CGPoint,
        sizeStatus == .success, let sizeValue = sizeRef as? CGSize
      {
        frame = CGRect(origin: positionValue, size: sizeValue)
      }
    }

    // Get available actions
    var actionsRef: CFTypeRef?
    let actionsStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.actions as CFString, &actionsRef)
    if actionsStatus == .success, let actionsArray = actionsRef as? [String] {
      actions = actionsArray
    }

    // Note: enabled, focused, and selected states are handled by getStateArray() method
    // and should not be duplicated in attributes dictionary

    // Generate the path string
    pathString = elementPath.toString()

    // Initialize the UIElement instance
    self.init(
      path: pathString,
      role: role,
      title: title,
      value: value,
      elementDescription: elementDescription,
      identifier: identifier,
      frame: frame,
      frameSource: .direct,
      attributes: attributes,
      actions: actions,
      axElement: axElement,
    )

    // Path is already set in constructor
  }

  /// Create a new UI element
  /// - Parameters:
  ///   - path: Path-based identifier for the element
  ///   - role: The accessibility role
  ///   - title: The title or label (optional)
  ///   - value: The current value (optional)
  ///   - description: A description (optional)
  ///   - identifier: The accessibility identifier (optional)
  ///   - frame: The element's frame in screen coordinates
  ///   - normalizedFrame: The frame coordinates normalized relative to parent (optional)
  ///   - viewportFrame: The frame coordinates relative to a scrollable viewport (optional)
  ///   - frameSource: The method used to determine the frame
  ///   - parent: The parent element (optional)
  ///   - children: Child elements (default is empty)
  ///   - attributes: Additional attributes (default is empty)
  ///   - actions: Available actions (default is empty)
  public init(
    path: String,
    role: String,
    title: String? = nil,
    value: String? = nil,
    elementDescription: String? = nil,
    identifier: String? = nil,
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
    self.path = path
    self.role = role
    self.title = title
    self.value = value
    self.elementDescription = elementDescription
    self.identifier = identifier
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
      "path": path,
      "role": role,
    ]

    // Add optional fields
    if let title {
      json["title"] = title
    }

    if let value {
      json["value"] = value
    }

    if let elementDescription {
      json["description"] = elementDescription
    }

    // Path is already included in the base properties
    // But we can try to regenerate it to get a more complete path if possible
    do {
      let generatedPath = try generatePath()
      // Use the generated path if it's different from the existing one
      if generatedPath != path {
        json["generatedPath"] = generatedPath
      }
    } catch {
      // If path generation fails, we already have the basic path included
    }

    // Add frame information
    json["frame"] = [
      "x": frame.origin.x,
      "y": frame.origin.y,
      "width": frame.size.width,
      "height": frame.size.height,
      "source": frameSource.rawValue,
    ]

    // Add normalized frame if available
    if let normalizedFrame {
      json["normalizedFrame"] = [
        "x": normalizedFrame.origin.x,
        "y": normalizedFrame.origin.y,
        "width": normalizedFrame.size.width,
        "height": normalizedFrame.size.height,
      ]
    }

    // Add viewport frame if available
    if let viewportFrame {
      json["viewportFrame"] = [
        "x": viewportFrame.origin.x,
        "y": viewportFrame.origin.y,
        "width": viewportFrame.size.width,
        "height": viewportFrame.size.height,
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
      "selected": isSelected,
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
    "\(role): \(title ?? "<no title>") [\(path)]"
  }

  // MARK: - Hashable

  public static func == (lhs: UIElement, rhs: UIElement) -> Bool {
    lhs.path == rhs.path
  }
  
  public static func != (lhs: UIElement, rhs: UIElement) -> Bool {
    !(lhs == rhs)
  }
  
  override public func isEqual(_ object: Any?) -> Bool {
    guard let other = object as? UIElement else { return false }
    return self == other
  }

  override public var hash: Int {
    path.hashValue
  }

  /// Create a copy of this UIElement
  /// - Returns: A new UIElement instance with the same properties
  public func copy() -> UIElement {
    let elementCopy = UIElement(
      path: path,
      role: role,
      title: title,
      value: value,
      elementDescription: elementDescription,
      identifier: identifier,
      frame: frame,
      normalizedFrame: normalizedFrame,
      viewportFrame: viewportFrame,
      frameSource: frameSource,
      parent: parent,
      children: children,
      attributes: attributes,
      actions: actions,
      axElement: axElement,
    )
    return elementCopy
  }
  
  /// Get an array of state strings describing the current state of this element
  /// Only includes exceptional states to reduce verbosity (disabled, hidden, focused, selected)
  /// - Returns: Array of exceptional state strings
  public func getStateArray() -> [String] {
    var states: [String] = []
    
    // Only include exceptional states (not normal/default states)
    // Don't show: enabled, visible, unfocused, unselected
    if !isEnabled {
      states.append("disabled")
    }
    
    if !isVisible {
      states.append("hidden")
    }
    
    if isFocused {
      states.append("focused")
    }
    
    if isSelected {
      states.append("selected")
    }
    
    // Add other state mappings based on attributes
    if let expanded = attributes["expanded"] as? Bool {
      states.append(expanded ? "expanded" : "collapsed")
    }
    
    if let readonly = attributes["readonly"] as? Bool {
      states.append(readonly ? "readonly" : "editable")
    }
    
    if let required = attributes["required"] as? Bool {
      states.append(required ? "required" : "optional")
    }
    
    return states
  }
  
  /// Get an array of capability strings describing the element's interaction capabilities
  /// - Returns: Array of capability strings (e.g., "clickable", "editable", "scrollable", etc.)
  public func getCapabilitiesArray() -> [String] {
    var capabilities: [String] = []
    
    // Add capability based on element properties
    if isClickable {
      capabilities.append("clickable")
    }
    
    if isEditable {
      capabilities.append("editable")
    }
    
    if isToggleable {
      capabilities.append("toggleable")
    }
    
    if isSelectable {
      capabilities.append("selectable")
    }
    
    if isAdjustable {
      capabilities.append("adjustable")
    }
    
    // Add additional capabilities based on role and actions
    if role == "AXScrollArea" || actions.contains(AXAttribute.Action.scrollToVisible) {
      capabilities.append("scrollable")
    }
    
    if !children.isEmpty {
      capabilities.append("hasChildren")
    }
    
    if actions.contains(AXAttribute.Action.showMenu) {
      capabilities.append("hasMenu")
    }
    
    if attributes["help"] != nil || attributes["helpText"] != nil {
      capabilities.append("hasHelp")
    }
    
    if attributes["tooltip"] != nil || attributes["toolTip"] != nil {
      capabilities.append("hasTooltip")
    }
    
    if role == AXAttribute.Role.link {
      capabilities.append("navigable")
    }
    
    if attributes["focusable"] as? Bool == true {
      capabilities.append("focusable")
    }
    
    return capabilities
  }
  
  /// Get a filtered and cleaned dictionary of attributes
  /// - Returns: Dictionary of string attributes with all values converted to strings
  public func getFilteredAttributes() -> [String: String] {
    var result: [String: String] = [:]
    for (key, value) in attributes {
      result[key] = String(describing: value)
    }
    return result
  }
  
  /// Filter criteria for searching UI elements
  public struct FilterCriteria {
    /// Filter by accessibility role (exact match)
    public let role: String?
    
    /// Filter by title (exact match)
    public let title: String?
    
    /// Filter by title containing this text (case-insensitive)
    public let titleContains: String?
    
    /// Filter by value (exact match)
    public let value: String?
    
    /// Filter by value containing this text (case-insensitive)
    public let valueContains: String?
    
    /// Filter by description (exact match)
    public let description: String?
    
    /// Filter by description containing this text (case-insensitive)
    public let descriptionContains: String?
    
    /// Filter by text containing this string in any text field (title, description, value, identifier)
    public let textContains: String?
    
    /// Filter for elements that can be acted upon (clickable, editable, etc.)
    public let isInteractable: Bool?
    
    /// Filter by enabled state
    public let isEnabled: Bool?
    
    /// Filter for elements in menu system
    public let inMenus: Bool?
    
    /// Filter for elements in main content area (not menus)
    public let inMainContent: Bool?
    
    /// Filter by element types (matches elements with these roles)
    public let elementTypes: [String]
    
    /// Whether to include hidden elements in results
    public let includeHidden: Bool
    
    /// Initialize filter criteria
    /// - Parameters:
    ///   - role: Filter by role (exact match)
    ///   - title: Filter by title (exact match)
    ///   - titleContains: Filter by title containing text
    ///   - value: Filter by value (exact match)
    ///   - valueContains: Filter by value containing text
    ///   - description: Filter by description (exact match)
    ///   - descriptionContains: Filter by description containing text
    ///   - textContains: Filter by text containing this string in any text field
    ///   - isInteractable: Filter for elements that can be acted upon
    ///   - isEnabled: Filter by enabled state
    ///   - inMenus: Filter for elements in menu system
    ///   - inMainContent: Filter for elements in main content area
    ///   - elementTypes: Filter by element types
    ///   - includeHidden: Whether to include hidden elements
    public init(
      role: String? = nil,
      title: String? = nil,
      titleContains: String? = nil,
      value: String? = nil,
      valueContains: String? = nil,
      description: String? = nil,
      descriptionContains: String? = nil,
      textContains: String? = nil,
      isInteractable: Bool? = nil,
      isEnabled: Bool? = nil,
      inMenus: Bool? = nil,
      inMainContent: Bool? = nil,
      elementTypes: [String] = ["any"],
      includeHidden: Bool = true
    ) {
      self.role = role
      self.title = title
      self.titleContains = titleContains
      self.value = value
      self.valueContains = valueContains
      self.description = description
      self.descriptionContains = descriptionContains
      self.textContains = textContains
      self.isInteractable = isInteractable
      self.isEnabled = isEnabled
      self.inMenus = inMenus
      self.inMainContent = inMainContent
      self.elementTypes = elementTypes
      self.includeHidden = includeHidden
    }
  }
  
  /// Check if this element matches the specified filter criteria
  /// - Parameter criteria: The filter criteria to check against
  /// - Returns: True if the element matches all criteria, false otherwise
  public func matchesFilter(criteria: FilterCriteria) -> Bool {
    // Skip AXMenuBar elements by default (unless specifically searching for them)
    if role == "AXMenuBar" && criteria.role != "AXMenuBar" {
      return false
    }
    
    // Define type-to-role mappings
    let typeToRoles: [String: [String]] = [
      "button": [AXAttribute.Role.button, "AXButtonSubstitute", "AXButtton"],
      "checkbox": [AXAttribute.Role.checkbox],
      "radio": [AXAttribute.Role.radioButton, "AXRadioGroup"],
      "textfield": [AXAttribute.Role.textField, AXAttribute.Role.textArea, "AXSecureTextField"],
      "dropdown": [AXAttribute.Role.popUpButton, "AXComboBox", "AXPopover"],
      "slider": ["AXSlider", "AXScrollBar"],
      "link": [AXAttribute.Role.link],
      "tab": ["AXTabGroup", "AXTab", "AXTabButton"],
      "any": [],  // Special case - matches all
    ]
    
    // Collect all roles to match based on elementTypes
    var targetRoles = Set<String>()
    
    if criteria.elementTypes.contains("any") {
      // If "any" is selected, we don't filter by role
      targetRoles = [] // Empty set means no filtering
    } else {
      // Otherwise, include roles for the specified types
      for type in criteria.elementTypes {
        if let roles = typeToRoles[type] {
          targetRoles.formUnion(roles)
        }
      }
    }
    
    // Role filter - use contains match to handle roles like "AXTextArea First Text View"
    let roleMatches = criteria.role == nil || role.contains(criteria.role!)
    
    // Element type filter
    let typeMatches = targetRoles.isEmpty || targetRoles.contains(role)
    
    // Title filter
    let titleMatches = 
      (criteria.title == nil || title == criteria.title) &&
      (criteria.titleContains == nil || (title?.localizedCaseInsensitiveContains(criteria.titleContains!) ?? false))
    
    // Value filter
    let valueMatches = 
      (criteria.value == nil || value == criteria.value) &&
      (criteria.valueContains == nil || (value?.localizedCaseInsensitiveContains(criteria.valueContains!) ?? false))
    
    // Description filter
    let descriptionMatches = 
      (criteria.description == nil || elementDescription == criteria.description) &&
      (criteria.descriptionContains == nil || (elementDescription?.localizedCaseInsensitiveContains(criteria.descriptionContains!) ?? false))
    
    // Universal text search filter
    let textContainsMatches: Bool
    if let searchText = criteria.textContains {
      
      textContainsMatches = 
        (title?.localizedCaseInsensitiveContains(searchText) == true) ||
        (elementDescription?.localizedCaseInsensitiveContains(searchText) == true) ||
        (value?.localizedCaseInsensitiveContains(searchText) == true) ||
        (identifier?.localizedCaseInsensitiveContains(searchText) == true) ||
        (role.localizedCaseInsensitiveContains(searchText) == true)
      
    } else {
      textContainsMatches = true
    }
    
    // Interactable filter
    let interactableMatches: Bool
    if let shouldBeInteractable = criteria.isInteractable {
      let elementIsInteractable = isClickable || isEditable || isToggleable || isSelectable || isAdjustable
      interactableMatches = elementIsInteractable == shouldBeInteractable
    } else {
      interactableMatches = true
    }
    
    // Enabled state filter
    let enabledMatches: Bool
    if let shouldBeEnabled = criteria.isEnabled {
      enabledMatches = isEnabled == shouldBeEnabled
    } else {
      enabledMatches = true
    }
    
    // Location context filter (menu vs main content)
    let locationMatches: Bool
    if let shouldBeInMenus = criteria.inMenus {
      let elementIsInMenus = isInMenuContext()
      locationMatches = elementIsInMenus == shouldBeInMenus
    } else if let shouldBeInMainContent = criteria.inMainContent {
      let elementIsInMenus = isInMenuContext()
      locationMatches = (!elementIsInMenus) == shouldBeInMainContent
    } else {
      locationMatches = true
    }
    
    // Visibility filter
    let visibilityMatches = criteria.includeHidden || isVisible
    
    // Element matches if it passes all applicable filters
    let finalResult = roleMatches && typeMatches && titleMatches && valueMatches && descriptionMatches && 
           textContainsMatches && interactableMatches && enabledMatches && locationMatches && visibilityMatches
    
    
    return finalResult
  }
  
  /// Static method to filter a collection of elements by criteria
  /// - Parameters:
  ///   - elements: The elements to filter
  ///   - criteria: The filter criteria
  ///   - limit: Maximum number of elements to return (default 100)
  /// - Returns: Filtered elements (up to the limit)
  public static func filterElements(
    elements: [UIElement],
    criteria: FilterCriteria,
    limit: Int = 100
  ) -> [UIElement] {
    var results: [UIElement] = []
    
    // Process each element
    for element in elements {
      // Skip if we've reached the limit
      if results.count >= limit {
        break
      }
      
      // Check if element matches criteria
      if element.matchesFilter(criteria: criteria) {
        results.append(element)
      }
    }
    return results
  }
  
  /// Find matching descendants in this element's hierarchy
  /// - Parameters:
  ///   - criteria: The filter criteria
  ///   - maxDepth: Maximum depth to search
  ///   - limit: Maximum number of elements to return
  /// - Returns: Matching descendant elements (up to the limit)
  public func findMatchingDescendants(
    criteria: FilterCriteria,
    maxDepth: Int,
    limit: Int = 100
  ) -> [UIElement] {
    var results: [UIElement] = []
    
    // Recursive function to search for matching elements
    func findElements(in element: UIElement, depth: Int = 0) {
      // Stop if we've reached the limit
      if results.count >= limit {
        return
      }
      
      // Check if this element matches
      if element.matchesFilter(criteria: criteria) {
        // We've already properly set up the parent relationship in constructor
        // No need to do it again, but we should validate
        if element.parent == nil, depth > 0 {
          // If a non-root element is missing its parent, this is unusual
          // but we'll still include the element
        }
        
        results.append(element)
      }
      
      // Stop recursion if we're at max depth
      if depth >= maxDepth {
        return
      }
      
      // Process children
      for child in element.children {
        // Ensure the parent relationship is set
        if child.parent == nil {
          child.parent = element
        }
        
        findElements(in: child, depth: depth + 1)
      }
    }
    
    // Start the search from this element
    findElements(in: self)
    
    return results
  }

  // MARK: - Hierarchy Analysis Methods

  /// Computed property to check if this element is interactable
  public var isInteractable: Bool {
    return isClickable || isEditable || isToggleable || isSelectable || isAdjustable
  }

  /// Check if this element has any interactable descendants
  public func hasInteractableDescendants() -> Bool {
    return hasDescendantsMatching { $0.isInteractable }
  }

  /// Check if this element has any descendants that match the given predicate
  public func hasDescendantsMatching(_ predicate: (UIElement) -> Bool) -> Bool {
    // Check direct children first
    for child in children {
      if predicate(child) {
        return true
      }
      // Recursively check grandchildren
      if child.hasDescendantsMatching(predicate) {
        return true
      }
    }
    return false
  }

  /// Get the flattened child for chain skipping.
  /// If this element has exactly one child and that child is non-interactable,
  /// recursively skip to find the first meaningful level.
  /// Returns nil if no meaningful level is found.
  public func getFlattenedChild() -> UIElement? {
    guard children.count == 1 else {
      return nil // Only flatten single-child chains
    }
    
    let onlyChild = children[0]
    
    // If the child is interactable, don't skip it
    if onlyChild.isInteractable {
      return nil
    }
    
    // If the child has multiple children, stop here and use the child
    if onlyChild.children.count != 1 {
      return onlyChild
    }
    
    // Recursively check if we can skip further
    if let grandchild = onlyChild.getFlattenedChild() {
      return grandchild
    } else {
      return onlyChild
    }
  }

  /// Compare two path strings to determine if they refer to the same UI element
  /// - Parameters:
  ///   - path1: The first path string
  ///   - path2: The second path string
  ///   - accessibilityService: The AccessibilityService to use for resolution
  /// - Returns: True if both paths resolve to the same element, false otherwise
  /// - Throws: ElementPathError if either path cannot be resolved
  public static func areSameElement(
    path1: String,
    path2: String,
    accessibilityService: AccessibilityServiceProtocol,
  ) async throws -> Bool {
    // Parse the path strings
    let elementPath1 = try ElementPath.parse(path1)
    let elementPath2 = try ElementPath.parse(path2)

    return try await areSameElement(
      elementPath1: elementPath1,
      elementPath2: elementPath2,
      accessibilityService: accessibilityService,
    )
  }

  /// Compare two ElementPaths to determine if they refer to the same UI element
  /// - Parameters:
  ///   - elementPath1: The first ElementPath
  ///   - elementPath2: The second ElementPath
  ///   - accessibilityService: The AccessibilityService to use for resolution
  /// - Returns: True if both paths resolve to the same element, false otherwise
  /// - Throws: ElementPathError if either path cannot be resolved
  public static func areSameElement(
    elementPath1: ElementPath,
    elementPath2: ElementPath,
    accessibilityService: AccessibilityServiceProtocol,
  ) async throws -> Bool {
    // Resolve both paths
    let element1 = try await elementPath1.resolve(using: accessibilityService)
    let element2 = try await elementPath2.resolve(using: accessibilityService)

    // Compare the raw AXUIElements for equality
    // Note: This comparison is implementation-defined and may not be reliable across all macOS versions
    // It relies on the system's notion of element equality
    return CFEqual(element1, element2)
  }

  /// Check if this element is in a menu context (part of the menu system)
  /// - Returns: True if element is part of menu hierarchy, false otherwise
  public func isInMenuContext() -> Bool {
    // Check if this element or any of its ancestors is menu-related
    var currentElement: UIElement? = self
    
    while let element = currentElement {
      // Check if the current element is menu-related
      if element.role.contains("Menu") || 
         element.role == "AXMenuBar" || 
         element.role == "AXMenuItem" ||
         element.role == "AXMenuButton" ||
         element.role == "AXMenuBarItem" {
        return true
      }
      
      // Move up the hierarchy
      currentElement = element.parent
    }
    
    return false
  }

  /// Generate a path-based identifier for this element
  /// - Parameters:
  ///   - includeValue: Whether to include the value attribute (default false since values can change)
  ///   - includeFrame: Whether to include frame information (default false)
  /// - Returns: A path string conforming to ElementPath syntax
  /// - Throws: ElementPathError if path generation fails
  public func generatePath(includeValue: Bool = false, includeFrame: Bool = false) throws -> String
  {
    // Start building the path with the current element
    var pathSegments: [PathSegment] = []

    // Build the path from current element to root (we'll reverse at the end)
    var currentElement: UIElement? = self

    // Convert the current element and its ancestors to path segments
    while let element = currentElement {
      // Create a segment for this element
      var attributes: [String: String] = [:]

      // Ensure role has AX prefix - this is critical for consistent resolution
      let normalizedRole = element.role.hasPrefix("AX") ? element.role : "AX\(element.role)"

      // For generic containers like AXGroup, add position-based matching if there are no other identifying
      // attributes
      let isGenericContainer =
        (normalizedRole == "AXGroup" || normalizedRole == "AXBox" || normalizedRole == "AXGeneric")

      // Add useful identifying attributes - title, description, and identifier are most stable
      // For AXApplication elements, skip title to keep paths clean (bundleId will be added during resolution)
      if let title = element.title, !title.isEmpty {
        if normalizedRole != "AXApplication" {
          attributes["AXTitle"] = PathNormalizer.escapeAttributeValue(title)
        }
      }

      if let desc = element.elementDescription, !desc.isEmpty {
        attributes["AXDescription"] = PathNormalizer.escapeAttributeValue(desc)
      }

      // Include the value if requested and available
      if includeValue, let value = element.value, !value.isEmpty {
        attributes["AXValue"] = PathNormalizer.escapeAttributeValue(value)
      }

      // Add custom identifier if available (check all common identifier attribute formats)
      // Try multiple attribute variations to catch all possible identifier formats
      let identifierKeys = ["AXIdentifier", "identifier", "Identifier"]
      
      for key in identifierKeys {
          if let identifier = element.attributes[key] as? String, !identifier.isEmpty {
              // Always consistently use "AXIdentifier" in the final path
              attributes["AXIdentifier"] = identifier
              // Diagnostic logging
              break  // Stop after finding the first valid identifier
          }
      }
      

      // For generic containers with no identifying attributes, consider adding index for disambiguation
      if isGenericContainer, attributes.isEmpty, element.parent != nil {
        // Find position of this element among siblings with the same role
        if let parent = element.parent {
          let sameRoleSiblings = parent.children.filter { $0.role == element.role }
          if let index = sameRoleSiblings.firstIndex(where: { $0.path == element.path }) {
            // Only add index if there are multiple siblings with the same role
            if sameRoleSiblings.count > 1 {
              let indexedSegment = PathSegment(
                role: normalizedRole, attributes: attributes, index: index)
              pathSegments.append(indexedSegment)
              // Move to parent
              currentElement = element.parent
              continue  // Skip the rest of this iteration to avoid adding duplicate segment
            }
          }
        }
      }

      // Include frame information if requested
      if includeFrame {
        // Frame attributes don't use AX prefix
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

      // Create the path segment with normalized role
      let segment = PathSegment(role: normalizedRole, attributes: attributes)
      pathSegments.append(segment)

      // Move to parent
      currentElement = element.parent
    }

    // Reverse the segments to get root-to-leaf order
    pathSegments.reverse()

    // Create the ElementPath
    let elementPath = try ElementPath(segments: pathSegments)

    // Use the complete path with all segments
    return elementPath.toString()
  }
}
