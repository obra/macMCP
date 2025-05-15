// ABOUTME: This file defines the InterfaceExplorerTool for exploring UI elements and their capabilities.
// ABOUTME: It consolidates functionality from UIStateTool, InteractiveElementsDiscoveryTool, and ElementCapabilitiesTool.

import Foundation
import MCP
import Logging

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
    
    /// Path-based identifier for the element
    public let path: String?
    
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
    ///   - path: Path-based identifier (optional)
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
        path: String? = nil,
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
        self.path = path
        self.children = children
    }
    
    /// Convert a UIElement to an EnhancedElementDescriptor with detailed state and capability information
    /// - Parameters:
    ///   - element: The UIElement to convert
    ///   - maxDepth: Maximum depth of the hierarchy to traverse
    ///   - currentDepth: Current depth in the hierarchy
    ///   - includePath: Whether to include the path (default true)
    /// - Returns: An EnhancedElementDescriptor
    public static func from(
        element: UIElement,
        maxDepth: Int = 10,
        currentDepth: Int = 0,
        includePath: Bool = true
    ) -> EnhancedElementDescriptor {
        // Generate a human-readable name
        let name: String
        if let title = element.title, !title.isEmpty {
            name = title
        } else if let desc = element.elementDescription, !desc.isEmpty {
            name = desc
        } else if let val = element.value, !val.isEmpty {
            name = "\(element.role) with value \(val)"
        } else {
            name = element.role
        }
        
        // Create the frame
        let frame = ElementFrame(
            x: element.frame.origin.x,
            y: element.frame.origin.y,
            width: element.frame.size.width,
            height: element.frame.size.height
        )
        
        // Determine element state
        let state = determineElementState(element)
        
        // Determine element capabilities
        let capabilities = determineElementCapabilities(element)
        
        // Clean and filter attributes
        let filteredAttributes = filterAttributes(element)
        
        // Generate path if requested
        let path: String?
        if includePath {
            do {
                path = try element.generatePath()
            } catch {
                // If path generation fails, we'll still return the descriptor without a path
                path = nil
            }
        } else {
            path = nil
        }
        
        // Handle children if we haven't reached maximum depth
        let children: [EnhancedElementDescriptor]?
        if currentDepth < maxDepth && !element.children.isEmpty {
            // Recursively convert children with incremented depth
            children = element.children.map { 
                from(element: $0, maxDepth: maxDepth, currentDepth: currentDepth + 1, includePath: includePath) 
            }
        } else {
            children = nil
        }
        
        return EnhancedElementDescriptor(
            id: element.identifier,
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
            path: path,
            children: children
        )
    }
    
    /// Determine element state based on its attributes
    /// - Parameter element: The UIElement to evaluate
    /// - Returns: Array of state strings
    private static func determineElementState(_ element: UIElement) -> [String] {
        var states: [String] = []
        
        // Map boolean attributes to string state values
        if element.isEnabled {
            states.append("enabled")
        } else {
            states.append("disabled")
        }
        
        if element.isVisible {
            states.append("visible")
        } else {
            states.append("hidden")
        }
        
        if element.isFocused {
            states.append("focused")
        } else {
            states.append("unfocused")
        }
        
        if element.isSelected {
            states.append("selected")
        } else {
            states.append("unselected")
        }
        
        // Add other state mappings based on attributes
        if let expanded = element.attributes["expanded"] as? Bool {
            states.append(expanded ? "expanded" : "collapsed")
        }
        
        if let readonly = element.attributes["readonly"] as? Bool {
            states.append(readonly ? "readonly" : "editable")
        }
        
        if let required = element.attributes["required"] as? Bool {
            states.append(required ? "required" : "optional")
        }
        
        return states
    }
    
    /// Determine element capabilities based on role and actions
    /// - Parameter element: The UIElement to evaluate
    /// - Returns: Array of capability strings
    private static func determineElementCapabilities(_ element: UIElement) -> [String] {
        var capabilities: [String] = []
        
        // Map element roles and actions to higher-level capabilities
        if element.isClickable || element.role == AXAttribute.Role.button || element.actions.contains(AXAttribute.Action.press) {
            capabilities.append("clickable")
        }
        
        if element.isEditable || element.role == AXAttribute.Role.textField || element.role == AXAttribute.Role.textArea {
            capabilities.append("editable")
        }
        
        if element.isToggleable || element.role == AXAttribute.Role.checkbox || element.role == AXAttribute.Role.radioButton {
            capabilities.append("toggleable")
        }
        
        if element.isSelectable {
            capabilities.append("selectable")
        }
        
        if element.isAdjustable {
            capabilities.append("adjustable")
        }
        
        if element.role == "AXScrollArea" || element.actions.contains(AXAttribute.Action.scrollToVisible) {
            capabilities.append("scrollable")
        }
        
        if !element.children.isEmpty {
            capabilities.append("hasChildren")
        }
        
        if element.actions.contains(AXAttribute.Action.showMenu) {
            capabilities.append("hasMenu")
        }
        
        if element.attributes["help"] != nil || element.attributes["helpText"] != nil {
            capabilities.append("hasHelp")
        }
        
        if element.attributes["tooltip"] != nil || element.attributes["toolTip"] != nil {
            capabilities.append("hasTooltip")
        }
        
        if element.role == AXAttribute.Role.link {
            capabilities.append("navigable")
        }
        
        if element.attributes["focusable"] as? Bool == true {
            capabilities.append("focusable")
        }
        
        return capabilities
    }
    
    /// Filter and clean attributes to remove duplicates with other properties
    /// - Parameter element: The UIElement to process
    /// - Returns: Dictionary of filtered and cleaned attributes
    private static func filterAttributes(_ element: UIElement) -> [String: String] {
        var result: [String: String] = [:]
        
        // Only include attributes that aren't already covered by other properties
        for (key, value) in element.attributes {
            // Skip attributes already covered by capabilities, state, or primary properties
            if ["role", "title", "value", "description", "identifier", 
                 "enabled", "visible", "focused", "selected"].contains(key) {
                continue
            }
            
            // Include keyboard shortcuts and other useful properties
            if let keyboardShortcut = element.attributes["keyboardShortcut"] as? String, !keyboardShortcut.isEmpty {
                result["keyboardShortcut"] = keyboardShortcut
            }
            
            if let helpText = element.attributes["help"] as? String, !helpText.isEmpty {
                result["helpText"] = helpText
            }
            
            // Include other attributes with string conversion
            result[key] = String(describing: value)
        }
        
        return result
    }
}

/// A tool for exploring UI elements and their capabilities in macOS applications
public struct InterfaceExplorerTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.interfaceExplorer
    
    /// Description of the tool
    public let description = "Explore and examine UI elements and their capabilities in macOS applications - essential for discovering elements to interact with"
    
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
    
    /// Create a new interface explorer tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.interface_explorer")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Interface Explorer",
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
                "scope": .object([
                    "type": .string("string"),
                    "description": .string("The scope of UI elements to retrieve: system (all apps, very broad), application (specific app by bundleId), focused (currently active app, RECOMMENDED), position (element at screen coordinates), element (specific element by ID)"),
                    "enum": .array([
                        .string("system"),
                        .string("application"),
                        .string("focused"),
                        .string("position"),
                        .string("element")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application to retrieve (required for 'application' scope)")
                ]),
                "elementId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of a specific element to retrieve (required for 'element' scope)")
                ]),
                "x": .object([
                    "type": .array([.string("number"), .string("integer")]),
                    "description": .string("X coordinate for position scope")
                ]),
                "y": .object([
                    "type": .array([.string("number"), .string("integer")]),
                    "description": .string("Y coordinate for position scope")
                ]),
                "maxDepth": .object([
                    "type": .string("number"),
                    "description": .string("Maximum depth of the element hierarchy to retrieve (higher values provide more detail but slower response)"),
                    "default": .double(15)
                ]),
                "filter": .object([
                    "type": .string("object"),
                    "description": .string("Filter criteria for elements"),
                    "properties": .object([
                        "role": .object([
                            "type": .string("string"),
                            "description": .string("Filter by accessibility role")
                        ]),
                        "titleContains": .object([
                            "type": .string("string"),
                            "description": .string("Filter by title containing this text")
                        ]),
                        "valueContains": .object([
                            "type": .string("string"),
                            "description": .string("Filter by value containing this text")
                        ]),
                        "descriptionContains": .object([
                            "type": .string("string"),
                            "description": .string("Filter by description containing this text")
                        ])
                    ])
                ]),
                "elementTypes": .object([
                    "type": .string("array"),
                    "description": .string("Types of interactive elements to find (when discovering interactive elements)"),
                    "items": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("button"),
                            .string("checkbox"),
                            .string("radio"),
                            .string("textfield"),
                            .string("dropdown"),
                            .string("slider"),
                            .string("link"),
                            .string("tab"),
                            .string("any")
                        ])
                    ]),
                    "default": .array([.string("any")])
                ]),
                "includeHidden": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include hidden elements"),
                    "default": .bool(false)
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of elements to return"),
                    "default": .int(100)
                ])
            ]),
            "required": .array([.string("scope")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Process a request for the tool
    /// - Parameter params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw MCPError.invalidParams("Parameters are required")
        }
        
        // Get the scope
        guard let scopeValue = params["scope"]?.stringValue else {
            throw MCPError.invalidParams("Scope is required")
        }
        
        // Get common parameters
        let maxDepth = params["maxDepth"]?.intValue ?? 10
        let includeHidden = params["includeHidden"]?.boolValue ?? false
        let limit = params["limit"]?.intValue ?? 100
        
        // Get element types if specified
        var elementTypes: [String] = []
        if case let .array(types)? = params["elementTypes"] {
            for typeValue in types {
                if let typeStr = typeValue.stringValue {
                    elementTypes.append(typeStr)
                }
            }
        }
        if elementTypes.isEmpty {
            elementTypes = ["any"]
        }
        
        // Extract filter criteria
        var role: String? = nil
        var titleContains: String? = nil
        var valueContains: String? = nil
        var descriptionContains: String? = nil
        
        if case let .object(filterObj)? = params["filter"] {
            role = filterObj["role"]?.stringValue
            titleContains = filterObj["titleContains"]?.stringValue
            valueContains = filterObj["valueContains"]?.stringValue
            descriptionContains = filterObj["descriptionContains"]?.stringValue
        }
        
        // Process based on scope
        switch scopeValue {
        case "system":
            return try await handleSystemScope(
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "application":
            // Validate bundle ID
            guard let bundleId = params["bundleId"]?.stringValue else {
                throw MCPError.invalidParams("bundleId is required when scope is 'application'")
            }
            
            return try await handleApplicationScope(
                bundleId: bundleId,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "focused":
            return try await handleFocusedScope(
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "position":
            // Get coordinates
            let xCoord: Double
            let yCoord: Double
            
            if let xDouble = params["x"]?.doubleValue {
                xCoord = xDouble
            } else if let xInt = params["x"]?.intValue {
                xCoord = Double(xInt)
            } else {
                throw MCPError.invalidParams("x coordinate is required when scope is 'position'")
            }
            
            if let yDouble = params["y"]?.doubleValue {
                yCoord = yDouble
            } else if let yInt = params["y"]?.intValue {
                yCoord = Double(yInt)
            } else {
                throw MCPError.invalidParams("y coordinate is required when scope is 'position'")
            }
            
            return try await handlePositionScope(
                x: xCoord,
                y: yCoord,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "element":
            // Validate element ID
            guard let elementId = params["elementId"]?.stringValue else {
                throw MCPError.invalidParams("elementId is required when scope is 'element'")
            }
            
            // Bundle ID is optional for element scope
            let bundleId = params["bundleId"]?.stringValue
            
            return try await handleElementScope(
                elementId: elementId,
                bundleId: bundleId,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        default:
            throw MCPError.invalidParams("Invalid scope: \(scopeValue)")
        }
    }
    
    /// Handle system scope
    private func handleSystemScope(
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get system-wide UI state
        let systemElement = try await accessibilityService.getSystemUIElement(
            recursive: true,
            maxDepth: maxDepth
        )
        
        // Apply filters if specified
        var elements: [UIElement]
        if role != nil || titleContains != nil || valueContains != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                titleContains: titleContains,
                scope: .systemWide,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters that weren't directly supported by findUIElements
            elements = applyAdditionalFilters(
                elements: elements,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes,
                includeHidden: includeHidden,
                limit: limit
            )
        } else {
            elements = [systemElement]
            
            // Apply hidden filter if specified
            if !includeHidden {
                elements = filterVisibleElements(elements)
            }
        }
        
        // Convert to enhanced element descriptors
        let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)
        
        // Apply limit
        let limitedDescriptors = descriptors.prefix(limit)
        
        // Return formatted response
        return try formatResponse(Array(limitedDescriptors))
    }
    
    /// Handle application scope
    private func handleApplicationScope(
        bundleId: String,
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get application-specific UI state
        var elements: [UIElement]
        
        if role != nil || titleContains != nil || valueContains != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                titleContains: titleContains,
                scope: .application(bundleIdentifier: bundleId),
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters
            elements = applyAdditionalFilters(
                elements: elements,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes,
                includeHidden: includeHidden,
                limit: limit
            )
        } else {
            // Get the full application element
            let appElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleId,
                recursive: true,
                maxDepth: maxDepth
            )
            elements = [appElement]
            
            // Apply hidden filter if specified
            if !includeHidden {
                elements = filterVisibleElements(elements)
            }
        }
        
        // Convert to enhanced element descriptors
        let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)
        
        // Apply limit
        let limitedDescriptors = descriptors.prefix(limit)
        
        // Return formatted response
        return try formatResponse(Array(limitedDescriptors))
    }
    
    /// Handle focused application scope
    private func handleFocusedScope(
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get focused application UI state
        var elements: [UIElement]
        
        if role != nil || titleContains != nil || valueContains != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                titleContains: titleContains,
                scope: .focusedApplication,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters
            elements = applyAdditionalFilters(
                elements: elements,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes,
                includeHidden: includeHidden,
                limit: limit
            )
        } else {
            // Get the full focused application element
            let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(
                recursive: true,
                maxDepth: maxDepth
            )
            elements = [focusedElement]
            
            // Apply hidden filter if specified
            if !includeHidden {
                elements = filterVisibleElements(elements)
            }
        }
        
        // Convert to enhanced element descriptors
        let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)
        
        // Apply limit
        let limitedDescriptors = descriptors.prefix(limit)
        
        // Return formatted response
        return try formatResponse(Array(limitedDescriptors))
    }
    
    /// Handle position scope
    private func handlePositionScope(
        x: Double,
        y: Double,
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get UI element at the specified position
        guard let element = try await accessibilityService.getUIElementAtPosition(
            position: CGPoint(x: x, y: y),
            recursive: true,
            maxDepth: maxDepth
        ) else {
            // No element found at position
            return try formatResponse([EnhancedElementDescriptor]())
        }
        
        var elements = [element]
        
        // Apply filters if needed
        if role != nil || titleContains != nil || valueContains != nil || descriptionContains != nil || !elementTypes.contains("any") || !includeHidden {
            elements = applyAdditionalFilters(
                elements: elements,
                role: role,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes,
                includeHidden: includeHidden,
                limit: limit
            )
        }
        
        // Convert to enhanced element descriptors
        let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)
        
        // Apply limit
        let limitedDescriptors = descriptors.prefix(limit)
        
        // Return formatted response
        return try formatResponse(Array(limitedDescriptors))
    }
    
    /// Handle element scope
    private func handleElementScope(
        elementId: String,
        bundleId: String?,
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Determine the search scope
        let searchScope: UIElementScope
        if let bundleId = bundleId {
            searchScope = .application(bundleIdentifier: bundleId)
        } else {
            searchScope = .systemWide
        }
        
        // Find the specified element
        let elements = try await accessibilityService.findUIElements(
            role: nil,
            titleContains: nil,
            scope: searchScope,
            recursive: true,
            maxDepth: maxDepth
        ).filter { $0.identifier == elementId }
        
        guard let element = elements.first else {
            if let bundleId = bundleId {
                throw MCPError.internalError("Element with ID \(elementId) not found in application \(bundleId)")
            } else {
                throw MCPError.internalError("Element with ID \(elementId) not found")
            }
        }
        
        // If we're searching within this element, we need to apply filters to its children
        var resultElements: [UIElement] = []
        
        if role != nil || titleContains != nil || valueContains != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // For filtering, we need to process the element and its descendants
            // Find the element by identifier
            let foundElement = try await accessibilityService.findElement(
                identifier: elementId,
                in: bundleId
            )

            if let element = foundElement {
                // Now search within this element for matching elements
                resultElements = findMatchingDescendants(
                    in: element,
                    role: role,
                    titleContains: titleContains,
                    valueContains: valueContains,
                    descriptionContains: descriptionContains,
                    elementTypes: elementTypes,
                    includeHidden: includeHidden,
                    maxDepth: maxDepth,
                    limit: limit
                )
            } else {
                resultElements = []
            }
        } else {
            // If no filters, just use the element as is
            resultElements = [element]
            
            // Apply hidden filter if specified
            if !includeHidden {
                resultElements = filterVisibleElements(resultElements)
            }
        }
        
        // Convert to enhanced element descriptors
        let descriptors = convertToEnhancedDescriptors(elements: resultElements, maxDepth: maxDepth)
        
        // Apply limit
        let limitedDescriptors = descriptors.prefix(limit)
        
        // Return formatted response
        return try formatResponse(Array(limitedDescriptors))
    }
    
    /// Find matching descendants in an element hierarchy
    private func findMatchingDescendants(
        in element: UIElement,
        role: String?,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        elementTypes: [String],
        includeHidden: Bool,
        maxDepth: Int,
        limit: Int
    ) -> [UIElement] {
        var results: [UIElement] = []
        
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
            "any": [] // Special case - matches all
        ]
        
        // Collect all roles to match
        var targetRoles = Set<String>()
        if elementTypes.contains("any") {
            // If "any" is selected, collect all roles
            for (_, roles) in typeToRoles where !roles.isEmpty {
                targetRoles.formUnion(roles)
            }
        } else {
            // Otherwise, just include roles for the specified types
            for type in elementTypes {
                if let roles = typeToRoles[type] {
                    targetRoles.formUnion(roles)
                }
            }
        }
        
        // Helper function to check if an element matches all criteria
        func elementMatches(_ element: UIElement) -> Bool {
            // Role check
            let roleMatches = role == nil || element.role == role
            
            // Type check
            let typeMatches = targetRoles.isEmpty || elementTypes.contains("any") || targetRoles.contains(element.role)
            
            // Title check
            let titleMatches = titleContains == nil || 
                              (element.title?.localizedCaseInsensitiveContains(titleContains!) ?? false)
            
            // Value check
            let valueMatches = valueContains == nil || 
                              (element.value?.localizedCaseInsensitiveContains(valueContains!) ?? false)
            
            // Description check
            let descriptionMatches = descriptionContains == nil || 
                                    (element.elementDescription?.localizedCaseInsensitiveContains(descriptionContains!) ?? false)
            
            // Visibility check
            let visibilityMatches = includeHidden || element.isVisible
            
            return roleMatches && typeMatches && titleMatches && valueMatches && descriptionMatches && visibilityMatches
        }
        
        // Recursive function to search for matching elements
        func findElements(in element: UIElement, depth: Int = 0) {
            // Stop if we've reached the limit
            if results.count >= limit {
                return
            }
            
            // Check if this element matches
            if elementMatches(element) {
                results.append(element)
            }
            
            // Stop recursion if we're at max depth
            if depth >= maxDepth {
                return
            }
            
            // Process children
            for child in element.children {
                findElements(in: child, depth: depth + 1)
            }
        }
        
        // Start the search
        findElements(in: element)
        
        return results
    }
    
    /// Apply additional filters not handled by the accessibility service
    private func applyAdditionalFilters(
        elements: [UIElement],
        valueContains: String? = nil,
        descriptionContains: String? = nil,
        elementTypes: [String]? = nil,
        includeHidden: Bool = true,
        limit: Int = 100
    ) -> [UIElement] {
        return applyAdditionalFilters(
            elements: elements,
            role: nil,
            titleContains: nil,
            valueContains: valueContains,
            descriptionContains: descriptionContains,
            elementTypes: elementTypes,
            includeHidden: includeHidden,
            limit: limit
        )
    }
    
    /// Apply filters to elements
    private func applyAdditionalFilters(
        elements: [UIElement],
        role: String? = nil,
        titleContains: String? = nil,
        valueContains: String? = nil,
        descriptionContains: String? = nil,
        elementTypes: [String]? = nil,
        includeHidden: Bool = true,
        limit: Int = 100
    ) -> [UIElement] {
        var results: [UIElement] = []
        
        // Define type-to-role mappings if we need to filter by element type
        var targetRoles = Set<String>()
        if let types = elementTypes, !types.contains("any") {
            let typeToRoles: [String: [String]] = [
                "button": [AXAttribute.Role.button, "AXButtonSubstitute", "AXButtton"],
                "checkbox": [AXAttribute.Role.checkbox],
                "radio": [AXAttribute.Role.radioButton, "AXRadioGroup"],
                "textfield": [AXAttribute.Role.textField, AXAttribute.Role.textArea, "AXSecureTextField"],
                "dropdown": [AXAttribute.Role.popUpButton, "AXComboBox", "AXPopover"],
                "slider": ["AXSlider", "AXScrollBar"],
                "link": [AXAttribute.Role.link],
                "tab": ["AXTabGroup", "AXTab", "AXTabButton"]
            ]
            
            for type in types {
                if let roles = typeToRoles[type] {
                    targetRoles.formUnion(roles)
                }
            }
        }
        
        // Process each element
        for element in elements {
            // Skip if we've reached the limit
            if results.count >= limit {
                break
            }
            
            // Role filter (if not already handled by accessibility service)
            if let role = role, element.role != role {
                continue
            }
            
            // Element type filter
            if !targetRoles.isEmpty && !targetRoles.contains(element.role) {
                continue
            }
            
            // Title filter (if not already handled by accessibility service)
            if let titleFilter = titleContains, 
               !(element.title?.localizedCaseInsensitiveContains(titleFilter) ?? false) {
                continue
            }
            
            // Value filter
            if let valueFilter = valueContains, 
               !(element.value?.localizedCaseInsensitiveContains(valueFilter) ?? false) {
                continue
            }
            
            // Description filter
            if let descriptionFilter = descriptionContains, 
               !(element.elementDescription?.localizedCaseInsensitiveContains(descriptionFilter) ?? false) {
                continue
            }
            
            // Visibility filter
            if !includeHidden && !element.isVisible {
                continue
            }
            
            // Element passed all filters
            results.append(element)
        }
        
        return results
    }
    
    /// Filter to only include visible elements
    private func filterVisibleElements(_ elements: [UIElement]) -> [UIElement] {
        return elements.filter { element in
            // If this element isn't visible, exclude it
            if !element.isVisible {
                return false
            }

            // Include visible elements
            return true
        }
    }
    
    /// Convert UI elements to enhanced element descriptors
    private func convertToEnhancedDescriptors(elements: [UIElement], maxDepth: Int) -> [EnhancedElementDescriptor] {
        return elements.map { element in
            EnhancedElementDescriptor.from(element: element, maxDepth: maxDepth)
        }
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