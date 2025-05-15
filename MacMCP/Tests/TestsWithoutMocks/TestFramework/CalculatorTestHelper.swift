// ABOUTME: This file provides a helper class for testing Calculator interactions.
// ABOUTME: It encapsulates common Calculator test operations and state management.

import Foundation
import XCTest
@testable import MacMCP
import MCP
import AppKit

/// Helper class for Calculator testing, providing shared resources and convenience methods
@MainActor
public final class CalculatorTestHelper {
    // MARK: - Properties
    
    /// The Calculator app model
    public let app: CalculatorModel
    
    /// The ToolChain for interacting with MCP tools
    public let toolChain: ToolChain
    
    // Singleton instance for shared usage
    private static var _sharedHelper: CalculatorTestHelper?
    
    // MARK: - Initialization
    
    /// Initialize with a new tool chain
    public init() {
        // Create a tool chain
        self.toolChain = ToolChain(logLabel: "mcp.test.calculator")
        
        // Create a Calculator model
        self.app = CalculatorModel(toolChain: toolChain)
    }
    
    /// Get or create a shared helper instance to avoid multiple app launches
    /// - Returns: A shared calculator helper instance
    public static func sharedHelper() -> CalculatorTestHelper {
        if let helper = _sharedHelper {
            return helper
        }
        
        // Create a new instance
        let helper = CalculatorTestHelper()
        _sharedHelper = helper
        return helper
    }
    
    // MARK: - Calculator Operations
    
    /// Ensure the Calculator app is running
    /// - Returns: True if the app is running
    public func ensureAppIsRunning() async throws -> Bool {
        if try await app.isRunning() {
            return true
        }
        
        // Launch the app
        return try await app.launch()
    }
    
    /// Reset the Calculator app state (clear the display)
    public func resetAppState() async {
        // First try to clear the calculator
        do {
            _ = try await app.clear()
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            // If clear fails, try to terminate and relaunch
            do {
                _ = try await app.terminate()
                try await Task.sleep(for: .milliseconds(1000))
                _ = try await app.launch()
                try await Task.sleep(for: .milliseconds(1000))
            } catch {
                // Log error but continue - we'll do our best with the current state
                print("Warning: Could not reset calculator state: \(error)")
            }
        }
    }
    
    /// Assert that the Calculator display shows a specific value
    /// - Parameters:
    ///   - expectedValue: The expected value
    ///   - message: Custom assertion message
    public func assertDisplayValue(_ expectedValue: String, message: String = "") async throws {
        // Get the actual display value
        let actualValue = try await app.getDisplayValue()
        
        // Use the custom message if provided, otherwise create a default message
        let assertionMessage = message.isEmpty
            ? "Calculator display should show '\(expectedValue)' but found '\(actualValue ?? "nil")'"
            : message
        
        // Assert the value matches
        XCTAssertEqual(actualValue, expectedValue, assertionMessage)
    }
    
    /// Press a button on the Calculator
    /// - Parameter buttonLabel: Label of the button to press
    /// - Returns: True if the button was successfully pressed
    public func pressButton(_ buttonLabel: String) async throws -> Bool {
        return try await app.pressButton(buttonLabel)
    }
    
    /// Enter a sequence of button presses
    /// - Parameter sequence: The sequence of buttons to press (e.g., "123+456=")
    /// - Returns: True if all buttons were successfully pressed
    public func enterSequence(_ sequence: String) async throws -> Bool {
        return try await app.enterSequence(sequence)
    }
    
    /// Type text using the keyboard
    /// - Parameter text: The text to type
    /// - Returns: True if the text was successfully typed
    public func typeText(_ text: String) async throws -> Bool {
        return try await app.typeText(text)
    }
    
    /// Take a screenshot of the calculator
    /// - Returns: Path to the screenshot file
    public func takeScreenshot() async throws -> String? {
        // Use the screenshot tool to take a screenshot
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string(app.bundleId)
        ]
        
        let result = try await toolChain.screenshotTool.handler(params)
        
        // Extract the screenshot path from the result
        if let content = result.first, case .text(let text) = content {
            if let path = text.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return path
            }
        }
        
        return nil
    }
    
    /// Perform a simple calculation and verify the result
    /// - Parameters:
    ///   - input: The calculation to perform (e.g., "2+2=")
    ///   - expectedResult: The expected result
    /// - Returns: True if the calculation was successful and matches the expected result
    public func performCalculation(input: String, expectedResult: String) async throws -> Bool {
        // Clear the calculator
        await resetAppState()
        
        // Enter the calculation
        _ = try await enterSequence(input)
        
        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))
        
        // Get the actual result
        let actualResult = try await app.getDisplayValue()
        
        // Return true if the result matches expected
        return actualResult == expectedResult
    }
}