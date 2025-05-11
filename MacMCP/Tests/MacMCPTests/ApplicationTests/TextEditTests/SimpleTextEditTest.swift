// ABOUTME: This file contains simple tests for the TextEdit app.
// ABOUTME: It verifies basic text editing capabilities through the MCP interface.

import XCTest
import Foundation
import MCP
import AppKit
@testable import MacMCP

/// Simple test cases for the TextEdit app using the TextEditTestHelper
@MainActor
final class SimpleTextEditTest: XCTestCase {
    // Test helper for TextEdit interactions
    private var helper: TextEditTestHelper!
    
    // Only initialize in setUp (async context), not in setUpWithError
    override func setUp() async throws {
        // Get shared helper
        helper = TextEditTestHelper.shared()

        // Ensure the app is running
        let appRunning = try await helper.ensureAppIsRunning()
        XCTAssertTrue(appRunning, "TextEdit should be running")

        // Reset app state for a clean test environment
        try await helper.resetAppState()
    }
    
    /// Test basic text typing
    func testBasicTextTyping() async throws {
        // Type some text
        let testText = "Hello, TextEdit!"
        let typingSuccess = try await helper.typeText(testText)
        XCTAssertTrue(typingSuccess, "Should be able to type text")
        
        // Verify text appears in the document
        try await helper.assertDocumentContainsText(testText, 
            message: "Document should contain the typed text")
    }
    
    /// Test basic text formatting
    func testBasicFormatting() async throws {
        // Type some text and select it
        let testText = "Formatted Text"
        let typingSuccess = try await helper.typeText(testText)
        XCTAssertTrue(typingSuccess, "Should be able to type text")
        
        // Select all text
        let selectionSuccess = try await helper.selectText(startPos: 0, length: testText.count)
        XCTAssertTrue(selectionSuccess, "Should be able to select text")
        
        // Apply bold formatting
        let boldSuccess = try await helper.toggleBold()
        XCTAssertTrue(boldSuccess, "Should be able to apply bold formatting")
        
        // Check document text is still there
        try await helper.assertDocumentContainsText(testText, 
            message: "Document should still contain the text after formatting")
    }
    
    /// Test combined formatting using performTextOperation
    func testCombinedTextOperations() async throws {
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
        
        XCTAssertTrue(success, "Text operation should complete successfully with correct verification")
    }
}