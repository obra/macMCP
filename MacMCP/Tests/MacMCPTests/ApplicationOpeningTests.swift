// ABOUTME: Tests for the application opening functionality of MacMCP.
// ABOUTME: Ensures the server can properly open and activate macOS applications.

import XCTest
@testable import MacMCP
import MCP
import Foundation
import Logging

final class ApplicationOpeningTests: XCTestCase {
    private var server: MCPServer!
    private var mockTransport: MockTransport!
    private var applicationService: ApplicationServiceProtocol!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create a mock transport for testing
        mockTransport = MockTransport()
        
        // Create a mock application service for testing
        let mockApplicationService = MockApplicationService()
        applicationService = mockApplicationService
        
        // Create the MCP server with the mock application service
        server = MCPServer(
            logger: Logger(label: "test.mcp.macos.server"),
            applicationService: mockApplicationService as? ApplicationService
        )
        
        // Start the server with the mock transport
        try await server.start(transport: mockTransport)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        mockTransport = nil
        server = nil
        applicationService = nil
    }
    
    func testOpenApplicationByBundleIdentifier() async throws {
        // Given
        let bundleIdentifier = "com.apple.Safari"
        let params: [String: Value] = [
            "bundleIdentifier": .string(bundleIdentifier)
        ]
        
        // When
        let result = try await mockTransport.executeToolRequest(
            name: "openApplication",
            parameters: params
        )
        
        // Then
        XCTAssertEqual(result.count, 1)
        guard case let .text(jsonString) = result.first else { 
            XCTFail("Expected text result")
            return 
        }
        let applicationData = jsonString.data(using: .utf8)!
        let applicationInfo = try JSONSerialization.jsonObject(with: applicationData) as? [String: Any]
        XCTAssertEqual(applicationInfo?["success"] as? Bool, true)
        XCTAssertEqual(applicationInfo?["bundleIdentifier"] as? String, bundleIdentifier)
        
        // Verify the application service was called correctly
        let mockService = try XCTUnwrap(applicationService as? MockApplicationService)
        XCTAssertEqual(mockService.openedApplications.count, 1)
        XCTAssertEqual(mockService.openedApplications.first, bundleIdentifier)
    }
    
    func testOpenApplicationByName() async throws {
        // Given
        let applicationName = "Safari"
        let params: [String: Value] = [
            "applicationName": .string(applicationName)
        ]
        
        // When
        let result = try await mockTransport.executeToolRequest(
            name: "openApplication",
            parameters: params
        )
        
        // Then
        XCTAssertEqual(result.count, 1)
        guard case let .text(jsonString) = result.first else { 
            XCTFail("Expected text result")
            return 
        }
        let applicationData = jsonString.data(using: .utf8)!
        let applicationInfo = try JSONSerialization.jsonObject(with: applicationData) as? [String: Any]
        XCTAssertEqual(applicationInfo?["success"] as? Bool, true)
        XCTAssertEqual(applicationInfo?["applicationName"] as? String, applicationName)
        
        // Verify the application service was called correctly
        let mockService = try XCTUnwrap(applicationService as? MockApplicationService)
        XCTAssertEqual(mockService.openedApplicationsByName.count, 1)
        XCTAssertEqual(mockService.openedApplicationsByName.first, applicationName)
    }
    
    func testOpenApplicationWithOptions() async throws {
        // Given
        let bundleIdentifier = "com.apple.Safari"
        let arguments = ["--private"]
        let params: [String: Value] = [
            "bundleIdentifier": .string(bundleIdentifier),
            "arguments": .array(arguments.map { .string($0) }),
            "hideOthers": .bool(true)
        ]
        
        // When
        let result = try await mockTransport.executeToolRequest(
            name: "openApplication",
            parameters: params
        )
        
        // Then
        XCTAssertEqual(result.count, 1)
        guard case let .text(jsonString) = result.first else { 
            XCTFail("Expected text result")
            return 
        }
        let applicationData = jsonString.data(using: .utf8)!
        let applicationInfo = try JSONSerialization.jsonObject(with: applicationData) as? [String: Any]
        XCTAssertEqual(applicationInfo?["success"] as? Bool, true)
        
        // Verify the application service was called correctly with all options
        let mockService = try XCTUnwrap(applicationService as? MockApplicationService)
        XCTAssertEqual(mockService.openedApplications.count, 1)
        XCTAssertEqual(mockService.openedApplications.first, bundleIdentifier)
        XCTAssertEqual(mockService.lastArguments, arguments)
        XCTAssertEqual(mockService.lastHideOthers, true)
    }
    
    func testOpenApplicationFailure() async throws {
        // Given
        let bundleIdentifier = "com.example.NonExistentApp"
        let params: [String: Value] = [
            "bundleIdentifier": .string(bundleIdentifier)
        ]
        
        // Configure the mock to fail when opening this app
        let mockService = try XCTUnwrap(applicationService as? MockApplicationService)
        mockService.shouldFailNextOpen = true
        let error = MacMCPErrorInfo(
            category: .applicationLaunch,
            code: 1001,
            message: "Failed to open application with bundle identifier: \(bundleIdentifier)",
            context: ["bundleIdentifier": bundleIdentifier],
            underlyingError: nil
        )
        mockService.failureError = error
        
        // When
        let result = try await mockTransport.executeToolRequest(
            name: "openApplication",
            parameters: params
        )
        
        // Then
        XCTAssertEqual(result.count, 1)
        guard case let .text(jsonString) = result.first else { 
            XCTFail("Expected text result")
            return 
        }
        let errorData = jsonString.data(using: .utf8)!
        let errorInfo = try JSONSerialization.jsonObject(with: errorData) as? [String: Any]
        XCTAssertEqual(errorInfo?["success"] as? Bool, false)
        XCTAssertEqual((errorInfo?["error"] as? [String: Any])?["message"] as? String, 
                      "Failed to open application with bundle identifier: \(bundleIdentifier)")
    }
}

// MARK: - Mocks

final class MockApplicationService: ApplicationServiceProtocol, @unchecked Sendable {
    // Use actors for thread safety to conform to Sendable
    private let lock = NSLock()
    private var _openedApplications: [String] = []
    private var _openedApplicationsByName: [String] = []
    private var _lastArguments: [String]?
    private var _lastHideOthers: Bool?
    private var _shouldFailNextOpen = false
    private var _failureError: Swift.Error?
    
    var openedApplications: [String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _openedApplications
        }
        set {
            lock.lock()
            _openedApplications = newValue
            lock.unlock()
        }
    }
    
    var openedApplicationsByName: [String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _openedApplicationsByName
        }
        set {
            lock.lock()
            _openedApplicationsByName = newValue
            lock.unlock()
        }
    }
    
    var lastArguments: [String]? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastArguments
        }
        set {
            lock.lock()
            _lastArguments = newValue
            lock.unlock()
        }
    }
    
    var lastHideOthers: Bool? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _lastHideOthers
        }
        set {
            lock.lock()
            _lastHideOthers = newValue
            lock.unlock()
        }
    }
    
    var shouldFailNextOpen: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _shouldFailNextOpen
        }
        set {
            lock.lock()
            _shouldFailNextOpen = newValue
            lock.unlock()
        }
    }
    
    var failureError: Swift.Error? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _failureError
        }
        set {
            lock.lock()
            _failureError = newValue
            lock.unlock()
        }
    }
    
    func openApplication(bundleIdentifier: String, arguments: [String]?, hideOthers: Bool?) async throws -> Bool {
        if shouldFailNextOpen {
            shouldFailNextOpen = false
            if let failureError = failureError {
                throw failureError
            }
            return false
        }
        
        openedApplications.append(bundleIdentifier)
        lastArguments = arguments
        lastHideOthers = hideOthers
        return true
    }
    
    func openApplication(name: String, arguments: [String]?, hideOthers: Bool?) async throws -> Bool {
        if shouldFailNextOpen {
            shouldFailNextOpen = false
            if let failureError = failureError {
                throw failureError
            }
            return false
        }
        
        openedApplicationsByName.append(name)
        lastArguments = arguments
        lastHideOthers = hideOthers
        return true
    }
    
    func activateApplication(bundleIdentifier: String) async throws -> Bool {
        if shouldFailNextOpen {
            shouldFailNextOpen = false
            if let failureError = failureError {
                throw failureError
            }
            return false
        }
        
        return true
    }
    
    func getRunningApplications() async throws -> [String: String] {
        return ["com.apple.Safari": "Safari", "com.apple.finder": "Finder"]
    }
}