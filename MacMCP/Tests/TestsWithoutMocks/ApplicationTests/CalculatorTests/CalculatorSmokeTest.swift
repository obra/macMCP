// ABOUTME: CalculatorSmokeTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// Smoke test for the Calculator app to verify basic MCP functionality
@Suite(.serialized)
struct CalculatorSmokeTest {
  // Calculator helper for testing
  private var calculatorHelper: CalculatorTestHelper!
  private var logger: Logger!
  private var logFileURL: URL?

  // Shared setup method 
  private mutating func setUp() async throws {
    // Set up standardized logging
    (logger, logFileURL) = TestLogger.create(label: "mcp.test.calculator", testName: "CalculatorSmokeTest")
    TestLogger.configureEnvironment(logger: logger)
    let _ = TestLogger.createDiagnosticLog(testName: "CalculatorSmokeTest", logger: logger)
    
    logger.info("Setting up CalculatorSmokeTest")
    
    // Get the shared calculator helper
    calculatorHelper = await CalculatorTestHelper.sharedHelper()
    logger.info("Obtained shared calculator helper")

    // Ensure app is running and reset state
    logger.info("Ensuring Calculator app is running")
    let _ = try await calculatorHelper.ensureAppIsRunning()
    
    logger.info("Resetting application state")
    await calculatorHelper.resetAppState()
    
    logger.info("Setup complete")
  }
  
  // Shared teardown method
  private mutating func tearDown() async throws {
    logger.info("Tearing down CalculatorSmokeTest")
    // Optional cleanup - in most cases the helper's reset handles this
    if calculatorHelper != nil {
      // No explicit termination since the helper may be reused
      logger.info("Helper may be reused, skipping termination")
    }
    logger.info("Teardown complete")
  }

  /// Test the most basic calculator interaction: press a button and read display
  @Test("Basic Button Press And Display Read")
  mutating func testBasicButtonPressAndDisplayRead() async throws {
    try await setUp()
    
    // Press the '5' button
    logger.info("Pressing '5' button")
    let buttonSuccess = try await calculatorHelper.app.pressButtonViaAccessibility("5")
    #expect(buttonSuccess, "Should be able to press the '5' button")
    try await Task.sleep(for: .milliseconds(500))

    // Verify the display shows "5"
    logger.info("Verifying display value is '5'")
    try await calculatorHelper.assertDisplayValue("5", message: "Display should show '5'")
    
    try await tearDown()
  }

  /// Test basic addition operation
  @Test("Basic Addition")
  mutating func testBasicAddition() async throws {
    try await setUp()
    
    // Press 3 + 4 = buttons
    logger.info("Executing calculation 3 + 4 = ")
    let pressSuccess1 = try await calculatorHelper.app.pressButtonViaAccessibility("3")
    #expect(pressSuccess1, "Should be able to press '3' button")

    let pressSuccess2 = try await calculatorHelper.app.pressButtonViaAccessibility("+")
    #expect(pressSuccess2, "Should be able to press '+' button")

    let pressSuccess3 = try await calculatorHelper.app.pressButtonViaAccessibility("4")
    #expect(pressSuccess3, "Should be able to press '4' button")

    let pressSuccess4 = try await calculatorHelper.app.pressButtonViaAccessibility("=")
    #expect(pressSuccess4, "Should be able to press '=' button")

    // Verify result is 7
    logger.info("Verifying display value is '7'")
    try await calculatorHelper.assertDisplayValue(
      "7", message: "Display should show the result '7'")
      
    try await tearDown()
  }
}