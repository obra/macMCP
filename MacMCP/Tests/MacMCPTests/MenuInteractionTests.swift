import XCTest
import Testing
import Foundation
import MCP

@testable import MacMCP

@Suite("Menu Interaction Tests")
struct MenuInteractionTests {
    @Test("Menu access and selection")
    func testMenuAccessAndSelection() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Step 1: Open the menu by right-clicking on an element
        let openMenuInput: [String: Value] = [
            "action": .string("right_click"),
            "elementId": .string("menu-parent")
        ]
        
        let openResult = try await tool.handler(openMenuInput)
        #expect(openResult.count == 1)
        #expect(mockInteractionService.lastRightClickedElementId == "menu-parent")
        
        // Step 2: Click on a menu item (assuming the menu is now open)
        let selectMenuItemInput: [String: Value] = [
            "action": .string("click"),
            "elementId": .string("menu-item-123")
        ]
        
        let selectResult = try await tool.handler(selectMenuItemInput)
        #expect(selectResult.count == 1)
        #expect(mockInteractionService.lastClickedElementId == "menu-item-123")
    }
    
    @Test("Menu access using keyboard shortcuts")
    func testMenuAccessUsingKeyboardShortcuts() async throws {
        let mockInteractionService = MockUIInteractionService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: MockAccessibilityService(),
            logger: nil
        )
        
        // Use key commands to access menu (e.g., Alt+F for File menu)
        let input: [String: Value] = [
            "action": .string("press_key"),
            "keyCode": .int(3)  // Example key code for F key
        ]
        
        let result = try await tool.handler(input)
        #expect(result.count == 1)
    }
    
    @Test("Menu bar access")
    func testMenuBarAccess() async throws {
        let mockInteractionService = MockUIInteractionService()
        let mockAccessibilityService = MockAccessibilityService()
        let tool = UIInteractionTool(
            interactionService: mockInteractionService,
            accessibilityService: mockAccessibilityService,
            logger: nil
        )
        
        // Click on a menu bar item
        let input: [String: Value] = [
            "action": .string("click"),
            "elementId": .string("menubar-file")  // ID of a menu bar item
        ]
        
        let result = try await tool.handler(input)
        #expect(result.count == 1)
        #expect(mockInteractionService.lastClickedElementId == "menubar-file")
    }
}

// Extended mock UI interaction service for testing
class MenuMockUIInteractionService: UIInteractionServiceProtocol {
    var lastClickedElementId: String?
    var lastClickedPosition: CGPoint?
    var lastDoubleClickedElementId: String?
    var lastRightClickedElementId: String?
    var lastTypedElementId: String?
    var lastTypedText: String?
    var lastPressedKey: Int?
    
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
        lastPressedKey = keyCode
    }
    
    func dragElement(sourceIdentifier: String, targetIdentifier: String) async throws {
        // Not tracked in this mock
    }
    
    func scrollElement(identifier: String, direction: ScrollDirection, amount: Double) async throws {
        // Not tracked in this mock
    }
}