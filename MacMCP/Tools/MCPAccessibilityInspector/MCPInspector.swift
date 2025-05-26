// ABOUTME: MCPInspector.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Cocoa
import Foundation
import Logging
import MCP

#if canImport(System)
  import System
#else
  @preconcurrency import SystemPackage
#endif

// Configure a logger for the inspector
private let inspectorLogger = Logger(label: "com.fsck.mac-mcp.mcp-inspector")

/// The main inspector class responsible for accessibility tree traversal using MCP tools
class MCPInspector: @unchecked Sendable {
  let appId: String?  // Changed to public access for menu and window helpers
  private let pid: Int?
  private let maxDepth: Int
  private var elementIndex = 0

  // Official MCP client for communicating with the MCP server
  var mcpClient: Client?  // Changed to public access for use by menu and window helpers
  private var transport: StdioTransport?
  private var process: Process?

  init(appId: String?, pid: Int?, maxDepth: Int, mcpPath: String? = nil) {
    self.appId = appId
    self.pid = pid
    self.maxDepth = maxDepth

    // Set up MCP path
    let serverPath = mcpPath ?? "./MacMCP"  // Default to local directory if not specified
    print("Using MCP server at: \(serverPath)")

    // Create a process for the MCP server
    let process = Process()
    process.executableURL = URL(fileURLWithPath: serverPath)
    process.arguments = []  // No arguments, just run in standard mode

    // Set up pipes for stdin/stdout
    let inPipe = Pipe()
    let outPipe = Pipe()
    let errPipe = Pipe()

    process.standardInput = inPipe
    process.standardOutput = outPipe
    process.standardError = errPipe

    // Store process for later use
    self.process = process

    // Set up error pipe reader to monitor MCP server output
    Task {
      for try await line in errPipe.fileHandleForReading.bytes.lines {
        print("MCP server stderr: \(line)")
      }
    }

    // Create client
    mcpClient = Client(name: "MCPAXInspector", version: "1.0.0")

    // Create stdio transport using the pipes
    transport = StdioTransport(
      input: FileDescriptor(rawValue: outPipe.fileHandleForReading.fileDescriptor),
      output: FileDescriptor(rawValue: inPipe.fileHandleForWriting.fileDescriptor),
      logger: inspectorLogger,
    )
  }

  /// Inspects the application and returns the root UI element node
  func inspectApplication(pathFilter: String? = nil) async throws -> MCPUIElementNode {
    inspectorLogger.info(
      "Inspecting application",
      metadata: ["appId": .string(appId ?? ""), "pid": .stringConvertible(pid ?? 0)],
    )

    // Verify we have either an app ID or PID
    guard appId != nil || pid != nil else {
      throw InspectionError.applicationNotFound
    }

    // Start MCP server if needed
    try await startMCPIfNeeded()

    // Find application bundle ID - either directly provided or derived from PID
    let bundleId: String
    if let appId {
      bundleId = appId
    } else if let pid {
      // Convert PID to bundle ID using NSRunningApplication
      guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
        throw InspectionError.applicationNotFound
      }
      guard let appBundle = app.bundleIdentifier else {
        throw InspectionError.applicationNotFound
      }
      bundleId = appBundle
    } else {
      throw InspectionError.applicationNotFound
    }

    // If we have a path filter, process it properly based on its format
    if let pathFilter {
      if pathFilter.hasPrefix("macos://ui/") {
        // This is a complete path - use server-side path resolution
        print("Using server-side path resolution for: \(pathFilter)")
        do {
          return try await inspectElementByPath(
            bundleId: bundleId,
            path: pathFilter,
            maxDepth: maxDepth,
          )
        } catch {
          // If path-based inspection fails, fall back to normal app inspection
          print("Path-based inspection failed with error: \(error.localizedDescription)")
          print("Falling back to standard application inspection")
          // Continue with standard app inspection
        }
      } else {
        // This is a UI element filter pattern, not a path
        print("Using filter pattern: \(pathFilter)")

        // Parse the filter pattern to extract role and attributes
        if let (role, attributes) = parseFilterPattern(pathFilter) {
          // Use parsed information to create appropriate filter parameters
          return try await fetchFilteredUIStateData(
            bundleId: bundleId,
            role: role,
            attributes: attributes,
            maxDepth: maxDepth,
          )
        }
      }
    }

    // Use MCP's InterfaceExplorerTool to get UI information if no filter or filter parsing failed
    let uiState = try await fetchUIStateData(bundleId: bundleId, maxDepth: maxDepth)

    // Process the UI state
    do {
      // UI state is returned as a [Tool.Content] array with text content
      guard let firstContent = uiState.content.first,
        case .text(let jsonString) = firstContent
      else {
        throw InspectionError.unexpectedError(
          "Invalid response format from MCP: missing text content")
      }

      // Convert the JSON string to data
      guard let jsonData = jsonString.data(using: .utf8) else {
        throw InspectionError.unexpectedError("Failed to convert JSON string to data")
      }

      // Parse the JSON into an array of dictionaries
      let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
      guard let rootJson = jsonArray?.first else {
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
      throw InspectionError.unexpectedError(
        "Failed to parse UI state: \(error.localizedDescription)")
    }
  }

  /// Start the MCP server if it's not already running
  private func startMCPIfNeeded() async throws {
    guard let process, let transport, let mcpClient else {
      throw InspectionError.unexpectedError("MCP client not initialized properly")
    }

    // Start the MCP server process if not already running
    if !process.isRunning {
      print("Starting MCP server process...")
      try process.run()

      // Connect the transport to the server
      try await transport.connect()

      // Connect the client to the transport
      try await mcpClient.connect(transport: transport)

      // Initialize the client
      print("Initializing MCP client...")
      _ = try await mcpClient.initialize()

      // Test connectivity with ping
      try await mcpClient.ping()
      print("Successfully connected to MCP server")
    }
  }

  /// Fetches UI state data from MCP InterfaceExplorerTool, enhanced with menu and window data
  private func fetchUIStateData(bundleId: String, maxDepth: Int) async throws
    -> CallTool.Result
  {
    guard let mcpClient else {
      throw InspectionError.unexpectedError("MCP client not initialized")
    }

    // Create the request parameters for the InterfaceExplorerTool (replacing the older UIStateTool)
    let arguments: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(bundleId),
      "maxDepth": .int(maxDepth),
      "includeHidden": .bool(true),  // Include all elements for completeness
    ]

    // Send request to the MCP server using the new tool name
    do {
      print("Sending interface explorer request to MCP for: \(bundleId)")
      let (content, isError) = try await mcpClient.callTool(
        name: "macos_explore_ui",  // Updated tool name
        arguments: arguments,
      )

      if let isError, isError {
        throw InspectionError.unexpectedError("Error from MCP tool: \(content)")
      }

      // Menu and window details are now handled by the AsyncInspectionTask

      // For now, we'll still just return the interface explorer content
      // In a more complete implementation, we'd merge the menu and window data
      return CallTool.Result(content: content)
    } catch {
      inspectorLogger.error("Failed to fetch UI state data: \(error.localizedDescription)")
      print("ERROR: Detailed interface explorer error: \(error)")
      throw InspectionError.unexpectedError(
        "Failed to fetch UI state: \(error.localizedDescription)")
    }
  }

  /// Fetches UI state data using a specific element path
  func inspectElementByPath(bundleId: String, path: String, maxDepth: Int) async throws
    -> MCPUIElementNode
  {
    print("Inspecting element by path: \(path) in application: \(bundleId)")
    guard let mcpClient else {
      throw InspectionError.unexpectedError("MCP client not initialized")
    }

    // Start MCP server if needed
    try await startMCPIfNeeded()

    // Create the request parameters for the InterfaceExplorerTool with element path parameter
    let arguments: [String: Value] = [
      "scope": .string("path"),
      "bundleId": .string(bundleId),
      "id": .string(path),  // Use the path parameter for path-based lookup
      "maxDepth": .int(maxDepth),
      "includeHidden": .bool(true),  // Include all elements for completeness
    ]

    // Send request to the MCP server
    do {
      print("Sending element path request to MCP: \(path)")
      let (content, isError) = try await mcpClient.callTool(
        name: "macos_explore_ui",
        arguments: arguments,
      )

      if let isError, isError {
        throw InspectionError.unexpectedError("Error from MCP tool: \(content)")
      }

      // Process the response
      guard let firstContent = content.first,
        case .text(let jsonString) = firstContent
      else {
        throw InspectionError.unexpectedError(
          "Invalid response format from MCP: missing text content")
      }

      // Convert the JSON string to data
      guard let jsonData = jsonString.data(using: .utf8) else {
        throw InspectionError.unexpectedError("Failed to convert JSON string to data")
      }

      // Parse the JSON into an array of dictionaries
      let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
      guard let rootJson = jsonArray?.first else {
        throw InspectionError.unexpectedError("Invalid JSON response from MCP or element not found")
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
      inspectorLogger.error("Failed to fetch element by path: \(error.localizedDescription)")
      print("ERROR: Element path inspection error: \(error)")
      throw InspectionError.unexpectedError(
        "Failed to fetch element by path: \(error.localizedDescription)")
    }
  }

  /// Parse a filter pattern like "AXButton[@AXDescription=\"1\"]" into role and attributes
  private func parseFilterPattern(_ pattern: String) -> (
    role: String, attributes: [String: String]
  )? {
    // Simple regex-based parsing logic
    // Extract role (everything before any [ character)
    var role: String?
    var attributes: [String: String] = [:]

    // Extract role
    if let roleEndIndex = pattern.firstIndex(of: "[") {
      role = String(pattern[..<roleEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      // If no attributes are specified, the whole string is the role
      role = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Extract attributes using regex - support both [@attr="value"] and [attr="value"] formats
    let attributePattern = "\\[@?([^=]+)=\"([^\"]+)\"\\]"
    let regex = try? NSRegularExpression(pattern: attributePattern)
    let nsRange = NSRange(pattern.startIndex..<pattern.endIndex, in: pattern)

    if let regex {
      let matches = regex.matches(in: pattern, options: [], range: nsRange)
      for match in matches {
        // Extract attribute name and value
        if match.numberOfRanges == 3,
          let nameRange = Range(match.range(at: 1), in: pattern),
          let valueRange = Range(match.range(at: 2), in: pattern)
        {
          let name = String(pattern[nameRange])
          let value = String(pattern[valueRange])
          attributes[name] = value
        }
      }
    }

    guard let extractedRole = role else {
      return nil
    }

    return (extractedRole, attributes)
  }

  /// Fetch UI state with specific filter criteria
  private func fetchFilteredUIStateData(
    bundleId: String,
    role: String,
    attributes: [String: String],
    maxDepth: Int,
  ) async throws -> MCPUIElementNode {
    guard let mcpClient else {
      throw InspectionError.unexpectedError("MCP client not initialized")
    }

    // Start MCP server if needed
    try await startMCPIfNeeded()

    // Create filter for InterfaceExplorerTool
    var filter: [String: Value] = [:]

    // Add role filter
    filter["role"] = .string(role)

    // Add attribute filters - make sure we only set the attributes actually supported by the API
    for (key, value) in attributes {
      if key.lowercased().contains("title") {
        filter["titleContains"] = .string(value)
      } else if key.lowercased().contains("description") {
        filter["descriptionContains"] = .string(value)
      } else if key.lowercased().contains("value") {
        filter["valueContains"] = .string(value)
      }
    }

    // Create the request parameters
    let arguments: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(bundleId),
      "maxDepth": .int(maxDepth),
      "includeHidden": .bool(true),
    ]

    // Send request to MCP
    print("Sending filtered request to MCP for: \(bundleId) with filter: \(filter)")
    print("DEBUG: role=\(role), attributes=\(attributes)")
    // Add the filter to the arguments
    var argumentsWithFilter = arguments
    argumentsWithFilter["filter"] = .object(filter)

    let (content, isError) = try await mcpClient.callTool(
      name: "macos_explore_ui",
      arguments: argumentsWithFilter,
    )

    if let isError, isError {
      throw InspectionError.unexpectedError("Error from MCP tool: \(content)")
    }

    // Process the response
    guard let firstContent = content.first,
      case .text(let jsonString) = firstContent
    else {
      throw InspectionError.unexpectedError(
        "Invalid response format from MCP: missing text content")
    }

    // Convert the JSON string to data and create a node
    guard let jsonData = jsonString.data(using: .utf8) else {
      throw InspectionError.unexpectedError("Failed to convert JSON string to data")
    }

    // Parse the JSON into an array of dictionaries
    let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
    guard let rootJson = jsonArray?.first else {
      throw InspectionError.unexpectedError(
        "Invalid JSON response from MCP or no matching elements found")
    }

    // Reset element counter
    elementIndex = 0

    // Create the root node
    let rootNode = MCPUIElementNode(jsonElement: rootJson, index: elementIndex)
    elementIndex += 1

    // Recursively populate children
    _ = rootNode.populateChildren(from: rootJson, startingIndex: elementIndex)

    return rootNode
  }

  // Menu and window details fetching now handled in AsyncInspectionTask

  /// Cleanup resources - call this method explicitly before deallocation
  func cleanup() async {
    // Disconnect the client
    await mcpClient?.disconnect()

    // Terminate the process
    process?.terminate()
    process = nil
  }

  /// Synchronous version of cleanup for use with synchronous code
  func cleanupSync() {
    // Save references locally to avoid capturing self in Task
    let client = mcpClient
    let proc = process

    // Create a semaphore to wait for task completion
    let semaphore = DispatchSemaphore(value: 0)

    // Create a task to handle the async cleanup with @Sendable to avoid capture issues
    Task { @Sendable in
      // Disconnect the client if it exists
      if let client {
        await client.disconnect()
      }

      // Signal semaphore when done
      semaphore.signal()
    }

    // Wait for the semaphore with a timeout (5 seconds)
    _ = semaphore.wait(timeout: .now() + 5.0)

    // Terminate the process synchronously after client disconnect
    proc?.terminate()
  }

  /// Deinit - automatically trigger cleanup
  deinit {
    // Weakly capture self to avoid deinit retention
    let client = mcpClient
    let proc = process

    // Create a detached task for cleanup that doesn't reference self
    Task.detached {
      // Disconnect the client if it exists
      if let client {
        await client.disconnect()
      }

      // Terminate the process if it exists
      proc?.terminate()
    }
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
      "Accessibility permission denied. Please enable accessibility permissions in System Settings > Privacy & Security > Accessibility."
    case .applicationNotFound:
      "Application not found. Please verify the bundle ID or process ID."
    case .timeout:
      "Operation timed out. The application may be busy or not responding."
    case .unexpectedError(let message):
      "Unexpected error: \(message)"
    }
  }
}
