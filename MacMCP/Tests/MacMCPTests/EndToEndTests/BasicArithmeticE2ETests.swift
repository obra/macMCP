// ABOUTME: This file contains end-to-end tests for basic arithmetic operations using the macOS Calculator.
// ABOUTME: It validates that MacMCP can correctly interact with real macOS applications.

import XCTest
import Testing
import Foundation
@testable import MacMCP

@Suite("Calculator Arithmetic E2E Tests")
struct BasicArithmeticE2ETests {
    // The Calculator app instance used for testing
    // We make it static to ensure it remains alive between test cases
    static var calculator: CalculatorApp?
    
    // Setup - runs before all tests in the suite
    @TestSuiteSetup
    static func setupCalculator() async throws {
        // Create a Calculator app instance
        calculator = CalculatorApp()
        
        // Launch the Calculator app
        _ = try await calculator?.launch()
        
        // Make sure the Calculator app is running
        guard calculator?.isRunning() == true else {
            XCTFail("Failed to launch Calculator app")
            return
        }
        
        // Brief pause to ensure UI is fully loaded
        try await Task.sleep(for: .milliseconds(500))
    }
    
    // Teardown - runs after all tests in the suite
    @TestSuiteTeardown
    static func closeCalculator() async throws {
        // Terminate the Calculator app
        _ = try await calculator?.terminate()
        calculator = nil
    }
    
    // MARK: - Test Cases
    
    @Test("Addition operation")
    func testAddition() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Perform 2 + 2 = 4 calculation
        let result = try await Self.calculator?.calculate(
            num1: "2",
            operation: "+",
            num2: "2"
        )
        
        // Verify result
        XCTAssertEqual(result, "4")
    }
    
    @Test("Subtraction operation")
    func testSubtraction() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Perform 5 - 3 = 2 calculation
        let result = try await Self.calculator?.calculate(
            num1: "5",
            operation: "-",
            num2: "3"
        )
        
        // Verify result
        XCTAssertEqual(result, "2")
    }
    
    @Test("Multiplication operation")
    func testMultiplication() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Perform 4 × 5 = 20 calculation
        let result = try await Self.calculator?.calculate(
            num1: "4",
            operation: "×",
            num2: "5"
        )
        
        // Verify result
        XCTAssertEqual(result, "20")
    }
    
    @Test("Division operation")
    func testDivision() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Perform 10 ÷ 2 = 5 calculation
        let result = try await Self.calculator?.calculate(
            num1: "10",
            operation: "÷",
            num2: "2"
        )
        
        // Verify result
        XCTAssertEqual(result, "5")
    }
    
    @Test("Complex sequence of operations")
    func testComplexSequence() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Clear the calculator
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.clear)
        
        // Enter a complex sequence: 2 + 3 × 4 = 14 (with order of operations)
        let sequence = "2+3×4="
        _ = try await Self.calculator?.enterSequence(sequence)
        
        // Get the result
        let result = try await Self.calculator?.getDisplayValue()
        
        // Verify result (should be 14 due to order of operations)
        XCTAssertEqual(result, "14")
    }
    
    @Test("decimal point operation")
    func testDecimalOperation() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Clear the calculator
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.clear)
        
        // Enter the sequence: 1.5 + 2.5 = 4
        _ = try await Self.calculator?.enterSequence("1.5+2.5=")
        
        // Get the result
        let result = try await Self.calculator?.getDisplayValue()
        
        // Verify result
        XCTAssertEqual(result, "4")
    }
    
    @Test("negative numbers operation")
    func testNegativeNumbers() async throws {
        try XCTSkipIf(Self.calculator == nil, "Calculator app not available")
        
        // Clear the calculator
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.clear)
        
        // Enter 5, then make it negative with the +/- button
        _ = try await Self.calculator?.pressButton(identifier: "5")
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.Operations.sign)
        
        // Add 3
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.Operations.plus)
        _ = try await Self.calculator?.pressButton(identifier: "3")
        _ = try await Self.calculator?.pressButton(identifier: CalculatorElements.Operations.equals)
        
        // Get the result
        let result = try await Self.calculator?.getDisplayValue()
        
        // Verify result: -5 + 3 = -2
        XCTAssertEqual(result, "-2")
    }
}