// ABOUTME: Core functionality for inspecting accessibility trees using MCP tools
// ABOUTME: Handles application access, element traversal, and attribute retrieval via MCP

import Foundation
import Logging
import Cocoa
import MCP

// Configure a logger for the inspector
private let inspectorLogger = Logger(label: "com.anthropic.mac-mcp.mcp-inspector")

/// The main inspector class responsible for accessibility tree traversal using MCP tools
class MCPInspector {
    private let appId: String?
    private let pid: Int?
    private let maxDepth: Int
    private var elementIndex = 0
    
    // MCP client for communicating with the MCP server
    private var mcpClient: MCPClient?
    
    init(appId: String?, pid: Int?, maxDepth: Int, mcpPath: String? = nil) {
        self.appId = appId
        self.pid = pid
        self.maxDepth = maxDepth
        
        // Create the MCP client with the correct path
        let serverPath = mcpPath ?? "./MacMCP"  // Default to local directory if not specified
        print("Using MCP server at: \(serverPath)")
        self.mcpClient = MCPClient(serverPath: serverPath)
    }
    
    /// Inspects the application and returns the root UI element node
    func inspectApplication() async throws -> MCPUIElementNode {
        inspectorLogger.info("Inspecting application", metadata: ["appId": .string(appId ?? ""), "pid": .stringConvertible(pid ?? 0)])
        
        // Verify we have either an app ID or PID
        guard appId != nil || pid != nil else {
            throw InspectionError.applicationNotFound
        }
        
        // Start MCP server if needed
        try await startMCPIfNeeded()
        
        // Find application bundle ID - either directly provided or derived from PID
        let bundleIdentifier: String
        if let appId = appId {
            bundleIdentifier = appId
        } else if let pid = pid {
            // Convert PID to bundle ID using NSRunningApplication
            guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
                throw InspectionError.applicationNotFound
            }
            guard let appBundle = app.bundleIdentifier else {
                throw InspectionError.applicationNotFound
            }
            bundleIdentifier = appBundle
        } else {
            throw InspectionError.applicationNotFound
        }
        
        // Use MCP's UIStateTool to get UI information
        let jsonData = try await fetchUIStateData(bundleIdentifier: bundleIdentifier, maxDepth: maxDepth)
        
        // Process JSON data
        do {
            // Parse JSON response
            guard let jsonArray = jsonData as? [[String: Any]],
                  let rootJson = jsonArray.first else {
                throw InspectionError.unexpectedError("Invalid JSON response from MCP")
            }
            
            // Reset element counter
            elementIndex = 0
            
            // Create the root node
            let rootNode = MCPUIElementNode(jsonElement: rootJson, index: elementIndex)
            elementIndex += 1
            
            // Recursively populate children
            _ = rootNode.populateChildren(from: rootJson, startingIndex: elementIndex)
            
            return rootNode
        } catch {
            throw InspectionError.unexpectedError("Failed to parse UI state: \(error.localizedDescription)")
        }
    }
    
    /// Start the MCP server if it's not already running
    private func startMCPIfNeeded() async throws {
        guard let mcpClient = self.mcpClient else {
            throw InspectionError.unexpectedError("MCP client not initialized")
        }
        
        // Start the MCP server process
        try mcpClient.startServer()
        
        // Small delay to let the server initialize
        try await Task.sleep(for: .milliseconds(500))
    }
    
    /// Fetches UI state data from MCP UIStateTool
    private func fetchUIStateData(bundleIdentifier: String, maxDepth: Int) async throws -> Any {
        guard let mcpClient = self.mcpClient else {
            throw InspectionError.unexpectedError("MCP client not initialized")
        }
        
        // Create the request parameters for the UIStateTool
        let params: [String: Any] = [
            "scope": "application",
            "bundleId": bundleIdentifier,
            "maxDepth": maxDepth
        ]
        
        // Send request to the MCP server
        do {
            print("Sending UI state request to MCP for: \(bundleIdentifier)")
            let response = try await mcpClient.sendRequest(
                toolName: "macos_ui_state",
                params: params
            )
            
            return response
        } catch {
            inspectorLogger.error("Failed to fetch UI state data: \(error.localizedDescription)")
            print("ERROR: Detailed UI state error: \(error)")
            throw InspectionError.unexpectedError("Failed to fetch UI state: \(error.localizedDescription)")
        }
    }
    
    /// Cleanup resources
    deinit {
        // Stop the MCP server on cleanup
        mcpClient?.stopServer()
    }
}

/// Define custom error types
enum InspectionError: Swift.Error {
    case accessibilityPermissionDenied
    case applicationNotFound
    case timeout
    case unexpectedError(String)
    
    var description: String {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission denied. Please enable accessibility permissions in System Settings > Privacy & Security > Accessibility."
        case .applicationNotFound:
            return "Application not found. Please verify the bundle ID or process ID."
        case .timeout:
            return "Operation timed out. The application may be busy or not responding."
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
}