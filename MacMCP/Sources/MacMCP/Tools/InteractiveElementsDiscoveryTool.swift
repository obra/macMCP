// ABOUTME: This file defines a tool for discovering interactive UI elements in macOS applications.
// ABOUTME: It provides methods for finding buttons, text fields, and other interactive controls.

import Foundation
import MCP
import Logging

/// A tool for discovering interactive UI elements in applications
public struct InteractiveElementsDiscoveryTool: @unchecked Sendable {
    /// The name of the tool
    public let name = "macos/interactive_elements"
    
    /// Description of the tool
    public let description = "Discover interactive UI elements in macOS applications"
    
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
    
    /// Create a new interactive elements discovery tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.interactive_elements")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Interactive Elements Discovery",
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
                    "description": .string("The scope of elements to search: application, window, element"),
                    "enum": .array([
                        .string("application"),
                        .string("window"),
                        .string("element")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application. Required for application and window scopes.")
                ]),
                "windowId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the window to search. Required for window scope.")
                ]),
                "elementId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the element to search within. Required for element scope.")
                ]),
                "types": .object([
                    "type": .string("array"),
                    "description": .string("Types of interactive elements to find"),
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
                "maxDepth": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum depth to search"),
                    "default": .int(10)
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
                ]),
                "filter": .object([
                    "type": .string("object"),
                    "description": .string("Filter criteria for elements"),
                    "properties": .object([
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
                        ]),
                        "enabled": .object([
                            "type": .string("boolean"),
                            "description": .string("Filter by enabled state")
                        ])
                    ])
                ])
            ]),
            "required": .array([.string("scope")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Process an interactive elements discovery request
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
        
        // Get element types
        var elementTypes: [String] = []
        if case let .array(types)? = params["types"] {
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
        var titleContains: String? = nil
        var valueContains: String? = nil
        var descriptionContains: String? = nil
        var enabledFilter: Bool? = nil
        
        if case let .object(filterObj)? = params["filter"] {
            titleContains = filterObj["titleContains"]?.stringValue
            valueContains = filterObj["valueContains"]?.stringValue
            descriptionContains = filterObj["descriptionContains"]?.stringValue
            enabledFilter = filterObj["enabled"]?.boolValue
        }
        
        // Process based on scope
        switch scopeValue {
        case "application":
            return try await handleApplicationScope(
                params: params,
                elementTypes: elementTypes,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                enabledFilter: enabledFilter
            )
            
        case "window":
            return try await handleWindowScope(
                params: params,
                elementTypes: elementTypes,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                enabledFilter: enabledFilter
            )
            
        case "element":
            return try await handleElementScope(
                params: params,
                elementTypes: elementTypes,
                maxDepth: maxDepth,
                includeHidden: includeHidden,
                limit: limit,
                titleContains: titleContains,
                valueContains: valueContains,
                descriptionContains: descriptionContains,
                enabledFilter: enabledFilter
            )
            
        default:
            throw MCPError.invalidParams("Invalid scope: \(scopeValue)")
        }
    }
    
    /// Handle application scope searching
    private func handleApplicationScope(
        params: [String: Value],
        elementTypes: [String],
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        enabledFilter: Bool?
    ) async throws -> [Tool.Content] {
        // Validate bundle ID
        guard let bundleId = params["bundleId"]?.stringValue else {
            throw MCPError.invalidParams("bundleId is required for application scope")
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: maxDepth
        )
        
        // Find interactive elements
        let elements = findInteractiveElements(
            in: appElement,
            types: elementTypes,
            includeHidden: includeHidden,
            limit: limit,
            titleContains: titleContains,
            valueContains: valueContains,
            descriptionContains: descriptionContains,
            enabledFilter: enabledFilter
        )
        
        // Convert to descriptors
        let descriptors = elements.map { ElementDescriptor.from(element: $0) }
        
        // Return the element descriptors
        return try formatResponse(descriptors)
    }
    
    /// Handle window scope searching
    private func handleWindowScope(
        params: [String: Value],
        elementTypes: [String],
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        enabledFilter: Bool?
    ) async throws -> [Tool.Content] {
        // Validate bundle ID
        guard let bundleId = params["bundleId"]?.stringValue else {
            throw MCPError.invalidParams("bundleId is required for window scope")
        }
        
        // Validate window ID
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for window scope")
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 2 // Shallow depth to find windows
        )
        
        // Find the specified window
        var windowElement: UIElement? = nil
        for child in appElement.children {
            if child.role == AXAttribute.Role.window && child.identifier == windowId {
                windowElement = child
                break
            }
        }
        
        guard let window = windowElement else {
            throw MCPError.internalError("Window with ID \(windowId) not found")
        }
        
        // Find interactive elements
        let elements = findInteractiveElements(
            in: window,
            types: elementTypes,
            includeHidden: includeHidden,
            limit: limit,
            titleContains: titleContains,
            valueContains: valueContains,
            descriptionContains: descriptionContains,
            enabledFilter: enabledFilter
        )
        
        // Convert to descriptors
        let descriptors = elements.map { ElementDescriptor.from(element: $0) }
        
        // Return the element descriptors
        return try formatResponse(descriptors)
    }
    
    /// Handle element scope searching
    private func handleElementScope(
        params: [String: Value],
        elementTypes: [String],
        maxDepth: Int,
        includeHidden: Bool,
        limit: Int,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        enabledFilter: Bool?
    ) async throws -> [Tool.Content] {
        // Validate element ID
        guard let elementId = params["elementId"]?.stringValue else {
            throw MCPError.invalidParams("elementId is required for element scope")
        }
        
        // We need to find the element first, which means we need to search the system or an application
        let bundleId = params["bundleId"]?.stringValue
        
        // Try to find the element
        var rootElement: UIElement
        var searchScope: UIElementScope
        
        if let bundleId = bundleId {
            rootElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleId,
                recursive: true,
                maxDepth: 3 // Shallow depth for initial search
            )
            searchScope = .application(bundleIdentifier: bundleId)
        } else {
            rootElement = try await accessibilityService.getSystemUIElement(
                recursive: true,
                maxDepth: 3 // Shallow depth for initial search
            )
            searchScope = .systemWide
        }
        
        // Function to find element by ID
        func findElementById(_ elementId: String, in element: UIElement) -> UIElement? {
            if element.identifier == elementId {
                return element
            }
            
            for child in element.children {
                if let found = findElementById(elementId, in: child) {
                    return found
                }
            }
            
            return nil
        }
        
        // Try to find the element directly
        var targetElement = findElementById(elementId, in: rootElement)
        
        // If not found, try a deeper search using the accessibility service
        if targetElement == nil {
            // Create a specific role filter to use with findUIElements
            let elements = try await accessibilityService.findUIElements(
                role: nil, // Don't filter by role
                titleContains: nil, // Don't filter by title
                scope: searchScope,
                recursive: true,
                maxDepth: maxDepth
            ).filter { $0.identifier == elementId }
            
            if let firstMatch = elements.first {
                targetElement = firstMatch
            }
        }
        
        guard let element = targetElement else {
            throw MCPError.internalError("Element with ID \(elementId) not found")
        }
        
        // Find interactive elements
        let elements = findInteractiveElements(
            in: element,
            types: elementTypes,
            includeHidden: includeHidden,
            limit: limit,
            titleContains: titleContains,
            valueContains: valueContains,
            descriptionContains: descriptionContains,
            enabledFilter: enabledFilter
        )
        
        // Convert to descriptors
        let descriptors = elements.map { ElementDescriptor.from(element: $0) }
        
        // Return the element descriptors
        return try formatResponse(descriptors)
    }
    
    /// Find interactive elements in a UI element hierarchy
    /// - Parameters:
    ///   - element: The root element to search
    ///   - types: Types of elements to find
    ///   - includeHidden: Whether to include hidden elements
    ///   - limit: Maximum number of elements to return
    ///   - titleContains: Filter by title substring
    ///   - valueContains: Filter by value substring
    ///   - descriptionContains: Filter by description substring
    ///   - enabledFilter: Filter by enabled state
    /// - Returns: Array of matching UI elements
    private func findInteractiveElements(
        in element: UIElement,
        types: [String],
        includeHidden: Bool,
        limit: Int,
        titleContains: String?,
        valueContains: String?,
        descriptionContains: String?,
        enabledFilter: Bool?
    ) -> [UIElement] {
        // Keep track of found elements
        var foundElements: [UIElement] = []
        
        // Map of element types to role patterns
        let typeToRoles: [String: [String]] = [
            "button": [AXAttribute.Role.button, "AXButtonSubstitute", "AXButtton"],
            "checkbox": [AXAttribute.Role.checkbox],
            "radio": [AXAttribute.Role.radioButton, "AXRadioGroup"],
            "textfield": [AXAttribute.Role.textField, AXAttribute.Role.textArea, "AXSecureTextField"],
            "dropdown": [AXAttribute.Role.popUpButton, "AXComboBox", "AXPopover"],
            "slider": ["AXSlider", "AXScrollBar"],
            "link": [AXAttribute.Role.link],
            "tab": ["AXTabGroup", "AXTab", "AXTabButton"],
            "any": [] // Special case - will match any interactive element
        ]
        
        // Set of roles to search for
        var targetRoles = Set<String>()
        
        // If "any" is in the types, we'll look for all interactive roles
        if types.contains("any") {
            for (_, roles) in typeToRoles {
                targetRoles.formUnion(roles)
            }
        } else {
            // Otherwise, just add the roles for the requested types
            for type in types {
                if let roles = typeToRoles[type] {
                    targetRoles.formUnion(roles)
                }
            }
        }
        
        // Recursive function to find elements
        func findElements(in element: UIElement, depth: Int = 0) {
            // Stop if we've reached the limit
            if foundElements.count >= limit {
                return
            }
            
            // Check if this element matches
            let isInteractive = targetRoles.isEmpty || targetRoles.contains(element.role)
            let isVisible = includeHidden || (element.attributes["visible"] as? Bool ?? true)
            let matchesTitle = titleContains == nil || element.title?.contains(titleContains!) == true
            let matchesValue = valueContains == nil || element.value?.contains(valueContains!) == true
            let matchesDescription = descriptionContains == nil || element.elementDescription?.contains(descriptionContains!) == true
            let matchesEnabled = enabledFilter == nil || (element.attributes["enabled"] as? Bool) == enabledFilter
            
            // Add the element if it matches all criteria
            if isInteractive && isVisible && matchesTitle && matchesValue && matchesDescription && matchesEnabled {
                foundElements.append(element)
            }
            
            // Recursively check children
            for child in element.children {
                findElements(in: child, depth: depth + 1)
            }
        }
        
        // Start the recursive search
        findElements(in: element)
        
        return foundElements
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