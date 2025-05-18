// ABOUTME: ElementPathFilteringTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP
import XCTest

@testable import MacMCP

final class ElementPathFilteringTests: XCTestCase {
  private var accessibilityService: AccessibilityService!
  private var interfaceExplorerTool: InterfaceExplorerTool!
  private var uiInteractionService: UIInteractionService!
  private var calculatorBundleId = "com.apple.calculator"
  private var app: NSRunningApplication?

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Create the services
    accessibilityService = AccessibilityService()
    uiInteractionService = UIInteractionService(accessibilityService: accessibilityService)
    interfaceExplorerTool = InterfaceExplorerTool(accessibilityService: accessibilityService)

    // Launch Calculator app using synchronous approach
    app = launchCalculatorSync()
    XCTAssertNotNil(app, "Failed to launch Calculator app")

    // Give time for app to fully load
    Thread.sleep(forTimeInterval: 1.0)
  }

  override func tearDownWithError() throws {
    // Terminate Calculator
    app?.terminate()
    app = nil

    // Wait for termination
    Thread.sleep(forTimeInterval: 1.0)

    try super.tearDownWithError()
  }

  // Helper method that wraps the MainActor-isolated method in a synchronous call
  private func launchCalculatorSync() -> NSRunningApplication? {
    // Use a dispatch semaphore to wait for the async operation to complete
    let semaphore = DispatchSemaphore(value: 0)
    var result: NSRunningApplication?
    
    // Capture the bundleId to avoid self reference in the closure
    let bundleId = calculatorBundleId
    
    // Launch on the main thread which is where MainActor runs
    DispatchQueue.main.async {
      Task { @MainActor in
        // Launch using the calculator helper on the main actor
        let calcHelper = CalculatorTestHelper.sharedHelper()
        do {
          _ = try await calcHelper.ensureAppIsRunning(forceRelaunch: true)
          result = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
        } catch {
          result = nil
        }
        semaphore.signal()
      }
    }
    
    // Wait for the async operation to complete (with timeout)
    _ = semaphore.wait(timeout: .now() + 10)
    return result
  }
  
  // The actual MainActor-isolated method to launch Calculator
  @MainActor private func launchCalculator() async throws -> NSRunningApplication? {
    // Get the shared helper
    let calcHelper = CalculatorTestHelper.sharedHelper()
    
    // Launch calculator via the calculator helper
    _ = try await calcHelper.ensureAppIsRunning(forceRelaunch: true)
    
    // Return the running app instance if we can find it
    return NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first
  }

  // Helper to verify a path is fully qualified
  private func verifyFullyQualifiedPath(_ path: String?) {
    guard let path else {
      XCTFail("Path is nil")
      return
    }
    XCTAssertTrue(path.hasPrefix("ui://"), "Path doesn't start with ui://: \(path)")
    XCTAssertTrue(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
    XCTAssertTrue(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
    let separatorCount = path.components(separatedBy: "/").count - 1
    XCTAssertGreaterThanOrEqual(separatorCount, 1, "Path doesn't have enough segments: \(path)")
  }

  // Helper to run a request, verify, and always attempt a click
  private func runRequestAndVerify(
    _ request: [String: Value],
    extraAssertions: ((EnhancedElementDescriptor) -> Void)? = nil,
  ) async throws {
    let response = try await interfaceExplorerTool.handler(request)
    guard case .text(let jsonString) = response.first else {
      XCTFail("Failed to get valid response from tool")
      return
    }
    let jsonData = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
    XCTAssertFalse(descriptors.isEmpty, "No elements returned")
    for descriptor in descriptors {
      verifyFullyQualifiedPath(descriptor.path)
      extraAssertions?(descriptor)
      print("Element path: \(descriptor.path ?? "nil")")
      if let children = descriptor.children {
        for child in children {
          verifyFullyQualifiedPath(child.path)
        }
      }
    }
    // Always attempt a click if any element is found
    if let first = descriptors.first, let path = first.path {
      try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
    }
  }

  /*
   func testNoFilteringFullPaths() async throws {
       let request: [String: Value] = [
           "scope": .string("application"),
           "bundleId": .string(calculatorBundleId),
           "maxDepth": .int(10)
       ]
       try await runRequestAndVerify(request)
   }
   */
  func testRoleFilteringFullPaths() async throws {
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object([
        "role": .string("AXButton"),
        "description": .string("1"),
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
    }
  }

  func testElementTypeFilteringFullPaths() async throws {
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]),
      "filter": .object([
        "description": .string("2")
      ]),
    ]
    try await runRequestAndVerify(request)
  }

  func testAttributeFilteringFullPaths() async throws {
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "filter": .object([
        "description": .string("3")
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertTrue(
        descriptor.description?.contains("3") ?? false, "Element doesn't match filter criteria")
    }
  }

  func testCombinedFilteringFullPaths() async throws {
    let request: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string(calculatorBundleId),
      "maxDepth": .int(10),
      "elementTypes": .array([.string("button")]),
      "filter": .object([
        "description": .string("4")
      ]),
    ]
    try await runRequestAndVerify(request) { descriptor in
      XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
      XCTAssertTrue(
        descriptor.description?.contains("4") ?? false, "Element doesn't match description criteria"
      )
    }
  }
}
