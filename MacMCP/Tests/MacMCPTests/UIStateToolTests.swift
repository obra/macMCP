import XCTest
import Testing
import Foundation
import MCP

@testable import MacMCP

@Suite("UI State Tool Tests")
struct UIStateToolTests {
    @Test("UIStateTool initialization and schema")
    func testUIStateToolInitialization() {
        let tool = UIStateTool(accessibilityService: MockAccessibilityService())
        
        #expect(tool.name == "macos/ui_state")
        #expect(tool.description.contains("Get the current UI state"))
        #expect(tool.inputSchema != nil)
        #expect(tool.annotations.readOnlyHint == true)
    }
    
    @Test("Get UI state with system scope")
    func testGetUIStateWithSystemScope() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create input params with system scope
        let input: [String: Value] = [
            "scope": .string("system"),
            "maxDepth": .int(2)
        ]
        
        // Call the tool handler
        let result = try await tool.handler(input)
        
        // Verify the result
        #expect(result.count == 1)
        if case .text(let json) = result[0] {
            #expect(json.contains("system"))
            #expect(json.contains("children"))
        } else {
            XCTFail("Expected text result")
        }
    }
    
    @Test("Get UI state with application scope")
    func testGetUIStateWithApplicationScope() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create input params with application scope
        let input: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string("com.apple.finder")
        ]
        
        // Call the tool handler
        let result = try await tool.handler(input)
        
        // Verify the result
        #expect(result.count == 1)
        if case .text(let json) = result[0] {
            #expect(json.contains("com.apple.finder"))
            #expect(json.contains("Finder"))
        } else {
            XCTFail("Expected text result")
        }
    }
    
    @Test("Get UI state with focused application scope")
    func testGetUIStateWithFocusedApplicationScope() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create input params with focused app scope
        let input: [String: Value] = [
            "scope": .string("focused")
        ]
        
        // Call the tool handler
        let result = try await tool.handler(input)
        
        // Verify the result
        #expect(result.count == 1)
        if case .text(let json) = result[0] {
            #expect(json.contains("focused"))
        } else {
            XCTFail("Expected text result")
        }
    }
    
    @Test("Get UI element at position")
    func testGetUIElementAtPosition() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create input params for position query
        let input: [String: Value] = [
            "scope": .string("position"),
            "x": .int(100),
            "y": .int(200)
        ]
        
        // Call the tool handler
        let result = try await tool.handler(input)
        
        // Verify the result
        #expect(result.count == 1)
        if case .text(let json) = result[0] {
            #expect(json.contains("position"))
            #expect(json.contains("x"))
            #expect(json.contains("y"))
        } else {
            XCTFail("Expected text result")
        }
    }
    
    @Test("Get UI state with element filter")
    func testGetUIStateWithElementFilter() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create input params with filter criteria
        let input: [String: Value] = [
            "scope": .string("system"),
            "filter": .object([
                "role": .string("AXButton"),
                "titleContains": .string("OK")
            ])
        ]
        
        // Call the tool handler
        let result = try await tool.handler(input)
        
        // Verify the result
        #expect(result.count == 1)
        if case .text(let json) = result[0] {
            #expect(json.contains("AXButton"))
        } else {
            XCTFail("Expected text result")
        }
    }
    
    @Test("Error handling for invalid parameters")
    func testErrorHandlingForInvalidParameters() async throws {
        let mockService = MockAccessibilityService()
        let tool = UIStateTool(accessibilityService: mockService)
        
        // Create invalid input params (missing required fields)
        let input: [String: Value] = [
            "scope": .string("invalid_scope")
        ]
        
        // Call the tool handler, which should throw an error
        do {
            let _ = try await tool.handler(input)
            XCTFail("Expected error not thrown")
        } catch {
            // Successfully caught error
            #expect(true)
        }
    }
}

/// Mock accessibility service for testing
final class MockAccessibilityService: AccessibilityServiceProtocol, @unchecked Sendable {
    func getSystemUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return UIElement(
            identifier: "system",
            role: "AXSystemWide",
            title: "System",
            frame: .zero,
            children: [
                UIElement(
                    identifier: "child1",
                    role: "AXApplication",
                    title: "App1",
                    frame: .zero
                ),
                UIElement(
                    identifier: "child2",
                    role: "AXApplication",
                    title: "App2",
                    frame: .zero
                )
            ]
        )
    }
    
    func getApplicationUIElement(bundleIdentifier: String, recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return UIElement(
            identifier: bundleIdentifier,
            role: "AXApplication",
            title: bundleIdentifier == "com.apple.finder" ? "Finder" : "App",
            frame: .zero,
            children: [
                UIElement(
                    identifier: "window1",
                    role: "AXWindow",
                    title: "Window 1",
                    frame: .zero
                )
            ]
        )
    }
    
    func getFocusedApplicationUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return UIElement(
            identifier: "focused-app",
            role: "AXApplication",
            title: "Focused App",
            frame: .zero
        )
    }
    
    func getUIElementAtPosition(position: CGPoint, recursive: Bool, maxDepth: Int) async throws -> UIElement? {
        return UIElement(
            identifier: "element-at-position",
            role: "AXElement",
            title: "Element at position \(position.x),\(position.y)",
            frame: CGRect(x: position.x, y: position.y, width: 50, height: 30)
        )
    }
    
    func findUIElements(
        role: String?,
        titleContains: String?,
        scope: UIElementScope,
        recursive: Bool,
        maxDepth: Int
    ) async throws -> [UIElement] {
        var elements: [UIElement] = []
        
        if role == "AXButton" {
            elements.append(
                UIElement(
                    identifier: "button1",
                    role: "AXButton",
                    title: "OK Button",
                    frame: .zero
                )
            )
        }
        
        return elements
    }
}