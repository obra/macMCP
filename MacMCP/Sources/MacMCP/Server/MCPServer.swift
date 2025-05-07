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
                // We have a minimal resources implementation to pass validation
                resources: .init(
                    subscribe: false,
                    listChanged: false
                ),
                // We fully support tools
                tools: .init(
                    listChanged: true
                )
            ),
            configuration: .strict
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
        logger.debug("Checking accessibility permissions")
        
        // For now, don't enforce accessibility permissions to avoid crashes
        // Just log the status but continue running
        if AccessibilityPermissions.isAccessibilityEnabled() {
            logger.info("Accessibility permissions already granted")
        } else {
            logger.warning("Accessibility permissions not granted - some functionality may be limited")
            logger.warning("The user needs to grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
            
            // Instead of trying to prompt for permissions (which can cause issues in direct mode),
            // just log a warning and continue
        }
        
        // Continue without throwing an error, even if permissions aren't granted
        // This allows the server to start and register tools, even if some tools won't work without permissions
    }
    
    /// Register all the tools the server provides
    private func registerTools() async {
        logger.info("Registering macOS accessibility tools")
        
        // Register server info handler
        await server.withMethodHandler(ServerInfo.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server was deallocated")
            }
            
            logger.debug("Received server/info request")
            
            // Detect the platform and OS
            let platform: String
            let os: String
            
            #if os(macOS)
            platform = "macOS"
            let version = ProcessInfo.processInfo.operatingSystemVersion
            os = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            #elseif os(iOS)
            platform = "iOS"
            let version = ProcessInfo.processInfo.operatingSystemVersion
            os = "iOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            #else
            platform = "Unknown"
            os = "Unknown"
            #endif
            
            return ServerInfo.Result(
                name: server.name,
                version: server.version,
                capabilities: ServerInfo.Capabilities(
                    apiExplorer: false
                ),
                info: ServerInfo.ServerInfoDetails(
                    platform: platform,
                    os: os
                ),
                supportedVersions: ["2024-11-05"]
            )
        }
        
        // Register shutdown handler
        await server.withMethodHandler(Shutdown.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server was deallocated")
            }
            
            logger.info("Received shutdown request, server will stop after response")
            
            // Schedule shutdown after response is sent
            Task {
                // Brief delay to ensure response is sent
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await self.stop()
            }
            
            return Shutdown.Result()
        }
        
        // Register resource listing handler (empty implementation)
        await server.withMethodHandler(ListResources.self) { params in
            // Return empty list of resources
            return ListResources.Result(resources: [], nextCursor: nil)
        }
        
        // Register prompts listing handler (empty implementation)
        await server.withMethodHandler(ListPrompts.self) { params in
            // Return empty list of prompts
            return ListPrompts.Result(prompts: [], nextCursor: nil)
        }
        
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
                // Rethrow MCP errors for proper handling by the server framework
                throw error
            } catch {
                // Convert any error to MCPError using the standard conversion
                throw error.asMCPError
            }
        }
        
        // Register a simple ping tool for initial connectivity validation
        await registerTool(
            name: ToolNames.ping, 
            description: "Test connectivity with the macOS MCP server",
            inputSchema: Value.object(["type": "object", "properties": [:], "additionalProperties": false, "$schema": "http://json-schema.org/draft-07/schema#"]),
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
        
        // Register the window management tool
        let windowManagementTool = WindowManagementTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        await registerTool(
            name: windowManagementTool.name,
            description: windowManagementTool.description,
            inputSchema: windowManagementTool.inputSchema,
            annotations: windowManagementTool.annotations,
            handler: windowManagementTool.handler
        )
        
        // Register the menu navigation tool
        let menuNavigationTool = MenuNavigationTool(
            accessibilityService: accessibilityService,
            interactionService: interactionService,
            logger: logger
        )
        await registerTool(
            name: menuNavigationTool.name,
            description: menuNavigationTool.description,
            inputSchema: menuNavigationTool.inputSchema,
            annotations: menuNavigationTool.annotations,
            handler: menuNavigationTool.handler
        )
        
        // Register the interactive elements discovery tool
        let interactiveElementsTool = InteractiveElementsDiscoveryTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        await registerTool(
            name: interactiveElementsTool.name,
            description: interactiveElementsTool.description,
            inputSchema: interactiveElementsTool.inputSchema,
            annotations: interactiveElementsTool.annotations,
            handler: interactiveElementsTool.handler
        )
        
        // Register the element capabilities tool
        let elementCapabilitiesTool = ElementCapabilitiesTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        await registerTool(
            name: elementCapabilitiesTool.name,
            description: elementCapabilitiesTool.description,
            inputSchema: elementCapabilitiesTool.inputSchema,
            annotations: elementCapabilitiesTool.annotations,
            handler: elementCapabilitiesTool.handler
        )
        
        // Register cancellation handler
        await server.onNotification(CancelNotification.self) { [weak self] notification in
            guard let self = self else { return }
            logger.debug("Received cancellation request", metadata: [
                "id": "\(notification.params.id)"
            ])
            // Note: Currently we don't have long-running operations that need to be cancelled
            // If such operations are added in the future, we would need to implement 
            // a cancellation mechanism here
        }
    }
    
    /// Register a new tool with the server
    /// - Parameters:
    ///   - name: The tool name (should use the ToolNames constants for consistency)
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