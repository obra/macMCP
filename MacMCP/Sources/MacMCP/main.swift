// ABOUTME: main.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import ArgumentParser
import Foundation
import Logging
import MCP

// Check for direct invocation (when no arguments are provided)
// This is important for the Claude desktop app which launches the MCP server without arguments
if CommandLine.arguments.count <= 1 {
  // Configure logging to stderr only (never stdout)
  let logger = Logger(label: "mcp.macos") { label in
    var handler = StreamLogHandler.standardError(label: label)

    // Check for test environment
    let isTestEnvironment =
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // Check for environment variable to override log level
    if let logLevelEnv = ProcessInfo.processInfo.environment["MCP_LOG_LEVEL"],
      let specifiedLevel = Logger.Level(rawValue: logLevelEnv.lowercased())
    {
      handler.logLevel = specifiedLevel
    } else if isTestEnvironment {
      // Default to warning level for tests to reduce noise
      handler.logLevel = .warning
    } else {
      // Default to debug level logging for normal operation
      handler.logLevel = .debug
    }

    return handler
  }

  // Direct execution mode - start the server immediately without using ArgumentParser
  // This avoids any help text being output to stdout which breaks the MCP protocol
  // Log direct mode startup
  logger.debug("Starting MacMCP server in direct mode (Claude desktop)")
  logger.debug("Working directory: \(FileManager.default.currentDirectoryPath)")
  logger.debug("Arguments: \(CommandLine.arguments)")

  // Create the server with debug logging
  let server = MCPServer(logger: logger, )
  logger.debug("Created MCPServer instance")

  // Create the transport
  let transport = StdioTransport(logger: logger)
  logger.debug("Created StdioTransport")

  // Run the server in a task to avoid blocking
  Task {
    do {
      logger.debug("Starting server with transport")
      try await server.start(transport: transport)
      logger.debug("Server started successfully in direct mode")
      logger.debug("Waiting for completion")
      await server.waitUntilCompleted()
      logger.debug("Server completed")
    } catch {
      logger.error("Failed to start server in direct mode", metadata: ["error": "\(error)"])
      logger.error("Stack trace: \(Thread.callStackSymbols.joined(separator: "\n"))")
      fatalError("Server failed to start: \(error)")
    }
  }

  // Log that we're entering the run loop
  logger.debug("Entering main run loop")

  // Keep the main thread running
  RunLoop.main.run()

  // This should not be reached
  logger.debug("Exiting main run loop (this is unexpected)")
  exit(0)
}

// If we reach here, the tool was invoked with arguments, so use ArgumentParser
struct MacMCPCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mac-mcp",
    abstract: "macOS Model Context Protocol (MCP) Server",
    discussion: """
      This tool provides a macOS MCP server that connects AI assistants 
      to macOS through the accessibility APIs.
      """,
    version: "0.1.0",
  )

  @Flag(name: .long, help: "Enable debug logging") var debug = false

  mutating func run() async throws {
    // Configure logging
    var logLevel: Logger.Level = debug ? .debug : .info

    // Check for test environment
    let isTestEnvironment =
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // Check for environment variable to override log level
    if let logLevelEnv = ProcessInfo.processInfo.environment["MCP_LOG_LEVEL"],
      let specifiedLevel = Logger.Level(rawValue: logLevelEnv.lowercased())
    {
      logLevel = specifiedLevel
    } else if isTestEnvironment {
      // Default to warning level for tests to reduce noise
      logLevel = .warning
    }

    let logger = Logger(label: "mcp.macos") { label in
      var handler = StreamLogHandler.standardError(label: label)
      handler.logLevel = logLevel
      return handler
    }

    logger.info("Starting macOS MCP Server (CLI mode)")

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

// Execute the command parser only when arguments are provided
MacMCPCommand.main()
