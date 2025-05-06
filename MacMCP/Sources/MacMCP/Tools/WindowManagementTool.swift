// ABOUTME: This file defines a tool for working with application windows in macOS.
// ABOUTME: It provides methods to list, find, and interact with windows across applications.

import Foundation
import MCP
import Logging

/// A tool for managing and interacting with application windows
public struct WindowManagementTool: @unchecked Sendable {
    /// The name of the tool
    public let name = "macos/window_management"
    
    /// Description of the tool
    public let description = "Get and manage windows of macOS applications"
    
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
    
    /// Create a new window management tool
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.tool.window_management")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Window Management",
            readOnlyHint: false,
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
                "action": .object([
                    "type": .string("string"),
                    "description": .string("The action to perform: getApplicationWindows, getActiveWindow, getFocusedElement"),
                    "enum": .array([
                        .string("getApplicationWindows"),
                        .string("getActiveWindow"),
                        .string("getFocusedElement")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application. Required for getApplicationWindows.")
                ]),
                "includeMinimized": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include minimized windows in the results"),
                    "default": .bool(true)
                ]),
                "windowId": .object([
                    "type": .string("string"),
                    "description": .string("Identifier of a specific window to target")
                ])
            ]),
            "required": .array([.string("action")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Process a window management request
    /// - Parameter params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw MCPError.invalidParams("Parameters are required")
        }
        
        // Get the action
        guard let actionValue = params["action"]?.stringValue else {
            throw MCPError.invalidParams("Action is required")
        }
        
        // Common parameters
        let includeMinimized = params["includeMinimized"]?.boolValue ?? true
        
        switch actionValue {
        case "getApplicationWindows":
            return try await handleGetApplicationWindows(params, includeMinimized: includeMinimized)
            
        case "getActiveWindow":
            return try await handleGetActiveWindow()
            
        case "getFocusedElement":
            return try await handleGetFocusedElement()
            
        default:
            throw MCPError.invalidParams("Invalid action: \(actionValue)")
        }
    }
    
    /// Handle the getApplicationWindows action
    /// - Parameters:
    ///   - params: The request parameters
    ///   - includeMinimized: Whether to include minimized windows
    /// - Returns: The tool result
    private func handleGetApplicationWindows(
        _ params: [String: Value],
        includeMinimized: Bool
    ) async throws -> [Tool.Content] {
        // Validate bundle ID
        guard let bundleId = params["bundleId"]?.stringValue else {
            throw MCPError.invalidParams("bundleId is required for getApplicationWindows")
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 2  // Only need shallow depth for windows
        )
        
        // Find all window elements
        var windows: [WindowDescriptor] = []
        
        // Look for window elements in the children
        for child in appElement.children {
            if child.role == AXAttribute.Role.window {
                if let window = WindowDescriptor.from(element: child) {
                    // Filter minimized windows if needed
                    if includeMinimized || !window.isMinimized {
                        windows.append(window)
                    }
                }
            }
        }
        
        // Return the window descriptors
        return try formatResponse(windows)
    }
    
    /// Handle the getActiveWindow action
    /// - Returns: The tool result
    private func handleGetActiveWindow() async throws -> [Tool.Content] {
        // Get the focused application element
        let focusedApp = try await accessibilityService.getFocusedApplicationUIElement(
            recursive: true,
            maxDepth: 2  // Only need shallow depth for windows
        )
        
        // Look for the main/focused window
        var mainWindow: WindowDescriptor? = nil
        
        for child in focusedApp.children {
            if child.role == AXAttribute.Role.window {
                if let window = WindowDescriptor.from(element: child) {
                    if window.isMain {
                        mainWindow = window
                        break
                    }
                }
            }
        }
        
        // If no window is marked as main, just return the first window
        if mainWindow == nil, let firstWindow = focusedApp.children.first(where: { $0.role == AXAttribute.Role.window }) {
            mainWindow = WindowDescriptor.from(element: firstWindow)
        }
        
        // Return the window descriptor or an empty result
        if let window = mainWindow {
            return try formatResponse([window])
        } else {
            // Return an empty array of the correct type
            let emptyArray: [WindowDescriptor] = []
            return try formatResponse(emptyArray)
        }
    }
    
    /// Handle the getFocusedElement action
    /// - Returns: The tool result
    private func handleGetFocusedElement() async throws -> [Tool.Content] {
        // Find the focused element
        let elements = try await accessibilityService.findUIElements(
            role: nil,
            titleContains: nil,
            scope: .focusedApplication,
            recursive: true,
            maxDepth: 10
        ).filter { ($0.attributes["focused"] as? Bool) == true }
        
        // Convert the focused element(s) to descriptors
        let descriptors = elements.map { ElementDescriptor.from(element: $0) }
        
        // Return the element descriptors
        return try formatResponse(descriptors)
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