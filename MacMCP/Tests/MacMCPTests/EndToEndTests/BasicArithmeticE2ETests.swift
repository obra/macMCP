// ABOUTME: This file contains end-to-end tests for basic arithmetic operations using the macOS Calculator.
// ABOUTME: It validates that MacMCP can correctly interact with real macOS applications.

import XCTest
import Foundation
import MCP
@testable import MacMCP

final class BasicArithmeticE2ETests: XCTestCase {
    // The Calculator app instance used for testing
    // We make it static to ensure it remains alive between test cases
    @MainActor static var calculator: CalculatorApp?
    
    // Setup - runs before all tests in the suite
    override class func setUp() {
        super.setUp()
        
        // Use a semaphore to properly wait for async setup to complete
        let setupSemaphore = DispatchSemaphore(value: 0)
        var setupError: Swift.Error? = nil
        
        print("Starting Calculator app setup...")
        
        // Launch the Calculator app in a task
        Task { @MainActor in
            do {
                print("Creating Calculator app instance")
                // Create the Calculator app
                calculator = CalculatorApp()
                
                print("Launching Calculator app")
                // Launch the Calculator app
                _ = try await calculator?.launch()
                
                // Longer pause to ensure UI is fully loaded
                print("Waiting for UI to fully load")
                try await Task.sleep(for: .milliseconds(2000))
                
                // Test that we can actually get the main window
                if let window = try await calculator?.getMainWindow() {
                    print("Successfully verified main window exists with \(window.children.count) children")
                    
                    // Scan for all buttons to help with debugging
                    print("Scanning for all Calculator buttons:")
                    try await calculator?.scanForButtons()
                } else {
                    print("WARNING: Could not verify main window exists, but continuing")
                }
                
                print("Calculator app setup completed successfully")
            } catch {
                print("Failed to set up Calculator app: \(error)")
                setupError = error
            }
            
            // Signal that setup is complete
            setupSemaphore.signal()
        }
        
        // Wait for async setup to complete with timeout
        let setupResult = setupSemaphore.wait(timeout: .now() + 30)
        
        if setupResult == .timedOut {
            XCTFail("Timed out waiting for Calculator app setup to complete")
        } else if let error = setupError {
            XCTFail("Error during Calculator app setup: \(error)")
        }
    }
    
    // Teardown - runs after all tests in the suite
    override class func tearDown() {
        // Use a semaphore to properly wait for async teardown to complete
        let teardownSemaphore = DispatchSemaphore(value: 0)
        
        print("Starting Calculator app teardown...")
        
        // Terminate the Calculator app
        Task { @MainActor in
            do {
                print("Terminating Calculator app")
                _ = try await calculator?.terminate()
                calculator = nil
                print("Calculator app teardown completed successfully")
            } catch {
                print("Error during teardown: \(error)")
            }
            
            // Signal that teardown is complete
            teardownSemaphore.signal()
        }
        
        // Wait for async teardown to complete with timeout
        let teardownResult = teardownSemaphore.wait(timeout: .now() + 10)
        
        if teardownResult == .timedOut {
            print("WARNING: Timed out waiting for Calculator app teardown to complete")
        }
        
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    // Scan the Calculator UI to find interactive elements
    @MainActor
    func testScanCalculatorUI() async throws {
        print("Starting UI scan test")
        
        guard let calculator = Self.calculator else {
            print("Calculator app not available, skipping test")
            throw XCTSkip("Calculator app not available")
        }
        
        print("---------------------------------------------")
        print("SCANNING CALCULATOR UI FOR ALL ELEMENTS")
        print("---------------------------------------------")
        try await calculator.scanForButtons()
        print("---------------------------------------------")
        print("SCAN COMPLETE")
        print("---------------------------------------------")
        
        // Skip further tests - this test is just for scanning
        XCTAssertTrue(true, "Scanner test completed")
    }
    
    // Addition operation
    @MainActor
    func testAddition() async throws {
        print("Starting testAddition")
        
        guard let calculator = Self.calculator else {
            print("Calculator app not available, skipping test")
            throw XCTSkip("Calculator app not available")
        }
        
        // First try to interact with the calculator to verify it's responsive
        print("Verifying Calculator is responsive")
        do {
            if let window = try await calculator.getMainWindow() {
                print("Calculator main window is available with \(window.children.count) children")
            } else {
                print("WARNING: Could not verify Calculator window exists, but continuing")
            }
        } catch {
            print("Error verifying Calculator window: \(error)")
            // Continue anyway - the calculate method will try multiple times
        }
        
        print("Performing 2 + 2 = 4 calculation")
        do {
            // Perform 2 + 2 = 4 calculation
            let result = try await calculator.calculate(
                num1: "2",
                operation: "+",
                num2: "2"
            )
            
            // Verify result
            print("Calculation result: \(result ?? "nil")")
            XCTAssertEqual(result, "4")
        } catch {
            XCTFail("Error performing calculation: \(error)")
        }
        
        print("Completed testAddition")
    }
    
    // Subtraction operation
    @MainActor
    func testSubtraction() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Perform 5 - 3 = 2 calculation
        let result = try await calculator.calculate(
            num1: "5",
            operation: "-",
            num2: "3"
        )
        
        // Verify result
        XCTAssertEqual(result, "2")
    }
    
    // Multiplication operation
    @MainActor
    func testMultiplication() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Perform 4 × 5 = 20 calculation
        let result = try await calculator.calculate(
            num1: "4",
            operation: "×",
            num2: "5"
        )
        
        // Verify result
        XCTAssertEqual(result, "20")
    }
    
    // Division operation
    @MainActor
    func testDivision() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Perform 10 ÷ 2 = 5 calculation
        let result = try await calculator.calculate(
            num1: "10",
            operation: "÷",
            num2: "2"
        )
        
        // Verify result
        XCTAssertEqual(result, "5")
    }
    
    // Complex sequence of operations
    @MainActor
    func testComplexSequence() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Clear the calculator
        _ = try await calculator.pressButton(identifier: CalculatorElements.clear)
        
        // Enter a complex sequence: 2 + 3 × 4 = 14 (with order of operations)
        let sequence = "2+3×4="
        _ = try await calculator.enterSequence(sequence)
        
        // Get the result
        let result = try await calculator.getDisplayValue()
        
        // Verify result (should be 14 due to order of operations)
        XCTAssertEqual(result, "14")
    }
    
    // Decimal point operation
    @MainActor
    func testDecimalOperation() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Clear the calculator
        _ = try await calculator.pressButton(identifier: CalculatorElements.clear)
        
        // Enter the sequence: 1.5 + 2.5 = 4
        _ = try await calculator.enterSequence("1.5+2.5=")
        
        // Get the result
        let result = try await calculator.getDisplayValue()
        
        // Verify result
        XCTAssertEqual(result, "4")
    }
    
    // Negative numbers operation
    @MainActor
    func testNegativeNumbers() async throws {
        guard let calculator = Self.calculator else {
            throw XCTSkip("Calculator app not available")
        }
        
        // Clear the calculator
        _ = try await calculator.pressButton(identifier: CalculatorElements.clear)
        
        // Enter 5, then make it negative with the +/- button
        _ = try await calculator.pressButton(identifier: "5")
        _ = try await calculator.pressButton(identifier: CalculatorElements.Operations.sign)
        
        // Add 3
        _ = try await calculator.pressButton(identifier: CalculatorElements.Operations.plus)
        _ = try await calculator.pressButton(identifier: "3")
        _ = try await calculator.pressButton(identifier: CalculatorElements.Operations.equals)
        
        // Get the result
        let result = try await calculator.getDisplayValue()
        
        // Verify result: -5 + 3 = -2
        XCTAssertEqual(result, "-2")
    }
}