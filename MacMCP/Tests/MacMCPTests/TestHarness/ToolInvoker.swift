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
}