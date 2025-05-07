// ABOUTME: This file contains tests for the ToolInvoker component.
// ABOUTME: It verifies that tools can be invoked directly without the MCP protocol layer.

import XCTest
import Logging
import MCP
@testable import MacMCP

final class ToolInvokerTests: XCTestCase {
    
    func testInvokeUIStateTool() async throws {
        print("========== STARTING INCREMENTAL TEST: testInvokeUIStateTool ==========")
        
        // Create services with test logger
        let (logger, _) = Logger.testLogger(label: "test.tool_invoker")
        let accessibilityService = AccessibilityService(logger: logger)
        
        // Create UI state tool
        let tool = UIStateTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        // Basic parameters to get system UI state with limited depth
        let params: [String: Value] = [
            "scope": .string("system"),
            "maxDepth": .int(2)
        ]
        
        // Print info about test
        print("Invoking UIStateTool directly with: \(params)")
        
        // Try direct invoke first
        let result = try await ToolInvoker.invoke(tool: tool, parameters: params)
        
        // Verify results
        XCTAssertFalse(result.isEmpty, "Result should not be empty")
        
        // Check if we got text content
        let textContent = result.getTextContent()
        XCTAssertNotNil(textContent, "Should get text content")
        
        if let text = textContent {
            print("Got text content of length: \(text.count)")
            XCTAssertTrue(text.count > 0, "Text content should not be empty")
            XCTAssertTrue(text.contains("AXSystemWide"), "Text should contain AXSystemWide")
        }
        
        // Now try the helper method
        print("Using getUIState helper method")
        do {
            let uiStateResult = try await ToolInvoker.getUIState(
                tool: tool,
                scope: "system",
                maxDepth: 2
            )
            
            // Verify the UIStateResult
            XCTAssertFalse(uiStateResult.elements.isEmpty, "Elements should not be empty")
            
            // Check if we can find an element with AXSystemWide role
            let systemElement = uiStateResult.findElement(matching: ElementCriteria(role: "AXSystemWide"))
            XCTAssertNotNil(systemElement, "Should find AXSystemWide element")
            
            print("Found system element with role: \(systemElement?.role ?? "nil")")
            print("System element has \(systemElement?.children.count ?? 0) children")
            
            // Use the verifier
            let verifierResult = UIStateVerifier.verifyElementExists(
                in: uiStateResult,
                matching: ElementCriteria(role: "AXSystemWide")
            )
            XCTAssertTrue(verifierResult, "Verifier should succeed")
            
            // Test completes successfully
            print("========== INCREMENTAL TEST COMPLETED SUCCESSFULLY ==========")
        } catch {
            print("ERROR in getUIState: \(error)")
            XCTFail("Error getting UI state: \(error)")
        }
    }
}