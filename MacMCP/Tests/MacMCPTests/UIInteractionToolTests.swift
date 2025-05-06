import XCTest
import Testing
import Foundation
import MCP

@testable import MacMCP

@Suite("UI Interaction Tool Tests")
struct UIInteractionToolTests {
    @Test("UIInteractionTool initialization and schema")
    func testUIInteractionToolInitialization() {
        let tool = UIInteractionTool(
            interactionService: MockUIInteractionService(),
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        #expect(tool.name == "macos/ui_interact")
        #expect(tool.description.contains("Interact with UI elements"))
        #expect(tool.inputSchema != nil)
        #expect(tool.annotations.readOnlyHint == false)
    }
    
    @Test("Click element by ID")
    func testClickElementById() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input for clicking an element by ID
        let input: [String: Value] = [
            "action": .string("click"),
            "elementId": .string("button-123")
        ]
        
        // Call the tool
        let result = try await tool.handler(input)
        
        // Verify the result indicates success
        #expect(result.count == 1)
        if case .text(let text) = result[0] {
            #expect(text.contains("Successfully clicked"))
            #expect(text.contains("button-123"))
        } else {
            XCTFail("Expected text result")
        }
        
        // Verify the mock service recorded the click
        #expect(mockInteractionService.lastClickedElementId == "button-123")
    }
    
    @Test("Click element at position")
    func testClickElementAtPosition() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input for clicking at a position
        let input: [String: Value] = [
            "action": .string("click"),
            "x": .number(100),
            "y": .number(200)
        ]
        
        // Call the tool
        let result = try await tool.handler(input)
        
        // Verify the result indicates success
        #expect(result.count == 1)
        if case .text(let text) = result[0] {
            #expect(text.contains("Successfully clicked at position"))
            #expect(text.contains("100") && text.contains("200"))
        } else {
            XCTFail("Expected text result")
        }
        
        // Verify the mock service recorded the click
        #expect(mockInteractionService.lastClickedPosition?.x == 100)
        #expect(mockInteractionService.lastClickedPosition?.y == 200)
    }
    
    @Test("Double click element")
    func testDoubleClickElement() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input for double-clicking
        let input: [String: Value] = [
            "action": .string("double_click"),
            "elementId": .string("item-456")
        ]
        
        // Call the tool
        let result = try await tool.handler(input)
        
        // Verify the result indicates success
        #expect(result.count == 1)
        if case .text(let text) = result[0] {
            #expect(text.contains("Successfully double-clicked"))
        } else {
            XCTFail("Expected text result")
        }
        
        // Verify the mock service recorded the double click
        #expect(mockInteractionService.lastDoubleClickedElementId == "item-456")
    }
    
    @Test("Right click element")
    func testRightClickElement() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input for right-clicking
        let input: [String: Value] = [
            "action": .string("right_click"),
            "elementId": .string("menu-789")
        ]
        
        // Call the tool
        let result = try await tool.handler(input)
        
        // Verify the result indicates success
        #expect(result.count == 1)
        if case .text(let text) = result[0] {
            #expect(text.contains("Successfully right-clicked"))
        } else {
            XCTFail("Expected text result")
        }
        
        // Verify the mock service recorded the right click
        #expect(mockInteractionService.lastRightClickedElementId == "menu-789")
    }
    
    @Test("Invalid action parameter")
    func testInvalidActionParameter() async throws {
        let tool = UIInteractionTool(
            interactionService: MockUIInteractionService(),
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input with invalid action
        let input: [String: Value] = [
            "action": .string("invalid_action"),
            "elementId": .string("button-123")
        ]
        
        // Should throw an error
        do {
            let _ = try await tool.handler(input)
            XCTFail("Expected error not thrown")
        } catch {
            // Successfully caught error
            #expect(true)
        }
    }
    
    @Test("Missing required parameters")
    func testMissingRequiredParameters() async throws {
        let tool = UIInteractionTool(
            interactionService: MockUIInteractionService(),
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Create input missing element ID or position
        let input: [String: Value] = [
            "action": .string("click")
            // Missing elementId or x,y
        ]
        
        // Should throw an error
        do {
            let _ = try await tool.handler(input)
            XCTFail("Expected error not thrown")
        } catch {
            // Successfully caught error
            #expect(true)
        }
    }
}

/// Mock UI Interaction service for testing
class MockUIInteractionService: UIInteractionServiceProtocol {
    var lastClickedElementId: String?
    var lastClickedPosition: CGPoint?
    var lastDoubleClickedElementId: String?
    var lastRightClickedElementId: String?
    var lastTypedElementId: String?
    var lastTypedText: String?
    
    func clickElement(identifier: String) async throws {
        lastClickedElementId = identifier
    }
    
    func clickAtPosition(position: CGPoint) async throws {
        lastClickedPosition = position
    }
    
    func doubleClickElement(identifier: String) async throws {
        lastDoubleClickedElementId = identifier
    }
    
    func rightClickElement(identifier: String) async throws {
        lastRightClickedElementId = identifier
    }
    
    func typeText(elementIdentifier: String, text: String) async throws {
        lastTypedElementId = elementIdentifier
        lastTypedText = text
    }
    
    func pressKey(keyCode: Int) async throws {
        // Not tracked in this mock
    }
    
    func dragElement(sourceIdentifier: String, targetIdentifier: String) async throws {
        // Not tracked in this mock
    }
    
    func scrollElement(identifier: String, direction: ScrollDirection, amount: Double) async throws {
        // Not tracked in this mock
    }
}