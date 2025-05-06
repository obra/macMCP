import XCTest
import Testing
import Foundation
import MCP
import Logging

@testable import MacMCP

@Suite("MacMCPServer Tests")
struct MacMCPServerTests {
    @Test("Server initialization with stdio transport")
    func testServerInitialization() async throws {
        let logger = Logger(label: "mcp.test.server")
        let transport = MockTransport(logger: logger)
        let server = MCPServer(name: "TestServer", version: "1.0.0", logger: logger)
        
        // Start the server with the mock transport
        try await server.start(transport: transport)
        
        // Verify the transport is connected
        #expect(await transport.isConnected == true)
        
        // Create and queue an initialize request
        try await transport.queue(
            request: Initialize.request(
                .init(
                    protocolVersion: Version.latest,
                    capabilities: .init(),
                    clientInfo: .init(name: "TestClient", version: "1.0")
                )
            )
        )
        
        // Wait for message processing and response
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify the server sent a response
        let sentMessages = await transport.sentMessages
        #expect(sentMessages.count >= 1)
        
        // Verify the response includes server info
        if let response = sentMessages.first {
            #expect(response.contains("serverInfo"))
            #expect(response.contains("TestServer"))
            #expect(response.contains("1.0.0"))
        }
        
        // Stop the server
        await server.stop()
        
        // Wait briefly to ensure everything has shutdown
        try await Task.sleep(for: .milliseconds(50))
    }
}