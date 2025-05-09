// ABOUTME: This file contains a simple smoke test for the Calculator app.
// ABOUTME: It tests basic button press and value reading to ensure MCP can interact with macOS apps.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

/// Smoke test for the Calculator app to verify basic MCP functionality
final class CalculatorSmokeTest: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private var calculator: CalculatorModel!
    
    override func setUp() async throws {
        print("==== Setting up Calculator smoke test ====")
        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        
        // Make sure no calculator instances are running at the start
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            print("Force terminating pre-existing Calculator instance: \(app.processIdentifier)")
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    /// Test the most basic calculator interaction: press a button and read display
    func testBasicButtonPressAndDisplayRead() async throws {
        print("\n==== testBasicButtonPressAndDisplayRead: Starting basic smoke test ====")
        
        // Launch calculator
        let launchSuccess = try await calculator.launch()
        XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
        
        // Wait for the app to fully initialize
        try await Task.sleep(for: .milliseconds(2000))
        
        // Verify the app is running
        let isRunning = try await calculator.isRunning()
        XCTAssertTrue(isRunning, "Calculator should be running after launch")
        
        // Clear the calculator using ESC key
        print("Clearing calculator with ESC key...")
        let clearSuccess = try await toolChain.pressKey(keyCode: 53) // ESC key
        XCTAssertTrue(clearSuccess, "Calculator should clear successfully")
        try await Task.sleep(for: .milliseconds(500))
        
        // Press the '5' button
        print("Pressing button '5'...")
        let buttonSuccess = try await calculator.pressButtonViaAccessibility("5")
        XCTAssertTrue(buttonSuccess, "Should be able to press the '5' button")
        try await Task.sleep(for: .milliseconds(500))
        
        // Read the display value - this is the key part we're testing
        print("Reading display value...")
        let displayValue = try await calculator.getDisplayValue()
        print("Display value: \(String(describing: displayValue))")
        
        // Verify the display shows "5"
        XCTAssertNotNil(displayValue, "Should be able to read the display value")
        if let value = displayValue {
            let isExpectedValue = value == "5" || value == "5." || value.hasPrefix("5")
            XCTAssertTrue(isExpectedValue, "Display should show '5', got '\(value)'")
        }
        
        // Clean up
        try await calculator.terminate()
        print("==== Basic smoke test complete ====")
    }
    
    override func tearDown() async throws {
        // Clean up any remaining calculator instances
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        calculator = nil
        toolChain = nil
    }
}