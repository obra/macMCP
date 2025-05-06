import Foundation
import MCP
import Logging

actor MockTransport: Transport {
    private(set) var sentMessages: [String] = []
    private(set) var isConnected: Bool = false
    
    let logger: Logger
    
    private let messageStream: AsyncThrowingStream<Data, Swift.Error>
    private let messageContinuation: AsyncThrowingStream<Data, Swift.Error>.Continuation
    
    private var queuedMessages: [Data] = []
    
    init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "mcp.mock.transport")
        
        var continuation: AsyncThrowingStream<Data, Swift.Error>.Continuation!
        messageStream = AsyncThrowingStream { continuation = $0 }
        messageContinuation = continuation
    }
    
    func connect() async throws {
        guard !isConnected else { return }
        isConnected = true
        
        // Process any queued messages
        for message in queuedMessages {
            messageContinuation.yield(message)
        }
    }
    
    func disconnect() async {
        isConnected = false
        messageContinuation.finish()
        queuedMessages.removeAll()
    }
    
    func send(_ data: Data) async throws {
        guard isConnected else {
            throw MCPError.transportError(NSError(domain: "mock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not connected"]))
        }
        
        // Convert data to string if valid UTF-8, otherwise store binary data
        if let str = String(data: data, encoding: .utf8) {
            sentMessages.append(str)
        } else {
            sentMessages.append("<binary data>")
        }
    }
    
    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        return messageStream
    }
    
    // Queue a message to be processed when the transport is connected
    func queue(data: Data) async throws {
        if isConnected {
            messageContinuation.yield(data)
        } else {
            queuedMessages.append(data)
        }
    }
    
    // Queue a request to be processed
    func queue<M: MCP.Method>(request: MCP.Request<M>) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(request)
        try await queue(data: data)
    }
    
    // Queue a notification to be processed
    func queue<N: MCP.Notification>(notification: MCP.Message<N>) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(notification)
        try await queue(data: data)
    }
    
    // Queue a batch to be processed
    // NOTE: Using [Any] as a placeholder since AnyRequest isn't defined
    func queue(batch: [Any]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        
        // This would normally encode the batch, but since AnyRequest isn't defined,
        // we'll just create a placeholder JSON object
        let placeholder = "{\"batch\": []}"
        let data = placeholder.data(using: .utf8)!
        try await queue(data: data)
    }
    
    // Clear sent messages
    func clearMessages() async {
        sentMessages.removeAll()
    }
    
    // Execute a tool request for testing purposes
    func executeToolRequest(name: String, parameters: [String: Value]?) async throws -> [Tool.Content] {
        // This is a simplified implementation for testing
        if name == "openApplication" {
            return [.text("{\"success\": true}")]
        }
        
        throw MCPError.invalidRequest("Unknown tool: \(name)")
    }
}