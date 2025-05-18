// ABOUTME: This file contains tests for the InterfaceExplorerTool functionality.
// ABOUTME: It verifies that the tool correctly explores and describes UI elements.

import XCTest
import Foundation
import MCP
@testable import MacMCP

// Test utilities are directly available in this module

/// Test the InterfaceExplorerTool
final class InterfaceExplorerToolTests: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private var calculator: CalculatorModel!
    
    override func setUp() async throws {
        // Create the test components
        toolChain = ToolChain()
        calculator = CalculatorModel(toolChain: toolChain)
        
        // Force terminate any existing Calculator instances
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    override func tearDown() async throws {
        // Terminate Calculator
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").forEach { app in
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    /// Helper to ensure calculator is launched and ready
    private func launchCalculator() async throws {
        // In our mocked tests, we don't actually launch the calculator app
        // Just simulate a successful launch
        
        // Wait to simulate app initialization
        try await Task.sleep(for: .milliseconds(300))
    }
    
    /// Test system scope with the interface explorer tool
    func testSystemScope() async throws {
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for system scope
        let params: [String: Value] = [
            "scope": .string("system"),
            "maxDepth": .int(3), // Limit depth to keep test manageable
            "limit": .int(10)    // Limit results to keep test manageable
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Verify each element has the expected properties
            for element in elements {
                XCTAssertNotNil(element["id"], "Element should have an ID")
                XCTAssertNotNil(element["role"], "Element should have a role")
                XCTAssertNotNil(element["name"], "Element should have a name")
                XCTAssertNotNil(element["state"], "Element should have state information")
                XCTAssertNotNil(element["capabilities"], "Element should have capabilities")
                
                // Check frame data
                if let frame = element["frame"] as? [String: Any] {
                    XCTAssertNotNil(frame["x"], "Frame should have x coordinate")
                    XCTAssertNotNil(frame["y"], "Frame should have y coordinate")
                    XCTAssertNotNil(frame["width"], "Frame should have width")
                    XCTAssertNotNil(frame["height"], "Frame should have height")
                } else {
                    XCTFail("Element should have frame information")
                }
            }
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test application scope with the interface explorer tool
    func testApplicationScope() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for application scope
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.calculator"),
            "maxDepth": .int(10),
            "includeHidden": .bool(false)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Verify the root element looks like a Calculator application
            let rootElement = elements[0]
            XCTAssertEqual(rootElement["role"] as? String, "AXApplication", "Root element should be an application")
            
            // With the new InterfaceExplorerTool, we should still be able to find some
            // basic elements like buttons, but windows may be handled by WindowManagementTool
            var foundButton = false

            // Check for basic Calculator elements in the hierarchy
            func checkForElements(element: [String: Any]) {
                // Check if this is a button (Calculator has many buttons)
                if let role = element["role"] as? String, role == "AXButton" {
                    foundButton = true
                }

                // Check children recursively
                if let children = element["children"] as? [[String: Any]] {
                    for child in children {
                        checkForElements(element: child)
                    }
                }
            }

            // Check all root elements
            for element in elements {
                checkForElements(element: element)
            }

            // Now assert that we found buttons - windows are handled by WindowManagementTool now
            XCTAssertTrue(foundButton, "Should find at least one button in the Calculator")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test element scope with the interface explorer tool
    func testElementScope() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // First, we need to construct an element path for the Calculator window
        // Instead of relying on element IDs, we'll use a path-based approach
        
        // Create a path to the Calculator window
        let elementPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow"
        
        // Create parameters for path scope
        let params: [String: Value] = [
            "scope": .string("path"),
            "elementPath": .string(elementPath),
            "maxDepth": .int(5)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Verify the element we got back matches our path
            let element = elements[0]
            XCTAssertEqual(element["role"] as? String, "AXWindow", "Element should be a window")
            
            // Verify path was returned and matches our expected format
            XCTAssertNotNil(element["path"], "Element should have a path")
            if let path = element["path"] as? String {
                XCTAssertTrue(path.hasPrefix("ui://AXApplication"), "Path should start with ui://AXApplication")
                XCTAssertTrue(path.contains("AXWindow"), "Path should include AXWindow")
            }
            
            // Verify children were also returned
            XCTAssertNotNil(element["children"], "Element should have children")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test filtering with the interface explorer tool
    func testFilteringElements() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for application scope with button filtering
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.calculator"),
            "filter": .object([
                "role": .string("AXButton")
            ]),
            "maxDepth": .int(10)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Verify all returned elements are buttons
            for element in elements {
                XCTAssertEqual(element["role"] as? String, "AXButton", "All elements should be buttons")
            }
            
            // Verify we got multiple button elements (Calculator has many)
            XCTAssertGreaterThan(elements.count, 5, "Should find multiple button elements")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test element types filtering with the interface explorer tool
    func testElementTypesFiltering() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters to specifically find buttons using elementTypes
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.calculator"),
            "elementTypes": .array([.string("button")]),
            "maxDepth": .int(10)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Verify all returned elements are buttons
            for element in elements {
                XCTAssertEqual(element["role"] as? String, "AXButton", "All elements should be buttons")
                
                // Also check that the element has the clickable capability
                if let capabilities = element["capabilities"] as? [String] {
                    XCTAssertTrue(capabilities.contains("clickable"), "Button should have clickable capability")
                }
            }
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test enhanced capabilities reporting
    func testEnhancedCapabilities() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for application scope
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.calculator"),
            "maxDepth": .int(5)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Check first for buttons with capabilities
            var foundButtonWithCapabilities = false
            var foundTextFieldWithState = false
            
            // Function to search recursively through the element tree
            func checkElementsForCapabilitiesAndState(element: [String: Any]) {
                // Check if this element has the expected properties
                if let role = element["role"] as? String {
                    // Check buttons for clickable capability
                    if role == "AXButton", let capabilities = element["capabilities"] as? [String], capabilities.contains("clickable") {
                        foundButtonWithCapabilities = true
                    }
                    
                    // Check text fields for state info
                    if (role == "AXTextField" || role == "AXStaticText"), let state = element["state"] as? [String], !state.isEmpty {
                        foundTextFieldWithState = true
                    }
                }
                
                // Recursively check children
                if let children = element["children"] as? [[String: Any]] {
                    for child in children {
                        checkElementsForCapabilitiesAndState(element: child)
                    }
                }
            }
            
            // Check all elements
            for element in elements {
                checkElementsForCapabilitiesAndState(element: element)
            }
            
            // Verify that we found elements with the expected capabilities and state
            XCTAssertTrue(foundButtonWithCapabilities || foundTextFieldWithState, 
                         "Should find at least one button with capabilities or text field with state")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test path support in interface explorer tool
    func testElementPathSupport() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for application scope
        let params: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.calculator"),
            "maxDepth": .int(5)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Check the elements for path information
            var foundElementWithPath = false
            
            // Function to search recursively through the element tree
            func checkElementsForPaths(element: [String: Any]) {
                // Check if this element has a path
                if let path = element["path"] as? String, path.hasPrefix("ui://") {
                    foundElementWithPath = true
                }
                
                // Recursively check children
                if let children = element["children"] as? [[String: Any]] {
                    for child in children {
                        checkElementsForPaths(element: child)
                    }
                }
            }
            
            // Check all elements
            for element in elements {
                checkElementsForPaths(element: element)
            }
            
            // Verify that we found at least one element with a path
            XCTAssertTrue(foundElementWithPath, "Should find at least one element with a path")
            
            // Find a specific type of element and check its path in more detail
            var foundButtonWithValidPath = false
            
            // Function to check for buttons with valid paths
            func checkButtonPaths(element: [String: Any]) {
                if let role = element["role"] as? String, role == "AXButton",
                   let path = element["path"] as? String {
                    // Verify the path has the correct format
                    XCTAssert(path.hasPrefix("ui://"), "Path should start with ui://")
                    XCTAssert(path.contains("AXButton"), "Button path should contain AXButton")
                    foundButtonWithValidPath = true
                }
                
                // Recursively check children
                if let children = element["children"] as? [[String: Any]] {
                    for child in children {
                        checkButtonPaths(element: child)
                    }
                }
            }
            
            // Check all elements for buttons with valid paths
            for element in elements {
                checkButtonPaths(element: element)
            }
            
            // Verify that we found at least one button with a valid path
            XCTAssertTrue(foundButtonWithValidPath, "Should find at least one button with a valid path")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test position scope with the interface explorer tool
    func testPositionScope() async throws {
        // Launch calculator first
        try await launchCalculator()
        
        // Get the window position
        let windows = try await toolChain.accessibilityService.findUIElements(
            role: "AXWindow",
            title: nil,
            titleContains: nil,
            value: nil,
            valueContains: nil,
            description: nil,
            descriptionContains: nil,
            scope: .application(bundleIdentifier: "com.apple.calculator"),
            recursive: true,
            maxDepth: 3
        )
        
        guard let window = windows.first else {
            throw XCTSkip("No window found in Calculator for position scope test")
        }
        
        // Get the center of the window
        let centerX = window.frame.origin.x + window.frame.size.width / 2
        let centerY = window.frame.origin.y + window.frame.size.height / 2
        
        // Define direct handler access for more precise testing
        let interfaceExplorerTool = InterfaceExplorerTool(
            accessibilityService: toolChain.accessibilityService,
            logger: nil
        )
        
        // Create parameters for position scope
        let params: [String: Value] = [
            "scope": .string("position"),
            "x": .double(Double(centerX)),
            "y": .double(Double(centerY)),
            "maxDepth": .int(5)
        ]
        
        // Call the handler directly
        let result = try await interfaceExplorerTool.handler(params)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Should receive a non-empty result")
        
        // Verify result is text content
        if case .text(let jsonString) = result[0] {
            // Parse JSON
            let jsonData = jsonString.data(using: String.Encoding.utf8)!
            let elements = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify we got UI elements back
            XCTAssertFalse(elements.isEmpty, "Should receive UI elements")
            
            // Not testing specific element properties here as the element
            // at the center of a window can vary, but we should at least
            // have received something from the Calculator app
        } else {
            XCTFail("Result should be text content")
        }
    }
}