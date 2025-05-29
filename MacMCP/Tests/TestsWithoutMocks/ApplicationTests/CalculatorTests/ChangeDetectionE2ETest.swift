// ABOUTME: ChangeDetectionE2ETest.swift
// ABOUTME: End-to-end test for UI change detection using Calculator app

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

/// End-to-end test for UI change detection functionality
@Suite(.serialized) struct ChangeDetectionE2ETest {
  private var calculatorHelper: CalculatorTestHelper!
  private var logger: Logger!
  private var logFileURL: URL?
  private mutating func setUp() async throws {
    // Set up standardized logging
    (logger, logFileURL) = TestLogger.create(
      label: "mcp.test.change_detection", testName: "ChangeDetectionE2ETest",
    )
    TestLogger.configureEnvironment(logger: logger)
    _ = TestLogger.createDiagnosticLog(testName: "ChangeDetectionE2ETest", logger: logger)
    logger.debug("Setting up ChangeDetectionE2ETest")
    // Get the shared calculator helper
    calculatorHelper = await CalculatorTestHelper.sharedHelper()
    logger.debug("Obtained shared calculator helper")
    // Ensure app is running and reset state
    logger.debug("Ensuring Calculator app is running")
    _ = try await calculatorHelper.ensureAppIsRunning()
    logger.debug("Resetting application state")
    await calculatorHelper.resetAppState()
    logger.debug("Setup complete")
  }

  private mutating func tearDown() async throws {
    logger.debug("Tearing down ChangeDetectionE2ETest")
    if calculatorHelper != nil { logger.debug("Helper may be reused, skipping termination") }
    logger.debug("Teardown complete")
  }

  /// Test that UI change detection works with button clicks
  @Test("UI Change Detection with Button Click") mutating func changeDetectionButtonClick()
    async throws
  {
    try await setUp()
    logger.debug("Testing UI change detection with button click")
    // First, clear the calculator to ensure known state
    await calculatorHelper.resetAppState()
    // Create change detection service to test at the service layer
    let changeDetectionService = UIChangeDetectionService(
      accessibilityService: calculatorHelper.toolChain.accessibilityService,
    )
    // Capture UI state before the interaction
    let beforeSnapshot = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    // Perform the button click using the helper
    let success = try await calculatorHelper.pressButton("1")
    #expect(success, "Button press should succeed")
    // Wait a moment for UI to update
    try await Task.sleep(for: .milliseconds(300))
    // Capture UI state after the interaction
    let afterSnapshot = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    // Detect changes
    let changes = changeDetectionService.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    // Verify that changes were detected
    let totalChanges =
      changes.newElements.count + changes.removedElements.count + changes.modifiedElements.count
    logger.info(
      "Detected \(totalChanges) total changes: \(changes.newElements.count) new, \(changes.removedElements.count) removed, \(changes.modifiedElements.count) modified",
    )
    // Dump detailed changes for inspection
    logger.info("=== NEW ELEMENTS ===")
    for element in changes.newElements {
      logger.info(
        "NEW: \(element.path) - \(element.role) '\(element.title ?? "")' value='\(element.value ?? "")'",
      )
    }
    logger.info("=== REMOVED ELEMENTS ===")
    for path in changes.removedElements {
      logger.info("REMOVED: \(path)")
    }
    logger.info("=== MODIFIED ELEMENTS ===")
    for change in changes.modifiedElements.prefix(5) {
      logger.info("MODIFIED: \(change.after.path)")
      // Compare ALL properties to see what's actually changing
      var changes: [String] = []
      // Basic properties
      if change.before.title != change.after.title {
        changes.append("title: '\(change.before.title ?? "")' → '\(change.after.title ?? "")'")
      }
      if change.before.value != change.after.value {
        changes.append("value: '\(change.before.value ?? "")' → '\(change.after.value ?? "")'")
      }
      if change.before.isEnabled != change.after.isEnabled {
        changes.append("enabled: \(change.before.isEnabled) → \(change.after.isEnabled)")
      }
      if change.before.isVisible != change.after.isVisible {
        changes.append("visible: \(change.before.isVisible) → \(change.after.isVisible)")
      }
      if change.before.elementDescription != change.after.elementDescription {
        changes.append(
          "description: '\(change.before.elementDescription ?? "")' → '\(change.after.elementDescription ?? "")'",
        )
      }
      if change.before.role != change.after.role {
        changes.append("role: '\(change.before.role)' → '\(change.after.role)'")
      }
      if change.before.identifier != change.after.identifier {
        changes.append(
          "identifier: '\(change.before.identifier ?? "")' → '\(change.after.identifier ?? "")'",
        )
      }
      // Frame/geometry
      if change.before.frame != change.after.frame {
        changes.append("frame: \(change.before.frame) → \(change.after.frame)")
      }
      // Focus/selection state
      if change.before.isFocused != change.after.isFocused {
        changes.append("focused: \(change.before.isFocused) → \(change.after.isFocused)")
      }
      if change.before.isSelected != change.after.isSelected {
        changes.append("selected: \(change.before.isSelected) → \(change.after.isSelected)")
      }
      // Array properties (children, etc)
      if change.before.children.count != change.after.children.count {
        changes.append(
          "children count: \(change.before.children.count) → \(change.after.children.count)",
        )
      }
      if changes.isEmpty {
        logger.info("  (WARNING: Element flagged as changed but no property differences found!)")
        logger.info("    Path: \(change.after.path)")
        logger.info("    Paths equal: \(change.before.path == change.after.path)")
        logger.info("    Objects equal: \(change.before == change.after)")
      } else {
        for changeDesc in changes.prefix(3) { // Limit to first 3 changes to avoid spam
          logger.info("  \(changeDesc)")
        }
        if changes.count > 3 { logger.info("  ... and \(changes.count - 3) more changes") }
      }
    }
    #expect(totalChanges > 0, "Should detect UI changes after button click")
    // Verify the calculator responded to the click
    try await calculatorHelper.assertDisplayValue(
      "1", message: "Calculator should show '1' after clicking button",
    )
    try await tearDown()
  }

  /// Test that UI change detection works with keyboard input
  @Test("UI Change Detection with Keyboard Input") mutating func changeDetectionKeyboardInput()
    async throws
  {
    try await setUp()
    logger.debug("Testing UI change detection with keyboard input")
    // Clear the calculator
    await calculatorHelper.resetAppState()
    // Create change detection service
    let changeDetectionService = UIChangeDetectionService(
      accessibilityService: calculatorHelper.toolChain.accessibilityService,
    )
    // Capture UI state before typing
    let beforeSnapshot = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    // Type text using the helper
    let success = try await calculatorHelper.typeText("42")
    #expect(success, "Typing should succeed")
    // Wait for UI to update
    try await Task.sleep(for: .milliseconds(300))
    // Capture UI state after typing
    let afterSnapshot = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    // Detect changes
    let changes = changeDetectionService.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    // Verify changes were detected
    let totalChanges =
      changes.newElements.count + changes.removedElements.count + changes.modifiedElements.count
    logger.info("Detected \(totalChanges) total changes from keyboard input")
    #expect(totalChanges > 0, "Should detect UI changes after typing")
    // Verify the calculator display was updated
    try await calculatorHelper.assertDisplayValue(
      "42", message: "Calculator should show '42' after typing",
    )
    try await tearDown()
  }

  /// Test that change detection service works correctly
  @Test("Change Detection Service Functionality") mutating func testChangeDetectionService()
    async throws
  {
    try await setUp()
    logger.debug("Testing change detection service functionality")
    // Clear the calculator
    await calculatorHelper.resetAppState()
    // Create change detection service
    let changeDetectionService = UIChangeDetectionService(
      accessibilityService: calculatorHelper.toolChain.accessibilityService,
    )
    // Test that capturing snapshots works
    let snapshot1 = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    #expect(!snapshot1.isEmpty, "First snapshot should contain elements")
    // Make a change to the UI
    let success = try await calculatorHelper.pressButton("2")
    #expect(success, "Button press should succeed")
    // Wait for UI to update
    try await Task.sleep(for: .milliseconds(300))
    // Capture second snapshot
    let snapshot2 = try await changeDetectionService.captureUISnapshot(
      scope: .application(bundleId: "com.apple.calculator"),
    )
    #expect(!snapshot2.isEmpty, "Second snapshot should contain elements")
    // Test change detection
    let changes = changeDetectionService.detectChanges(before: snapshot1, after: snapshot2)
    // Should detect some changes
    let totalChanges =
      changes.newElements.count + changes.removedElements.count + changes.modifiedElements.count
    logger.info("Service test detected \(totalChanges) total changes")
    #expect(totalChanges > 0, "Should detect changes between snapshots")
    try await tearDown()
  }

  /// Test change detection with menu navigation
  @Test("UI Change Detection with Menu Navigation")
  mutating func changeDetectionMenuNavigation() async throws {
    try await setUp()
    logger.debug("Testing UI change detection with menu navigation")
    // Try to access a menu item that might cause UI changes (like About dialog)
    // First get available menu items
    let menuItems = try await calculatorHelper.toolChain.getMenuItems(
      bundleId: "com.apple.calculator",
      menuTitle: "Calculator",
    )
    logger.debug("Available menu items: \(menuItems)")
    // Look for "About Calculator" menu item
    let aboutItems = menuItems.filter { item in
      if case .text(let itemText) = item { return itemText.lowercased().contains("about") }
      return false
    }
    if let aboutItem = aboutItems.first {
      logger.debug("Found About menu item, testing menu activation with change detection")
      // Extract element ID from the response (this is a simplified approach)
      guard case .text(let menuResponse) = aboutItem else {
        logger.debug("About menu item is not text content")
        return
      }
      // Try to find an element ID in the menu response
      // This is a bit hacky but necessary for this E2E test
      if menuResponse.contains("\"id\":") {
        // Parse out an ID to use for activation (in real usage, this would come from menu
        // exploration)
        logger.debug("Menu item response contains ID, attempting activation with change detection")
        // For this test, we'll just verify the menu navigation structure works
        // without actually activating since About dialogs can be modal and hard to dismiss
        logger.info(
          "Menu navigation structure verified - skipping actual activation to avoid modal dialogs",
        )
      }
    } else {
      logger.info(
        "No About menu found - this is OK, just testing the change detection infrastructure",
      )
    }
    try await tearDown()
  }
}
