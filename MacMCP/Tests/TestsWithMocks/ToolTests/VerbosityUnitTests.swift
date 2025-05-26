// ABOUTME: VerbosityUnitTests.swift
// ABOUTME: Unit tests for verbosity reduction that don't depend on other test infrastructure

import Testing
import Foundation
@testable import MacMCP

@Suite("Verbosity Unit Tests")
struct VerbosityUnitTests {
  
  @Test("getStateArray excludes normal states")
  func testStateArrayOnlyShowsExceptions() async throws {
    // Test normal element - should have empty state array
    let normalElement = UIElement(
      path: "test://normal",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "enabled": true,   // Use lowercase keys that UIElement properties expect
        "focused": false,
        "selected": false,
        "visible": true
      ]
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
        "enabled": false,   // Exception
        "focused": true,    // Exception
        "selected": true,   // Exception
        "visible": false    // Exception
      ]
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
  
  @Test("EnhancedElementDescriptor omits redundant name field") 
  func testNameDeduplication() async throws {
    // Create element where name matches role
    let roleMatchElement = UIElement(
      path: "test://role-match",
      role: "AXButton", 
      title: "AXButton",  // Will become name, matches role
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:]
    )
    
    let descriptor1 = EnhancedElementDescriptor.from(element: roleMatchElement)
    let jsonData1 = try JSONEncoder().encode(descriptor1)
    let json1 = String(data: jsonData1, encoding: .utf8)!
    
    #expect(!json1.contains("\"name\""), "Should omit name when it matches role")
    #expect(json1.contains("\"role\":\"AXButton\""), "Should include role")
    
    // Create element where name matches identifier
    let identifierMatchElement = UIElement(
      path: "test://id-match",
      role: "AXButton",
      title: "Save",
      elementDescription: nil,
      identifier: "Save",  // Pass identifier as constructor parameter
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:]
    )
    
    let descriptor2 = EnhancedElementDescriptor.from(element: identifierMatchElement)
    let jsonData2 = try JSONEncoder().encode(descriptor2)
    let json2 = String(data: jsonData2, encoding: .utf8)!
    
    #expect(!json2.contains("\"name\""), "Should omit name when it matches identifier")
    #expect(json2.contains("\"identifier\""), "Should include identifier")
    
    // Create element with unique name - should include it
    let uniqueNameElement = UIElement(
      path: "test://unique",
      role: "AXButton",
      title: "Click Me",  // Unique name
      elementDescription: nil,
      identifier: "btn1",   // Different from title
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [:]
    )
    
    let descriptor3 = EnhancedElementDescriptor.from(element: uniqueNameElement)
    let jsonData3 = try JSONEncoder().encode(descriptor3)
    let json3 = String(data: jsonData3, encoding: .utf8)!
    
    #expect(json3.contains("\"name\":\"Click Me\""), "Should include unique name")
  }
  
  @Test("Token reduction is significant")
  func testTokenReduction() async throws {
    // Element that would have been verbose before improvements
    let element = UIElement(
      path: "test://verbose",
      role: "AXButton",
      title: "AXButton",  // Matches role - will be omitted
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXEnabled": true,     // Normal - will be omitted
        "AXFocused": false,    // Normal - will be omitted
        "AXSelected": false,   // Normal - will be omitted
        "visible": true,       // Normal - will be omitted
        "AXIdentifier": "test"
      ]
    )
    
    let descriptor = EnhancedElementDescriptor.from(element: element)
    let jsonData = try JSONEncoder().encode(descriptor)
    let json = String(data: jsonData, encoding: .utf8)!
    
    // Verify verbosity reduction
    #expect(!json.contains("\"name\""), "Name should be omitted")
    #expect(json.contains("\"props\":[]"), "Props should be empty (no normal states)")
    
    // JSON should be significantly shorter
    // Rough estimate: under 200 chars instead of 400+ with verbose output
    #expect(json.count < 300, "JSON should be under 300 chars, got \(json.count)")
    
    print("Reduced JSON (\(json.count) chars): \(json)")
  }
  
  @Test("showCoordinates parameter controls frame output")
  func testShowCoordinatesParameter() async throws {
    let element = UIElement(
      path: "test://coordinates",
      role: "AXButton",
      title: "Button",
      elementDescription: nil,
      frame: CGRect(x: 100, y: 200, width: 50, height: 30),
      children: [],
      attributes: [:]
    )
    
    // Test with showCoordinates = false (default)
    let descriptorWithoutCoordinates = EnhancedElementDescriptor.from(
      element: element, 
      maxDepth: 1, 
      showCoordinates: false
    )
    let jsonWithoutCoords = try JSONEncoder().encode(descriptorWithoutCoordinates)
    let jsonStringWithoutCoords = String(data: jsonWithoutCoords, encoding: .utf8)!
    
    #expect(!jsonStringWithoutCoords.contains("frame"), "Frame should be omitted when showCoordinates=false")
    #expect(!jsonStringWithoutCoords.contains("100"), "X coordinate should not appear when showCoordinates=false")
    
    // Test with showCoordinates = true
    let descriptorWithCoordinates = EnhancedElementDescriptor.from(
      element: element,
      maxDepth: 1,
      showCoordinates: true
    )
    let jsonWithCoords = try JSONEncoder().encode(descriptorWithCoordinates)
    let jsonStringWithCoords = String(data: jsonWithCoords, encoding: .utf8)!
    
    #expect(jsonStringWithCoords.contains("frame"), "Frame should be included when showCoordinates=true")
    #expect(jsonStringWithCoords.contains("100"), "X coordinate should appear when showCoordinates=true")
    #expect(jsonStringWithCoords.contains("200"), "Y coordinate should appear when showCoordinates=true")
    #expect(jsonStringWithCoords.contains("50"), "Width should appear when showCoordinates=true")
    #expect(jsonStringWithCoords.contains("30"), "Height should appear when showCoordinates=true")
    
    // Verify significant size difference
    let sizeDifference = jsonStringWithCoords.count - jsonStringWithoutCoords.count
    #expect(sizeDifference > 20, "Including coordinates should add significant content, got difference: \(sizeDifference)")
    
    print("Without coordinates (\(jsonStringWithoutCoords.count) chars): \(jsonStringWithoutCoords)")
    print("With coordinates (\(jsonStringWithCoords.count) chars): \(jsonStringWithCoords)")
  }
}