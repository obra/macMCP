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
      withBundleIdentifier: calculatorBundleId,
    )
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }
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
      withBundleIdentifier: calculatorBundleId,
    )
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }
    try await Task.sleep(for: .milliseconds(1000))
  }

  @Test("Test applications resource lists Calculator") mutating func applicationsResource()
    async throws
  {
    try await setUp()
    // Create an ApplicationsResourceHandler
    let applicationService = toolChain.applicationService
    let logger = Logger(label: "test.resources")
    let handler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger,
    )
    // Create a resource URI for applications
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
        
        // Verify Calculator is in the list
        let hasCalculatorApp = applications.contains { app in
          (app["bundleId"] as? String)?.contains(calculatorBundleId) == true ||
          (app["name"] as? String)?.contains("Calculator") == true
        }
        #expect(hasCalculatorApp, "Calculator should be in the applications list")
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }

  @Test("Test application windows resource shows Calculator window")
  mutating func applicationWindowsResource()
    async throws
  {
    try await setUp()
    // Create an ApplicationWindowsResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = ApplicationWindowsResourceHandler(
      accessibilityService: accessibilityService, logger: logger,
    )
    // Create a resource URI for windows
    let resourceURI = "macos://applications/\(calculatorBundleId)/windows"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/\(calculatorBundleId)/windows",
      queryParameters: [:],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { windows in
        #expect(!windows.isEmpty, "Should have at least one window")
        
        // Verify window information
        let hasCalculatorWindow = windows.contains { window in
          if let title = window["title"] as? String,
             let id = window["id"] as? String {
            return title.contains("Calculator") || id.contains("AXWindow")
          }
          return false
        }
        #expect(hasCalculatorWindow, "Response should include Calculator window")
        
        // Verify window properties exist
        for window in windows {
          try JSONTestUtilities.assertPropertyExists(window, property: "isMain")
          try JSONTestUtilities.assertPropertyExists(window, property: "frame")
        }
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }

  @Test("Test UI element resource for Calculator application") mutating func uIElementResource()
    async throws
  {
    try await setUp()
    // Create a UIElementResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger,
    )
    // Create a resource URI for UI element
    let resourceURI = "macos://ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]",
      queryParameters: ["maxDepth": "2"],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONObject(jsonString) { element in
        // Verify calculator information
        try JSONTestUtilities.assertPropertyExists(element, property: "role")
        if let role = element["role"] as? String {
          #expect(role.contains("AXApplication"), "Response should include AXApplication")
        }
        
        if let name = element["name"] as? String {
          #expect(name.contains("Calculator"), "Response should include Calculator title")
        }
        
        try JSONTestUtilities.assertPropertyExists(element, property: "children")
        
        // Check if children contain AXWindow
        if let children = element["children"] as? [[String: Any]] {
          let hasWindow = children.contains { child in
            if let childRole = child["role"] as? String {
              return childRole.contains("AXWindow")
            }
            return false
          }
          #expect(hasWindow, "Response should include AXWindow in children")
        }
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Verify metadata
    #expect(metadata != nil, "Metadata should be provided")
    #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
    try await tearDown()
  }

  @Test("Test interactable elements filtering for Calculator")
  mutating func interactableElementsFiltering()
    async throws
  {
    try await setUp()
    // Create a UIElementResourceHandler
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let handler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger,
    )
    // Create a resource URI with interactable filter
    let resourceURI =
      "macos://ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]?interactable=true&maxDepth=5"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/ui/AXApplication[@bundleId=\"\(calculatorBundleId)\"]",
      queryParameters: ["interactable": "true", "maxDepth": "5"],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { interactableElements in
        #expect(!interactableElements.isEmpty, "Should have interactable elements")
        
        // Verify we got interactable elements like buttons
        let hasButtons = interactableElements.contains { element in
          if let role = element["role"] as? String {
            return role.contains("AXButton")
          }
          return false
        }
        #expect(hasButtons, "Response should include calculator buttons")
        
        // Verify all returned elements have some kind of interactive action
        for element in interactableElements {
          try JSONTestUtilities.assertPropertyExists(element, property: "actions")
        }
      }
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      if let metadata {
        #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
        #expect(
          metadata.additionalMetadata?["interactableCount"] != nil,
          "Metadata should include interactable count",
        )
      }
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
    // Create real resource handlers
    let applicationService = toolChain.applicationService
    let accessibilityService = toolChain.accessibilityService
    let logger = Logger(label: "test.resources")
    let applicationsHandler = ApplicationsResourceHandler(
      applicationService: applicationService, logger: logger,
    )
    let uiElementHandler = UIElementResourceHandler(
      accessibilityService: accessibilityService, logger: logger,
    )
    // Register the handlers
    registry.register(applicationsHandler)
    registry.register(uiElementHandler)
    // List the resources
    let (resources, nextCursor) = registry.listResources()
    // Verify the resources
    #expect(resources.count >= 2, "Registry should have at least 2 resources")
    #expect(
      resources.contains(where: { $0.id.contains("applications") }),
      "Should contain applications resource",
    )
    #expect(
      resources.contains(where: { $0.id.contains("ui") }), "Should contain UI elements resource",
    )
    #expect(nextCursor == nil, "Next cursor should be nil since all resources were returned")
    try await tearDown()
  }
}
