// ABOUTME: SimpleTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import Testing

/// Function that wraps #expect with a custom message
/// In the Testing framework, we can't pass a custom message to #expect, so we just use the
/// expression
public func expectMessage(_ expression: Bool, _: String = "") {
  // Just forward to the normal #expect but ignore the message since we can't show it
  #expect(expression)
}

/// TestCase protocol that provides standard logging capabilities for Swift Testing framework tests
public protocol TestCase {
  /// Logger for test output
  var logger: Logger { get set }
  /// URL of the log file for test output
  var logFileURL: URL? { get set }
  /// Diagnostic log path for accessibility tree dumps
  var diagnosticLogPath: String? { get set }
  /// Set up test environment
  mutating func setUp() async throws
  /// Tear down test environment
  mutating func tearDown() async throws
}

/// Default implementation of TestCase protocol
extension TestCase {
  /// Standard setup implementation
  public mutating func setUp() async throws {
    // Set up logging for this test
    let typeName = String(describing: type(of: self))
    (logger, logFileURL) = TestLogger.create(
      label: "mcp.test.\(typeName.lowercased())", testName: typeName,
    )
    // Configure standard environment variables
    TestLogger.configureEnvironment(logger: logger)
    // Create diagnostic log if needed
    diagnosticLogPath = TestLogger.createDiagnosticLog(testName: typeName, logger: logger)
    logger.info("====== TEST SETUP STARTED ======")
  }

  /// Standard teardown implementation
  public mutating func tearDown() async throws {
    logger.info("====== TEST TEARDOWN STARTED ======")
    // Print log file location if available
    if let logURL = logFileURL {
      logger.info("Test log available at: \(logURL.path)")
      print("For detailed debug info, check the log file at: \(logURL.path)")
    }
    if let diagnosticPath = diagnosticLogPath {
      logger.info("Accessibility diagnostic log available at: \(diagnosticPath)")
    }
    logger.info("====== TEST TEARDOWN COMPLETE ======")
  }
}

/// A testing utility struct to include in Swift Testing framework test suites
/// Use this as a property in your test struct to include logging capabilities
public struct TestSetup: TestCase {
  public var logger: Logger = .init(label: "mcp.test.default")
  public var logFileURL: URL?
  public var diagnosticLogPath: String?
  public init() {}
}
