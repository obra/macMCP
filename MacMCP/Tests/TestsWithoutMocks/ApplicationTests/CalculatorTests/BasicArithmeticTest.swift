// ABOUTME: This file tests the accessibility interactions with the Calculator app through MCP.
// ABOUTME: It verifies that the MCP tools can locate, identify, and interact with UI elements.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

// Import shared test utilities
@_implementationOnly import TestsWithoutMocks

/// Test case for MCP's ability to interact with the Calculator app
@MainActor
final class BasicArithmeticTest: XCTestCase {
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
    
    /// Test simple direct UI inspection of Calculator
    func testUIInspection() async throws {
        // Look for window elements
        let windows = try await calculatorHelper.toolChain.findElements(
            matching: UIElementCriteria(role: "AXWindow"),
            scope: "application", 
            bundleId: "com.apple.calculator",
            maxDepth: 5
        )
        
        // Simple assertion - should have found at least one window
        XCTAssertFalse(windows.isEmpty, "Should find at least one window")
        
        // Look for buttons
        let buttons = try await calculatorHelper.toolChain.findElements(
            matching: UIElementCriteria(role: "AXButton"),
            scope: "application",
            bundleId: "com.apple.calculator",
            maxDepth: 10
        )
        
        // Simple assertion - should have found buttons
        XCTAssertFalse(buttons.isEmpty, "Should find at least one button")
        
        // Look for static text elements that might contain the display value
        let textElements = try await calculatorHelper.toolChain.findElements(
            matching: UIElementCriteria(role: "AXStaticText"),
            scope: "application",
            bundleId: "com.apple.calculator",
            maxDepth: 10
        )
        
        // Should find at least one text element (the display)
        XCTAssertFalse(textElements.isEmpty, "Should find at least one text element")
        
        // Test a simple interaction with the calculator
        // Try to type a digit using the keyboard interaction tool
        _ = try await calculatorHelper.toolChain.typeTextWithKeyboard(text: "1")
        
        // Wait for UI to update
        try await Task.sleep(for: .milliseconds(500))
        
        // Verify the display shows "1"
        try await calculatorHelper.assertDisplayValue("1", message: "Display should show '1'")
    }
    
    /// Test sequential UI interactions like entering a series of button presses
    func testSequentialUIInteractions() async throws {
        // Enter a sequence of button presses
        let sequenceSuccess = try await calculatorHelper.app.enterSequence("123")
        XCTAssertTrue(sequenceSuccess, "Should be able to enter a sequence of buttons")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify the result shows the correct sequence
        try await calculatorHelper.assertDisplayValue("123", message: "Display should show the entered sequence '123'")
    }
    
    /// Test calculator operations using keyboard input
    func testKeyboardInput() async throws {
        // Use the keyboard interaction tool to type a simple calculation
        let typingSuccess = try await calculatorHelper.app.typeText("123+456=")
        XCTAssertTrue(typingSuccess, "Should be able to type text using keyboard")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify the result is 579 (123+456)
        try await calculatorHelper.assertDisplayValue("579", message: "Display should show the result '579'")

        // Test with different calculation
        await calculatorHelper.resetAppState()

        // Use direct typing for 50*2=
        let typingSuccess2 = try await calculatorHelper.app.typeText("50*2=")
        XCTAssertTrue(typingSuccess2, "Should be able to type calculation using keyboard")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify the result is 100 (50*2)
        try await calculatorHelper.assertDisplayValue("100", message: "Display should show the result '100'")

        // Now test more complex key sequences
        await calculatorHelper.resetAppState()

        // Create a more complex sequence with explicit modifiers for special characters
        let keySequence: [[String: Value]] = [
            // First tap 5
            ["tap": .string("5")],

            // Tap * (shift+8)
            ["tap": .string("8"), "modifiers": .array([.string("shift")])],

            // Tap 4
            ["tap": .string("4")],

            // Add a small delay (200ms)
            ["delay": .double(0.2)],

            // Press plus (shift+=)
            ["tap": .string("="), "modifiers": .array([.string("shift")])],

            // Tap 6
            ["tap": .string("6")],

            // Tap =
            ["tap": .string("=")]
        ]

        let keySequenceSuccess = try await calculatorHelper.app.executeKeySequence(keySequence)
        XCTAssertTrue(keySequenceSuccess, "Should be able to execute complex key sequence")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify the result is 26 (5*4+6)
        try await calculatorHelper.assertDisplayValue("26", message: "Display should show the result '26'")
    }
}
