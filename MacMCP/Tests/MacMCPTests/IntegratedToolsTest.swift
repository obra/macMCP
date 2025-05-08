// ABOUTME: This file demonstrates using multiple MCP tools together with the testing framework.
// ABOUTME: It shows comprehensive testing of UI interactions, screenshots, and state verification.

import XCTest
import Logging
import MCP
@testable import MacMCP

final class IntegratedToolsTest: XCTestCase {
    // Test harness for creating tools and services
    private var testHarness: ToolTestHarness!
    
    // Active calculator driver to clean up on teardown
    private var calculatorDriver: CalculatorDriver?
    
    // Tools for testing
    private var uiStateTool: UIStateTool!
    private var screenshotTool: ScreenshotTool!
    private var uiInteractionTool: UIInteractionTool!
    private var openAppTool: OpenApplicationTool!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test harness
        testHarness = ToolTestHarness()
        
        // Create tools
        uiStateTool = testHarness.createUIStateTool()
        screenshotTool = testHarness.createScreenshotTool()
        uiInteractionTool = testHarness.createUIInteractionTool()
        openAppTool = testHarness.createOpenApplicationTool()
    }
    
    override func tearDown() async throws {
        // Clean up the calculator if it was launched
        if let calculatorDriver = calculatorDriver {
            _ = try? await calculatorDriver.terminate()
            self.calculatorDriver = nil
        }
        
        testHarness = nil
        uiStateTool = nil
        screenshotTool = nil
        uiInteractionTool = nil
        openAppTool = nil
        
        try await super.tearDown()
    }
    
    /// Skip tests that require interactive UI in CI environment
    private func skipIfCI() throws {
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("Skipping interactive UI test in CI environment")
        }
    }
    
    /// Test calculator addition using the testing framework
    func testCalculatorAddition() async throws {
        try skipIfCI()
        
        print("===== STARTING TEST: testCalculatorAddition =====")
        
        // Create calculator driver
        let calculator = testHarness.createCalculatorDriver()
        calculatorDriver = calculator
        
        // Launch calculator app
        let launched = try await calculator.launch()
        XCTAssertTrue(launched, "Calculator should launch successfully")
        
        // Wait for app to stabilize
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get initial UI state
        let initialUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: calculator.bundleIdentifier,
            maxDepth: 5
        )
        
        // Use UIStateVerifier to verify the calculator UI is available
        UIStateVerifier.verifyElementExists(
            in: initialUIState, 
            matching: ElementCriteria(role: "AXWindow", title: "Calculator")
        )
        
        // Verify the display element exists
        UIStateVerifier.verifyElementExists(
            in: initialUIState,
            matching: ElementCriteria(role: "AXStaticText")
        )
        
        // Verify calculator buttons exist
        let hasButtons = UIStateVerifier.verifyElementExists(
            in: initialUIState,
            matching: ElementCriteria(role: "AXButton")
        )
        XCTAssertTrue(hasButtons, "Calculator should have buttons")
        
        // Get the display value before interaction
        let displayBefore = try await calculator.getDisplayValue()
        print("Calculator display before: \(displayBefore ?? "nil")")
        
        // Take a screenshot before interaction
        let screenshotBefore = try await ToolInvoker.takeWindowScreenshot(
            tool: screenshotTool,
            bundleId: calculator.bundleIdentifier
        )
        
        // Verify screenshot is valid
        ScreenshotVerifier.verifyScreenshotIsValid(screenshotBefore)
        
        // Calculate 5 + 3 using the calculator driver
        let result = try await calculator.calculate(num1: "5", operation: "+", num2: "3")
        
        // Get UI state after interaction
        let afterUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: calculator.bundleIdentifier,
            maxDepth: 5
        )
        
        // Use InteractionVerifier to validate state changes
        InteractionVerifier.verifyInteraction(
            before: initialUIState,
            after: afterUIState,
            verification: .elementExists(ElementCriteria(role: "AXStaticText", value: "8"))
        )
        
        // Take a screenshot after interaction
        let screenshotAfter = try await ToolInvoker.takeWindowScreenshot(
            tool: screenshotTool,
            bundleId: calculator.bundleIdentifier
        )
        
        // Verify screenshot is valid
        ScreenshotVerifier.verifyScreenshotIsValid(screenshotAfter)
        
        // Verify result
        XCTAssertEqual(result, "8", "5 + 3 should equal 8")
        
        print("===== TEST COMPLETED SUCCESSFULLY =====")
    }
    
    /// Test typing in TextEdit using the testing framework
    func testTextEditTyping() async throws {
        try skipIfCI()
        
        print("===== STARTING TEST: testTextEditTyping =====")
        
        // Create TextEdit driver
        let textEdit = testHarness.createTextEditDriver()
        
        // Launch TextEdit
        let launched = try await textEdit.launch()
        XCTAssertTrue(launched, "TextEdit should launch successfully")
        
        // Wait for app to stabilize
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get initial UI state
        let initialUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: textEdit.bundleIdentifier,
            maxDepth: 5
        )
        
        // Verify TextEdit UI is available
        UIStateVerifier.verifyElementExists(
            in: initialUIState,
            matching: ElementCriteria(role: "AXWindow")
        )
        
        // Verify text area exists
        let textArea = UIStateVerifier.getElement(
            from: initialUIState,
            matching: ElementCriteria(role: "AXTextArea")
        )
        XCTAssertNotNil(textArea, "TextEdit should have a text area")
        
        // Get text area element ID
        let textAreaId = textArea?.identifier ?? ""
        XCTAssertFalse(textAreaId.isEmpty, "Text area should have an identifier")
        
        // Type text using UIInteractionTool
        let testText = "Hello from MacMCP testing framework!"
        let typeResult = try await ToolInvoker.typeText(
            tool: uiInteractionTool,
            elementId: textAreaId,
            text: testText
        )
        XCTAssertFalse(typeResult.isEmpty, "Type operation should return result")
        
        // Get UI state after typing
        let afterUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: textEdit.bundleIdentifier,
            maxDepth: 5
        )
        
        // Verify text was entered
        InteractionVerifier.verifyInteraction(
            before: initialUIState,
            after: afterUIState,
            verification: .elementHasValue(
                ElementCriteria(role: "AXTextArea"),
                testText
            )
        )
        
        // Take a screenshot after typing
        let screenshot = try await ToolInvoker.takeWindowScreenshot(
            tool: screenshotTool,
            bundleId: textEdit.bundleIdentifier
        )
        
        // Verify screenshot is valid
        ScreenshotVerifier.verifyScreenshotIsValid(screenshot)
        
        // Clean up - terminate TextEdit without saving
        _ = try await textEdit.terminate()
        
        print("===== TEST COMPLETED SUCCESSFULLY =====")
    }
    
    /// Test using OpenApplicationTool directly
    func testOpenApplicationTool() async throws {
        try skipIfCI()
        
        print("===== STARTING TEST: testOpenApplicationTool =====")
        
        // Open calculator using OpenApplicationTool
        let result = try await ToolInvoker.openApplicationByName(
            tool: openAppTool,
            appName: "Calculator"
        )
        
        // Verify result
        XCTAssertFalse(result.isEmpty, "Result should not be empty")
        let textContent = result.getTextContent()
        XCTAssertNotNil(textContent, "Result should contain text content")
        
        // Wait for app to launch
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get system UI state
        let uiState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "system",
            maxDepth: 3
        )
        
        // Verify calculator is running
        UIStateVerifier.verifyElementExists(
            in: uiState,
            matching: ElementCriteria(role: "AXApplication", title: "Calculator")
        )
        
        // Create a calculator driver for cleanup
        let calculator = testHarness.createCalculatorDriver()
        calculatorDriver = calculator
        
        print("===== TEST COMPLETED SUCCESSFULLY =====")
    }
    
    /// Test using multiple verifiers together
    func testMultipleVerifiers() async throws {
        try skipIfCI()
        
        print("===== STARTING TEST: testMultipleVerifiers =====")
        
        // Create calculator driver
        let calculator = testHarness.createCalculatorDriver()
        calculatorDriver = calculator
        
        // Launch calculator app
        let launched = try await calculator.launch()
        XCTAssertTrue(launched, "Calculator should launch successfully")
        
        // Wait for app to stabilize
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get initial UI state
        let initialUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: calculator.bundleIdentifier,
            maxDepth: 5
        )
        
        // Perform a calculation: 7 * 8
        let result = try await calculator.calculate(num1: "7", operation: "×", num2: "8")
        
        // Get UI state after calculation
        let afterUIState = try await ToolInvoker.getUIState(
            tool: uiStateTool,
            scope: "application",
            bundleId: calculator.bundleIdentifier,
            maxDepth: 5
        )
        
        // Use multiple verifiers to validate the result
        let verificationResults = InteractionVerifier.verifyAll(
            before: initialUIState,
            after: afterUIState,
            verifications: [
                .elementExists(ElementCriteria(role: "AXStaticText")),
                .elementHasValue(ElementCriteria(role: "AXStaticText"), "56"),
                .custom(
                    { state in 
                        // Check result is 56
                        let displayElements = state.findElements(matching: ElementCriteria(role: "AXStaticText"))
                        return displayElements.contains { $0.value == "56" }
                    },
                    "Display shows 56"
                )
            ]
        )
        
        // Verify all checks passed
        XCTAssertTrue(verificationResults.allSatisfy { $0.success }, "All verifications should pass")
        
        // Verify the result using direct assertion
        XCTAssertEqual(result, "56", "7 * 8 should equal 56")
        
        print("===== TEST COMPLETED SUCCESSFULLY =====")
    }
}