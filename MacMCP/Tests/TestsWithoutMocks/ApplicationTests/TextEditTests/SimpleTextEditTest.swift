// ABOUTME: SimpleTextEditTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// Simple test cases for the TextEdit app using the TextEditTestHelper
@Suite(.serialized) struct SimpleTextEditTest {
  // Test helper for TextEdit interactions
  private var helper: TextEditTestHelper!

  @Test("Test basic text typing") mutating func testBasicTextTyping() async throws {
    // Setup
    helper = await TextEditTestHelper.shared()

    // Ensure the app is running
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning)

    // Reset app state for a clean test environment
    try await helper.resetAppState()
    // Type some text
    let testText = "Hello, TextEdit!"
    let typingSuccess = try await helper.typeText(testText)
    #expect(typingSuccess)

    // Verify text appears in the document
    try await helper.assertDocumentContainsText(testText)
    // Cleanup
    _ = try await helper.closeWindowAndDiscardChanges()
  }

  @Test("Test basic formatting") mutating func testBasicFormatting() async throws {
    // Setup
    helper = await TextEditTestHelper.shared()

    // Ensure the app is running
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning)

    // Reset app state for a clean test environment
    try await helper.resetAppState()
    // Type some text and select it
    let testText = "Formatted Text"
    let typingSuccess = try await helper.typeText(testText)
    #expect(typingSuccess)

    // Select all text
    let selectionSuccess = try await helper.selectText(startPos: 0, length: testText.count)
    #expect(selectionSuccess, "Should be able to select text")

    // Apply bold formatting
    let boldSuccess = try await helper.toggleBold()
    #expect(boldSuccess, "Should be able to apply bold formatting")

    // Check document text is still there
    try await helper.assertDocumentContainsText(
      testText,
      message: "Document should still contain the text after formatting"
    )
    // Cleanup
    _ = try await helper.closeWindowAndDiscardChanges()
  }

  @Test("Test combined text operations") mutating func testCombinedTextOperations() async throws {
    // Setup
    helper = await TextEditTestHelper.shared()

    // Ensure the app is running
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning)

    // Reset app state for a clean test environment
    try await helper.resetAppState()
    let testText = "Testing Operations"

    // Use the performTextOperation helper method to test a sequence of operations
    let success = try await helper.performTextOperation(
      operation: {
        // Type text
        _ = try await self.helper.typeText(testText)

        // Select text
        _ = try await self.helper.selectText(startPos: 0, length: testText.count)

        // Make text larger
        return try await self.helper.makeTextLarger()
      },
      verificationText: testText
    )

    #expect(success)
    // Cleanup
    _ = try await helper.closeWindowAndDiscardChanges()
  }
}
