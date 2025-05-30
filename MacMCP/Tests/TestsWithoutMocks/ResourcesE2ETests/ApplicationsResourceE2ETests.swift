// ABOUTME: ApplicationsResourceE2ETests.swift
// ABOUTME: End-to-end tests for applications resource functionality using real macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct ApplicationsResourceE2ETests {
  // Test components
  private var toolChain: ToolChain!
  private var calculatorApp: CalculatorModel!
  // The Calculator bundle ID for testing
  private let calculatorBundleId = "com.apple.calculator"
  // Setup method
  private mutating func setUp() async throws {
    // Create tool chain
    toolChain = ToolChain()
    // Create calculator app model
    calculatorApp = CalculatorModel(toolChain: toolChain)
    // Terminate any existing Calculator instances
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId,
    )
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }
    try await Task.sleep(for: .milliseconds(1000))
  }

  // Teardown method
  private mutating func tearDown() async throws {
    // Terminate the calculator application
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId,
    )
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }
    try await Task.sleep(for: .milliseconds(1000))
  }

  @Test("Test applications resource lists running apps") mutating func applicationsResource()
    async throws
  {
    try await setUp()
    // Launch Calculator
    _ = try await calculatorApp.launch(hideOthers: false)
    // Wait for Calculator to be ready
    try await Task.sleep(for: .milliseconds(2000))
    // Create an ApplicationsResourceHandler
    let applicationService = toolChain.applicationService
    let logger = Logger(label: "test.applications")
    let handler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger,
    )
    // Create the resource URI
    let resourceURI = "macos://applications"
    let components = ResourceURIComponents(
      scheme: "macos", path: "/applications", queryParameters: [:],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { applications in
        #expect(!applications.isEmpty, "Should have running applications")

        // Verify standard system processes are listed
        let hasFinderApp = applications.contains { app in
          if let name = app["name"] as? String {
            return name.contains("Finder")
          }
          return false
        }
        #expect(hasFinderApp, "Response should include Finder")

        // Our test app should be listed
        let hasCalculatorApp = applications.contains { app in
          (app["bundleId"] as? String)?.contains(calculatorBundleId) == true ||
            (app["name"] as? String)?.contains("Calculator") == true
        }
        #expect(hasCalculatorApp, "Response should include Calculator")

        // Each application entry should have basic information
        for app in applications {
          try JSONTestUtilities.assertPropertyExists(app, property: "bundleId")
          try JSONTestUtilities.assertPropertyExists(app, property: "name")
          try JSONTestUtilities.assertPropertyExists(app, property: "processIdentifier")
        }
      }
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    try await tearDown()
  }

  @Test("Test application launch and termination reflection in applications resource")
  mutating func launchAndTerminationReflection() async throws {
    try await setUp()
    // Create an ApplicationsResourceHandler
    let applicationService = toolChain.applicationService
    let logger = Logger(label: "test.applications")
    let handler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger,
    )
    // Create the resource URI
    let resourceURI = "macos://applications"
    let components = ResourceURIComponents(
      scheme: "macos", path: "/applications", queryParameters: [:],
    )
    // Call the handler before launching Calculator
    let (beforeContent, _) = try await handler.handleRead(uri: resourceURI, components: components)
    // Now launch Calculator
    _ = try await calculatorApp.launch(hideOthers: false)
    // Wait for Calculator to launch
    try await Task.sleep(for: .milliseconds(2000))
    // Call the handler again after launching Calculator
    let (afterContent, _) = try await handler.handleRead(uri: resourceURI, components: components)
    // Check that Calculator appears in the second response but not the first
    if case .text(let beforeJson) = beforeContent, case .text(let afterJson) = afterContent {
      let beforeHasCalculator = beforeJson.contains(calculatorBundleId)
      let afterHasCalculator = afterJson.contains(calculatorBundleId)
      #expect(!beforeHasCalculator, "Calculator should not be in applications list before launch")
      #expect(afterHasCalculator, "Calculator should be in applications list after launch")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Now terminate Calculator
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId,
    )
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }
    try await Task.sleep(for: .milliseconds(1000))
    // Call the handler again after terminating Calculator
    let (finalContent, _) = try await handler.handleRead(uri: resourceURI, components: components)
    // Check that Calculator no longer appears
    if case .text(let finalJson) = finalContent {
      let finalHasCalculator = finalJson.contains(calculatorBundleId)
      #expect(
        !finalHasCalculator, "Calculator should not be in applications list after termination",
      )
    } else {
      #expect(Bool(false), "Content should be text")
    }
    try await tearDown()
  }

  @Test("Test resource registry with real handlers")
  mutating func resourceRegistryWithRealHandlers() async throws {
    try await setUp()
    // Create a resource registry
    let registry = ResourceRegistry()
    // Register real handlers
    let applicationService = toolChain.applicationService
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.applications")
    let applicationsHandler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger,
    )
    let windowsHandler = ApplicationWindowsResourceHandler(
      accessibilityService: accessibilityService,
      logger: logger,
    )
    // Register the handlers
    registry.register(applicationsHandler)
    registry.register(windowsHandler)
    // List the resources
    let (resources, nextCursor) = registry.listResources()
    // Verify the resources
    #expect(resources.count >= 2, "Registry should have at least 2 resources")
    #expect(
      resources.contains(where: { $0.id.contains("applications") }),
      "Should contain applications resource",
    )
    #expect(nextCursor == nil, "Next cursor should be nil since all resources were returned")
    try await tearDown()
  }
}
