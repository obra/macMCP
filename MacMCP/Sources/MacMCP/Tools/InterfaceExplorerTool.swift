// ABOUTME: This file defines the InterfaceExplorerTool for exploring UI elements and their capabilities.
// ABOUTME: It consolidates functionality from UIStateTool, InteractiveElementsDiscoveryTool, and ElementCapabilitiesTool.

import Foundation
import MCP
import Logging
import MacMCPUtilities

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
    
    /// Fully qualified path-based identifier for the element (always starts with ui://)
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
    /// - Returns: An EnhancedElementDescriptor
    public static func from(
        element: UIElement,
        maxDepth: Int = 10,
        currentDepth: Int = 0
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
        
        // Always generate the fully qualified path
        var path: String?
        
        // First check if the element already has a path set
        // Use the element's already set path - this should be the fully qualified path
        path = element.path
        elementDescriptorLogger.debug("Using path on element", metadata: ["path": .string(path ?? "<nil>")])
            
            // Always generate a more detailed path if the current one isn't fully qualified
            if path == nil || !path!.contains("/") { // Generate full path if missing or incomplete
                // No pre-existing path, so we need to generate one
                do {
                    // Always generate a fully qualified path from root to current element
                    // Start with the complete path segments
                    var pathSegments: [PathSegment] = []
                    
                    // Collect all elements from current to root
                    var elementsChain: [UIElement] = []
                    var currentElement: UIElement? = element
                    
                    // Build chain of elements from current to root
                    while let elem = currentElement {
                        elementsChain.insert(elem, at: 0)
                        currentElement = elem.parent
                    }
                    
                    // Make sure we include the application at the root if not already in chain
                    if !elementsChain.isEmpty && elementsChain[0].role != "AXApplication" {
                        // Try to get the application from the chain's parent links
                        var foundApp = false
                        currentElement = element.parent
                        while let elem = currentElement {
                            if elem.role == "AXApplication" {
                                elementsChain.insert(elem, at: 0)
                                foundApp = true
                                break
                            }
                            currentElement = elem.parent
                        }
                        
                        // If we still don't have an app, create a generic application segment
                        if !foundApp {
                            var appAttributes: [String: String] = [:]
                            if let bundleId = element.attributes["bundleIdentifier"] as? String {
                                appAttributes["bundleIdentifier"] = bundleId
                            } else if let appTitle = element.attributes["applicationTitle"] as? String {
                                appAttributes["AXTitle"] = PathNormalizer.escapeAttributeValue(appTitle)
                            }
                            pathSegments.append(PathSegment(role: "AXApplication", attributes: appAttributes))
                        }
                    }
                    
                    // Process each element in the chain to create path segments
                    for elem in elementsChain {
                        // Create appropriate attributes for this segment
                        var attributes: [String: String] = [:]
                        
                        // Add useful identifying attributes
                        if let title = elem.title, !title.isEmpty {
                            attributes["AXTitle"] = PathNormalizer.escapeAttributeValue(title)
                        }
                        
                        if let desc = elem.elementDescription, !desc.isEmpty {
                            attributes["AXDescription"] = PathNormalizer.escapeAttributeValue(desc)
                        }
                        
                        // Include identifier if available
                        if let identifier = elem.attributes["identifier"] as? String, !identifier.isEmpty {
                            attributes["AXIdentifier"] = identifier
                        }
                        
                        // For applications, include bundle identifier if available
                        if elem.role == "AXApplication" {
                            if let bundleId = elem.attributes["bundleIdentifier"] as? String, !bundleId.isEmpty {
                                attributes["bundleIdentifier"] = bundleId
                            }
                        }
                        
                        // Create the path segment with proper attributes
                        let segment = PathSegment(role: elem.role, attributes: attributes)
                        pathSegments.append(segment)
                    }
                    
                    // Create the ElementPath
                    let elementPath = try ElementPath(segments: pathSegments)
                    
                    // Convert to string
                    path = elementPath.toString()
                    
                    // Store the path on the element itself so that child elements can access it
                    if let unwrappedPath = path {
                        element.path = unwrappedPath
                    }
                } catch {
                    // If path generation fails, we'll still return the descriptor without a path
                    path = nil
                }
            }
        // The else block for includePath=false is removed as we always want a path
        
        // Handle children if we haven't reached maximum depth
        let children: [EnhancedElementDescriptor]?
        if currentDepth < maxDepth && !element.children.isEmpty {
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
            id: finalPath, // Always use fully qualified path for id
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
            path: finalPath, // Always use fully qualified path
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
                    "description": .string("The scope of UI elements to retrieve: system (all apps, very broad), application (specific app by bundleId), focused (currently active app, RECOMMENDED), position (element at screen coordinates), element (specific element by ID), path (element by path)"),
                    "enum": .array([
                        .string("system"),
                        .string("application"),
                        .string("focused"),
                        .string("position"),
                        .string("element"),
                        .string("path")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application to retrieve (required for 'application' scope)")
                ]),
                "elementPath": .object([
                    "type": .string("string"),
                    "description": .string("The path of a specific element to retrieve using ui:// notation (required for 'path' scope)")
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
                        "title": .object([
                            "type": .string("string"),
                            "description": .string("Filter by title (exact match)")
                        ]),
                        "titleContains": .object([
                            "type": .string("string"),
                            "description": .string("Filter by title containing this text")
                        ]),
                        "value": .object([
                            "type": .string("string"),
                            "description": .string("Filter by value (exact match)")
                        ]),
                        "valueContains": .object([
                            "type": .string("string"),
                            "description": .string("Filter by value containing this text")
                        ]),
                        "description": .object([
                            "type": .string("string"),
                            "description": .string("Filter by description (exact match)")
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
        var title: String? = nil
        var titleContains: String? = nil
        var value: String? = nil
        var valueContains: String? = nil
        var description: String? = nil
        var descriptionContains: String? = nil
        
        if case let .object(filterObj)? = params["filter"] {
            role = filterObj["role"]?.stringValue
            title = filterObj["title"]?.stringValue
            titleContains = filterObj["titleContains"]?.stringValue
            value = filterObj["value"]?.stringValue
            valueContains = filterObj["valueContains"]?.stringValue
            description = filterObj["description"]?.stringValue
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
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "focused":
            return try await handleFocusedScope(
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "element":
            // Validate element ID
            guard let elementPath = params["elementPath"]?.stringValue else {
                throw MCPError.invalidParams("elementPath is required when scope is 'element'")
            }
            
            // Bundle ID is optional for element scope
            let bundleId = params["bundleId"]?.stringValue
            
            return try await handleElementScope(
                elementPath: elementPath,
                bundleId: bundleId,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                elementTypes: elementTypes
            )
            
        case "path":
            // Validate element path
            guard let elementPath = params["elementPath"]?.stringValue else {
                throw MCPError.invalidParams("elementPath is required when scope is 'path'")
            }
            
            return try await handlePathScope(
                elementPath: elementPath,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
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
        if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                scope: .systemWide,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters that weren't directly supported by findUIElements
            elements = applyAdditionalFilters(
                elements: elements,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get application-specific UI state
        var elements: [UIElement]
        
        if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                scope: .application(bundleIdentifier: bundleId),
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters if needed (if not handled by findUIElements)
            elements = applyAdditionalFilters(
                elements: elements,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // Get focused application UI state
        var elements: [UIElement]
        
        if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") {
            // Use findUIElements for filtered results
            elements = try await accessibilityService.findUIElements(
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
                descriptionContains: descriptionContains,
                scope: .focusedApplication,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply additional filters
            elements = applyAdditionalFilters(
                elements: elements,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
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
        if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") || !includeHidden {
            elements = applyAdditionalFilters(
                elements: elements,
                role: role,
                title: title,
                titleContains: titleContains,
                value: value,
                valueContains: valueContains,
                description: description,
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
        elementPath: String,
        bundleId: String?,
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // First check if the path is valid
        guard ElementPath.isElementPath(elementPath) else {
            throw MCPError.invalidParams("Invalid element path format: \(elementPath)")
        }
        
        // Parse and resolve the path
        do {
            let parsedPath = try ElementPath.parse(elementPath)
            let axElement = try await parsedPath.resolve(using: accessibilityService)
            
            // Convert to UIElement
            let element = try AccessibilityElement.convertToUIElement(
                axElement,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // If we're searching within this element, we need to apply filters to its children
            var resultElements: [UIElement] = []
            
            if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") {
                // For filtering, we need to process the element and its descendants
                // Now search within this element for matching elements
                resultElements = findMatchingDescendants(
                    in: element,
                    role: role,
                    title: title,
                    titleContains: titleContains,
                    value: value,
                    valueContains: valueContains,
                    description: description,
                    descriptionContains: descriptionContains,
                    elementTypes: elementTypes,
                    includeHidden: includeHidden,
                    maxDepth: maxDepth,
                    limit: limit
                )
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
        } catch let pathError as ElementPathError {
            // If there's a path resolution error, provide specific information
            throw MCPError.internalError("Failed to resolve element path: \(pathError.description)")
        } catch {
            // For other errors
            throw MCPError.internalError("Error finding element by path: \(error.localizedDescription)")
        }
    }
    
    /// Handle path scope
    private func handlePathScope(
        elementPath: String,
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        role: String?,
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
        descriptionContains: String?,
        elementTypes: [String]
    ) async throws -> [Tool.Content] {
        // First check if the path is valid
        guard ElementPath.isElementPath(elementPath) else {
            throw MCPError.invalidParams("Invalid element path format: \(elementPath)")
        }
        
        // Parse and resolve the path
        do {
            let parsedPath = try ElementPath.parse(elementPath)
            let axElement = try await parsedPath.resolve(using: accessibilityService)
            
            // Convert to UIElement
            let element = try AccessibilityElement.convertToUIElement(
                axElement,
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Don't set element.path here
            // We'll calculate accurate hierarchical paths for each element instead
            
            // If we're searching within this element, apply filters to it and its children
            var resultElements: [UIElement] = []
            
            if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil || description != nil || descriptionContains != nil || !elementTypes.contains("any") {
                // Find matching elements within the hierarchy
                resultElements = findMatchingDescendants(
                    in: element,
                    role: role,
                    title: title,
                    titleContains: titleContains,
                    value: value,
                    valueContains: valueContains,
                    description: description,
                    descriptionContains: descriptionContains,
                    elementTypes: elementTypes,
                    includeHidden: includeHidden,
                    maxDepth: maxDepth,
                    limit: limit
                )
                
                // When using path filter, ensure we have proper full paths
                // This ensures we have complete hierarchy information
                for resultElement in resultElements {
                    // For path filtering, we need to handle both fully qualified and partial paths
                    if elementPath.hasPrefix("ui://") && elementPath.contains("/") {
                        // This appears to be a fully qualified path, so use it directly
                        resultElement.path = elementPath
                        self.logger.debug("PATH FILTER - Using provided fully qualified path", metadata: ["path": "\(elementPath)"])
                    } else {
                        // Try to generate a fully qualified path
                        do {
                            let fullPath = try resultElement.generatePath()
                            resultElement.path = fullPath
                            self.logger.debug("PATH FILTER - Generated fully qualified path", metadata: [
                                "original": "\(elementPath)",
                                "fully_qualified": "\(fullPath)"
                            ])
                        } catch {
                            // Fall back to using the provided path if generation fails
                            resultElement.path = elementPath
                            self.logger.warning("PATH FILTER - Using partial path due to generation failure", metadata: ["path": "\(elementPath)"])
                        }
                    }
                }
            } else {
                // If no filters, just use the element itself
                resultElements = [element]
                
                // Apply visibility filter if needed
                if !includeHidden {
                    resultElements = filterVisibleElements(resultElements)
                }

                // When using path-based filtering, set the base path for each element
                // This ensures clients have the proper context for each element
                for resultElement in resultElements {
                    // For path filtering, we set a base path that the element will extend
                    // when creating its fully qualified path
                    if elementPath.hasPrefix("ui://") && elementPath.contains("/") {
                        // This appears to be a fully qualified path, so use it directly
                        resultElement.path = elementPath
                        self.logger.debug("Using provided fully qualified path", metadata: ["path": "\(elementPath)"])
                    } else {
                        // Try to generate a fully qualified path
                        do {
                            let fullPath = try resultElement.generatePath()
                            resultElement.path = fullPath
                            self.logger.debug("Generated fully qualified path for element", metadata: ["path": "\(fullPath)"])
                        } catch {
                            // Fall back to using the provided path if generation fails
                            resultElement.path = elementPath
                            self.logger.warning("Using partial path due to path generation failure", metadata: ["path": "\(elementPath)"])
                        }
                    }
                }
            }
            
            // Convert to enhanced element descriptors
            let descriptors = convertToEnhancedDescriptors(elements: resultElements, maxDepth: maxDepth)
            
            // Apply limit
            let limitedDescriptors = descriptors.prefix(limit)
            
            // Return formatted response
            return try formatResponse(Array(limitedDescriptors))
            
        } catch let pathError as ElementPathError {
            // If there's a path resolution error, provide specific information
            throw MCPError.internalError("Failed to resolve element path: \(pathError.description)")
        } catch {
            // For other errors
            throw MCPError.internalError("Error finding element by path: \(error.localizedDescription)")
        }
    }
    
    /// Find matching descendants in an element hierarchy
    private func findMatchingDescendants(
        in element: UIElement,
        role: String?,
        title: String?,
        titleContains: String?,
        value: String?,
        valueContains: String?,
        description: String?,
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
            let roleMatches = role == nil || element.role == role
            let typeMatches = targetRoles.isEmpty || elementTypes.contains("any") || targetRoles.contains(element.role)
            let titleMatches = (title == nil || element.title == title) &&
                               (titleContains == nil || (element.title?.localizedCaseInsensitiveContains(titleContains!) ?? false))
            let valueMatches = (value == nil || element.value == value) &&
                               (valueContains == nil || (element.value?.localizedCaseInsensitiveContains(valueContains!) ?? false))
            let descriptionMatches = (description == nil || element.elementDescription == description) &&
                                     (descriptionContains == nil || (element.elementDescription?.localizedCaseInsensitiveContains(descriptionContains!) ?? false))
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
                // IMPORTANT: Build up the parent hierarchy before adding to results
                // This ensures each element has a proper parent chain for path generation
                
                // We've already properly set up the parent relationship in convertToUIElement
                // No need to do it again, but we should validate
                if element.parent == nil && depth > 0 {
                    // If a non-root element is missing its parent, this is unusual and might
                    // cause path generation to fail, but we'll still include the element
                    logger.warning("Element at depth \(depth) has no parent - path generation may be incomplete")
                }
                
                results.append(element)
            }
            
            // Stop recursion if we're at max depth
            if depth >= maxDepth {
                return
            }
            
            // Process children and ensure they have a reference to this element as their parent
            for child in element.children {
                // IMPORTANT: Make sure the parent relationship is set
                // This is critical for proper path generation later
                if child.parent == nil {
                    child.parent = element
                }
                
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
            title: nil,
            titleContains: nil,
            value: valueContains,
            valueContains: valueContains,
            description: descriptionContains,
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
        title: String? = nil,
        titleContains: String? = nil,
        value: String? = nil,
        valueContains: String? = nil,
        description: String? = nil,
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
            // Before converting to descriptor, ensure the element has a properly calculated path
            if element.path.isEmpty {
                do {
                    // Generate a path based on the element's position in the hierarchy
                    // This uses parent relationships to build a fully qualified path
                    element.path = try element.generatePath()
                    elementDescriptorLogger.debug("Generated fully qualified path", metadata: ["path": .string(element.path)])
                } catch {
                    // Log any path generation errors but continue
                    logger.warning("Could not generate fully qualified path for element: \(error.localizedDescription)")
                }
            } else if !element.path.hasPrefix("ui://") {
                // Path exists but isn't fully qualified - try to generate a proper one
                do {
                    element.path = try element.generatePath()
                    elementDescriptorLogger.debug("Replaced non-qualified path with fully qualified path", metadata: ["path": .string(element.path)])
                } catch {
                    logger.warning("Could not replace non-qualified path: \(error.localizedDescription)")
                }
            } else if !element.path.contains("/") {
                // Path has ui:// prefix but doesn't contain hierarchy separators
                // This indicates it's a partial path, not a fully qualified one
                do {
                    // Try to generate a more complete path
                    let fullPath = try element.generatePath()
                    elementDescriptorLogger.debug("Replacing partial path with fully qualified path", metadata: [
                        "old": .string(element.path),
                        "new": .string(fullPath)
                    ])
                    element.path = fullPath
                } catch {
                    logger.warning("Could not generate fully qualified path from partial path: \(error.localizedDescription)")
                }
            } else {
                // Element already has a fully qualified path (likely from path filtering)
                // Log it to help with debugging
                elementDescriptorLogger.debug("Element already has fully qualified path", metadata: ["path": .string(element.path)])
            }
            
            // Verify the path is fully qualified
            if !element.path.hasPrefix("ui://") || !element.path.contains("/") {
                logger.warning("Path may not be fully qualified", metadata: ["path": .string(element.path)])
            }
            
            // Convert the element to an enhanced descriptor with its fully qualified path
            return EnhancedElementDescriptor.from(element: element, maxDepth: maxDepth)
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