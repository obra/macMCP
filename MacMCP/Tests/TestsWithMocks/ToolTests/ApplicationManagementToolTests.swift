// ABOUTME: ApplicationManagementToolTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Test utilities are directly available in this module

/// Mock of the ApplicationService for testing ApplicationManagementTool
private class MockApplicationService: @unchecked Sendable, ApplicationServiceProtocol {
  // MARK: - Test Control Properties

  // Tracking properties for launch operations
  var launchApplicationCalled = false
  var lastApplicationName: String?
  var lastBundleIdentifier: String?
  var lastArguments: [String]?
  var lastHideOthers: Bool?
  var lastWaitForLaunch: Bool?
  var lastTimeout: TimeInterval?

  // Mock return values
  var launchResultToReturn = ApplicationLaunchResult(
    success: true,
    processIdentifier: 12345,
    bundleIdentifier: "com.test.app",
    applicationName: "Test App",
  )

  // Tracking properties for terminate operations
  var terminateApplicationCalled = false
  var terminateLastBundleIdentifier: String?
  var terminateLastTimeout: TimeInterval?
  var terminateResultToReturn = true

  // Tracking properties for force terminate operations
  var forceTerminateApplicationCalled = false
  var forceTerminateLastBundleIdentifier: String?
  var forceTerminateResultToReturn = true

  // Tracking properties for running status
  var isApplicationRunningCalled = false
  var isRunningLastBundleIdentifier: String?
  var isRunningResultToReturn = true

  // Tracking properties for running applications
  var getRunningApplicationsCalled = false
  var runningAppsToReturn: [String: String] = [
    "com.test.app1": "Test App 1",
    "com.test.app2": "Test App 2",
  ]

  // Tracking properties for activation
  var activateApplicationCalled = false
  var activateLastBundleIdentifier: String?
  var activateResultToReturn = true

  // Tracking properties for hiding
  var hideApplicationCalled = false
  var hideLastBundleIdentifier: String?
  var hideResultToReturn = true

  // Tracking properties for unhiding
  var unhideApplicationCalled = false
  var unhideLastBundleIdentifier: String?
  var unhideResultToReturn = true

  // Tracking properties for hiding others
  var hideOtherApplicationsCalled = false
  var hideOthersLastExceptBundleIdentifier: String?
  var hideOthersResultToReturn = true

  // Tracking properties for frontmost application
  var getFrontmostApplicationCalled = false
  var frontmostApplicationToReturn: ApplicationStateInfo? = ApplicationStateInfo(
    bundleIdentifier: "com.test.frontmost",
    name: "Frontmost App",
    isRunning: true,
    processId: 12345,
    isActive: true,
    isFinishedLaunching: true,
    url: URL(string: "file:///Applications/Test.app"),
  )

  // Tracking properties for observation
  var startObservingApplicationsCalled = false
  var stopObservingApplicationsCalled = false
  var lastObserverId: String?
  var observerIdToReturn = "test-observer-id"

  // Tracking properties for application info
  var getApplicationInfoCalled = false
  var infoLastBundleIdentifier: String?
  var applicationInfoToReturn: ApplicationStateInfo? = ApplicationStateInfo(
    bundleIdentifier: "com.test.app",
    name: "Test App",
    isRunning: true,
    processId: 12345,
    isActive: true,
    isFinishedLaunching: true,
    url: URL(string: "file:///Applications/Test.app"),
  )

  // Error control
  var shouldFailOperations = false
  var errorToThrow: MCPError?

  // MARK: - ApplicationServiceProtocol Implementation

  func openApplication(
    bundleIdentifier _: String,
    arguments _: [String]? = nil,
    hideOthers _: Bool? = nil,
  ) async throws -> Bool {
    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
    return true
  }

  func openApplication(name _: String, arguments _: [String]? = nil, hideOthers _: Bool? = nil)
    async throws -> Bool
  {
    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
    return true
  }

  func launchApplication(
    name: String?,
    bundleIdentifier: String?,
    arguments: [String],
    hideOthers: Bool,
    waitForLaunch: Bool,
    timeout: TimeInterval,
  ) async throws -> ApplicationLaunchResult {
    launchApplicationCalled = true
    lastApplicationName = name
    lastBundleIdentifier = bundleIdentifier
    lastArguments = arguments
    lastHideOthers = hideOthers
    lastWaitForLaunch = waitForLaunch
    lastTimeout = timeout

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return launchResultToReturn
  }

  func terminateApplication(bundleIdentifier: String, timeout: TimeInterval) async throws -> Bool {
    terminateApplicationCalled = true
    terminateLastBundleIdentifier = bundleIdentifier
    terminateLastTimeout = timeout

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return terminateResultToReturn
  }

  func forceTerminateApplication(bundleIdentifier: String) async throws -> Bool {
    forceTerminateApplicationCalled = true
    forceTerminateLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return forceTerminateResultToReturn
  }

  func activateApplication(bundleIdentifier: String) async throws -> Bool {
    activateApplicationCalled = true
    activateLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return activateResultToReturn
  }

  func hideApplication(bundleIdentifier: String) async throws -> Bool {
    hideApplicationCalled = true
    hideLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return hideResultToReturn
  }

  func unhideApplication(bundleIdentifier: String) async throws -> Bool {
    unhideApplicationCalled = true
    unhideLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return unhideResultToReturn
  }

  func hideOtherApplications(exceptBundleIdentifier: String?) async throws -> Bool {
    hideOtherApplicationsCalled = true
    hideOthersLastExceptBundleIdentifier = exceptBundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return hideOthersResultToReturn
  }

  func getRunningApplications() async throws -> [String: String] {
    getRunningApplicationsCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return runningAppsToReturn
  }

  func getFrontmostApplication() async throws -> ApplicationStateInfo? {
    getFrontmostApplicationCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return frontmostApplicationToReturn
  }

  func startObservingApplications(
    notificationHandler _: @escaping @Sendable (ApplicationStateChange) async
      -> Void,
  ) async throws -> String {
    startObservingApplicationsCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return observerIdToReturn
  }

  func stopObservingApplications(observerId: String) async throws {
    stopObservingApplicationsCalled = true
    lastObserverId = observerId

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func isApplicationRunning(bundleIdentifier: String) async throws -> Bool {
    isApplicationRunningCalled = true
    isRunningLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return isRunningResultToReturn
  }

  func getApplicationInfo(bundleIdentifier: String) async throws -> ApplicationStateInfo? {
    getApplicationInfoCalled = true
    infoLastBundleIdentifier = bundleIdentifier

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return applicationInfoToReturn
  }
}

/// Tests for the ApplicationManagementTool
@Suite(.serialized)
struct ApplicationManagementToolTests {
  // Test components
  private var mockApplicationService: MockApplicationService!
  private var applicationManagementTool: ApplicationManagementTool!

  // Shared setup method
  private mutating func setUp() async throws {
    mockApplicationService = MockApplicationService()
    applicationManagementTool = ApplicationManagementTool(
      applicationService: mockApplicationService,
      logger: Logger(label: "test.application_management"),
    )
  }

  // Shared teardown method
  private mutating func tearDown() async throws {
    applicationManagementTool = nil
    mockApplicationService = nil
  }

  // MARK: - Test Methods

  /// Test launching an application by bundle identifier
  @Test("Launch by bundle identifier")
  mutating func testLaunchByBundleIdentifier() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("launch"),
      "bundleIdentifier": .string("com.test.app"),
      "arguments": .array([.string("--arg1"), .string("--arg2")]),
      "hideOthers": .bool(true),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.launchApplicationCalled, "Should call launchApplication")
    #expect(mockApplicationService.lastApplicationName == nil)
    #expect(mockApplicationService.lastBundleIdentifier == "com.test.app")
    #expect(mockApplicationService.lastArguments == ["--arg1", "--arg2"])
    #expect(mockApplicationService.lastHideOthers == true)

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"processIdentifier\": 12345"), "Response should include process ID")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test launching an application by name
  @Test("Launch by application name")
  mutating func testLaunchByApplicationName() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("launch"),
      "applicationName": .string("Test App"),
      "waitForLaunch": .bool(false),
      "launchTimeout": .double(60.0),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.launchApplicationCalled, "Should call launchApplication")
    #expect(mockApplicationService.lastApplicationName == "Test App")
    #expect(mockApplicationService.lastBundleIdentifier == nil)
    #expect(mockApplicationService.lastWaitForLaunch == false)
    #expect(mockApplicationService.lastTimeout == 60.0)

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test terminating an application
  @Test("Terminate application")
  mutating func testTerminate() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("terminate"),
      "bundleIdentifier": .string("com.test.app"),
      "terminateTimeout": .double(15.0),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.terminateApplicationCalled, "Should call terminateApplication")
    #expect(mockApplicationService.terminateLastBundleIdentifier == "com.test.app")
    #expect(mockApplicationService.terminateLastTimeout == 15.0)

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test force terminating an application
  @Test("Force terminate application")
  mutating func testForceTerminate() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("forceTerminate"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.forceTerminateApplicationCalled, "Should call forceTerminateApplication")
    #expect(mockApplicationService.forceTerminateLastBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test checking if an application is running
  @Test("Check if application is running")
  mutating func testIsRunning() async throws {
    try await setUp()
    
    // Setup
    mockApplicationService.isRunningResultToReturn = true

    let params: [String: Value] = [
      "action": .string("isRunning"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.isApplicationRunningCalled, "Should call isApplicationRunning")
    #expect(mockApplicationService.isRunningLastBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
      #expect(jsonString.contains("\"isRunning\": true"), "Response should include running status")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test getting running applications
  @Test("Get running applications")
  mutating func testGetRunningApplications() async throws {
    try await setUp()
    
    // Setup - mock is already configured in setup

    let params: [String: Value] = [
      "action": .string("getRunningApplications")
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.getRunningApplicationsCalled, "Should call getRunningApplications")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"applications\":"), "Response should include applications array")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app1\""), "Response should include first app bundle ID")
      #expect(jsonString.contains("\"applicationName\": \"Test App 1\""), "Response should include first app name")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app2\""), "Response should include second app bundle ID")
      #expect(jsonString.contains("\"applicationName\": \"Test App 2\""), "Response should include second app name")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test activating an application
  @Test("Activate application")
  mutating func testActivateApplication() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("activateApplication"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.activateApplicationCalled, "Should call activateApplication")
    #expect(mockApplicationService.activateLastBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test hiding an application
  @Test("Hide application")
  mutating func testHideApplication() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("hideApplication"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.hideApplicationCalled, "Should call hideApplication")
    #expect(mockApplicationService.hideLastBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test unhiding an application
  @Test("Unhide application")
  mutating func testUnhideApplication() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("unhideApplication"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.unhideApplicationCalled, "Should call unhideApplication")
    #expect(mockApplicationService.unhideLastBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.app\""), "Response should include bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test hiding other applications
  @Test("Hide other applications")
  mutating func testHideOtherApplications() async throws {
    try await setUp()
    
    // Setup
    let params: [String: Value] = [
      "action": .string("hideOtherApplications"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.hideOtherApplicationsCalled, "Should call hideOtherApplications")
    #expect(mockApplicationService.hideOthersLastExceptBundleIdentifier == "com.test.app")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"exceptBundleIdentifier\": \"com.test.app\""), "Response should include except bundle ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test getting the frontmost application
  @Test("Get frontmost application")
  mutating func testGetFrontmostApplication() async throws {
    try await setUp()
    
    // Setup - mock is already configured in setup

    let params: [String: Value] = [
      "action": .string("getFrontmostApplication")
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.getFrontmostApplicationCalled, "Should call getFrontmostApplication")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"bundleIdentifier\": \"com.test.frontmost\""), "Response should include bundle ID")
      #expect(jsonString.contains("\"applicationName\": \"Frontmost App\""), "Response should include app name")
      #expect(jsonString.contains("\"processIdentifier\": 12345"), "Response should include process ID")
      #expect(jsonString.contains("\"isActive\": true"), "Response should include active status")
      #expect(jsonString.contains("\"isFinishedLaunching\": true"), "Response should include finished launching status")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test the case when there is no frontmost application
  @Test("Get frontmost application when none exists")
  mutating func testGetFrontmostApplicationNone() async throws {
    try await setUp()
    
    // Setup - override the mock to return nil
    mockApplicationService.frontmostApplicationToReturn = nil

    let params: [String: Value] = [
      "action": .string("getFrontmostApplication")
    ]

    // Execute the test
    let result = try await applicationManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockApplicationService.getFrontmostApplicationCalled, "Should call getFrontmostApplication")

    // Verify the result content
    if case .text(let jsonString) = result[0] {
      // Basic validation of JSON format
      #expect(jsonString.contains("\"success\": true"), "Response should indicate success")
      #expect(jsonString.contains("\"hasFrontmostApplication\": false"), "Response should indicate no frontmost app")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
    
    try await tearDown()
  }

  /// Test error handling for failures
  @Test("Error handling")
  mutating func testErrorHandling() async throws {
    try await setUp()
    
    // Setup - configure mock to fail
    mockApplicationService.shouldFailOperations = true
    mockApplicationService.errorToThrow = MCPError.internalError("Test error message")

    let params: [String: Value] = [
      "action": .string("launch"),
      "bundleIdentifier": .string("com.test.app"),
      "arguments": .array([.string("--arg1"), .string("--arg2")]),
    ]

    // Test that the error is propagated
    do {
      _ = try await applicationManagementTool.handler(params)
      #expect(Bool(false), "Should throw an error")
    } catch let error as MCPError {
      // Verify it's the correct error type
      switch error {
      case .internalError(let message):
        #expect(message?.contains("Test error message") == true, "Error message should include the original error details")
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }
    
    try await tearDown()
  }

  /// Test validation errors for missing parameters
  @Test("Validation errors")
  mutating func testValidationErrors() async throws {
    try await setUp()
    
    // Test missing bundleIdentifier for an action that requires it
    let params: [String: Value] = [
      "action": .string("terminate")
    ]

    // Test that parameter validation works
    do {
      _ = try await applicationManagementTool.handler(params)
      #expect(Bool(false), "Should throw an error for missing bundleIdentifier")
    } catch let error as MCPError {
      switch error {
      case .invalidParams(let message):
        #expect(message?.contains("bundleIdentifier is required") == true, "Error should indicate missing bundleIdentifier")
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }

    // Test missing both identifiers for launch
    let launchParams: [String: Value] = [
      "action": .string("launch")
    ]

    do {
      _ = try await applicationManagementTool.handler(launchParams)
      #expect(Bool(false), "Should throw an error for missing both applicationName and bundleIdentifier")
    } catch let error as MCPError {
      switch error {
      case .invalidParams(let message):
        #expect(message?.contains("Either applicationName or bundleIdentifier is required") == true, "Error should indicate missing identifiers")
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }

    // Test invalid action
    let invalidActionParams: [String: Value] = [
      "action": .string("invalidAction"),
      "bundleIdentifier": .string("com.test.app"),
    ]

    do {
      _ = try await applicationManagementTool.handler(invalidActionParams)
      #expect(Bool(false), "Should throw an error for invalid action")
    } catch let error as MCPError {
      switch error {
      case .invalidParams(let message):
        #expect(message?.contains("Valid action is required") == true, "Error should indicate invalid action")
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }
    
    try await tearDown()
  }
}
