// ABOUTME: CalculatorTestHelper.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import Testing

@testable import MacMCP

/// Helper class for Calculator testing, providing shared resources and convenience methods
@MainActor
public final class CalculatorTestHelper {
  // MARK: - Properties

  /// The Calculator app model
  public let app: CalculatorModel

  /// The ToolChain for interacting with MCP tools
  public let toolChain: ToolChain

  // Singleton instance for shared usage
  private static var _sharedHelper: CalculatorTestHelper?

  // MARK: - Initialization

  /// Initialize with a new tool chain
  public init() {
    // Create a tool chain
    toolChain = ToolChain(logLabel: "mcp.test.calculator")

    // Create a Calculator model
    app = CalculatorModel(toolChain: toolChain)
  }

  /// Get or create a shared helper instance to avoid multiple app launches
  /// - Returns: A shared calculator helper instance
  public static func sharedHelper() -> CalculatorTestHelper {
    if let helper = _sharedHelper {
      return helper
    }

    // Create a new instance
    let helper = CalculatorTestHelper()
    _sharedHelper = helper
    return helper
  }

  // MARK: - Calculator Operations

  /// Ensure the Calculator app is running, properly foregrounded, and ready for testing
  /// - Parameters:
  ///   - forceRelaunch: Whether to force relaunching the app even if it's already running
  ///   - hideOthers: Whether to hide other applications when launching (defaults to false)
  /// - Returns: True if the app is running and ready
  public func ensureAppIsRunning(forceRelaunch: Bool = false, hideOthers: Bool = false) async throws
    -> Bool
  {
    let isRunning = try await app.isRunning()

    // If forceRelaunch is true or app is not running, terminate any existing instances and relaunch
    if forceRelaunch || !isRunning {
      // Terminate any existing calculator instances first to ensure clean state
      let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
      for runningApp in runningApps {
        _ = runningApp.terminate()
      }

      // Wait for termination to complete
      if !runningApps.isEmpty {
        try await Task.sleep(for: .milliseconds(1000))
      }

      // Launch calculator fresh
      _ = try await app.launch(hideOthers: hideOthers)

      // Wait for app to be ready
      try await Task.sleep(for: .milliseconds(2000))
    }

    // Ensure Calculator is frontmost application regardless of whether we just launched it
    if let calcApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
      .first
    {
      let activateSuccess = calcApp.activate(options: [])
      if !activateSuccess {
        print("Warning: Failed to activate Calculator as frontmost app")
      }

      // Wait for activation
      try await Task.sleep(for: .milliseconds(500))
    } else {
      return false
    }

    // Wait for Calculator UI to be ready before proceeding
    try await waitForCalculatorUIReady()

    // Clear the calculator
    _ = try await app.clear()
    try await Task.sleep(for: .milliseconds(500))  // Wait for clear to complete

    return true
  }

  /// Wait for Calculator UI to be ready and accessible
  /// - Throws: Error if UI doesn't become ready within timeout
  private func waitForCalculatorUIReady() async throws {
    let maxAttempts = 10
    let delayMs = 500
    
    for attempt in 1...maxAttempts {
      // Try to verify that basic UI elements are accessible
      do {
        // Check if we can find the main window
        if let _ = try await app.getMainWindow() {
          // Try to find a basic button to ensure the UI is loaded
          if let _ = try await app.findButton("1") {
            // UI is ready
            return
          }
        }
      } catch {
        // UI not ready yet, continue waiting
      }
      
      if attempt < maxAttempts {
        try await Task.sleep(for: .milliseconds(delayMs))
      }
    }
    
    // If we get here, UI didn't become ready in time
    throw NSError(
      domain: "CalculatorTestHelper",
      code: 2000,
      userInfo: [NSLocalizedDescriptionKey: "Calculator UI did not become ready within timeout"]
    )
  }

  /// Reset the Calculator app state (clear the display)
  public func resetAppState() async {
    // First try to clear the calculator
    do {
      _ = try await app.clear()
      try await Task.sleep(for: .milliseconds(500))
    } catch {
      // If clear fails, try to terminate and relaunch
      do {
        _ = try await app.terminate()
        try await Task.sleep(for: .milliseconds(1000))
        _ = try await app.launch()
        try await Task.sleep(for: .milliseconds(1000))
      } catch {
        // Log error but continue - we'll do our best with the current state
        print("Warning: Could not reset calculator state: \(error)")
      }
    }
  }

  /// Assert that the Calculator display shows a specific value
  /// - Parameters:
  ///   - expectedValue: The expected value
  ///   - message: Custom assertion message
  public func assertDisplayValue(_ expectedValue: String, message: String = "") async throws {
    // Get the actual display value
    let actualValue = try await app.getDisplayValue()

    // Use the custom message if provided, otherwise create a default message
    let _ =
      message.isEmpty
      ? "Calculator display should show '\(expectedValue)' but found '\(actualValue ?? "nil")'"
      : message

    // Use Swift Testing framework's expect - can't pass message directly
    #expect(actualValue == expectedValue)
  }

  /// Press a button on the Calculator
  /// - Parameter buttonLabel: Label of the button to press
  /// - Returns: True if the button was successfully pressed
  public func pressButton(_ buttonLabel: String) async throws -> Bool {
    try await app.pressButton(buttonLabel)
  }

  /// Enter a sequence of button presses
  /// - Parameter sequence: The sequence of buttons to press (e.g., "123+456=")
  /// - Returns: True if all buttons were successfully pressed
  public func enterSequence(_ sequence: String) async throws -> Bool {
    try await app.enterSequence(sequence)
  }

  /// Type text using the keyboard
  /// - Parameter text: The text to type
  /// - Returns: True if the text was successfully typed
  public func typeText(_ text: String) async throws -> Bool {
    try await app.typeText(text)
  }

  /// Take a screenshot of the calculator
  /// - Returns: Path to the screenshot file
  public func takeScreenshot() async throws -> String? {
    // Use the screenshot tool to take a screenshot
    let params: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string(app.bundleId),
    ]

    let result = try await toolChain.screenshotTool.handler(params)

    // Extract the screenshot path from the result
    if let content = result.first, case .text(let text) = content {
      if let path = text.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
      {
        return path
      }
    }

    return nil
  }

  /// Perform a simple calculation and verify the result
  /// - Parameters:
  ///   - input: The calculation to perform (e.g., "2+2=")
  ///   - expectedResult: The expected result
  /// - Returns: True if the calculation was successful and matches the expected result
  public func performCalculation(input: String, expectedResult: String) async throws -> Bool {
    // Clear the calculator
    await resetAppState()

    // Enter the calculation
    _ = try await enterSequence(input)

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Get the actual result
    let actualResult = try await app.getDisplayValue()

    // Return true if the result matches expected
    return actualResult == expectedResult
  }
}
