// ABOUTME: ElementPathInspectorTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import XCTest

@testable import MacMCP

final class ElementPathInspectorTests: XCTestCase {
  // Test data for path generation
  let testElement1 = UIElement(
    path: "ui://AXButton[@title='Test Button']",
    role: "AXButton",
    title: "Test Button",
    elementDescription: "Button description",
    frame: CGRect(x: 100, y: 100, width: 200, height: 50),
    frameSource: .direct,
    parent: nil,
    children: [],
    attributes: ["enabled": true, "visible": true],
    actions: ["AXPress"],
  )

  let testElement2 = UIElement(
    path: "ui://AXTextField[@title='Test Field']",
    role: "AXTextField",
    title: "Test Field",
    value: "Hello world",
    frame: CGRect(x: 100, y: 200, width: 200, height: 30),
    frameSource: .direct,
    parent: nil,
    children: [],
    attributes: ["enabled": true, "visible": true, "editable": true],
    actions: [],
  )

  // Test that path generation works correctly
  func testElementPathGeneration() throws {
    // Generate paths for different elements
    let path1 = try testElement1.generatePath()
    let path2 = try testElement2.generatePath()

    // Verify that paths have the correct format
    XCTAssertTrue(path1.hasPrefix("ui://"), "Path should start with ui://")
    XCTAssertTrue(path1.contains("AXButton"), "Path should include the element's role")
    XCTAssertTrue(path1.contains("title=\"Test Button\""), "Path should include title attribute")

    XCTAssertTrue(path2.hasPrefix("ui://"), "Path should start with ui://")
    XCTAssertTrue(path2.contains("AXTextField"), "Path should include the element's role")
    XCTAssertTrue(path2.contains("title=\"Test Field\""), "Path should include title attribute")
  }

  // Test path generation with optional attributes
  func testPathWithOptionalAttributes() throws {
    // Test path with value included
    let pathWithValue = try testElement2.generatePath(includeValue: true)
    XCTAssertTrue(
      pathWithValue.contains("value=\"Hello world\""),
      "Path should include value attribute when requested",
    )

    // Test path with frame included
    let pathWithFrame = try testElement1.generatePath(includeFrame: true)
    XCTAssertTrue(pathWithFrame.contains("x=\"100\""), "Path should include x coordinate")
    XCTAssertTrue(pathWithFrame.contains("y=\"100\""), "Path should include y coordinate")
    XCTAssertTrue(pathWithFrame.contains("width=\"200\""), "Path should include width")
    XCTAssertTrue(pathWithFrame.contains("height=\"50\""), "Path should include height")
  }

  // Test element path hierarchy with parent-child relationships
  func testElementPathHierarchy() throws {
    // Create a parent element
    let parentElement = UIElement(
      path: "ui://AXGroup[@AXTitle=\"Parent Group\"][@identifier=\"test-parent\"]",
      role: "AXGroup",
      title: "Parent Group",
      frame: CGRect(x: 50, y: 50, width: 400, height: 300),
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: ["enabled": true, "visible": true],
      actions: [],
    )

    // Create a child element with the parent
    let childElement = UIElement(
      path:
        "ui://AXGroup[@AXTitle=\"Parent Group\"]/AXButton[@AXTitle=\"Child Button\"][@identifier=\"test-child\"]",
      role: "AXButton",
      title: "Child Button",
      frame: CGRect(x: 100, y: 100, width: 100, height: 50),
      frameSource: .direct,
      parent: parentElement,
      children: [],
      attributes: ["enabled": true, "visible": true],
      actions: ["AXPress"],
    )

    // Generate path for the child element
    let childPath = try childElement.generatePath()

    // Verify that the path includes both parent and child information
    XCTAssertTrue(childPath.contains("AXGroup"), "Child path should include parent's role")
    XCTAssertTrue(childPath.contains("AXButton"), "Child path should include its own role")

    // The order should be parent first, then child
    let groupIndex = childPath.range(of: "AXGroup")?.lowerBound
    let buttonIndex = childPath.range(of: "AXButton")?.lowerBound
    XCTAssertLessThan(
      groupIndex!, buttonIndex!, "Parent role should appear before child role in path")
  }
}
