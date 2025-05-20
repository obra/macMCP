// ABOUTME: ElementPathFilteringTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized)
struct ElementPathFilteringTests {
  // Test components
  private var toolChain: ToolChain!
  private var interfaceExplorerTool: InterfaceExplorerTool!
  private var uiInteractionService: UIInteractionService!
  private let calculatorBundleId = "com.apple.calculator"
  private var app: NSRunningApplication?
  
  // Logger for test output
  private var logger: Logger!
  private var logFileURL: URL?
  private var diagnosticLogPath: String?

  private mutating func setUp() async throws {
    // No super.setUp() call needed for struct
    
    // Set up logging to file for debugging
    (logger, logFileURL) = TestLogger.create(label: "mcp.test.element_path_filtering", testName: "ElementPathFilteringTests")
    TestLogger.configureEnvironment(logger: logger)
    diagnosticLogPath = TestLogger.createDiagnosticLog(testName: "ElementPathFilteringTests", logger: logger)
    
    logger.debug("====== TEST SETUP STARTED ======")

    // Create the test components - this creates properly configured services
    toolChain = ToolChain(logLabel: "mcp.test.calculator")
    
    // Get references to the tools we'll use
    interfaceExplorerTool = toolChain.interfaceExplorerTool
    uiInteractionService = toolChain.interactionService
    
    // Make sure we're using the enhanced logging for relevant components
    enhanceLoggingForComponents()

    // Force terminate any existing instances of Calculator
    logger.debug("Terminating any existing Calculator instances")
    await terminateApplication(bundleId: calculatorBundleId)
    
    // Wait for termination to complete
    logger.debug("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    // Launch the Calculator app using the ApplicationManagementTool
    logger.debug("Launching Calculator...")
    let launchParams: [String: Value] = [
      "action": .string("launch"),
      "bundleIdentifier": .string(calculatorBundleId),
    ]
    
    // Launch Calculator
    let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)
    logger.debug("Launch result: \(launchResult)")
    
    // Wait for the app to launch fully
    logger.debug("Waiting for app to launch...")
    try await Task.sleep(for: .milliseconds(3000))
    
    // Check if app is running
    app = NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first
    logger.debug("Calculator running status: \(app != nil)")
    #expect(app != nil, "Failed to launch Calculator app")
    
    // Try to activate the app to ensure it's in the foreground
    if let runningApp = app {
      logger.debug("Activating Calculator...")
      let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
      logger.debug("Activation result: \(activated)")
    }
    
    // Give additional time for app to fully load
    try await Task.sleep(for: .milliseconds(1000))
    logger.debug("Setup complete - Calculator should be running")
  }

  private mutating func tearDown() async throws {
    logger.debug("====== TEST TEARDOWN STARTED ======")
    
    // Terminate test application
    logger.debug("Terminating Calculator")
    await terminateApplication(bundleId: calculatorBundleId)
    app = nil
    
    // Wait for termination to complete
    logger.debug("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    toolChain = nil
    logger.debug("Removed toolChain")
    
    // Print log file location if available
    if let logURL = logFileURL {
      logger.debug("Test log available at: \(logURL.path)")
      print("For detailed debug info, check the log file at: \(logURL.path)")
    }
    
    if let diagnosticPath = diagnosticLogPath {
      logger.debug("Accessibility diagnostic log available at: \(diagnosticPath)")
    }
    
    logger.debug("====== TEST TEARDOWN COMPLETE ======")
    // No super.tearDown() call needed for struct
  }
  
  // MARK: - Logging Setup
  
  /// Enhance the logging level for key components
  private func enhanceLoggingForComponents() {
    // Use reflection to access and modify the logger in UIInteractionService
    if let interactionService = uiInteractionService {
      let mirror = Mirror(reflecting: interactionService)
      for child in mirror.children {
        if child.label == "logger", let existingLogger = child.value as? Logger {
          // We can't modify the private logger directly, but we can log this info
          logger.debug("Found UIInteractionService logger: \(existingLogger)")
          
          // The ideal solution would be setting a different logger, but since we can't
          // do that directly, we'll use environment variables as a fallback
          setenv("MCP_LOG_LEVEL", "trace", 1)
          logger.debug("Set MCP_LOG_LEVEL=trace for enhanced logging")
        }
      }
    }
    
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

  /// Helper method to terminate an application
  private func terminateApplication(bundleId: String) async {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    logger.debug("Found \(runningApps.count) instances of \(bundleId) to terminate")
    for app in runningApps {
      let terminated = app.forceTerminate()
      logger.debug("Force termination result for \(bundleId): \(terminated)")
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
      #expect(Bool(false), "Path is nil")
      return
    }
    #expect(path.hasPrefix("ui://"), "Path doesn't start with ui://: \(path)")
    #expect(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
    #expect(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
    let separatorCount = path.components(separatedBy: "/").count - 1
    #expect(separatorCount >= 1, "Path doesn't have enough segments: \(path)")
  }

  // Helper to run a request, verify, and always attempt a click
  private func runRequestAndVerify(
    _ request: [String: Value],
    extraAssertions: ((EnhancedElementDescriptor) -> Void)? = nil
  ) async throws {
    logger.debug("Running InterfaceExplorerTool with request: \(request)")
    
    let response = try await interfaceExplorerTool.handler(request)
    
    logger.debug("Got response with \(response.count) items")
    
    guard case .text(let jsonString) = response.first else {
      #expect(Bool(false), "Failed to get valid response from tool")
      return
    }
    
    logger.debug("Response text length: \(jsonString.count) characters")
    
    // Print the first part of the response for debugging
    if jsonString.count > 0 {
      let previewLength = min(jsonString.count, 200)
      let startIndex = jsonString.startIndex
      let endIndex = jsonString.index(startIndex, offsetBy: previewLength)
      logger.debug("Response preview: \(jsonString[startIndex..<endIndex])...")
      
      // Save the full response to the log for detailed analysis
      logger.trace("FULL RESPONSE JSON: \(jsonString)")
    }
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    
    do {
      let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
      
      logger.debug("Found \(descriptors.count) descriptors in response")
      
      if descriptors.isEmpty {
        // Check if app is still running
        let isStillRunning = isApplicationRunning(calculatorBundleId)
        logger.warning("Is Calculator still running? \(isStillRunning)")
        
        // If the app is running but no elements found, try to diagnose
        if isStillRunning {
          logger.warning("Calculator is running but no elements were found for the request")
          
          // Try a more basic request to see if any elements are visible
          logger.debug("Trying a basic request to see if Calculator is accessible")
          let basicRequest: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(2),
          ]
          
          do {
            let basicResponse = try await interfaceExplorerTool.handler(basicRequest)
            if let content = basicResponse.first, case .text(let basicJson) = content {
              logger.debug("Basic request response length: \(basicJson.count)")
              if basicJson.count > 0 {
                logger.debug("Calculator is accessible, but specific query returned no elements")
              }
            }
          } catch {
            logger.error("Failed even with basic request: \(error)")
          }
        }
        
        #expect(!descriptors.isEmpty, "No elements returned")
        return
      }
      
      for (i, descriptor) in descriptors.enumerated() {
        logger.debug("Descriptor \(i): \(descriptor.role) - \(descriptor.name)")
        verifyFullyQualifiedPath(descriptor.id)
        extraAssertions?(descriptor)
        logger.debug("Element path: \(descriptor.id)")
        if let children = descriptor.children {
          logger.debug("Element has \(children.count) children")
          for (j, child) in children.enumerated() {
            logger.debug("  Child \(j): \(child.role) - \(child.name)")
            verifyFullyQualifiedPath(child.id)
          }
        }
      }
      
      // Always attempt a click if any element is found
      if let first = descriptors.first {
        // Extract app bundle ID from path
        var appBundleId: String? = nil
        let path = first.id
        if let pathComponents = path.split(separator: "/").first {
          // Extract app bundle ID from path format like "ui://com.apple.calculator/AXApplication..."
          let uiPrefix = "ui://"
          if pathComponents.hasPrefix(uiPrefix) {
            let startIndex = pathComponents.index(pathComponents.startIndex, offsetBy: uiPrefix.count)
            let appIdEndIndex = pathComponents.firstIndex(of: "/") ?? pathComponents.endIndex
            if startIndex < appIdEndIndex {
              appBundleId = String(pathComponents[startIndex..<appIdEndIndex])
              logger.debug("Extracted app bundle ID: \(appBundleId ?? "nil")")
            }
          }
        }
        
        // Use our reflection capabilities to call the internal dumpAccessibilityTree method
        // Even though dumpAccessibilityTree is private, we can call it via the clickElementByPath
        // method which we've instrumented to dump the tree before attempting resolution
        
        // Log that we're about to perform the click (which will dump the tree)
        logger.debug("Attempting to click element at path: \(path)")
        do {
          try await uiInteractionService.clickElementByPath(path: path, appBundleId: appBundleId)
          logger.debug("Click appears to have succeeded")
        } catch {
          logger.error("Click failed: \(error)")
          
          // Provide additional diagnostic information
          logger.error("Failure details for path: \(path)")
          
          // For failures related to path resolution, check the diagnostic log
          if let diagnosticLogPath = ProcessInfo.processInfo.environment["MCP_AX_DIAGNOSTIC_LOG"] {
            logger.error("Check diagnostic log for detailed accessibility tree: \(diagnosticLogPath)")
          }
          
          throw error
        }
      }
    } catch {
      logger.error("Error decoding response: \(error)")
      #expect(Bool(false), "Failed to decode response JSON: \(error)")
    }
  }
  
  // MARK: - Test Cases
  
  @Test("Role filtering with full paths")
  mutating func testRoleFilteringFullPaths() async throws {
    try await setUp()
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running before test")
    
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
      #expect(descriptor.role == "AXButton", "Non-button element returned")
    }
    
    try await tearDown()
  }

  @Test("Element type filtering with full paths")
  mutating func testElementTypeFilteringFullPaths() async throws {
    try await setUp()
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running before test")
    
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
    
    try await tearDown()
  }

  @Test("Attribute filtering with full paths")
  mutating func testAttributeFilteringFullPaths() async throws {
    try await setUp()
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running before test")
    
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object([
        "description": .string("3")
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      #expect(
        descriptor.description?.contains("3") ?? false, "Element doesn't match filter criteria")
    }
    
    try await tearDown()
  }

  @Test("Combined filtering with full paths")
  mutating func testCombinedFilteringFullPaths() async throws {
    try await setUp()
    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running before test")
    
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
      #expect(descriptor.role == "AXButton", "Non-button element returned")
      #expect(
        descriptor.description?.contains("4") ?? false, "Element doesn't match description criteria"
      )
    }
    
    try await tearDown()
  }
}