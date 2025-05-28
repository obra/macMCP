// ABOUTME: TestLogger.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging

/// Standardized logging utility for MacMCP tests
public class TestLogger {
  /// Creates a test logger with file output for detailed diagnostics
  /// - Parameters:
  ///   - label: The logger label, typically "mcp.test.<component>"
  ///   - testName: Name of the test (defaults to class name)
  /// - Returns: Configured logger with console and file output
  public static func create(label: String, testName: String? = nil) -> (
    logger: Logger, logFileURL: URL?
  ) {
    // Create a unique log file for this test run
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let sanitizedTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
    // Get the temporary directory
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    let logFileName = "\(testName ?? label)-\(sanitizedTimestamp).log"
    let logFileURL = tempDir.appendingPathComponent(logFileName)
    // Create the file handler
    let fileHandler = FileLogHandler(logFile: logFileURL)
    // Create the combined logger with console and file output
    let logger = Logger(label: label) { _ in
      // Combine a console handler with the file handler
      let consoleHandler = StreamLogHandler.standardOutput(label: "\(label).console")
      return MultiplexLogHandler([consoleHandler, fileHandler])
    }
    // Set default log level from environment if available
    if let logLevelString = ProcessInfo.processInfo.environment["MCP_TEST_LOG_LEVEL"],
      let logLevel = Logger.Level(rawValue: logLevelString.lowercased())
    {
      // We can't modify the logger's log level directly, but this will be read
      logger.debug("Setting log level to \(logLevel) from environment")
    }
    // Log initial info
    logger.debug("Initialized logging to file: \(logFileURL.path)")
    return (logger, logFileURL)
  }
  /// Sets up common environment variables for enhanced test logging
  public static func configureEnvironment(logger: Logger) {
    // Enable trace level logging
    setenv("MCP_LOG_LEVEL", "trace", 1)
    logger.debug("Set MCP_LOG_LEVEL=trace for enhanced logging")
    // Enable additional debug flags for ElementPath resolution diagnostics
    setenv("MCP_PATH_RESOLUTION_DEBUG", "true", 1)
    logger.debug("Set MCP_PATH_RESOLUTION_DEBUG=true for path resolution diagnostics")
    // Enable attribute matching debug information
    setenv("MCP_ATTRIBUTE_MATCHING_DEBUG", "true", 1)
    logger.debug("Set MCP_ATTRIBUTE_MATCHING_DEBUG=true for attribute matching diagnostics")
    // Enable comprehensive AX hierarchy diagnostics
    setenv("MCP_FULL_HIERARCHY_DEBUG", "true", 1)
    logger.debug("Set MCP_FULL_HIERARCHY_DEBUG=true for full hierarchy diagnostics")
  }
  /// Creates a diagnostic log file for detailed accessibility info
  public static func createDiagnosticLog(testName: String, logger: Logger) -> String? {
    // Create a unique log file
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let sanitizedTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
    // Get the temporary directory
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    let diagnosticFileName = "\(testName)-accessibility-\(sanitizedTimestamp).log"
    let diagnosticPath = tempDir.appendingPathComponent(diagnosticFileName).path
    // Create an empty file
    do {
      try "DIAGNOSTIC LOG STARTED\n".write(
        toFile: diagnosticPath, atomically: true, encoding: .utf8)
      logger.debug("Created accessibility tree diagnostic log at: \(diagnosticPath)")
      // Set environment variable for UIInteractionService to use
      setenv("MCP_AX_DIAGNOSTIC_LOG", diagnosticPath, 1)
      return diagnosticPath
    } catch {
      logger.error("Failed to create diagnostic log file: \(error)")
      return nil
    }
  }
}

/// A log handler that writes to a file
public struct FileLogHandler: LogHandler {
  private let fileHandle: FileHandle
  private let logFile: URL
  public var logLevel: Logger.Level = .debug
  private var prettyMetadata: String?
  public var metadata = Logger.Metadata() { didSet { prettyMetadata = prettify(metadata) } }
  public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
    get { metadata[metadataKey] }
    set { metadata[metadataKey] = newValue }
  }
  public init(logFile: URL) {
    self.logFile = logFile
    // Create an empty file if it doesn't exist
    if !FileManager.default.fileExists(atPath: logFile.path) {
      FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }
    // Open file for writing
    do {
      let fileHandle = try FileHandle(forWritingTo: logFile)
      self.fileHandle = fileHandle
      // Write header
      let header = "===== LOG STARTED AT \(Date()) =====\n"
      if let data = header.data(using: .utf8) { fileHandle.write(data) }
    } catch { fatalError("Failed to open log file: \(error)") }
  }
  public func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata metadataOverride: Logger.Metadata?,
    file: String,
    function: String,
    line: UInt
  ) {
    // Merge metadata
    let mergedMeta = mergedMetadata(metadataOverride)
    let metadataString = prettify(mergedMeta) ?? ""
    // Format the log message
    let timestamp = ISO8601DateFormatter().string(from: Date())
    var logMessage = "[\(timestamp)] [\(level)] \(message)"
    if !metadataString.isEmpty { logMessage += " -- \(metadataString)" }
    // Add file/line info for higher log levels
    if level >= .warning { logMessage += " (\(file):\(line) \(function))" }
    logMessage += "\n"
    // Write to file
    if let data = logMessage.data(using: .utf8) { fileHandle.write(data) }
  }
  // Support the new log method signature with source parameter
  public func log(
    level: Logger.Level,
    message: Logger.Message,
    metadata: Logger.Metadata?,
    source: String,
    file: String,
    function: String,
    line: UInt
  ) {
    log(
      level: level, message: message, metadata: metadata, file: file, function: function, line: line
    )
  }
  private func mergedMetadata(_ metadataOverride: Logger.Metadata?) -> Logger.Metadata {
    var mergedMetadata = self.metadata
    if let metadataOverride = metadataOverride {
      for (key, value) in metadataOverride { mergedMetadata[key] = value }
    }
    return mergedMetadata
  }
  private func prettify(_ metadata: Logger.Metadata) -> String? {
    if metadata.isEmpty { return nil }
    return metadata.map { "\($0)=\($1)" }.joined(separator: " ")
  }
}
