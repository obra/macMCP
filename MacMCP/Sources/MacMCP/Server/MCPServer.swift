// ABOUTME: This file defines the macOS Model Context Protocol (MCP) server class.
// ABOUTME: It handles initialization, tool registration, and accessibility permissions.

import Foundation
import MCP
import Logging
import AppKit

/// The macOS MCP server implementation that supports accessibility features
public actor MCPServer {
    /// The underlying MCP server
    private let server: Server
    
    /// The logger for server operations
    private let logger: Logger
    
    /// Whether the server has been started
    private var isStarted = false
    
    /// The registered tools
    private var tools: [Tool] = []
    
    /// Map of tool names to their handlers
    private var toolHandlers: [String: @Sendable ([String: Value]?) async throws -> [Tool.Content]] = [:]
    
    /// The accessibility service
    private lazy var accessibilityService = AccessibilityService(logger: logger)
    
    /// The screenshot service
    private lazy var screenshotService = ScreenshotService(
        accessibilityService: accessibilityService,
        logger: logger
    )
    
    /// The UI interaction service
    private lazy var interactionService = UIInteractionService(
        accessibilityService: accessibilityService,
        logger: logger
    )
    
    /// The application service
    private lazy var applicationService = ApplicationService(logger: logger)
    
    /// Create a new macOS MCP server
    /// - Parameters:
    ///   - name: The server name
    ///   - version: The server version
    ///   - logger: Optional logger to use (creates one if not provided)
    ///   - applicationService: Optional application service to use (creates one if not provided)
    public init(
        name: String = "MacMCP",
        version: String = "0.1.0",
        logger: Logger? = nil,
        applicationService: ApplicationService? = nil
    ) {
        // Create a server with the capabilities we support
        self.server = Server(
            name: name,
            version: version,
            capabilities: Server.Capabilities(
                resources: .init(
                    subscribe: true,
                    listChanged: true
                ),
                tools: .init(
                    listChanged: true
                )
            ),
            configuration: .default
        )
        
        self.logger = logger ?? Logger(label: "mcp.macos.server")
        
        // We don't set the application service here because it's actor-isolated
        // Instead, we'll use the default lazy initialization
    }
    
    /// Start the server with the given transport
    /// - Parameter transport: The transport to use for communication
    public func start(transport: any Transport) async throws {
        guard !isStarted else {
            logger.warning("Server already started, ignoring start request")
            return
        }
        
        logger.info("Starting macOS MCP Server", metadata: [
            "name": "\(server.name)",
            "version": "\(server.version)"
        ])
        
        // Before starting, ensure we have accessibility permissions
        try await checkAccessibilityPermissions()
        
        // Register all tools
        await registerTools()
        
        // Start the server with initialization hook
        try await server.start(transport: transport) { [weak self] clientInfo, capabilities in
            guard let self = self else { return }
            
            // Log client connection
            self.logger.info("Client connected", metadata: [
                "clientName": "\(clientInfo.name)",
                "clientVersion": "\(clientInfo.version)"
            ])
        }
        
        isStarted = true
    }
    
    /// Stop the server
    public func stop() async {
        if isStarted {
            await server.stop()
            isStarted = false
            logger.info("Server stopped")
        }
    }
    
    /// Wait until the server completes
    public func waitUntilCompleted() async {
        if isStarted {
            await server.waitUntilCompleted()
        }
    }
    
    /// Check if the process has the required accessibility permissions
    private func checkAccessibilityPermissions() async throws {
        logger.info("Checking accessibility permissions")
        
        if AccessibilityPermissions.isAccessibilityEnabled() {
            logger.info("Accessibility permissions already granted")
            return
        }
        
        logger.info("Requesting accessibility permissions")
        do {
            try await AccessibilityPermissions.requestAccessibilityPermissions()
            logger.info("Accessibility permissions granted")
        } catch let error as AccessibilityPermissions.Error {
            // Convert to our rich error type
            let macError = error.asMacMCPError
            
            logger.error("Failed to obtain accessibility permissions", metadata: [
                "error": "\(error.localizedDescription)",
                "category": "\(macError.category.rawValue)",
                "code": "\(macError.code)"
            ])
            
            // Throw the rich error
            throw macError
        } catch {
            // For other errors, convert to a standardized permission error
            let macError = createPermissionError(
                message: "Failed to obtain accessibility permissions: \(error.localizedDescription)"
                // Cannot include error as underlyingError due to compatibility issues
            )
            
            logger.error("Failed to obtain accessibility permissions", metadata: [
                "error": "\(error.localizedDescription)",
                "category": "\(macError.category.rawValue)",
                "code": "\(macError.code)"
            ])
            
            throw macError
        }
    }
    
    /// Register all the tools the server provides
    private func registerTools() async {
        logger.info("Registering macOS accessibility tools")
        
        // Register tool listing handler
        await server.withMethodHandler(ListTools.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server was deallocated")
            }
            
            return ListTools.Result(tools: await self.tools)
        }
        
        // Register tool call handler
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server was deallocated")
            }
            
            // Find the handler for this tool
            guard let handler = await self.toolHandlers[params.name] else {
                throw MCPError.methodNotFound("Unknown tool: \(params.name)")
            }
            
            do {
                // Execute the tool handler
                let content = try await handler(params.arguments)
                return CallTool.Result(content: content)
            } catch let error as MCPError {
                // Return MCP errors directly
                return CallTool.Result(content: [.text(error.localizedDescription)], isError: true)
            } catch let error as MacMCPErrorInfo {
                // Return our rich error info with category, message, and suggestion
                let errorMessage = """
                    Error: \(error.message)
                    Category: \(error.category.rawValue)
                    \(error.recoverySuggestion ?? "")
                    """
                return CallTool.Result(content: [.text(errorMessage)], isError: true)
            } catch {
                // Create a standardized error format
                let macError = MacMCPErrorInfo(
                    category: .unknown,
                    code: (error as NSError).code,
                    message: error.localizedDescription
                )
                
                let errorMessage = """
                    Error: \(macError.message)
                    Category: \(macError.category.rawValue)
                    \(macError.recoverySuggestion ?? "")
                    """
                return CallTool.Result(content: [.text(errorMessage)], isError: true)
            }
        }
        
        // Register a simple ping tool for initial connectivity validation
        await registerTool(
            name: "macos/ping", 
            description: "Test connectivity with the macOS MCP server",
            annotations: .init(
                title: "Ping",
                readOnlyHint: true
            ),
            handler: { params in
                // Return a simple ping response
                return [Tool.Content.text("Pong from macOS MCP server")]
            }
        )
        
        // Register the UI state tool
        let uiStateTool = UIStateTool(accessibilityService: accessibilityService, logger: logger)
        await registerTool(
            name: uiStateTool.name,
            description: uiStateTool.description,
            inputSchema: uiStateTool.inputSchema,
            annotations: uiStateTool.annotations,
            handler: uiStateTool.handler
        )
        
        // Register the screenshot tool
        let screenshotTool = ScreenshotTool(screenshotService: screenshotService, logger: logger)
        await registerTool(
            name: screenshotTool.name,
            description: screenshotTool.description,
            inputSchema: screenshotTool.inputSchema,
            annotations: screenshotTool.annotations,
            handler: screenshotTool.handler
        )
        
        // Register the UI interaction tool
        let interactionTool = UIInteractionTool(
            interactionService: interactionService,
            accessibilityService: accessibilityService,
            logger: logger
        )
        await registerTool(
            name: interactionTool.name,
            description: interactionTool.description,
            inputSchema: interactionTool.inputSchema,
            annotations: interactionTool.annotations,
            handler: interactionTool.handler
        )
        
        // Register the open application tool
        let openApplicationTool = OpenApplicationTool(
            applicationService: applicationService,
            logger: logger
        )
        await registerTool(
            name: openApplicationTool.name,
            description: openApplicationTool.description,
            inputSchema: openApplicationTool.inputSchema,
            annotations: openApplicationTool.annotations,
            handler: openApplicationTool.handler
        )
    }
    
    /// Register a new tool with the server
    /// - Parameters:
    ///   - name: The tool name (should be prefixed with 'macos/' for this server)
    ///   - description: A description of what the tool does
    ///   - inputSchema: Optional JSON schema for the tool's input parameters
    ///   - annotations: Optional annotations for the tool
    ///   - handler: The function that handles tool calls
    private func registerTool(
        name: String,
        description: String,
        inputSchema: Value? = nil,
        annotations: Tool.Annotations = nil,
        handler: @escaping @Sendable ([String: Value]?) async throws -> [Tool.Content]
    ) async {
        // Define the tool
        let tool = Tool(
            name: name,
            description: description,
            inputSchema: inputSchema,
            annotations: annotations
        )
        
        // Add to our tools list
        tools.append(tool)
        
        // Store the handler
        toolHandlers[name] = handler
        
        logger.info("Registered tool", metadata: [
            "name": "\(name)",
            "description": "\(description)"
        ])
    }
}