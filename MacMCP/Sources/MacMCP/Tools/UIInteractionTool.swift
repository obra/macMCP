// ABOUTME: This file defines the UI interaction tool for interacting with UI elements.
// ABOUTME: It allows LLMs to click, type, drag and perform other actions on the UI.

import Foundation
import MCP
import Logging

/// A tool for interacting with UI elements on macOS
public struct UIInteractionTool {
    /// The name of the tool
    public let name = ToolNames.uiInteraction
    
    /// Description of the tool
    public let description = "Interact with UI elements on macOS - click, type, scroll and more"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The UI interaction service
    private let interactionService: any UIInteractionServiceProtocol
    
    /// The accessibility service
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// The logger
    private let logger: Logger
    
    /// Create a new UI interaction tool
    /// - Parameters:
    ///   - interactionService: The UI interaction service to use
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        interactionService: any UIInteractionServiceProtocol,
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.interactionService = interactionService
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.ui_interact")
        
        // Set tool annotations first
        self.annotations = .init(
            title: "UI Interaction",
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: false,
            openWorldHint: true
        )
        
        // Initialize inputSchema with an empty object first
        self.inputSchema = .object([:])
        
        // Create the input schema
        self.inputSchema = createInputSchema()
    }
    
    /// Create the input schema for the tool
    private func createInputSchema() -> Value {
        return .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("The interaction action to perform"),
                    "enum": .array([
                        .string("click"),
                        .string("double_click"),
                        .string("right_click"),
                        .string("type"),
                        .string("press_key"),
                        .string("drag"),
                        .string("scroll")
                    ])
                ]),
                "elementId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the UI element to interact with")
                ]),
                "appBundleId": .object([
                    "type": .string("string"),
                    "description": .string("Optional bundle ID of the application containing the element (helps with finding elements in specific apps)")
                ]),
                "x": .object([
                    "type": .string("number"),
                    "description": .string("X coordinate for positional actions (required for position-based clicking)")
                ]),
                "y": .object([
                    "type": .string("number"),
                    "description": .string("Y coordinate for positional actions (required for position-based clicking)")
                ]),
                "text": .object([
                    "type": .string("string"),
                    "description": .string("Text to type (required for type action)")
                ]),
                "keyCode": .object([
                    "type": .string("number"),
                    "description": .string("Key code to press (required for press_key action)")
                ]),
                "targetElementId": .object([
                    "type": .string("string"),
                    "description": .string("Target element ID for drag action (required for drag action)")
                ]),
                "direction": .object([
                    "type": .string("string"),
                    "description": .string("Scroll direction (required for scroll action)"),
                    "enum": .array([
                        .string("up"),
                        .string("down"),
                        .string("left"),
                        .string("right")
                    ])
                ]),
                "amount": .object([
                    "type": .string("number"),
                    "description": .string("Scroll amount from 0.0 to 1.0 (required for scroll action)"),
                    "minimum": .double(0.0),
                    "maximum": .double(1.0)
                ])
            ]),
            "required": .array([.string("action")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Tool handler function
    public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
        
        // Create services on demand to ensure we're in the right context
        let handlerLogger = Logger(label: "mcp.tool.ui_interact")
        handlerLogger.info("Creating services for UIInteractionTool")
        
        let accessibilityService = AccessibilityService(
            logger: Logger(label: "mcp.tool.ui_interact.accessibility")
        )
        let interactionService = UIInteractionService(
            accessibilityService: accessibilityService,
            logger: Logger(label: "mcp.tool.ui_interact.interaction")
        )
        let tool = UIInteractionTool(
            interactionService: interactionService,
            accessibilityService: accessibilityService,
            logger: handlerLogger
        )
        
        // Extract and log the key parameters for debugging
        if let params = params {
            let action = params["action"]?.stringValue ?? "unknown"
            let elementId = params["elementId"]?.stringValue ?? "none"
            let appBundleId = params["appBundleId"]?.stringValue ?? "none"
            
            if action == "click" {
                if let x = params["x"]?.doubleValue, let y = params["y"]?.doubleValue {
                    print("   - Position: (\(x), \(y))")
                }
            }
        }
        
        do {
            let result = try await tool.processRequest(params)
            
            return result
        } catch {
            print("❌ DEBUG: UIInteractionTool.handler error: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   - Error domain: \(nsError.domain)")
            print("   - Error code: \(nsError.code)")
            print("   - Error info: \(nsError.userInfo)")
            throw error
        }
    }
    
    /// Process a UI interaction request
    /// - Parameter params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw createInteractionError(
                message: "Parameters are required",
                context: ["toolName": name]
            ).asMCPError
        }
        
        // Get the action
        guard let actionValue = params["action"]?.stringValue else {
            throw createInteractionError(
                message: "Action is required",
                context: ["toolName": name]
            ).asMCPError
        }
        
        // Process based on action type
        switch actionValue {
        case "click":
            return try await handleClick(params)
        case "double_click":
            return try await handleDoubleClick(params)
        case "right_click":
            return try await handleRightClick(params)
        case "type":
            return try await handleType(params)
        case "press_key":
            return try await handlePressKey(params)
        case "drag":
            return try await handleDrag(params)
        case "scroll":
            return try await handleScroll(params)
        default:
            throw createInteractionError(
                message: "Invalid action: \(actionValue). Must be one of: click, double_click, right_click, type, press_key, drag, scroll",
                context: [
                    "toolName": name,
                    "providedAction": actionValue,
                    "validActions": "click, double_click, right_click, type, press_key, drag, scroll"
                ]
            ).asMCPError
        }
    }
    
    /// Handle click action
    private func handleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
        
        // Element ID click
        if let elementId = params["elementId"]?.stringValue {
            // Check if app bundle ID is provided
            let appBundleId = params["appBundleId"]?.stringValue
            
            // Before clicking, try to look up the element to verify it exists
            do {
                // Use the accessibility service to search for the element
                var foundElement: UIElement? = nil
                
                if let bundleId = appBundleId {
                    print("   - Searching in application with bundle ID: \(bundleId)")
                    // Try finding in specific app first
                    foundElement = try await accessibilityService.findElement(
                        identifier: elementId,
                        in: bundleId
                    )
                }
                
                if foundElement == nil {
                    print("   - Element not found in specified app, searching system-wide")
                    // Fall back to system-wide search
                    foundElement = try await accessibilityService.findElement(
                        identifier: elementId,
                        in: nil
                    )
                }
                
                if let element = foundElement {
                } else {
                    print("⚠️ DEBUG: handleClick - WARNING: Element NOT found before click operation. This may fail.")
                }
            } catch {
                print("⚠️ DEBUG: handleClick - Error validating element: \(error.localizedDescription)")
                print("   - Will still attempt click operation...")
            }
            
            do {
                try await interactionService.clickElement(identifier: elementId, appBundleId: appBundleId)
                
                let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
                return [.text("Successfully clicked element with ID: \(elementId)\(bundleIdInfo)")]
            } catch {
                print("❌ DEBUG: handleClick - Click operation failed: \(error.localizedDescription)")
                let nsError = error as NSError
                print("   - Error domain: \(nsError.domain)")
                print("   - Error code: \(nsError.code)")
                throw error
            }
        }
        
        // Position click
        if let x = params["x"]?.intValue, let y = params["y"]?.intValue {
            
            do {
                try await interactionService.clickAtPosition(position: CGPoint(x: x, y: y))
                return [.text("Successfully clicked at position (\(x), \(y))")]
            } catch {
                print("❌ DEBUG: handleClick - Position click operation failed: \(error.localizedDescription)")
                throw error
            }
        }
        
        print("❌ DEBUG: handleClick - Missing required parameters (elementId or x,y coordinates)")
        throw createInteractionError(
            message: "Click action requires either elementId or x,y coordinates",
            context: [
                "toolName": name,
                "action": "click",
                "providedParams": "\(params.keys.joined(separator: ", "))"
            ]
        ).asMCPError
    }
    
    /// Handle double click action
    private func handleDoubleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let elementId = params["elementId"]?.stringValue else {
            throw createInteractionError(
                message: "Double click action requires elementId",
                context: [
                    "toolName": name,
                    "action": "double_click",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        // Check if app bundle ID is provided
        let appBundleId = params["appBundleId"]?.stringValue
        
        if let appId = appBundleId {
            // If we update doubleClickElement in the future to support appBundleId, use this
            // try await interactionService.doubleClickElement(identifier: elementId, appBundleId: appId)
            
            // For now, we can't pass the bundle ID to doubleClickElement
            logger.warning("appBundleId parameter is provided but not yet supported for double_click action", 
                    metadata: ["elementId": "\(elementId)", "appBundleId": "\(appId)"])
        }
        
        try await interactionService.doubleClickElement(identifier: elementId)
        return [.text("Successfully double-clicked element with ID: \(elementId)")]
    }
    
    /// Handle right click action
    private func handleRightClick(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let elementId = params["elementId"]?.stringValue else {
            throw createInteractionError(
                message: "Right click action requires elementId",
                context: [
                    "toolName": name,
                    "action": "right_click",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        try await interactionService.rightClickElement(identifier: elementId)
        return [.text("Successfully right-clicked element with ID: \(elementId)")]
    }
    
    /// Handle type action
    private func handleType(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let elementId = params["elementId"]?.stringValue else {
            throw createInteractionError(
                message: "Type action requires elementId",
                context: [
                    "toolName": name,
                    "action": "type",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        guard let text = params["text"]?.stringValue else {
            throw createInteractionError(
                message: "Type action requires text",
                context: [
                    "toolName": name,
                    "action": "type",
                    "elementId": elementId,
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        try await interactionService.typeText(elementIdentifier: elementId, text: text)
        return [.text("Successfully typed \(text.count) characters into element with ID: \(elementId)")]
    }
    
    /// Handle press key action
    private func handlePressKey(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let keyCode = params["keyCode"]?.intValue else {
            throw createInteractionError(
                message: "Press key action requires keyCode",
                context: [
                    "toolName": name,
                    "action": "press_key",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        try await interactionService.pressKey(keyCode: keyCode)
        return [.text("Successfully pressed key with code: \(keyCode)")]
    }
    
    /// Handle drag action
    private func handleDrag(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let sourceElementId = params["elementId"]?.stringValue else {
            throw createInteractionError(
                message: "Drag action requires elementId (source)",
                context: [
                    "toolName": name,
                    "action": "drag",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        guard let targetElementId = params["targetElementId"]?.stringValue else {
            throw createInteractionError(
                message: "Drag action requires targetElementId",
                context: [
                    "toolName": name,
                    "action": "drag",
                    "sourceElementId": sourceElementId,
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        try await interactionService.dragElement(
            sourceIdentifier: sourceElementId,
            targetIdentifier: targetElementId
        )
        return [.text("Successfully dragged from element \(sourceElementId) to element \(targetElementId)")]
    }
    
    /// Handle scroll action
    private func handleScroll(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let elementId = params["elementId"]?.stringValue else {
            throw createInteractionError(
                message: "Scroll action requires elementId",
                context: [
                    "toolName": name,
                    "action": "scroll",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        guard let directionString = params["direction"]?.stringValue,
              let direction = ScrollDirection(rawValue: directionString) else {
            throw createInteractionError(
                message: "Scroll action requires valid direction (up, down, left, right)",
                context: [
                    "toolName": name,
                    "action": "scroll",
                    "elementId": elementId,
                    "providedDirection": params["direction"]?.stringValue ?? "nil",
                    "validDirections": "up, down, left, right"
                ]
            ).asMCPError
        }
        
        guard let amount = params["amount"]?.doubleValue, amount >= 0.0, amount <= 1.0 else {
            throw createInteractionError(
                message: "Scroll action requires amount between 0.0 and 1.0",
                context: [
                    "toolName": name,
                    "action": "scroll",
                    "elementId": elementId,
                    "direction": directionString,
                    "providedAmount": params["amount"]?.doubleValue != nil ? "\(params["amount"]!.doubleValue!)" : "nil"
                ]
            ).asMCPError
        }
        
        try await interactionService.scrollElement(
            identifier: elementId,
            direction: direction,
            amount: amount
        )
        return [.text("Successfully scrolled element \(elementId) in direction \(direction.rawValue)")]
    }
}
