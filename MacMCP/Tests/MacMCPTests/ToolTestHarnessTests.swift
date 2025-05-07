// ABOUTME: This file contains example tests using the new ToolTestHarness framework.
// ABOUTME: It demonstrates how to use the various components together for effective testing.

import XCTest
import Logging
import MCP
@testable import MacMCP

final class ToolTestHarnessTests: XCTestCase {
    // Properties to keep track of running apps
    private var activeCalculatorDriver: CalculatorDriver?
    
    override func tearDown() async throws {
        // Clean up any active drivers
        if let calculator = activeCalculatorDriver {
            _ = try? await calculator.terminate()
            activeCalculatorDriver = nil
        }
        
        try await super.tearDown()
    }
    
    func testUIStateTool() async throws {
        print("========== STARTING TEST: testUIStateTool ==========")
        
        // Create test harness
        let testHarness = ToolTestHarness()
        
        // Create UI state tool
        let uiStateTool = testHarness.createUIStateTool()
        
        // Get system UI state with limited depth
        print("Getting UI state...")
        let result = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "system",
            maxDepth: 3
        )
        print("Got UI state")
        
        // Verify we got elements
        XCTAssertFalse(result.elements.isEmpty, "Should return elements")
        
        // Check if we can find system element
        let systemElement = result.findElement(matching: ElementCriteria(role: "AXSystemWide"))
        XCTAssertNotNil(systemElement, "Should find system element")
        
        print("Found system element with role: \(systemElement?.role ?? "nil")")
        print("System element has \(systemElement?.children.count ?? 0) children")
        
        // Use the verifier 
        let verifierResult = UIStateVerifier.verifyElementExists(
            in: result,
            matching: ElementCriteria(role: "AXSystemWide")
        )
        XCTAssertTrue(verifierResult, "Verifier should find system element")
        
        print("========== TEST COMPLETED SUCCESSFULLY ==========")
    }
    
    func testCalculatorDriver() async throws {
        print("========== STARTING TEST: testCalculatorDriver ==========")
        
        // Skip if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping calculator test in CI environment")
            return
        }
        
        // Create test harness
        let testHarness = ToolTestHarness()
        
        // Create calculator driver
        let calculator = testHarness.createCalculatorDriver()
        activeCalculatorDriver = calculator
        
        // Launch calculator
        let launched = try await calculator.launch()
        XCTAssertTrue(launched, "Calculator should launch")
        
        // Clean up will happen in tearDown
        
        // Wait for app to be ready
        try await Task.sleep(for: .milliseconds(1000))
        
        // Verify calculator window exists
        let window = try await calculator.getMainWindow()
        XCTAssertNotNil(window, "Calculator window should exist")
        
        // Test calculation
        let result = try await calculator.calculate(num1: "5", operation: "+", num2: "3")
        XCTAssertEqual(result, "8", "5 + 3 should equal 8")
        
        print("========== TEST COMPLETED SUCCESSFULLY ==========")
    }
    
    func testCombinedToolsAndDrivers() async throws {
        print("========== STARTING TEST: testCombinedToolsAndDrivers ==========")
        
        // Skip if running in CI environment
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            print("Skipping calculator test in CI environment")
            return
        }
        
        // Create test harness
        let testHarness = ToolTestHarness()
        
        // Create calculator driver
        let calculator = testHarness.createCalculatorDriver()
        activeCalculatorDriver = calculator
        
        // Create UI state tool
        let uiStateTool = testHarness.createUIStateTool()
        
        // Launch calculator
        try await calculator.launch()
        
        // Clean up will happen in tearDown
        
        // Wait for app to be ready
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get UI state for calculator application
        let uiState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: calculator.bundleIdentifier,
            maxDepth: 5
        )
        
        // Verify calculator has buttons
        let hasButtons = UIStateVerifier.verifyElementExists(
            in: uiState,
            matching: ElementCriteria(role: "AXButton")
        )
        XCTAssertTrue(hasButtons, "Calculator should have buttons")
        
        // Verify calculator has equals button
        let hasEqualsButton = UIStateVerifier.verifyElementExists(
            in: uiState,
            matching: ElementCriteria(role: "AXButton", title: "=")
        )
        XCTAssertTrue(hasEqualsButton, "Calculator should have equals button")
        
        // Test calculation
        let result = try await calculator.calculate(num1: "7", operation: "×", num2: "6")
        XCTAssertEqual(result, "42", "7 × 6 should equal 42")
        
        print("========== TEST COMPLETED SUCCESSFULLY ==========")
    }
}