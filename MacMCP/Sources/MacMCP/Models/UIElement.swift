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

    // Check for enabled state
    var enabledRef: CFTypeRef?
    let enabledStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.enabled as CFString, &enabledRef)
    if enabledStatus == .success, let enabledValue = enabledRef as? Bool {
      attributes["enabled"] = enabledValue
    }

    // Check for focused state
    var focusedRef: CFTypeRef?
    let focusedStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.focused as CFString, &focusedRef)
    if focusedStatus == .success, let focusedValue = focusedRef as? Bool {
      attributes["focused"] = focusedValue
    }

    // Check for selected state
    var selectedRef: CFTypeRef?
    let selectedStatus = AXUIElementCopyAttributeValue(
      axElement, AXAttribute.selected as CFString, &selectedRef)
    if selectedStatus == .success, let selectedValue = selectedRef as? Bool {
      attributes["selected"] = selectedValue
    }

    // Generate the path string
    pathString = elementPath.toString()

    // Initialize the UIElement instance
    self.init(
      path: pathString,
      role: role,
      title: title,
      value: value,
      elementDescription: elementDescription,
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

      // Add custom identifier if available (check all common identifier attribute formats)
      // Try multiple attribute variations to catch all possible identifier formats
      let identifierKeys = ["AXIdentifier", "identifier", "Identifier"]
      var foundIdentifier = false
      
      for key in identifierKeys {
          if let identifier = element.attributes[key] as? String, !identifier.isEmpty {
              // Always consistently use "AXIdentifier" in the final path
              attributes["AXIdentifier"] = identifier
              // Diagnostic logging
              foundIdentifier = true
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

      // For applications, ALWAYS prioritize bundle identifier
      if normalizedRole == "AXApplication" {
        if let bundleId = element.attributes["bundleIdentifier"] as? String, !bundleId.isEmpty {
          // bundleIdentifier is a special case - don't add AX prefix
          attributes["bundleIdentifier"] = bundleId

          // When we have a bundleIdentifier, remove the title attribute
          // to ensure consistent path generation that relies only on bundleIdentifier
          attributes.removeValue(forKey: "AXTitle")
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
