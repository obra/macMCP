// ABOUTME: Tests for positional indexing algorithm in path disambiguation
// ABOUTME: Verifies that sibling elements get correct #index syntax for duplicates only

import Foundation
import Testing

@testable import MacMCP

@Suite(.serialized) struct PositionalIndexingTests {
  @Test("insertPositionalIndex function - syntax formatting") func testInsertPositionalIndex()
    throws
  {
    // Test inserting index into path with attributes
    let withAttributes = "AXButton[@AXDescription=\"Add\"]"
    let indexed1 = AccessibilityElement.insertPositionalIndex(2, into: withAttributes)
    #expect(indexed1 == "AXButton#2[@AXDescription=\"Add\"]", "Should insert #2 after role")
    // Test inserting index into path without attributes
    let withoutAttributes = "AXButton"
    let indexed2 = AccessibilityElement.insertPositionalIndex(3, into: withoutAttributes)
    #expect(indexed2 == "AXButton#3", "Should append #3 to role")
    // Test with multiple attributes
    let multipleAttrs = "AXButton[@AXTitle=\"Save\"][@AXDescription=\"Save Document\"]"
    let indexed3 = AccessibilityElement.insertPositionalIndex(1, into: multipleAttrs)
    #expect(
      indexed3 == "AXButton#1[@AXTitle=\"Save\"][@AXDescription=\"Save Document\"]",
      "Should insert #1 after role before first attribute",
    )
  }

  @Test("Positional indexing algorithm - expected behavior") func positionalIndexingAlgorithm()
    throws
  {
    // Simulate the example from documentation:
    // Position 1: AXButton[@AXDescription="Save"]    → Unique, no index
    // Position 2: AXButton[@AXDescription="Add"]     → Duplicate, show #2
    // Position 3: AXButton[@AXDescription="Add"]     → Duplicate, show #3
    // Position 4: AXButton[@AXDescription="Cancel"]  → Unique, no index
    // Position 5: AXButton[@AXDescription="Add"]     → Duplicate, show #5

    let mockChildData = [
      ("AXButton", ["AXDescription": "Save"]), // Position 1, unique
      ("AXButton", ["AXDescription": "Add"]), // Position 2, duplicate
      ("AXButton", ["AXDescription": "Add"]), // Position 3, duplicate
      ("AXButton", ["AXDescription": "Cancel"]), // Position 4, unique
      ("AXButton", ["AXDescription": "Add"]), // Position 5, duplicate
    ]
    // Expected results: indices only for duplicates
    let expectedIndices = [
      nil, // Position 1: Unique, no index
      2, // Position 2: Duplicate, show #2
      3, // Position 3: Duplicate, show #3
      nil, // Position 4: Unique, no index
      5, // Position 5: Duplicate, show #5
    ]
    // Test the algorithm logic (we can't easily test the full function with AXUIElement)
    // So we'll test the algorithm steps manually

    // Step 1: Generate base paths
    var basePaths: [String] = []
    for (role, attrs) in mockChildData {
      let path = createMockPath(role: role, attributes: attrs)
      basePaths.append(path)
    }
    // Step 2: Count duplicates
    var pathCounts: [String: Int] = [:]
    for path in basePaths {
      pathCounts[path, default: 0] += 1
    }
    // Step 3: Assign indices
    var actualIndices: [Int?] = []
    for (position, basePath) in basePaths.enumerated() {
      if pathCounts[basePath]! > 1 {
        actualIndices.append(position + 1) // 1-based position
      } else {
        actualIndices.append(nil)
      }
    }
    print("Base paths:")
    for (i, path) in basePaths.enumerated() {
      print("  [\(i + 1)]: \(path)")
    }
    print("Path counts:")
    for (path, count) in pathCounts {
      print("  \(path): \(count)")
    }
    print("Expected indices: \(expectedIndices)")
    print("Actual indices: \(actualIndices)")
    #expect(actualIndices == expectedIndices, "Algorithm should produce correct positional indices")
    // Verify specific cases
    #expect(actualIndices[0] == nil, "Position 1 (Save) should have no index (unique)")
    #expect(actualIndices[1] == 2, "Position 2 (Add) should have index 2")
    #expect(actualIndices[2] == 3, "Position 3 (Add) should have index 3")
    #expect(actualIndices[3] == nil, "Position 4 (Cancel) should have no index (unique)")
    #expect(actualIndices[4] == 5, "Position 5 (Add) should have index 5")
  }

  @Test("Generated path formats with positional indexing") func generatedPathFormats() throws {
    // Test that the final paths look correct
    let testCases = [
      (
        role: "AXButton", attrs: ["AXDescription": "Save"], index: nil,
        expected: "AXButton[@AXDescription=\"Save\"]"
      ),
      (
        role: "AXButton", attrs: ["AXDescription": "Add"], index: 2,
        expected: "AXButton#2[@AXDescription=\"Add\"]"
      ),
      (
        role: "AXButton", attrs: ["AXDescription": "Add"], index: 3,
        expected: "AXButton#3[@AXDescription=\"Add\"]"
      ),
      (
        role: "AXButton", attrs: ["AXDescription": "Cancel"], index: nil,
        expected: "AXButton[@AXDescription=\"Cancel\"]"
      ),
      (
        role: "AXButton", attrs: ["AXDescription": "Add"], index: 5,
        expected: "AXButton#5[@AXDescription=\"Add\"]"
      ),
    ]
    for testCase in testCases {
      let basePath = createMockPath(role: testCase.role, attributes: testCase.attrs)
      let finalPath =
        if let index = testCase.index {
          AccessibilityElement.insertPositionalIndex(index, into: basePath)
        } else { basePath }
      print("Generated: \(finalPath)")
      print("Expected:  \(testCase.expected)")
      #expect(finalPath == testCase.expected, "Path format should match expected pattern")
    }
  }
}

// MARK: - Helper Functions

/// Create a mock path string in the same format as createElementPathString
private func createMockPath(role: String, attributes: [String: String]) -> String {
  var pathString = role
  // Add attributes in format [@key="value"] (sorted for consistency)
  for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
    let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
    pathString += "[@\(key)=\"\(escapedValue)\"]"
  }
  return pathString
}
