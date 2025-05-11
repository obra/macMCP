// ABOUTME: This file defines a tool for working with application windows in macOS.
// ABOUTME: It provides methods to list, find, and interact with windows across applications.

import Foundation
import MCP
import Logging

/// A tool for managing and interacting with application windows
public struct WindowManagementTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.windowManagement
    
    /// Description of the tool
    public let description = "Comprehensive window management for macOS applications"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// The logger
    private let logger: Logger
    
    /// Tool handler function that uses this instance's accessibility service
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
        return { [self] params in
            return try await self.processRequest(params)
        }
    }
    
    /// Available window management actions
    enum Action: String, Codable {
        /// Get all windows for an application
        case getApplicationWindows
        
        /// Get the currently active window
        case getActiveWindow
        
        /// Get the currently focused UI element
        case getFocusedElement
        
        /// Move a window to a new position
        case moveWindow
        
        /// Resize a window
        case resizeWindow
        
        /// Minimize a window
        case minimizeWindow
        
        /// Maximize (zoom) a window
        case maximizeWindow
        
        /// Close a window
        case closeWindow
        
        /// Activate a window (bring to front)
        case activateWindow
        
        /// Change window ordering
        case setWindowOrder
        
        /// Focus a window (give it keyboard focus)
        case focusWindow
    }
    
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
                    "description": .string("The window management action to perform"),
                    "enum": .array([
                        .string("getApplicationWindows"),
                        .string("getActiveWindow"),
                        .string("getFocusedElement"),
                        .string("moveWindow"),
                        .string("resizeWindow"),
                        .string("minimizeWindow"),
                        .string("maximizeWindow"),
                        .string("closeWindow"),
                        .string("activateWindow"),
                        .string("setWindowOrder"),
                        .string("focusWindow")
                    ])
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application")
                ]),
                "windowId": .object([
                    "type": .string("string"),
                    "description": .string("Identifier of a specific window to target")
                ]),
                "includeMinimized": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include minimized windows in the results"),
                    "default": .bool(true)
                ]),
                "x": .object([
                    "type": .string("number"),
                    "description": .string("X coordinate for window positioning")
                ]),
                "y": .object([
                    "type": .string("number"),
                    "description": .string("Y coordinate for window positioning")
                ]),
                "width": .object([
                    "type": .string("number"),
                    "description": .string("Width for window resizing")
                ]),
                "height": .object([
                    "type": .string("number"),
                    "description": .string("Height for window resizing")
                ]),
                "orderMode": .object([
                    "type": .string("string"),
                    "description": .string("Window ordering mode: front, back, above, below"),
                    "enum": .array([
                        .string("front"),
                        .string("back"),
                        .string("above"),
                        .string("below")
                    ])
                ]),
                "referenceWindowId": .object([
                    "type": .string("string"),
                    "description": .string("Reference window ID for relative ordering operations")
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
        guard let actionString = params["action"]?.stringValue,
              let action = Action(rawValue: actionString) else {
            throw MCPError.invalidParams("Valid action is required")
        }
        
        // Common parameters
        let includeMinimized = params["includeMinimized"]?.boolValue ?? true
        
        switch action {
        case .getApplicationWindows:
            return try await handleGetApplicationWindows(params, includeMinimized: includeMinimized)
            
        case .getActiveWindow:
            return try await handleGetActiveWindow()
            
        case .getFocusedElement:
            return try await handleGetFocusedElement()
            
        case .moveWindow:
            return try await handleMoveWindow(params)
            
        case .resizeWindow:
            return try await handleResizeWindow(params)
            
        case .minimizeWindow:
            return try await handleMinimizeWindow(params)
            
        case .maximizeWindow:
            return try await handleMaximizeWindow(params)
            
        case .closeWindow:
            return try await handleCloseWindow(params)
            
        case .activateWindow:
            return try await handleActivateWindow(params)
            
        case .setWindowOrder:
            return try await handleSetWindowOrder(params)
            
        case .focusWindow:
            return try await handleFocusWindow(params)
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
    
    /// Handle the moveWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleMoveWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for moveWindow action")
        }
        
        let x: CGFloat
        let y: CGFloat
        
        if let xDouble = params["x"]?.doubleValue {
            x = CGFloat(xDouble)
        } else {
            throw MCPError.invalidParams("x coordinate is required for moveWindow action")
        }
        
        if let yDouble = params["y"]?.doubleValue {
            y = CGFloat(yDouble)
        } else {
            throw MCPError.invalidParams("y coordinate is required for moveWindow action")
        }
        
        do {
            try await accessibilityService.moveWindow(
                withIdentifier: windowId,
                to: CGPoint(x: x, y: y)
            )
            
            return [.text("""
                {
                    "success": true,
                    "action": "moveWindow",
                    "windowId": "\(windowId)",
                    "position": {
                        "x": \(x),
                        "y": \(y)
                    }
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to move window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the resizeWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleResizeWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for resizeWindow action")
        }
        
        let width: CGFloat
        let height: CGFloat
        
        if let widthDouble = params["width"]?.doubleValue {
            width = CGFloat(widthDouble)
        } else {
            throw MCPError.invalidParams("width is required for resizeWindow action")
        }
        
        if let heightDouble = params["height"]?.doubleValue {
            height = CGFloat(heightDouble)
        } else {
            throw MCPError.invalidParams("height is required for resizeWindow action")
        }
        
        do {
            try await accessibilityService.resizeWindow(
                withIdentifier: windowId,
                to: CGSize(width: width, height: height)
            )
            
            return [.text("""
                {
                    "success": true,
                    "action": "resizeWindow",
                    "windowId": "\(windowId)",
                    "size": {
                        "width": \(width),
                        "height": \(height)
                    }
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to resize window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the minimizeWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleMinimizeWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for minimizeWindow action")
        }
        
        do {
            try await accessibilityService.minimizeWindow(withIdentifier: windowId)
            
            return [.text("""
                {
                    "success": true,
                    "action": "minimizeWindow",
                    "windowId": "\(windowId)"
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to minimize window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the maximizeWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleMaximizeWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for maximizeWindow action")
        }
        
        do {
            try await accessibilityService.maximizeWindow(withIdentifier: windowId)
            
            return [.text("""
                {
                    "success": true,
                    "action": "maximizeWindow",
                    "windowId": "\(windowId)"
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to maximize window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the closeWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleCloseWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for closeWindow action")
        }
        
        do {
            try await accessibilityService.closeWindow(withIdentifier: windowId)
            
            return [.text("""
                {
                    "success": true,
                    "action": "closeWindow",
                    "windowId": "\(windowId)"
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to close window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the activateWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleActivateWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for activateWindow action")
        }
        
        do {
            try await accessibilityService.activateWindow(withIdentifier: windowId)
            
            return [.text("""
                {
                    "success": true,
                    "action": "activateWindow",
                    "windowId": "\(windowId)"
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to activate window: \(error.localizedDescription)")
        }
    }
    
    /// Handle the setWindowOrder action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleSetWindowOrder(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for setWindowOrder action")
        }
        
        guard let orderModeString = params["orderMode"]?.stringValue,
              let orderMode = WindowOrderMode(rawValue: orderModeString) else {
            throw MCPError.invalidParams("Valid orderMode is required for setWindowOrder action (front, back, above, below)")
        }
        
        // Reference window ID is required for above/below ordering
        let referenceWindowId = params["referenceWindowId"]?.stringValue
        
        if (orderMode == .above || orderMode == .below) && referenceWindowId == nil {
            throw MCPError.invalidParams("referenceWindowId is required for '\(orderMode.rawValue)' order mode")
        }
        
        do {
            try await accessibilityService.setWindowOrder(
                withIdentifier: windowId,
                orderMode: orderMode,
                referenceWindowId: referenceWindowId
            )
            
            let referenceInfo = referenceWindowId != nil ? """
                ,
                    "referenceWindowId": "\(referenceWindowId!)"
                """ : ""
            
            return [.text("""
                {
                    "success": true,
                    "action": "setWindowOrder",
                    "windowId": "\(windowId)",
                    "orderMode": "\(orderMode.rawValue)"\(referenceInfo)
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to set window order: \(error.localizedDescription)")
        }
    }
    
    /// Handle the focusWindow action
    /// - Parameter params: The request parameters
    /// - Returns: The tool result
    private func handleFocusWindow(_ params: [String: Value]) async throws -> [Tool.Content] {
        guard let windowId = params["windowId"]?.stringValue else {
            throw MCPError.invalidParams("windowId is required for focusWindow action")
        }
        
        do {
            try await accessibilityService.focusWindow(withIdentifier: windowId)
            
            return [.text("""
                {
                    "success": true,
                    "action": "focusWindow",
                    "windowId": "\(windowId)"
                }
                """)]
        } catch {
            throw MCPError.internalError("Failed to focus window: \(error.localizedDescription)")
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