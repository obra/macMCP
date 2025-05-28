// ABOUTME: ResourcesE2ETests.swift
// ABOUTME: End-to-end tests for resources functionality using real macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct ResourcesE2ETests {
  // Test components
  private var toolChain: ToolChain!
  private var calculatorApp: CalculatorModel!
  // The calculator bundle ID
  private let calculatorBundleId = "com.apple.calculator"
  // Setup method
  private mutating func setUp() async throws {
    // Create tool chain
    toolChain = ToolChain()
    // Create calculator app model
    calculatorApp = CalculatorModel(toolChain: toolChain)
    // Terminate any existing Calculator instances
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId)
    for runningApp in runningApps { _ = runningApp.terminate() }
    try await Task.sleep(for: .milliseconds(1000))
    // Launch calculator
    _ = try await calculatorApp.launch(hideOthers: false)
    // Wait for Calculator to be ready
    try await Task.sleep(for: .milliseconds(2000))
  }
  // Teardown method
  private mutating func tearDown() async throws {
    // Terminate the calculator application
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId)
    for runningApp in runningApps { _ = runningApp.terminate() }
    try await Task.sleep(for: .milliseconds(1000))
  }
  @Test("Test applications resource lists Calculator") mutating func testApplicationsResource()
    async throws
  {
    try await setUp()
    // Create an ApplicationsResourceHandler
    let applicationService = toolChain.applicationService
    let logger = Logger(label: "test.resources")
    let handler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger)
    // Create a resource URI for applications
    let resourceURI = "macos://applications"
    let components = ResourceURIComponents(
      scheme: "macos", path: "/applications", queryParameters: [:])
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case let .text(jsonString) = content {
      // Verify Calculator is in the list
      #expect(
        jsonString.contains(calculatorBundleId), "Calculator should be in the applications list")
      #expect(
        jsonString.contains("Calculator"), "Calculator name should be in the applications list")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }
  @Test("Test application windows resource shows Calculator window")
  mutating func testApplicationWindowsResource()
    async throws
  {
    try await setUp()
    // Create an ApplicationWindowsResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = ApplicationWindowsResourceHandler(
      accessibilityService: accessibilityService, logger: logger)
    // Create a resource URI for windows
    let resourceURI = "macos://applications/\(calculatorBundleId)/windows"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/\(calculatorBundleId)/windows",
      queryParameters: [:]
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case let .text(jsonString) = content {
      // Verify window information
      #expect(jsonString.contains("AXWindow"), "Response should include AXWindow")
      #expect(jsonString.contains("Calculator"), "Window title should contain Calculator")
      // Verify window properties
      #expect(jsonString.contains("\"isMain\""), "Response should include main window status")
      #expect(jsonString.contains("\"frame\""), "Response should include frame information")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }
  @Test("Test UI element resource for Calculator application") mutating func testUIElementResource()
    async throws
  {
    try await setUp()
    // Create a UIElementResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger)
    // Create a resource URI for UI element
    let resourceURI = "macos://ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]",
      queryParameters: ["maxDepth": "2"]
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case let .text(jsonString) = content {
      // Verify calculator information
      #expect(jsonString.contains("AXApplication"), "Response should include AXApplication")
      #expect(jsonString.contains("Calculator"), "Response should include Calculator title")
      #expect(jsonString.contains("children"), "Response should include children")
      #expect(jsonString.contains("AXWindow"), "Response should include AXWindow in children")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }
  @Test("Test interactable elements filtering for Calculator")
  mutating func testInteractableElementsFiltering()
    async throws
  {
    try await setUp()
    // Create a UIElementResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger)
    // Create a resource URI with interactable filter
    let resourceURI =
      "macos://ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]?interactable=true&maxDepth=5"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]",
      queryParameters: ["interactable": "true", "maxDepth": "5"]
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case let .text(jsonString) = content {
      // Verify we got interactable elements
      #expect(jsonString.contains("AXButton"), "Response should include calculator buttons")
      // The response should be an array since interactable=true returns an array
      #expect(jsonString.hasPrefix("["), "Response should be an array")
      #expect(jsonString.hasSuffix("]"), "Response should be an array")
      // Verify all returned elements have some kind of interactive action
      #expect(jsonString.contains("\"actions\""), "Response should include actions")
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      if let metadata = metadata {
        #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
        #expect(
          metadata.additionalMetadata?["interactableCount"] != nil,
          "Metadata should include interactable count"
        )
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    try await tearDown()
  }
  @Test("Test resource registry with real handlers")
  mutating func testResourceRegistryWithRealHandlers() async throws {
    try await setUp()
    // Create a resource registry
    let registry = ResourceRegistry()
    // Create real resource handlers
    let applicationService = toolChain.applicationService
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let applicationsHandler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger)
    let uiElementHandler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger)
    // Register the handlers
    registry.register(applicationsHandler)
    registry.register(uiElementHandler)
    // List the resources
    let (resources, nextCursor) = registry.listResources()
    // Verify the resources
    #expect(resources.count >= 2, "Registry should have at least 2 resources")
    #expect(
      resources.contains(where: { $0.id.contains("applications") }),
      "Should contain applications resource")
    #expect(
      resources.contains(where: { $0.id.contains("ui") }), "Should contain UI elements resource")
    #expect(nextCursor == nil, "Next cursor should be nil since all resources were returned")
    try await tearDown()
  }
}
