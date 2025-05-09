// ABOUTME: This file tests the accessibility interactions with the Calculator app through MCP.
// ABOUTME: It verifies that the MCP tools can locate, identify, and interact with UI elements.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

/// Test case for MCP's ability to interact with the Calculator app
final class BasicArithmeticTest: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private var calculator: CalculatorModel!
    private var uiVerifier: UIVerifier!
    
    override func setUp() async throws {
        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        uiVerifier = UIVerifier(toolChain: toolChain)
    }
    
    /// Helper to ensure calculator is in a clean state before tests
    private func resetCalculator() async throws {
        // Terminate any existing calculator instances
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.terminate()
        }
        try await Task.sleep(for: .milliseconds(1000))
        
        // Launch calculator and wait for it to be ready
        let launchSuccess = try await calculator.launch()
        XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
        try await Task.sleep(for: .milliseconds(2000))
        
        // Clear the calculator
        let clearSuccess = try await calculator.clear()
        XCTAssertTrue(clearSuccess, "Calculator should clear successfully")
        try await Task.sleep(for: .milliseconds(500))
    }
    
    /// Test that UI elements can be properly identified and interacted with
    func testUIElementInteraction() async throws {
        // Set up calculator
        try await resetCalculator()
        
        // Test 1: Verify we can get the main window
        let window = try await calculator.getMainWindow()
        XCTAssertNotNil(window, "Should find the main calculator window")
        
        // Test 2: Verify we can find buttons by their descriptions
        let button2 = try await calculator.findButton("2")
        XCTAssertNotNil(button2, "Should find button '2'")
        
        let buttonPlus = try await calculator.findButton("+")
        XCTAssertNotNil(buttonPlus, "Should find button '+'")
        
        // Test 3: Verify we can interact with buttons via accessibility
        let buttonSuccess = try await calculator.pressButton("2")
        XCTAssertTrue(buttonSuccess, "Should be able to press button '2'")
        try await Task.sleep(for: .milliseconds(300))
        
        // Test 4: Verify we can read the display value after interaction
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertNotNil(displayValue, "Should be able to read the display value")
        XCTAssertEqual(displayValue, "2", "Display should show the pressed button value")
        
        // Close the calculator
        let terminateSuccess = try await calculator.terminate()
        XCTAssertTrue(terminateSuccess, "Calculator should terminate successfully")
    }
    
    /// Test that we can use different methods to interact with UI elements
    func testDifferentInteractionMethods() async throws {
        // Set up calculator
        try await resetCalculator()
        
        // Test 1: Using button press via AXPress
        let accessibilitySuccess = try await calculator.pressButtonViaAccessibility("5")
        XCTAssertTrue(accessibilitySuccess, "Should be able to press button via accessibility")
        try await Task.sleep(for: .milliseconds(300))
        
        // Verify the interaction worked
        var displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "5", "Display should show '5'")
        
        // Clear for the next test
        let clearSuccess = try await calculator.clear()
        XCTAssertTrue(clearSuccess, "Should be able to clear the calculator")
        try await Task.sleep(for: .milliseconds(300))
        
        // Test 2: Using keyboard input
        let keyboardSuccess = try await calculator.typeDigit("7")
        XCTAssertTrue(keyboardSuccess, "Should be able to type digit via keyboard")
        try await Task.sleep(for: .milliseconds(300))
        
        // Verify the interaction worked
        displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "7", "Display should show '7'")
        
        // Close the calculator
        let terminateSuccess = try await calculator.terminate()
        XCTAssertTrue(terminateSuccess, "Calculator should terminate successfully")
    }
    
    /// Test that we can handle more complex UI interactions
    func testSequentialUIInteractions() async throws {
        // Set up calculator
        try await resetCalculator()
        
        // Test: Enter a sequence of button presses and check the display
        let sequenceSuccess = try await calculator.enterSequence("123")
        XCTAssertTrue(sequenceSuccess, "Should be able to enter a sequence of buttons")
        try await Task.sleep(for: .milliseconds(300))
        
        // Verify the result shows the correct sequence
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "123", "Display should show the entered sequence")
        
        // Close the calculator
        let terminateSuccess = try await calculator.terminate()
        XCTAssertTrue(terminateSuccess, "Calculator should terminate successfully")
    }
}