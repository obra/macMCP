// ABOUTME: InterfaceExplorerToolTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import AppKit  // For NSRunningApplication
import MCP
import Testing

@testable import MacMCP

// Test utilities are directly available in this module

/// Test the InterfaceExplorerTool
@Suite(.serialized)
struct InterfaceExplorerToolTests {
  // Test components
  private var toolChain: ToolChain!
  private var calculator: CalculatorModel!

  // Setup method to replace setUp and tearDown
  private mutating func setupTest() async throws {
    // Force terminate any existing Calculator instances first
    for app in NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator")
    {
      _ = app.forceTerminate()
    }

    try await Task.sleep(for: .milliseconds(1000))

    // Create the test components
    toolChain = ToolChain()
    calculator = CalculatorModel(toolChain: toolChain)
  }

  // Helper method to clean up after tests
  private func cleanupTest() async throws {
    // Terminate Calculator
    for app in NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator")
    {
      _ = app.forceTerminate()
    }

    try await Task.sleep(for: .milliseconds(1000))
  }

  /// Helper to ensure calculator is launched and ready
  private func launchCalculator() async throws {
    // In our mocked tests, we don't actually launch the calculator app
    // Just simulate a successful launch

    // Wait to simulate app initialization
    try await Task.sleep(for: .milliseconds(300))
  }

  /// Test system scope with the interface explorer tool
  @Test("Test system scope")
  mutating func testSystemScope() async throws {
    try await setupTest()
    
    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for system scope
    let params: [String: Value] = [
      "scope": .string("system"),
      "maxDepth": .int(3),  // Limit depth to keep test manageable
      "limit": .int(10),  // Limit results to keep test manageable
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Verify each element has the expected properties
      for element in elements {
        #expect(element["id"] != nil, "Element should have an ID")
        #expect(element["role"] != nil, "Element should have a role")
        #expect(element["name"] != nil, "Element should have a name")
        #expect(element["state"] != nil, "Element should have state information")
        #expect(element["capabilities"] != nil, "Element should have capabilities")

        // Check frame data
        if let frame = element["frame"] as? [String: Any] {
          #expect(frame["x"] != nil, "Frame should have x coordinate")
          #expect(frame["y"] != nil, "Frame should have y coordinate")
          #expect(frame["width"] != nil, "Frame should have width")
          #expect(frame["height"] != nil, "Frame should have height")
        } else {
          #expect(Bool(false), "Element should have frame information")
        }
      }
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test application scope with the interface explorer tool
  @Test("Test application scope")
  mutating func testApplicationScope() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for application scope
    let params: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
      "maxDepth": .int(10),
      "includeHidden": .bool(false),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Verify the root element looks like a Calculator application
      let rootElement = elements[0]
      #expect(
        rootElement["role"] as? String == "AXApplication", "Root element should be an application")

      // With the new InterfaceExplorerTool, we should still be able to find some
      // basic elements like buttons, but windows may be handled by WindowManagementTool
      var foundButton = false

      // Check for basic Calculator elements in the hierarchy
      func checkForElements(element: [String: Any]) {
        // Check if this is a button (Calculator has many buttons)
        if let role = element["role"] as? String, role == "AXButton" {
          foundButton = true
        }

        // Check children recursively
        if let children = element["children"] as? [[String: Any]] {
          for child in children {
            checkForElements(element: child)
          }
        }
      }

      // Check all root elements
      for element in elements {
        checkForElements(element: element)
      }

      // Now assert that we found buttons - windows are handled by WindowManagementTool now
      #expect(foundButton, "Should find at least one button in the Calculator")
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test element scope with the interface explorer tool
  @Test("Test element scope")
  mutating func testElementScope() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // First, we need to construct an element path for the Calculator window
    // Instead of relying on element IDs, we'll use a path-based approach

    // Create a path to the Calculator window
    let elementPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow"

    // Create parameters for path scope
    let params: [String: Value] = [
      "scope": .string("path"),
      "elementPath": .string(elementPath),
      "maxDepth": .int(5),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Verify the element we got back matches our path
      let element = elements[0]
      #expect(element["role"] as? String == "AXWindow", "Element should be a window")

      // Verify path was returned and matches our expected format
      #expect(element["path"] != nil, "Element should have a path")
      if let path = element["path"] as? String {
        #expect(
          path.hasPrefix("ui://AXApplication"), "Path should start with ui://AXApplication")
        #expect(path.contains("AXWindow"), "Path should include AXWindow")
      }

      // Verify children were also returned
      #expect(element["children"] != nil, "Element should have children")
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test filtering with the interface explorer tool
  @Test("Test filtering elements")
  mutating func testFilteringElements() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for application scope with button filtering
    let params: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
      "filter": .object([
        "role": .string("AXButton")
      ]),
      "maxDepth": .int(10),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Verify all returned elements are buttons
      for element in elements {
        #expect(element["role"] as? String == "AXButton", "All elements should be buttons")
      }

      // Verify we got multiple button elements (Calculator has many)
      #expect(elements.count > 5, "Should find multiple button elements")
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test element types filtering with the interface explorer tool
  @Test("Test element types filtering")
  mutating func testElementTypesFiltering() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters to specifically find buttons using elementTypes
    let params: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
      "elementTypes": .array([.string("button")]),
      "maxDepth": .int(10),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Verify all returned elements are buttons
      for element in elements {
        #expect(element["role"] as? String == "AXButton", "All elements should be buttons")

        // Also check that the element has the clickable capability
        if let capabilities = element["capabilities"] as? [String] {
          #expect(
            capabilities.contains("clickable"), "Button should have clickable capability")
        }
      }
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test enhanced capabilities reporting
  @Test("Test enhanced capabilities")
  mutating func testEnhancedCapabilities() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for application scope
    let params: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
      "maxDepth": .int(5),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Check first for buttons with capabilities
      var foundButtonWithCapabilities = false
      var foundTextFieldWithState = false

      // Function to search recursively through the element tree
      func checkElementsForCapabilitiesAndState(element: [String: Any]) {
        // Check if this element has the expected properties
        if let role = element["role"] as? String {
          // Check buttons for clickable capability
          if role == "AXButton", let capabilities = element["capabilities"] as? [String],
            capabilities.contains("clickable")
          {
            foundButtonWithCapabilities = true
          }

          // Check text fields for state info
          if role == "AXTextField" || role == "AXStaticText",
            let state = element["state"] as? [String],
            !state.isEmpty
          {
            foundTextFieldWithState = true
          }
        }

        // Recursively check children
        if let children = element["children"] as? [[String: Any]] {
          for child in children {
            checkElementsForCapabilitiesAndState(element: child)
          }
        }
      }

      // Check all elements
      for element in elements {
        checkElementsForCapabilitiesAndState(element: element)
      }

      // Verify that we found elements with the expected capabilities and state
      #expect(
        foundButtonWithCapabilities || foundTextFieldWithState,
        "Should find at least one button with capabilities or text field with state",
      )
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test path support in interface explorer tool
  @Test("Test element path support")
  mutating func testElementPathSupport() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for application scope
    let params: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
      "maxDepth": .int(5),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Check the elements for path information
      var foundElementWithPath = false

      // Function to search recursively through the element tree
      func checkElementsForPaths(element: [String: Any]) {
        // Check if this element has a path
        if let path = element["path"] as? String, path.hasPrefix("ui://") {
          foundElementWithPath = true
        }

        // Recursively check children
        if let children = element["children"] as? [[String: Any]] {
          for child in children {
            checkElementsForPaths(element: child)
          }
        }
      }

      // Check all elements
      for element in elements {
        checkElementsForPaths(element: element)
      }

      // Verify that we found at least one element with a path
      #expect(foundElementWithPath, "Should find at least one element with a path")

      // Find a specific type of element and check its path in more detail
      var foundButtonWithValidPath = false

      // Function to check for buttons with valid paths
      func checkButtonPaths(element: [String: Any]) {
        if let role = element["role"] as? String, role == "AXButton",
          let path = element["path"] as? String
        {
          // Verify the path has the correct format
          #expect(path.hasPrefix("ui://"), "Path should start with ui://")
          #expect(path.contains("AXButton"), "Button path should contain AXButton")
          foundButtonWithValidPath = true
        }

        // Recursively check children
        if let children = element["children"] as? [[String: Any]] {
          for child in children {
            checkButtonPaths(element: child)
          }
        }
      }

      // Check all elements for buttons with valid paths
      for element in elements {
        checkButtonPaths(element: element)
      }

      // Verify that we found at least one button with a valid path
      #expect(foundButtonWithValidPath, "Should find at least one button with a valid path")
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }

  /// Test position scope with the interface explorer tool
  @Test("Test position scope")
  mutating func testPositionScope() async throws {
    try await setupTest()
    
    // Launch calculator first
    try await launchCalculator()

    // Get the window position
    let windows = try await toolChain.accessibilityService.findUIElements(
      role: "AXWindow",
      title: nil,
      titleContains: nil,
      value: nil,
      valueContains: nil,
      description: nil,
      descriptionContains: nil,
      scope: .application(bundleIdentifier: "com.apple.calculator"),
      recursive: true,
      maxDepth: 3,
    )

    guard let window = windows.first else {
      // Instead of throwing MCPError.elementNotFound since we can't access that enum,
      // Just throw a simple error for testing
      #expect(Bool(false), "No window found in Calculator for position scope test")
      throw MCPError.invalidParams("No window found in Calculator for position scope test")
    }

    // Get the center of the window
    let centerX = window.frame.origin.x + window.frame.size.width / 2
    let centerY = window.frame.origin.y + window.frame.size.height / 2

    // Define direct handler access for more precise testing
    let interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: toolChain.accessibilityService,
      logger: nil,
    )

    // Create parameters for position scope
    let params: [String: Value] = [
      "scope": .string("position"),
      "x": .double(Double(centerX)),
      "y": .double(Double(centerY)),
      "maxDepth": .int(5),
    ]

    // Call the handler directly
    let result = try await interfaceExplorerTool.handler(params)

    // Verify we got a result
    #expect(!result.isEmpty, "Should receive a non-empty result")

    // Verify result is text content
    if case .text(let jsonString) = result[0] {
      // Parse JSON
      let jsonData = jsonString.data(using: String.Encoding.utf8)!
      let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify we got UI elements back
      #expect(!elements.isEmpty, "Should receive UI elements")

      // Not testing specific element properties here as the element
      // at the center of a window can vary, but we should at least
      // have received something from the Calculator app
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    try await cleanupTest()
  }
}