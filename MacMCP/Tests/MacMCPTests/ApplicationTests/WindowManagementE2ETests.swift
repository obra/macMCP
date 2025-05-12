// ABOUTME: This file contains end-to-end tests for the WindowManagementTool.
// ABOUTME: It verifies that window operations work correctly with real macOS applications.

import XCTest
import Foundation
import MCP
import AppKit
import Logging
@testable import MacMCP

/// End-to-end tests for the WindowManagementTool
final class WindowManagementE2ETests: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private var calculator: CalculatorModel!
    
    override func setUp() async throws {
        try await super.setUp()

        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        
        // Force terminate any existing Calculator instances
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
        
        // Launch calculator for the tests
        let launchSuccess = try await calculator.launch()
        XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
        
        // Wait for the app to fully initialize
        try await Task.sleep(for: .milliseconds(2000))
    }
    
    override func tearDown() async throws {
        // Terminate Calculator
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
        
        calculator = nil
        toolChain = nil

        try await super.tearDown()
    }
    
    /// Test getting application windows
    func testGetApplicationWindows() async throws {
        // Create parameters
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        // Execute the test
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Parse the result JSON to verify content
        if case .text(let jsonString) = result[0] {
            // Parse the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify window count
            XCTAssertGreaterThanOrEqual(json.count, 1, "Should have at least 1 window")
            
            // Verify window properties
            let window = json[0]
            XCTAssertNotNil(window["id"], "Window should have an ID")
            XCTAssertEqual(window["role"] as? String, "AXWindow", "Role should be AXWindow")
            
            // Save window ID for other tests
            if let windowId = window["id"] as? String {
                calculator.windowId = windowId
            }
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test moving a window
    func testMoveWindow() async throws {
        // First ensure we have the calculator window ID
        guard let windowId = try await getCalculatorWindowId() else {
            XCTFail("Failed to get calculator window ID")
            return
        }
        
        // Create parameters to move the window to a specific position
        let params: [String: Value] = [
            "action": .string("moveWindow"),
            "windowId": .string(windowId),
            "x": .double(200),
            "y": .double(200)
        ]
        
        // Execute the test
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Parse the result JSON to verify content
        if case .text(let jsonString) = result[0] {
            // Verify the response format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Should indicate success")
            
            // Wait for UI to update
            try await Task.sleep(for: .milliseconds(1000))
            
            // Get the window position to verify it moved
            let windowInfo = try await getWindowPosition(windowId: windowId)
            
            // Verify the position (allow some tolerance for window management adjustments)
            XCTAssertNotNil(windowInfo, "Should get window information")
            if let info = windowInfo {
                let frame = info["frame"] as! [String: Any]
                let x = frame["x"] as! CGFloat
                let y = frame["y"] as! CGFloat
                
                // Use approximate comparison with tolerance
                XCTAssertEqual(x, 200, accuracy: 20, "X position should be approximately 200")
                XCTAssertEqual(y, 200, accuracy: 20, "Y position should be approximately 200")
            }
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test resizing a window
    func testResizeWindow() async throws {
        // First ensure we have the calculator window ID
        guard let windowId = try await getCalculatorWindowId() else {
            XCTFail("Failed to get calculator window ID")
            return
        }
        
        // Create parameters to resize the window
        let params: [String: Value] = [
            "action": .string("resizeWindow"),
            "windowId": .string(windowId),
            "width": .double(400),
            "height": .double(500)
        ]
        
        // Execute the test
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Parse the result JSON to verify content
        if case .text(let jsonString) = result[0] {
            // Verify the response format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Should indicate success")
            
            // Wait for UI to update
            try await Task.sleep(for: .milliseconds(1000))
            
            // Get the window size to verify it resized
            let windowInfo = try await getWindowPosition(windowId: windowId)
            
            // Verify the size (allow some tolerance for window management adjustments)
            XCTAssertNotNil(windowInfo, "Should get window information")
            if let info = windowInfo {
                let frame = info["frame"] as! [String: Any]
                let width = frame["width"] as! CGFloat
                let height = frame["height"] as! CGFloat
                
                // Use approximate comparison with tolerance
                XCTAssertEqual(width, 400, accuracy: 20, "Width should be approximately 400")
                XCTAssertEqual(height, 500, accuracy: 20, "Height should be approximately 500")
            }
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test minimizing and activating a window
    func testMinimizeAndActivateWindow() async throws {
        // First ensure we have the calculator window ID
        guard let windowId = try await getCalculatorWindowId() else {
            XCTFail("Failed to get calculator window ID")
            return
        }
        
        // Create parameters to minimize the window
        let minimizeParams: [String: Value] = [
            "action": .string("minimizeWindow"),
            "windowId": .string(windowId)
        ]
        
        // Execute the minimize test
        let minimizeResult = try await toolChain.windowManagementTool.handler(minimizeParams)
        
        // Verify the result
        XCTAssertEqual(minimizeResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = minimizeResult[0] {
            // Verify the response format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Should indicate success")
            
            // Wait for UI to update
            try await Task.sleep(for: .milliseconds(1000))
            
            // Verify the window is minimized
            let isVisible = try await isWindowVisible(windowId: windowId)
            XCTAssertFalse(isVisible, "Window should be minimized/not visible")
            
            // Now activate the window
            let activateParams: [String: Value] = [
                "action": .string("activateWindow"),
                "windowId": .string(windowId)
            ]
            
            // Execute the activate test
            let activateResult = try await toolChain.windowManagementTool.handler(activateParams)
            
            // Verify the result
            XCTAssertEqual(activateResult.count, 1, "Should return one content item")
            
            if case .text(let activateJsonString) = activateResult[0] {
                // Verify the response format
                XCTAssertTrue(activateJsonString.contains("\"success\":true"), "Should indicate success")
                
                // Wait for UI to update
                try await Task.sleep(for: .milliseconds(1500))
                
                // Verify the window is visible again
                let isVisibleAfterActivate = try await isWindowVisible(windowId: windowId)
                XCTAssertTrue(isVisibleAfterActivate, "Window should be visible after activation")
            } else {
                XCTFail("Activate result should be text content")
            }
        } else {
            XCTFail("Minimize result should be text content")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the Calculator window ID
    private func getCalculatorWindowId() async throws -> String? {
        // Create parameters
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        // Execute the query
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Parse the result JSON
        if case .text(let jsonString) = result[0] {
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Get the first window ID
            if json.count > 0, let windowId = json[0]["id"] as? String {
                return windowId
            }
        }
        
        return nil
    }
    
    /// Get window position and size information
    private func getWindowPosition(windowId: String) async throws -> [String: Any]? {
        // First get all calculator windows
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        // Execute the query
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Parse the result JSON
        if case .text(let jsonString) = result[0] {
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Find the window with the matching ID
            for window in json {
                if let id = window["id"] as? String, id == windowId {
                    return window
                }
            }
        }
        
        return nil
    }
    
    /// Check if a window is visible
    private func isWindowVisible(windowId: String) async throws -> Bool {
        // Get the window information
        let windowInfo = try await getWindowPosition(windowId: windowId)
        
        // Check if it's visible
        if let info = windowInfo {
            return !(info["isMinimized"] as? Bool ?? false)
        }
        
        // If we can't find the window, assume it's not visible
        return false
    }
}