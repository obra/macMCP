// ABOUTME: CalculatorSmokeTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import XCTest

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// Smoke test for the Calculator app to verify basic MCP functionality
@MainActor
final class CalculatorSmokeTest: XCTestCase {
  // Calculator helper for testing
  private var calculatorHelper: CalculatorTestHelper!

  override func setUp() async throws {
    // Setup runs on the MainActor due to class annotation

    // Get the shared calculator helper
    calculatorHelper = CalculatorTestHelper.sharedHelper()

    // Ensure app is running and reset state
    let _ = try await calculatorHelper.ensureAppIsRunning()
    await calculatorHelper.resetAppState()
  }

  /// Test the most basic calculator interaction: press a button and read display
  func testBasicButtonPressAndDisplayRead() async throws {
    // Press the '5' button
    let buttonSuccess = try await calculatorHelper.app.pressButtonViaAccessibility("5")
    XCTAssertTrue(buttonSuccess, "Should be able to press the '5' button")
    try await Task.sleep(for: .milliseconds(500))

    // Verify the display shows "5"
    try await calculatorHelper.assertDisplayValue("5", message: "Display should show '5'")
  }

  /// Test basic addition operation
  func testBasicAddition() async throws {
    // Press 3 + 4 = buttons
    let pressSuccess1 = try await calculatorHelper.app.pressButtonViaAccessibility("3")
    XCTAssertTrue(pressSuccess1, "Should be able to press '3' button")

    let pressSuccess2 = try await calculatorHelper.app.pressButtonViaAccessibility("+")
    XCTAssertTrue(pressSuccess2, "Should be able to press '+' button")

    let pressSuccess3 = try await calculatorHelper.app.pressButtonViaAccessibility("4")
    XCTAssertTrue(pressSuccess3, "Should be able to press '4' button")

    let pressSuccess4 = try await calculatorHelper.app.pressButtonViaAccessibility("=")
    XCTAssertTrue(pressSuccess4, "Should be able to press '=' button")

    // Verify result is 7
    try await calculatorHelper.assertDisplayValue(
      "7", message: "Display should show the result '7'")
  }

  override func tearDown() async throws {
    // Clean up - no need to call super.tearDown() since we're on MainActor
    // and it would cause actor isolation issues
  }
}
