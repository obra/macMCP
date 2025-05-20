// ABOUTME: TextEditFormattingTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// Test case for MCP's ability to interact with the TextEdit app
@Suite(.serialized)
struct TextEditFormattingTest {
  // Test helper for TextEdit interactions
  private var helper: TextEditTestHelper!

  // Shared setup method
  private mutating func setUp() async throws {
    // Get shared helper
    helper = await TextEditTestHelper.shared()

    // Ensure app is running and reset state
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning)
    try await helper.resetAppState()
  }
  
  // Shared teardown method
  private mutating func tearDown() async throws {
    if helper != nil {
     _ = try await helper.closeWindowAndDiscardChanges()
    }
  }

  /// Test that we can type text in TextEdit using keyboard commands
  @Test("Type Text in TextEdit")
  mutating func testTypeText() async throws {
    try await setUp()
    
    // Type text in TextEdit using keyboard commands
    let text = "Hello world"
    let typeSuccess = try await helper.typeText(text)
    #expect(typeSuccess)

    // Take a pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Verify text appears in the document
    try await helper.assertDocumentContainsText(text)
    
    try await tearDown()
  }

  /// Test formatting text in TextEdit - bold, italic, newline, etc.
  @Test("Text Formatting in TextEdit")
  mutating func testTextFormatting() async throws {
    try await setUp()
    
    // Type "Hello world" in TextEdit
    let text = "Hello world"
    let typeSuccess = try await helper.typeText(text)
    #expect(typeSuccess)

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Select the first word ("Hello")
    let selectSuccess = try await helper.selectText(startPos: 0, length: 5)
    #expect(selectSuccess)

    // Apply bold formatting to the first word
    let boldSuccess = try await helper.toggleBold()
    #expect(boldSuccess)

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Verify text still exists in the document
    try await helper.assertDocumentContainsText(text)
    
    try await tearDown()
  }

  /// Test more advanced formatting and saving/reopening
  @Test("Save and Reopen TextEdit Document")
  mutating func testSaveAndReopen() async throws {
    try await setUp()
    
    // Type "Formatting Test" in TextEdit
    let text = "Formatting Test"
    let typeSuccess = try await helper.typeText(text)
    #expect(typeSuccess)

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Select all text
    let selectAll = try await helper.selectText(startPos: 0, length: text.count)
    #expect(selectAll)

    // Make text larger using the Format menu
    let largerSuccess = try await helper.makeTextLarger()
    #expect(largerSuccess)

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Save the document to /tmp
    let savePath = "/tmp/textedit_test.rtf"
    let (_, saveSuccess) = try await helper.saveDocument(to: savePath)
    #expect(saveSuccess)

    // Get the current text for later comparison
    let documentText = try await helper.app.getText()
    #expect(documentText != nil)

    // Force terminate the app
    for app in NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit") {
      _ = app.forceTerminate()
    }

    // Wait for the app to close
    try await Task.sleep(for: .milliseconds(2000))

    // Relaunch TextEdit
    let reopenSuccess = try await helper.ensureAppIsRunning()
    #expect(reopenSuccess)

    // Wait for the app to fully initialize
    try await Task.sleep(for: .milliseconds(2000))

    // Open the saved document
    let openSuccess = try await helper.openDocument(from: savePath)
    #expect(openSuccess)

    // Brief pause to allow document to load
    try await Task.sleep(for: .milliseconds(2000))

    // Verify the reopened document contains the correct text
    try await helper.assertDocumentContainsText(text)
    
    try await tearDown()
  }
}