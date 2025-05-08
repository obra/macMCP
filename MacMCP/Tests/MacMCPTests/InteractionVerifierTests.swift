// ABOUTME: This file contains tests for the InteractionVerifier component.
// ABOUTME: It validates that UI interaction verification works correctly.

import XCTest
import Logging
import MCP
@testable import MacMCP

final class InteractionVerifierTests: XCTestCase {
    
    // Test mock data to simulate UI states
    private func createMockBeforeState() -> UIStateResult {
        // Create a mock UI state before interaction
        let buttonElement = UIElementRepresentation(
            identifier: "button1",
            role: "AXButton",
            title: "Click Me",
            value: "Initial",
            description: "A test button",
            frame: CGRect(x: 10, y: 10, width: 100, height: 40),
            children: [],
            capabilities: [
                "clickable": true,
                "editable": false,
                "visible": true,
                "enabled": true,
                "focused": false,
                "selected": false
            ],
            actions: ["AXPress"]
        )
        
        let textFieldElement = UIElementRepresentation(
            identifier: "textField1",
            role: "AXTextField",
            title: "Input Field",
            value: "",
            description: "A test text field",
            frame: CGRect(x: 10, y: 60, width: 200, height: 30),
            children: [],
            capabilities: [
                "clickable": true,
                "editable": true,
                "visible": true,
                "enabled": true,
                "focused": false,
                "selected": false
            ],
            actions: ["AXPress"]
        )
        
        return try! UIStateResult(
            rawContent: [.text("""
            [
                {
                    "identifier": "root",
                    "role": "AXWindow",
                    "title": "Test Window",
                    "frame": {"x": 0, "y": 0, "width": 500, "height": 400},
                    "children": [
                        \(buttonElementToJSON(buttonElement)),
                        \(buttonElementToJSON(textFieldElement))
                    ],
                    "capabilities": {
                        "clickable": false,
                        "visible": true,
                        "enabled": true
                    },
                    "actions": []
                }
            ]
            """)]
        )
    }
    
    private func createMockAfterState() -> UIStateResult {
        // Create a mock UI state after interaction
        let buttonElement = UIElementRepresentation(
            identifier: "button1",
            role: "AXButton",
            title: "Click Me",
            value: "Clicked",  // Value changed
            description: "A test button",
            frame: CGRect(x: 10, y: 10, width: 100, height: 40),
            children: [],
            capabilities: [
                "clickable": true,
                "editable": false,
                "visible": true,
                "enabled": true,
                "focused": false,
                "selected": true  // Selection state changed
            ],
            actions: ["AXPress"]
        )
        
        let textFieldElement = UIElementRepresentation(
            identifier: "textField1",
            role: "AXTextField",
            title: "Input Field",
            value: "User input",  // Value changed
            description: "A test text field",
            frame: CGRect(x: 10, y: 60, width: 200, height: 30),
            children: [],
            capabilities: [
                "clickable": true,
                "editable": true,
                "visible": true,
                "enabled": true,
                "focused": true,  // Focus state changed
                "selected": false
            ],
            actions: ["AXPress"]
        )
        
        let newElement = UIElementRepresentation(
            identifier: "result1",
            role: "AXStaticText",
            title: "Result",
            value: "Operation completed",
            description: "A result message",
            frame: CGRect(x: 10, y: 100, width: 200, height: 20),
            children: [],
            capabilities: [
                "clickable": false,
                "editable": false,
                "visible": true,
                "enabled": true,
                "focused": false,
                "selected": false
            ],
            actions: []
        )
        
        return try! UIStateResult(
            rawContent: [.text("""
            [
                {
                    "identifier": "root",
                    "role": "AXWindow",
                    "title": "Test Window",
                    "frame": {"x": 0, "y": 0, "width": 500, "height": 400},
                    "children": [
                        \(buttonElementToJSON(buttonElement)),
                        \(buttonElementToJSON(textFieldElement)),
                        \(buttonElementToJSON(newElement))
                    ],
                    "capabilities": {
                        "clickable": false,
                        "visible": true,
                        "enabled": true
                    },
                    "actions": []
                }
            ]
            """)]
        )
    }
    
    // Helper function to convert an element to JSON
    private func buttonElementToJSON(_ element: UIElementRepresentation) -> String {
        let frame = element.frame
        let capabilities = element.capabilities.map { key, value in
            return "\"\(key)\": \(value)"
        }.joined(separator: ", ")
        
        let actions = element.actions.map { action in
            return "\"\(action)\""
        }.joined(separator: ", ")
        
        return """
        {
            "identifier": "\(element.identifier)",
            "role": "\(element.role)",
            "title": "\(element.title ?? "")",
            "value": "\(element.value ?? "")",
            "description": "\(element.description ?? "")",
            "frame": {"x": \(frame.origin.x), "y": \(frame.origin.y), "width": \(frame.size.width), "height": \(frame.size.height)},
            "children": [],
            "capabilities": {
                \(capabilities)
            },
            "actions": [\(actions)]
        }
        """
    }
    
    func testVerifyElementExists() {
        let afterState = createMockAfterState()
        
        // Verify an element exists
        let result = InteractionVerifier.verifyInteraction(
            before: nil,
            after: afterState,
            verification: .elementExists(ElementCriteria(role: "AXStaticText", title: "Result"))
        )
        
        XCTAssertTrue(result.success, "Verification should succeed")
    }
    
    func testVerifyElementHasValue() {
        let afterState = createMockAfterState()
        
        // Verify an element has a specific value
        let result = InteractionVerifier.verifyInteraction(
            before: nil,
            after: afterState,
            verification: .elementHasValue(
                ElementCriteria(role: "AXTextField"),
                "User input"
            )
        )
        
        XCTAssertTrue(result.success, "Verification should succeed")
    }
    
    func testVerifyElementIsSelected() {
        let afterState = createMockAfterState()
        
        // Verify an element is selected
        let result = InteractionVerifier.verifyInteraction(
            before: nil,
            after: afterState,
            verification: .elementIsSelected(ElementCriteria(role: "AXButton"))
        )
        
        XCTAssertTrue(result.success, "Verification should succeed")
    }
    
    func testVerifyStateChange() {
        let beforeState = createMockBeforeState()
        let afterState = createMockAfterState()
        
        // Verify state changes
        let result = InteractionVerifier.verifyStateChange(
            before: beforeState,
            after: afterState,
            elementMatching: ElementCriteria(role: "AXTextField"),
            beforeValue: "",
            afterValue: "User input",
            valueExtractor: { $0.value }
        )
        
        XCTAssertTrue(result, "State change verification should succeed")
    }
    
    func testVerifyElementAppeared() {
        let beforeState = createMockBeforeState()
        let afterState = createMockAfterState()
        
        // Verify an element appeared
        let result = InteractionVerifier.verifyElementAppeared(
            before: beforeState,
            after: afterState,
            elementMatching: ElementCriteria(role: "AXStaticText")
        )
        
        XCTAssertTrue(result, "Element appearance verification should succeed")
    }
    
    func testVerifyAll() {
        let beforeState = createMockBeforeState()
        let afterState = createMockAfterState()
        
        // Verify multiple conditions
        let results = InteractionVerifier.verifyAll(
            before: beforeState,
            after: afterState,
            verifications: [
                .elementExists(ElementCriteria(role: "AXStaticText")),
                .elementHasValue(ElementCriteria(role: "AXTextField"), "User input"),
                .elementIsSelected(ElementCriteria(role: "AXButton"))
            ]
        )
        
        XCTAssertEqual(results.count, 3, "Should have 3 verification results")
        XCTAssertTrue(results.allSatisfy { $0.success }, "All verifications should succeed")
    }
    
    func testVerifyCustomCondition() {
        let afterState = createMockAfterState()
        
        // Verify using a custom verification
        let result = InteractionVerifier.verifyInteraction(
            before: nil,
            after: afterState,
            verification: .custom(
                { state in 
                    // Check if there's at least one text field with a non-empty value
                    let textFields = state.findElements(matching: ElementCriteria(role: "AXTextField"))
                    return textFields.contains { $0.value != nil && !($0.value ?? "").isEmpty }
                },
                "Text field has user input"
            )
        )
        
        XCTAssertTrue(result.success, "Custom verification should succeed")
    }
    
    func testVerifyElementDoesNotExist() {
        let afterState = createMockAfterState()
        
        // Verify an element does not exist
        let result = InteractionVerifier.verifyInteraction(
            before: nil,
            after: afterState,
            verification: .elementDoesNotExist(ElementCriteria(role: "AXMenu"))
        )
        
        XCTAssertTrue(result.success, "Verification should succeed")
    }
}