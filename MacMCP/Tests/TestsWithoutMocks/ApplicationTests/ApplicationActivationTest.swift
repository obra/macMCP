// ABOUTME: This file provides focused tests for application activation and management.
// ABOUTME: It verifies that applications can be properly launched, activated, deactivated, and terminated.

import Foundation
import XCTest
@testable import MacMCP
import MCP

/// A focused test for application activation and management operations
@MainActor
final class ApplicationActivationTest: XCTestCase {
    private var toolChain: ToolChain!
    
    override func setUp() async throws {
        // Create a new toolchain for test operations
        toolChain = ToolChain(logLabel: "mcp.test.application_activation")
        
        // Ensure clean state - terminate TextEdit if running
        _ = try? await terminateApp(bundleId: "com.apple.TextEdit")
        
        // Wait briefly to ensure cleanup is complete
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    /// Basic test for application launch and activation flow
    func testBasicAppActivation() async throws {
        // Launch TextEdit
        let launchSuccess = try await launchApp(bundleId: "com.apple.TextEdit")
        XCTAssertTrue(launchSuccess, "TextEdit should launch successfully")
        
        // Wait for app to initialize
        try await Task.sleep(for: .milliseconds(2000))
        
        // Get frontmost app to verify state
        let frontmostBeforeSwitch = try await getFrontmostApp()
        print("Frontmost app before switch: \(frontmostBeforeSwitch?.bundleIdentifier ?? "None")")
        
        // Switch to Finder (deactivate TextEdit)
        let switchToFinderSuccess = try await activateApp(bundleId: "com.apple.finder")
        XCTAssertTrue(switchToFinderSuccess, "Should successfully activate Finder")
        
        // Wait for app switch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Get frontmost app to verify switch worked
        let frontmostAfterSwitch = try await getFrontmostApp()
        print("Frontmost app after switch to Finder: \(frontmostAfterSwitch?.bundleIdentifier ?? "None")")
        XCTAssertEqual(frontmostAfterSwitch?.bundleIdentifier, "com.apple.finder", "Finder should be frontmost after activation")
        
        // Switch back to TextEdit
        let switchBackSuccess = try await activateApp(bundleId: "com.apple.TextEdit")
        XCTAssertTrue(switchBackSuccess, "Should successfully activate TextEdit again")
        
        // Wait for app switch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Get frontmost app to verify switch back worked
        let frontmostAfterSwitchBack = try await getFrontmostApp()
        print("Frontmost app after switch back to TextEdit: \(frontmostAfterSwitchBack?.bundleIdentifier ?? "None")")
        XCTAssertEqual(frontmostAfterSwitchBack?.bundleIdentifier, "com.apple.TextEdit", "TextEdit should be frontmost after activation")
        
        // Test window counting with WindowManagementTool
        let windowCount = try await getWindowCount(bundleId: "com.apple.TextEdit")
        print("TextEdit window count: \(windowCount)")
        
        // Terminate TextEdit
        let terminateSuccess = try await terminateApp(bundleId: "com.apple.TextEdit")
        XCTAssertTrue(terminateSuccess, "TextEdit should terminate successfully")
    }
    
    // MARK: - Helper Methods
    
    /// Launch an application by bundle identifier
    private func launchApp(bundleId: String) async throws -> Bool {
        let params: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string(bundleId),
            "waitForLaunch": .bool(true)
        ]
        
        let result = try await toolChain.applicationManagementTool.handler(params)
        
        // Check if launch was successful
        if let content = result.first, case .text(let text) = content {
            print("Launch result: \(text)")
            return text.contains("success") && text.contains("true")
        }
        
        return false
    }
    
    /// Activate an application by bundle identifier
    private func activateApp(bundleId: String) async throws -> Bool {
        let params: [String: Value] = [
            "action": .string("activateApplication"),
            "bundleIdentifier": .string(bundleId)
        ]
        
        let result = try await toolChain.applicationManagementTool.handler(params)
        
        // Check if activation was successful
        if let content = result.first, case .text(let text) = content {
            print("Activation result: \(text)")
            return text.contains("success") && text.contains("true")
        }
        
        return false
    }
    
    /// Terminate an application by bundle identifier
    private func terminateApp(bundleId: String) async throws -> Bool {
        let params: [String: Value] = [
            "action": .string("terminate"),
            "bundleIdentifier": .string(bundleId)
        ]
        
        let result = try await toolChain.applicationManagementTool.handler(params)
        
        // Check if termination was successful
        if let content = result.first, case .text(let text) = content {
            print("Termination result: \(text)")
            return text.contains("success") && text.contains("true")
        }
        
        return false
    }
    
    /// Get the frontmost application
    private func getFrontmostApp() async throws -> ApplicationInfo? {
        let params: [String: Value] = [
            "action": .string("getFrontmostApplication")
        ]
        
        let result = try await toolChain.applicationManagementTool.handler(params)
        
        // Parse the response to get application info
        if let content = result.first, case .text(let text) = content {
            // Extract application info from the JSON response
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bundleId = json["bundleIdentifier"] as? String,
               let appName = json["applicationName"] as? String {
                
                return ApplicationInfo(
                    bundleIdentifier: bundleId,
                    applicationName: appName
                )
            }
        }
        
        return nil
    }
    
    /// Get count of windows for an application
    private func getWindowCount(bundleId: String) async throws -> Int {
        // Use window management tool to get the application windows
        let windowParams: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string(bundleId),
            "includeMinimized": .bool(true)
        ]
        
        let result = try await toolChain.windowManagementTool.handler(windowParams)
        
        // Extract window count from result
        if let content = result.first, case .text(let text) = content {
            print("Window management result: \(text)")
            
            // Parse the JSON for window information
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                // The result directly contains an array of window descriptors
                return json.count
            }
        }
        
        return 0
    }
}

/// Simple struct to hold application information
struct ApplicationInfo {
    let bundleIdentifier: String
    let applicationName: String
}