// ABOUTME: This file contains tests for the ApplicationManagementTool functionality.
// ABOUTME: It verifies that the tool correctly manages macOS applications.

import XCTest
import Foundation
import MCP
import Logging
@testable import MacMCP

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
        applicationName: "Test App"
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
        "com.test.app2": "Test App 2"
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
        url: URL(string: "file:///Applications/Test.app")
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
        url: URL(string: "file:///Applications/Test.app")
    )
    
    // Error control
    var shouldFailOperations = false
    var errorToThrow: MCPError?
    
    // MARK: - ApplicationServiceProtocol Implementation
    
    func openApplication(bundleIdentifier: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        return true
    }
    
    func openApplication(name: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
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
        timeout: TimeInterval
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
    
    func startObservingApplications(notificationHandler: @escaping @Sendable (ApplicationStateChange) async -> Void) async throws -> String {
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
final class ApplicationManagementToolTests: XCTestCase {
    
    // Test components
    private var mockApplicationService: MockApplicationService!
    private var applicationManagementTool: ApplicationManagementTool!
    
    override func setUp() {
        super.setUp()
        mockApplicationService = MockApplicationService()
        applicationManagementTool = ApplicationManagementTool(
            applicationService: mockApplicationService,
            logger: Logger(label: "test.application_management")
        )
    }
    
    override func tearDown() {
        applicationManagementTool = nil
        mockApplicationService = nil
        super.tearDown()
    }
    
    // MARK: - Test Methods
    
    /// Test launching an application by bundle identifier
    func testLaunchByBundleIdentifier() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string("com.test.app"),
            "arguments": .array([.string("--arg1"), .string("--arg2")]),
            "hideOthers": .bool(true)
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.launchApplicationCalled, "Should call launchApplication")
        XCTAssertNil(mockApplicationService.lastApplicationName)
        XCTAssertEqual(mockApplicationService.lastBundleIdentifier, "com.test.app")
        XCTAssertEqual(mockApplicationService.lastArguments, ["--arg1", "--arg2"])
        XCTAssertEqual(mockApplicationService.lastHideOthers, true)
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"processIdentifier\":12345"), "Response should include process ID")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test launching an application by name
    func testLaunchByApplicationName() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("launch"),
            "applicationName": .string("Test App"),
            "waitForLaunch": .bool(false),
            "launchTimeout": .double(60.0)
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.launchApplicationCalled, "Should call launchApplication")
        XCTAssertEqual(mockApplicationService.lastApplicationName, "Test App")
        XCTAssertNil(mockApplicationService.lastBundleIdentifier)
        XCTAssertEqual(mockApplicationService.lastWaitForLaunch, false)
        XCTAssertEqual(mockApplicationService.lastTimeout, 60.0)
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test terminating an application
    func testTerminate() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("terminate"),
            "bundleIdentifier": .string("com.test.app"),
            "terminateTimeout": .double(15.0)
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.terminateApplicationCalled, "Should call terminateApplication")
        XCTAssertEqual(mockApplicationService.terminateLastBundleIdentifier, "com.test.app")
        XCTAssertEqual(mockApplicationService.terminateLastTimeout, 15.0)
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test force terminating an application
    func testForceTerminate() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("forceTerminate"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.forceTerminateApplicationCalled, "Should call forceTerminateApplication")
        XCTAssertEqual(mockApplicationService.forceTerminateLastBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test checking if an application is running
    func testIsRunning() async throws {
        // Setup
        mockApplicationService.isRunningResultToReturn = true
        
        let params: [String: Value] = [
            "action": .string("isRunning"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.isApplicationRunningCalled, "Should call isApplicationRunning")
        XCTAssertEqual(mockApplicationService.isRunningLastBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
            XCTAssertTrue(jsonString.contains("\"isRunning\":true"), "Response should include running status")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test getting running applications
    func testGetRunningApplications() async throws {
        // Setup - mock is already configured in setup
        
        let params: [String: Value] = [
            "action": .string("getRunningApplications")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.getRunningApplicationsCalled, "Should call getRunningApplications")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"applications\":"), "Response should include applications array")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app1\""), "Response should include first app bundle ID")
            XCTAssertTrue(jsonString.contains("\"applicationName\":\"Test App 1\""), "Response should include first app name")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app2\""), "Response should include second app bundle ID")
            XCTAssertTrue(jsonString.contains("\"applicationName\":\"Test App 2\""), "Response should include second app name")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test activating an application
    func testActivateApplication() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("activateApplication"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.activateApplicationCalled, "Should call activateApplication")
        XCTAssertEqual(mockApplicationService.activateLastBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test hiding an application
    func testHideApplication() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("hideApplication"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.hideApplicationCalled, "Should call hideApplication")
        XCTAssertEqual(mockApplicationService.hideLastBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test unhiding an application
    func testUnhideApplication() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("unhideApplication"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.unhideApplicationCalled, "Should call unhideApplication")
        XCTAssertEqual(mockApplicationService.unhideLastBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.app\""), "Response should include bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test hiding other applications
    func testHideOtherApplications() async throws {
        // Setup
        let params: [String: Value] = [
            "action": .string("hideOtherApplications"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.hideOtherApplicationsCalled, "Should call hideOtherApplications")
        XCTAssertEqual(mockApplicationService.hideOthersLastExceptBundleIdentifier, "com.test.app")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"exceptBundleIdentifier\":\"com.test.app\""), "Response should include except bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test getting the frontmost application
    func testGetFrontmostApplication() async throws {
        // Setup - mock is already configured in setup
        
        let params: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.getFrontmostApplicationCalled, "Should call getFrontmostApplication")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"bundleIdentifier\":\"com.test.frontmost\""), "Response should include bundle ID")
            XCTAssertTrue(jsonString.contains("\"applicationName\":\"Frontmost App\""), "Response should include app name")
            XCTAssertTrue(jsonString.contains("\"processIdentifier\":12345"), "Response should include process ID")
            XCTAssertTrue(jsonString.contains("\"isActive\":true"), "Response should include active status")
            XCTAssertTrue(jsonString.contains("\"isFinishedLaunching\":true"), "Response should include finished launching status")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test the case when there is no frontmost application
    func testGetFrontmostApplicationNone() async throws {
        // Setup - override the mock to return nil
        mockApplicationService.frontmostApplicationToReturn = nil
        
        let params: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]
        
        // Execute the test
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockApplicationService.getFrontmostApplicationCalled, "Should call getFrontmostApplication")
        
        // Verify the result content
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"hasFrontmostApplication\":false"), "Response should indicate no frontmost app")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test error handling for failures
    func testErrorHandling() async throws {
        // Setup - configure mock to fail
        mockApplicationService.shouldFailOperations = true
        mockApplicationService.errorToThrow = MCPError.internalError("Test error message")
        
        let params: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string("com.test.app"),
            "arguments": .array([.string("--arg1"), .string("--arg2")])
        ]
        
        // Test that the error is propagated
        do {
            _ = try await applicationManagementTool.handler(params)
            XCTFail("Should throw an error")
        } catch let error as MCPError {
            // Verify it's the correct error type
            switch error {
            case .internalError(let message):
                XCTAssertTrue(message?.contains("Test error message") ?? false, "Error message should include the original error details")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test validation errors for missing parameters
    func testValidationErrors() async throws {
        // Test missing bundleIdentifier for an action that requires it
        let params: [String: Value] = [
            "action": .string("terminate")
        ]
        
        // Test that parameter validation works
        do {
            _ = try await applicationManagementTool.handler(params)
            XCTFail("Should throw an error for missing bundleIdentifier")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("bundleIdentifier is required") ?? false, "Error should indicate missing bundleIdentifier")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test missing both identifiers for launch
        let launchParams: [String: Value] = [
            "action": .string("launch")
        ]
        
        do {
            _ = try await applicationManagementTool.handler(launchParams)
            XCTFail("Should throw an error for missing both applicationName and bundleIdentifier")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Either applicationName or bundleIdentifier is required") ?? false, "Error should indicate missing identifiers")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test invalid action
        let invalidActionParams: [String: Value] = [
            "action": .string("invalidAction"),
            "bundleIdentifier": .string("com.test.app")
        ]
        
        do {
            _ = try await applicationManagementTool.handler(invalidActionParams)
            XCTFail("Should throw an error for invalid action")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Valid action is required") ?? false, "Error should indicate invalid action")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}