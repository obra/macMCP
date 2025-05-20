// ABOUTME: UIElementTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Testing

@testable import MacMCP

@Suite("UIElement Tests")
struct UIElementTests {
  @Test("UIElement initialization and properties")
  func uIElementInitialization() {
    let element = UIElement(
      path: "macos://ui/AXButton[@AXTitle=\"Test Button\"]",
      role: "button",
      title: "Test Button",
      value: "test value",
      elementDescription: "A test button element",
      frame: CGRect(x: 10, y: 20, width: 100, height: 50),
      parent: nil,
      children: [],
      attributes: [
        "enabled": true,
        "focused": false,
      ],
      actions: ["press", "show menu"],
    )

    #expect(element.path == "macos://ui/AXButton[@AXTitle=\"Test Button\"]")
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
  func uIElementChildren() {
    let child1 = UIElement(
      path: "macos://ui/AXText[@AXTitle=\"Child 1\"]",
      role: "text",
      title: "Child 1",
      frame: CGRect(x: 0, y: 0, width: 50, height: 25),
    )

    let child2 = UIElement(
      path: "macos://ui/AXImage[@AXTitle=\"Child 2\"]",
      role: "image",
      title: "Child 2",
      frame: CGRect(x: 0, y: 30, width: 50, height: 25),
    )

    let parent = UIElement(
      path: "macos://ui/AXGroup[@AXTitle=\"Parent Element\"]",
      role: "group",
      title: "Parent Element",
      frame: CGRect(x: 10, y: 10, width: 200, height: 100),
      children: [child1, child2],
    )

    #expect(parent.children.count == 2)
    #expect(parent.children[0].path == "macos://ui/AXText[@AXTitle=\"Child 1\"]")
    #expect(parent.children[1].path == "macos://ui/AXImage[@AXTitle=\"Child 2\"]")
  }

  @Test("UIElement to JSON conversion")
  func uIElementToJSON() throws {
    let element = UIElement(
      path: "macos://ui/AXButton[@AXTitle=\"Test Button\"]",
      role: "button",
      title: "Test Button",
      value: "test value",
      elementDescription: "A test button element",
      frame: CGRect(x: 10, y: 20, width: 100, height: 50),
      attributes: [
        "enabled": true,
        "focused": false,
      ],
      actions: ["press"],
    )

    let json = try element.toJSON()

    #expect(json["path"] as? String == "macos://ui/AXButton[@AXTitle=\"Test Button\"]")
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
      #expect(Bool(false), "Frame not found in JSON")
    }

    if let attributes = json["attributes"] as? [String: Any] {
      #expect(attributes["enabled"] as? Bool == true)
      #expect(attributes["focused"] as? Bool == false)
    } else {
      #expect(Bool(false), "Attributes not found in JSON")
    }

    if let actions = json["actions"] as? [String] {
      #expect(actions.count == 1)
      #expect(actions[0] == "press")
    } else {
      #expect(Bool(false), "Actions not found in JSON")
    }
  }

  @Test("UIElement to MCP Value conversion")
  func uIElementToValue() throws {
    let element = UIElement(
      path: "macos://ui/AXButton[@AXTitle=\"Test Button\"]",
      role: "button",
      title: "Test Button",
      frame: CGRect(x: 10, y: 20, width: 100, height: 50),
    )

    // Convert to Value, then to a Swift dictionary for testing
    let value = try element.toValue()
    let jsonData = try JSONSerialization.data(withJSONObject: value.asAnyDictionary())
    let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    // Test some fields
    #expect(dictionary?["path"] as? String == "macos://ui/AXButton[@AXTitle=\"Test Button\"]")
    #expect(dictionary?["role"] as? String == "button")
    #expect(dictionary?["title"] as? String == "Test Button")

    // Check frame
    let frame = dictionary?["frame"] as? [String: Any]
    #expect(frame?["x"] as? Double == 10)
    #expect(frame?["y"] as? Double == 20)
    #expect(frame?["width"] as? Double == 100)
    #expect(frame?["height"] as? Double == 50)
  }

  @Test("Simple UIElement path generation")
  func simplePathGeneration() throws {
    let element = UIElement(
      path: "macos://ui/AXButton[@AXTitle=\"Test Button\"]",
      role: "AXButton",
      title: "Test Button",
      elementDescription: "A test button",
      frame: CGRect(x: 10, y: 20, width: 100, height: 50),
    )

    // Test path generation without parent
    let path = try element.generatePath()
    #expect(path.hasPrefix(ElementPath.pathPrefix))
    #expect(path.contains("AXButton"))
    #expect(path.contains("[@AXTitle=\"Test Button\"]"))

    // The path should include useful attributes for identification
    #expect(path.contains("[@AXDescription=\"A test button\"]"))
  }

  @Test("UIElement path generation with parent hierarchy")
  func pathGenerationWithParents() throws {
    // Create a window element
    let window = UIElement(
      path: "macos://ui/AXWindow[@AXTitle=\"Test Window\"]",
      role: "AXWindow",
      title: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
    )

    // Create a group element
    let group = UIElement(
      path: "macos://ui/AXWindow[@AXTitle=\"Test Window\"]/AXGroup[@AXTitle=\"Controls Group\"]",
      role: "AXGroup",
      title: "Controls Group",
      frame: CGRect(x: 10, y: 10, width: 200, height: 100),
      parent: window,
    )

    // Create a button element
    let button = UIElement(
      path:
        "macos://ui/AXWindow[@AXTitle=\"Test Window\"]/AXGroup[@AXTitle=\"Controls Group\"]/AXButton[@AXTitle=\"OK Button\"]",
      role: "AXButton",
      title: "OK Button",
      frame: CGRect(x: 20, y: 50, width: 80, height: 30),
      parent: group,
    )

    // Generate path for the button
    let path = try button.generatePath()

    // Path should include the full hierarchy
    #expect(path.hasPrefix(ElementPath.pathPrefix))
    #expect(path.contains("AXWindow"))
    #expect(path.contains("[@AXTitle=\"Test Window\"]"))
    #expect(path.contains("AXGroup"))
    #expect(path.contains("[@AXTitle=\"Controls Group\"]"))
    #expect(path.contains("AXButton"))
    #expect(path.contains("[@AXTitle=\"OK Button\"]"))

    // The path segments should be in the correct order (parent first)
    let segments = path.replacingOccurrences(of: ElementPath.pathPrefix, with: "").split(
      separator: "/")
    #expect(segments.count == 3)
    #expect(segments[0].hasPrefix("AXWindow"))
    #expect(segments[1].hasPrefix("AXGroup"))
    #expect(segments[2].hasPrefix("AXButton"))
  }

  @Test("UIElement path generation with various attribute types")
  func pathGenerationWithAttributes() throws {
    // Create an element with several attribute types
    let element = UIElement(
      path: "macos://ui/AXTextField[@AXTitle=\"Search\"][@identifier=\"searchField\"]",
      role: "AXTextField",
      title: "Search",
      value: "query text",
      elementDescription: "Search field",
      frame: CGRect(x: 10, y: 20, width: 100, height: 30),
      attributes: [
        "enabled": true,
        "focused": true,
        "required": true,
        "placeholder": "Enter search terms",
        "identifier": "searchField",
      ],
    )

    // Generate the path
    let path = try element.generatePath()

    // Path should include useful attributes for identification
    #expect(path.hasPrefix(ElementPath.pathPrefix))
    #expect(path.contains("AXTextField"))
    #expect(path.contains("[@AXTitle=\"Search\"]"))
    #expect(path.contains("[@AXDescription=\"Search field\"]"))
    #expect(path.contains("[@AXIdentifier=\"searchField\"]"))

    // Value is not included by default as it can change
    #expect(!path.contains("[@value=\"query text\"]"))
  }

  @Test("UIElement path generation with missing attributes")
  func pathGenerationWithMissingAttributes() throws {
    // Create an element with minimal attributes
    let element = UIElement(
      path: "macos://ui/AXUnknown",
      role: "AXUnknown",
      frame: CGRect(x: 10, y: 20, width: 100, height: 30),
    )

    // Generate the path
    let path = try element.generatePath()

    // Path should still be valid with just the role
    #expect(path.hasPrefix(ElementPath.pathPrefix))
    #expect(path.contains("AXUnknown"))

    // Should not contain empty attributes
    #expect(!path.contains("[@AXTitle="))
    #expect(!path.contains("[@AXDescription="))
  }

  @Test("Menu element path generation compatibility")
  func menuElementPathGeneration() throws {
    // Create a menu bar item
    let menuBarItem = UIElement(
      path: "macos://ui/AXMenuBarItem[@AXTitle=\"File\"]",
      role: "AXMenuBarItem",
      title: "File",
      frame: CGRect(x: 10, y: 0, width: 50, height: 20),
    )

    // Create a menu
    let menu = UIElement(
      path: "macos://ui/AXMenuBarItem[@AXTitle=\"File\"]/AXMenu",
      role: "AXMenu",
      frame: CGRect(x: 10, y: 20, width: 200, height: 300),
      parent: menuBarItem,
    )

    // Create a menu item
    let menuItem = UIElement(
      path: "macos://ui/AXMenuBarItem[@AXTitle=\"File\"]/AXMenu/AXMenuItem[@AXTitle=\"Open\"]",
      role: "AXMenuItem",
      title: "Open",
      frame: CGRect(x: 10, y: 40, width: 180, height: 20),
      parent: menu,
    )

    // Generate path for the menu item
    let path = try menuItem.generatePath()

    // Path should use the new format but preserve the menu structure
    #expect(path.hasPrefix(ElementPath.pathPrefix))
    #expect(path.contains("AXMenuBarItem"))
    #expect(path.contains("[@AXTitle=\"File\"]"))
    #expect(path.contains("AXMenu"))
    #expect(path.contains("AXMenuItem"))
    #expect(path.contains("[@AXTitle=\"Open\"]"))
  }
}
