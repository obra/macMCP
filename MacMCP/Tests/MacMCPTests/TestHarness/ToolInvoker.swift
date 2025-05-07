// ABOUTME: This file provides utilities for directly invoking MCP tools without the protocol layer.
// ABOUTME: It allows for testing tools with specific parameters in a controlled way.

import Foundation
import MCP
@testable import MacMCP

/// Direct invoker for MCP tools without going through protocol
public class ToolInvoker {
    /// Invokes a UIStateTool with the given parameters
    /// - Parameters:
    ///   - tool: The UIStateTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: UIStateTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes a ScreenshotTool with the given parameters
    /// - Parameters:
    ///   - tool: The ScreenshotTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: ScreenshotTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes a UIInteractionTool with the given parameters
    /// - Parameters:
    ///   - tool: The UIInteractionTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: UIInteractionTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes an OpenApplicationTool with the given parameters
    /// - Parameters:
    ///   - tool: The OpenApplicationTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: OpenApplicationTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes a WindowManagementTool with the given parameters
    /// - Parameters:
    ///   - tool: The WindowManagementTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: WindowManagementTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes a MenuNavigationTool with the given parameters
    /// - Parameters:
    ///   - tool: The MenuNavigationTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: MenuNavigationTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes an InteractiveElementsDiscoveryTool with the given parameters
    /// - Parameters:
    ///   - tool: The InteractiveElementsDiscoveryTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: InteractiveElementsDiscoveryTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Invokes an ElementCapabilitiesTool with the given parameters
    /// - Parameters:
    ///   - tool: The ElementCapabilitiesTool to invoke
    ///   - parameters: The parameters to pass to the tool
    /// - Returns: The result of invoking the tool
    public static func invoke(
        tool: ElementCapabilitiesTool,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Helper method for UI state tool
    /// - Parameters:
    ///   - tool: The UI state tool
    ///   - scope: The scope to query (system, application, focused, position)
    ///   - bundleId: Optional bundle ID for application scope
    ///   - position: Optional position for position scope
    ///   - maxDepth: Maximum depth of the element hierarchy
    /// - Returns: UI state result
    public static func getUIState(
        tool: UIStateTool,
        scope: String,
        bundleId: String? = nil,
        position: CGPoint? = nil,
        maxDepth: Int = 5
    ) async throws -> UIStateResult {
        var params: [String: Value] = [
            "scope": .string(scope),
            "maxDepth": .int(maxDepth)
        ]
        
        if let bundleId = bundleId {
            params["bundleId"] = .string(bundleId)
        }
        
        if let position = position {
            params["x"] = .double(Double(position.x))
            params["y"] = .double(Double(position.y))
        }
        
        let result = try await invoke(tool: tool, parameters: params)
        return try UIStateResult(rawContent: result.content)
    }
    
    /// Helper method for screenshot tool (full screen)
    /// - Parameter tool: The screenshot tool
    /// - Returns: Screenshot result
    public static func takeFullScreenshot(
        tool: ScreenshotTool
    ) async throws -> ScreenshotResult {
        let params: [String: Value] = [
            "region": .string("full")
        ]
        
        let result = try await invoke(tool: tool, parameters: params)
        return try getScreenshotResultFromToolResult(result)
    }
    
    /// Helper method for screenshot tool (area)
    /// - Parameters:
    ///   - tool: The screenshot tool
    ///   - x: X coordinate of the area
    ///   - y: Y coordinate of the area
    ///   - width: Width of the area
    ///   - height: Height of the area
    /// - Returns: Screenshot result
    public static func takeAreaScreenshot(
        tool: ScreenshotTool,
        x: Int,
        y: Int,
        width: Int,
        height: Int
    ) async throws -> ScreenshotResult {
        let params: [String: Value] = [
            "region": .string("area"),
            "x": .int(x),
            "y": .int(y),
            "width": .int(width),
            "height": .int(height)
        ]
        
        let result = try await invoke(tool: tool, parameters: params)
        return try getScreenshotResultFromToolResult(result)
    }
    
    /// Helper method for screenshot tool (window)
    /// - Parameters:
    ///   - tool: The screenshot tool
    ///   - bundleId: Bundle ID of the application
    /// - Returns: Screenshot result
    public static func takeWindowScreenshot(
        tool: ScreenshotTool,
        bundleId: String
    ) async throws -> ScreenshotResult {
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string(bundleId)
        ]
        
        let result = try await invoke(tool: tool, parameters: params)
        return try getScreenshotResultFromToolResult(result)
    }
    
    /// Helper method for screenshot tool (element)
    /// - Parameters:
    ///   - tool: The screenshot tool
    ///   - elementId: ID of the UI element
    /// - Returns: Screenshot result
    public static func takeElementScreenshot(
        tool: ScreenshotTool,
        elementId: String
    ) async throws -> ScreenshotResult {
        let params: [String: Value] = [
            "region": .string("element"),
            "elementId": .string(elementId)
        ]
        
        let result = try await invoke(tool: tool, parameters: params)
        return try getScreenshotResultFromToolResult(result)
    }
    
    /// Extract ScreenshotResult from ToolResult
    /// - Parameter result: The tool result
    /// - Returns: Screenshot result
    private static func getScreenshotResultFromToolResult(_ result: ToolResult) throws -> ScreenshotResult {
        guard !result.isEmpty, let first = result.first else {
            throw NSError(
                domain: "ToolInvoker",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Empty result from screenshot tool"]
            )
        }
        
        if case let .image(data, _, metadata) = first {
            guard let base64Data = Data(base64Encoded: data) else {
                throw NSError(
                    domain: "ToolInvoker",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid base64 data in screenshot result"]
                )
            }
            
            // Extract metadata
            let width = Int(metadata?["width"] ?? "0") ?? 0
            let height = Int(metadata?["height"] ?? "0") ?? 0
            let scale = Double(metadata?["scale"] ?? "1.0") ?? 1.0
            
            return ScreenshotResult(
                data: base64Data,
                width: width,
                height: height,
                scale: scale
            )
        } else {
            throw NSError(
                domain: "ToolInvoker",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Expected image content in screenshot result"]
            )
        }
    }
    
    // MARK: - UI Interaction Tool Helper Methods
    
    /// Helper method to click an element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - elementId: ID of the element to click
    /// - Returns: Result of the interaction
    public static func clickElement(
        tool: UIInteractionTool,
        elementId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("click"),
            "elementId": .string(elementId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to click at a position
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - position: Position to click
    /// - Returns: Result of the interaction
    public static func clickAtPosition(
        tool: UIInteractionTool,
        position: CGPoint
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("click"),
            "x": .int(Int(position.x)),
            "y": .int(Int(position.y))
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to double-click an element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - elementId: ID of the element to double-click
    /// - Returns: Result of the interaction
    public static func doubleClickElement(
        tool: UIInteractionTool,
        elementId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("double_click"),
            "elementId": .string(elementId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to right-click an element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - elementId: ID of the element to right-click
    /// - Returns: Result of the interaction
    public static func rightClickElement(
        tool: UIInteractionTool,
        elementId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("right_click"),
            "elementId": .string(elementId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to type text into an element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - elementId: ID of the element to type into
    ///   - text: Text to type
    /// - Returns: Result of the interaction
    public static func typeText(
        tool: UIInteractionTool,
        elementId: String,
        text: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("type"),
            "elementId": .string(elementId),
            "text": .string(text)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to press a key
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - keyCode: Key code to press
    /// - Returns: Result of the interaction
    public static func pressKey(
        tool: UIInteractionTool,
        keyCode: Int
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("press_key"),
            "keyCode": .int(keyCode)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to drag an element to another element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - sourceElementId: ID of the source element
    ///   - targetElementId: ID of the target element
    /// - Returns: Result of the interaction
    public static func dragElement(
        tool: UIInteractionTool,
        sourceElementId: String,
        targetElementId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("drag"),
            "elementId": .string(sourceElementId),
            "targetElementId": .string(targetElementId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to scroll an element
    /// - Parameters:
    ///   - tool: The UI interaction tool
    ///   - elementId: ID of the element to scroll
    ///   - direction: Scroll direction
    ///   - amount: Scroll amount
    /// - Returns: Result of the interaction
    public static func scrollElement(
        tool: UIInteractionTool,
        elementId: String,
        direction: ScrollDirection,
        amount: Double
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("scroll"),
            "elementId": .string(elementId),
            "direction": .string(direction.rawValue),
            "amount": .double(amount)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    // MARK: - OpenApplication Tool Helper Methods
    
    /// Helper method to open an application by bundle identifier
    /// - Parameters:
    ///   - tool: The OpenApplicationTool
    ///   - bundleId: Bundle identifier of the application
    ///   - arguments: Optional command line arguments
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: Result of the operation
    public static func openApplicationByBundleId(
        tool: OpenApplicationTool,
        bundleId: String,
        arguments: [String]? = nil,
        hideOthers: Bool = false
    ) async throws -> ToolResult {
        var params: [String: Value] = [
            "bundleIdentifier": .string(bundleId)
        ]
        
        if let arguments = arguments {
            params["arguments"] = .array(arguments.map { .string($0) })
        }
        
        params["hideOthers"] = .bool(hideOthers)
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to open an application by name
    /// - Parameters:
    ///   - tool: The OpenApplicationTool
    ///   - appName: Name of the application
    ///   - arguments: Optional command line arguments
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: Result of the operation
    public static func openApplicationByName(
        tool: OpenApplicationTool,
        appName: String,
        arguments: [String]? = nil,
        hideOthers: Bool = false
    ) async throws -> ToolResult {
        var params: [String: Value] = [
            "applicationName": .string(appName)
        ]
        
        if let arguments = arguments {
            params["arguments"] = .array(arguments.map { .string($0) })
        }
        
        params["hideOthers"] = .bool(hideOthers)
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    // MARK: - WindowManagement Tool Helper Methods
    
    /// Helper method to get windows of an application
    /// - Parameters:
    ///   - tool: The WindowManagementTool
    ///   - bundleId: Bundle identifier of the application
    /// - Returns: Result containing window information
    public static func getApplicationWindows(
        tool: WindowManagementTool,
        bundleId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("get_windows"),
            "bundleId": .string(bundleId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to focus a window
    /// - Parameters:
    ///   - tool: The WindowManagementTool
    ///   - windowId: ID of the window to focus
    /// - Returns: Result of the operation
    public static func focusWindow(
        tool: WindowManagementTool,
        windowId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("focus_window"),
            "windowId": .string(windowId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    /// Helper method to minimize a window
    /// - Parameters:
    ///   - tool: The WindowManagementTool
    ///   - windowId: ID of the window to minimize
    /// - Returns: Result of the operation
    public static func minimizeWindow(
        tool: WindowManagementTool,
        windowId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "action": .string("minimize_window"),
            "windowId": .string(windowId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    // MARK: - MenuNavigation Tool Helper Methods
    
    /// Helper method to open a menu item
    /// - Parameters:
    ///   - tool: The MenuNavigationTool
    ///   - bundleId: Bundle identifier of the application
    ///   - menuPath: Path to the menu item (e.g., "File/Open")
    /// - Returns: Result of the operation
    public static func openMenuItem(
        tool: MenuNavigationTool,
        bundleId: String,
        menuPath: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "bundleId": .string(bundleId),
            "menuPath": .string(menuPath)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    // MARK: - ElementCapabilities Tool Helper Methods
    
    /// Helper method to get element capabilities
    /// - Parameters:
    ///   - tool: The ElementCapabilitiesTool
    ///   - elementId: ID of the element
    /// - Returns: Result containing element capabilities
    public static func getElementCapabilities(
        tool: ElementCapabilitiesTool,
        elementId: String
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "elementId": .string(elementId)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
    
    // MARK: - InteractiveElementsDiscovery Tool Helper Methods
    
    /// Helper method to discover interactive elements
    /// - Parameters:
    ///   - tool: The InteractiveElementsDiscoveryTool
    ///   - bundleId: Bundle identifier of the application
    ///   - maxElements: Maximum number of elements to return
    /// - Returns: Result containing interactive elements
    public static func discoverInteractiveElements(
        tool: InteractiveElementsDiscoveryTool,
        bundleId: String,
        maxElements: Int = 20
    ) async throws -> ToolResult {
        let params: [String: Value] = [
            "bundleId": .string(bundleId),
            "maxElements": .int(maxElements)
        ]
        
        return try await invoke(tool: tool, parameters: params)
    }
}