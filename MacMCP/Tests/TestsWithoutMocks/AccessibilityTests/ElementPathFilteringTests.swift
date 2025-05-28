// ABOUTME: ElementPathFilteringTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct ElementPathFilteringTests {
  private let calculatorBundleId = "com.apple.calculator"

  /// Ensure Calculator is running and ready for tests
  @MainActor private func setUp() async throws {
    let helper = CalculatorTestHelper.sharedHelper()
    let isReady = try await helper.ensureAppIsRunning(forceRelaunch: false)
    #expect(isReady, "Calculator should be ready for testing")
  }

  /// Reset Calculator state after tests
  @MainActor private func tearDown() async {
    let helper = CalculatorTestHelper.sharedHelper()
    await helper.resetAppState()
  }

  /// Helper to verify a path is fully qualified
  private func verifyFullyQualifiedPath(_ path: String?) {
    guard let path else {
      #expect(Bool(false), "Path is nil")
      return
    }
    #expect(path.hasPrefix("macos://ui/"), "Path doesn't start with macos://ui/: \(path)")
    #expect(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
    #expect(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
    let separatorCount = path.components(separatedBy: "/").count - 1
    #expect(separatorCount >= 1, "Path doesn't have enough segments: \(path)")
  }

  /// Helper to run a request and verify results using the shared helper
  @MainActor private func runRequestAndVerify(
    _ request: [String: Value],
    extraAssertions: ((EnhancedElementDescriptor) -> Void)? = nil
  ) async throws {
    let helper = CalculatorTestHelper.sharedHelper()
    let response = try await helper.toolChain.interfaceExplorerTool.handler(request)
    guard case .text(let jsonString) = response.first else {
      #expect(Bool(false), "Failed to get valid response from tool")
      return
    }
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    do {
      let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
      #expect(!descriptors.isEmpty, "No elements returned for request")
      for descriptor in descriptors {
        verifyFullyQualifiedPath(descriptor.id)
        extraAssertions?(descriptor)
        if let children = descriptor.children {
          for child in children { verifyFullyQualifiedPath(child.id) }
        }
      }
      // Verify we can find the button using the model interface
      if let first = descriptors.first, let description = first.description {
        // Try to find the button through the model
        let foundButton = try await helper.app.findButton(description)
        #expect(
          foundButton != nil, "Should be able to find button with description '\(description)'")
      }
    } catch { #expect(Bool(false), "Failed to decode response JSON: \(error)") }
  }
  // MARK: - Test Cases

  @Test("Role filtering with full paths") func testRoleFilteringFullPaths() async throws {
    try await setUp()
    let request: [String: Value] = [
      "scope": .string("application"), "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object(["role": .string("AXButton"), "description": .string("1")]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      #expect(descriptor.role == "AXButton", "Non-button element returned")
    }
    await tearDown()
  }

  @Test("Element type filtering with full paths") func testElementTypeFilteringFullPaths()
    async throws
  {
    try await setUp()
    let request: [String: Value] = [
      "scope": .string("application"), "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]), "filter": .object(["description": .string("2")]),
    ]
    try await runRequestAndVerify(request)
    await tearDown()
  }

  @Test("Attribute filtering with full paths") func testAttributeFilteringFullPaths() async throws {
    try await setUp()
    let request: [String: Value] = [
      "scope": .string("application"), "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object(["description": .string("3")]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      #expect(
        descriptor.description?.contains("3") ?? false, "Element doesn't match filter criteria")
    }
    await tearDown()
  }

  @Test("Combined filtering with full paths") func testCombinedFilteringFullPaths() async throws {
    try await setUp()
    let request: [String: Value] = [
      "scope": .string("application"), "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]), "filter": .object(["description": .string("4")]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      #expect(descriptor.role == "AXButton", "Non-button element returned")
      #expect(
        descriptor.description?.contains("4") ?? false, "Element doesn't match description criteria"
      )
    }
    await tearDown()
  }
}
