// ABOUTME: EnhancedElementDescriptor.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import CoreGraphics

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
  
  /// Whether to include actions information in output
  private let showActions: Bool
  
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
    showCoordinates: Bool = false,
    showActions: Bool = false
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
    self.showActions = showActions
  }

  /// Convert a UIElement to an EnhancedElementDescriptor with detailed state and capability information
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
    showActions: Bool = false
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
      "Using path on element", metadata: ["path": .string(path ?? "<nil>")])

    // Always generate a more detailed path if the current one isn't fully qualified
    if path == nil || !path!.contains("/") {  // Generate full path if missing or incomplete
      // No pre-existing path, so we need to generate one
      do {
        // Generate a fully qualified path
        path = try element.generatePath()
        
        // Store the path on the element itself so that child elements can access it
        if let unwrappedPath = path {
          element.path = unwrappedPath
        }
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
        from(element: $0, maxDepth: maxDepth, currentDepth: currentDepth + 1, showCoordinates: showCoordinates, showActions: showActions)
      }
    } else {
      children = nil
    }

    // Ensure the full path is always used for both id and path fields
    let finalPath = path ?? (try? element.generatePath()) ?? element.path

    return EnhancedElementDescriptor(
      id: finalPath,  // Always use fully qualified path for id
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
      showActions: showActions
    )
  }
  
  /// Custom encoding to output compact format with coalesced fields
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    // Encode id as opaque ID to eliminate escaping issues
    let opaqueID = try OpaqueIDEncoder.encode(id)
    try container.encode(opaqueID, forKey: .id)
    
    // Create coalesced role field: role: "{{role}} {{identifier? identifier." "}}{{ title ? title. " "}}{{ description ? description}}"
    var roleValue = role  // Start with the actual role
    if let identifier = identifier, !identifier.isEmpty {
      roleValue += " \(identifier)."
    }
    if let title = title, !title.isEmpty {
      roleValue += " \(title)."
    }
    if let description = description, !description.isEmpty {
      roleValue += " \(description)"
    }
    // Remove trailing "." if we only had identifier/title but no description
    if roleValue.hasSuffix(".") && description?.isEmpty != false {
      roleValue = String(roleValue.dropLast(1))
    }
    try container.encode(roleValue, forKey: .role)
    
    // Include value if present
    if let value = value, !value.isEmpty {
      try container.encode(value, forKey: .value)
    }
    
    // Include help if present
    if let help = help, !help.isEmpty {
      try container.encode(help, forKey: .help)
    }
    
    // Only include frame/coordinates if requested
    if showCoordinates {
      try container.encode(frame, forKey: .frame)
    }
    
    // Convert props array to comma-separated string
    if !props.isEmpty {
      let propsString = props.joined(separator: ", ")
      try container.encode(propsString, forKey: .props)
    }
    
    // Convert actions array to comma-separated string if requested
    if showActions && !actions.isEmpty {
      let actionsString = actions.joined(separator: ", ")
      try container.encode(actionsString, forKey: .actions)
    }
    
    // Convert attributes dictionary to comma-separated string
    if !attributes.isEmpty {
      let attributesString = attributes.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      try container.encode(attributesString, forKey: .attributes)
    }
    
    if children?.isEmpty == false {
      try container.encodeIfPresent(children, forKey: .children)
    }
  }
  
  /// Custom decoding that handles both old and new compact format
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    self.id = try container.decode(String.self, forKey: .id)
    
    // The role field now contains coalesced information, extract just the role part
    let roleValue = try container.decode(String.self, forKey: .role)
    // For backward compatibility, if it's just a role (like "AXButton"), use as is
    // If it contains spaces, take the first part as the role
    let roleParts = roleValue.components(separatedBy: " ")
    self.role = roleParts.first ?? roleValue
    
    // For the new compact format, these fields are embedded in the role field
    // For backward compatibility, still try to decode them if present
    self.title = try container.decodeIfPresent(String.self, forKey: .title)
    self.value = try container.decodeIfPresent(String.self, forKey: .value)
    self.description = try container.decodeIfPresent(String.self, forKey: .description)
    self.help = try container.decodeIfPresent(String.self, forKey: .help)
    self.identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
    
    self.frame = try container.decodeIfPresent(ElementFrame.self, forKey: .frame) ?? ElementFrame(x: 0, y: 0, width: 0, height: 0)
    
    // Handle props - could be array (old format) or string (new format)
    if let propsArray = try? container.decode([String].self, forKey: .props) {
      self.props = propsArray
    } else if let propsString = try? container.decode(String.self, forKey: .props) {
      self.props = propsString.components(separatedBy: ", ").map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
    } else {
      self.props = []
    }
    
    // Handle actions - could be array (old format) or string (new format)
    if let actionsArray = try? container.decodeIfPresent([String].self, forKey: .actions) {
      self.actions = actionsArray
    } else if let actionsString = try? container.decodeIfPresent(String.self, forKey: .actions) {
      self.actions = actionsString.components(separatedBy: ", ").map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
    } else {
      self.actions = []
    }
    
    // Handle attributes - could be dictionary (old format) or string (new format)
    if let attributesDict = try? container.decodeIfPresent([String: String].self, forKey: .attributes) {
      self.attributes = attributesDict
    } else if let attributesString = try? container.decodeIfPresent(String.self, forKey: .attributes) {
      // Parse "key=value, key2=value2" format
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
      self.attributes = attributesDict
    } else {
      self.attributes = [:]
    }
    
    self.children = try container.decodeIfPresent([EnhancedElementDescriptor].self, forKey: .children)
    
    // showCoordinates and showActions are not encoded/decoded, default to false for decoded instances
    self.showCoordinates = false
    self.showActions = false
  }
  
  /// Coding keys for custom Codable implementation
  private enum CodingKeys: String, CodingKey {
    case id, role, title, value, description, help, identifier, frame
    case props, actions, attributes, children
  }
}