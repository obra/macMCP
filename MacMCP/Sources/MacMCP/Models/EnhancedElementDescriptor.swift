// ABOUTME: EnhancedElementDescriptor.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import CoreGraphics
import Foundation
import Logging
import MCP

// Logger for EnhancedElementDescriptor
private let elementDescriptorLogger = Logger(label: "mcp.models.enhanced_element_descriptor")

/// A descriptor for UI elements with enhanced information about states and capabilities
public struct EnhancedElementDescriptor: Codable, Sendable, Identifiable {
  /// Unique identifier for the element
  public let id: String
  /// The accessibility role of the element
  public let role: String
  /// The title or label of the element (if any)
  public let title: String?
  /// The current value of the element (if applicable)
  public let value: String?
  /// Human-readable description of the element
  public let description: String?
  /// Help text for the element (if available)
  public let help: String?
  /// Unique identifier for the element (if available)
  public let identifier: String?
  /// Element position and size
  public let frame: ElementFrame
  /// Combined element properties including state and capabilities
  public let props: [String]
  /// Available accessibility actions
  public let actions: [String]
  /// Additional element attributes
  public let attributes: [String: String]
  /// Children elements, if within maxDepth
  public let children: [EnhancedElementDescriptor]?
  /// Whether to include coordinate information in output
  private let showCoordinates: Bool
  /// Create a new element descriptor with enhanced state and capability information
  /// - Parameters:
  ///   - id: Unique identifier
  ///   - role: Accessibility role
  ///   - title: Title or label (optional)
  ///   - value: Current value (optional)
  ///   - description: Human-readable description (optional)
  ///   - help: Help text (optional)
  ///   - identifier: Element identifier (optional)
  ///   - frame: Element position and size
  ///   - props: Combined properties (state and capabilities)
  ///   - actions: Available actions
  ///   - attributes: Additional attributes
  ///   - children: Child elements (optional)
  ///   - showCoordinates: Whether to include coordinate information in output
  public init(
    id: String,
    role: String,
    title: String? = nil,
    value: String? = nil,
    description: String? = nil,
    help: String? = nil,
    identifier: String? = nil,
    frame: ElementFrame,
    props: [String],
    actions: [String],
    attributes: [String: String] = [:],
    children: [EnhancedElementDescriptor]? = nil,
    showCoordinates: Bool = false
  ) {
    self.id = id
    self.role = role
    self.title = title
    self.value = value
    self.description = description
    self.help = help
    self.identifier = identifier
    self.frame = frame
    self.props = props
    self.actions = actions
    self.attributes = attributes
    self.children = children
    self.showCoordinates = showCoordinates
  }

  /// Convert a UIElement to an EnhancedElementDescriptor with detailed state and capability
  /// information
  /// - Parameters:
  ///   - element: The UIElement to convert
  ///   - maxDepth: Maximum depth of the hierarchy to traverse
  ///   - currentDepth: Current depth in the hierarchy
  ///   - showCoordinates: Whether to include coordinate information in the output
  /// - Returns: An EnhancedElementDescriptor
  public static func from(
    element: UIElement,
    maxDepth: Int = 10,
    currentDepth: Int = 0,
    showCoordinates: Bool = false,
  ) -> EnhancedElementDescriptor {
    // Create the frame
    let frame = ElementFrame(
      x: element.frame.origin.x,
      y: element.frame.origin.y,
      width: element.frame.size.width,
      height: element.frame.size.height,
    )

    // Get element state and capabilities
    let state = element.getStateArray()
    let capabilities = element.getCapabilitiesArray()
    // Combine state and capabilities into props array
    var props: [String] = []
    props.append(contentsOf: state)
    props.append(contentsOf: capabilities)

    // Get filtered attributes using the new UIElement method
    let filteredAttributes = element.getFilteredAttributes()
    // Extract help from attributes and get identifier from the dedicated property
    let help = element.attributes[AXAttribute.help] as? String
    let identifier = element.identifier

    // Always generate the fully qualified path
    var path: String?

    // First check if the element already has a path set
    path = element.path
    elementDescriptorLogger.debug(
      "Using path on element", metadata: ["path": .string(path ?? "<nil>")],
    )

    // Always generate a more detailed path if the current one isn't fully qualified
    if path == nil ||
      !(path?.contains("/") ?? false)
    { // Generate full path if missing or incomplete
      // No pre-existing path, so we need to generate one
      do {
        // Generate a fully qualified path
        path = try element.generatePath()
        // Store the path on the element itself so that child elements can access it
        if let unwrappedPath = path { element.path = unwrappedPath }
      } catch {
        // If path generation fails, we'll still return the descriptor without a path
        path = nil
      }
    }

    // Handle children if we haven't reached maximum depth
    let children: [EnhancedElementDescriptor]?
    if currentDepth < maxDepth, !element.children.isEmpty {
      // Make sure each child has a proper parent reference before processing
      for child in element.children {
        // Ensure parent relationship is set properly
        child.parent = element
      }

      // Recursively convert children with incremented depth
      children = element.children.map {
        from(
          element: $0, maxDepth: maxDepth, currentDepth: currentDepth + 1,
          showCoordinates: showCoordinates,
        )
      }
    } else {
      children = nil
    }

    // Ensure the full path is always used for both id and path fields
    let finalPath = path ?? (try? element.generatePath()) ?? element.path

    return EnhancedElementDescriptor(
      id: finalPath, // Always use fully qualified path for id
      role: element.role,
      title: element.title,
      value: element.value,
      description: element.elementDescription,
      help: help,
      identifier: identifier,
      frame: frame,
      props: props,
      actions: element.actions,
      attributes: filteredAttributes,
      children: children,
      showCoordinates: showCoordinates,
    )
  }

  /// Convert to dictionary representation for JSON serialization
  public func toDictionary() throws -> [String: Any] {
    var result: [String: Any] = [:]

    // Encode id as opaque ID to eliminate escaping issues
    let opaqueID = try OpaqueIDEncoder.encode(id)
    result["id"] = opaqueID

    // Encode pure role for filtering
    result["role"] = role

    // Create el field with descriptive parts (without duplicating role): "{{identifier?
    // identifier." "}}{{ title ? title. " "}}{{ description ? description}}"
    var elParts: [String] = []
    if let identifier, !identifier.isEmpty { elParts.append("\(identifier).") }
    if let title, !title.isEmpty { elParts.append("\(title).") }
    if let description, !description.isEmpty { elParts.append(description) }
    if !elParts.isEmpty {
      var elValue = elParts.joined(separator: " ")
      // Remove trailing "." if we only had identifier/title but no description
      if elValue.hasSuffix("."), description?.isEmpty != false {
        elValue = String(elValue.dropLast(1))
      }
      result["el"] = elValue
    }

    // Include value if present
    if let value, !value.isEmpty { result["value"] = value }

    // Include help if present
    if let help, !help.isEmpty { result["help"] = help }

    // Only include frame/coordinates if requested
    if showCoordinates { result["frame"] = frame }

    // Convert props array to comma-separated string
    if !props.isEmpty {
      let propsString = props.joined(separator: ", ")
      result["props"] = propsString
    }

    // Convert actions array to comma-separated string (always show, strip AX prefix)
    if !actions.isEmpty {
      let cleanedActions = actions.map { action in
        action.hasPrefix("AX") ? String(action.dropFirst(2)) : action
      }
      let actionsString = cleanedActions.joined(separator: ", ")
      result["actions"] = actionsString
    }

    // Convert attributes dictionary to comma-separated string
    if !attributes.isEmpty {
      let attributesString = attributes.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      result["attributes"] = attributesString
    }

    if let children = children, !children.isEmpty {
      result["children"] = try children.map { try $0.toDictionary() }
    }

    return result
  }

  /// Custom encoding to output compact format with coalesced fields
  public func encode(to encoder: Encoder) throws {
    let dictionary = try toDictionary()
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Map dictionary keys to coding keys
    let keyMappings: [(String, CodingKeys, Any.Type)] = [
      ("id", .id, String.self),
      ("role", .role, String.self),
      ("el", .element, String.self),
      ("value", .value, String.self),
      ("help", .help, String.self),
      ("frame", .frame, ElementFrame.self),
      ("props", .props, String.self),
      ("actions", .actions, String.self),
      ("attributes", .attributes, String.self),
    ]

    // Encode each field if present
    for (dictKey, codingKey, type) in keyMappings {
      if let value = dictionary[dictKey] {
        if type == String.self, let stringValue = value as? String {
          try container.encode(stringValue, forKey: codingKey)
        } else if type == ElementFrame.self, let frameValue = value as? ElementFrame {
          try container.encode(frameValue, forKey: codingKey)
        }
      }
    }
    
    // Handle children separately since they need special encoding
    if let children = children, !children.isEmpty {
      try container.encode(children, forKey: .children)
    }
  }

  /// Simple decode implementation for tests (only handles fields we actually encode)
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    role = try container.decode(String.self, forKey: .role)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    value = try container.decodeIfPresent(String.self, forKey: .value)
    description = try container.decodeIfPresent(String.self, forKey: .description)
    help = try container.decodeIfPresent(String.self, forKey: .help)
    identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
    frame =
      try container.decodeIfPresent(ElementFrame.self, forKey: .frame)
        ?? ElementFrame(x: 0, y: 0, width: 0, height: 0)
    // Handle props as comma-separated string (new format only)
    if let propsString = try? container.decode(String.self, forKey: .props) {
      props = propsString.components(separatedBy: ", ").map {
        $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      }
    } else {
      props = []
    }
    // Handle actions as comma-separated string (new format only)
    if let actionsString = try? container.decode(String.self, forKey: .actions) {
      // Add back AX prefix when decoding
      let rawActions = actionsString.components(separatedBy: ", ").map {
        $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      }
      actions = rawActions.map { action in action.hasPrefix("AX") ? action : "AX\(action)" }
    } else {
      actions = []
    }
    // Handle attributes as comma-separated string (new format only)
    if let attributesString = try? container.decode(String.self, forKey: .attributes) {
      var attributesDict: [String: String] = [:]
      let pairs = attributesString.components(separatedBy: ", ")
      for pair in pairs {
        let components = pair.components(separatedBy: "=")
        if components.count == 2 {
          let key = components[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          let value = components[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          attributesDict[key] = value
        }
      }
      attributes = attributesDict
    } else {
      attributes = [:]
    }
    children = try container.decodeIfPresent(
      [EnhancedElementDescriptor].self, forKey: .children,
    )
    // These are not encoded/decoded
    showCoordinates = false
  }

  /// Coding keys for custom Codable implementation
  private enum CodingKeys: String, CodingKey {
    case id, role, title, value, description, help, identifier, frame
    case props, actions, attributes, children
    case element = "el"
  }
}
