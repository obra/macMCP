// ABOUTME: ApplicationActivationTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import Testing

@testable import MacMCP

/// Simple struct to hold application information
struct ApplicationInfo {
  let bundleId: String
  let applicationName: String
}

/// A focused test for application activation and management operations
@Suite(.serialized) struct ApplicationActivationTest {
  private var toolChain: ToolChain!

  // Shared setup method
  private mutating func setUp() async throws {
    // Create a new toolchain for test operations
    toolChain = ToolChain(logLabel: "mcp.test.application_activation")

    // Ensure clean state - terminate grapher if running
    _ = try? await terminateApp(bundleId: "com.apple.grapher")

    // Wait briefly to ensure cleanup is complete
    try await Task.sleep(for: .milliseconds(1000))
  }

  // Shared teardown method
  private mutating func tearDown() async throws {
    // Clean up - terminate grapher if it's still running
    _ = try? await terminateApp(bundleId: "com.apple.grapher")
    // Wait briefly to ensure cleanup is complete
    try await Task.sleep(for: .milliseconds(1000))
  }

  /// Basic test for application launch and activation flow
  @Test("Basic App Activation") mutating func basicAppActivation() async throws {
    try await setUp()
    // Launch grapher
    let launchSuccess = try await launchApp(bundleId: "com.apple.grapher")
    #expect(launchSuccess)

    // Wait for app to initialize
    try await Task.sleep(for: .milliseconds(2000))

    // Get frontmost app to verify state - we don't need to check this value
    // just making sure grapher launched successfully
    _ = try await getFrontmostApp()

    // Switch to Finder (deactivate grapher)
    let switchToFinderSuccess = try await activateApp(bundleId: "com.apple.finder")
    #expect(switchToFinderSuccess, "Should successfully activate Finder")

    // Wait for app switch
    try await Task.sleep(for: .milliseconds(2000))

    // Get frontmost app to verify switch worked
    let frontmostAfterSwitch = try await getFrontmostApp()
    #expect(
      frontmostAfterSwitch?.bundleId == "com.apple.finder",
      "Finder should be frontmost after activation",
    )

    // Switch back to grapher
    let switchBackSuccess = try await activateApp(bundleId: "com.apple.grapher")
    #expect(switchBackSuccess, "Should successfully activate grapher again")

    // Wait for app switch
    try await Task.sleep(for: .milliseconds(2000))

    // Get frontmost app to verify switch back worked
    let frontmostAfterSwitchBack = try await getFrontmostApp()

    #expect(
      frontmostAfterSwitchBack?.bundleId == "com.apple.grapher",
      "grapher should be frontmost after activation",
    )

    // Test window counting with WindowManagementTool
    let windowCount = try await getWindowCount(bundleId: "com.apple.grapher")
    #expect(windowCount == 1, "Grapher is showing one window")
    // Terminate grapher
    let terminateSuccess = try await terminateApp(bundleId: "com.apple.grapher")
    #expect(terminateSuccess, "grapher should terminate successfully")
    try await tearDown()
  }

  // MARK: - Helper Methods

  /// Launch an application by bundle identifier
  private func launchApp(bundleId: String) async throws -> Bool {
    let params: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(bundleId), "waitForLaunch": .bool(true),
    ]

    let result = try await toolChain.applicationManagementTool.handler(params)

    // Check if launch was successful
    if let content = result.first, case .text(let text) = content {
      return text.contains("success") && text.contains("true")
    }

    return false
  }

  /// Activate an application by bundle identifier
  private func activateApp(bundleId: String) async throws -> Bool {
    let params: [String: Value] = [
      "action": .string("activateApplication"), "bundleId": .string(bundleId),
    ]

    let result = try await toolChain.applicationManagementTool.handler(params)

    // Check if activation was successful
    if let content = result.first, case .text(let text) = content {
      return text.contains("success") && text.contains("true")
    }

    return false
  }

  /// Terminate an application by bundle identifier
  private func terminateApp(bundleId: String) async throws -> Bool {
    let params: [String: Value] = ["action": .string("terminate"), "bundleId": .string(bundleId)]

    let result = try await toolChain.applicationManagementTool.handler(params)

    // Check if termination was successful
    if let content = result.first, case .text(let text) = content {
      return text.contains("success") && text.contains("true")
    }

    return false
  }

  /// Get the frontmost application
  private func getFrontmostApp() async throws -> ApplicationInfo? {
    let params: [String: Value] = ["action": .string("getFrontmostApplication")]

    let result = try await toolChain.applicationManagementTool.handler(params)

    // Parse the response to get application info
    if let content = result.first, case .text(let text) = content {
      // Extract application info from the JSON response
      if let data = text.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let bundleId = json["bundleId"] as? String,
         let appName = json["applicationName"] as? String
      {
        return ApplicationInfo(bundleId: bundleId, applicationName: appName)
      }
    }

    return nil
  }

  /// Get count of windows for an application
  private func getWindowCount(bundleId: String) async throws -> Int {
    // Use window management tool to get the application windows
    let windowParams: [String: Value] = [
      "action": .string("getApplicationWindows"), "bundleId": .string(bundleId),
      "includeMinimized": .bool(true),
    ]

    let result = try await toolChain.windowManagementTool.handler(windowParams)

    // Extract window count from result
    if let content = result.first, case .text(let text) = content {
      // Parse the JSON for window information
      if let data = text.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      {
        // The result directly contains an array of window descriptors
        return json.count
      }
    }

    return 0
  }
}
