// ABOUTME: This file contains end-to-end tests for the ApplicationManagementTool.
// ABOUTME: It verifies that application management operations work correctly with real macOS applications.

import XCTest
import Foundation
import MCP
import AppKit
import Logging
@testable import MacMCP

/// End-to-end tests for the ApplicationManagementTool
final class ApplicationManagementE2ETests: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    
    // Bundle IDs for test applications
    private let calculatorBundleId = "com.apple.calculator"
    private let textEditBundleId = "com.apple.TextEdit"
    
    override func setUp() async throws {
        try await super.setUp()

        // Create the test components
        toolChain = ToolChain()
        
        // Force terminate any existing instances of test applications
        for bundleId in [calculatorBundleId, textEditBundleId] {
            await terminateApplication(bundleId: bundleId)
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    override func tearDown() async throws {
        // Terminate test applications
        for bundleId in [calculatorBundleId, textEditBundleId] {
            await terminateApplication(bundleId: bundleId)
        }
        
        try await Task.sleep(for: .milliseconds(1000))
        
        toolChain = nil

        try await super.tearDown()
    }
    
    /// Helper method to terminate an application
    private func terminateApplication(bundleId: String) async {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in runningApps {
            _ = app.forceTerminate()
        }
    }
    
    /// Test launching and terminating an application
    func testLaunchAndTerminate() async throws {
        // Verify Calculator is not running at start
        let initialIsRunning = isApplicationRunning(calculatorBundleId)
        XCTAssertFalse(initialIsRunning, "Calculator should not be running at test start")
        
        // Create launch parameters
        let launchParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        // Launch Calculator
        let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)
        
        // Verify launch result
        XCTAssertEqual(launchResult.count, 1, "Should return one content item")
        
        // Wait for the app to launch fully
        try await Task.sleep(for: .milliseconds(2000))
        
        // Check if app is running
        let isRunning = isApplicationRunning(calculatorBundleId)
        XCTAssertTrue(isRunning, "Calculator should be running after launch")
        
        // Create terminate parameters
        let terminateParams: [String: Value] = [
            "action": .string("terminate"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        // Terminate Calculator
        let terminateResult = try await toolChain.applicationManagementTool.handler(terminateParams)
        
        // Verify terminate result
        XCTAssertEqual(terminateResult.count, 1, "Should return one content item")
        
        // Wait for app to terminate
        try await Task.sleep(for: .milliseconds(1000))
        
        // Check if app is still running
        let isStillRunning = isApplicationRunning(calculatorBundleId)
        XCTAssertFalse(isStillRunning, "Calculator should not be running after termination")
    }
    
    /// Test getting running applications
    func testGetRunningApplications() async throws {
        // Launch a test application
        let launchParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchParams)
        
        // Wait for the app to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Create get running applications parameters
        let getRunningParams: [String: Value] = [
            "action": .string("getRunningApplications")
        ]
        
        // Get running applications
        let result = try await toolChain.applicationManagementTool.handler(getRunningParams)
        
        // Verify result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Verify that Calculator is listed in the running applications
            XCTAssertTrue(jsonString.contains(calculatorBundleId), "Running applications should include Calculator")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test checking if an application is running
    func testIsRunning() async throws {
        // Launch Calculator
        let launchParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchParams)
        
        // Wait for app to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Check if Calculator is running
        let isRunningParams: [String: Value] = [
            "action": .string("isRunning"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        let calcResult = try await toolChain.applicationManagementTool.handler(isRunningParams)
        
        // Verify result for running application
        XCTAssertEqual(calcResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = calcResult[0] {
            XCTAssertTrue(jsonString.contains("\"isRunning\":true"), "Calculator should be reported as running")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Check if a non-running application is reported correctly
        let notRunningParams: [String: Value] = [
            "action": .string("isRunning"),
            "bundleIdentifier": .string("com.nonexistent.app")
        ]
        
        let nonRunningResult = try await toolChain.applicationManagementTool.handler(notRunningParams)
        
        // Verify result for non-running application
        XCTAssertEqual(nonRunningResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = nonRunningResult[0] {
            XCTAssertTrue(jsonString.contains("\"isRunning\":false"), "Non-existent app should be reported as not running")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test hiding, unhiding and activating an application
    func testHideUnhideActivate() async throws {
        // First launch both test applications
        
        // Launch Calculator
        let launchCalcParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchCalcParams)
        
        // Wait for Calculator to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Launch TextEdit
        let launchTextEditParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(textEditBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchTextEditParams)
        
        // Wait for TextEdit to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Hide Calculator
        let hideParams: [String: Value] = [
            "action": .string("hideApplication"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        let hideResult = try await toolChain.applicationManagementTool.handler(hideParams)
        
        // Verify hide result
        XCTAssertEqual(hideResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = hideResult[0] {
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Hide operation should succeed")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Allow time for UI to update
        try await Task.sleep(for: .milliseconds(1000))
        
        // Activate Calculator (should also unhide it)
        let activateParams: [String: Value] = [
            "action": .string("activateApplication"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        let activateResult = try await toolChain.applicationManagementTool.handler(activateParams)
        
        // Verify activate result
        XCTAssertEqual(activateResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = activateResult[0] {
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Activate operation should succeed")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Allow time for UI to update
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get frontmost application
        let frontmostParams: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]
        
        let frontmostResult = try await toolChain.applicationManagementTool.handler(frontmostParams)
        
        // Verify frontmost result
        XCTAssertEqual(frontmostResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = frontmostResult[0] {
            // Calculator should now be the frontmost application
            XCTAssertTrue(jsonString.contains(calculatorBundleId), "Calculator should be the frontmost application")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test hiding other applications
    func testHideOtherApplications() async throws {
        // First launch both test applications
        
        // Launch Calculator
        let launchCalcParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchCalcParams)
        
        // Wait for Calculator to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Launch TextEdit
        let launchTextEditParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(textEditBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchTextEditParams)
        
        // Wait for TextEdit to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Hide other applications, keeping Calculator visible
        let hideOthersParams: [String: Value] = [
            "action": .string("hideOtherApplications"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        let hideOthersResult = try await toolChain.applicationManagementTool.handler(hideOthersParams)
        
        // Verify hide others result
        XCTAssertEqual(hideOthersResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = hideOthersResult[0] {
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Hide others operation should succeed")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Allow time for UI to update
        try await Task.sleep(for: .milliseconds(1000))
        
        // Get frontmost application
        let frontmostParams: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]
        
        let frontmostResult = try await toolChain.applicationManagementTool.handler(frontmostParams)
        
        // Verify frontmost result
        XCTAssertEqual(frontmostResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = frontmostResult[0] {
            // Calculator should now be the frontmost application
            XCTAssertTrue(jsonString.contains(calculatorBundleId), "Calculator should be the frontmost application")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test force terminating an application
    func testForceTerminate() async throws {
        // Launch Calculator
        let launchParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        _ = try await toolChain.applicationManagementTool.handler(launchParams)
        
        // Wait for app to launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Verify Calculator is running
        let isRunning = isApplicationRunning(calculatorBundleId)
        XCTAssertTrue(isRunning, "Calculator should be running after launch")
        
        // Force terminate Calculator
        let forceTerminateParams: [String: Value] = [
            "action": .string("forceTerminate"),
            "bundleIdentifier": .string(calculatorBundleId)
        ]
        
        let forceTerminateResult = try await toolChain.applicationManagementTool.handler(forceTerminateParams)
        
        // Verify force terminate result
        XCTAssertEqual(forceTerminateResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = forceTerminateResult[0] {
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Force terminate operation should succeed")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Wait for app to terminate
        try await Task.sleep(for: .milliseconds(1000))
        
        // Verify Calculator is no longer running
        let isStillRunning = isApplicationRunning(calculatorBundleId)
        XCTAssertFalse(isStillRunning, "Calculator should not be running after force termination")
    }
    
    // MARK: - Helper Methods
    
    /// Check if an application is running using NSRunningApplication directly
    private func isApplicationRunning(_ bundleId: String) -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        return !runningApps.isEmpty
    }
}