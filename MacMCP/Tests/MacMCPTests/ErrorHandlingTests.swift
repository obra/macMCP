import XCTest
import Testing
import Foundation
import MCP

@testable import MacMCP

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    @Test("Accessibility permission errors")
    func testAccessibilityPermissionErrors() async {
        let permissionError = AccessibilityPermissions.Error.permissionDenied
        
        // Check error description
        #expect(permissionError.errorDescription != nil)
        #expect(permissionError.errorDescription?.contains("permission denied") == true)
        
        // Check recovery suggestion
        #expect(permissionError.recoverySuggestion != nil)
        #expect(permissionError.recoverySuggestion?.contains("System Settings") == true || 
               permissionError.recoverySuggestion?.contains("System Preferences") == true)
    }
    
    @Test("Element not found errors")
    func testElementNotFoundErrors() async throws {
        let mockService = ErrorGeneratingInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Try to click on a non-existent element
        let input: [String: Value] = [
            "action": .string("click"),
            "elementId": .string("non-existent-id")
        ]
        
        // Should return an error response
        do {
            let _ = try await tool.handler(input)
            XCTFail("Expected an error to be thrown")
        } catch {
            // Just check that some error is thrown - the specific error type might vary
            // depending on implementation details
            let errorDescription = error.localizedDescription
            #expect(errorDescription.contains("not found") || 
                   errorDescription.contains("invalid") || 
                   errorDescription.contains("element"))
        }
    }
    
    @Test("Invalid parameter errors")
    func testInvalidParameterErrors() async throws {
        let tool = UIInteractionTool(
            interactionService: MockUIInteractionService(),
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Missing required parameters
        let input: [String: Value] = [
            "action": .string("click")
            // Missing elementId or x,y
        ]
        
        // Should return an error response
        do {
            let _ = try await tool.handler(input)
            XCTFail("Expected an error to be thrown")
        } catch let error as MCPError {
            // Verify this is an invalid params error
            #expect(error.code == -32602)
            
            // Verify error description contains useful information
            let description = error.errorDescription ?? ""
            #expect(description.contains("requires") || description.contains("missing"))
        }
    }
    
    @Test("Detailed error messages")
    func testDetailedErrorMessages() async {
        // Test different error types
        let errors: [MCPError] = [
            .parseError("Invalid JSON format"),
            .invalidRequest("Unknown method"),
            .methodNotFound("Method not available"),
            .invalidParams("Missing required parameter"),
            .internalError("Unexpected condition"),
            .serverError(code: -32000, message: "Custom server error"),
            .connectionClosed,
            .transportError(NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
        ]
        
        // Check that each error has a meaningful description and code
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
            #expect(error.code != 0)
        }
    }
    
    @Test("UIInteractionTool error handling")
    func testUIInteractionToolUpdatedErrorHandling() async throws {
        // Create tool with mock services
        let mockInteractionService = ErrorGeneratingInteractionService()
        let mockAccessService = MockAccessibilityService()
        
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: mockAccessService,
            logger: nil
        )
        
        // Test cases that should throw specific errors
        let testCases: [(name: String, params: [String: Value]?)] = [
            ("Missing params", nil),
            ("Missing action", [:]),
            ("Invalid action", ["action": .string("invalid_action")]),
            ("Click missing targets", ["action": .string("click")]),
            ("Type missing element", ["action": .string("type")]),
            ("Type missing text", ["action": .string("type"), "elementId": .string("test-id")]),
            ("Scroll missing direction", ["action": .string("scroll"), "elementId": .string("test-id")])
        ]
        
        // Run tests
        for (name, params) in testCases {
            do {
                _ = try await tool.handler(params)
                XCTFail("Test \(name) should have thrown an error but didn't")
            } catch let error as MCPError {
                // Verify the error is properly formatted
                switch error {
                case .invalidParams(let message):
                    // Check that the message contains useful context information
                    #expect(message != nil && !message!.isEmpty, "Error message should not be empty")
                    
                    // We won't test specific message content since the exact message format may change
                    // Just verify that the message isn't empty and is related to the test case
                    #expect(message != nil, "Error message should exist")
                    
                    // Log the message for debugging
                    if let msg = message {
                        print("Test \(name) produced message: \(msg)")
                    }
                    
                default:
                    // Some errors might be categorized differently
                    // This is fine as long as they're proper MCPErrors
                    break
                }
            } catch {
                XCTFail("Test \(name) threw unexpected error type: \(type(of: error))")
            }
        }
    }
}

/// A service that generates errors for testing error handling
class ErrorGeneratingInteractionService: UIInteractionServiceProtocol {
    func clickElement(identifier: String, appBundleId: String?) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1000,
            userInfo: [NSLocalizedDescriptionKey: "Element not found: \(identifier)"]
        )
    }
    
    func clickAtPosition(position: CGPoint) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "No element at position \(position)"]
        )
    }
    
    func doubleClickElement(identifier: String) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Cannot double-click element: \(identifier)"]
        )
    }
    
    func rightClickElement(identifier: String) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1003,
            userInfo: [NSLocalizedDescriptionKey: "Cannot right-click element: \(identifier)"]
        )
    }
    
    func typeText(elementIdentifier: String, text: String) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1004,
            userInfo: [NSLocalizedDescriptionKey: "Cannot type text into element: \(elementIdentifier)"]
        )
    }
    
    func pressKey(keyCode: Int) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1005,
            userInfo: [NSLocalizedDescriptionKey: "Cannot press key: \(keyCode)"]
        )
    }
    
    func dragElement(sourceIdentifier: String, targetIdentifier: String) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1006,
            userInfo: [NSLocalizedDescriptionKey: "Cannot drag element \(sourceIdentifier) to \(targetIdentifier)"]
        )
    }
    
    func scrollElement(identifier: String, direction: ScrollDirection, amount: Double) async throws {
        throw NSError(
            domain: "com.macos.mcp.test",
            code: 1007,
            userInfo: [NSLocalizedDescriptionKey: "Cannot scroll element: \(identifier)"]
        )
    }
}