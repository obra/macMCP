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
            configuration: [:]
        )
    }
    
    // Helper to verify a path is fully qualified
    private func verifyFullyQualifiedPath(_ path: String?) {
        guard let path = path else {
            XCTFail("Path is nil")
            return
        }
        XCTAssertTrue(path.hasPrefix("ui://"), "Path doesn't start with ui://: \(path)")
        XCTAssertTrue(path.contains("AXApplication"), "Path doesn't include AXApplication: \(path)")
        XCTAssertTrue(path.contains("/"), "Path doesn't contain hierarchy separators: \(path)")
        let separatorCount = path.components(separatedBy: "/").count - 1
        XCTAssertGreaterThanOrEqual(separatorCount, 1, "Path doesn't have enough segments: \(path)")
    }

    // Helper to run a request, verify, and always attempt a click
    private func runRequestAndVerify(
        _ request: [String: Value],
        extraAssertions: ((EnhancedElementDescriptor) -> Void)? = nil
    ) async throws {
        let response = try await interfaceExplorerTool.handler(request)
        guard case .text(let jsonString) = response.first else {
            XCTFail("Failed to get valid response from tool")
            return
        }
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        let descriptors = try decoder.decode([EnhancedElementDescriptor].self, from: jsonData)
        XCTAssertFalse(descriptors.isEmpty, "No elements returned")
        for descriptor in descriptors {
            verifyFullyQualifiedPath(descriptor.path)
            extraAssertions?(descriptor)
            print("Element path: \(descriptor.path ?? "nil")")
            if let children = descriptor.children {
                for child in children {
                    verifyFullyQualifiedPath(child.path)
                }
            }
        }
        // Always attempt a click if any element is found
        if let first = descriptors.first, let path = first.path {
            try await uiInteractionService.clickElementByPath(path: path, appBundleId: nil)
        }
    }
/*
    func testNoFilteringFullPaths() async throws {
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10)
        ]
        try await runRequestAndVerify(request)
    }
*/
    func testRoleFilteringFullPaths() async throws {
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "filter": .object([
                "role": .string("AXButton"),
                "description": .string("1")
            ])
        ]
        try await runRequestAndVerify(request) { descriptor in
            XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
        }
    }

    func testElementTypeFilteringFullPaths() async throws {
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "elementTypes": .array([.string("button")]),
            "filter": .object([
                "description": .string("2")
            ])
        ]
        try await runRequestAndVerify(request)
    }

    func testAttributeFilteringFullPaths() async throws {
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "filter": .object([
                "description": .string("3")
            ])
        ]
        try await runRequestAndVerify(request) { descriptor in
            XCTAssertTrue(descriptor.description?.contains("3") ?? false, "Element doesn't match filter criteria")
        }
    }

    func testCombinedFilteringFullPaths() async throws {
        let request: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10),
            "elementTypes": .array([.string("button")]),
            "filter": .object([
                "description": .string("4")
            ])
        ]
        try await runRequestAndVerify(request) { descriptor in
            XCTAssertEqual(descriptor.role, "AXButton", "Non-button element returned")
            XCTAssertTrue(descriptor.description?.contains("4") ?? false, "Element doesn't match description criteria")
        }
    }
}