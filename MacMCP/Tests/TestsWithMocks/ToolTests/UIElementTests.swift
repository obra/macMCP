import XCTest
import Testing
import Foundation

@testable import MacMCP

@Suite("UIElement Tests")
struct UIElementTests {
    @Test("UIElement initialization and properties")
    func testUIElementInitialization() {
        let element = UIElement(
            identifier: "test-element",
            role: "button",
            title: "Test Button",
            value: "test value",
            elementDescription: "A test button element",
            frame: CGRect(x: 10, y: 20, width: 100, height: 50),
            parent: nil,
            children: [],
            attributes: [
                "enabled": true,
                "focused": false
            ],
            actions: ["press", "show menu"]
        )
        
        #expect(element.identifier == "test-element")
        #expect(element.role == "button")
        #expect(element.title == "Test Button")
        #expect(element.value == "test value")
        #expect(element.elementDescription == "A test button element")
        #expect(element.frame.origin.x == 10)
        #expect(element.frame.origin.y == 20)
        #expect(element.frame.size.width == 100)
        #expect(element.frame.size.height == 50)
        #expect(element.parent == nil)
        #expect(element.children.isEmpty)
        #expect(element.attributes.count == 2)
        #expect(element.attributes["enabled"] as? Bool == true)
        #expect(element.attributes["focused"] as? Bool == false)
        #expect(element.actions.count == 2)
        #expect(element.actions.contains("press"))
        #expect(element.actions.contains("show menu"))
    }
    
    @Test("UIElement child relationships")
    func testUIElementChildren() {
        let child1 = UIElement(
            identifier: "child-1",
            role: "text",
            title: "Child 1",
            frame: CGRect(x: 0, y: 0, width: 50, height: 25)
        )
        
        let child2 = UIElement(
            identifier: "child-2",
            role: "image",
            title: "Child 2", 
            frame: CGRect(x: 0, y: 30, width: 50, height: 25)
        )
        
        let parent = UIElement(
            identifier: "parent",
            role: "group",
            title: "Parent Element",
            frame: CGRect(x: 10, y: 10, width: 200, height: 100),
            children: [child1, child2]
        )
        
        #expect(parent.children.count == 2)
        #expect(parent.children[0].identifier == "child-1")
        #expect(parent.children[1].identifier == "child-2")
    }
    
    @Test("UIElement to JSON conversion")
    func testUIElementToJSON() throws {
        let element = UIElement(
            identifier: "test-element",
            role: "button",
            title: "Test Button",
            value: "test value",
            elementDescription: "A test button element",
            frame: CGRect(x: 10, y: 20, width: 100, height: 50),
            attributes: [
                "enabled": true,
                "focused": false
            ],
            actions: ["press"]
        )
        
        let json = try element.toJSON()
        
        #expect(json["identifier"] as? String == "test-element")
        #expect(json["role"] as? String == "button")
        #expect(json["title"] as? String == "Test Button")
        #expect(json["value"] as? String == "test value")
        #expect(json["description"] as? String == "A test button element")
        
        if let frame = json["frame"] as? [String: Any] {
            #expect(frame["x"] as? CGFloat == 10)
            #expect(frame["y"] as? CGFloat == 20)
            #expect(frame["width"] as? CGFloat == 100)
            #expect(frame["height"] as? CGFloat == 50)
        } else {
            XCTFail("Frame not found in JSON")
        }
        
        if let attributes = json["attributes"] as? [String: Any] {
            #expect(attributes["enabled"] as? Bool == true)
            #expect(attributes["focused"] as? Bool == false)
        } else {
            XCTFail("Attributes not found in JSON")
        }
        
        if let actions = json["actions"] as? [String] {
            #expect(actions.count == 1)
            #expect(actions[0] == "press")
        } else {
            XCTFail("Actions not found in JSON")
        }
    }
    
    @Test("UIElement to MCP Value conversion")
    func testUIElementToValue() throws {
        let element = UIElement(
            identifier: "test-element",
            role: "button",
            title: "Test Button",
            frame: CGRect(x: 10, y: 20, width: 100, height: 50)
        )
        
        // Convert to Value, then to a Swift dictionary for testing
        let value = try element.toValue()
        let jsonData = try JSONSerialization.data(withJSONObject: value.asAnyDictionary())
        let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        
        // Test some fields
        #expect(dictionary?["identifier"] as? String == "test-element")
        #expect(dictionary?["role"] as? String == "button")
        #expect(dictionary?["title"] as? String == "Test Button")
        
        // Check frame
        let frame = dictionary?["frame"] as? [String: Any]
        #expect(frame?["x"] as? Double == 10)
        #expect(frame?["y"] as? Double == 20)
        #expect(frame?["width"] as? Double == 100)
        #expect(frame?["height"] as? Double == 50)
    }
}