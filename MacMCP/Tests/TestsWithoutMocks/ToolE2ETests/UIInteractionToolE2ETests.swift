// ABOUTME: UIInteractionToolE2ETests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// End-to-end tests for the UIInteractionTool using Calculator and TextEdit apps
@Suite(.serialized)
struct UIInteractionToolE2ETests {
  // Test components
  private var calculatorHelper: CalculatorTestHelper!
  private var textEditHelper: TextEditTestHelper!

  // Save references to app state
  private var calculatorRunning = false
  private var textEditRunning = false

  // Shared setup method
  private mutating func setUp() async throws {

    // Initialize test helpers
    calculatorHelper = await CalculatorTestHelper.sharedHelper()
    textEditHelper = await TextEditTestHelper.shared()

    // Check if apps are already running
    calculatorRunning = try await calculatorHelper.app.isRunning()
    textEditRunning = try await textEditHelper.app.isRunning()

    // For Calculator: terminate and relaunch for a clean state
    if calculatorRunning {
      _ = try await calculatorHelper.app.terminate()
      try await Task.sleep(for: .milliseconds(1000))
    }

    // Launch Calculator
    _ = try await calculatorHelper.app.launch()

    // Allow time for Calculator to launch and stabilize - increased wait time
    try await Task.sleep(for: .milliseconds(3000))

    // Only set up TextEdit if the test needs it
    if try await testRequiresTextEdit() {
      if textEditRunning {
        _ = try await textEditHelper.app.terminate()
        try await Task.sleep(for: .milliseconds(1000))
      }

      // Launch TextEdit
      _ = try await textEditHelper.app.launch()

      // Allow time for TextEdit to launch and stabilize
      try await Task.sleep(for: .milliseconds(3000))

      // Reset TextEdit state
      try await textEditHelper.resetAppState()
    }
  }

  /// Helper method to determine if the current test requires TextEdit
  private func testRequiresTextEdit(function: String = #function) async throws -> Bool {
    // Use the function name instead of XCTestCase.name
    let testName = function

    // Return true for tests that need TextEdit
    return testName.contains("testDifferentClickTypes") || testName.contains("testRightClick")
      || testName.contains("testDragOperation") || testName.contains("testScrollOperation")
      || testName.contains("testTypeText")
  }

  // Shared teardown method
  private mutating func tearDown() async throws {
    // Always terminate apps we launched during the test
    _ = try? await calculatorHelper.app.terminate()

    // Only close TextEdit if the test used it
    if try await testRequiresTextEdit() {
      _ = try? await textEditHelper.app.terminate()
    }
  }

  // MARK: - Test Methods

  /// Test basic clicking using UIInteractionTool handler interface
  @Test("Basic Click Operations")
  mutating func testBasicClick() async throws {
    try await setUp()

    // Ensure Calculator is active before interactions
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Clear the calculator first
    _ = try await calculatorHelper.app.clear()
    try await Task.sleep(for: .milliseconds(1000))

    // Find a simple button to test clicking
    var digitFive: UIElement?
    for _ in 0..<3 {
      digitFive = try await calculatorHelper.app.findButton("5")
      if digitFive != nil { break }
      try await Task.sleep(for: .milliseconds(1000))
    }

    #expect(digitFive != nil, "Should find the '5' button")
    guard let fiveButton = digitFive else {
      #expect(Bool(false), "Failed to find '5' button")
      return
    }

    // Test direct UIInteractionTool handler interface
    let buttonPath = fiveButton.path
    if buttonPath.isEmpty {
      #expect(Bool(false), "Empty path for '5' button")
      return
    }
    
    let result = try await calculatorHelper.toolChain.uiInteractionTool.handler([
      "action": .string("click"),
      "id": .string(buttonPath),
      "appBundleId": .string(calculatorHelper.app.bundleId),
    ])

    #expect(!result.isEmpty, "Handler should return non-empty result")
    if case .text(let message) = result.first {
      #expect(
        message.contains("Successfully clicked") || message.contains("success"),
        "Success message should indicate click was successful"
      )
    } else {
      #expect(Bool(false), "Handler should return text content")
    }

    // Verify the display shows the clicked button
    try await Task.sleep(for: .milliseconds(1000))
    try await calculatorHelper.assertDisplayValue(
      "5", message: "Display should show '5' after clicking button")

    try await tearDown()
  }

  /// Test clicking on a UI element at specific coordinates
  @Test("Click With Coordinates")
  mutating func testClickWithCoordinates() async throws {
    try await setUp()
    // First ensure Calculator is running and active
    // This is redundant with setUp, but serves as a safety measure
    if try await !(calculatorHelper.app.isRunning()) {
      _ = try await calculatorHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate Calculator to ensure it's in front
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId)
      .first?
      .activate(options: [])
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

    guard let digitFive else {
      #expect(Bool(false), "Failed to find button '5' after multiple attempts")
      return
    }


    // Verify the button has valid coordinates
    #expect(digitFive.frame.width > 10, "Button should have reasonable width")
    #expect(digitFive.frame.height > 10, "Button should have reasonable height")

    // Calculate the center point of the button
    let centerX = digitFive.frame.origin.x + digitFive.frame.size.width / 2
    let centerY = digitFive.frame.origin.y + digitFive.frame.size.height / 2

    // Test parameter validation using both toolChain.clickAtPosition and the raw handler

    // First test via toolChain
    let clickSuccess = try await calculatorHelper.toolChain.clickAtPosition(
      position: CGPoint(x: centerX, y: centerY),
    )
    #expect(clickSuccess, "Should click at coordinates successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // Verify the display shows "5"
    try await calculatorHelper.assertDisplayValue(
      "5",
      message: "Display should show '5' after clicking at coordinates",
    )

    // Clear calculator for next test
    _ = try await calculatorHelper.app.clear()
    try await Task.sleep(for: .milliseconds(1000))

    // Now test the handler directly with double values
    let doubleParams: [String: Value] = [
      "action": .string("click"),
      "x": .double(centerX),
      "y": .double(centerY),
    ]

    let doubleResult = try await calculatorHelper.toolChain.uiInteractionTool.handler(doubleParams)
    #expect(
      !doubleResult.isEmpty, "Handler should return non-empty result for double coordinates")

    // Verify the display shows "5" again
    try await calculatorHelper.assertDisplayValue(
      "5",
      message: "Display should show '5' after clicking with double coordinates",
    )

    // Test with int values to verify backward compatibility
    _ = try await calculatorHelper.app.clear()
    try await Task.sleep(for: .milliseconds(1000))

    let intParams: [String: Value] = [
      "action": .string("click"),
      "x": .int(Int(centerX)),
      "y": .int(Int(centerY)),
    ]

    let intResult = try await calculatorHelper.toolChain.uiInteractionTool.handler(intParams)
    #expect(!intResult.isEmpty, "Handler should return non-empty result for int coordinates")

    // Verify the display shows "5" again
    try await calculatorHelper.assertDisplayValue(
      "5",
      message: "Display should show '5' after clicking with int coordinates",
    )
    
    try await tearDown()
  }

  /// Test different click types (double-click, right-click)
  @Test("Different Click Types")
  mutating func testDifferentClickTypes() async throws {
    try await setUp()

    // First ensure TextEdit is running and active
    if try await !(textEditHelper.app.isRunning()) {
      _ = try await textEditHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate TextEdit and ensure a new document
    NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Start with a clean document
    try await textEditHelper.resetAppState()
    try await Task.sleep(for: .milliseconds(1000))


    // Type some text with a clear word to double-click
    let testText = "Double-click-test word test"
    let typingSuccess = try await textEditHelper.typeText(testText)
    #expect(typingSuccess, "Should type text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // Get the text area element
    guard let textArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area")
      return
    }

    // Calculate a point in the text area to double-click
    // We'll aim for roughly the middle to hit our text
    let centerX = textArea.frame.origin.x + textArea.frame.size.width / 2
    let centerY = textArea.frame.origin.y + textArea.frame.size.height / 2

    // First test the position-based double-click using doubleClickAtPosition
    try await textEditHelper.toolChain.interactionService.doubleClickAtPosition(
      position: CGPoint(
        x: centerX,
        y: centerY,
      ))
    try await Task.sleep(for: .milliseconds(1000))

    // Now type replacement text that should replace the selected word
    let replacementText = "REPLACED"
    _ = try await textEditHelper.typeText(replacementText)
    try await Task.sleep(for: .milliseconds(1000))

    // Get the text and verify the replacement
    let documentText = try await textEditHelper.app.getText()
    #expect(documentText != nil, "Should get text from document")
   
    // We can't guarantee exactly which word was selected,
    // but we can verify the replacement text is there
    #expect(
      documentText?.contains(replacementText) ?? false,
      "Document should contain the replacement text",
    )

    // Now test the element-based double-click using the handler directly
    // Type new text for this test
    try await textEditHelper.resetAppState()
    try await Task.sleep(for: .milliseconds(1000))

    let newText = "Test double-click on element"
    _ = try await textEditHelper.typeText(newText)
    try await Task.sleep(for: .milliseconds(2000))

    // Get the text area element again after reset
    guard let newTextArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area after reset")
      return
    }

    // Try double-click through the handler
    let newTextAreaPath = newTextArea.path
    if newTextAreaPath.isEmpty {
      #expect(Bool(false), "Empty path for text area")
      return
    }
    let doubleClickParams: [String: Value] = [
      "action": .string("double_click"),
      "id": .string(newTextAreaPath),
    ]

    let doubleClickResult = try await textEditHelper.toolChain.uiInteractionTool.handler(
      doubleClickParams)
    #expect(!doubleClickResult.isEmpty, "Handler should return non-empty result for double-click")
    try await Task.sleep(for: .milliseconds(1000))

    // Type new replacement text
    let newReplacement = "ELEMENT_DOUBLE_CLICKED"
    _ = try await textEditHelper.typeText(newReplacement)
    try await Task.sleep(for: .milliseconds(1000))

    // Verify text was replaced
    let newDocumentText = try await textEditHelper.app.getText()
    #expect(newDocumentText != nil, "Should get text from document after element double-click")
    #expect(
      newDocumentText?.contains(newReplacement) ?? false,
      "Document should contain the new replacement text after element double-click",
    )
    
    try await tearDown()
  }

  /// Test right-click functionality
  @Test("Right Click Functionality")
  mutating func testRightClick() async throws {
    try await setUp()

    // Ensure TextEdit is running and active
    if try await !(textEditHelper.app.isRunning()) {
      _ = try await textEditHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate TextEdit and ensure a new document
    NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Start with a clean document
    try await textEditHelper.resetAppState()
    try await Task.sleep(for: .milliseconds(1000))

    // Type some text to right-click on
    let testText = "Right-click test text"
    let typingSuccess = try await textEditHelper.typeText(testText)
    #expect(typingSuccess, "Should type text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // Get the text area element
    guard let textArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area")
      return
    }

    // Use the UIInteractionTool handler directly to test right-click
    let textAreaPath = textArea.path
    if textAreaPath.isEmpty {
      #expect(Bool(false), "Empty path for text area")
      return
    }
    
    // Verify this is actually a text area with the right actions
    #expect(textArea.role == "AXTextArea", "Element should be AXTextArea, got: \(textArea.role)")
    #expect(textArea.actions.contains("AXShowMenu"), "TextArea should support AXShowMenu action")
    let rightClickParams: [String: Value] = [
      "action": .string("right_click"),
      "id": .string(textAreaPath),
    ]

    let rightClickResult = try await textEditHelper.toolChain.uiInteractionTool.handler(
      rightClickParams)
    #expect(!rightClickResult.isEmpty, "Handler should return non-empty result for right-click")

    // Since it's difficult to programmatically verify a context menu appeared,
    // we'll just validate that no error was thrown and a result was returned

    // Dismiss any context menu with escape key
    _ = try await textEditHelper.toolChain.keyboardInteractionTool.handler([
      "action": .string("key_sequence"),
      "sequence": .array([
        .object(["tap": .string("Escape")])
      ])
    ])
    try await Task.sleep(for: .milliseconds(500))
    
    try await tearDown()
  }

  /// Test drag operation
  @Test("Drag Operation")
  mutating func testDragOperation() async throws {
    try await setUp()
    // This is a placeholder for a drag operation test
    // Implementing a robust drag test requires careful selection of source and target elements
    // and verification of the drag result, which depends on the specific application behavior

    // For now, we'll implement a basic test that verifies the API accepts the parameters
    // and returns a success result, even though we won't verify the actual drag effect


    // Ensure TextEdit is running and active
    if try await !(textEditHelper.app.isRunning()) {
      _ = try await textEditHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate TextEdit and ensure a new document
    NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Start with a clean document
    try await textEditHelper.resetAppState()
    try await Task.sleep(for: .milliseconds(1000))

    // Type some text
    let testText = "Drag operation test text"
    let typingSuccess = try await textEditHelper.typeText(testText)
    #expect(typingSuccess, "Should type text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // Get the text area element
    guard let textArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area")
      return
    }

    // Use the API with expected parameters, though we can't effectively verify a drag operation
    // without a proper source and target that make sense to drag between

    // TEST PARAMETER VALIDATION
    // Test missing targetId
    do {
      let textAreaPath = textArea.path
      if textAreaPath.isEmpty {
        #expect(Bool(false), "Empty path for text area")
        return
      }
      let invalidParams: [String: Value] = [
        "action": .string("drag"),
        "id": .string(textAreaPath),
        // Missing targetId
      ]

      _ = try await textEditHelper.toolChain.uiInteractionTool.handler(invalidParams)
      #expect(Bool(false), "Should throw an error when targetId is missing")
    } catch {
      // Expected error - success
      let errorMessage = error.localizedDescription.lowercased()
      #expect(
        errorMessage.contains("target") || errorMessage.contains("missing"),
        "Error should indicate missing targetId parameter",
      )
    }
    
    try await tearDown()
  }

  /// Test scroll operation
  @Test("Scroll Operation")
  mutating func testScrollOperation() async throws {
    try await setUp()

    // Ensure TextEdit is running and active
    if try await !(textEditHelper.app.isRunning()) {
      _ = try await textEditHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate TextEdit and ensure a new document
    NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Use the current working directory to build the path (simpler approach)
    // During testing, the CWD is the MacMCP project directory
    let projectDir = FileManager.default.currentDirectoryPath

    // Build full path to test file
    let testFileURL = URL(fileURLWithPath: projectDir)
      .appendingPathComponent("Tests")
      .appendingPathComponent("TestsWithoutMocks")
      .appendingPathComponent("TestAssets")
      .appendingPathComponent("ScrollTestContent.txt")


    // Verify file exists before attempting to open
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: testFileURL.path) {
      #expect(Bool(false), "Test file not found at path: \(testFileURL.path)")
      return
    }

    // Ensure TextEdit is in the foreground by explicitly activating it
    let activateParams: [String: Value] = [
      "action": .string("activateApplication"),
      "bundleId": .string(textEditHelper.app.bundleId),
    ]

    let activateResult = try await textEditHelper.toolChain.applicationManagementTool.handler(
      activateParams)
    if let content = activateResult.first, case .text(_) = content {
    }

    // Verify that TextEdit is now the frontmost application
    let frontmostParams: [String: Value] = [
      "action": .string("getFrontmostApplication")
    ]

    let frontmostResult = try await textEditHelper.toolChain.applicationManagementTool.handler(
      frontmostParams)
    if let content = frontmostResult.first, case .text(_) = content {
    }

    // Wait a bit to ensure application is fully focused
    try await Task.sleep(for: .milliseconds(1000))

    // Open the scroll test file - this brings up a file dialog
    let openSuccess = try await textEditHelper.app.openDocument(from: testFileURL.path)
    #expect(openSuccess, "Should start open document operation successfully")

    // Wait for the dialog to fully appear and stabilize
    try await Task.sleep(for: .milliseconds(3000))

    // We need to click the "Open" button in the file dialog
    // Multiple approaches ensure we can reliably find the button:
    // 1. Look for a button with title "Open"
    // 2. Look for a button with ID containing "OKButton"
    // 3. Look for a button in a sheet or dialog


    // Use multiple approaches to find the Open/OK button
    let searchScopes = ["application", "system"]
    var openButton: UIElement? = nil

    // First, try to find by title "Open"
    for scope in searchScopes {

      let openButtonCriteria = UIElementCriteria(
        role: "AXButton",
        title: "Open",
      )

      openButton = try await textEditHelper.toolChain.findElement(
        matching: openButtonCriteria,
        scope: scope,
        bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
        maxDepth: 20,
      )

      if openButton != nil {
        break
      }
    }

    // If not found by title, try to find by ID containing "OKButton"
    if openButton == nil {

      for scope in searchScopes {
        let buttons = try await textEditHelper.toolChain.findElements(
          matching: UIElementCriteria(role: "AXButton"),
          scope: scope,
          bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
          maxDepth: 20,
        )

        // Look for buttons with "OKButton" in their ID
        for button in buttons {
          if button.path.contains("OKButton") {
            openButton = button
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

      for scope in searchScopes {
        let openButtonCriteria = UIElementCriteria(
          role: "AXButton",
          titleContains: "Open",
        )

        openButton = try await textEditHelper.toolChain.findElement(
          matching: openButtonCriteria,
          scope: scope,
          bundleId: scope == "application" ? textEditHelper.app.bundleId : nil,
          maxDepth: 20,
        )

        if openButton != nil {
          break
        }
      }
    }

    if let openButton {

      // Click the Open button
      let openButtonPath = openButton.path
      if openButtonPath.isEmpty {
        #expect(Bool(false), "Empty path for Open button")
        return
      }
      let clickParams: [String: Value] = [
        "action": .string("click"),
        "id": .string(openButtonPath),
      ]

      _ = try await textEditHelper.toolChain.uiInteractionTool.handler(clickParams)

      // Wait for file to open
      try await Task.sleep(for: .milliseconds(3000))
    } else {
      // As a fallback, try using keyboard shortcut to confirm the dialog

      // Press Return key to confirm the dialog
      let returnKeyParams: [String: Value] = [
        "action": .string("key_sequence"),
        "sequence": .array([
          .object([
            "tap": .string("return")
          ])
        ]),
      ]

      _ = try await textEditHelper.toolChain.keyboardInteractionTool.handler(returnKeyParams)

      try await Task.sleep(for: .milliseconds(3000))
    }

    // Get the text area element
    guard let textArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area")
      return
    }

    // Create a path to the scroll area for scrolling operations
    let scrollAreaPath =
      "macos://ui/AXApplication[@bundleId=\"\(textEditHelper.app.bundleId)\"]/AXWindow/AXScrollArea"

    // Get initial document content position information
    // We'll check this to verify that scrolling actually worked
    let initialDocText = try await textEditHelper.app.getText()

    // Get initial visible range (a real implementation would capture what's visible)
    // For this test, we'll simulate a check using a marker in the text file
    let hasScrolledMarker = "SCROLL_TEST_MARKER_END"
    let _ = initialDocText?.contains(hasScrolledMarker) ?? false
  

    // Also search for groups that might be confusing the system
    let groups = try await textEditHelper.toolChain.findElements(
      matching: UIElementCriteria(role: "AXGroup"),
      scope: "application",
      bundleId: textEditHelper.app.bundleId,
      maxDepth: 10,
    )

    let _ = groups.filter {
      $0.isEditable || ($0.frame.size.width > 200 && $0.frame.size.height > 200)
    }

    let scrollDownParams: [String: Value] = [
      "action": .string("scroll"),
      "id": .string(scrollAreaPath),
      "direction": .string("down"),
      "amount": .double(0.9),  // Scroll almost to the bottom
    ]

    let scrollDownResult = try await textEditHelper.toolChain.uiInteractionTool.handler(
      scrollDownParams)
    #expect(!scrollDownResult.isEmpty, "Handler should return non-empty result for scroll down")
    try await Task.sleep(for: .milliseconds(1000))

    // A real test would check if scrolling changed what's visible
    // Ideally, we'd check the scroll position in the text area

    // Test scroll up
    let scrollUpParams: [String: Value] = [
      "action": .string("scroll"),
      "id": .string(scrollAreaPath),
      "direction": .string("up"),
      "amount": .double(0.9),  // Scroll almost to the top
    ]

    let scrollUpResult = try await textEditHelper.toolChain.uiInteractionTool.handler(
      scrollUpParams)
    #expect(!scrollUpResult.isEmpty, "Handler should return non-empty result for scroll up")
    try await Task.sleep(for: .milliseconds(1000))

    // Now verify results of all operations
    // 1. File should be loaded - we already verified text area
    #expect(initialDocText != nil, "Document should contain text content")

    // Check for the file content - look for any text that would be in our file
    #expect(
      initialDocText?.contains("test file for scrolling") ?? false,
      "Document should contain test file content",
    )

    // Check if the marker string is present (might be in a different part of visible area)
    let testFileMarkers = ["Lorem ipsum", "scrolling operations", "content below"]
    let foundAnyMarker = testFileMarkers.contains { marker in
      initialDocText?.contains(marker) ?? false
    }
    #expect(foundAnyMarker, "Document should contain at least one expected marker")

    // 2. Scroll operations should have returned success results
    if let content = scrollDownResult.first, case .text(let text) = content {
      #expect(
        text.contains("success") || text.contains("scroll"),
        "Scroll down result should indicate success",
      )
    }

    if let content = scrollUpResult.first, case .text(let text) = content {
      #expect(
        text.contains("success") || text.contains("scroll"),
        "Scroll up result should indicate success",
      )
    }

    // PARAMETER VALIDATION TESTS - Separated from actual functionality tests

    // Test helper to validate error responses
    func testInvalidParams(
      _ params: [String: Value], expectedErrorContains: String, message: String
    ) async throws {
      do {
        _ = try await textEditHelper.toolChain.uiInteractionTool.handler(params)
        #expect(Bool(false), #"\(message)"#)
      } catch {
        // Expected error - success
        let errorMessage = error.localizedDescription.lowercased()
        #expect(
          errorMessage.contains(expectedErrorContains.lowercased()),
          "Error should indicate: \(expectedErrorContains)",
        )
      }
    }

    // Check the path for text area
    if textArea.path.isEmpty {
      #expect(Bool(false), "Empty path for text area")
      return
    }
    // We already have scrollAreaPath defined above

    // Test missing direction
    try await testInvalidParams(
      [
        "action": .string("scroll"),
        "id": .string(scrollAreaPath),
        "amount": .double(0.5),
        // Missing direction
      ],
      expectedErrorContains: "direction",
      message: "Should throw an error when direction is missing",
    )

    // Test invalid direction
    try await testInvalidParams(
      [
        "action": .string("scroll"),
        "id": .string(scrollAreaPath),
        "direction": .string("invalid"),
        "amount": .double(0.5),
      ],
      expectedErrorContains: "direction",
      message: "Should throw an error when direction is invalid",
    )

    // Test missing amount
    try await testInvalidParams(
      [
        "action": .string("scroll"),
        "id": .string(scrollAreaPath),
        "direction": .string("down"),
        // Missing amount
      ],
      expectedErrorContains: "amount",
      message: "Should throw an error when amount is missing",
    )

    // Test invalid amount (out of range)
    try await testInvalidParams(
      [
        "action": .string("scroll"),
        "id": .string(scrollAreaPath),
        "direction": .string("down"),
        "amount": .double(1.5),  // Out of range
      ],
      expectedErrorContains: "amount",
      message: "Should throw an error when amount is out of range",
    )
    
    try await tearDown()
  }

  /// Test type text functionality (handled via keyboard interactions)
  @Test("Type Text Functionality")
  mutating func testTypeText() async throws {
    try await setUp()
    // Note: Type text is typically handled via KeyboardInteractionTool rather than UIInteractionTool
    // But we should make sure that our click operations correctly position the cursor for text input


    // Ensure TextEdit is running and active
    if try await !(textEditHelper.app.isRunning()) {
      _ = try await textEditHelper.app.launch()
      try await Task.sleep(for: .milliseconds(3000))
    }

    // Activate TextEdit and ensure a new document
    NSRunningApplication.runningApplications(withBundleIdentifier: textEditHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Start with a clean document
    try await textEditHelper.resetAppState()
    try await Task.sleep(for: .milliseconds(1000))

    // Make sure we have a clean document for this positioning test
    _ = try await textEditHelper.app.clearDocumentContent()
    try await Task.sleep(for: .milliseconds(500))

    // Get the text area element
    guard let textArea = try await textEditHelper.app.getTextArea() else {
      #expect(Bool(false), "Failed to find TextEdit text area")
      return
    }

    // 1. First click in text area to ensure it has focus
    let keyboardTextAreaPath = textArea.path
    if keyboardTextAreaPath.isEmpty {
      #expect(Bool(false), "Empty path for text area")
      return
    }
    let clickResult = try await textEditHelper.toolChain.clickElement(
      elementPath: keyboardTextAreaPath,
      bundleId: textEditHelper.app.bundleId,
    )
    #expect(clickResult, "Should click text area successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // 2. Type "Part1" text
    let part1 = "Part1"
    let typingSuccess1 = try await textEditHelper.typeText(part1)
    #expect(typingSuccess1, "Should type part1 text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // 3. Type "Part3" text - this creates a gap where we'll insert "Part2"
    let part3 = " Part3"
    let typingSuccess3 = try await textEditHelper.typeText(part3)
    #expect(typingSuccess3, "Should type part3 text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // We now have "Part1 Part3" in the document

    // 4. Get text content for verification
    let initialText = try await textEditHelper.app.getText()
    let expectedInitialText = "Part1 Part3"
    #expect(
      initialText?.contains(expectedInitialText) ?? false,
      "Document should initially contain 'Part1 Part3'",
    )

    // 5. Now position the cursor right after "Part1" by clicking at that position
    // First, get the text area element again to ensure we have current coordinates
    let freshTextArea = try await textEditHelper.app.getTextArea()
    guard let textArea = freshTextArea else {
      #expect(Bool(false), "Could not find text area for positioning cursor")
      return
    }

    // Calculate a position just after "Part1" - this will be slightly to the right of the start
    // of the text, enough to be after the first word but before the second
    let textAreaFrame = textArea.frame

    // Position approximately after "Part1" - about 20% of the way across
    // For a real test we would want to calculate this more precisely based on font metrics
    let posX = textAreaFrame.origin.x + (textAreaFrame.size.width * 0.2)
    let posY = textAreaFrame.origin.y + (textAreaFrame.size.height * 0.5)  // Middle of text area


    // Click at the calculated position to place cursor after "Part1"
    _ = try await textEditHelper.toolChain.clickAtPosition(
      position: CGPoint(x: posX, y: posY),
    )
    try await Task.sleep(for: .milliseconds(1000))

    // 6. Now type the inserted text - using the new typeText that doesn't clear
    let part2 = " Part2"
    let typingSuccess2 = try await textEditHelper.typeText(part2)
    #expect(typingSuccess2, "Should type part2 text successfully")
    try await Task.sleep(for: .milliseconds(1000))

    // 7. Verify the final text has all three parts in the correct order
    let finalText = try await textEditHelper.app.getText()
    let expectedFinalText = "Part1 Part2 Part3"

    #expect(
      finalText?.contains(expectedFinalText) ?? false,
      "Document should contain all three parts in correct order: 'Part1 Part2 Part3'",
    )
    
    try await tearDown()
  }

  /// Test attempting to click on a non-existent element
  @Test("Click Non-Existent Element")
  mutating func testClickNonExistentElement() async throws {
    try await setUp()

    // Ensure Calculator is active before interactions
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Use a clearly non-existent element ID
    let nonExistentId = "macos://ui/AXApplication/AXWindow/AXButton[@AXDescription=\"NonExistentButton\"]"

    do {
      _ = try await calculatorHelper.toolChain.clickElement(
        elementPath: nonExistentId,
        bundleId: calculatorHelper.app.bundleId,
      )
      #expect(Bool(false), "Should throw an error for non-existent element")
    } catch {
      // Success - we expect an error
      let errorMessage = error.localizedDescription.lowercased()
      #expect(
        errorMessage.contains("not found") || errorMessage.contains("no element")
          || errorMessage.contains("invalid") || errorMessage.contains("unable to find"),
        "Error should indicate element not found: \(errorMessage)",
      )
    }

    // Test direct handler call with non-existent element
    do {
      let nonExistentParams: [String: Value] = [
        "action": .string("click"),
        "id": .string(nonExistentId),
        "appBundleId": .string(calculatorHelper.app.bundleId),
      ]

      _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(nonExistentParams)
      #expect(Bool(false), "Handler should throw an error for non-existent element")
    } catch {
      // Expected error - success
      let errorMessage = error.localizedDescription.lowercased()
      #expect(
        errorMessage.contains("not found") || errorMessage.contains("no element")
          || errorMessage.contains("invalid"),
        "Error should indicate element not found",
      )
    }
    
    try await tearDown()
  }

  /// Test invalid action parameter
  @Test("Invalid Action Parameter")
  mutating func testInvalidAction() async throws {
    try await setUp()

    // Ensure Calculator is active before interactions
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorHelper.app.bundleId)
      .first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))

    // Test with an invalid action
    do {
      let invalidParams: [String: Value] = [
        "action": .string("invalid_action"),
        "id": .string("macos://ui/AXApplication/AXButton"),
      ]

      _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(invalidParams)
      #expect(Bool(false), "Should throw an error for invalid action")
    } catch {
      // Expected error - success
      let errorMessage = error.localizedDescription.lowercased()
      #expect(
        errorMessage.contains("invalid action") || errorMessage.contains("unknown action"),
        "Error should indicate invalid action: \(errorMessage)",
      )
    }

    // Test with missing action
    do {
      let invalidParams: [String: Value] = [
        "id": .string("macos://ui/AXApplication/AXButton")
        // Missing action
      ]

      _ = try await calculatorHelper.toolChain.uiInteractionTool.handler(invalidParams)
      #expect(Bool(false), "Should throw an error for missing action")
    } catch {
      // Expected error - success
      let errorMessage = error.localizedDescription.lowercased()
      #expect(
        errorMessage.contains("action") || errorMessage.contains("required"),
        "Error should indicate missing action: \(errorMessage)",
      )
    }
    
    try await tearDown()
  }

  // MARK: - Helper Methods

  /// Save a screenshot of the UI state for debugging
  private func saveDebugScreenshot(appBundleId: String, testName: String) async throws {
    // Create parameters for the screenshot tool
    let params: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string(appBundleId),
    ]

    do {
      // Take the screenshot
      let result = try await calculatorHelper.toolChain.screenshotTool.handler(params)

      // Save the screenshot with a meaningful name
      if let content = result.first, case .image(let data, _, _) = content {
        let decodedData = Data(base64Encoded: data)!

        // Save screenshots to a temporary directory so the path works on any machine
        let outputDir = FileManager.default.temporaryDirectory
          .appendingPathComponent("macmcp-test-screenshots", isDirectory: true)
          .path
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "ui_interaction_\(testName)_\(timestamp).png"
        let fileURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)

        do {
          // Create the directory if it doesn't exist
          try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir),
            withIntermediateDirectories: true,
          )

          try decodedData.write(to: fileURL)
        } catch {
          print("Error saving debug screenshot: \(error.localizedDescription)")
        }
      }
    } catch {
      print("Error taking debug screenshot: \(error.localizedDescription)")
    }
  }
}
