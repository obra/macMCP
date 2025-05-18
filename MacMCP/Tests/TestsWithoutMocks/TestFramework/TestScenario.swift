// ABOUTME: TestScenario.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import XCTest

@testable import MacMCP

/// Protocol defining the structure of test scenarios for MacMCP tools
public protocol TestScenario {
  /// Prepare the environment for the test
  /// This typically includes launching applications and verifying initial state
  func setup() async throws

  /// Run the test scenario
  /// This is where the main test assertions are performed
  func run() async throws

  /// Clean up after the test
  /// This typically includes terminating applications and resetting state
  func teardown() async throws

  /// Get the name of the test scenario
  /// - Returns: The name of the test scenario
  var name: String { get }

  /// Get the description of the test scenario
  /// - Returns: A detailed description of what the test verifies
  var description: String { get }
}

/// Extension providing default implementations and convenience methods
extension TestScenario {
  /// Default implementation for name which uses the type name
  public var name: String {
    String(describing: type(of: self))
  }

  /// Default implementation for description
  public var description: String {
    "Test scenario for \(name)"
  }

  /// Helper method to wait for a condition with timeout
  /// - Parameters:
  ///   - timeout: Maximum time to wait in seconds
  ///   - description: Description of what we're waiting for (used in timeout message)
  ///   - condition: The condition to wait for
  /// - Throws: Error if timeout is reached
  public func waitFor(
    timeout: TimeInterval,
    description: String,
    condition: @escaping () async throws -> Bool,
  ) async throws {
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
      // Check if the condition is met
      if try await condition() {
        return
      }

      // Wait a bit before trying again
      try await Task.sleep(for: .milliseconds(100))
    }

    // Timeout reached
    throw NSError(
      domain: "TestScenario",
      code: 1000,
      userInfo: [NSLocalizedDescriptionKey: "Timeout waiting for condition: \(description)"],
    )
  }

  /// Helper method to expect a UI element matching criteria
  /// - Parameters:
  ///   - criteria: Criteria to match against UI elements
  ///   - timeout: Maximum time to wait (defaults to 5 seconds)
  ///   - message: Error message if element not found
  /// - Returns: Matching UIElement if found
  /// - Throws: Error if element not found within timeout
  public func expectUIElementMatching(
    _ criteria: UIElementCriteria,
    timeout: TimeInterval = 5.0,
    message: String? = nil,
  ) async throws -> UIElement {
    // This will be implemented once the UIElementCriteria and ToolChain are available
    // For now, throw a not implemented error
    throw NSError(
      domain: "TestScenario",
      code: 1001,
      userInfo: [NSLocalizedDescriptionKey: "Not yet implemented: \(#function)"],
    )
  }

  /// Helper method to expect a condition to become true
  /// - Parameters:
  ///   - condition: The condition to check
  ///   - timeout: Maximum time to wait (defaults to 5 seconds)
  ///   - message: Error message if condition not met
  /// - Throws: Error if condition not met within timeout
  public func expectCondition(
    _ condition: @escaping () async throws -> Bool,
    timeout: TimeInterval = 5.0,
    message: String,
  ) async throws {
    try await waitFor(timeout: timeout, description: message) {
      try await condition()
    }
  }
}

/// Base class for XCTest integration
/// Use this class to run test scenarios within XCTest
open class ScenarioTestCase: XCTestCase {
  /// The test scenario to run
  open var scenario: TestScenario?

  /// Setup that runs before the test
  override open func setUp() async throws {
    try await super.setUp()

    // Skip setup when running the base class - only run in subclasses
    guard type(of: self) != ScenarioTestCase.self else {
      return
    }

    // Get the scenario to test
    guard let scenario else {
      XCTFail("No test scenario provided")
      return
    }

    // Run the scenario setup
    try await scenario.setup()
  }

  /// Teardown that runs after the test
  override open func tearDown() async throws {
    // Skip teardown when running the base class - only run in subclasses
    if type(of: self) != ScenarioTestCase.self, let scenario {
      try await scenario.teardown()
    }

    try await super.tearDown()
  }

  /// Run the test scenario
  open func testScenario() async throws {
    // Skip this test when running the base class - only run in subclasses
    guard type(of: self) != ScenarioTestCase.self else {
      return
    }

    guard let scenario else {
      XCTFail("No test scenario provided")
      return
    }

    try await scenario.run()
  }
}
