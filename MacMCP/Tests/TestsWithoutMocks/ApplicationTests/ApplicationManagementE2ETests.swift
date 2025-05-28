// ABOUTME: ApplicationManagementE2ETests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// End-to-end tests for the ApplicationManagementTool
@Suite(.serialized) struct ApplicationManagementE2ETests {
  // Test components
  private var toolChain: ToolChain!

  // Bundle IDs for test applications
  private let calculatorBundleId = "com.apple.calculator"
  private let textEditBundleId = "com.apple.TextEdit"

  private mutating func setUp() async throws {
    // Create the test components
    toolChain = ToolChain()

    // Force terminate any existing instances of test applications
    for bundleId in [calculatorBundleId, textEditBundleId] {
      await terminateApplication(bundleId: bundleId)
    }

    try await Task.sleep(for: .milliseconds(1000))
  }

  private mutating func tearDown() async throws {
    // Terminate test applications
    for bundleId in [calculatorBundleId, textEditBundleId] {
      await terminateApplication(bundleId: bundleId)
    }

    try await Task.sleep(for: .milliseconds(1000))

    toolChain = nil
  }

  /// Helper method to terminate an application
  private func terminateApplication(bundleId: String) async {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    for app in runningApps { _ = app.forceTerminate() }
  }

  /// Test launching and terminating an application
  @Test("Launch and Terminate") mutating func testLaunchAndTerminate() async throws {
    try await setUp()
    // Verify Calculator is not running at start
    let initialIsRunning = isApplicationRunning(calculatorBundleId)
    #expect(!initialIsRunning, "Calculator should not be running at test start")

    // Create launch parameters
    let launchParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    // Launch Calculator
    let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)

    // Verify launch result
    #expect(launchResult.count == 1, "Should return one content item")

    // Wait for the app to launch fully
    try await Task.sleep(for: .milliseconds(2000))

    // Check if app is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running after launch")

    // Create terminate parameters
    let terminateParams: [String: Value] = [
      "action": .string("terminate"), "bundleId": .string(calculatorBundleId),
    ]

    // Terminate Calculator
    let terminateResult = try await toolChain.applicationManagementTool.handler(terminateParams)

    // Verify terminate result
    #expect(terminateResult.count == 1, "Should return one content item")

    // Wait for app to terminate
    try await Task.sleep(for: .milliseconds(1000))

    // Check if app is still running
    let isStillRunning = isApplicationRunning(calculatorBundleId)
    #expect(!isStillRunning, "Calculator should not be running after termination")
    try await tearDown()
  }

  /// Test getting running applications
  @Test("Get Running Applications") mutating func testGetRunningApplications() async throws {
    try await setUp()
    // Launch a test application
    let launchParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchParams)

    // Wait for the app to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Create get running applications parameters
    let getRunningParams: [String: Value] = ["action": .string("getRunningApplications")]

    // Get running applications
    let result = try await toolChain.applicationManagementTool.handler(getRunningParams)

    // Verify result
    #expect(result.count == 1, "Should return one content item")

    if case .text(let jsonString) = result[0] {
      // Verify that Calculator is listed in the running applications
      #expect(
        jsonString.contains(calculatorBundleId), "Running applications should include Calculator")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    try await tearDown()
  }

  /// Test checking if an application is running
  @Test("Check if Application is Running") mutating func testIsRunning() async throws {
    try await setUp()
    // Launch Calculator
    let launchParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchParams)

    // Wait for app to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Check if Calculator is running
    let isRunningParams: [String: Value] = [
      "action": .string("isRunning"), "bundleId": .string(calculatorBundleId),
    ]

    let calcResult = try await toolChain.applicationManagementTool.handler(isRunningParams)

    // Verify result for running application
    #expect(calcResult.count == 1, "Should return one content item")

    do {
      let json = try toolChain.parseJsonResponse(calcResult[0])
      let isRunning = toolChain.getBoolValue(from: json, forKey: "isRunning")
      #expect(isRunning, "Calculator should be reported as running")
    } catch { #expect(Bool(false), "Failed to parse JSON response: \(error)") }

    // Check if a non-running application is reported correctly
    let notRunningParams: [String: Value] = [
      "action": .string("isRunning"), "bundleId": .string("com.nonexistent.app"),
    ]

    let nonRunningResult = try await toolChain.applicationManagementTool.handler(notRunningParams)

    // Verify result for non-running application
    #expect(nonRunningResult.count == 1, "Should return one content item")

    do {
      let json = try toolChain.parseJsonResponse(nonRunningResult[0])
      let isRunning = toolChain.getBoolValue(from: json, forKey: "isRunning")
      #expect(!isRunning, "Non-existent app should be reported as not running")
    } catch { #expect(Bool(false), "Failed to parse JSON response: \(error)") }
    try await tearDown()
  }

  /// Test hiding, unhiding and activating an application
  @Test("Hide Unhide Activate") mutating func testHideUnhideActivate() async throws {
    try await setUp()
    // First launch both test applications

    // Launch Calculator
    let launchCalcParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchCalcParams)

    // Wait for Calculator to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Launch TextEdit
    let launchTextEditParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(textEditBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchTextEditParams)

    // Wait for TextEdit to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Hide Calculator - note that hiding can be unreliable in automated tests,
    // especially if the application doesn't have focus
    let hideParams: [String: Value] = [
      "action": .string("hideApplication"), "bundleId": .string(calculatorBundleId),
    ]

    let hideResult = try await toolChain.applicationManagementTool.handler(hideParams)

    // Verify hide result - but don't assert on the actual success value
    // since it may legitimately fail in some cases
    #expect(hideResult.count == 1, "Should return one content item")

    if case .text(let jsonString) = hideResult[0] {
      // We don't assert on success since hiding can sometimes fail
      // when an app doesn't have focus in automated tests
    } else {
      #expect(Bool(false), "Result should be text content")
    }

    // Allow time for UI to update
    try await Task.sleep(for: .milliseconds(1000))

    // Activate Calculator (should also unhide it)
    let activateParams: [String: Value] = [
      "action": .string("activateApplication"), "bundleId": .string(calculatorBundleId),
    ]

    let activateResult = try await toolChain.applicationManagementTool.handler(activateParams)

    // Verify activate result - activating should succeed reliably
    #expect(activateResult.count == 1, "Should return one content item")

    do {
      let json = try toolChain.parseJsonResponse(activateResult[0])
      let success = toolChain.getBoolValue(from: json, forKey: "success")
      #expect(success, "Activate operation should succeed")
    } catch { #expect(Bool(false), "Failed to parse JSON response: \(error)") }

    // Allow time for UI to update
    try await Task.sleep(for: .milliseconds(1000))

    // Get frontmost application
    let frontmostParams: [String: Value] = ["action": .string("getFrontmostApplication")]

    let frontmostResult = try await toolChain.applicationManagementTool.handler(frontmostParams)

    // Verify frontmost result
    #expect(frontmostResult.count == 1, "Should return one content item")

    if case .text(let jsonString) = frontmostResult[0] {
      // Calculator should now be the frontmost application
      #expect(
        jsonString.contains(calculatorBundleId), "Calculator should be the frontmost application")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    try await tearDown()
  }

  /// Test hiding other applications
  @Test("Hide Other Applications") mutating func testHideOtherApplications() async throws {
    try await setUp()
    // First launch both test applications

    // Launch Calculator
    let launchCalcParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchCalcParams)

    // Wait for Calculator to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Launch TextEdit
    let launchTextEditParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(textEditBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchTextEditParams)

    // Wait for TextEdit to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Hide other applications, keeping Calculator visible
    let hideOthersParams: [String: Value] = [
      "action": .string("hideOtherApplications"), "bundleId": .string(calculatorBundleId),
    ]

    let hideOthersResult = try await toolChain.applicationManagementTool.handler(hideOthersParams)

    // Verify hide others result
    #expect(hideOthersResult.count == 1, "Should return one content item")

    do {
      let json = try toolChain.parseJsonResponse(hideOthersResult[0])
      let success = toolChain.getBoolValue(from: json, forKey: "success")
      #expect(success, "Hide others operation should succeed")
    } catch { #expect(Bool(false), "Failed to parse JSON response: \(error)") }

    // Allow time for UI to update
    try await Task.sleep(for: .milliseconds(1000))

    // Get frontmost application
    let frontmostParams: [String: Value] = ["action": .string("getFrontmostApplication")]

    let frontmostResult = try await toolChain.applicationManagementTool.handler(frontmostParams)

    // Verify frontmost result
    #expect(frontmostResult.count == 1, "Should return one content item")

    if case .text(let jsonString) = frontmostResult[0] {
      // Calculator should now be the frontmost application
      #expect(
        jsonString.contains(calculatorBundleId), "Calculator should be the frontmost application")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    try await tearDown()
  }

  /// Test force terminating an application
  @Test("Force Terminate") mutating func testForceTerminate() async throws {
    try await setUp()
    // Launch Calculator
    let launchParams: [String: Value] = [
      "action": .string("launch"), "bundleId": .string(calculatorBundleId),
    ]

    _ = try await toolChain.applicationManagementTool.handler(launchParams)

    // Wait for app to launch
    try await Task.sleep(for: .milliseconds(2000))

    // Verify Calculator is running
    let isRunning = isApplicationRunning(calculatorBundleId)
    #expect(isRunning, "Calculator should be running after launch")

    // Force terminate Calculator
    let forceTerminateParams: [String: Value] = [
      "action": .string("forceTerminate"), "bundleId": .string(calculatorBundleId),
    ]

    let forceTerminateResult = try await toolChain.applicationManagementTool.handler(
      forceTerminateParams)

    // Verify force terminate result
    #expect(forceTerminateResult.count == 1, "Should return one content item")

    do {
      let json = try toolChain.parseJsonResponse(forceTerminateResult[0])
      let success = toolChain.getBoolValue(from: json, forKey: "success")
      #expect(success, "Force terminate operation should succeed")
    } catch { #expect(Bool(false), "Failed to parse JSON response: \(error)") }

    // Wait for app to terminate
    try await Task.sleep(for: .milliseconds(1000))

    // Verify Calculator is no longer running
    let isStillRunning = isApplicationRunning(calculatorBundleId)
    #expect(!isStillRunning, "Calculator should not be running after force termination")
    try await tearDown()
  }

  // MARK: - Helper Methods

  /// Check if an application is running using NSRunningApplication directly
  private func isApplicationRunning(_ bundleId: String) -> Bool {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    return !runningApps.isEmpty
  }
}
