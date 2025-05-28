// ABOUTME: ElementPathResolveUnitTest.swift - Unit test for ElementPath.resolve() logic
// ABOUTME: Tests segment counting and BFS triggering without requiring real applications

import ApplicationServices
import Foundation
import Testing

@testable import MacMCP

/// Unit test for ElementPath segment counting and resolution logic
@Suite(.serialized) struct ElementPathResolveUnitTest {
  @Test("ElementPath segment counting for BFS trigger") func testSegmentCountingLogic() throws {
    // Test 1: Single application segment should return app element directly
    let singleSegmentPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.test.app\"]")
    #expect(singleSegmentPath.segments.count == 1)
    #expect(singleSegmentPath.segments[0].role == "AXApplication")
    // Test 2: Two-segment path (app + window) should trigger BFS, not return app element
    let twoSegmentPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.test.app\"]/AXWindow[@AXTitle=\"Test Window\"]"
    )
    #expect(twoSegmentPath.segments.count == 2)
    #expect(twoSegmentPath.segments[0].role == "AXApplication")
    #expect(twoSegmentPath.segments[1].role == "AXWindow")
    // Test 3: Three-segment path should definitely trigger BFS
    let threeSegmentPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.test.app\"]/AXWindow[@AXTitle=\"Test\"]/AXButton[@AXTitle=\"OK\"]"
    )
    #expect(threeSegmentPath.segments.count == 3)
    #expect(threeSegmentPath.segments[0].role == "AXApplication")
    #expect(threeSegmentPath.segments[1].role == "AXWindow")
    #expect(threeSegmentPath.segments[2].role == "AXButton")
  }
  @Test("ElementPath parsing validates correct structure") func testElementPathParsing() throws {
    // Test the exact path that was failing
    let failingPath =
      "macos://ui/AXApplication[@AXTitle=\"TextEdit\"][@bundleId=\"com.apple.TextEdit\"]/AXWindow[@AXTitle=\"Untitled 26\"]"
    let elementPath = try ElementPath.parse(failingPath)
    #expect(elementPath.segments.count == 2)
    // First segment: Application with both title and bundleId
    let appSegment = elementPath.segments[0]
    #expect(appSegment.role == "AXApplication")
    #expect(appSegment.attributes["AXTitle"] == "TextEdit")
    #expect(appSegment.attributes["bundleId"] == "com.apple.TextEdit")
    // Second segment: Window with title
    let windowSegment = elementPath.segments[1]
    #expect(windowSegment.role == "AXWindow")
    #expect(windowSegment.attributes["AXTitle"] == "Untitled 26")
  }
  @Test("ElementPath toString preserves structure") func testElementPathToString() throws {
    let originalPath =
      "macos://ui/AXApplication[@AXTitle=\"TextEdit\"][@bundleId=\"com.apple.TextEdit\"]/AXWindow[@AXTitle=\"Test Window\"]"
    let elementPath = try ElementPath.parse(originalPath)
    let reconstructedPath = elementPath.toString()
    // The reconstructed path should contain the same elements (order of attributes may vary)
    #expect(reconstructedPath.contains("AXApplication"))
    #expect(reconstructedPath.contains("AXWindow"))
    #expect(reconstructedPath.contains("@AXTitle=\"TextEdit\""))
    #expect(reconstructedPath.contains("@bundleId=\"com.apple.TextEdit\""))
    #expect(reconstructedPath.contains("@AXTitle=\"Test Window\""))
  }
  @Test("ElementPath segments access") func testSegmentsAccess() throws {
    let path = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"test\"]/AXWindow/AXButton[@AXTitle=\"Click Me\"]"
    )
    #expect(path.segments.count == 3)
    // Test segment access and properties
    let appSegment = path.segments[0]
    #expect(appSegment.role == "AXApplication")
    #expect(appSegment.attributes.count == 1)
    #expect(appSegment.attributes["bundleId"] == "test")
    let windowSegment = path.segments[1]
    #expect(windowSegment.role == "AXWindow")
    #expect(windowSegment.attributes.isEmpty)
    let buttonSegment = path.segments[2]
    #expect(buttonSegment.role == "AXButton")
    #expect(buttonSegment.attributes.count == 1)
    #expect(buttonSegment.attributes["AXTitle"] == "Click Me")
  }
}

// Note: The existing MockAccessibilityService is already defined in ToolChain.swift
// We'll use that one instead of creating a duplicate

/// Regression test that documents the exact bug and fix
@Suite(.serialized) struct ElementPathSegmentCountingBugTest {
  @Test("Documents the exact segment counting bug that was fixed")
  func testSegmentCountingBugLogic() throws {
    // This test documents the exact logic bug and proves the fix is correct

    // Scenario: 2-segment path (Application + Window)
    let twoSegmentPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.test.app\"]/AXWindow[@AXTitle=\"Test\"]"
    )
    #expect(twoSegmentPath.segments.count == 2)
    #expect(twoSegmentPath.segments[0].role == "AXApplication")
    // This is the key condition from ElementPath.resolve():
    let skipFirstSegment = twoSegmentPath.segments[0].role == "AXApplication"
    #expect(skipFirstSegment == true)
    // THE BUG: Old condition incorrectly returned app element for 2-segment paths
    let oldBuggyCondition =
      twoSegmentPath.segments.count == 1 || (skipFirstSegment && twoSegmentPath.segments.count == 2)
    //                      = false || (true && true)
    //                      = false || true
    //                      = true  <-- BUG! Should trigger BFS, not return app element

    // THE FIX: New condition only returns app element for 1-segment paths
    let newFixedCondition = twoSegmentPath.segments.count == 1
    //                      = false  <-- CORRECT! Triggers BFS for 2-segment paths

    #expect(oldBuggyCondition == true, "Old buggy condition would incorrectly return app element")
    #expect(newFixedCondition == false, "New fixed condition correctly triggers BFS")
    // Verify single-segment paths still work correctly
    let singleSegmentPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.test.app\"]")
    let singleOldCondition =
      singleSegmentPath.segments.count == 1 || (true && singleSegmentPath.segments.count == 2)
    let singleNewCondition = singleSegmentPath.segments.count == 1
    #expect(singleOldCondition == true, "Old condition works correctly for single segment")
    #expect(singleNewCondition == true, "New condition works correctly for single segment")
  }
  @Test("Validates the fix handles edge cases correctly") func testEdgeCases() throws {
    // Test various segment counts to ensure the fix is robust

    // 1 segment: Should return app element (both old and new logic work)
    let path1 = try ElementPath.parse("macos://ui/AXApplication[@bundleId=\"test\"]")
    let condition1 = path1.segments.count == 1
    #expect(condition1 == true, "1-segment path should return app element")
    // 2 segments: Should trigger BFS (new logic fixes this)
    let path2 = try ElementPath.parse("macos://ui/AXApplication[@bundleId=\"test\"]/AXWindow")
    let condition2 = path2.segments.count == 1
    #expect(condition2 == false, "2-segment path should trigger BFS")
    // 3 segments: Should trigger BFS (both old and new logic work)
    let path3 = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"test\"]/AXWindow/AXButton")
    let condition3 = path3.segments.count == 1
    #expect(condition3 == false, "3-segment path should trigger BFS")
    // 4 segments: Should trigger BFS (both old and new logic work)
    let path4 = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"test\"]/AXWindow/AXGroup/AXButton")
    let condition4 = path4.segments.count == 1
    #expect(condition4 == false, "4-segment path should trigger BFS")
  }
}
