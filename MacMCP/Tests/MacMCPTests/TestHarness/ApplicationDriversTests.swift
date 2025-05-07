// ABOUTME: This file contains tests for the application drivers in the testing framework.
// ABOUTME: It demonstrates how to use Calculator, TextEdit, and Safari drivers for testing.

import XCTest
import Foundation
import Logging
@testable import MacMCP

final class ApplicationDriversTests: XCTestCase {
    private var toolTestHarness: ToolTestHarness!
    private var calculatorDriver: CalculatorDriver!
    private var textEditDriver: TextEditDriver!
    private var safariDriver: SafariDriver!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a test logger for capturing logs
        let (logger, handler) = Logger.testLogger(label: "com.mac.mcp.test.drivers")
        
        // Create the test harness
        toolTestHarness = ToolTestHarness(logger: logger, testHandler: handler)
        
        // Create drivers
        calculatorDriver = CalculatorDriver(
            applicationService: toolTestHarness.applicationService,
            accessibilityService: toolTestHarness.accessibilityService,
            interactionService: toolTestHarness.interactionService
        )
        
        textEditDriver = TextEditDriver(
            applicationService: toolTestHarness.applicationService,
            accessibilityService: toolTestHarness.accessibilityService,
            interactionService: toolTestHarness.interactionService
        )
        
        safariDriver = SafariDriver(
            applicationService: toolTestHarness.applicationService,
            accessibilityService: toolTestHarness.accessibilityService,
            interactionService: toolTestHarness.interactionService
        )
    }
    
    override func tearDown() async throws {
        // Terminate applications
        if calculatorDriver != nil {
            _ = try await calculatorDriver.terminate()
        }
        
        if textEditDriver != nil {
            _ = try await textEditDriver.terminate()
        }
        
        if safariDriver != nil {
            _ = try await safariDriver.terminate()
        }
        
        // Clean up
        calculatorDriver = nil
        textEditDriver = nil
        safariDriver = nil
        toolTestHarness = nil
        
        try await super.tearDown()
    }
    
    func testCalculatorDriver() async throws {
        // Launch Calculator
        let launched = try await calculatorDriver.launch()
        XCTAssertTrue(launched, "Calculator should launch successfully")
        
        // Perform a calculation
        let result = try await calculatorDriver.calculate(num1: "5", operation: "+", num2: "7")
        XCTAssertEqual(result, "12", "5 + 7 should equal 12")
        
        // Test clear functionality
        try await calculatorDriver.pressButton(CalculatorDriver.Button.allClear)
        let displayValue = try await calculatorDriver.getDisplayValue()
        XCTAssertEqual(displayValue, "0", "Display should be 0 after clear")
    }
    
    func testTextEditDriver() async throws {
        // Skip this test if running in a CI environment or without user interaction
        let runInteractiveTests = ProcessInfo.processInfo.environment["RUN_INTERACTIVE_TESTS"] == "true"
        guard runInteractiveTests else {
            throw XCTSkip("Skipping interactive test that requires user environment")
        }
        
        // Launch TextEdit
        let launched = try await textEditDriver.launch()
        XCTAssertTrue(launched, "TextEdit should launch successfully")
        
        // Create a new document
        let newDocCreated = try await textEditDriver.newDocument()
        XCTAssertTrue(newDocCreated, "New document should be created")
        
        // Type some text
        let typingSuccessful = try await textEditDriver.typeText("Hello, world! This is a test document.")
        XCTAssertTrue(typingSuccessful, "Typing should be successful")
        
        // Get the text content and verify
        let content = try await textEditDriver.getTextContent()
        XCTAssertEqual(content, "Hello, world! This is a test document.", "Text content should match")
        
        // Clear the document
        let clearSuccessful = try await textEditDriver.clearDocument()
        XCTAssertTrue(clearSuccessful, "Document should be cleared")
        
        // Verify document is cleared
        let clearedContent = try await textEditDriver.getTextContent()
        XCTAssertTrue(clearedContent?.isEmpty ?? true, "Document should be empty after clearing")
    }
    
    func testSafariDriver() async throws {
        // Skip this test if running in a CI environment or without internet connection
        let runNetworkTests = ProcessInfo.processInfo.environment["RUN_NETWORK_TESTS"] == "true"
        guard runNetworkTests else {
            throw XCTSkip("Skipping network test that requires internet connection")
        }
        
        // Launch Safari
        let launched = try await safariDriver.launch()
        XCTAssertTrue(launched, "Safari should launch successfully")
        
        // Navigate to a website
        let navigationSuccessful = try await safariDriver.navigateTo(url: "https://www.apple.com")
        XCTAssertTrue(navigationSuccessful, "Navigation should be successful")
        
        // Wait for page to load
        let pageLoaded = try await safariDriver.waitForPageLoad(timeout: 10)
        XCTAssertTrue(pageLoaded, "Page should load within timeout")
        
        // Verify URL contains apple.com
        let currentURL = try await safariDriver.getCurrentURL()
        XCTAssertNotNil(currentURL, "Current URL should be available")
        XCTAssertTrue(currentURL?.contains("apple.com") ?? false, "URL should contain apple.com")
        
        // Get page title
        let pageTitle = try await safariDriver.getPageTitle()
        XCTAssertNotNil(pageTitle, "Page title should be available")
        
        // Test navigation
        try await safariDriver.navigateTo(url: "https://www.apple.com/mac/")
        _ = try await safariDriver.waitForPageLoad(timeout: 10)
        
        // Navigate back
        let backSuccessful = try await safariDriver.goBack()
        XCTAssertTrue(backSuccessful, "Back navigation should be successful")
        _ = try await safariDriver.waitForPageLoad(timeout: 5)
        
        // Navigate forward
        let forwardSuccessful = try await safariDriver.goForward()
        XCTAssertTrue(forwardSuccessful, "Forward navigation should be successful")
        _ = try await safariDriver.waitForPageLoad(timeout: 5)
    }
    
    func testMultipleDriversSequentially() async throws {
        // Skip if not running interactive tests
        let runInteractiveTests = ProcessInfo.processInfo.environment["RUN_INTERACTIVE_TESTS"] == "true"
        guard runInteractiveTests else {
            throw XCTSkip("Skipping interactive test that requires user environment")
        }
        
        // 1. Use Calculator to perform calculation
        try await calculatorDriver.launch()
        let result = try await calculatorDriver.calculate(num1: "123", operation: "×", num2: "456")
        XCTAssertEqual(result, "56088", "123 × 456 should equal 56088")
        
        // Terminate Calculator before moving to next app
        _ = try await calculatorDriver.terminate()
        
        // 2. Use TextEdit to create a document
        try await textEditDriver.launch()
        _ = try await textEditDriver.newDocument()
        _ = try await textEditDriver.typeText("Calculation result: 123 × 456 = 56088")
        
        let content = try await textEditDriver.getTextContent()
        XCTAssertTrue(content?.contains("56088") ?? false, "TextEdit content should contain calculation result")
        
        // Terminate TextEdit
        _ = try await textEditDriver.terminate()
    }
}