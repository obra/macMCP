// ABOUTME: WindowManagementE2ETests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// End-to-end tests for the WindowManagementTool
@Suite(.serialized)
struct WindowManagementE2ETests {
  // Test components
  private var toolChain: ToolChain!
  private var dictionaryApp: BaseApplicationModel!
  private var logger: Logger!
  private var logFileURL: URL?

  private mutating func setUp() async throws {
    // Set up standardized logging
    (logger, logFileURL) = TestLogger.create(label: "mcp.test.windowmanagement", testName: "WindowManagementE2ETests")
    TestLogger.configureEnvironment(logger: logger)
    let _ = TestLogger.createDiagnosticLog(testName: "WindowManagementE2ETests", logger: logger)
    
    logger.debug("Setting up WindowManagementE2ETests")

    // Create the test components
    toolChain = ToolChain()
    dictionaryApp = BaseApplicationModel(
      bundleId: "com.apple.Dictionary",
      appName: "Dictionary",
      toolChain: toolChain
    )

    // Force terminate any existing Dictionary instances
    logger.debug("Terminating any existing Dictionary instances")
    for app in NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.Dictionary")
    {
      _ = app.forceTerminate()
    }

    try await Task.sleep(for: .milliseconds(1000))

    // Launch Dictionary for the tests
    logger.debug("Launching Dictionary application")
    let launchSuccess = try await dictionaryApp.launch()
    #expect(launchSuccess, "Dictionary should launch successfully")

    // Wait for the app to fully initialize
    try await Task.sleep(for: .milliseconds(2000))
  }

  private mutating func tearDown() async throws {
    logger.debug("Tearing down WindowManagementE2ETests")
    
    // Terminate Dictionary
    for app in NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.Dictionary")
    {
      _ = app.forceTerminate()
    }

    try await Task.sleep(for: .milliseconds(1000))

    dictionaryApp = nil
    toolChain = nil
  }

  /// Test getting application windows
  @Test("Get application windows")
  mutating func testGetApplicationWindows() async throws {
    try await setUp()
    
    // Create parameters
    let params: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string("com.apple.Dictionary"),
    ]

    // Execute the test
    logger.debug("Getting application windows")
    let result = try await toolChain.windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Parse the result JSON to verify content
    if case .text(let jsonString) = result[0] {
      // Parse the JSON
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify window count
      #expect(json.count >= 1, "Should have at least 1 window")

      // Verify window properties
      let window = json[0]
      #expect(window["id"] != nil, "Window should have an ID")
      #expect(window["AXRole"] as? String == "AXWindow", "Role should be AXWindow")
  
      // Window ID will be obtained dynamically for each test
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test moving a window
  @Test("Move window")
  mutating func testMoveWindow() async throws {
    try await setUp()
    
    // First ensure we have the dictionary window ID
    guard let windowId = try await getDictionaryWindowId() else {
      #expect(Bool(false), "Failed to get dictionary window ID")
      try await tearDown()
      return
    }

    // Create parameters to move the window to a specific position
    let params: [String: Value] = [
      "action": .string("moveWindow"),
      "windowId": .string(windowId),
      "x": .double(200),
      "y": .double(200),
    ]

    // Execute the test
    logger.debug("Moving window to position (200, 200)")
    let result = try await toolChain.windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Parse the result JSON to verify content
    if case .text(let jsonString) = result[0] {
      // Verify the response format
      #expect(jsonString.contains("\"success\":true"), "Should indicate success")

      // Wait for UI to update
      try await Task.sleep(for: .milliseconds(1000))

      // Get the window position to verify it moved
      let windowInfo = try await getWindowPosition(windowId: windowId)

      // Verify the position (allow some tolerance for window management adjustments)
      #expect(windowInfo != nil, "Should get window information")
      if let info = windowInfo {
        let frame = info["frame"] as! [String: Any]
        let x = frame["x"] as! CGFloat
        let y = frame["y"] as! CGFloat

        // Use approximate equality checks
        let xDiff = abs(x - 200)
        let yDiff = abs(y - 200)
        #expect(xDiff <= 20, "X position should be approximately 200, got \(x)")
        #expect(yDiff <= 20, "Y position should be approximately 200, got \(y)")
      }
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test resizing a window
  @Test("Resize window")
  mutating func testResizeWindow() async throws {
    try await setUp()
    
    // First ensure we have the dictionary window ID
    guard let windowId = try await getDictionaryWindowId() else {
      #expect(Bool(false), "Failed to get dictionary window ID")
      try await tearDown()
      return
    }

    // Create parameters to resize the window
    let params: [String: Value] = [
      "action": .string("resizeWindow"),
      "windowId": .string(windowId),
      "width": .double(400),
      "height": .double(500),
    ]

    // Execute the test
    logger.debug("Resizing window to 400x500")
    let result = try await toolChain.windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Parse the result JSON to verify content
    if case .text(let jsonString) = result[0] {
      // Verify the response format
      #expect(jsonString.contains("\"success\":true"), "Should indicate success")

      // Wait for UI to update
      try await Task.sleep(for: .milliseconds(1000))

      // Get the window size to verify it resized
      let windowInfo = try await getWindowPosition(windowId: windowId)

      // Verify the size (allow some tolerance for window management adjustments)
      #expect(windowInfo != nil, "Should get window information")
      if let info = windowInfo {
        let frame = info["frame"] as! [String: Any]
        let width = frame["width"] as! CGFloat
        let height = frame["height"] as! CGFloat

        // Use approximate equality checks
        let widthDiff = abs(width - 400)
        let heightDiff = abs(height - 500)
        #expect(widthDiff <= 20, "Width should be approximately 400, got \(width)")
        #expect(heightDiff <= 20, "Height should be approximately 500, got \(height)")
      }
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test minimizing and activating a window
  @Test("Minimize and activate window")
  mutating func testMinimizeAndActivateWindow() async throws {
    try await setUp()
    
    // First ensure we have the dictionary window ID
    guard let windowId = try await getDictionaryWindowId() else {
      #expect(Bool(false), "Failed to get dictionary window ID")
      try await tearDown()
      return
    }

    // Create parameters to minimize the window
    let minimizeParams: [String: Value] = [
      "action": .string("minimizeWindow"),
      "windowId": .string(windowId),
    ]

    // Execute the minimize test
    logger.debug("Minimizing window")
    let minimizeResult = try await toolChain.windowManagementTool.handler(minimizeParams)

    // Verify the result
    #expect(minimizeResult.count == 1, "Should return one content item")

    if case .text(let jsonString) = minimizeResult[0] {
      // Verify the response format
      #expect(jsonString.contains("\"success\":true"), "Should indicate success")

      // Wait for UI to update
      try await Task.sleep(for: .milliseconds(1000))

      // Verify the window is minimized
      let isVisible = try await isWindowVisible(windowId: windowId)
      #expect(!isVisible, "Window should be minimized/not visible")

      // Now activate the window
      let activateParams: [String: Value] = [
        "action": .string("activateWindow"),
        "windowId": .string(windowId),
      ]

      // Execute the activate test
      logger.debug("Activating window")
      let activateResult = try await toolChain.windowManagementTool.handler(activateParams)

      // Verify the result
      #expect(activateResult.count == 1, "Should return one content item")

      if case .text(let activateJsonString) = activateResult[0] {
        // Verify the response format
        #expect(activateJsonString.contains("\"success\":true"), "Should indicate success")

        // Wait for UI to update
        try await Task.sleep(for: .milliseconds(1500))

        // Verify the window is visible again
        let isVisibleAfterActivate = try await isWindowVisible(windowId: windowId)
        #expect(isVisibleAfterActivate, "Window should be visible after activation")
      } else {
        #expect(Bool(false), "Activate result should be text content")
      }
    } else {
      #expect(Bool(false), "Minimize result should be text content")
    }
    
    try await tearDown()
  }

  // MARK: - Helper Methods

  /// Get the Dictionary window ID
  private func getDictionaryWindowId() async throws -> String? {
    // Create parameters
    let params: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string("com.apple.Dictionary"),
    ]

    // Execute the query
    let result = try await toolChain.windowManagementTool.handler(params)

    // Parse the result JSON
    if case .text(let jsonString) = result[0] {
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Get the first window ID
      if json.count > 0, let windowId = json[0]["id"] as? String {
        return windowId
      }
    }

    return nil
  }

  /// Get window position and size information
  private func getWindowPosition(windowId: String) async throws -> [String: Any]? {
    // First get all dictionary windows
    let params: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string("com.apple.Dictionary"),
    ]

    // Execute the query
    let result = try await toolChain.windowManagementTool.handler(params)

    // Parse the result JSON
    if case .text(let jsonString) = result[0] {
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Find the window with the matching ID
      for window in json {
        if let id = window["id"] as? String, id == windowId {
          return window
        }
      }
    }

    return nil
  }

  /// Check if a window is visible
  private func isWindowVisible(windowId: String) async throws -> Bool {
    // Get the window information
    let windowInfo = try await getWindowPosition(windowId: windowId)

    // Check if it's visible
    if let info = windowInfo {
      return !(info["isMinimized"] as? Bool ?? false)
    }

    // If we can't find the window, assume it's not visible
    return false
  }
}