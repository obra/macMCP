// ABOUTME: ErrorHandlingTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import Testing
import XCTest

@testable import MacMCP

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
  @Test("Accessibility permission errors")
  func accessibilityPermissionErrors() async {
    let permissionError = AccessibilityPermissions.Error.permissionDenied

    // Check error description
    #expect(permissionError.errorDescription != nil)
    #expect(permissionError.errorDescription?.contains("permission denied") == true)

    // Check recovery suggestion
    #expect(permissionError.recoverySuggestion != nil)
    #expect(
      permissionError.recoverySuggestion?.contains("System Settings") == true
        || permissionError.recoverySuggestion?.contains("System Preferences") == true,
    )
  }

  @Test("Detailed error messages")
  func detailedErrorMessages() async {
    // Test different error types
    let errors: [MCPError] = [
      .parseError("Invalid JSON format"),
      .invalidRequest("Unknown method"),
      .methodNotFound("Method not available"),
      .invalidParams("Missing required parameter"),
      .internalError("Unexpected condition"),
      .serverError(code: -32000, message: "Custom server error"),
      .connectionClosed,
      .transportError(
        NSError(
          domain: "test",
          code: 123,
          userInfo: [NSLocalizedDescriptionKey: "Connection timeout"],
        )),
    ]

    // Check that each error has a meaningful description and code
    for error in errors {
      #expect(error.errorDescription != nil)
      #expect(error.errorDescription?.isEmpty == false)
      #expect(error.code != 0)
    }
  }

  @Test("UIInteractionTool parameter validation")
  func uIInteractionToolParameterValidation() async throws {
    // Create a real tool instance with real services
    let logger = Logger(label: "test.error-handling")
    let accessibilityService = AccessibilityService(logger: logger)
    let interactionService = UIInteractionService(
      accessibilityService: accessibilityService,
      logger: logger,
    )

    let tool = UIInteractionTool(
      interactionService: interactionService,
      accessibilityService: accessibilityService,
      logger: logger,
    )

    // Test invalid parameter combinations that should result in errors
    let testCases: [(name: String, params: [String: Value]?)] = [
      ("Missing params", nil),
      ("Missing action", [:]),
      ("Invalid action", ["action": .string("invalid_action")]),
      ("Click missing targets", ["action": .string("click")]),
      ("Scroll missing element path", ["action": .string("scroll")]),
      (
        "Scroll missing direction",
        [
          "action": .string("scroll"),
          "elementPath": .string(
            "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow"),
        ]
      ),
      ("Drag missing source path", ["action": .string("drag")]),
      (
        "Drag missing target path",
        [
          "action": .string("drag"),
          "elementPath": .string(
            "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow"),
        ]
      ),
    ]

    // Run tests - these should fail because of parameter validation, not because of mocks
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
          // Just verify that the message isn't empty
          #expect(message != nil, "Error message should exist")

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
