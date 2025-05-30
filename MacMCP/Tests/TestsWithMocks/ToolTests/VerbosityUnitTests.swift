// ABOUTME: VerbosityUnitTests.swift
// ABOUTME: Unit tests for verbosity reduction that don't depend on other test infrastructure

import Foundation
import Logging
import Testing

@testable import MacMCP

@Suite("Verbosity Unit Tests") struct VerbosityUnitTests {
  @Test("getStateArray excludes normal states") func stateArrayOnlyShowsExceptions()
    async throws
  {
    // Test normal element - should have empty state array
    let normalElement = UIElement(
      path: "test://normal",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "enabled": true, // Use lowercase keys that UIElement properties expect
        "focused": false, "selected": false, "visible": true,
      ],
    )
    let normalStates = normalElement.getStateArray()
    #expect(normalStates.isEmpty, "Normal states should result in empty array")
    // Test exceptional element - should show only exceptions
    let exceptionalElement = UIElement(
      path: "test://exceptional",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "enabled": false, // Exception
        "focused": true, // Exception
        "selected": true, // Exception
        "visible": false, // Exception
      ],
    )
    let exceptionalStates = exceptionalElement.getStateArray()
    #expect(exceptionalStates.contains("disabled"))
    #expect(exceptionalStates.contains("focused"))
    #expect(exceptionalStates.contains("selected"))
    #expect(exceptionalStates.contains("hidden"))
    // Should not contain normal cases
    #expect(!exceptionalStates.contains("enabled"))
    #expect(!exceptionalStates.contains("unfocused"))
    #expect(!exceptionalStates.contains("unselected"))
    #expect(!exceptionalStates.contains("visible"))
  }

  @Test("EnhancedElementDescriptor omits redundant name field") func nameDeduplication()
    async throws
  {
    // Create element where name matches role
    let roleMatchElement = UIElement(
      path: "test://role-match",
      role: "AXButton",
      title: "AXButton", // Will become name, matches role
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:],
    )
    let descriptor1 = EnhancedElementDescriptor.from(element: roleMatchElement)

    try JSONTestUtilities.testElementDescriptor(descriptor1) { json in
      try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "name")
      try JSONTestUtilities.assertProperty(json, property: "role", equals: "AXButton")
    }

    // Create element where name matches identifier
    let identifierMatchElement = UIElement(
      path: "test://id-match",
      role: "AXButton",
      title: "Save",
      elementDescription: nil,
      identifier: "Save", // Pass identifier as constructor parameter
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:],
    )
    let descriptor2 = EnhancedElementDescriptor.from(element: identifierMatchElement)

    try JSONTestUtilities.testElementDescriptor(descriptor2) { json in
      try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "name")
      try JSONTestUtilities.assertPropertyContains(json, property: "el", substring: "Save")
    }

    // Create element with unique name - should include it
    let uniqueNameElement = UIElement(
      path: "test://unique",
      role: "AXButton",
      title: "Click Me", // Unique name
      elementDescription: nil,
      identifier: "btn1", // Different from title
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:],
    )
    let descriptor3 = EnhancedElementDescriptor.from(element: uniqueNameElement)

    try JSONTestUtilities.testElementDescriptor(descriptor3) { json in
      try JSONTestUtilities.assertPropertyContains(json, property: "el", substring: "Click Me")
      try JSONTestUtilities.assertPropertyContains(json, property: "el", substring: "btn1")
    }
  }

  @Test("Token reduction is significant") func tokenReduction() async throws {
    // Element that would have been verbose before improvements
    let element = UIElement(
      path: "test://verbose",
      role: "AXButton",
      title: "AXButton", // Matches role - will be omitted
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXEnabled": true, // Normal - will be omitted
        "AXFocused": false, // Normal - will be omitted
        "AXSelected": false, // Normal - will be omitted
        "visible": true, // Normal - will be omitted
        "AXIdentifier": "test",
      ],
    )
    let descriptor = EnhancedElementDescriptor.from(element: element)
    let jsonData = try JSONEncoder().encode(descriptor)
    let json = String(data: jsonData, encoding: .utf8)!

    try JSONTestUtilities.testElementDescriptor(descriptor) { json in
      // Verify verbosity reduction
      try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "name")
      // Props field may not exist if empty (which is correct behavior)
      // If it exists, it should be empty or only contain non-normal states
      if json["props"] != nil {
        // Props should not contain normal states like "enabled", "visible", etc.
        if let propsString = json["props"] as? String {
          #expect(!propsString.contains("enabled"), "Props should not contain 'enabled'")
          #expect(!propsString.contains("visible"), "Props should not contain 'visible'")
        }
      }
    }

    // JSON should be significantly shorter due to verbosity reduction
    #expect(json.count < 300, "JSON should be under 300 chars, got \(json.count)")
    print("Reduced JSON (\(json.count) chars): \(json)")
  }

  @Test("showCoordinates parameter controls frame output") func showCoordinatesParameter()
    async throws
  {
    let element = UIElement(
      path: "test://coordinates",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 100, y: 200, width: 50, height: 30),
      children: [],
      attributes: [:],
    )
    // Test with showCoordinates = false (default)
    let descriptorWithoutCoordinates = EnhancedElementDescriptor.from(
      element: element,
      maxDepth: 1,
      showCoordinates: false,
    )
    let jsonWithoutCoords = try JSONEncoder().encode(descriptorWithoutCoordinates)
    let jsonStringWithoutCoords = String(data: jsonWithoutCoords, encoding: .utf8)!
    #expect(
      !jsonStringWithoutCoords.contains("frame"),
      "Frame should be omitted when showCoordinates=false",
    )
    #expect(
      !jsonStringWithoutCoords.contains("100"),
      "X coordinate should not appear when showCoordinates=false",
    )
    // Test with showCoordinates = true
    let descriptorWithCoordinates = EnhancedElementDescriptor.from(
      element: element,
      maxDepth: 1,
      showCoordinates: true,
    )
    let jsonWithCoords = try JSONEncoder().encode(descriptorWithCoordinates)
    let jsonStringWithCoords = String(data: jsonWithCoords, encoding: .utf8)!
    #expect(
      jsonStringWithCoords.contains("frame"), "Frame should be included when showCoordinates=true",
    )
    #expect(
      jsonStringWithCoords.contains("100"), "X coordinate should appear when showCoordinates=true",
    )
    #expect(
      jsonStringWithCoords.contains("200"), "Y coordinate should appear when showCoordinates=true",
    )
    #expect(jsonStringWithCoords.contains("50"), "Width should appear when showCoordinates=true")
    #expect(jsonStringWithCoords.contains("30"), "Height should appear when showCoordinates=true")
    // Verify significant size difference
    let sizeDifference = jsonStringWithCoords.count - jsonStringWithoutCoords.count
    #expect(
      sizeDifference > 20,
      "Including coordinates should add significant content, got difference: \(sizeDifference)",
    )
    print(
      "Without coordinates (\(jsonStringWithoutCoords.count) chars): \(jsonStringWithoutCoords)",
    )
    print("With coordinates (\(jsonStringWithCoords.count) chars): \(jsonStringWithCoords)")
  }

  @Test("actions are always shown without AX prefix") func actionsAlwaysShown() async throws {
    let element = UIElement(
      path: "test://actions",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 50, height: 30),
      children: [],
      attributes: [:],
      actions: ["AXPress", "AXFocus", "AXShowMenu"],
    )
    // Actions should always be included now
    let descriptor = EnhancedElementDescriptor.from(element: element, maxDepth: 1)
    let jsonData = try JSONEncoder().encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    #expect(jsonString.contains("actions"), "Actions should always be included")
    #expect(jsonString.contains("Press"), "Press action should appear without AX prefix")
    #expect(jsonString.contains("Focus"), "Focus action should appear without AX prefix")
    #expect(jsonString.contains("ShowMenu"), "ShowMenu action should appear without AX prefix")
    #expect(!jsonString.contains("AXPress"), "AXPress should not appear (prefix removed)")
    #expect(!jsonString.contains("AXFocus"), "AXFocus should not appear (prefix removed)")
    #expect(!jsonString.contains("AXShowMenu"), "AXShowMenu should not appear (prefix removed)")
    print("Actions JSON (\(jsonString.count) chars): \(jsonString)")
  }

  @Test("ChangeDetectionHelper uses verbosity reduction")
  func changeDetectionHelperVerbosityReduction()
    async throws
  {
    let element = UIElement(
      path: "test://change-detection",
      role: "AXButton",
      title: "Test Button",
      elementDescription: "A test button for change detection",
      frame: CGRect(x: 100, y: 200, width: 150, height: 40),
      children: [],
      attributes: [:],
      actions: ["AXPress", "AXFocus", "AXShowMenu"],
    )
    // Create mock UI changes
    let changes = UIChanges(newElements: [element])
    // Test ChangeDetectionHelper response formatting
    let logger = Logger(label: "test.verbosity")
    let response = ChangeDetectionHelper.formatResponse(
      message: "Element added successfully",
      uiChanges: changes,
      logger: logger,
    )
    // Extract the JSON response
    #expect(response.count == 1, "Should return one content item")
    if case .text(let jsonString) = response[0] {
      // Verify verbosity reduction is applied
      #expect(
        !jsonString.contains("\"frame\""), "Frame should be excluded due to showCoordinates=false",
      )
      #expect(jsonString.contains("\"actions\""), "Actions should always be included now")
      #expect(!jsonString.contains("100"), "X coordinate should not appear in response")
      #expect(jsonString.contains("Press"), "Actions should appear without AX prefix")
      // Verify essential information is still present
      #expect(jsonString.contains("AXButton"), "Role should be included")
      #expect(jsonString.contains("newElements"), "newElements should be included")
      print("ChangeDetectionHelper response (\(jsonString.count) chars): \(jsonString)")
    } else {
      #expect(Bool(false), "Response should be text content")
    }
  }
}
