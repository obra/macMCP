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
    
    override func setUp() async throws {
        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        
        // Make sure no calculator instances are running at the start
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    /// Helper to ensure calculator is in a clean state before tests
    private func resetCalculator() async throws {
        // Terminate any existing calculator instances
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        
        // Force terminate all instances to ensure a clean slate
        runningApps.forEach { $0.forceTerminate() }
        
        // Give the system time to fully close the app
        try await Task.sleep(for: .milliseconds(1000))
        
        // Verify we're starting clean
        let finalCheck = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(finalCheck.isEmpty, "No Calculator instances should be running before launch")
        
        // Launch calculator
        let launchSuccess = try await calculator.launch()
        XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
        
        // Wait for the app to fully initialize
        try await Task.sleep(for: .milliseconds(2000))
        
        // Verify the app is running
        let isRunning = try await calculator.isRunning()
        XCTAssertTrue(isRunning, "Calculator should be running after launch")
        
        // Verify that we have a main window
        let window = try await calculator.getMainWindow()
        XCTAssertNotNil(window, "Calculator should have a main window after launch")
        
        // Clear the calculator to start fresh
        let clearSuccess = try await calculator.clear()
        XCTAssertTrue(clearSuccess, "Calculator should clear successfully")
        
        // Brief pause to ensure the clear operation completed
        try await Task.sleep(for: .milliseconds(500))
    }
    
    /// Test simple direct UI inspection of Calculator
    func testUIInspection() async throws {
        // Force terminate any existing Calculator instances
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { $0.forceTerminate() }
        try await Task.sleep(for: .milliseconds(1000))

        // Launch calculator directly
        let workspace = NSWorkspace.shared
        let calculatorURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.calculator")
        XCTAssertNotNil(calculatorURL, "Calculator application should be available")

        if let url = calculatorURL {
            _ = try workspace.launchApplication(at: url, options: .default, configuration: [:])

            try await Task.sleep(for: .milliseconds(3000))

            // Verify that Calculator is running
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
            XCTAssertFalse(runningApps.isEmpty, "Calculator should be running")

            // Get application element
            _ = try await toolChain.accessibilityService.getApplicationUIElement(
                bundleIdentifier: "com.apple.calculator",
                recursive: true,
                maxDepth: 3
            )

            // Look for window elements
            let windows = try await toolChain.findElements(
                matching: UIElementCriteria(role: "AXWindow"),
                scope: "application",
                bundleId: "com.apple.calculator",
                maxDepth: 5
            )

            // Simple assertion - should have found at least one window
            XCTAssertFalse(windows.isEmpty, "Should find at least one window")

            // Look for buttons
            let buttons = try await toolChain.findElements(
                matching: UIElementCriteria(role: "AXButton"),
                scope: "application",
                bundleId: "com.apple.calculator",
                maxDepth: 10
            )

            // Simple assertion - should have found buttons
            XCTAssertFalse(buttons.isEmpty, "Should find at least one button")

            // Look for static text elements that might contain the display value
            _ = try await toolChain.findElements(
                matching: UIElementCriteria(role: "AXStaticText"),
                scope: "application",
                bundleId: "com.apple.calculator",
                maxDepth: 10
            )

            _ = try await toolChain.findElements(
                matching: UIElementCriteria(role: "AXScrollArea"),
                scope: "application",
                bundleId: "com.apple.calculator",
                maxDepth: 10
            )

            // Test a simple interaction with the calculator
            // Try to press a digit with a keyboard shortcut
            _ = try await toolChain.pressKey(keyCode: 18) // 1 key

            // Wait for UI to update
            try await Task.sleep(for: .milliseconds(1000))

            // Check text elements again to see if display updated
            _ = try await toolChain.findElements(
                matching: UIElementCriteria(role: "AXStaticText"),
                scope: "application",
                bundleId: "com.apple.calculator",
                maxDepth: 10
            )

            // Clean up
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { $0.forceTerminate() }
        }
    }
    
    
    /// Test sequential UI interactions like entering a series of button presses
    func testSequentialUIInteractions() async throws {
        // Set up calculator
        try await resetCalculator()
        
        // Enter a sequence of button presses
        let sequenceSuccess = try await calculator.enterSequence("123")
        XCTAssertTrue(sequenceSuccess, "Should be able to enter a sequence of buttons")
        
        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))
        
        // Verify the result shows the correct sequence
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertNotNil(displayValue, "Should be able to read the display value")
        
        if let displayValue = displayValue {
            let isExpectedValue = displayValue == "123" || displayValue == "123." || displayValue.hasPrefix("123")
            XCTAssertTrue(
                isExpectedValue,
                "Display should show the entered sequence '123' (got '\(displayValue)')"
            )
        }
        
        // Clean up
        let terminateSuccess = try await calculator.terminate()
        XCTAssertTrue(terminateSuccess, "Calculator should terminate successfully")
    }
}
