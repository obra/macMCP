// ABOUTME: This file contains end-to-end tests for UI state inspection using the macOS Calculator.
// ABOUTME: It validates that MacMCP can correctly retrieve UI state information from real applications.

import XCTest
import Foundation
import MCP
@testable import MacMCP

final class UIStateInspectionE2ETests: XCTestCase {
    // The Calculator app instance used for testing
    @MainActor static var calculator: CalculatorApp?
    
    // The UI state tool for inspection
    @MainActor static var uiStateTool: UIStateTool?
    
    // Setup - runs before all tests in the suite
    override class func setUp() {
        super.setUp()
        
        // Launch the Calculator app in a task
        Task { @MainActor in
            do {
                // Create the Calculator app and UI state tool
                calculator = CalculatorApp()
                let accessibilityService = AccessibilityService()
                uiStateTool = UIStateTool(accessibilityService: accessibilityService)
                
                // Launch the Calculator app
                _ = try await calculator?.launch()
                
                // Brief pause to ensure UI is fully loaded
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                XCTFail("Failed to set up Calculator app: \(error)")
            }
        }
    }
    
    // Teardown - runs after all tests in the suite
    override class func tearDown() {
        // Terminate the Calculator app
        Task { @MainActor in
            do {
                _ = try await calculator?.terminate()
                calculator = nil
                uiStateTool = nil
            } catch {
                print("Error during teardown: \(error)")
            }
        }
        
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    // Get Calculator UI state with application scope
    @MainActor
    func testGetCalculatorUIState() async throws {
        guard let _ = Self.calculator, let uiStateTool = Self.uiStateTool else {
            throw XCTSkip("Calculator app or UI state tool not available")
        }
        
        // Create input params with application scope
        let input: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(CalculatorApp.bundleId)
        ]
        
        // Call the tool handler
        let result = try await uiStateTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .text(let json) = result[0] {
            // Check that the JSON contains Calculator-specific information
            XCTAssertTrue(json.contains(CalculatorApp.bundleId), "JSON should contain Calculator bundle ID")
            XCTAssertTrue(json.contains("Calculator"), "JSON should contain 'Calculator' string")
            
            // Check that the JSON includes window elements
            XCTAssertTrue(json.contains("AXWindow"), "JSON should contain window elements")
            
            // Check for common Calculator UI elements
            let containsButtons = json.contains("AXButton") || 
                                 json.contains("button") || 
                                 json.contains("Button")
            XCTAssertTrue(containsButtons, "JSON should contain calculator buttons")
            
            // Check for display element
            let containsDisplay = json.contains("AXStaticText") || 
                                 json.contains("AXTextField") || 
                                 json.contains("Display")
            XCTAssertTrue(containsDisplay, "JSON should contain display element")
        } else {
            XCTFail("Expected text result")
        }
    }
    
    // Find Calculator display element
    @MainActor
    func testFindCalculatorDisplayElement() async throws {
        guard let _ = Self.calculator, let uiStateTool = Self.uiStateTool else {
            throw XCTSkip("Calculator app or UI state tool not available")
        }
        
        // Create input params with filter to find text elements
        let input: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(CalculatorApp.bundleId),
            "filter": .object([
                "role": .string("AXStaticText")
                // No title filter to catch more potential matches
            ])
        ]
        
        // Call the tool handler
        let result = try await uiStateTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .text(let json) = result[0] {
            // Check that the JSON contains static text elements
            XCTAssertTrue(json.contains("AXStaticText"), "JSON should contain static text elements")
            
            // Usually one of these will be the display element
            print("Found static text elements in Calculator: \(json)")
        } else {
            XCTFail("Expected text result")
        }
    }
    
    // Get element at Calculator button position
    @MainActor
    func testGetElementAtButtonPosition() async throws {
        guard let calculator = Self.calculator, let uiStateTool = Self.uiStateTool else {
            throw XCTSkip("Calculator app or UI state tool not available")
        }
        
        // Get the main window to find its position
        guard let window = try await calculator.getMainWindow() else {
            XCTFail("Failed to get Calculator main window")
            return
        }
        
        // Try to get position of a button (e.g., "5" button)
        guard let buttonFive = try await calculator.getButton(identifier: "5") else {
            XCTFail("Failed to find '5' button in Calculator")
            return
        }
        
        // Get position in the middle of the button
        let x = Int(buttonFive.frame.origin.x + buttonFive.frame.size.width / 2)
        let y = Int(buttonFive.frame.origin.y + buttonFive.frame.size.height / 2)
        
        // Create input params for position query
        let input: [String: Value] = [
            "scope": .string("position"),
            "x": .int(x),
            "y": .int(y)
        ]
        
        // Call the tool handler
        let result = try await uiStateTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .text(let json) = result[0] {
            // The element should be a button or contain the digit 5
            let isButton = json.contains("AXButton") || json.contains("button")
            let containsFive = json.contains("\"5\"") || json.contains("\"title\" : \"5\"")
            
            // Print the result for debugging
            print("Element at position (\(x), \(y)): \(json)")
            
            // We consider the test passed if we got either a button or something with "5"
            // in it, since different macOS versions may report different elements
            XCTAssertTrue(isButton || containsFive, 
                        "Element at button position should be a button or contain '5'")
        } else {
            XCTFail("Expected text result")
        }
    }
    
    // Get UI hierarchy depth
    @MainActor
    func testGetUIHierarchyDepth() async throws {
        guard let _ = Self.calculator, let uiStateTool = Self.uiStateTool else {
            throw XCTSkip("Calculator app or UI state tool not available")
        }
        
        // Get Calculator UI with different depths
        let depths = [1, 2, 3]
        
        for depth in depths {
            // Create input params with specified max depth
            let input: [String: Value] = [
                "scope": .string("application"),
                "bundleId": .string(CalculatorApp.bundleId),
                "maxDepth": .int(depth)
            ]
            
            // Call the tool handler
            let result = try await uiStateTool.handler(input)
            
            // Verify the result
            XCTAssertEqual(result.count, 1, "Expected 1 result item")
            
            if case .text(let json) = result[0] {
                // For depth 1, we should have limited child elements
                if depth == 1 {
                    // Fewer occurrences of "children" at depth 1
                    let childrenCount = json.components(separatedBy: "children").count - 1
                    print("Depth \(depth) children count: \(childrenCount)")
                    
                    // We expect at most a few children at depth 1
                    XCTAssertLessThan(childrenCount, 10, 
                                    "Depth 1 should have limited child elements")
                }
                
                // For depth 3, we should have more child elements
                if depth == 3 {
                    // More occurrences of "children" at depth 3
                    let childrenCount = json.components(separatedBy: "children").count - 1
                    print("Depth \(depth) children count: \(childrenCount)")
                    
                    // We expect more children at depth 3
                    XCTAssertGreaterThan(childrenCount, 1, 
                                       "Depth 3 should have more child elements")
                }
            } else {
                XCTFail("Expected text result")
            }
        }
    }
}