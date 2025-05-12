// ABOUTME: This file contains simplified tests for the Calculator app.
// ABOUTME: It verifies the shared application approach works correctly.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

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
        
        // Terminate any existing calculator instances
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        if runningApps.isEmpty {
            // Launch calculator
            let launchSuccess = try await app.launch()
            XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
            calculatorRunning = true
        } else {
            // Reuse existing instance
            calculatorRunning = true
        }
        
        // Wait for app to be ready
        try await Task.sleep(for: .milliseconds(1000))
        
        // Clear the calculator 
        _ = try await app.clear()
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
        
        if let displayValue = displayValue {
            let isExpectedValue = displayValue == "5" || displayValue == "5." || displayValue.hasPrefix("5")
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
        
        if let displayValue = displayValue {
            let isExpectedValue = displayValue == "7" || displayValue == "7." || displayValue.hasPrefix("7")
            XCTAssertTrue(isExpectedValue, "Display should show '7', got '\(displayValue)'")
        }
    }
}