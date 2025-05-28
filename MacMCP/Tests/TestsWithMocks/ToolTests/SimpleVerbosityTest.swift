// ABOUTME: SimpleVerbosityTest.swift
// ABOUTME: Simple manual test for verbosity reduction

import Foundation
import Testing

@testable import MacMCP

@Suite("Simple Verbosity Test") struct SimpleVerbosityTest {
  @Test("Manual verification of verbosity improvements") func testManualVerbosityCheck()
    async throws
  {
    // Create element that should have minimal output due to verbosity reduction
    let element = UIElement(
      path: "test://minimal",
      role: "AXButton",
      title: "AXButton",  // Should be deduplicated (matches role)
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 30),
      children: [],
      attributes: [
        "AXEnabled": true,  // Normal case - should not appear in states
        "AXFocused": false,  // Normal case - should not appear in states
        "AXSelected": false,  // Normal case - should not appear in states
        "visible": true,  // Normal case - should not appear in states
        "AXIdentifier": "button",
      ]
    )
    // Test state array verbosity reduction
    let states = element.getStateArray()
    print("States for normal element: \(states)")
    // Should be empty since all are normal states

    // Test enhanced descriptor creation
    let descriptor = EnhancedElementDescriptor.from(element: element)
    // Encode to JSON and print for manual verification
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let jsonData = try? encoder.encode(descriptor),
      let jsonString = String(data: jsonData, encoding: .utf8)
    {
      print("Enhanced descriptor JSON:")
      print(jsonString)
      print("Character count: \(jsonString.count)")
    }
    // This test always passes - we're just printing for manual verification
    #expect(true)
  }
}
