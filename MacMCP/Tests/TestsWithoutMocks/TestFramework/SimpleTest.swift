// ABOUTME: SimpleTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import XCTest
import Logging

/// Base test class that provides standard logging capabilities
class SimpleTest: XCTestCase {
  /// Logger for test output
  var logger: Logger!
  
  /// URL of the log file for test output
  var logFileURL: URL?
  
  /// Diagnostic log path for accessibility tree dumps
  var diagnosticLogPath: String?
  
  override func setUp() async throws {
    try await super.setUp()
    
    // Set up logging for this test
    let className = String(describing: type(of: self))
    (logger, logFileURL) = TestLogger.create(label: "mcp.test.\(className.lowercased())", testName: className)
    
    // Configure standard environment variables
    TestLogger.configureEnvironment(logger: logger)
    
    // Create diagnostic log if needed
    diagnosticLogPath = TestLogger.createDiagnosticLog(testName: className, logger: logger)
    
    logger.info("====== TEST SETUP STARTED ======")
  }
  
  override func tearDown() async throws {
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
    try await super.tearDown()
  }
  
  func testExample() {
    logger.info("Running example test")
    XCTAssertTrue(true)
    logger.debug("Test completed successfully")
  }
}