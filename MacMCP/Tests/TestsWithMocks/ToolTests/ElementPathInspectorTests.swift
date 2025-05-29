// ABOUTME: ElementPathInspectorTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Testing

@testable import MacMCP

@Suite(.serialized) struct ElementPathInspectorTests {
  // Test data for path generation
  let testElement1 = UIElement(
    path: "macos://ui/AXButton[@AXTitle='Test Button']",
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
    path: "macos://ui/AXTextField[@AXTitle='Test Field']",
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
  @Test("Test element path generation") mutating func elementPathGeneration() throws {
    // Generate paths for different elements
    let path1 = try testElement1.generatePath()
    let path2 = try testElement2.generatePath()

    // Verify that paths have the correct format
    #expect(path1.hasPrefix("macos://ui/"), "Path should start with macos://ui/")
    #expect(path1.contains("AXButton"), "Path should include the element's role")
    #expect(path1.contains("AXTitle"), "Path should include title attribute")

    #expect(path2.hasPrefix("macos://ui/"), "Path should start with macos://ui/")
    #expect(path2.contains("AXTextField"), "Path should include the element's role")
    #expect(path2.contains("AXTitle"), "Path should include title attribute")
  }

  // Test path generation with optional attributes
  @Test("Test path with optional attributes") mutating func pathWithOptionalAttributes() throws {
    // Test path with value included
    let pathWithValue = try testElement2.generatePath(includeValue: true)
    #expect(pathWithValue.contains("AXValue"), "Path should include value attribute when requested")

    // Test path with frame included
    let pathWithFrame = try testElement1.generatePath(includeFrame: true)
    #expect(pathWithFrame.contains("x="), "Path should include x coordinate")
    #expect(pathWithFrame.contains("y="), "Path should include y coordinate")
    #expect(pathWithFrame.contains("width="), "Path should include width")
    #expect(pathWithFrame.contains("height="), "Path should include height")
  }

  // Test element path hierarchy with parent-child relationships
  @Test("Test element path hierarchy") mutating func elementPathHierarchy() throws {
    // Create a parent element
    let parentElement = UIElement(
      path: "macos://ui/AXGroup[@AXTitle=\"Parent Group\"][@identifier=\"test-parent\"]",
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
      "macos://ui/AXGroup[@AXTitle=\"Parent Group\"]/AXButton[@AXTitle=\"Child Button\"][@identifier=\"test-child\"]",
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
    #expect(childPath.contains("AXGroup"), "Child path should include parent's role")
    #expect(childPath.contains("AXButton"), "Child path should include its own role")

    // The order should be parent first, then child
    let groupIndex = childPath.range(of: "AXGroup")?.lowerBound
    let buttonIndex = childPath.range(of: "AXButton")?.lowerBound
    #expect(groupIndex! < buttonIndex!, "Parent role should appear before child role in path")
  }
}
