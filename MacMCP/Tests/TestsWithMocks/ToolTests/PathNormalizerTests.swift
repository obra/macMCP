// ABOUTME: PathNormalizerTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Testing
import XCTest

@testable import MacMCP
@testable import MacMCPUtilities

@Suite("PathNormalizer Tests")
struct PathNormalizerTests {
  @Test("Normalize attribute names")
  func normalizeAttributeNames() {
    // Test standard mappings
    #expect(PathNormalizer.normalizeAttributeName("title") == "AXTitle")
    #expect(PathNormalizer.normalizeAttributeName("description") == "AXDescription")
    #expect(PathNormalizer.normalizeAttributeName("value") == "AXValue")
    #expect(PathNormalizer.normalizeAttributeName("id") == "AXIdentifier")
    #expect(PathNormalizer.normalizeAttributeName("identifier") == "AXIdentifier")
    #expect(PathNormalizer.normalizeAttributeName("bundleId") == "bundleIdentifier")

    // Test already normalized names
    #expect(PathNormalizer.normalizeAttributeName("AXTitle") == "AXTitle")
    #expect(PathNormalizer.normalizeAttributeName("AXDescription") == "AXDescription")

    // Test automatic capitalization for unmapped attributes
    #expect(PathNormalizer.normalizeAttributeName("customAttribute") == "AXCustomAttribute")
    #expect(PathNormalizer.normalizeAttributeName("visible") == "AXVisible")
  }

  @Test("Escape attribute values")
  func escapeAttributeValues() {
    // Test quote escaping
    #expect(
      PathNormalizer.escapeAttributeValue("Value with \"quotes\"") == "Value with \\\"quotes\\\"")

    // Test backslash escaping
    #expect(
      PathNormalizer.escapeAttributeValue("Value with \\ backslash") == "Value with \\\\ backslash")

    // Test control character escaping
    #expect(
      PathNormalizer.escapeAttributeValue("Value with \n newline") == "Value with \\n newline")
    #expect(PathNormalizer.escapeAttributeValue("Value with \t tab") == "Value with \\t tab")
    #expect(PathNormalizer.escapeAttributeValue("Value with \r return") == "Value with \\r return")

    // Test combined escaping
    #expect(
      PathNormalizer
        .escapeAttributeValue("\"Value\"\nwith\\everything")
        == "\\\"Value\\\"\\nwith\\\\everything",
    )
  }

  @Test("Unescape attribute values")
  func unescapeAttributeValues() {
    // Test quote unescaping
    #expect(
      PathNormalizer.unescapeAttributeValue("Value with \\\"quotes\\\"") == "Value with \"quotes\"")

    // Test backslash unescaping
    #expect(
      PathNormalizer.unescapeAttributeValue("Value with \\\\ backslash")
        == "Value with \\ backslash")

    // Test control character unescaping
    #expect(
      PathNormalizer.unescapeAttributeValue("Value with \\n newline") == "Value with \n newline")
    #expect(PathNormalizer.unescapeAttributeValue("Value with \\t tab") == "Value with \t tab")
    #expect(
      PathNormalizer.unescapeAttributeValue("Value with \\r return") == "Value with \r return")

    // Test combined unescaping
    #expect(
      PathNormalizer
        .unescapeAttributeValue("\\\"Value\\\"\\nwith\\\\everything")
        == "\"Value\"\nwith\\everything",
    )
  }

  @Test("Round-trip escaping and unescaping")
  func roundTripEscaping() {
    let testCases = [
      "Simple string",
      "String with \"quotes\"",
      "String with \\ backslash",
      "String with \n newline",
      "String with \t tab",
      "Complex string \"with\"\n\\everything\t\r",
    ]

    for testCase in testCases {
      let escaped = PathNormalizer.escapeAttributeValue(testCase)
      let unescaped = PathNormalizer.unescapeAttributeValue(escaped)
      #expect(unescaped == testCase, "Round-trip failed for: \(testCase)")
    }
  }

  @Test("Normalize path string")
  func testNormalizePathString() {
    // Test basic normalization
    let path1 = "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXDescription=\"OK\"]"
    let normalized1 = PathNormalizer.normalizePathString(path1)
    #expect(normalized1 != nil)
    #expect(normalized1!.contains("AXGroup[@AXTitle=\"Controls\"]"))
    #expect(normalized1!.contains("AXButton[@AXDescription=\"OK\"]"))

    // Test with mixed attributes
    let path2 =
      "ui://AXWindow/AXGroup[@AXTitle=\"Main\"][@id=\"mainGroup\"]/AXButton[@value=\"Click\"]"
    let normalized2 = PathNormalizer.normalizePathString(path2)
    #expect(normalized2 != nil)
    #expect(normalized2!.contains("AXGroup"))
    #expect(normalized2!.contains("AXTitle=\"Main\""))
    #expect(normalized2!.contains("AXIdentifier=\"mainGroup\""))
    #expect(normalized2!.contains("AXButton[@AXValue=\"Click\"]"))

    // Test with already normalized path
    let path3 =
      "ui://AXWindow/AXGroup[@AXTitle=\"Already Normalized\"]/AXButton[@AXEnabled=\"false\"]"
    let normalized3 = PathNormalizer.normalizePathString(path3)
    #expect(normalized3 != nil)
    #expect(normalized3!.contains("AXGroup[@AXTitle=\"Already Normalized\"]"))
    #expect(normalized3!.contains("AXButton[@AXEnabled=\"false\"]"))

    // Test with invalid path
    let path4 = "invalid://path"
    let normalized4 = PathNormalizer.normalizePathString(path4)
    #expect(normalized4 == nil)
  }

  // Test the generateNormalizedPath function with a mock element hierarchy
  @Test("Generate normalized path for UIElement")
  func testGenerateNormalizedPath() {
    // Create a sample element hierarchy
    let buttonElement = UIElement(
      path:
        "ui://AXButton[@AXTitle=\"OK\"][@AXDescription=\"OK Button\"][@AXIdentifier=\"okButton\"]",
      role: "AXButton",
      title: "OK",
      elementDescription: "OK Button",
      frame: CGRect(x: 10, y: 10, width: 100, height: 30),
      attributes: ["identifier": "okButton", "enabled": true],
    )

    let groupElement = UIElement(
      path: "ui://AXGroup[@AXTitle=\"Controls\"][@AXIdentifier=\"controlGroup\"]",
      role: "AXGroup",
      title: "Controls",
      frame: CGRect(x: 0, y: 0, width: 200, height: 100),
      children: [buttonElement],
      attributes: ["identifier": "controlGroup"],
    )

    // Set parent relationship
    // Since buttonElement is created with parent = nil, we need to update it here
    // This is a test-only workaround as UIElement uses weak parent references
    let buttonWithParent = UIElement(
      path:
        "ui://AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"][@AXDescription=\"OK Button\"][@AXIdentifier=\"okButton\"]",
      role: "AXButton",
      title: "OK",
      elementDescription: "OK Button",
      frame: CGRect(x: 10, y: 10, width: 100, height: 30),
      parent: groupElement,
      attributes: ["identifier": "okButton", "enabled": true],
    )

    // Generate path for the button
    let path = PathNormalizer.generateNormalizedPath(for: buttonWithParent)

    // The path should include normalized attributes for just this element
    #expect(path.contains("AXButton"))
    #expect(path.contains("AXIdentifier=\"okButton\""))
    #expect(path.contains("AXTitle=\"OK\""))
    #expect(path.contains("AXDescription=\"OK Button\""))
  }
}
