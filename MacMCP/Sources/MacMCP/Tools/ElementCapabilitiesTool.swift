// ABOUTME: This file defines a tool for getting detailed capabilities of UI elements.
// ABOUTME: It provides information about what actions can be performed on elements.

import Foundation
import MCP
import Logging

/// A tool for getting detailed capabilities of UI elements
public struct ElementCapabilitiesTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.elementCapabilities
    
    /// Description of the tool
    public let description = "Get detailed capabilities and properties of UI elements"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// Tool handler function that uses this instance's accessibility service
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
        return { [self] params in
            return try await self.processRequest(params)
        }
    }
    
    /// The logger
    private let logger: Logger
    
    /// Create a new element capabilities tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.element_capabilities")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Element Capabilities",
            readOnlyHint: true,
            openWorldHint: true
        )
        
        // Initialize inputSchema with an empty object first
        self.inputSchema = .object([:])
        
        // Now create the full input schema
        self.inputSchema = createInputSchema()
    }
    
    /// Create the input schema for the tool
    private func createInputSchema() -> Value {
        return .object([
            "type": .string("object"),
            "properties": .object([
                "elementId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the element to get capabilities for")
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application containing the element")
                ]),
                "includeChildren": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include children in the result"),
                    "default": .bool(false)
                ]),
                "childrenDepth": .object([
                    "type": .string("integer"),
                    "description": .string("Depth of children to include if includeChildren is true"),
                    "default": .int(1)
                ])
            ]),
            "required": .array([.string("elementId")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Process an element capabilities request
    /// - Parameter params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw MCPError.invalidParams("Parameters are required")
        }
        
        // Get the element ID
        guard let elementId = params["elementId"]?.stringValue else {
            throw MCPError.invalidParams("elementId is required")
        }
        
        // Get optional parameters
        let bundleId = params["bundleId"]?.stringValue
        let includeChildren = params["includeChildren"]?.boolValue ?? false
        let childrenDepth = params["childrenDepth"]?.intValue ?? 1
        
        // Find the element
        let element = try await findElement(id: elementId, bundleId: bundleId)
        
        // Create the capabilities descriptor
        let capabilities = try createCapabilitiesDescriptor(
            for: element,
            includeChildren: includeChildren,
            childrenDepth: childrenDepth
        )
        
        // Return the capabilities
        return try formatResponse(capabilities)
    }
    
    /// Find an element by ID
    /// - Parameters:
    ///   - id: The element ID
    ///   - bundleId: Optional bundle ID to narrow the search
    /// - Returns: The found element
    private func findElement(id: String, bundleId: String?) async throws -> UIElement {
        // Determine the search scope
        let scope: UIElementScope
        if let bundleId = bundleId {
            scope = .application(bundleIdentifier: bundleId)
        } else {
            scope = .systemWide
        }
        
        // Find elements matching the ID
        let elements = try await accessibilityService.findUIElements(
            role: nil,
            titleContains: nil,
            scope: scope,
            recursive: true,
            maxDepth: 25 // Deep search
        ).filter { $0.identifier == id }
        
        // Check if we found the element
        guard let element = elements.first else {
            if let bundleId = bundleId {
                throw MCPError.internalError("Element with ID \(id) not found in application \(bundleId)")
            } else {
                throw MCPError.internalError("Element with ID \(id) not found")
            }
        }
        
        return element
    }
    
    /// Create a capabilities descriptor for an element
    /// - Parameters:
    ///   - element: The element to describe
    ///   - includeChildren: Whether to include children
    ///   - childrenDepth: Depth of children to include
    /// - Returns: The capabilities descriptor
    private func createCapabilitiesDescriptor(
        for element: UIElement,
        includeChildren: Bool,
        childrenDepth: Int
    ) throws -> ElementCapabilitiesDescriptor {
        // Map common actions to capabilities
        var capabilities = Set<String>()
        
        // Add specific capabilities based on role and actions
        if element.role == AXAttribute.Role.button || element.actions.contains(AXAttribute.Action.press) {
            capabilities.insert("clickable")
        }
        
        if element.role == AXAttribute.Role.textField || element.role == AXAttribute.Role.textArea {
            capabilities.insert("editable")
        }
        
        if element.role == AXAttribute.Role.checkbox || element.role == AXAttribute.Role.radioButton {
            capabilities.insert("toggleable")
        }
        
        if element.role == AXAttribute.Role.popUpButton || element.role == "AXComboBox" {
            capabilities.insert("selectable")
        }
        
        if element.actions.contains(AXAttribute.Action.increment) || 
           element.actions.contains(AXAttribute.Action.decrement) {
            capabilities.insert("adjustable")
        }
        
        if element.role == AXAttribute.Role.link {
            capabilities.insert("navigable")
        }
        
        if element.actions.contains(AXAttribute.Action.showMenu) {
            capabilities.insert("hasMenu")
        }
        
        if !element.children.isEmpty {
            capabilities.insert("hasChildren")
        }
        
        if element.role == "AXScrollArea" || element.actions.contains(AXAttribute.Action.scrollToVisible) {
            capabilities.insert("scrollable")
        }
        
        // Process children if requested
        var children: [ElementCapabilitiesDescriptor]?
        if includeChildren && !element.children.isEmpty && childrenDepth > 0 {
            children = []
            for child in element.children {
                let childCapabilities = try createCapabilitiesDescriptor(
                    for: child,
                    includeChildren: childrenDepth > 1,
                    childrenDepth: childrenDepth - 1
                )
                children?.append(childCapabilities)
            }
        }
        
        // Convert element attributes to dictionary of strings
        var attributes: [String: String] = [:]
        for (key, value) in element.attributes {
            attributes[key] = String(describing: value)
        }
        
        return ElementCapabilitiesDescriptor(
            id: element.identifier,
            role: element.role,
            title: element.title,
            value: element.value,
            description: element.elementDescription,
            frame: ElementFrame(
                x: element.frame.origin.x,
                y: element.frame.origin.y,
                width: element.frame.size.width,
                height: element.frame.size.height
            ),
            capabilities: Array(capabilities).sorted(),
            actions: element.actions,
            attributes: attributes,
            children: children,
            childCount: element.children.count
        )
    }
    
    /// Format a response as JSON
    /// - Parameter data: The data to format
    /// - Returns: The formatted tool content
    private func formatResponse<T: Encodable>(_ data: T) throws -> [Tool.Content] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(data)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode response as JSON")
            }
            
            return [.text(jsonString)]
        } catch {
            logger.error("Error encoding response as JSON", metadata: [
                "error": "\(error.localizedDescription)"
            ])
            throw MCPError.internalError("Failed to encode response as JSON: \(error.localizedDescription)")
        }
    }
}

/// A descriptor for element capabilities
public struct ElementCapabilitiesDescriptor: Codable, Sendable, Identifiable {
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
    
    /// Element position and size
    public let frame: ElementFrame
    
    /// Capabilities of the element (e.g., clickable, editable)
    public let capabilities: [String]
    
    /// Available actions that can be performed on this element
    public let actions: [String]
    
    /// Additional attributes of the element
    public let attributes: [String: String]
    
    /// Children elements, if requested and available
    public let children: [ElementCapabilitiesDescriptor]?
    
    /// The count of children
    public let childCount: Int
    
    /// Create a new capabilities descriptor
    /// - Parameters:
    ///   - id: Unique identifier
    ///   - role: Accessibility role
    ///   - title: Title or label (optional)
    ///   - value: Current value (optional)
    ///   - description: Human-readable description (optional)
    ///   - frame: Element position and size
    ///   - capabilities: Capabilities of the element
    ///   - actions: Available actions
    ///   - attributes: Additional attributes
    ///   - children: Child elements (optional)
    ///   - childCount: Number of children
    public init(
        id: String,
        role: String,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        frame: ElementFrame,
        capabilities: [String] = [],
        actions: [String] = [],
        attributes: [String: String] = [:],
        children: [ElementCapabilitiesDescriptor]? = nil,
        childCount: Int = 0
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.frame = frame
        self.capabilities = capabilities
        self.actions = actions
        self.attributes = attributes
        self.children = children
        self.childCount = childCount
    }
    
    /// Convert to MCP Value
    /// - Returns: An MCP Value representation of the descriptor
    public func toValue() throws -> Value {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let decoder = JSONDecoder()
        return try decoder.decode(Value.self, from: data)
    }
}