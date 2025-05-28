// ABOUTME: VerbosityReductionTests.swift
// ABOUTME: Tests for InterfaceExplorer verbosity reduction features

import Foundation
import Testing

@testable import MacMCP

@Suite("Verbosity Reduction Tests") struct VerbosityReductionTests {
  @Test("UIElement getStateArray only shows exceptional states")
  func testStateArrayVerbosityReduction() async throws {
    // Create a UIElement with normal states (enabled, visible, unfocused, unselected)
    let normalElement = UIElement(
      path: "test://button",
      role: "AXButton",
      title: "Test Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXEnabled": true,  // Normal case - should not appear
        "AXFocused": false,  // Normal case - should not appear
        "AXSelected": false,  // Normal case - should not appear
        "visible": true,  // Normal case - should not appear
      ]
    )
    let states = normalElement.getStateArray()
    // Should be empty since all states are "normal" cases
    #expect(states.isEmpty, "Normal states should not be included in state array")
  }
  @Test("UIElement getStateArray shows exceptional states") func testStateArrayExceptionalStates()
    async throws
  {
    // Create a UIElement with exceptional states
    let exceptionalElement = UIElement(
      path: "test://disabled-button",
      role: "AXButton",
      title: "Disabled Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXEnabled": false,  // Exceptional - should appear
        "AXFocused": true,  // Exceptional - should appear
        "AXSelected": true,  // Exceptional - should appear
        "visible": false,  // Exceptional - should appear
      ]
    )
    let states = exceptionalElement.getStateArray()
    // Should contain only the exceptional states
    #expect(states.contains("disabled"), "Disabled state should be included")
    #expect(states.contains("hidden"), "Hidden state should be included")
    #expect(states.contains("focused"), "Focused state should be included")
    #expect(states.contains("selected"), "Selected state should be included")
    // Should not contain normal case states
    #expect(!states.contains("enabled"), "Enabled state should not be included")
    #expect(!states.contains("visible"), "Visible state should not be included")
    #expect(!states.contains("unfocused"), "Unfocused state should not be included")
    #expect(!states.contains("unselected"), "Unselected state should not be included")
  }
  @Test("EnhancedElementDescriptor skips name when it matches role")
  func testNameDeduplicationWithRole() async throws {
    // Create element where name would match role
    let element = UIElement(
      path: "test://role-match",
      role: "AXButton",
      title: "AXButton",  // Name will be derived from title, which matches role
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:]
    )
    let descriptor = EnhancedElementDescriptor.from(element: element)
    // Encode to JSON to check what fields are included
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    // Should not include name field since it matches role
    #expect(!jsonString.contains("\"name\""), "Name field should be omitted when it matches role")
    #expect(jsonString.contains("\"role\":\"AXButton\""), "Role should be present")
  }
  @Test("EnhancedElementDescriptor skips name when it matches identifier")
  func testNameDeduplicationWithIdentifier()
    async throws
  {
    // Create element where name would match identifier
    let element = UIElement(
      path: "test://identifier-match",
      role: "AXButton",
      title: "Save",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXIdentifier": "Save"  // Name will be "Save", same as identifier
      ]
    )
    let descriptor = EnhancedElementDescriptor.from(element: element)
    // Encode to JSON to check what fields are included
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    // Should not include name field since it matches identifier
    #expect(
      !jsonString.contains("\"name\""), "Name field should be omitted when it matches identifier")
    #expect(jsonString.contains("\"identifier\":\"Save\""), "Identifier should be present")
  }
  @Test("EnhancedElementDescriptor includes name when it differs from role and identifier")
  func testNameIncludedWhenUnique() async throws {
    // Create element where name is unique
    let element = UIElement(
      path: "test://unique-name",
      role: "AXButton",
      title: "Click Me",  // Unique name
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXIdentifier": "button1"  // Different from name
      ]
    )
    let descriptor = EnhancedElementDescriptor.from(element: element)
    // Encode to JSON to check what fields are included
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    // Should include name field since it's unique
    #expect(
      jsonString.contains("\"name\":\"Click Me\""), "Name field should be included when unique")
    #expect(jsonString.contains("\"role\":\"AXButton\""), "Role should be present")
    #expect(jsonString.contains("\"identifier\":\"button1\""), "Identifier should be present")
  }
  @Test("Token reduction is significant") func testTokenReduction() async throws {
    // Create element with verbose output (old style)
    let element = UIElement(
      path: "test://token-reduction",
      role: "AXButton",
      title: "AXButton",  // Would duplicate role
      elementDescription: "AXButton",  // Would duplicate role
      frame: CGRect(x: 100, y: 200, width: 80, height: 30),
      children: [],
      attributes: [
        "AXEnabled": true,  // Normal case
        "AXFocused": false,  // Normal case
        "AXSelected": false,  // Normal case
        "AXIdentifier": "test", "visible": true,  // Normal case
      ]
    )
    let descriptor = EnhancedElementDescriptor.from(element: element)
    // Encode to JSON and measure size
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    // Verify verbosity reduction worked
    #expect(!jsonString.contains("\"name\""), "Name should be omitted (matches role)")
    #expect(!jsonString.contains("enabled"), "Enabled state should be omitted")
    #expect(!jsonString.contains("visible"), "Visible state should be omitted")
    #expect(!jsonString.contains("unfocused"), "Unfocused state should be omitted")
    #expect(!jsonString.contains("unselected"), "Unselected state should be omitted")
    // JSON should be significantly shorter due to verbosity reduction
    // Rough estimate: should be under 300 characters instead of 500+
    #expect(
      jsonString.count < 400,
      "JSON output should be significantly reduced: \(jsonString.count) chars")
    print("Reduced JSON output (\(jsonString.count) chars): \(jsonString)")
  }
}
