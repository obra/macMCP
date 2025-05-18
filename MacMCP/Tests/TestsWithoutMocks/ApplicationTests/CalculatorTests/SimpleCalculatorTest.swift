// ABOUTME: SimpleCalculatorTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import XCTest

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// A simpler approach to testing calculator functionality
final class SimpleCalculatorTest: XCTestCase {
  private var app: CalculatorModel!
  private var toolChain: ToolChain!
  private var calculatorRunning = false

  override func setUp() async throws {
    try await super.setUp()

    // Create tool chain
    toolChain = ToolChain()

    // Create app model
    app = CalculatorModel(toolChain: toolChain)

    // We don't need to use the helper here since we're implementing the same logic directly

    // Since we need to use our specific app instance, call the methods directly
    // but follow the same pattern as the helper's ensureAppIsRunning method

    // Terminate any existing calculator instances first to ensure clean state
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
    for runningApp in runningApps {
      _ = runningApp.terminate()
    }

    // Wait for termination to complete
    if !runningApps.isEmpty {
      try await Task.sleep(for: .milliseconds(1000))
    }

    // Launch calculator fresh without hiding other apps
    let launchSuccess = try await app.launch(hideOthers: false)
    XCTAssertTrue(launchSuccess, "Calculator should launch successfully")

    // Wait for app to be ready
    try await Task.sleep(for: .milliseconds(2000))

    // Ensure Calculator is frontmost application
    if let calcApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
      .first
    {
      let activateSuccess = calcApp.activate(options: [])
      if !activateSuccess {
        print("Warning: Failed to activate Calculator as frontmost app")
      }

      // Wait for activation
      try await Task.sleep(for: .milliseconds(500))
    }

    // Clear the calculator
    _ = try await app.clear()
    try await Task.sleep(for: .milliseconds(500))  // Wait for clear to complete

    calculatorRunning = true

    // Note: ensureAppIsRunning includes clearing the calculator and proper delays
  }

  override func tearDown() async throws {
    // Don't terminate calculator between tests
    try await super.tearDown()
  }

  /// Test the most basic calculator interaction: press a button and read display
  func testBasicButtonPress() async throws {
    // Press the '5' button
    let buttonSuccess = try await app.pressButtonViaAccessibility("5")
    XCTAssertTrue(buttonSuccess, "Should be able to press the '5' button")

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Read the display value
    let displayValue = try await app.getDisplayValue()
    XCTAssertNotNil(displayValue, "Should be able to read the display value")

    if let displayValue {
      let isExpectedValue =
        displayValue == "5" || displayValue == "5." || displayValue.hasPrefix("5")
      XCTAssertTrue(isExpectedValue, "Display should show '5', got '\(displayValue)'")
    }
  }

  /// Test basic addition operation
  func testBasicAddition() async throws {
    // Clear the calculator first
    _ = try await app.clear()

    // Press 3 + 4 = buttons
    _ = try await app.pressButtonViaAccessibility("3")
    _ = try await app.pressButtonViaAccessibility("+")
    _ = try await app.pressButtonViaAccessibility("4")
    _ = try await app.pressButtonViaAccessibility("=")

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Read the display value
    let displayValue = try await app.getDisplayValue()
    XCTAssertNotNil(displayValue, "Should be able to read the display value")

    if let displayValue {
      let isExpectedValue =
        displayValue == "7" || displayValue == "7." || displayValue.hasPrefix("7")
      XCTAssertTrue(isExpectedValue, "Display should show '7', got '\(displayValue)'")
    }
  }
}
