// ABOUTME: This is the main entry point for the macOS MCP server application.
// ABOUTME: It initializes and starts the server with a stdio transport.

import Foundation
import ArgumentParser
import MCP
import Logging

struct MacMCPCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mac-mcp",
        abstract: "macOS Model Context Protocol (MCP) Server",
        discussion: """
        This tool provides a macOS MCP server that connects AI assistants 
        to macOS through the accessibility APIs.
        """,
        version: "0.1.0"
    )
    
    @Flag(name: .long, help: "Enable debug logging")
    var debug = false
    
    mutating func run() async throws {
        // Configure logging
        let logLevel: Logger.Level = debug ? .debug : .info
        let logger = Logger(label: "mcp.macos") { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = logLevel
            return handler
        }
        
        logger.info("Starting macOS MCP Server")
        
        // Create and start the server
        let server = MCPServer(logger: logger)
        let transport = StdioTransport(logger: logger)
        
        do {
            try await server.start(transport: transport)
            logger.info("Server started successfully, waiting for requests")
            await server.waitUntilCompleted()
        } catch {
            logger.error("Failed to start server", metadata: ["error": "\(error)"])
            throw error
        }
    }
}

// Execute the command line tool
MacMCPCommand.main()