// ABOUTME: UIElementPathInitUnitTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Testing

@testable import MacMCP

// Let's use a different approach for testing without extension conflicts

/// These tests focus on specific aspects of UIElement's path-based initialization
/// without relying on complex mocks of the entire UI hierarchy
@Suite("UIElement Path Initialization Unit Tests")
struct UIElementPathInitUnitTests {
  // Test the parsing functionality directly
  @Test("Test ElementPath parsing")
  func elementPathParsing() throws {
    // Simple path
    let simplePath = try ElementPath.parse("macos://ui/AXApplication/AXWindow")
    #expect(simplePath.segments.count == 2)
    #expect(simplePath.segments[0].role == "AXApplication")
    #expect(simplePath.segments[1].role == "AXWindow")

    // Path with attributes
    let attributePath =
      try ElementPath
      .parse("macos://ui/AXApplication[@bundleId=\"com.test\"]/AXWindow[@AXTitle=\"Title\"]")
    #expect(attributePath.segments.count == 2)
    #expect(attributePath.segments[0].attributes["bundleId"] == "com.test")
    #expect(attributePath.segments[1].attributes["AXTitle"] == "Title")

    // Path with index
    let indexPath = try ElementPath.parse("macos://ui/AXApplication/AXGroup[1]/AXButton")
    #expect(indexPath.segments.count == 3)
    #expect(indexPath.segments[1].index == 1)
  }

  // Test error cases for path parsing
  @Test("Test ElementPath parsing errors")
  func elementPathParsingErrors() throws {
    // Invalid prefix
    do {
      _ = try ElementPath.parse("invalid://AXApplication")
      #expect(Bool(false), "Expected an error but none was thrown")
    } catch let error as ElementPathError {
      switch error {
      case .invalidPathPrefix:
        // This is expected
        break
      default:
        #expect(Bool(false), "Expected invalidPathPrefix error but got: \(error)")
      }
    }

    // Empty path
    do {
      _ = try ElementPath.parse("macos://ui/")
      #expect(Bool(false), "Expected an error but none was thrown")
    } catch let error as ElementPathError {
      switch error {
      case .emptyPath:
        // This is expected
        break
      default:
        #expect(Bool(false), "Expected emptyPath error but got: \(error)")
      }
    }
  }

  // Test path segment creation and properties
  @Test("Test PathSegment properties")
  func pathSegmentProperties() {
    // Simple segment
    let simpleSegment = PathSegment(role: "AXButton")
    #expect(simpleSegment.role == "AXButton")
    #expect(simpleSegment.attributes.isEmpty)
    #expect(simpleSegment.index == nil)

    // Segment with attributes
    let attributeSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "OK"])
    #expect(attributeSegment.role == "AXButton")
    #expect(attributeSegment.attributes["AXTitle"] == "OK")

    // Segment with index
    let indexSegment = PathSegment(role: "AXButton", attributes: [:], index: 2)
    #expect(indexSegment.role == "AXButton")
    #expect(indexSegment.index == 2)
  }

  // Test string representation of path segments
  @Test("Test PathSegment toString")
  func pathSegmentToString() {
    // Simple segment
    let simpleSegment = PathSegment(role: "AXButton")
    #expect(simpleSegment.toString() == "AXButton")

    // Segment with attributes
    let attributeSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "OK"])
    #expect(attributeSegment.toString() == "AXButton[@AXTitle=\"OK\"]")

    // Segment with multiple attributes (should be sorted alphabetically)
    let multiAttributeSegment = PathSegment(
      role: "AXButton",
      attributes: ["AXTitle": "OK", "AXDescription": "Button"],
    )
    #expect(
      multiAttributeSegment.toString() == "AXButton[@AXDescription=\"Button\"][@AXTitle=\"OK\"]")

    // Segment with index
    let indexSegment = PathSegment(role: "AXButton", attributes: [:], index: 2)
    #expect(indexSegment.toString() == "AXButton[2]")

    // Segment with attributes and index
    let fullSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "OK"], index: 2)
    #expect(fullSegment.toString() == "AXButton[@AXTitle=\"OK\"][2]")
  }

  // Test string representation of full paths
  @Test("Test ElementPath toString")
  func elementPathToString() throws {
    // Simple path
    let simplePath = try ElementPath.parse("macos://ui/AXApplication/AXWindow")
    #expect(simplePath.toString() == "macos://ui/AXApplication/AXWindow")

    // Complex path
    let complexPath =
      try ElementPath
      .parse("macos://ui/AXApplication[@bundleId=\"com.test\"]/AXWindow[@AXTitle=\"Title\"][1]")
    #expect(
      complexPath
        .toString()
        == "macos://ui/AXApplication[@bundleId=\"com.test\"]/AXWindow[@AXTitle=\"Title\"][1]",
    )
  }

  // Test appending segments to paths
  @Test("Test appending segments to paths")
  func testAppendingSegments() throws {
    // Start with a simple path
    let startPath = try ElementPath.parse("macos://ui/AXApplication")

    // Create a new segment
    let newSegment = PathSegment(role: "AXWindow", attributes: ["AXTitle": "Window"])

    // Append the segment
    let extendedPath = try startPath.appendingSegment(newSegment)

    // Verify the resulting path
    #expect(extendedPath.segments.count == 2)
    #expect(extendedPath.segments[1].role == "AXWindow")
    #expect(extendedPath.segments[1].attributes["AXTitle"] == "Window")
    #expect(extendedPath.toString() == "macos://ui/AXApplication/AXWindow[@AXTitle=\"Window\"]")

    // Append multiple segments
    let moreSegments = [
      PathSegment(role: "AXGroup"),
      PathSegment(role: "AXButton", attributes: ["AXTitle": "OK"]),
    ]

    let fullPath = try startPath.appendingSegments(moreSegments)
    #expect(fullPath.segments.count == 3)
    #expect(fullPath.segments[1].role == "AXGroup")
    #expect(fullPath.segments[2].role == "AXButton")
    #expect(fullPath.toString() == "macos://ui/AXApplication/AXGroup/AXButton[@AXTitle=\"OK\"]")
  }
}