// ABOUTME: This file demonstrates very basic direct testing of MacMCP tools.
// ABOUTME: It shows how to use tools without the MCP protocol layer.

import XCTest
import Logging
import MCP
@testable import MacMCP

/// Simple direct testing of tools without protocol layer
final class StandaloneDirectToolTest: XCTestCase {
    
    func testUIStateTool() async throws {
        // Create services
        let logger = Logger(label: "test.ui_state")
        let accessibilityService = AccessibilityService(logger: logger)
        
        // Create UI state tool
        let tool = UIStateTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        // Get system UI state with depth=2
        let params: [String: Value] = [
            "scope": .string("system"),
            "maxDepth": .int(2)
        ]
        
        // Print verbose debugging
        print("RUNNING STANDALONE DIRECT TOOL TEST")
        print("Params: \(params)")
        
        // Call handler directly (bypassing MCP protocol)
        let result = try await tool.handler(params)
        
        // Verify we got some results
        print("Result count: \(result.count)")
        print("Result types: \(result.map { String(describing: $0) })")
        
        XCTAssertFalse(result.isEmpty, "Should return non-empty results")
        
        if let first = result.first {
            print("First result type: \(type(of: first))")
            
            if case .text(let json) = first {
                // Print the full JSON for inspection
                print("FULL JSON OUTPUT:")
                print(json)
                
                // Verify we got system-wide accessibility data
                XCTAssertTrue(json.contains("AXSystemWide"), "Result should contain AXSystemWide role")
            } else {
                print("Result is not text type: \(first)")
                XCTFail("Expected text result")
            }
        } else {
            XCTFail("No results returned")
        }
    }
}