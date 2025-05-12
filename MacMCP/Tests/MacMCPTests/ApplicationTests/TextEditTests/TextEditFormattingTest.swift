// ABOUTME: This file tests the accessibility interactions with TextEdit app through MCP.
// ABOUTME: It verifies the MCP tools can interact with text editing, formatting, saving and reopening files.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

/// Test case for MCP's ability to interact with the TextEdit app
@MainActor
final class TextEditFormattingTest: XCTestCase {
    // Test helper for TextEdit interactions
    private var helper: TextEditTestHelper!

    override func setUp() async throws {
        // Get shared helper
        helper = TextEditTestHelper.shared()

        // Ensure app is running and reset state
        let appRunning = try await helper.ensureAppIsRunning()
        XCTAssertTrue(appRunning, "TextEdit should be running")
        try await helper.resetAppState()
    }
    
    /// Test that we can type text in TextEdit using keyboard commands
    func testTypeText() async throws {
        // Type text in TextEdit using keyboard commands
        let text = "Hello world"
        let typeSuccess = try await helper.typeText(text)
        XCTAssertTrue(typeSuccess, "Should be able to type text")

        // Take a pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify text appears in the document
        try await helper.assertDocumentContainsText(text,
            message: "Document should contain the typed text")
    }

    /// Test formatting text in TextEdit - bold, italic, newline, etc.
    func testTextFormatting() async throws {
        // Type "Hello world" in TextEdit
        let text = "Hello world"
        let typeSuccess = try await helper.typeText(text)
        XCTAssertTrue(typeSuccess, "Should be able to type text")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Select the first word ("Hello")
        let selectSuccess = try await helper.selectText(startPos: 0, length: 5)
        XCTAssertTrue(selectSuccess, "Should be able to select text")

        // Apply bold formatting to the first word
        let boldSuccess = try await helper.toggleBold()
        XCTAssertTrue(boldSuccess, "Should be able to toggle bold")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Verify text still exists in the document
        try await helper.assertDocumentContainsText(text,
            message: "Document should still contain the text after formatting")
    }

    /// Test more advanced formatting and saving/reopening
    func testSaveAndReopen() async throws {
        // Type "Formatting Test" in TextEdit
        let text = "Formatting Test"
        let typeSuccess = try await helper.typeText(text)
        XCTAssertTrue(typeSuccess, "Should be able to type text")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Select all text
        let selectAll = try await helper.selectText(startPos: 0, length: text.count)
        XCTAssertTrue(selectAll, "Should be able to select all text")

        // Make text larger using the Format menu
        let largerSuccess = try await helper.makeTextLarger()
        XCTAssertTrue(largerSuccess, "Should be able to make text larger")

        // Brief pause to allow UI to update
        try await Task.sleep(for: .milliseconds(500))

        // Save the document to /tmp
        let savePath = "/tmp/textedit_test.rtf"
        let (_, saveSuccess) = try await helper.saveDocument(to: savePath)
        XCTAssertTrue(saveSuccess, "Should be able to save the document")

        // Get the current text for later comparison
        let documentText = try await helper.app.getText()
        XCTAssertNotNil(documentText, "Should be able to get document text")

        // Force terminate the app
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").forEach { app in
            _ = app.forceTerminate()
        }

        // Wait for the app to close
        try await Task.sleep(for: .milliseconds(2000))

        // Relaunch TextEdit
        let reopenSuccess = try await helper.ensureAppIsRunning()
        XCTAssertTrue(reopenSuccess, "Should be able to relaunch TextEdit")

        // Wait for the app to fully initialize
        try await Task.sleep(for: .milliseconds(2000))

        // Open the saved document
        let openSuccess = try await helper.openDocument(from: savePath)
        XCTAssertTrue(openSuccess, "Should be able to open the document")

        // Brief pause to allow document to load
        try await Task.sleep(for: .milliseconds(2000))

        // Verify the reopened document contains the correct text
        try await helper.assertDocumentContainsText(text,
            message: "Reopened document should contain the original text")
    }
}