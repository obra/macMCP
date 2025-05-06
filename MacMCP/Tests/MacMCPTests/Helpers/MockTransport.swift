import Foundation
import MCP
import Logging
@testable import MacMCP

// Extensions for easier Value access
extension Value {
    func asString() -> String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }
    
    func asInt() -> Int? {
        if case let .int(value) = self {
            return value
        }
        return nil
    }
    
    func asDouble() -> Double? {
        if case let .double(value) = self {
            return value
        }
        return nil
    }
    
    func asBool() -> Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }
}

actor MockTransport: Transport {
    private(set) var sentMessages: [String] = []
    private(set) var isConnected: Bool = false
    
    // For testing, allow passing external services
    private var _applicationService: ApplicationServiceProtocol?
    
    // Setter method for the application service (needed due to actor isolation)
    func setApplicationService(_ service: ApplicationServiceProtocol) {
        self._applicationService = service
    }
    
    // Getter for the application service
    var applicationService: ApplicationServiceProtocol? {
        return _applicationService
    }
    
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
        // This is a testing implementation that routes directly to the mocked services
        if name == "macos/openApplication" || name == "openApplication" {
            // Make sure we have an application service
            guard let appService = applicationService else {
                throw MCPError.internalError("No application service available for testing")
            }
            
            // Extract parameters from the request
            guard let params = parameters else {
                return [.text("{\"success\": false, \"error\": {\"message\": \"Missing parameters\"}}")]
            }
            
            var success = false
            var resultInfo: [String: Any] = [:]
            
            do {
                // Check if we're opening by bundle ID or name
                if let bundleId = params["bundleIdentifier"]?.asString() {
                    // Extract additional parameters
                    var arguments: [String]?
                    if case let .array(argValues) = params["arguments"] {
                        arguments = argValues.compactMap { $0.asString() }
                    }
                    
                    var hideOthers: Bool?
                    if case let .bool(hide) = params["hideOthers"] {
                        hideOthers = hide
                    }
                    
                    // Call the mock service
                    success = try await appService.openApplication(
                        bundleIdentifier: bundleId,
                        arguments: arguments,
                        hideOthers: hideOthers
                    )
                    
                    // Build the result
                    resultInfo["bundleIdentifier"] = bundleId
                    if let args = arguments {
                        resultInfo["arguments"] = args
                    }
                    if let hide = hideOthers {
                        resultInfo["hideOthers"] = hide
                    }
                } 
                else if let appName = params["applicationName"]?.asString() {
                    // Extract additional parameters
                    var arguments: [String]?
                    if case let .array(argValues) = params["arguments"] {
                        arguments = argValues.compactMap { $0.asString() }
                    }
                    
                    var hideOthers: Bool?
                    if case let .bool(hide) = params["hideOthers"] {
                        hideOthers = hide
                    }
                    
                    // Call the mock service
                    success = try await appService.openApplication(
                        name: appName,
                        arguments: arguments,
                        hideOthers: hideOthers
                    )
                    
                    // Build the result
                    resultInfo["applicationName"] = appName
                    if let args = arguments {
                        resultInfo["arguments"] = args
                    }
                    if let hide = hideOthers {
                        resultInfo["hideOthers"] = hide
                    }
                }
                else {
                    return [.text("{\"success\": false, \"error\": {\"message\": \"Missing bundleIdentifier or applicationName\"}}")]
                }
                
                // Add success to the result
                resultInfo["success"] = success
                
                // Convert to JSON
                let jsonData = try JSONSerialization.data(withJSONObject: resultInfo, options: [.prettyPrinted])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return [.text(jsonString)]
            } 
            catch let error as MacMCPErrorInfo {
                // Handle MacMCP errors
                let errorInfo: [String: Any] = [
                    "success": false,
                    "error": [
                        "category": error.category.rawValue,
                        "code": error.code,
                        "message": error.message,
                        "suggestion": error.recoverySuggestion ?? ""
                    ]
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: errorInfo, options: [.prettyPrinted])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return [.text(jsonString)]
            }
            catch {
                // Handle other errors
                let errorInfo: [String: Any] = [
                    "success": false,
                    "error": [
                        "message": error.localizedDescription
                    ]
                ]
                
                let jsonData = try JSONSerialization.data(withJSONObject: errorInfo, options: [.prettyPrinted])
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                return [.text(jsonString)]
            }
        }
        
        throw MCPError.invalidRequest("Unknown tool: \(name)")
    }
}