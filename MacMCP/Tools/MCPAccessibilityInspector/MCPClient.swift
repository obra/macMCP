// ABOUTME: Provides connectivity to the MCP server via stdio
// ABOUTME: Handles communication with MCP to execute tools and process responses

import Foundation
import MCP
import Logging

/// Client for communicating with the Model Context Protocol (MCP) server
class MCPClient {
    private let logger = Logger(label: "com.anthropic.mac-mcp.mcp-client")
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var stderrPipe: Pipe?
    
    // Communication pipes for the MCP server
    private let inputPipe = Pipe()
    private let outputPipe = Pipe()
    private let errorPipe = Pipe()
    
    // Path to the MCP server executable
    private let mcpServerPath: String
    
    /// Initialize with a path to the MCP server
    /// - Parameter serverPath: Path to the MCP server executable
    init(serverPath: String = "./MacMCP") {
        // Resolve the server path - if it's a relative path, make it absolute based on current directory
        if serverPath.hasPrefix("./") || !serverPath.hasPrefix("/") {
            let currentDirectory = FileManager.default.currentDirectoryPath
            let resolvedPath = URL(fileURLWithPath: currentDirectory).appendingPathComponent(serverPath).path
            self.mcpServerPath = resolvedPath
        } else {
            self.mcpServerPath = serverPath
        }
        
        print("MCPClient initialized with resolved server path: \(self.mcpServerPath)")
        logger.info("MCPClient initialized with server path: \(self.mcpServerPath)")
    }
    
    /// Start the MCP server process
    func startServer() throws {
        logger.info("Starting MCP server at path: \(mcpServerPath)")
        print("Starting MCP server at path: \(mcpServerPath)")
        
        // Check if the file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: mcpServerPath) else {
            let errorMessage = "MCP server executable not found at path: \(mcpServerPath)"
            logger.error("\(errorMessage)")
            print("ERROR: \(errorMessage)")
            throw MCPClientError.serverStartFailed(errorMessage)
        }
        
        print("MCP server executable found at: \(mcpServerPath)")
        
        // Create and configure the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: mcpServerPath)
        process.arguments = ["--debug"] // Add any necessary arguments
        
        // Set up pipes for communication
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Store references for later use
        self.process = process
        self.stdin = inputPipe.fileHandleForWriting
        self.stdout = outputPipe.fileHandleForReading
        
        // Set up error reading on a separate Task to avoid data races
        self.stderrPipe = errorPipe
        setupErrorReading(errorPipe: errorPipe)
        
        // Start the process
        do {
            try process.run()
            logger.info("MCP server started successfully")
            print("MCP server started successfully")
        } catch {
            logger.error("Failed to start MCP server: \(error.localizedDescription)")
            print("ERROR: Failed to start MCP server: \(error.localizedDescription)")
            throw MCPClientError.serverStartFailed(error.localizedDescription)
        }
    }
    
    /// Set up error reading in a way that avoids data races
    private func setupErrorReading(errorPipe: Pipe) {
        // Create a strong reference to the logger to avoid capturing self
        let errLogger = self.logger
        
        // Start a task that doesn't capture self
        Task {
            for try await line in errorPipe.fileHandleForReading.bytes.lines {
                errLogger.debug("MCP stderr: \(line)")
                print("MCP stderr: \(line)")
            }
        }
    }
    
    /// Stop the MCP server process
    func stopServer() {
        logger.info("Stopping MCP server")
        print("Stopping MCP server")
        
        // Clean shutdown
        if let process = self.process, process.isRunning {
            process.terminate()
        }
        
        // Close pipes
        try? stdin?.close()
        try? stdout?.close()
        try? stderrPipe?.fileHandleForReading.close()
        
        // Clear references
        self.process = nil
        self.stdin = nil
        self.stdout = nil
        self.stderrPipe = nil
        
        logger.info("MCP server stopped")
        print("MCP server stopped")
    }
    
    /// Send a request to the MCP server
    /// - Parameters:
    ///   - toolName: The name of the tool to call
    ///   - params: Tool parameters as [String: Any]
    /// - Returns: The response from the MCP server
    func sendRequest(toolName: String, params: [String: Any]) async throws -> Any {
        logger.debug("Sending request to MCP tool: \(toolName)", metadata: ["params": .string("\(params)")])
        print("Sending request to MCP tool: \(toolName) with params: \(params)")
        
        // Convert params to MCP Value format
        let mcpParams = convertToMCPValues(params)
        
        // Create MCP-formatted request
        let requestDict = createMCPRequest(toolName: toolName, params: mcpParams)
        
        // Convert to JSON string manually
        let requestData = try JSONSerialization.data(withJSONObject: requestDict, options: [])
        let requestString = String(data: requestData, encoding: .utf8)!
        
        logger.debug("MCP request: \(requestString)")
        print("MCP request JSON: \(requestString)")
        
        // Send the request
        guard let stdin = self.stdin else {
            print("ERROR: MCP server not running (stdin not available)")
            throw MCPClientError.serverNotRunning
        }
        
        // Send to server with newline
        do {
            try stdin.write(contentsOf: Data((requestString + "\n").utf8))
            logger.debug("Request sent to MCP server")
            print("Request sent to MCP server")
        } catch {
            logger.error("Failed to write to MCP server: \(error.localizedDescription)")
            print("ERROR: Failed to write to MCP server: \(error.localizedDescription)")
            throw MCPClientError.connectionClosed
        }
        
        // Read the response
        guard let stdout = self.stdout else {
            print("ERROR: MCP server not running (stdout not available)")
            throw MCPClientError.serverNotRunning
        }
        
        logger.debug("Reading response from MCP server")
        print("Reading response from MCP server")
        
        // Read response line
        var responseData = Data()
        
        repeat {
            do {
                // Read data from stdout
                logger.debug("Waiting for data from MCP server...")
                print("Waiting for data from MCP server...")
                if let data = try stdout.read(upToCount: 1024) {
                    logger.debug("Received \(data.count) bytes from MCP server")
                    print("Received \(data.count) bytes from MCP server")
                    
                    if data.isEmpty {
                        logger.error("Received empty data from MCP server")
                        print("ERROR: Received empty data from MCP server")
                        throw MCPClientError.connectionClosed
                    }
                    
                    // Check for newline
                    if let newlineIndex = data.firstIndex(of: 10) { // ASCII for newline
                        // Add bytes up to the newline
                        responseData.append(data[0..<newlineIndex])
                        logger.debug("Found newline, response complete")
                        print("Found newline, response complete")
                        break
                    }
                    
                    // Add all bytes read to response data
                    responseData.append(data)
                    logger.debug("Added data to response buffer, total size: \(responseData.count) bytes")
                    print("Added data to response buffer, total size: \(responseData.count) bytes")
                } else {
                    // No data available
                    logger.error("No data available from MCP server")
                    print("ERROR: No data available from MCP server")
                    throw MCPClientError.connectionClosed
                }
            } catch {
                logger.error("Error reading from MCP server: \(error.localizedDescription)")
                print("ERROR: Error reading from MCP server: \(error.localizedDescription)")
                throw MCPClientError.connectionClosed
            }
        } while true
        
        // Parse the response
        do {
            if let responseString = String(data: responseData, encoding: .utf8) {
                logger.debug("Raw response from MCP server: \(responseString)")
                print("Raw response from MCP server: \(responseString.prefix(100))...")
            }
            
            let responseJson = try JSONSerialization.jsonObject(with: responseData)
            logger.debug("Successfully parsed JSON response")
            print("Successfully parsed JSON response")
            return processResponse(responseJson)
        } catch {
            logger.error("Failed to parse MCP response: \(error.localizedDescription)")
            print("ERROR: Failed to parse MCP response: \(error.localizedDescription)")
            if let responseString = String(data: responseData, encoding: .utf8) {
                logger.error("Raw response that failed to parse: \(responseString)")
                print("Raw response that failed to parse: \(responseString.prefix(100))...")
            }
            throw MCPClientError.invalidResponse(String(data: responseData, encoding: .utf8) ?? "")
        }
    }
    
    /// Create an MCP-formatted request object
    private func createMCPRequest(toolName: String, params: [String: Value]) -> [String: Any] {
        // Convert Value objects to JSON-serializable values
        var serializedParams: [String: Any] = [:]
        for (key, value) in params {
            serializedParams[key] = convertValueToJSON(value)
        }
        
        return [
            "type": "tool_call",
            "tool": [
                "name": toolName,
                "parameters": serializedParams
            ]
        ]
    }
    
    /// Convert MCP Value to JSON-serializable value
    private func convertValueToJSON(_ value: Value) -> Any {
        switch value {
        case .string(let string):
            return string
        case .int(let int):
            return int
        case .double(let double):
            return double
        case .bool(let bool):
            return bool
        case .array(let array):
            return array.map { convertValueToJSON($0) }
        case .object(let dict):
            return dict.mapValues { convertValueToJSON($0) }
        case .null:
            return NSNull()
        default:
            return NSNull()
        }
    }
    
    /// Convert Swift dictionary to MCP Value format
    private func convertToMCPValues(_ params: [String: Any]) -> [String: Value] {
        var result = [String: Value]()
        
        for (key, value) in params {
            result[key] = convertToValue(value)
        }
        
        return result
    }
    
    /// Convert a Swift value to MCP Value type
    private func convertToValue(_ value: Any) -> Value {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .int(int)
        case let double as Double:
            return .double(double)
        case let bool as Bool:
            return .bool(bool)
        case let array as [Any]:
            return .array(array.map { convertToValue($0) })
        case let dict as [String: Any]:
            return .object(dict.mapValues { convertToValue($0) })
        default:
            return .null
        }
    }
    
    /// Process the MCP response
    private func processResponse(_ response: Any) -> Any {
        logger.debug("Processing response: \(response)")
        print("Processing response...")
        
        // Extract the relevant data from the response
        // This would depend on the exact format of MCP responses
        if let responseDict = response as? [String: Any],
           let content = responseDict["content"] as? [[String: Any]],
           let firstContent = content.first,
           let text = firstContent["text"] as? String {
            
            logger.debug("Extracted text content from response: \(text.prefix(50))...")
            print("Extracted text content from response: \(text.prefix(50))...")
            
            // Try to parse as JSON if it looks like JSON
            if text.hasPrefix("[") || text.hasPrefix("{") {
                do {
                    let jsonData = text.data(using: .utf8)!
                    let parsedJSON = try JSONSerialization.jsonObject(with: jsonData)
                    logger.debug("Successfully parsed content as JSON")
                    print("Successfully parsed content as JSON")
                    return parsedJSON
                } catch {
                    // If it's not valid JSON, return as string
                    logger.debug("Content couldn't be parsed as JSON, returning as string")
                    print("Content couldn't be parsed as JSON, returning as string")
                    return text
                }
            }
            
            return text
        }
        
        // Return the raw response if we can't extract structured data
        logger.debug("Could not extract content from response, returning raw response")
        print("Could not extract content from response, returning raw response")
        return response
    }
}

/// Error types for MCP client operations
enum MCPClientError: Swift.Error {
    case serverNotRunning
    case serverStartFailed(String)
    case connectionClosed
    case invalidResponse(String)
    
    var localizedDescription: String {
        switch self {
        case .serverNotRunning:
            return "MCP server is not running"
        case .serverStartFailed(let reason):
            return "Failed to start MCP server: \(reason)"
        case .connectionClosed:
            return "Connection to MCP server was closed unexpectedly"
        case .invalidResponse(let response):
            return "Invalid response from MCP server: \(response)"
        }
    }
}