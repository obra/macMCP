// ABOUTME: Tests to verify path generation in InterfaceExplorerTool under various filtering conditions.
// ABOUTME: Validates that paths remain fully qualified regardless of filtering approach.

import XCTest
import Foundation
import MCP
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
        
        // Launch Calculator app
        app = launchCalculator()
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
    
    private func launchCalculator() -> NSRunningApplication? {
        let calcURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: calculatorBundleId)
        guard let url = calcURL else {
            XCTFail("Could not find Calculator app")
            return nil
        }
        
        return try? NSWorkspace.shared.launchApplication(
            at: url,
            options: .default,
            configuration: [:]
        )
    }
    
    func testNoFilteringFullPaths() async throws {
        // Get app element with no filtering
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10)
        ]
        
        // Process request through tool
        let response = try await interfaceExplorerTool.handler(request)
        
        // Extract result from tool response
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        
        // Decode response
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        
        // Verify paths
        XCTAssertFalse(descriptors.isEmpty, "No elements returned")
        
        // Check all paths are fully qualified
        for descriptor in descriptors {
            verifyFullyQualifiedPath(descriptor.path)
            
            // Also check children if available
            if let children = descriptor.children {
                for child in children {
                    verifyFullyQualifiedPath(child.path)
                }
            }
        }
    }

    // Helper to verify a path is fully qualified
    private func verifyFullyQualifiedPath(_ path: String?) {
        guard let path = path else {
            XCTFail("Path is nil")
            return
        }
        
        // Check path starts with ui://
        XCTAssertTrue(path.hasPrefix("ui://"), "Path doesn't start with ui://: \(path)")
        
        // Check path has AXApplication as first element
        XCTAssertTrue(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
        
        // Check path contains hierarchy separators
        XCTAssertTrue(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
        
        // Count separators - should have at least 1 (Application/Something)
        let separatorCount = path.components(separatedBy: "/").count - 1
        XCTAssertGreaterThanOrEqual(separatorCount, 1, "Path doesn't have enough segments: \(path)")
    }
    
    func testRoleFilteringFullPaths() async throws {
        // Filter for numeric button "1" specifically
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "filter": .object([
                "role": .string("AXButton"),
                "descriptionContains": .string("1")
            ])
        ]
        
        // Process request through tool
        let response = try await interfaceExplorerTool.handler(request)
        
        // Extract and decode result
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        
        // Decode response
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        
        // Verify results
        XCTAssertFalse(descriptors.isEmpty, "No buttons found")
        
        // Verify all results are buttons with fully qualified paths
        for descriptor in descriptors {
            XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
            verifyFullyQualifiedPath(descriptor.path)
            
            // Log paths to help with debugging
            print("Button path: \(descriptor.path ?? "nil")")
        }
        
        // Test interaction with at least one element if available
        if let firstButton = descriptors.first, let path = firstButton.path {
            // Try to interact with the button
            try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
            // If we got here without an exception, the path worked
        }
    }
    
    func testElementTypeFilteringFullPaths() async throws {
        // Filter by element type and specific description
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "elementTypes": .array([.string("button")]),
            "filter": .object([
                "descriptionContains": .string("1")
            ])
        ]
        
        // Process request through tool
        let response = try await interfaceExplorerTool.handler(request)
        
        // Extract and decode result
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        
        // Decode response
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        
        // Verify results
        XCTAssertFalse(descriptors.isEmpty, "No buttons found with elementTypes filtering")
        
        // Verify all results have fully qualified paths
        for descriptor in descriptors {
            verifyFullyQualifiedPath(descriptor.path)
            
            // Log paths to help with debugging
            print("Element path with elementTypes filtering: \(descriptor.path ?? "nil")")
        }
        
        // Test interaction with the first element
        if let firstElement = descriptors.first, let path = firstElement.path {
            try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
        }
    }
    
    func testAttributeFilteringFullPaths() async throws {
        // Filter by description attribute to find numeric buttons
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "filter": .object([
                "descriptionContains": .string("1") // Look for button "1"
            ])
        ]
        
        // Process request through tool
        let response = try await interfaceExplorerTool.handler(request)
        
        // Extract and decode result
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        
        // Decode response
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        
        // Verify results
        XCTAssertFalse(descriptors.isEmpty, "No elements found with description filter")
        
        // Verify all results have fully qualified paths
        for descriptor in descriptors {
            verifyFullyQualifiedPath(descriptor.path)
            XCTAssertTrue(descriptor.description?.contains("1") ?? false, 
                         "Element doesn't match filter criteria")
            
            // Log paths to help with debugging
            print("Element path with attribute filtering: \(descriptor.path ?? "nil")")
        }
        
        // Test interaction with the first matching element
        if let firstElement = descriptors.first, let path = firstElement.path {
            try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
        }
    }
    
    func testCombinedFilteringFullPaths() async throws {
        // Combine multiple filter types
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "elementTypes": .array([.string("button")]),
            "filter": .object([
                "descriptionContains": .string("1")
            ])
        ]
        
        // Process request through tool
        let response = try await interfaceExplorerTool.handler(request)
        
        // Extract and decode result
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        
        // Decode response
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        
        // Verify results
        XCTAssertFalse(descriptors.isEmpty, "No elements found with combined filtering")
        
        // Verify all results have fully qualified paths and match criteria
        for descriptor in descriptors {
            verifyFullyQualifiedPath(descriptor.path)
            XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
            XCTAssertTrue(descriptor.description?.contains("1") ?? false, 
                         "Element doesn't match description criteria")
            
            // Log paths to help with debugging
            print("Element path with combined filtering: \(descriptor.path ?? "nil")")
        }
        
        // Test interaction with the first matching element
        if let firstElement = descriptors.first, let path = firstElement.path {
            try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
        }
    }
}