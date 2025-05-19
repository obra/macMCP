// ABOUTME: ElementPathFilteringTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import XCTest

@testable import MacMCP

final class ElementPathFilteringTests: XCTestCase {
  // Test components
  private var toolChain: ToolChain!
  private var interfaceExplorerTool: InterfaceExplorerTool!
  private var uiInteractionService: UIInteractionService!
  private let calculatorBundleId = "com.apple.calculator"
  private var app: NSRunningApplication?
  
  // Custom logger for enhanced debug output
  private var debugLogger: Logger!
  private var fileLogHandler: FileLogHandler?
  private var testLogFileURL: URL?

  override func setUp() async throws {
    try await super.setUp()
    
    // Set up logging to file for debugging
    setupLogging()
    
    debugLogger.info("====== TEST SETUP STARTED ======")

    // Create the test components - this creates properly configured services
    toolChain = ToolChain(logLabel: "mcp.test.calculator")
    
    // Get references to the tools we'll use
    interfaceExplorerTool = toolChain.interfaceExplorerTool
    uiInteractionService = toolChain.interactionService
    
    // Make sure we're using the enhanced logging for relevant components
    enhanceLoggingForComponents()

    // Force terminate any existing instances of Calculator
    debugLogger.info("Terminating any existing Calculator instances")
    await terminateApplication(bundleId: calculatorBundleId)
    
    // Wait for termination to complete
    debugLogger.info("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    // Launch the Calculator app using the ApplicationManagementTool
    debugLogger.info("Launching Calculator...")
    let launchParams: [String: Value] = [
      "action": .string("launch"),
      "bundleIdentifier": .string(calculatorBundleId),
    ]
    
    // Launch Calculator
    let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)
    debugLogger.info("Launch result: \(launchResult)")
    
    // Wait for the app to launch fully
    debugLogger.info("Waiting for app to launch...")
    try await Task.sleep(for: .milliseconds(3000))
    
    // Check if app is running
    app = NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first
    debugLogger.info("Calculator running status: \(app != nil)")
    XCTAssertNotNil(app, "Failed to launch Calculator app")
    
    // Try to activate the app to ensure it's in the foreground
    if let runningApp = app {
      debugLogger.info("Activating Calculator...")
      let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
      debugLogger.info("Activation result: \(activated)")
    }
    
    // Give additional time for app to fully load
    try await Task.sleep(for: .milliseconds(1000))
    debugLogger.info("Setup complete - Calculator should be running")
  }

  override func tearDown() async throws {
    debugLogger.info("====== TEST TEARDOWN STARTED ======")
    
    // Terminate test application
    debugLogger.info("Terminating Calculator")
    await terminateApplication(bundleId: calculatorBundleId)
    app = nil
    
    // Wait for termination to complete
    debugLogger.info("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    toolChain = nil
    debugLogger.info("Removed toolChain")
    
    // Print log file location if available
    if let logURL = testLogFileURL {
      debugLogger.info("Test log available at: \(logURL.path)")
      print("For detailed debug info, check the log file at: \(logURL.path)")
    }
    
    debugLogger.info("====== TEST TEARDOWN COMPLETE ======")
    try await super.tearDown()
  }
  
  // MARK: - Logging Setup
  
  /// Set up enhanced logging for this test class
  private func setupLogging() {
    // Create a unique log file for this test run
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let sanitizedTimestamp = timestamp.replacingOccurrences(of: ":", with: "-")
    
    // Get the temporary directory
    let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
    let logFileName = "ElementPathFilteringTests-\(sanitizedTimestamp).log"
    let logFileURL = tempDir.appendingPathComponent(logFileName)
    testLogFileURL = logFileURL
    
    // Create the file handler
    let fileHandler = FileLogHandler(logFile: logFileURL)
    fileLogHandler = fileHandler
    
    // Create the combined logger with console and file output
    // We don't use bootstrap since it can only be called once per process
    let logger = Logger(label: "mcp.test.element_path_filtering") { _ in
      // Combine a console handler with the file handler
      let consoleHandler = StreamLogHandler.standardOutput(label: "mcp.test.console")
      return MultiplexLogHandler([
        consoleHandler,
        fileHandler
      ])
    }
    
    debugLogger = logger
    
    // Log initial info
    debugLogger.info("Initialized logging to file: \(logFileURL.path)")
    
    // Create a diagnostic log file specifically for accessibility tree
    let diagnosticFileName = "accessibility-tree-\(sanitizedTimestamp).log"
    let diagnosticPath = tempDir.appendingPathComponent(diagnosticFileName).path
    
    // Create an empty file
    do {
      try "DIAGNOSTIC LOG STARTED\n".write(toFile: diagnosticPath, atomically: true, encoding: .utf8)
      debugLogger.info("Created accessibility tree diagnostic log at: \(diagnosticPath)")
      // Set environment variable for UIInteractionService to use
      setenv("MCP_AX_DIAGNOSTIC_LOG", diagnosticPath, 1)
    } catch {
      debugLogger.error("Failed to create diagnostic log file: \(error)")
    }
  }
  
  /// Enhance the logging level for key components
  private func enhanceLoggingForComponents() {
    // Use reflection to access and modify the logger in UIInteractionService
    if let interactionService = uiInteractionService {
      let mirror = Mirror(reflecting: interactionService)
      for child in mirror.children {
        if child.label == "logger", let existingLogger = child.value as? Logger {
          // We can't modify the private logger directly, but we can log this info
          debugLogger.info("Found UIInteractionService logger: \(existingLogger)")
          
          // The ideal solution would be setting a different logger, but since we can't
          // do that directly, we'll use environment variables as a fallback
          setenv("MCP_LOG_LEVEL", "trace", 1)
          debugLogger.info("Set MCP_LOG_LEVEL=trace for enhanced logging")
        }
      }
    }
    
    // Enable additional debug flags for ElementPath resolution diagnostics
    setenv("MCP_PATH_RESOLUTION_DEBUG", "true", 1)
    debugLogger.info("Set MCP_PATH_RESOLUTION_DEBUG=true for path resolution diagnostics")
    
    // Enable attribute matching debug information
    setenv("MCP_ATTRIBUTE_MATCHING_DEBUG", "true", 1)
    debugLogger.info("Set MCP_ATTRIBUTE_MATCHING_DEBUG=true for attribute matching diagnostics")
    
    // Enable comprehensive AX hierarchy diagnostics 
    setenv("MCP_FULL_HIERARCHY_DEBUG", "true", 1)
    debugLogger.info("Set MCP_FULL_HIERARCHY_DEBUG=true for full hierarchy diagnostics")
  }

  /// Helper method to terminate an application
  private func terminateApplication(bundleId: String) async {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    debugLogger.info("Found \(runningApps.count) instances of \(bundleId) to terminate")
    for app in runningApps {
      let terminated = app.forceTerminate()
      debugLogger.info("Force termination result for \(bundleId): \(terminated)")
    }
  }
  
  /// Helper method to check if an application is running
  private func isApplicationRunning(_ bundleId: String) -> Bool {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    return !runningApps.isEmpty
  }

  // Helper to verify a path is fully qualified
  private func verifyFullyQualifiedPath(_ path: String?) {
    guard let path else {
      XCTFail("Path is nil")
      return
    }
    XCTAssertTrue(path.hasPrefix("ui://"), "Path doesn't start with ui://: \(path)")
    XCTAssertTrue(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
    XCTAssertTrue(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
    let separatorCount = path.components(separatedBy: "/").count - 1
    XCTAssertGreaterThanOrEqual(separatorCount, 1, "Path doesn't have enough segments: \(path)")
  }

  // Helper to run a request, verify, and always attempt a click
  private func runRequestAndVerify(
    _ request: [String: Value],
    extraAssertions: ((EnhancedElementDescriptor) -> Void)? = nil
  ) async throws {
    debugLogger.info("Running InterfaceExplorerTool with request: \(request)")
    
    let response = try await interfaceExplorerTool.handler(request)
    
    debugLogger.info("Got response with \(response.count) items")
    
    guard case .text(let jsonString) = response.first else {
      XCTFail("Failed to get valid response from tool")
      return
    }
    
    debugLogger.info("Response text length: \(jsonString.count) characters")
    
    // Print the first part of the response for debugging
    if jsonString.count > 0 {
      let previewLength = min(jsonString.count, 200)
      let startIndex = jsonString.startIndex
      let endIndex = jsonString.index(startIndex, offsetBy: previewLength)
      debugLogger.info("Response preview: \(jsonString[startIndex..<endIndex])...")
      
      // Save the full response to the log for detailed analysis
      debugLogger.trace("FULL RESPONSE JSON: \(jsonString)")
    }
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    
    do {
      let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
      
      debugLogger.info("Found \(descriptors.count) descriptors in response")
      
      if descriptors.isEmpty {
        // Check if app is still running
        let isStillRunning = isApplicationRunning(calculatorBundleId)
        debugLogger.warning("Is Calculator still running? \(isStillRunning)")
        
        // If the app is running but no elements found, try to diagnose
        if isStillRunning {
          debugLogger.warning("Calculator is running but no elements were found for the request")
          
          // Try a more basic request to see if any elements are visible
          debugLogger.info("Trying a basic request to see if Calculator is accessible")
          let basicRequest: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(2),
          ]
          
          do {
            let basicResponse = try await interfaceExplorerTool.handler(basicRequest)
            if let content = basicResponse.first, case .text(let basicJson) = content {
              debugLogger.info("Basic request response length: \(basicJson.count)")
              if basicJson.count > 0 {
                debugLogger.info("Calculator is accessible, but specific query returned no elements")
              }
            }
          } catch {
            debugLogger.error("Failed even with basic request: \(error)")
          }
        }
        
        XCTAssertFalse(descriptors.isEmpty, "No elements returned")
        return
      }
      
      for (i, descriptor) in descriptors.enumerated() {
        debugLogger.info("Descriptor \(i): \(descriptor.role) - \(descriptor.name)")
        verifyFullyQualifiedPath(descriptor.path)
        extraAssertions?(descriptor)
        debugLogger.info("Element path: \(descriptor.path ?? "nil")")
        if let children = descriptor.children {
          debugLogger.info("Element has \(children.count) children")
          for (j, child) in children.enumerated() {
            debugLogger.debug("  Child \(j): \(child.role) - \(child.name)")
            verifyFullyQualifiedPath(child.path)
          }
        }
      }
      
      // Always attempt a click if any element is found
      if let first = descriptors.first, let path = first.path {
        // Extract app bundle ID from path
        var appBundleId: String? = nil
        if let pathComponents = path.split(separator: "/").first {
          // Extract app bundle ID from path format like "ui://com.apple.calculator/AXApplication..."
          let uiPrefix = "ui://"
          if pathComponents.hasPrefix(uiPrefix) {
            let startIndex = pathComponents.index(pathComponents.startIndex, offsetBy: uiPrefix.count)
            let appIdEndIndex = pathComponents.firstIndex(of: "/") ?? pathComponents.endIndex
            if startIndex < appIdEndIndex {
              appBundleId = String(pathComponents[startIndex..<appIdEndIndex])
              debugLogger.info("Extracted app bundle ID: \(appBundleId ?? "nil")")
            }
          }
        }
        
        // Use our reflection capabilities to call the internal dumpAccessibilityTree method
        // Even though dumpAccessibilityTree is private, we can call it via the clickElementByPath
        // method which we've instrumented to dump the tree before attempting resolution
        
        // Log that we're about to perform the click (which will dump the tree)
        debugLogger.info("Attempting to click element at path: \(path)")
        do {
          try await uiInteractionService.clickElementByPath(path: path, appBundleId: appBundleId)
          debugLogger.info("Click appears to have succeeded")
        } catch {
          debugLogger.error("Click failed: \(error)")
          
          // Provide additional diagnostic information
          debugLogger.error("Failure details for path: \(path)")
          
          // For failures related to path resolution, check the diagnostic log
          if let diagnosticLogPath = ProcessInfo.processInfo.environment["MCP_AX_DIAGNOSTIC_LOG"] {
            debugLogger.error("Check diagnostic log for detailed accessibility tree: \(diagnosticLogPath)")
          }
          
          throw error
        }
      }
    } catch {
      debugLogger.error("Error decoding response: \(error)")
      XCTFail("Failed to decode response JSON: \(error)")
    }
  }
  
  // MARK: - Test Cases
  
  func testRoleFilteringFullPaths() async throws {
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    XCTAssertTrue(isRunning, "Calculator should be running before test")
    
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object([
        "role": .string("AXButton"),
        "description": .string("1"),
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
    }
  }

  func testElementTypeFilteringFullPaths() async throws {
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    XCTAssertTrue(isRunning, "Calculator should be running before test")
    
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]),
      "filter": .object([
        "description": .string("2")
      ]),
    ]
    try await runRequestAndVerify(request)
  }

  func testAttributeFilteringFullPaths() async throws {
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    XCTAssertTrue(isRunning, "Calculator should be running before test")
    
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object([
        "description": .string("3")
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertTrue(
        descriptor.description?.contains("3") ?? false, "Element doesn't match filter criteria")
    }
  }

  func testCombinedFilteringFullPaths() async throws {
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    XCTAssertTrue(isRunning, "Calculator should be running before test")
    
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]),
      "filter": .object([
        "description": .string("4")
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
      XCTAssertTrue(
        descriptor.description?.contains("4") ?? false, "Element doesn't match description criteria"
      )
    }
  }
}

// MARK: - FileLogHandler Implementation

/// A log handler that writes to a file
struct FileLogHandler: LogHandler {
  private let fileHandle: FileHandle
  private let logFile: URL
  
  public var logLevel: Logger.Level = .debug
  
  private var prettyMetadata: String?
  public var metadata = Logger.Metadata() {
    didSet {
      prettyMetadata = prettify(metadata)
    }
  }
  
  public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
    get {
      metadata[metadataKey]
    }
    set {
      metadata[metadataKey] = newValue
    }
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
      if let data = header.data(using: .utf8) {
        fileHandle.write(data)
      }
    } catch {
      fatalError("Failed to open log file: \(error)")
    }
  }
  
  public func log(level: Logger.Level, message: Logger.Message, metadata metadataOverride: Logger.Metadata?, file: String, function: String, line: UInt) {
    // Merge metadata, but we don't actually use it since we rely on prettyMetadata
    _ = mergedMetadata(metadataOverride)
    let metadataString = prettyMetadata ?? ""
    
    // Format the log message
    let timestamp = ISO8601DateFormatter().string(from: Date())
    var logMessage = "[\(timestamp)] [\(level)] \(message)"
    
    if !metadataString.isEmpty {
      logMessage += " -- \(metadataString)"
    }
    
    // Add file/line info for higher log levels
    if level >= .warning {
      logMessage += " (\(file):\(line) \(function))"
    }
    
    logMessage += "\n"
    
    // Write to file
    if let data = logMessage.data(using: .utf8) {
      fileHandle.write(data)
    }
  }
  
  // Support the new log method signature with source parameter
  public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
    log(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
  }
  
  private func mergedMetadata(_ metadataOverride: Logger.Metadata?) -> Logger.Metadata {
    var mergedMetadata = self.metadata
    
    if let metadataOverride = metadataOverride {
      for (key, value) in metadataOverride {
        mergedMetadata[key] = value
      }
    }
    
    return mergedMetadata
  }
  
  private func prettify(_ metadata: Logger.Metadata) -> String? {
    if metadata.isEmpty {
      return nil
    }
    
    return metadata.map { "\($0)=\($1)" }.joined(separator: " ")
  }
}