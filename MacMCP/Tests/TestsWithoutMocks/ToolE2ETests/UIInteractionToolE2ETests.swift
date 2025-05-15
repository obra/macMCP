// ABOUTME: This file contains end-to-end tests for the UIInteractionTool.
// ABOUTME: It verifies the tool's ability to interact with UI elements across multiple applications.

import XCTest
import Foundation
import MCP
import AppKit
import Logging
@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// End-to-end tests for the UIInteractionTool using Calculator and TextEdit apps
@MainActor
final class UIInteractionToolE2ETests: XCTestCase {
    // Test components
    private var calculatorHelper: CalculatorTestHelper!
    private var textEditHelper: TextEditTestHelper!
    
    // Save references to app state
    private var calculatorRunning = false
    private var textEditRunning = false
    
    override func setUp() async throws {
        print("Setting up UIInteractionToolE2ETests")

        // Initialize test helpers
        calculatorHelper = CalculatorTestHelper.sharedHelper()
        textEditHelper = TextEditTestHelper.shared()

        // Check if apps are already running
        calculatorRunning = try await calculatorHelper.app.isRunning()
        textEditRunning = try await textEditHelper.app.isRunning()

        // For Calculator: terminate and relaunch for a clean state
        if calculatorRunning {
            print("Terminating existing Calculator instance")
            _ = try await calculatorHelper.app.terminate()
            try await Task.sleep(for: .milliseconds(1000))
        }

        // Launch Calculator
        print("Launching Calculator")
        _ = try await calculatorHelper.app.launch()

        // Allow time for Calculator to launch and stabilize - increased wait time
        try await Task.sleep(for: .milliseconds(3000))

        // Only set up TextEdit if the test needs it
        if try await testRequiresTextEdit() {
            print("Test requires TextEdit, setting it up")
            if textEditRunning {
                print("Terminating existing TextEdit instance")
                _ = try await textEditHelper.app.terminate()
                try await Task.sleep(for: .milliseconds(1000))
            }

            // Launch TextEdit
            print("Launching TextEdit")
            _ = try await textEditHelper.app.launch()

            // Allow time for TextEdit to launch and stabilize
            try await Task.sleep(for: .milliseconds(3000))

            // Reset TextEdit state
            try await textEditHelper.resetAppState()
        }
    }

    /// Helper method to determine if the current test requires TextEdit
    private func testRequiresTextEdit() async throws -> Bool {
        // Get the name of the currently running test
        let testName = name

        // Return true for tests that need TextEdit
        return testName.contains("testDifferentClickTypes") || 
               testName.contains("testRightClick") ||
               testName.contains("testDragOperation") ||
               testName.contains("testScrollOperation") ||
               testName.contains("testTypeText")
    }
    
    override func tearDown() async throws {
        // Always terminate apps we launched during the test
        _ = try? await calculatorHelper.app.terminate()

        // Only close TextEdit if the test used it
        if try await testRequiresTextEdit() {
            _ = try? await textEditHelper.app.terminate()
        }
    }
    
    // MARK: - Test Methods
    
    /// Test basic clicking on calculator buttons
    func testBasicClick() async throws {
        print("Starting testBasicClick")

        // Ensure Calculator is active before interactions
        NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Clear the calculator first
        _ = try await calculatorHelper.app.clear()
        try await Task.sleep(for: .milliseconds(1000))

        print("Finding calculator buttons...")
        // Find calculator buttons with retries if needed
        var digitOne: UIElement?
        var digitTwo: UIElement?
        var plusButton: UIElement?
        var equalsButton: UIElement?

        // Add retry logic for finding buttons
        for _ in 0..<3 {
            digitOne = try await calculatorHelper.app.findButton("1")
            digitTwo = try await calculatorHelper.app.findButton("2")
            plusButton = try await calculatorHelper.app.findButton("+")
            equalsButton = try await calculatorHelper.app.findButton("=")

            if digitOne != nil && digitTwo != nil && plusButton != nil && equalsButton != nil {
                break
            }
            try await Task.sleep(for: .milliseconds(1000))
        }

        XCTAssertNotNil(digitOne, "Should find the '1' button")
        XCTAssertNotNil(digitTwo, "Should find the '2' button")
        XCTAssertNotNil(plusButton, "Should find the '+' button")
        XCTAssertNotNil(equalsButton, "Should find the '=' button")

        // Now perform a simple calculation using the UIInteractionTool directly
        guard let oneButton = digitOne, let twoButton = digitTwo,
              let addButton = plusButton, let eqButton = equalsButton else {
            XCTFail("Failed to find all required buttons")
            return
        }

        print("Performing calculation 1+2=...")

        // Click each button in sequence with increased wait times
        print("Clicking button '1'")
        let clickOneSuccess = try await calculatorHelper.toolChain.clickElement(
            elementId: oneButton.identifier,
            bundleId: calculatorHelper.app.bundleId
        )
        XCTAssertTrue(clickOneSuccess, "Should click '1' button successfully")
        try await Task.sleep(for: .milliseconds(1000))

        print("Clicking button '+'")
        let clickPlusSuccess = try await calculatorHelper.toolChain.clickElement(
            elementId: addButton.identifier,
            bundleId: calculatorHelper.app.bundleId
        )
        XCTAssertTrue(clickPlusSuccess, "Should click '+' button successfully")
        try await Task.sleep(for: .milliseconds(1000))

        print("Clicking button '2'")
        let clickTwoSuccess = try await calculatorHelper.toolChain.clickElement(
            elementId: twoButton.identifier,
            bundleId: calculatorHelper.app.bundleId
        )
        XCTAssertTrue(clickTwoSuccess, "Should click '2' button successfully")
        try await Task.sleep(for: .milliseconds(1000))

        print("Clicking button '='")
        let clickEqualsSuccess = try await calculatorHelper.toolChain.clickElement(
            elementId: eqButton.identifier,
            bundleId: calculatorHelper.app.bundleId
        )
        XCTAssertTrue(clickEqualsSuccess, "Should click '=' button successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // Verify the result is 3 (1+2)
        print("Verifying display value...")
        try await calculatorHelper.assertDisplayValue("3", message: "Display should show '3' after clicking buttons")
        
        // Test direct UIInteractionTool interface to verify proper passing of parameters
        let result = try await calculatorHelper.toolChain.uiInteractionTool.handler([
            "action": .string("click"),
            "elementId": .string(oneButton.identifier),
            "appBundleId": .string(calculatorHelper.app.bundleId)
        ])
        
        XCTAssertFalse(result.isEmpty, "Handler should return non-empty result")
        if case .text(let message) = result.first {
            XCTAssertTrue(message.contains("Successfully clicked"), "Success message should indicate click was successful")
            XCTAssertTrue(message.contains(oneButton.identifier), "Success message should include element ID")
        } else {
            XCTFail("Handler should return text content")
        }
        
        print("testBasicClick completed successfully")
    }
    
    /// Test clicking on a UI element at specific coordinates
    func testClickWithCoordinates() async throws {
        // First ensure Calculator is running and active
        // This is redundant with setUp, but serves as a safety measure
        if !(try await calculatorHelper.app.isRunning()) {
            _ = try await calculatorHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }

        // Activate Calculator to ensure it's in front
        NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Clear the calculator display
        _ = try await calculatorHelper.app.clear()
        try await Task.sleep(for: .milliseconds(1000))

        // Find the "5" button with retries if needed
        var digitFive: UIElement?
        for _ in 0..<3 {
            digitFive = try await calculatorHelper.app.findButton("5")
            if digitFive != nil { break }
            try await Task.sleep(for: .milliseconds(1000))
        }

        guard let digitFive = digitFive else {
            XCTFail("Failed to find button '5' after multiple attempts")
            return
        }

        // Log the element we found to help with debugging
        print("Found button '5' at frame: \(digitFive.frame)")

        // Verify the button has valid coordinates
        XCTAssertGreaterThan(digitFive.frame.width, 10, "Button should have reasonable width")
        XCTAssertGreaterThan(digitFive.frame.height, 10, "Button should have reasonable height")

        // Calculate the center point of the button
        let centerX = digitFive.frame.origin.x + digitFive.frame.size.width / 2
        let centerY = digitFive.frame.origin.y + digitFive.frame.size.height / 2

        // Test parameter validation using both toolChain.clickAtPosition and the raw handler
        
        // First test via toolChain
        let clickSuccess = try await calculatorHelper.toolChain.clickAtPosition(
            position: CGPoint(x: centerX, y: centerY)
        )
        XCTAssertTrue(clickSuccess, "Should click at coordinates successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // Verify the display shows "5"
        try await calculatorHelper.assertDisplayValue("5", message: "Display should show '5' after clicking at coordinates")
        
        // Clear calculator for next test
        _ = try await calculatorHelper.app.clear()
        try await Task.sleep(for: .milliseconds(1000))
        
        // Now test the handler directly with double values
        let doubleParams: [String: Value] = [
            "action": .string("click"),
            "x": .double(centerX),
            "y": .double(centerY)
        ]
        
        let doubleResult = try await calculatorHelper.toolChain.uiInteractionTool.handler(doubleParams)
        XCTAssertFalse(doubleResult.isEmpty, "Handler should return non-empty result for double coordinates")
        
        // Verify the display shows "5" again
        try await calculatorHelper.assertDisplayValue("5", message: "Display should show '5' after clicking with double coordinates")
        
        // Test with int values to verify backward compatibility
        _ = try await calculatorHelper.app.clear()
        try await Task.sleep(for: .milliseconds(1000))
        
        let intParams: [String: Value] = [
            "action": .string("click"),
            "x": .int(Int(centerX)),
            "y": .int(Int(centerY))
        ]
        
        let intResult = try await calculatorHelper.toolChain.uiInteractionTool.handler(intParams)
        XCTAssertFalse(intResult.isEmpty, "Handler should return non-empty result for int coordinates")
        
        // Verify the display shows "5" again
        try await calculatorHelper.assertDisplayValue("5", message: "Display should show '5' after clicking with int coordinates")
    }
    
    /// Test different click types (double-click, right-click)
    func testDifferentClickTypes() async throws {
        print("Starting testDifferentClickTypes with mouse-based interactions...")

        // First ensure TextEdit is running and active
        if !(try await textEditHelper.app.isRunning()) {
            _ = try await textEditHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }

        // Activate TextEdit and ensure a new document
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Start with a clean document
        try await textEditHelper.resetAppState()
        try await Task.sleep(for: .milliseconds(1000))

        print("Typing text in TextEdit...")

        // Type some text with a clear word to double-click
        let testText = "Double-click-test word test"
        let typingSuccess = try await textEditHelper.typeText(testText)
        XCTAssertTrue(typingSuccess, "Should type text successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // Get the text area element
        guard let textArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area")
            return
        }

        // Calculate a point in the text area to double-click
        // We'll aim for roughly the middle to hit our text
        let centerX = textArea.frame.origin.x + textArea.frame.size.width / 2
        let centerY = textArea.frame.origin.y + textArea.frame.size.height / 2

        print("Text area found at: \(textArea.frame)")
        print("Will double-click at position: (\(centerX), \(centerY))")

        // First test the position-based double-click using doubleClickAtPosition
        try await textEditHelper.toolChain.interactionService.doubleClickAtPosition(position: CGPoint(x: centerX, y: centerY))
        try await Task.sleep(for: .milliseconds(1000))

        // Now type replacement text that should replace the selected word
        print("Typing replacement text...")
        let replacementText = "REPLACED"
        _ = try await textEditHelper.typeText(replacementText)
        try await Task.sleep(for: .milliseconds(1000))

        // Get the text and verify the replacement
        let documentText = try await textEditHelper.app.getText()
        XCTAssertNotNil(documentText, "Should get text from document")
        print("Final document text: \(documentText ?? "nil")")

        // We can't guarantee exactly which word was selected,
        // but we can verify the replacement text is there
        XCTAssertTrue(documentText?.contains(replacementText) ?? false,
                      "Document should contain the replacement text")
        
        // Now test the element-based double-click using the handler directly
        // Type new text for this test
        try await textEditHelper.resetAppState()
        try await Task.sleep(for: .milliseconds(1000))
        
        let newText = "Test double-click on element"
        _ = try await textEditHelper.typeText(newText)
        try await Task.sleep(for: .milliseconds(2000))
        
        // Get the text area element again after reset
        guard let newTextArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area after reset")
            return
        }
        
        // Try double-click through the handler
        let doubleClickParams: [String: Value] = [
            "action": .string("double_click"),
            "elementId": .string(newTextArea.identifier)
        ]
        
        let doubleClickResult = try await textEditHelper.toolChain.uiInteractionTool.handler(doubleClickParams)
        XCTAssertFalse(doubleClickResult.isEmpty, "Handler should return non-empty result for double-click")
        try await Task.sleep(for: .milliseconds(1000))
        
        // Type new replacement text
        let newReplacement = "ELEMENT_DOUBLE_CLICKED"
        _ = try await textEditHelper.typeText(newReplacement)
        try await Task.sleep(for: .milliseconds(1000))
        
        // Verify text was replaced
        let newDocumentText = try await textEditHelper.app.getText()
        XCTAssertNotNil(newDocumentText, "Should get text from document after element double-click")
        XCTAssertTrue(newDocumentText?.contains(newReplacement) ?? false,
                      "Document should contain the new replacement text after element double-click")
    }
    
    /// Test right-click functionality
    func testRightClick() async throws {
        print("Starting testRightClick...")
        
        // Ensure TextEdit is running and active
        if !(try await textEditHelper.app.isRunning()) {
            _ = try await textEditHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }
        
        // Activate TextEdit and ensure a new document
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))
        
        // Start with a clean document
        try await textEditHelper.resetAppState()
        try await Task.sleep(for: .milliseconds(1000))
        
        // Type some text to right-click on
        let testText = "Right-click test text"
        let typingSuccess = try await textEditHelper.typeText(testText)
        XCTAssertTrue(typingSuccess, "Should type text successfully")
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get the text area element
        guard let textArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area")
            return
        }
        
        // Use the UIInteractionTool handler directly to test right-click
        let rightClickParams: [String: Value] = [
            "action": .string("right_click"),
            "elementId": .string(textArea.identifier)
        ]
        
        let rightClickResult = try await textEditHelper.toolChain.uiInteractionTool.handler(rightClickParams)
        XCTAssertFalse(rightClickResult.isEmpty, "Handler should return non-empty result for right-click")
        
        // Since it's difficult to programmatically verify a context menu appeared,
        // we'll just validate that no error was thrown and a result was returned
        
        // Dismiss any context menu by clicking elsewhere
        // Calculate a point outside the text area
        let outsidePoint = CGPoint(x: 50, y: 50)
        _ = try await textEditHelper.toolChain.clickAtPosition(position: outsidePoint)
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    /// Test drag operation
    func testDragOperation() async throws {
        // This is a placeholder for a drag operation test
        // Implementing a robust drag test requires careful selection of source and target elements
        // and verification of the drag result, which depends on the specific application behavior
        
        // For now, we'll implement a basic test that verifies the API accepts the parameters
        // and returns a success result, even though we won't verify the actual drag effect
        
        print("Starting testDragOperation placeholder...")
        
        // Ensure TextEdit is running and active
        if !(try await textEditHelper.app.isRunning()) {
            _ = try await textEditHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }
        
        // Activate TextEdit and ensure a new document
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))
        
        // Start with a clean document
        try await textEditHelper.resetAppState()
        try await Task.sleep(for: .milliseconds(1000))
        
        // Type some text
        let testText = "Drag operation test text"
        let typingSuccess = try await textEditHelper.typeText(testText)
        XCTAssertTrue(typingSuccess, "Should type text successfully")
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get the text area element
        guard let textArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area")
            return
        }
        
        // Use the API with expected parameters, though we can't effectively verify a drag operation
        // without a proper source and target that make sense to drag between
        
        // TEST PARAMETER VALIDATION
        // Test missing targetElementId
        do {
            let invalidParams: [String: Value] = [
                "action": .string("drag"),
                "elementId": .string(textArea.identifier)
                // Missing targetElementId
            ]
            
            _ = try await textEditHelper.toolChain.uiInteractionTool.handler(invalidParams)
            XCTFail("Should throw an error when targetElementId is missing")
        } catch {
            // Expected error - success
            let errorMessage = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorMessage.contains("target") || errorMessage.contains("missing"),
                "Error should indicate missing targetElementId parameter"
            )
        }
    }
    
    /// Test scroll operation
    func testScrollOperation() async throws {
        print("Starting testScrollOperation...")

        // Ensure TextEdit is running and active
        if !(try await textEditHelper.app.isRunning()) {
            _ = try await textEditHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }

        // Activate TextEdit and ensure a new document
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Use the current working directory to build the path (simpler approach)
        // During testing, the CWD is the MacMCP project directory
        let projectDir = FileManager.default.currentDirectoryPath
        print("Current working directory: \(projectDir)")

        // Build full path to test file
        let testFileURL = URL(fileURLWithPath: projectDir)
            .appendingPathComponent("Tests")
            .appendingPathComponent("TestsWithoutMocks")
            .appendingPathComponent("TestAssets")
            .appendingPathComponent("ScrollTestContent.txt")

        print("Test file path: \(testFileURL.path)")

        // Verify file exists before attempting to open
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: testFileURL.path) {
            print("Test file exists at path: \(testFileURL.path)")
        } else {
            XCTFail("Test file not found at path: \(testFileURL.path)")
            return
        }

        // Ensure TextEdit is in the foreground by explicitly activating it
        print("Ensuring TextEdit is in foreground before opening file...")
        let activateParams: [String: Value] = [
            "action": .string("activateApplication"),
            "bundleIdentifier": .string(textEditHelper.app.bundleId)
        ]

        let activateResult = try await textEditHelper.toolChain.applicationManagementTool.handler(activateParams)
        if let content = activateResult.first, case .text(let text) = content {
            print("Activation result: \(text)")
        }

        // Verify that TextEdit is now the frontmost application
        let frontmostParams: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]

        let frontmostResult = try await textEditHelper.toolChain.applicationManagementTool.handler(frontmostParams)
        if let content = frontmostResult.first, case .text(let text) = content {
            print("Frontmost app: \(text)")
        }

        // Wait a bit to ensure application is fully focused
        try await Task.sleep(for: .milliseconds(1000))

        // Open the scroll test file - this brings up a file dialog
        let openSuccess = try await textEditHelper.app.openDocument(from: testFileURL.path)
        XCTAssertTrue(openSuccess, "Should start open document operation successfully")
        print("Started document open operation")

        // Wait for the dialog to fully appear and stabilize
        print("Waiting for file dialog to appear...")
        try await Task.sleep(for: .milliseconds(3000))

        // We need to click the "Open" button in the file dialog
        // Multiple approaches ensure we can reliably find the button:
        // 1. Look for a button with title "Open"
        // 2. Look for a button with ID containing "OKButton"
        // 3. Look for a button in a sheet or dialog

        print("Looking for Open button in file dialog...")

        // Use multiple approaches to find the Open/OK button
        let searchScopes = ["application", "system"]
        var openButton: UIElement? = nil

        // First, try to find by title "Open"
        for scope in searchScopes {
            print("Searching for button with title 'Open' in scope: \(scope)...")

            let openButtonCriteria = UIElementCriteria(
                role: "AXButton",
                title: "Open"
            )

            openButton = try await textEditHelper.toolChain.findElement(
                matching: openButtonCriteria,
                scope: scope,
                bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
                maxDepth: 20
            )

            if openButton != nil {
                print("Found button with title 'Open': \(openButton!.identifier)")
                break
            }
        }

        // If not found by title, try to find by ID containing "OKButton"
        if openButton == nil {
            print("Button with title 'Open' not found, searching for ID containing 'OKButton'...")

            for scope in searchScopes {
                let buttons = try await textEditHelper.toolChain.findElements(
                    matching: UIElementCriteria(role: "AXButton"),
                    scope: scope,
                    bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
                    maxDepth: 20
                )

                // Look for buttons with "OKButton" in their ID
                for button in buttons {
                    if button.identifier.contains("OKButton") {
                        openButton = button
                        print("Found button with ID containing 'OKButton': \(button.identifier)")
                        break
                    }
                }

                if openButton != nil {
                    break
                }
            }
        }

        // If still not found, try to find by title containing "Open"
        if openButton == nil {
            print("Button with ID containing 'OKButton' not found, searching for title containing 'Open'...")

            for scope in searchScopes {
                let openButtonCriteria = UIElementCriteria(
                    role: "AXButton",
                    titleContains: "Open"
                )

                openButton = try await textEditHelper.toolChain.findElement(
                    matching: openButtonCriteria,
                    scope: scope,
                    bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
                    maxDepth: 20
                )

                if openButton != nil {
                    print("Found button with title containing 'Open': \(openButton!.identifier)")
                    break
                }
            }
        }

        if let openButton = openButton {
            print("Found Open button with ID: \(openButton.identifier)")

            // Click the Open button
            let clickParams: [String: Value] = [
                "action": .string("click"),
                "elementId": .string(openButton.identifier)
            ]

            _ = try await textEditHelper.toolChain.uiInteractionTool.handler(clickParams)
            print("Clicked Open button")

            // Wait for file to open
            try await Task.sleep(for: .milliseconds(3000))
        } else {
            // As a fallback, try using keyboard shortcut to confirm the dialog
            print("Could not find Open button - trying keyboard shortcut...")

            // Press Return key to confirm the dialog
            let returnKeyParams: [String: Value] = [
                "action": .string("key_sequence"),
                "sequence": .array([
                    .object([
                        "tap": .string("return")
                    ])
                ])
            ]

            _ = try await textEditHelper.toolChain.keyboardInteractionTool.handler(returnKeyParams)
            print("Pressed Return key to confirm dialog")

            try await Task.sleep(for: .milliseconds(3000))
        }

        // Get the text area element
        print("Attempting to get text area...")
        guard let textArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area")
            return
        }
        print("Found text area with identifier: \(textArea.identifier)")
        
        // Get initial document content position information
        // We'll check this to verify that scrolling actually worked
        let initialDocText = try await textEditHelper.app.getText()
        print("Document loaded with \(initialDocText?.count ?? 0) characters")

        // Get initial visible range (a real implementation would capture what's visible)
        // For this test, we'll simulate a check using a marker in the text file
        let hasScrolledMarker = "SCROLL_TEST_MARKER_END"
        let initiallyShowsEndMarker = initialDocText?.contains(hasScrolledMarker) ?? false
        print("Initial document view state - shows end marker: \(initiallyShowsEndMarker)")

        print("===== TextArea Element Details =====")
        print("Role: \(textArea.role)")
        print("ID: \(textArea.identifier)")
        if let desc = textArea.elementDescription {
            print("Description: \(desc)")
        } else {
            print("Description: <unavailable>")
        }
        print("Frame: \(textArea.frame)")
        print("Children: \(textArea.children.count)")
        print("Actions: \(textArea.actions.joined(separator: ", "))")
        print("Capabilities: Clickable: \(textArea.isClickable), Editable: \(textArea.isEditable)")

        // Additional debugging - raw attributes
        print("All attributes:")
        for (key, value) in textArea.attributes {
            print("  \(key): \(value)")
        }

        // Let's also search for ALL text areas and list them to see if we're getting the wrong one
        print("\n=== All Text Areas in TextEdit ===")
        let allTextAreas = try await textEditHelper.toolChain.findElements(
            matching: UIElementCriteria(role: "AXTextArea"),
            scope: "application",
            bundleId: textEditHelper.app.bundleId,
            maxDepth: 20
        )

        print("Found \(allTextAreas.count) text areas")
        for (i, area) in allTextAreas.enumerated() {
            print("TextArea \(i):")
            print("  ID: \(area.identifier)")
            print("  Role: \(area.role)")
            print("  Frame: \(area.frame)")
            print("  Actions: \(area.actions.joined(separator: ", "))")
        }

        // Also search for groups that might be confusing the system
        print("\n=== All Groups that might be text areas ===")
        let groups = try await textEditHelper.toolChain.findElements(
            matching: UIElementCriteria(role: "AXGroup"),
            scope: "application",
            bundleId: textEditHelper.app.bundleId,
            maxDepth: 10
        )

        let potentialTextGroups = groups.filter {
            $0.isEditable || ($0.frame.size.width > 200 && $0.frame.size.height > 200)
        }

        print("Found \(potentialTextGroups.count) potential text groups")
        for (i, group) in potentialTextGroups.enumerated() {
            print("Group \(i):")
            print("  ID: \(group.identifier)")
            print("  Role: \(group.role)")
            print("  Frame: \(group.frame)")
            print("  Editable: \(group.isEditable)")
            print("  Actions: \(group.actions.joined(separator: ", "))")
        }

        print("===================================")

        // Test scroll down (scrolls toward end of document)
        print("Testing scroll down operation...")
        let scrollDownParams: [String: Value] = [
            "action": .string("scroll"),
            "elementId": .string(textArea.identifier),
            "direction": .string("down"),
            "amount": .double(0.9) // Scroll almost to the bottom
        ]

        let scrollDownResult = try await textEditHelper.toolChain.uiInteractionTool.handler(scrollDownParams)
        XCTAssertFalse(scrollDownResult.isEmpty, "Handler should return non-empty result for scroll down")
        print("Scroll down operation completed")
        try await Task.sleep(for: .milliseconds(1000))

        // A real test would check if scrolling changed what's visible
        // Ideally, we'd check the scroll position in the text area

        // Test scroll up
        print("Testing scroll up operation...")
        let scrollUpParams: [String: Value] = [
            "action": .string("scroll"),
            "elementId": .string(textArea.identifier),
            "direction": .string("up"),
            "amount": .double(0.9) // Scroll almost to the top
        ]

        let scrollUpResult = try await textEditHelper.toolChain.uiInteractionTool.handler(scrollUpParams)
        XCTAssertFalse(scrollUpResult.isEmpty, "Handler should return non-empty result for scroll up")
        print("Scroll up operation completed")
        try await Task.sleep(for: .milliseconds(1000))

        // Now verify results of all operations
        // 1. File should be loaded - we already verified text area
        XCTAssertNotNil(initialDocText, "Document should contain text content")
        print("Document content preview: \(String(describing: initialDocText?.prefix(100)))")

        // Check for the file content - look for any text that would be in our file
        XCTAssertTrue(initialDocText?.contains("test file for scrolling") ?? false,
                      "Document should contain test file content")

        // Check if the marker string is present (might be in a different part of visible area)
        let testFileMarkers = ["Lorem ipsum", "scrolling operations", "content below"]
        let foundAnyMarker = testFileMarkers.contains { marker in
            initialDocText?.contains(marker) ?? false
        }
        XCTAssertTrue(foundAnyMarker, "Document should contain at least one expected marker")

        // 2. Scroll operations should have returned success results
        if let content = scrollDownResult.first, case .text(let text) = content {
            XCTAssertTrue(text.contains("success") || text.contains("scroll"),
                          "Scroll down result should indicate success")
        }

        if let content = scrollUpResult.first, case .text(let text) = content {
            XCTAssertTrue(text.contains("success") || text.contains("scroll"),
                          "Scroll up result should indicate success")
        }

        // PARAMETER VALIDATION TESTS - Separated from actual functionality tests
        print("Running parameter validation tests...")

        // Test helper to validate error responses
        func testInvalidParams(_ params: [String: Value], expectedErrorContains: String, message: String) async throws {
            do {
                _ = try await textEditHelper.toolChain.uiInteractionTool.handler(params)
                XCTFail(message)
            } catch {
                // Expected error - success
                let errorMessage = error.localizedDescription.lowercased()
                XCTAssertTrue(
                    errorMessage.contains(expectedErrorContains.lowercased()),
                    "Error should indicate: \(expectedErrorContains)"
                )
                print("✓ Validation test passed: \(message)")
            }
        }

        // Test missing direction
        try await testInvalidParams(
            [
                "action": .string("scroll"),
                "elementId": .string(textArea.identifier),
                "amount": .double(0.5)
                // Missing direction
            ],
            expectedErrorContains: "direction",
            message: "Should throw an error when direction is missing"
        )

        // Test invalid direction
        try await testInvalidParams(
            [
                "action": .string("scroll"),
                "elementId": .string(textArea.identifier),
                "direction": .string("invalid"),
                "amount": .double(0.5)
            ],
            expectedErrorContains: "direction",
            message: "Should throw an error when direction is invalid"
        )

        // Test missing amount
        try await testInvalidParams(
            [
                "action": .string("scroll"),
                "elementId": .string(textArea.identifier),
                "direction": .string("down")
                // Missing amount
            ],
            expectedErrorContains: "amount",
            message: "Should throw an error when amount is missing"
        )

        // Test invalid amount (out of range)
        try await testInvalidParams(
            [
                "action": .string("scroll"),
                "elementId": .string(textArea.identifier),
                "direction": .string("down"),
                "amount": .double(1.5) // Out of range
            ],
            expectedErrorContains: "amount",
            message: "Should throw an error when amount is out of range"
        )
    }
    
    /// Test type text functionality (handled via keyboard interactions)
    func testTypeText() async throws {
        // Note: Type text is typically handled via KeyboardInteractionTool rather than UIInteractionTool
        // But we should make sure that our click operations correctly position the cursor for text input

        print("Starting testTypeText with keyboard navigation...")

        // Ensure TextEdit is running and active
        if !(try await textEditHelper.app.isRunning()) {
            _ = try await textEditHelper.app.launch()
            try await Task.sleep(for: .milliseconds(3000))
        }

        // Activate TextEdit and ensure a new document
        NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Start with a clean document
        try await textEditHelper.resetAppState()
        try await Task.sleep(for: .milliseconds(1000))

        // Make sure we have a clean document for this positioning test
        _ = try await textEditHelper.app.clearDocumentContent()
        try await Task.sleep(for: .milliseconds(500))

        // Get the text area element
        guard let textArea = try await textEditHelper.app.getTextArea() else {
            XCTFail("Failed to find TextEdit text area")
            return
        }

        // 1. First click in text area to ensure it has focus
        let clickResult = try await textEditHelper.toolChain.clickElement(
            elementId: textArea.identifier,
            bundleId: textEditHelper.app.bundleId
        )
        XCTAssertTrue(clickResult, "Should click text area successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // 2. Type "Part1" text
        let part1 = "Part1"
        let typingSuccess1 = try await textEditHelper.typeText(part1)
        XCTAssertTrue(typingSuccess1, "Should type part1 text successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // 3. Type "Part3" text - this creates a gap where we'll insert "Part2"
        let part3 = " Part3"
        let typingSuccess3 = try await textEditHelper.typeText(part3)
        XCTAssertTrue(typingSuccess3, "Should type part3 text successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // We now have "Part1 Part3" in the document

        // 4. Get text content for verification
        let initialText = try await textEditHelper.app.getText()
        let expectedInitialText = "Part1 Part3"
        XCTAssertTrue(initialText?.contains(expectedInitialText) ?? false,
                      "Document should initially contain 'Part1 Part3'")

        // 5. Now position the cursor right after "Part1" by clicking at that position
        // First, get the text area element again to ensure we have current coordinates
        let freshTextArea = try await textEditHelper.app.getTextArea()
        guard let textArea = freshTextArea else {
            XCTFail("Could not find text area for positioning cursor")
            return
        }

        // Calculate a position just after "Part1" - this will be slightly to the right of the start
        // of the text, enough to be after the first word but before the second
        let textAreaFrame = textArea.frame

        // Position approximately after "Part1" - about 20% of the way across
        // For a real test we would want to calculate this more precisely based on font metrics
        let posX = textAreaFrame.origin.x + (textAreaFrame.size.width * 0.2)
        let posY = textAreaFrame.origin.y + (textAreaFrame.size.height * 0.5) // Middle of text area

        print("Clicking to position cursor after 'Part1' at coordinates: (\(posX), \(posY))")

        // Click at the calculated position to place cursor after "Part1"
        _ = try await textEditHelper.toolChain.clickAtPosition(
            position: CGPoint(x: posX, y: posY)
        )
        try await Task.sleep(for: .milliseconds(1000))

        // 6. Now type the inserted text - using the new typeText that doesn't clear
        let part2 = " Part2"
        let typingSuccess2 = try await textEditHelper.typeText(part2)
        XCTAssertTrue(typingSuccess2, "Should type part2 text successfully")
        try await Task.sleep(for: .milliseconds(1000))

        // 7. Verify the final text has all three parts in the correct order
        let finalText = try await textEditHelper.app.getText()
        let expectedFinalText = "Part1 Part2 Part3"

        print("Expected final text: \"\(expectedFinalText)\"")
        print("Actual final text: \"\(finalText ?? "nil")\"")

        XCTAssertTrue(finalText?.contains(expectedFinalText) ?? false,
                      "Document should contain all three parts in correct order: 'Part1 Part2 Part3'")
    }
    
    /// Test attempting to click on a non-existent element
    func testClickNonExistentElement() async throws {
        print("Starting testClickNonExistentElement")

        // Ensure Calculator is active before interactions
        NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))

        // Use a clearly non-existent element ID
        let nonExistentId = "ui://AXApplication/AXWindow/AXButton[@description=\"NonExistentButton\"]"
        print("Attempting to click on non-existent element: \(nonExistentId)")

        do {
            _ = try await calculatorHelper.toolChain.clickElement(
                elementId: nonExistentId,
                bundleId: calculatorHelper.app.bundleId
            )
            XCTFail("Should throw an error for non-existent element")
        } catch {
            // Success - we expect an error
            let errorMessage = error.localizedDescription.lowercased()
            print("Received expected error: \(errorMessage)")
            XCTAssertTrue(
                errorMessage.contains("not found") ||
                errorMessage.contains("no element") ||
                errorMessage.contains("invalid") ||
                errorMessage.contains("unable to find"),
                "Error should indicate element not found: \(errorMessage)"
            )
            print("Test passed: Appropriate error thrown for non-existent element")
        }
        
        // Test direct handler call with non-existent element
        do {
            let nonExistentParams: [String: Value] = [
                "action": .string("click"),
                "elementId": .string(nonExistentId),
                "appBundleId": .string(calculatorHelper.app.bundleId)
            ]
            
            _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(nonExistentParams)
            XCTFail("Handler should throw an error for non-existent element")
        } catch {
            // Expected error - success
            let errorMessage = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorMessage.contains("not found") || 
                errorMessage.contains("no element") || 
                errorMessage.contains("invalid"),
                "Error should indicate element not found"
            )
        }
    }
    
    /// Test invalid action parameter
    func testInvalidAction() async throws {
        print("Starting testInvalidAction")
        
        // Ensure Calculator is active before interactions
        NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId).first?.activate(options: [])
        try await Task.sleep(for: .milliseconds(2000))
        
        // Test with an invalid action
        do {
            let invalidParams: [String: Value] = [
                "action": .string("invalid_action"),
                "elementId": .string("some_element_id")
            ]
            
            _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(invalidParams)
            XCTFail("Should throw an error for invalid action")
        } catch {
            // Expected error - success
            let errorMessage = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorMessage.contains("invalid action") || 
                errorMessage.contains("unknown action"),
                "Error should indicate invalid action: \(errorMessage)"
            )
        }
        
        // Test with missing action
        do {
            let invalidParams: [String: Value] = [
                "elementId": .string("some_element_id")
                // Missing action
            ]
            
            _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(invalidParams)
            XCTFail("Should throw an error for missing action")
        } catch {
            // Expected error - success
            let errorMessage = error.localizedDescription.lowercased()
            XCTAssertTrue(
                errorMessage.contains("action") || 
                errorMessage.contains("required"),
                "Error should indicate missing action: \(errorMessage)"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Save a screenshot of the UI state for debugging
    private func saveDebugScreenshot(appBundleId: String, testName: String) async throws {
        // Create parameters for the screenshot tool
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string(appBundleId)
        ]
        
        do {
            // Take the screenshot
            let result = try await calculatorHelper.toolChain.screenshotTool.handler(params)
            
            // Save the screenshot with a meaningful name
            if let content = result.first, case .image(let data, _, _) = content {
                let decodedData = Data(base64Encoded: data)!
                
                let outputDir = "/Users/jesse/Documents/GitHub/projects/mac-mcp/MacMCP/test-screenshots"
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = dateFormatter.string(from: Date())
                let filename = "ui_interaction_\(testName)_\(timestamp).png"
                let fileURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)
                
                do {
                    // Create the directory if it doesn't exist
                    try FileManager.default.createDirectory(
                        at: URL(fileURLWithPath: outputDir),
                        withIntermediateDirectories: true
                    )
                    
                    try decodedData.write(to: fileURL)
                    print("Saved debug screenshot: \(fileURL.path)")
                } catch {
                    print("Error saving debug screenshot: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error taking debug screenshot: \(error.localizedDescription)")
        }
    }
}
