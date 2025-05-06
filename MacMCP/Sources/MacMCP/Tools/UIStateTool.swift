// ABOUTME: This file defines the UI state tool that provides access to the UI hierarchy.
// ABOUTME: It's the primary tool for getting the current state of UI elements on screen.

import Foundation
import MCP
import Logging

/// A tool for getting the current UI state
public struct UIStateTool {
    /// The name of the tool
    public let name = "macos/ui_state"
    
    /// Description of the tool
    public let description = "Get the current UI state and accessibility hierarchy of macOS applications"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// The logger
    private let logger: Logger
    
    /// Create a new UI state tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.ui_state")
        
        // Set tool annotations first
        self.annotations = .init(
            title: "Get UI State",
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
                    "description": .string("The scope of UI elements to retrieve: system, application, focused, position"),
                    "enum": .array([
                        .string("system"),
                        .string("application"),
                        .string("focused"),
                        .string("position")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application to retrieve. Required when scope is 'application'.")
                ]),
                "x": .object([
                    "type": .string("number"),
                    "description": .string("X coordinate for position scope")
                ]),
                "y": .object([
                    "type": .string("number"),
                    "description": .string("Y coordinate for position scope")
                ]),
                "maxDepth": .object([
                    "type": .string("number"),
                    "description": .string("Maximum depth of the element hierarchy to retrieve"),
                    "default": .double(10)
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
                        ])
                    ])
                ])
            ]),
            "required": .array([.string("scope")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Tool handler function
    public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
        // Cast self to access properties
        let this = Self(
            accessibilityService: AccessibilityService(
                logger: Logger(label: "mcp.tool.ui_state")
            )
        )
        
        return try await this.processRequest(params)
    }
    
    /// Process a UI state request
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
        
        // Extract filter criteria if present
        var role: String? = nil
        var titleContains: String? = nil
        
        // Check if there's a filter object
        if case let .object(filterObj)? = params["filter"] {
            // Extract role if present
            if case let .string(r)? = filterObj["role"] {
                role = r
            }
            
            // Extract titleContains if present
            if case let .string(t)? = filterObj["titleContains"] {
                titleContains = t
            }
        }
        
        let elements: [UIElement]
        
        switch scopeValue {
        case "system":
            // Get system-wide UI state
            let systemElement = try await accessibilityService.getSystemUIElement(
                recursive: true,
                maxDepth: maxDepth
            )
            
            // Apply filters if specified
            if role != nil || titleContains != nil {
                elements = try await accessibilityService.findUIElements(
                    role: role,
                    titleContains: titleContains,
                    scope: .systemWide,
                    recursive: true,
                    maxDepth: maxDepth
                )
            } else {
                elements = [systemElement]
            }
            
        case "application":
            // Get application-specific UI state
            guard let bundleId = params["bundleId"]?.stringValue else {
                throw MCPError.invalidParams("bundleId is required when scope is 'application'")
            }
            
            if role != nil || titleContains != nil {
                elements = try await accessibilityService.findUIElements(
                    role: role,
                    titleContains: titleContains,
                    scope: .application(bundleIdentifier: bundleId),
                    recursive: true,
                    maxDepth: maxDepth
                )
            } else {
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: maxDepth
                )
                elements = [appElement]
            }
            
        case "focused":
            // Get focused application UI state
            if role != nil || titleContains != nil {
                elements = try await accessibilityService.findUIElements(
                    role: role,
                    titleContains: titleContains,
                    scope: .focusedApplication,
                    recursive: true,
                    maxDepth: maxDepth
                )
            } else {
                let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(
                    recursive: true,
                    maxDepth: maxDepth
                )
                elements = [focusedElement]
            }
            
        case "position":
            // Get UI element at position
            guard
                let x = params["x"]?.doubleValue,
                let y = params["y"]?.doubleValue
            else {
                throw MCPError.invalidParams("x and y coordinates are required when scope is 'position'")
            }
            
            if let element = try await accessibilityService.getUIElementAtPosition(
                position: CGPoint(x: x, y: y),
                recursive: true,
                maxDepth: maxDepth
            ) {
                elements = [element]
            } else {
                elements = []
            }
            
        default:
            throw MCPError.invalidParams("Invalid scope: \(scopeValue)")
        }
        
        // Convert elements to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            var jsonObjects: [[String: Any]] = []
            for element in elements {
                let json = try element.toJSON()
                jsonObjects.append(json)
            }
            
            let jsonData = try JSONSerialization.data(
                withJSONObject: jsonObjects,
                options: [.prettyPrinted, .sortedKeys]
            )
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode UI state as JSON")
            }
            
            return [.text(jsonString)]
        } catch {
            logger.error("Error converting UI elements to JSON", metadata: [
                "error": "\(error.localizedDescription)"
            ])
            throw MCPError.internalError("Failed to convert UI elements to JSON: \(error.localizedDescription)")
        }
    }
}