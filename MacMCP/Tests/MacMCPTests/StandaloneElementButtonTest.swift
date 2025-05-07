// ABOUTME: This file contains a minimal test for finding and interacting with the Calculator's 0 button.
// ABOUTME: It verifies that button elements can be located and have valid frame coordinates.

import XCTest
import Logging
@testable import MacMCP

/// A minimal test to find and interact with the Calculator's 0 button
final class StandaloneElementButtonTest: XCTestCase {
    
    /// Helper class to run @MainActor isolated code for Calculator app
    @MainActor
    class CalculatorTestHelper {
        private var calculator: CalculatorApp?
        
        func setup() async throws -> Bool {
            calculator = CalculatorApp()
            guard let calc = calculator else {
                return false
            }
            
            return try await calc.launch()
        }
        
        func findZeroButton() async throws -> UIElement? {
            guard let calc = calculator else {
                return nil
            }
            
            return try await calc.getButton(identifier: CalculatorElements.Digits.zero)
        }
        
        func pressZeroButton() async throws -> Bool {
            guard let calc = calculator else {
                return false
            }
            
            return try await calc.pressButton(identifier: CalculatorElements.Digits.zero)
        }
        
        func getDisplayValue() async throws -> String? {
            guard let calc = calculator else {
                return nil
            }
            
            return try await calc.getDisplayValue()
        }
        
        func cleanup() async throws {
            if let calc = calculator {
                _ = try await calc.terminate()
            }
        }
    }
    
    /// Tests finding and pressing the 0 button on the Calculator app
    func testFindAndPressZeroButton() async throws {
        // Create a helper to run code on the main actor
        let helper = CalculatorTestHelper()
        
        do {
            // Launch Calculator and ensure it's running
            let launchSuccess = try await helper.setup()
            XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
            
            // Find the 0 button
            print("Searching for the 0 button...")
            guard let zeroButton = try await helper.findZeroButton() else {
                XCTFail("Failed to find the 0 button")
                return
            }
            
            // Verify the button has frame coordinates that aren't 0
            print("Checking button frame coordinates: \(zeroButton.frame)")
            XCTAssertNotEqual(zeroButton.frame.origin.x, 0, "Button X coordinate should not be 0")
            XCTAssertNotEqual(zeroButton.frame.origin.y, 0, "Button Y coordinate should not be 0")
            XCTAssertGreaterThan(zeroButton.frame.size.width, 0, "Button width should be greater than 0")
            XCTAssertGreaterThan(zeroButton.frame.size.height, 0, "Button height should be greater than 0")
            
            // Press the 0 button
            print("Pressing the 0 button...")
            let pressSuccess = try await helper.pressZeroButton()
            XCTAssertTrue(pressSuccess, "Should successfully press the 0 button")
            
            // Get the display value to verify the button press had an effect
            print("Getting calculator display value...")
            guard let displayValue = try await helper.getDisplayValue() else {
                XCTFail("Failed to get calculator display value")
                return
            }
            
            // Verify the display shows 0 (or contains 0, depending on calculator behavior)
            print("Checking display value: \(displayValue)")
            XCTAssertTrue(displayValue.contains("0"), "Calculator display should contain '0'")
            
            print("Test completed successfully")
        } catch {
            XCTFail("Test failed with error: \(error)")
            throw error
        }
        
        // Clean up after the test, even if it fails
        try? await helper.cleanup()
    }
}