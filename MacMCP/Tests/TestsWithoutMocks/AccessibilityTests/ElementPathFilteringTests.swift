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
  
  // Logger for test output
  private var logger: Logger!
  private var logFileURL: URL?
  private var diagnosticLogPath: String?

  override func setUp() async throws {
    try await super.setUp()
    
    // Set up logging to file for debugging
    (logger, logFileURL) = TestLogger.create(label: "mcp.test.element_path_filtering", testName: "ElementPathFilteringTests")
    TestLogger.configureEnvironment(logger: logger)
    diagnosticLogPath = TestLogger.createDiagnosticLog(testName: "ElementPathFilteringTests", logger: logger)
    
    logger.info("====== TEST SETUP STARTED ======")

    // Create the test components - this creates properly configured services
    toolChain = ToolChain(logLabel: "mcp.test.calculator")
    
    // Get references to the tools we'll use
    interfaceExplorerTool = toolChain.interfaceExplorerTool
    uiInteractionService = toolChain.interactionService
    
    // Make sure we're using the enhanced logging for relevant components
    enhanceLoggingForComponents()

    // Force terminate any existing instances of Calculator
    logger.info("Terminating any existing Calculator instances")
    await terminateApplication(bundleId: calculatorBundleId)
    
    // Wait for termination to complete
    logger.info("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    // Launch the Calculator app using the ApplicationManagementTool
    logger.info("Launching Calculator...")
    let launchParams: [String: Value] = [
      "action": .string("launch"),
      "bundleIdentifier": .string(calculatorBundleId),
    ]
    
    // Launch Calculator
    let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)
    logger.info("Launch result: \(launchResult)")
    
    // Wait for the app to launch fully
    logger.info("Waiting for app to launch...")
    try await Task.sleep(for: .milliseconds(3000))
    
    // Check if app is running
    app = NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first
    logger.info("Calculator running status: \(app != nil)")
    XCTAssertNotNil(app, "Failed to launch Calculator app")
    
    // Try to activate the app to ensure it's in the foreground
    if let runningApp = app {
      logger.info("Activating Calculator...")
      let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
      logger.info("Activation result: \(activated)")
    }
    
    // Give additional time for app to fully load
    try await Task.sleep(for: .milliseconds(1000))
    logger.info("Setup complete - Calculator should be running")
  }

  override func tearDown() async throws {
    logger.info("====== TEST TEARDOWN STARTED ======")
    
    // Terminate test application
    logger.info("Terminating Calculator")
    await terminateApplication(bundleId: calculatorBundleId)
    app = nil
    
    // Wait for termination to complete
    logger.info("Waiting for termination to complete")
    try await Task.sleep(for: .milliseconds(1000))
    
    toolChain = nil
    logger.info("Removed toolChain")
    
    // Print log file location if available
    if let logURL = logFileURL {
      logger.info("Test log available at: \(logURL.path)")
      print("For detailed debug info, check the log file at: \(logURL.path)")
    }
    
    if let diagnosticPath = diagnosticLogPath {
      logger.info("Accessibility diagnostic log available at: \(diagnosticPath)")
    }
    
    logger.info("====== TEST TEARDOWN COMPLETE ======")
    try await super.tearDown()
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
          logger.info("Found UIInteractionService logger: \(existingLogger)")
          
          // The ideal solution would be setting a different logger, but since we can't
          // do that directly, we'll use environment variables as a fallback
          setenv("MCP_LOG_LEVEL", "trace", 1)
          logger.info("Set MCP_LOG_LEVEL=trace for enhanced logging")
        }
      }
    }
    
    // Enable additional debug flags for ElementPath resolution diagnostics
    setenv("MCP_PATH_RESOLUTION_DEBUG", "true", 1)
    logger.info("Set MCP_PATH_RESOLUTION_DEBUG=true for path resolution diagnostics")
    
    // Enable attribute matching debug information
    setenv("MCP_ATTRIBUTE_MATCHING_DEBUG", "true", 1)
    logger.info("Set MCP_ATTRIBUTE_MATCHING_DEBUG=true for attribute matching diagnostics")
    
    // Enable comprehensive AX hierarchy diagnostics 
    setenv("MCP_FULL_HIERARCHY_DEBUG", "true", 1)
    logger.info("Set MCP_FULL_HIERARCHY_DEBUG=true for full hierarchy diagnostics")
  }

  /// Helper method to terminate an application
  private func terminateApplication(bundleId: String) async {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    logger.info("Found \(runningApps.count) instances of \(bundleId) to terminate")
    for app in runningApps {
      let terminated = app.forceTerminate()
      logger.info("Force termination result for \(bundleId): \(terminated)")
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
    logger.info("Running InterfaceExplorerTool with request: \(request)")
    
    let response = try await interfaceExplorerTool.handler(request)
    
    logger.info("Got response with \(response.count) items")
    
    guard case .text(let jsonString) = response.first else {
      XCTFail("Failed to get valid response from tool")
      return
    }
    
    logger.info("Response text length: \(jsonString.count) characters")
    
    // Print the first part of the response for debugging
    if jsonString.count > 0 {
      let previewLength = min(jsonString.count, 200)
      let startIndex = jsonString.startIndex
      let endIndex = jsonString.index(startIndex, offsetBy: previewLength)
      logger.info("Response preview: \(jsonString[startIndex..<endIndex])...")
      
      // Save the full response to the log for detailed analysis
      logger.trace("FULL RESPONSE JSON: \(jsonString)")
    }
    
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    
    do {
      let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
      
      logger.info("Found \(descriptors.count) descriptors in response")
      
      if descriptors.isEmpty {
        // Check if app is still running
        let isStillRunning = isApplicationRunning(calculatorBundleId)
        logger.warning("Is Calculator still running? \(isStillRunning)")
        
        // If the app is running but no elements found, try to diagnose
        if isStillRunning {
          logger.warning("Calculator is running but no elements were found for the request")
          
          // Try a more basic request to see if any elements are visible
          logger.info("Trying a basic request to see if Calculator is accessible")
          let basicRequest: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(2),
          ]
          
          do {
            let basicResponse = try await interfaceExplorerTool.handler(basicRequest)
            if let content = basicResponse.first, case .text(let basicJson) = content {
              logger.info("Basic request response length: \(basicJson.count)")
              if basicJson.count > 0 {
                logger.info("Calculator is accessible, but specific query returned no elements")
              }
            }
          } catch {
            logger.error("Failed even with basic request: \(error)")
          }
        }
        
        XCTAssertFalse(descriptors.isEmpty, "No elements returned")
        return
      }
      
      for (i, descriptor) in descriptors.enumerated() {
        logger.info("Descriptor \(i): \(descriptor.role) - \(descriptor.name)")
        verifyFullyQualifiedPath(descriptor.id)
        extraAssertions?(descriptor)
        logger.info("Element path: \(descriptor.id)")
        if let children = descriptor.children {
          logger.info("Element has \(children.count) children")
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
              logger.info("Extracted app bundle ID: \(appBundleId ?? "nil")")
            }
          }
        }
        
        // Use our reflection capabilities to call the internal dumpAccessibilityTree method
        // Even though dumpAccessibilityTree is private, we can call it via the clickElementByPath
        // method which we've instrumented to dump the tree before attempting resolution
        
        // Log that we're about to perform the click (which will dump the tree)
        logger.info("Attempting to click element at path: \(path)")
        do {
          try await uiInteractionService.clickElementByPath(path: path, appBundleId: appBundleId)
          logger.info("Click appears to have succeeded")
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