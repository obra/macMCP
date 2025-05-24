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
  
  /// Human-readable name of the element (derived from title or description)
  public let name: String
  
  /// The title or label of the element (if any)
  public let title: String?
  
  /// The current value of the element (if applicable)
  public let value: String?
  
  /// Human-readable description of the element
  public let description: String?
  
  /// Element position and size
  public let frame: ElementFrame
  
  /// Current state values as string array
  public let state: [String]
  
  /// Higher-level interaction capabilities
  public let capabilities: [String]
  
  /// Available accessibility actions
  public let actions: [String]
  
  /// Additional element attributes
  public let attributes: [String: String]
  
  
  /// Children elements, if within maxDepth
  public let children: [EnhancedElementDescriptor]?
  
  /// Create a new element descriptor with enhanced state and capability information
  /// - Parameters:
  ///   - id: Unique identifier
  ///   - role: Accessibility role
  ///   - name: Human-readable name
  ///   - title: Title or label (optional)
  ///   - value: Current value (optional)
  ///   - description: Human-readable description (optional)
  ///   - frame: Element position and size
  ///   - state: Current state values as strings
  ///   - capabilities: Interaction capabilities
  ///   - actions: Available actions
  ///   - attributes: Additional attributes
  ///   - children: Child elements (optional)
  public init(
    id: String,
    role: String,
    name: String,
    title: String? = nil,
    value: String? = nil,
    description: String? = nil,
    frame: ElementFrame,
    state: [String],
    capabilities: [String],
    actions: [String],
    attributes: [String: String] = [:],
    children: [EnhancedElementDescriptor]? = nil
  ) {
    self.id = id
    self.role = role
    self.name = name
    self.title = title
    self.value = value
    self.description = description
    self.frame = frame
    self.state = state
    self.capabilities = capabilities
    self.actions = actions
    self.attributes = attributes
    self.children = children
  }

  /// Convert a UIElement to an EnhancedElementDescriptor with detailed state and capability information
  /// - Parameters:
  ///   - element: The UIElement to convert
  ///   - maxDepth: Maximum depth of the hierarchy to traverse
  ///   - currentDepth: Current depth in the hierarchy
  /// - Returns: An EnhancedElementDescriptor
  public static func from(
    element: UIElement,
    maxDepth: Int = 10,
    currentDepth: Int = 0
  ) -> EnhancedElementDescriptor {
    // Generate a human-readable name
    let name: String =
      if let title = element.title, !title.isEmpty {
        title
      } else if let desc = element.elementDescription, !desc.isEmpty {
        desc
      } else if let val = element.value, !val.isEmpty {
        "\(element.role) with value \(val)"
      } else {
        element.role
      }

    // Create the frame
    let frame = ElementFrame(
      x: element.frame.origin.x,
      y: element.frame.origin.y,
      width: element.frame.size.width,
      height: element.frame.size.height,
    )

    // Get element state using the new UIElement method
    let state = element.getStateArray()

    // Get element capabilities using the new UIElement method
    let capabilities = element.getCapabilitiesArray()

    // Get filtered attributes using the new UIElement method
    let filteredAttributes = element.getFilteredAttributes()

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
        from(element: $0, maxDepth: maxDepth, currentDepth: currentDepth + 1)
      }
    } else {
      children = nil
    }

    // Ensure the full path is always used for both id and path fields
    let finalPath = path ?? (try? element.generatePath()) ?? element.path

    return EnhancedElementDescriptor(
      id: finalPath,  // Always use fully qualified path for id
      role: element.role,
      name: name,
      title: element.title,
      value: element.value,
      description: element.elementDescription,
      frame: frame,
      state: state,
      capabilities: capabilities,
      actions: element.actions,
      attributes: filteredAttributes,
      children: children
    )
  }
  
  /// Custom encoding to output opaque IDs instead of raw element paths
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    // Encode id as opaque ID to eliminate escaping issues
    let opaqueID = try OpaqueIDEncoder.encode(id)
    try container.encode(opaqueID, forKey: .id)
    
    // Encode all other fields normally
    try container.encode(role, forKey: .role)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(title, forKey: .title)
    try container.encodeIfPresent(value, forKey: .value)
    try container.encodeIfPresent(description, forKey: .description)
    try container.encode(frame, forKey: .frame)
    try container.encode(state, forKey: .state)
    try container.encode(capabilities, forKey: .capabilities)
    try container.encode(actions, forKey: .actions)
    try container.encode(attributes, forKey: .attributes)
    try container.encodeIfPresent(children, forKey: .children)
  }
  
  /// Coding keys for custom Codable implementation
  private enum CodingKeys: String, CodingKey {
    case id, role, name, title, value, description, frame
    case state, capabilities, actions, attributes, children
  }
}