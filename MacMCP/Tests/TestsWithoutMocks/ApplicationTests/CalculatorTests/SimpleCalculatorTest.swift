// ABOUTME: SimpleCalculatorTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// A simpler approach to testing calculator functionality
@Suite(.serialized) struct SimpleCalculatorTest {
  private var app: CalculatorModel!
  private var toolChain: ToolChain!
  private var calculatorRunning = false
  private var logger: Logger!
  private var logFileURL: URL?

  // Shared setup method
  private mutating func setUp() async throws {
    // Set up standardized logging
    (logger, logFileURL) = TestLogger.create(
      label: "mcp.test.calculator", testName: "SimpleCalculatorTest",
    )
    TestLogger.configureEnvironment(logger: logger)
    _ = TestLogger.createDiagnosticLog(testName: "SimpleCalculatorTest", logger: logger)
    logger.debug("Setting up SimpleCalculatorTest")
    // Initialize toolchain and app model
    toolChain = ToolChain()
    app = CalculatorModel(toolChain: toolChain)

    // Terminate any existing calculator instances first to ensure clean state
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
    if !runningApps.isEmpty {
      logger.debug("Terminating existing Calculator instances")
      for runningApp in runningApps {
        _ = runningApp.terminate()
      }
      // Wait for termination to complete
      try await Task.sleep(for: .milliseconds(1000))
    }

    // Launch calculator fresh without hiding other apps
    logger.debug("Launching Calculator application")
    let launchSuccess = try await app.launch(hideOthers: false)
    #expect(launchSuccess, "Calculator should launch successfully")

    // Wait for app to be ready
    try await Task.sleep(for: .milliseconds(2000))

    // Ensure Calculator is frontmost application
    if let calcApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
      .first
    {
      logger.debug("Activating Calculator as frontmost application")
      let activateSuccess = calcApp.activate(options: [])
      if !activateSuccess { logger.warning("Failed to activate Calculator as frontmost app") }

      // Wait for activation
      try await Task.sleep(for: .milliseconds(500))
    }

    // Clear the calculator state
    logger.debug("Clearing calculator state")
    _ = try await app.clear()
    try await Task.sleep(for: .milliseconds(500)) // Wait for clear to complete

    calculatorRunning = true
    logger.debug("Calculator setup complete")
  }

  // Shared teardown method
  private mutating func tearDown() async throws {
    logger.debug("Tearing down SimpleCalculatorTest")
    if calculatorRunning {
      // Terminate the calculator application
      let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
      if !runningApps.isEmpty {
        logger.debug("Terminating Calculator application")
        for runningApp in runningApps {
          _ = runningApp.terminate()
        }
        // Wait for termination to complete
        try await Task.sleep(for: .milliseconds(1000))
      }
      calculatorRunning = false
    }
    logger.debug("Teardown complete")
  }

  @Test("Test basic button press") mutating func basicButtonPress() async throws {
    try await setUp()

    // Press the '5' button
    logger.debug("Pressing '5' button")
    let buttonSuccess = try await app.pressButtonViaAccessibility("5")
    #expect(buttonSuccess, "Should be able to press the '5' button")

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Read the display value
    logger.debug("Reading display value")
    let displayValue = try await app.getDisplayValue()
    #expect(displayValue != nil, "Should be able to read the display value")

    if let displayValue {
      logger.debug("Display value: '\(displayValue)'")
      let isExpectedValue =
        displayValue == "5" || displayValue == "5." || displayValue.hasPrefix("5")
      #expect(isExpectedValue, "Display should show '5', got '\(displayValue)'")
    }
    try await tearDown()
  }

  @Test("Test basic addition") mutating func basicAddition() async throws {
    try await setUp()
    // Clear the calculator first to ensure clean state
    logger.debug("Clearing calculator state")
    _ = try await app.clear()

    // Press 3 + 4 = buttons
    logger.debug("Executing calculation 3 + 4 = ")
    _ = try await app.pressButtonViaAccessibility("3")
    _ = try await app.pressButtonViaAccessibility("+")
    _ = try await app.pressButtonViaAccessibility("4")
    _ = try await app.pressButtonViaAccessibility("=")

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Read the display value
    logger.debug("Reading display value")
    let displayValue = try await app.getDisplayValue()
    #expect(displayValue != nil, "Should be able to read the display value")

    if let displayValue {
      logger.debug("Display value: '\(displayValue)'")
      let isExpectedValue =
        displayValue == "7" || displayValue == "7." || displayValue.hasPrefix("7")
      #expect(isExpectedValue, "Display should show '7', got '\(displayValue)'")
    }
    try await tearDown()
  }
}
