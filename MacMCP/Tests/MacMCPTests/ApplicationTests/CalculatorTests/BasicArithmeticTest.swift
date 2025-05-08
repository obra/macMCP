// ABOUTME: This file implements a basic arithmetic test for the Calculator using the new test framework.
// ABOUTME: It tests the MCP tools' ability to interact with the Calculator using different input methods.

import XCTest
import Foundation
@testable import MacMCP

/// Test case for basic arithmetic operations in Calculator
final class BasicArithmeticTest: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private var calculator: CalculatorModel!
    private var uiVerifier: UIVerifier!
    
    // Constants for verification
    private let displayCriteria = UIElementCriteria(role: "AXStaticText")
    
    override func setUp() async throws {
        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        uiVerifier = UIVerifier(toolChain: toolChain)
        
        // Launch the Calculator app
        print("Launching Calculator app...")
        try await calculator.launch()
        
        // Verify that the Calculator is running and accessible
        let window = try await calculator.getMainWindow()
        XCTAssertNotNil(window, "Calculator window should be available")
        
        // Add teardown block for clean shutdown
        addTeardownBlock { [calculator] in
            print("Terminating Calculator app...")
            try? await calculator?.terminate()
        }
    }
    
    /// Test addition using accessibility-based button pressing
    func testAdditionUsingAccessibility() async throws {
        print("Testing addition using accessibility buttons...")
        
        // Clear the calculator
        try await calculator.clear()
        
        // Enter 2 + 2 = using accessibility
        try await calculator.pressButtonViaAccessibility("2")
        try await calculator.pressButtonViaAccessibility("+")
        try await calculator.pressButtonViaAccessibility("2")
        try await calculator.pressButtonViaAccessibility("=")
        
        // Verify the result
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "4", "2 + 2 should equal 4")
        
        // Verify using the UI verifier
        try await uiVerifier.verifyElementPropertyContains(
            matching: displayCriteria,
            property: "value",
            contains: "4",
            in: "application",
            bundleId: calculator.bundleId
        )
    }
    
    /// Test subtraction using mouse-based button clicking
    func testSubtractionUsingMouse() async throws {
        print("Testing subtraction using mouse clicks...")
        
        // Clear the calculator
        try await calculator.clear()
        
        // Enter 5 - 3 = using mouse clicks
        try await calculator.clickButtonWithMouse("5")
        try await calculator.clickButtonWithMouse("-")
        try await calculator.clickButtonWithMouse("3")
        try await calculator.clickButtonWithMouse("=")
        
        // Verify the result
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "2", "5 - 3 should equal 2")
        
        // Verify using the UI verifier
        try await uiVerifier.verifyElementPropertyContains(
            matching: displayCriteria,
            property: "value",
            contains: "2",
            in: "application",
            bundleId: calculator.bundleId
        )
    }
    
    /// Test multiplication using keyboard input
    func testMultiplicationUsingKeyboard() async throws {
        print("Testing multiplication using keyboard input...")
        
        // Clear the calculator
        try await calculator.clear()
        
        // Enter 4 * 5 = using keyboard
        try await calculator.typeDigit("4")
        try await calculator.typeOperator("*")
        try await calculator.typeDigit("5")
        try await calculator.typeOperator("=")
        
        // Verify the result
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "20", "4 * 5 should equal 20")
        
        // Verify using the UI verifier
        try await uiVerifier.verifyElementPropertyContains(
            matching: displayCriteria,
            property: "value",
            contains: "20",
            in: "application",
            bundleId: calculator.bundleId
        )
    }
    
    /// Test division using a mix of interaction methods
    func testDivisionUsingMixedMethods() async throws {
        print("Testing division using mixed input methods...")
        
        // Clear the calculator
        try await calculator.clear()
        
        // Enter 10 using accessibility
        try await calculator.pressButtonViaAccessibility("1")
        try await calculator.pressButtonViaAccessibility("0")
        
        // Enter ÷ using mouse
        try await calculator.clickButtonWithMouse("÷")
        
        // Enter 2 using keyboard
        try await calculator.typeDigit("2")
        
        // Enter = using accessibility
        try await calculator.pressButtonViaAccessibility("=")
        
        // Verify the result
        let displayValue = try await calculator.getDisplayValue()
        XCTAssertEqual(displayValue, "5", "10 ÷ 2 should equal 5")
        
        // Verify using the UI verifier
        try await uiVerifier.verifyElementPropertyContains(
            matching: displayCriteria,
            property: "value",
            contains: "5",
            in: "application",
            bundleId: calculator.bundleId
        )
    }
    
    /// Test complex expression using UIInteractionTool directly
    func testComplexExpressionUsingToolDirectly() async throws {
        print("Testing complex expression using UIInteractionTool directly...")
        
        // Clear the calculator
        try await calculator.clear()
        
        // Get the window element
        guard let window = try await calculator.getMainWindow() else {
            XCTFail("Could not get Calculator window")
            return
        }
        
        // Find the buttons using UIStateTool directly
        let elements = try await toolChain.accessibilityService.findUIElements(
            role: "AXButton",
            titleContains: nil,
            scope: .application(bundleIdentifier: calculator.bundleId),
            recursive: true
        )
        
        // Find buttons by identifiers (partial match)
        func findButton(containing pattern: String) -> UIElement? {
            return elements.first { element in
                element.identifier.contains(pattern)
            }
        }
        
        // Enter 2 + 3 × 4 = using direct tool calls
        let buttonSequence = ["2", "Add", "3", "Multiply", "4", "Equals"]
        
        for buttonPattern in buttonSequence {
            if let button = findButton(containing: buttonPattern) {
                // Use UIInteractionTool directly
                let params: [String: Value] = [
                    "action": .string("click"),
                    "elementId": .string(button.identifier)
                ]
                
                _ = try await toolChain.uiInteractionTool.handler(params)
                
                // Small delay between button presses
                try await Task.sleep(for: .milliseconds(100))
            } else {
                XCTFail("Button containing '\(buttonPattern)' not found")
            }
        }
        
        // Verify the result using UIStateTool directly
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculator.bundleId),
            "maxDepth": .int(15)
        ]
        
        let result = try await toolChain.uiStateTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let jsonString) = content {
            let jsonData = jsonString.data(using: .utf8)!
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Look for the display element in the UI state
            var displayValue: String? = nil
            
            func findDisplayValue(in elements: [[String: Any]]) -> String? {
                for element in elements {
                    if let role = element["role"] as? String, role == "AXStaticText",
                       let value = element["value"] as? String {
                        return value
                    }
                    
                    // Check children
                    if let children = element["children"] as? [[String: Any]],
                       let value = findDisplayValue(in: children) {
                        return value
                    }
                }
                return nil
            }
            
            displayValue = findDisplayValue(in: jsonArray)
            
            // Verify the result (should be 14 due to order of operations)
            XCTAssertEqual(displayValue, "14", "2 + 3 × 4 should equal 14 with order of operations")
        } else {
            XCTFail("Could not get UI state")
        }
    }
}