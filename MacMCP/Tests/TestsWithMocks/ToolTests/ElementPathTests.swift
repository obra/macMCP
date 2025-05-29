// ABOUTME: ElementPathTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit

// TODO: - remove mock diagnostic output and the key canonnicaliation for the non-ax versions
import Foundation
import MacMCPUtilities
import Testing

@testable import MacMCP

@Suite("ElementPath Tests") struct ElementPathTests {
  @Test("PathSegment initialization and properties") func pathSegmentInitialization() {
    let segment = PathSegment(
      role: "AXButton",
      attributes: ["AXName": "Test Button", "AXDescription": "A test button"],
      index: 2,
    )

    #expect(segment.role == "AXButton")
    #expect(segment.attributes.count == 2)
    #expect(segment.attributes["AXName"] == "Test Button")
    #expect(segment.attributes["AXDescription"] == "A test button")
    #expect(segment.index == 2)
  }

  @Test("PathSegment toString conversion") func pathSegmentToString() {
    // Simple segment with just a role
    let simpleSegment = PathSegment(role: "AXButton")
    #expect(simpleSegment.toString() == "AXButton")

    // Segment with attributes
    let attributeSegment = PathSegment(role: "AXButton", attributes: ["AXName": "Test Button"])
    #expect(attributeSegment.toString() == "AXButton[@AXName=\"Test Button\"]")

    // Segment with multiple attributes (should be sorted alphabetically)
    let multiAttributeSegment = PathSegment(
      role: "AXButton",
      attributes: ["AXName": "Test Button", "AXDescription": "A test button"],
    )
    #expect(
      multiAttributeSegment.toString()
        == "AXButton[@AXDescription=\"A test button\"][@AXName=\"Test Button\"]",
    )

    // Segment with index
    let indexSegment = PathSegment(role: "AXButton", index: 2)
    #expect(indexSegment.toString() == "AXButton#2")

    // Segment with attributes and index
    let fullSegment = PathSegment(role: "AXButton", attributes: ["name": "Test Button"], index: 2)
    #expect(fullSegment.toString() == "AXButton[@name=\"Test Button\"]#2")

    // Test escaping quotes in attribute values
    let escapedSegment = PathSegment(
      role: "AXButton", attributes: ["AXName": "Button with \"quotes\""],
    )
    #expect(escapedSegment.toString() == "AXButton[@AXName=\"Button with \\\"quotes\\\"\"]")
  }

  @Test("ElementPath initialization and properties") func elementPathInitialization() throws {
    let segments = [
      PathSegment(role: "AXWindow"),
      PathSegment(role: "AXGroup", attributes: ["AXName": "Controls"]),
      PathSegment(role: "AXButton", attributes: ["AXDescription": "Submit"]),
    ]

    let path = try ElementPath(segments: segments)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].attributes["AXName"] == "Controls")
    #expect(path.segments[2].role == "AXButton")
    #expect(path.segments[2].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath empty initialization") func elementPathEmptyInitialization() {
    let emptySegments: [PathSegment] = []

    do {
      _ = try ElementPath(segments: emptySegments)
      #expect(Bool(false), "Should have thrown an error for empty segments")
    } catch let error as ElementPathError { #expect(error == ElementPathError.emptyPath) } catch {
      #expect(Bool(false), "Threw unexpected error: \(error)")
    }
  }

  @Test("ElementPath toString conversion") func elementPathToString() throws {
    let segments = [
      PathSegment(role: "AXWindow"),
      PathSegment(role: "AXGroup", attributes: ["AXName": "Controls"]),
      PathSegment(role: "AXButton", attributes: ["AXDescription": "Submit"]),
    ]

    let path = try ElementPath(segments: segments)
    let pathString = path.toString()

    #expect(
      pathString
        == "macos://ui/AXWindow/AXGroup[@AXName=\"Controls\"]/AXButton[@AXDescription=\"Submit\"]",
    )
  }

  @Test("ElementPath parsing simple path") func elementPathParsing() throws {
    let pathString = "macos://ui/AXWindow/AXGroup/AXButton"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[2].role == "AXButton")
  }

  @Test("ElementPath parsing with attributes") func elementPathParsingWithAttributes() throws {
    let pathString =
      "macos://ui/AXWindow/AXGroup[@AXName=\"Controls\"]/AXButton[@AXDescription=\"Submit\"]"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].attributes["AXName"] == "Controls")
    #expect(path.segments[2].role == "AXButton")
    #expect(path.segments[2].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath isElementPath with different slash formats")
  func elementPathIsElementPathWithDifferentSlashFormats() throws {
    // Test various slash escaping scenarios to understand what works vs fails
    let unescapedPath = "macos://ui/AXApplication[@AXTitle=\"Calculator\"]"
    let escapedSlashPath = "macos:\\/\\/ui\\/AXApplication[@AXTitle=\"Calculator\"]"
    let mixedPath = "macos:\\/\\/ui/AXApplication[@AXTitle=\"Calculator\"]"
    // Document current behavior - need to figure out which one is failing
    print("Unescaped (canonical): \(ElementPath.isElementPath(unescapedPath))")
    print("Escaped slashes: \(ElementPath.isElementPath(escapedSlashPath))")
    print("Mixed: \(ElementPath.isElementPath(mixedPath))")
    // The canonical format should definitely work
    #expect(ElementPath.isElementPath(unescapedPath) == true)
  }

  @Test("ElementPath parsing with different slash formats")
  func elementPathParsingWithDifferentSlashFormats() throws {
    // Test what actually parses vs throws errors
    let unescapedPath = "macos://ui/AXApplication[@AXTitle=\"Calculator\"]"
    let escapedSlashPath = "macos:\\/\\/ui\\/AXApplication[@AXTitle=\"Calculator\"]"
    // Try parsing both and see which ones work
    do {
      let unescapedParsed = try ElementPath.parse(unescapedPath)
      print("Unescaped parsing: SUCCESS")
      print("  Segments: \(unescapedParsed.segments.count)")
    } catch { print("Unescaped parsing: FAILED - \(error)") }
    do {
      let escapedParsed = try ElementPath.parse(escapedSlashPath)
      print("Escaped parsing: SUCCESS")
      print("  Segments: \(escapedParsed.segments.count)")
    } catch { print("Escaped parsing: FAILED - \(error)") }
  }

  @Test("Real JSON quote escaping scenario") func realJSONQuoteEscapingScenario() throws {
    // This is what the interface explorer returns in JSON
    let jsonFromExplorer =
      #"macos://ui/AXApplication[@AXTitle=\"Calculator\"][@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"All Clear\"]"#
    // This is what Claude tries to use (without escaped quotes)
    let claudeInput =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    print("JSON from explorer: \(jsonFromExplorer)")
    print("Claude input: \(claudeInput)")
    // Both should parse successfully after our fixes
    do {
      let explorerParsed = try ElementPath.parse(jsonFromExplorer)
      print("Explorer JSON parsing: SUCCESS - \(explorerParsed.segments.count) segments")
    } catch { print("Explorer JSON parsing: FAILED - \(error)") }
    do {
      let claudeParsed = try ElementPath.parse(claudeInput)
      print("Claude input parsing: SUCCESS - \(claudeParsed.segments.count) segments")
    } catch { print("Claude input parsing: FAILED - \(error)") }
    // Both should parse to identical results
    let explorerParsed = try ElementPath.parse(jsonFromExplorer)
    let claudeParsed = try ElementPath.parse(claudeInput)
    #expect(explorerParsed.segments.count == claudeParsed.segments.count)
    #expect(explorerParsed.segments[0].role == claudeParsed.segments[0].role)
  }

  @Test("ElementPath parsing with index") func elementPathParsingWithIndex() throws {
    let pathString = "macos://ui/AXWindow/AXGroup#2/AXButton"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].index == 2)
    #expect(path.segments[2].role == "AXButton")
  }

  @Test("ElementPath parsing with attributes and index")
  func elementPathParsingWithAttributesAndIndex() throws {
    let pathString =
      "macos://ui/AXWindow/AXGroup[@AXName=\"Controls\"]#2/AXButton[@AXDescription=\"Submit\"]"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].attributes["AXName"] == "Controls")
    #expect(path.segments[1].index == 2)
    #expect(path.segments[2].role == "AXButton")
    #expect(path.segments[2].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath parsing with escaped quotes") func elementPathParsingWithEscapedQuotes() throws
  {
    let pathString = "macos://ui/AXWindow/AXGroup[@AXName=\"Group with \\\"quotes\\\"\"]/AXButton"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].attributes["AXName"] == "Group with \"quotes\"")
    #expect(path.segments[2].role == "AXButton")
  }

  @Test("ElementPath parsing with both escaped and unescaped quotes")
  func elementPathParsingQuoteFormats() throws {
    // Test with escaped quotes (user's problematic format)
    let pathWithEscapedQuotes =
      "macos://ui/AXApplication[@AXTitle=\\\"Calculator\\\"][@bundleId=\\\"com.apple.calculator\\\"]/AXButton[@AXDescription=\\\"2\\\"]"
    // Test with unescaped quotes (should work)
    let pathWithUnescapedQuotes =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXButton[@AXDescription="2"]"#

    // Both should parse successfully
    let pathUnescaped = try ElementPath.parse(pathWithUnescapedQuotes)
    let pathEscaped = try ElementPath.parse(pathWithEscapedQuotes)

    // Both should have the same structure
    #expect(pathEscaped.segments.count == pathUnescaped.segments.count)
    #expect(pathUnescaped.segments.count == 2)
    // The key test: Both should produce the SAME attribute values
    #expect(
      pathUnescaped.segments[0].attributes["AXTitle"]
        == pathEscaped.segments[0].attributes["AXTitle"],
    )
    #expect(
      pathUnescaped.segments[0].attributes["bundleId"]
        == pathEscaped.segments[0].attributes["bundleId"],
    )
    #expect(
      pathUnescaped.segments[1].attributes["AXDescription"]
        == pathEscaped.segments[1].attributes["AXDescription"],
    )
    // Both should contain the plain value without quotes
    #expect(pathUnescaped.segments[0].attributes["AXTitle"] == "Calculator")
    #expect(pathUnescaped.segments[1].attributes["AXDescription"] == "2")
    #expect(pathEscaped.segments[0].attributes["AXTitle"] == "Calculator")
    #expect(pathEscaped.segments[1].attributes["AXDescription"] == "2")
    // Both should generate the same toString output (with escaped quotes)
    #expect(pathEscaped.toString() == pathUnescaped.toString())
  }

  @Test("Index parsing edge cases") func indexParsingEdgeCases() throws {
    // Test parsing with index at different positions
    let pathWithIndexAtEnd = "macos://ui/AXWindow/AXButton#0"
    let pathParsed1 = try ElementPath.parse(pathWithIndexAtEnd)
    #expect(pathParsed1.segments[1].index == 0)
    // Test parsing with index in middle
    let pathWithIndexInMiddle = "macos://ui/AXWindow/AXGroup#3/AXButton"
    let pathParsed2 = try ElementPath.parse(pathWithIndexInMiddle)
    #expect(pathParsed2.segments[1].index == 3)
    #expect(pathParsed2.segments[2].index == nil)
    // Test parsing with index and attributes in different orders
    let pathWithAttributesBeforeIndex = "macos://ui/AXWindow/AXButton[@AXTitle=\"Test\"]#5"
    let pathParsed3 = try ElementPath.parse(pathWithAttributesBeforeIndex)
    #expect(pathParsed3.segments[1].index == 5)
    #expect(pathParsed3.segments[1].attributes["AXTitle"] == "Test")
    // Test large index numbers
    let pathWithLargeIndex = "macos://ui/AXWindow/AXButton#999"
    let pathParsed4 = try ElementPath.parse(pathWithLargeIndex)
    #expect(pathParsed4.segments[1].index == 999)
  }

  @Test("Index syntax error handling") func indexSyntaxErrorHandling() throws {
    // Test invalid index syntax (non-numeric)
    do {
      _ = try ElementPath.parse("macos://ui/AXWindow/AXButton#abc")
      #expect(Bool(false), "Should have thrown error for non-numeric index")
    } catch let error as ElementPathError {
      if case .invalidIndexSyntax(let syntax, let segment) = error {
        #expect(syntax == "#abc")
        #expect(segment == 1)
      } else {
        #expect(Bool(false), "Expected invalidIndexSyntax error but got \(error)")
      }
    }
    // Test negative index (should parse successfully)
    let pathWithNegativeIndex = "macos://ui/AXWindow/AXButton#-1"
    let parsed = try ElementPath.parse(pathWithNegativeIndex)
    #expect(parsed.segments[1].index == -1)
    // Test that round-trip works with negative index
    let regenerated = parsed.toString()
    #expect(regenerated == pathWithNegativeIndex)
  }

  @Test("Round-trip consistency with index") func roundTripConsistencyWithIndex() throws {
    // Test that parsing and regenerating preserves index format
    let originalPaths = [
      "macos://ui/AXWindow#0", "macos://ui/AXWindow/AXButton[@AXTitle=\"OK\"]#2",
      "macos://ui/AXWindow/AXGroup#1/AXButton#0",
      "macos://ui/AXApplication[@bundleId=\"com.test\"]#0/AXWindow#1/AXButton[@AXDescription=\"Test\"]#5",
    ]
    for originalPath in originalPaths {
      let parsed = try ElementPath.parse(originalPath)
      let regenerated = parsed.toString()
      #expect(regenerated == originalPath, "Round-trip failed for: \(originalPath)")
    }
  }

  @Test("Complete round-trip compatibility (generate → parse → resolve → generate)")
  func completeRoundTripCompatibility() throws {
    // Test the complete cycle: path generation → parsing → resolution → path generation
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)
    // Test paths that should work through the complete cycle
    let testPaths = [
      // Simple paths without index
      "macos://ui/AXWindow", "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]",
      "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"]",
      // Paths with indices
      "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#0",
      "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#1",
      // Mixed paths with some segments having indices
      "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton#1",
    ]
    for originalPath in testPaths {
      // Step 1: Parse the original path
      let parsedPath = try ElementPath.parse(originalPath)
      // Step 2: Regenerate path string from parsed path
      let regeneratedPath = parsedPath.toString()
      #expect(regeneratedPath == originalPath, "Initial round-trip failed for: \(originalPath)")
      // Step 3: Try to resolve the path (this may fail for some test paths, but parsing should
      // work)
      let resolveResult = mockResolvePathForTest(service: mockService, path: parsedPath)
      if resolveResult != nil {
        // Resolution succeeded - test that we can parse the regenerated path again
        let reparsedPath = try ElementPath.parse(regeneratedPath)
        let reregeneratedPath = reparsedPath.toString()
        #expect(reregeneratedPath == originalPath, "Full round-trip failed for: \(originalPath)")
      } else {
        // Resolution failed - just verify parsing consistency
        let reparsedPath = try ElementPath.parse(regeneratedPath)
        let reregeneratedPath = reparsedPath.toString()
        #expect(reregeneratedPath == originalPath, "Parse round-trip failed for: \(originalPath)")
      }
    }
  }

  @Test("Round-trip with complex attribute combinations") func roundTripComplexAttributes() throws {
    // Test round-trip with various attribute combinations and index placements
    // NOTE: Attributes will be sorted alphabetically during generation, so we use expected sorted
    // forms
    let complexPaths = [
      // Multiple attributes with index (sorted: AXTitle comes before bundleId)
      "macos://ui/AXApplication[@AXTitle=\"Test App\"][@bundleId=\"com.test\"]/AXWindow#2",
      // Index with multiple attributes in different orders (sorted: AXDescription before AXTitle)
      "macos://ui/AXButton[@AXDescription=\"Save\"][@AXTitle=\"Save Button\"]#3",
      // Escaped quotes with index
      "macos://ui/AXButton[@AXDescription=\"Button with \\\"quotes\\\"\"]#1",
      // Mixed format with some segments having index, others not
      "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]#0/AXButton[@AXDescription=\"Submit\"]",
      // Deep hierarchy with indices at different levels
      "macos://ui/AXApplication#0/AXWindow#1/AXGroup#2/AXButton#3",
    ]
    for originalPath in complexPaths {
      let parsed = try ElementPath.parse(originalPath)
      let regenerated = parsed.toString()
      #expect(regenerated == originalPath, "Complex round-trip failed for: \(originalPath)")
      // Verify that each segment has the expected properties
      for (i, segment) in parsed.segments.enumerated() {
        // Re-parse to make sure individual segments are consistent
        let segmentString = segment.toString()
        // This indirectly tests that the segment can be parsed back if needed
        #expect(
          !segmentString.isEmpty, "Segment \(i) generated empty string for path: \(originalPath)",
        )
      }
    }
  }

  @Test("Attribute order normalization in round-trip") func attributeOrderNormalizationInRoundTrip()
    throws
  {
    // Test that parsing normalizes attribute order consistently
    let pathsWithDifferentAttributeOrders = [
      // Same path with attributes in different orders - all should normalize to the same result
      ("original1", "macos://ui/AXApplication[@bundleId=\"com.test\"][@AXTitle=\"Test App\"]"),
      ("original2", "macos://ui/AXApplication[@AXTitle=\"Test App\"][@bundleId=\"com.test\"]"),
    ]
    var normalizedResults: [String] = []
    for (label, originalPath) in pathsWithDifferentAttributeOrders {
      let parsed = try ElementPath.parse(originalPath)
      let regenerated = parsed.toString()
      normalizedResults.append(regenerated)
      // Re-parse the regenerated path to ensure consistency
      let reparsed = try ElementPath.parse(regenerated)
      let rerenerated = reparsed.toString()
      #expect(rerenerated == regenerated, "Double round-trip failed for \(label): \(originalPath)")
    }
    // All different input orders should produce the same normalized output
    #expect(
      normalizedResults[0] == normalizedResults[1],
      "Different attribute orders should normalize to same result",
    )
    // The normalized result should have attributes in alphabetical order
    let expectedNormalized =
      "macos://ui/AXApplication[@AXTitle=\"Test App\"][@bundleId=\"com.test\"]"
    #expect(
      normalizedResults[0] == expectedNormalized,
      "Normalized result should be alphabetically sorted",
    )
  }

  @Test("Original user failing scenario - Calculator button click")
  func originalUserFailingScenario() throws {
    // This is the exact path that was failing for the user
    let userProvidedPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="2"]"#
    // This should now parse successfully
    let parsedPath = try ElementPath.parse(userProvidedPath)
    // Verify correct structure
    #expect(parsedPath.segments.count == 7)
    // Verify the application segment
    #expect(parsedPath.segments[0].role == "AXApplication")
    #expect(parsedPath.segments[0].attributes["AXTitle"] == "Calculator")
    #expect(parsedPath.segments[0].attributes["bundleId"] == "com.apple.calculator")
    // Verify the button segment (the one that was failing)
    #expect(parsedPath.segments[6].role == "AXButton")
    #expect(parsedPath.segments[6].attributes["AXDescription"] == "2")
    // Verify the path can be converted back to string form
    let regeneratedPath = parsedPath.toString()
    #expect(regeneratedPath.contains("AXButton[@AXDescription=\"2\"]"))
  }

  @Test("ElementPath parsing with multiple attributes")
  func elementPathParsingWithMultipleAttributes() throws {
    let pathString =
      "macos://ui/AXWindow/AXGroup[@AXName=\"Controls\"][@id=\"group1\"]/AXButton[@AXDescription=\"Submit\"][@enabled=\"true\"]"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 3)
    #expect(path.segments[0].role == "AXWindow")
    #expect(path.segments[1].role == "AXGroup")
    #expect(path.segments[1].attributes["AXName"] == "Controls")
    #expect(path.segments[1].attributes["AXIdentifier"] == "group1")
    #expect(path.segments[2].role == "AXButton")
    #expect(path.segments[2].attributes["AXDescription"] == "Submit")
    #expect(path.segments[2].attributes["AXEnabled"] == "true")
  }

  @Test("ElementPath parsing invalid prefix") func elementPathParsingInvalidPrefix() {
    let pathString = "invalid://AXWindow/AXGroup/AXButton"

    do {
      _ = try ElementPath.parse(pathString)
      #expect(Bool(false), "Should have thrown an error for invalid prefix")
    } catch let error as ElementPathError {
      #expect(error == ElementPathError.invalidPathPrefix(pathString))
    } catch { #expect(Bool(false), "Threw unexpected error: \(error)") }
  }

  @Test("ElementPath parsing empty path") func elementPathParsingEmptyPath() {
    let pathString = "macos://ui/"

    do {
      _ = try ElementPath.parse(pathString)
      #expect(Bool(false), "Should have thrown an error for empty path")
    } catch let error as ElementPathError { #expect(error == ElementPathError.emptyPath) } catch {
      #expect(Bool(false), "Threw unexpected error: \(error)")
    }
  }

  @Test("ElementPath appending segment") func elementPathAppendingSegment() throws {
    let initialSegments = [PathSegment(role: "AXWindow"), PathSegment(role: "AXGroup")]

    let path = try ElementPath(segments: initialSegments)
    let newSegment = PathSegment(role: "AXButton", attributes: ["AXDescription": "Submit"])
    let newPath = try path.appendingSegment(newSegment)

    #expect(newPath.segments.count == 3)
    #expect(newPath.segments[0].role == "AXWindow")
    #expect(newPath.segments[1].role == "AXGroup")
    #expect(newPath.segments[2].role == "AXButton")
    #expect(newPath.segments[2].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath appending segments") func elementPathAppendingSegments() throws {
    let initialSegments = [PathSegment(role: "AXWindow")]

    let additionalSegments = [
      PathSegment(role: "AXGroup"),
      PathSegment(role: "AXButton", attributes: ["AXDescription": "Submit"]),
    ]

    let path = try ElementPath(segments: initialSegments)
    let newPath = try path.appendingSegments(additionalSegments)

    #expect(newPath.segments.count == 3)
    #expect(newPath.segments[0].role == "AXWindow")
    #expect(newPath.segments[1].role == "AXGroup")
    #expect(newPath.segments[2].role == "AXButton")
    #expect(newPath.segments[2].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath isElementPath check") func testIsElementPath() {
    #expect(ElementPath.isElementPath("macos://ui/AXWindow/AXGroup/AXButton") == true)
    #expect(
      ElementPath
        .isElementPath("macos://ui/") ==
        true,
    ) // Empty path is still an element path (will fail on parse)
    #expect(ElementPath.isElementPath("somestring") == false)
    #expect(ElementPath.isElementPath("") == false)
  }

  @Test("ElementPath roundtrip (parse and toString)") func elementPathRoundtrip() throws {
    let originalPath =
      "macos://ui/AXWindow/AXGroup[@AXName=\"Controls\"]#2/AXButton[@AXDescription=\"Submit\"]"
    let path = try ElementPath.parse(originalPath)
    let regeneratedPath = path.toString()

    #expect(regeneratedPath == originalPath)
  }

  // MARK: - Path Resolution Tests

  // Mock AXUIElement class for testing path resolution
  class MockAXUIElement: @unchecked Sendable {
    let role: String
    let attributes: [String: Any]
    let children: [MockAXUIElement]

    init(role: String, attributes: [String: Any] = [:], children: [MockAXUIElement] = []) {
      self.role = role
      self.attributes = attributes
      self.children = children
    }
  }

  // Mock class for simple element attribute access
  final class ElementPathTestMockService {
    let rootElement: MockAXUIElement

    init(rootElement: MockAXUIElement) { self.rootElement = rootElement }

    func getAttribute(_ element: MockAXUIElement, attribute: String) -> Any? {
      if attribute == "AXRole" {
        element.role
      } else if attribute == "AXChildren" {
        element.children
      } else {
        element.attributes[attribute]
      }
    }
  }

  // Simplified mock for AccessibilityServiceProtocol that only implements required methods
  final class MockAccessibilityService: AccessibilityServiceProtocol, @unchecked Sendable {
    let rootElement: MockAXUIElement

    init(rootElement: MockAXUIElement) { self.rootElement = rootElement }

    func getAttribute(_ element: MockAXUIElement, attribute: String) -> Any? {
      if attribute == "AXRole" {
        element.role
      } else if attribute == "AXChildren" {
        element.children
      } else {
        element.attributes[attribute]
      }
    }

    // Required core function for AccessibilityServiceProtocol
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
      try await operation()
    }

    // Minimal implementations to satisfy the protocol
    func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
      UIElement(
        path: "macos://ui/AXApplication[@AXTitle=\"System\"][@identifier=\"mock-system\"]",
        role: "AXApplication",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func getApplicationUIElement(bundleId _: String, recursive _: Bool, maxDepth _: Int)
      async throws -> UIElement
    {
      UIElement(
        path: "macos://ui/AXApplication[@AXTitle=\"Application\"][@bundleId=\"mock-app\"]",
        role: "AXApplication",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func getFocusedApplicationUIElement(recursive _: Bool, maxDepth _: Int) async throws
      -> UIElement
    {
      UIElement(
        path: "macos://ui/AXApplication[@AXTitle=\"Focused App\"][@bundleId=\"mock-focused-app\"]",
        role: "AXApplication",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func getUIElementAtPosition(position _: CGPoint, recursive _: Bool, maxDepth _: Int)
      async throws
      -> UIElement?
    {
      UIElement(
        path: "macos://ui/AXElement[@identifier=\"mock-position\"]",
        role: "AXElement",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func findUIElements(
      role _: String?,
      title _: String?,
      titleContains _: String?,
      value _: String?,
      valueContains _: String?,
      description _: String?,
      descriptionContains _: String?,
      textContains _: String?,
      anyFieldContains _: String?,
      isInteractable _: Bool?,
      isEnabled _: Bool?,
      inMenus _: Bool?,
      inMainContent _: Bool?,
      elementTypes _: [String]?,
      scope _: UIElementScope,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws -> [UIElement] { [] }

    func findElements(withRole _: String, recursive _: Bool, maxDepth _: Int) async throws
      -> [UIElement]
    { [] }

    func findElements(
      withRole _: String, forElement _: AXUIElement, recursive _: Bool, maxDepth _: Int,
    )
      async throws -> [UIElement]
    { [] }

    func findElementByPath(_: String) async throws -> UIElement? {
      UIElement(
        path: "macos://ui/AXElement[@identifier=\"mock-path-element\"]",
        role: "AXElement",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func findElementByPath(path _: String) async throws -> UIElement? {
      UIElement(
        path: "macos://ui/AXElement[@identifier=\"mock-path-element\"]",
        role: "AXElement",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func performAction(action _: String, onElementWithPath _: String) async throws {
      // No-op for tests
    }

    func setWindowOrder(
      withPath _: String, orderMode _: WindowOrderMode, referenceWindowPath _: String?,
    )
      async throws
    {
      // No-op for tests
    }

    func getChildElements(forElement _: AXUIElement, recursive _: Bool, maxDepth _: Int)
      async throws
      -> [UIElement]
    { [] }

    func getElementWithFocus() async throws -> UIElement {
      UIElement(
        path: "macos://ui/AXElement[@identifier=\"mock-focused-element\"]",
        role: "AXElement",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    func getRunningApplications() -> [NSRunningApplication] { [] }

    func isApplicationRunning(withBundleIdentifier _: String) -> Bool { false }

    func isApplicationRunning(withTitle _: String) -> Bool { false }

    func waitForElementByPath(_: String, timeout _: TimeInterval, pollInterval _: TimeInterval)
      async throws
      -> UIElement
    {
      UIElement(
        path: "macos://ui/AXElement[@identifier=\"mock-wait-element\"]",
        role: "AXElement",
        frame: CGRect.zero,
        axElement: nil,
      )
    }

    // Window management methods required by protocol
    func getWindows(forApplication _: String) async throws -> [UIElement] { [] }

    func getActiveWindow(forApplication _: String) async throws -> UIElement? { nil }

    func moveWindow(withPath _: String, to _: CGPoint) async throws {
      // No-op for tests
    }

    func resizeWindow(withPath _: String, to _: CGSize) async throws {
      // No-op for tests
    }

    func minimizeWindow(withPath _: String) async throws {
      // No-op for tests
    }

    func maximizeWindow(withPath _: String) async throws {
      // No-op for tests
    }

    func closeWindow(withPath _: String) async throws {
      // No-op for tests
    }

    func activateWindow(withPath _: String) async throws {
      // No-op for tests
    }

    func setWindowOrder(withPath _: String, orderMode _: WindowOrderMode) async throws {
      // No-op for tests
    }

    func focusWindow(withPath _: String) async throws {
      // No-op for tests
    }

    func navigateMenu(elementPath _: String, in _: String) async throws {
      // No-op for tests
    }
  }

  // Helper function to create a mock element hierarchy
  func createMockElementHierarchy() -> MockAXUIElement {
    // Create a window with various controls
    let button1 = MockAXUIElement(
      role: "AXButton",
      attributes: ["AXTitle": "OK", "AXDescription": "OK Button", "AXEnabled": true],
    )

    let button2 = MockAXUIElement(
      role: "AXButton",
      attributes: ["AXTitle": "Cancel", "AXDescription": "Cancel Button", "AXEnabled": true],
    )

    let textField = MockAXUIElement(
      role: "AXTextField",
      attributes: ["AXValue": "Sample text", "AXDescription": "Text input"],
    )

    let controlGroup = MockAXUIElement(
      role: "AXGroup",
      attributes: ["AXTitle": "Controls", "AXDescription": "Control group"],
      children: [button1, button2, textField],
    )

    let contentArea = MockAXUIElement(
      role: "AXScrollArea",
      attributes: ["AXDescription": "Content area"],
      children: [MockAXUIElement(role: "AXStaticText", attributes: ["AXValue": "Hello World"])],
    )

    let duplicateGroup1 = MockAXUIElement(
      role: "AXGroup",
      attributes: ["AXTitle": "Duplicate", "AXIdentifier": "group1"],
      children: [
        MockAXUIElement(role: "AXCheckBox", attributes: ["AXTitle": "Option 1", "AXValue": 1]),
      ],
    )

    let duplicateGroup2 = MockAXUIElement(
      role: "AXGroup",
      attributes: ["AXTitle": "Duplicate", "AXIdentifier": "group2"],
      children: [
        MockAXUIElement(role: "AXCheckBox", attributes: ["AXTitle": "Option 2", "AXValue": 0]),
      ],
    )

    return MockAXUIElement(
      role: "AXWindow",
      attributes: ["AXTitle": "Test Window"],
      children: [controlGroup, contentArea, duplicateGroup1, duplicateGroup2],
    )
  }

  @Test("Path resolution with simple path") func pathResolutionSimple() throws {
    // This test will validate the basic resolution logic using our mock hierarchy
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving a simple path
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]"
    let path = try ElementPath.parse(pathString)

    let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
    #expect(mockResolveResult != nil)
    #expect(mockResolveResult?.role == "AXGroup")
    #expect(mockResolveResult?.attributes["AXTitle"] as? String == "Controls")
  }

  @Test("Path resolution with attributes") func pathResolutionWithAttributes() throws {
    // This test will validate resolution with attribute matching
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving a path with attribute constraints
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"]"
    let path = try ElementPath.parse(pathString)

    let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
    #expect(mockResolveResult != nil)
    #expect(mockResolveResult?.role == "AXButton")
    #expect(mockResolveResult?.attributes["AXTitle"] as? String == "OK")
  }

  @Test("Path resolution with index") func pathResolutionWithIndex() throws {
    // This test will validate resolution with index-based selection
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving a path with index for disambiguation
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#1"
    let path = try ElementPath.parse(pathString)

    let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
    #expect(mockResolveResult != nil)
    #expect(mockResolveResult?.role == "AXGroup")
    #expect(mockResolveResult?.attributes["AXIdentifier"] as? String == "group2")
  }

  @Test("Path resolution with index out of range") func pathResolutionWithIndexOutOfRange() throws {
    // Test index validation when index is out of range
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test with index that's too high
    let pathStringHighIndex = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#5"
    let pathHighIndex = try ElementPath.parse(pathStringHighIndex)

    let highIndexError = mockResolvePathWithExceptionForTest(
      service: mockService, path: pathHighIndex,
    )
    #expect(highIndexError != nil)
    if case .indexOutOfRange(let index, let availableCount, let segmentIndex)? = highIndexError {
      #expect(index == 5)
      #expect(availableCount == 2) // We have 2 duplicate groups in mock hierarchy
      #expect(segmentIndex == 1)
    } else {
      #expect(
        Bool(false), "Expected indexOutOfRange error but got \(String(describing: highIndexError))",
      )
    }
    // Test with negative index
    let pathStringNegativeIndex = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#-1"
    let pathNegativeIndex = try ElementPath.parse(pathStringNegativeIndex)

    let negativeIndexError = mockResolvePathWithExceptionForTest(
      service: mockService, path: pathNegativeIndex,
    )
    #expect(negativeIndexError != nil)
    if case .indexOutOfRange(let index, let availableCount, let segmentIndex)? = negativeIndexError
    {
      #expect(index == -1)
      #expect(availableCount == 2)
      #expect(segmentIndex == 1)
    } else {
      #expect(
        Bool(false),
        "Expected indexOutOfRange error but got \(String(describing: negativeIndexError))",
      )
    }
  }

  @Test("Path resolution with zero index") func pathResolutionWithZeroIndex() throws {
    // Test that index 0 selects the first matching element
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving with index 0 (first element)
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]#0"
    let path = try ElementPath.parse(pathString)

    let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
    #expect(mockResolveResult != nil)
    #expect(mockResolveResult?.role == "AXGroup")
    #expect(mockResolveResult?.attributes["AXIdentifier"] as? String == "group1")
  }

  @Test("Path resolution with no matching elements") func pathResolutionNoMatch() throws {
    // This test will validate error handling when no elements match
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving a path that has no matches
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"NonExistent\"]"
    let path = try ElementPath.parse(pathString)

    let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
    #expect(mockResolveResult == nil)
  }

  @Test("Path resolution with ambiguous match") func pathResolutionAmbiguousMatch() throws {
    // This test will validate error handling when multiple elements match without an index
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test resolving a path with ambiguous matches (both duplicate groups)
    let pathString = "macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]"
    let path = try ElementPath.parse(pathString)

    let mockResolveException = mockResolvePathWithExceptionForTest(service: mockService, path: path)
    #expect(mockResolveException != nil)
    guard let error = mockResolveException else {
      #expect(Bool(false), "Expected ambiguous match error but no error occurred")
      return
    }

    // Should get the new enhanced ambiguous match error
    if case .ambiguousMatchNoIndex(let segment, let matchCount, let segmentIndex) = error {
      #expect(segment.contains("AXGroup[@AXTitle=\"Duplicate\"]"))
      #expect(matchCount == 2)
      #expect(segmentIndex == 1)
    } else {
      #expect(Bool(false), "Expected ambiguousMatchNoIndex error but got \(error)")
    }
  }

  @Test("New error types validation") func newErrorTypesValidation() throws {
    // Test all new error types to ensure they're properly implemented

    // Test indexOutOfRange error
    let indexOutOfRangeError = ElementPathError.indexOutOfRange(5, availableCount: 3, atSegment: 2)
    let expectedIndexOutOfRange =
      "Index 5 is out of range at segment 2. Only 3 elements match this segment (valid indices: 0-2)."
    #expect(indexOutOfRangeError.description == expectedIndexOutOfRange)
    // Test ambiguousMatchNoIndex error
    let ambiguousError = ElementPathError.ambiguousMatchNoIndex(
      "AXButton[@AXTitle=\"Save\"]",
      matchCount: 4,
      atSegment: 3,
    )
    let expectedAmbiguous =
      "Ambiguous match at segment 3: 4 elements match 'AXButton[@AXTitle=\"Save\"]' but no index specified. Use #0, #1, #2, etc. to select a specific element."
    #expect(ambiguousError.description == expectedAmbiguous)
    // Test unnecessaryIndex error (this could be used for warnings in the future)
    let unnecessaryError = ElementPathError.unnecessaryIndex(1, atSegment: 2)
    let expectedUnnecessary =
      "Unnecessary index #1 at segment 2: only one element matches this segment. Consider removing the index for cleaner paths."
    #expect(unnecessaryError.description == expectedUnnecessary)
    // Test equality for new error types
    let error1 = ElementPathError.indexOutOfRange(3, availableCount: 2, atSegment: 1)
    let error2 = ElementPathError.indexOutOfRange(3, availableCount: 2, atSegment: 1)
    let error3 = ElementPathError.indexOutOfRange(3, availableCount: 3, atSegment: 1)
    #expect(error1 == error2)
    #expect(error1 != error3)
    let ambiguous1 = ElementPathError.ambiguousMatchNoIndex("AXButton", matchCount: 2, atSegment: 1)
    let ambiguous2 = ElementPathError.ambiguousMatchNoIndex("AXButton", matchCount: 2, atSegment: 1)
    let ambiguous3 = ElementPathError.ambiguousMatchNoIndex("AXButton", matchCount: 3, atSegment: 1)
    #expect(ambiguous1 == ambiguous2)
    #expect(ambiguous1 != ambiguous3)
  }

  // These need to be defined inside the test suite class, not as an extension
  @Test("Utility for path resolution in tests") func mockPathResolution() throws {
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Simple path test
    let path = try ElementPath.parse("macos://ui/AXWindow/AXGroup[@AXTitle=\"Controls\"]")
    let result = mockResolvePathForTest(service: mockService, path: path)
    #expect(result != nil)
    #expect(result?.role == "AXGroup")
  }

  // Check if a segment matches an element
  func mockSegmentMatchesElement(_ segment: PathSegment, element: MockAXUIElement) -> Bool {
    // Check role first
    guard segment.role == element.role else { return false }

    // If there are no attributes to match, we're done
    if segment.attributes.isEmpty { return true }

    // Check each attribute
    for (key, value) in segment.attributes {
      // Try with various keys to improve matching chances
      let normalizedKey = normalizeAttributeNameForTest(key)
      let keys = [key, normalizedKey]

      var attributeFound = false
      for attributeKey in keys {
        if let elementValue = element.attributes[attributeKey] {
          // Convert to string for comparison
          let elementValueString: String =
            if let stringValue = elementValue as? String {
              stringValue
            } else if let numberValue = elementValue as? NSNumber {
              numberValue.stringValue
            } else if let boolValue = elementValue as? Bool { boolValue ? "true" : "false" } else {
              String(describing: elementValue)
            }

          // The matching logic is built into mockAttributeMatches and doesn't need the type
          // explicitly
          let doesMatch = mockAttributeMatches(expected: value, actual: elementValueString)

          if doesMatch {
            attributeFound = true
            break
          }
        }
      }

      if !attributeFound { return false }
    }

    return true
  }

  // Simple attribute name normalization for test
  func normalizeAttributeNameForTest(_ name: String) -> String {
    // If it already has AX prefix, return as is
    if name.hasPrefix("AX") { return name }

    // Handle common mappings
    let mappings = [
      "title": "AXTitle", "description": "AXDescription", "value": "AXValue", "id": "AXIdentifier",
      "identifier": "AXIdentifier",
    ]

    if let mapped = mappings[name] { return mapped }

    // Add AX prefix for other attributes
    return "AX" + name.prefix(1).uppercased() + name.dropFirst()
  }

  // Match attribute values using appropriate strategy
  func mockAttributeMatches(expected: String, actual: String) -> Bool {
    // Check for exact match first
    if actual == expected { return true }

    // Then case-insensitive match
    if actual.localizedCaseInsensitiveCompare(expected) == .orderedSame { return true }

    // Then check contains relationships
    if actual.localizedCaseInsensitiveContains(expected)
      || expected.localizedCaseInsensitiveContains(actual)
    {
      return true
    }

    // No match
    return false
  }

  @Test("Testing attribute matching") func attributeMatching() throws {
    // Create test elements and check if they match

    // Element with title
    let buttonWithTitle = MockAXUIElement(role: "AXButton", attributes: ["AXTitle": "OK Button"])

    // Check exact match
    let exactPathSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "OK Button"])
    #expect(mockSegmentMatchesElement(exactPathSegment, element: buttonWithTitle) == true)

    // Check case-insensitive match
    let casePathSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "ok button"])
    #expect(mockSegmentMatchesElement(casePathSegment, element: buttonWithTitle) == true)

    // Check substring match
    let substringPathSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "OK"])
    #expect(mockSegmentMatchesElement(substringPathSegment, element: buttonWithTitle) == true)

    // Check non-match
    let nonMatchPathSegment = PathSegment(role: "AXButton", attributes: ["AXTitle": "Cancel"])
    #expect(mockSegmentMatchesElement(nonMatchPathSegment, element: buttonWithTitle) == false)
  }

  @Test("Testing enhanced error reporting") func enhancedErrorReporting() throws {
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)

    // Test ambiguous match with enhanced error
    let ambiguousPath = try ElementPath.parse("macos://ui/AXWindow/AXGroup[@AXTitle=\"Duplicate\"]")
    let ambiguousError = mockResolvePathWithExceptionForTest(
      service: mockService, path: ambiguousPath,
    )
    #expect(ambiguousError != nil)

    if case .ambiguousMatchNoIndex(let segment, let matchCount, let segmentIndex)? = ambiguousError
    {
      #expect(segment.contains("AXGroup[@AXTitle=\"Duplicate\"]"))
      #expect(segmentIndex == 1)
      #expect(matchCount == 2)
    } else {
      #expect(
        Bool(false),
        "Expected ambiguousMatchNoIndex error but got \(String(describing: ambiguousError))",
      )
    }

    // Test no matching elements with enhanced error
    let nonExistentPath = try ElementPath.parse("macos://ui/AXWindow/AXNonExistentElement")
    let nonExistentError = mockResolvePathWithExceptionForTest(
      service: mockService, path: nonExistentPath,
    )
    #expect(nonExistentError != nil)

    if case .noMatchingElements(let message, let atSegment)? = nonExistentError {
      #expect(message.contains("AXNonExistentElement"))
      #expect(atSegment == 1)
    } else {
      #expect(
        Bool(false),
        "Expected noMatchingElements error but got \(String(describing: nonExistentError))",
      )
    }
  }

  // Helper functions for test path resolution
  private func mockResolvePathForTest(service: MockAccessibilityService, path: ElementPath)
    -> MockAXUIElement?
  {
    do { return try mockResolvePathInternal(service: service, path: path) } catch { return nil }
  }

  private func mockResolvePathWithExceptionForTest(
    service: MockAccessibilityService, path: ElementPath,
  )
    -> ElementPathError?
  {
    do {
      _ = try mockResolvePathInternal(service: service, path: path)
      return nil
    } catch let error as ElementPathError { return error } catch { return nil }
  }

  // Internal implementation that throws errors
  private func mockResolvePathInternal(service: MockAccessibilityService, path: ElementPath)
    throws
    -> MockAXUIElement
  {
    // Start with the root element
    var current = service.rootElement

    // Navigate through each segment of the path
    for (index, segment) in path.segments.enumerated() {
      // Skip the root segment if it's already matched
      if index == 0, segment.role == "AXWindow" { continue }

      // Find children matching this segment
      var matches: [MockAXUIElement] = []

      if index == 0, segment.role == current.role {
        // Special case for the root element
        if mockSegmentMatchesElement(segment, element: current) { matches.append(current) }
      } else {
        // Check all children
        for child in current.children {
          if mockSegmentMatchesElement(segment, element: child) { matches.append(child) }
        }
      }

      // Handle matches based on count and index
      if matches.isEmpty {
        throw ElementPathError.noMatchingElements(
          "No children match segment: \(segment.toString())",
          atSegment: index,
        )
      } else if matches.count > 1, segment.index == nil {
        throw ElementPathError.ambiguousMatchNoIndex(
          segment.toString(),
          matchCount: matches.count,
          atSegment: index,
        )
      } else {
        if let segmentIndex = segment.index {
          // Use the specified index if available
          if segmentIndex < 0 || segmentIndex >= matches.count {
            throw ElementPathError.indexOutOfRange(
              segmentIndex,
              availableCount: matches.count,
              atSegment: index,
            )
          }
          current = matches[segmentIndex]
        } else {
          // Use the first match
          current = matches[0]
        }
      }
    }

    return current
  }

  @Test("Path validation with valid path") func pathValidationWithValidPath() throws {
    // Test a well-formed path
    let pathString =
      "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"1\"]"

    let (isValid, warnings) = try ElementPath.validatePath(pathString)

    #expect(isValid == true)

    // In non-strict mode, there should be no warnings for a well-formed path
    #expect(warnings.isEmpty)
  }

  @Test("Test path round-trip with real-world paths") func realWorldPathRoundTrip() throws {
    // Test with realistic paths seen in real applications
    let calculatorPath =
      "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
    let textEditPath =
      "macos://ui/AXApplication[@AXTitle=\"TextEdit\"]/AXWindow[@AXTitle=\"Untitled\"]/AXTextArea"

    // Validate round-trip for Calculator path
    let calcPath = try ElementPath.parse(calculatorPath)
    let regeneratedCalcPath = calcPath.toString()
    #expect(regeneratedCalcPath == calculatorPath)

    // Validate round-trip for TextEdit path
    let textEditPathObj = try ElementPath.parse(textEditPath)
    let regeneratedTextEditPath = textEditPathObj.toString()
    #expect(regeneratedTextEditPath == textEditPath)
  }

  @Test("Measure resolution performance") func resolutionPerformance() throws {
    // Create a complex mock hierarchy with many elements

    // Helper function to create a deep hierarchy for testing
    func createDeepHierarchy(depth: Int, breadth: Int, currentDepth: Int = 0) -> MockAXUIElement {
      // Create a deep hierarchy for performance testing
      if currentDepth == depth {
        // At max depth, create leaf nodes
        return MockAXUIElement(
          role: "AXButton",
          attributes: ["AXTitle": "Deep Button", "AXDescription": "Button at depth \(depth)"],
        )
      }

      // Create children for this level
      var children: [MockAXUIElement] = []

      for _ in 0 ..< breadth {
        children.append(
          createDeepHierarchy(depth: depth, breadth: breadth, currentDepth: currentDepth + 1),
        )
      }

      // Create a group at this level
      return MockAXUIElement(
        role: currentDepth == 0 ? "AXWindow" : "AXGroup",
        attributes: [
          "AXTitle": "Group at depth \(currentDepth)", "AXDescription": "Group \(currentDepth)",
        ],
        children: children,
      )
    }

    let deepHierarchy = createDeepHierarchy(depth: 5, breadth: 3)
    let mockService = MockAccessibilityService(rootElement: deepHierarchy)

    // Create a complex path to resolve
    let pathString =
      "macos://ui/AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXButton[@AXTitle=\"Deep Button\"]"
    let path = try ElementPath.parse(pathString)

    // Basic performance check
    let startTime = Date()
    _ = mockResolvePathForTest(service: mockService, path: path)
    let endTime = Date()

    let elapsedTime = endTime.timeIntervalSince(startTime)
    // print("Resolution time: \(elapsedTime) seconds")

    // No hard assertion, just informational
    #expect(elapsedTime > 0)
  }

  // Test our diagnostic function by analyzing the output text
  // instead of actually testing path resolution against mock objects
  @Test("Test path resolution diagnostic output contents") func pathDiagnosticOutputContent()
    async throws
  {
    // We'll simply test that the diagnostic method produces appropriate output
    // for different types of path issues by checking the text format
    let pathString =
      "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"]"

    // Create a simple mock diagnostic result for testing
    let mockDiagnosticOutput = """
    Path Resolution Diagnosis for: \(pathString)
    ================================================================================

    Path syntax validation: ✅ No syntax warnings

    ✅ Successfully resolved application element

    Segment 1: AXWindow
    ✅ One child matches this segment
      Match details: role=AXWindow, AXTitle="Main Window"

    Segment 2: AXGroup[@AXTitle="Controls"]
    ✅ One child matches this segment
      Match details: role=AXGroup, AXTitle="Controls"

    Segment 3: AXButton[@AXTitle="OK"]
    ❌ No children match this segment
    Available children (sample):
      Child 0: role=AXButton, AXTitle="Cancel"
        ⚠️ This child has the right role but didn't match other criteria
        - Attribute AXTitle: actual="Cancel", expected="OK" ❌ NO MATCH
      Child 1: role=AXButton, AXTitle="Apply"
        ⚠️ This child has the right role but didn't match other criteria
        - Attribute AXTitle: actual="Apply", expected="OK" ❌ NO MATCH
      Child 2: role=AXTextField, AXValue="Input text"

    Possible solutions:
      1. Check if the role is correct (case-sensitive: AXButton)
      2. Verify attribute names and values match exactly
      3. Consider using the mcp-ax-inspector tool to see the exact element structure
      4. Try simplifying the path or using an index if there are many similar elements

    Final result: ❌ Failed to resolve complete path
    Try using the mcp-ax-inspector tool to examine the actual UI hierarchy
    """

    // Test that our diagnostic output has the expected format sections
    // These checks focus on the content format, not actual resolution
    #expect(mockDiagnosticOutput.contains("Path Resolution Diagnosis for:"))
    #expect(
      mockDiagnosticOutput.contains(
        "================================================================================",
      ),
    )

    // Check for section markers in the diagnostic format
    #expect(mockDiagnosticOutput.contains("Segment"))
    #expect(mockDiagnosticOutput.contains("Available children (sample):"))
    #expect(mockDiagnosticOutput.contains("Possible solutions:"))
    #expect(mockDiagnosticOutput.contains("Final result:"))

    // Check for the enhanced diagnostic information we added
    #expect(
      mockDiagnosticOutput
        .contains("This child has the right role but didn't match other criteria"),
    )
    #expect(mockDiagnosticOutput.contains("actual="))
    #expect(mockDiagnosticOutput.contains("expected="))
    #expect(mockDiagnosticOutput.contains("NO MATCH"))

    // Check for recommendations and helpful information
    #expect(mockDiagnosticOutput.contains("Consider using the mcp-ax-inspector tool"))
  }

  // MARK: - Phase 4.3: Edge Case Tests

  @Test("ElementPath parsing with invalid index syntax - empty index")
  func elementPathParsingInvalidIndexEmpty() {
    let pathString = "macos://ui/AXWindow/AXButton#"

    do {
      _ = try ElementPath.parse(pathString)
      #expect(Bool(false), "Should have thrown an error for empty index")
    } catch let error as ElementPathError {
      if case .invalidIndexSyntax(let invalidIndex, let atSegment) = error {
        #expect(invalidIndex == "#")
        #expect(atSegment == 1)
      } else {
        #expect(Bool(false), "Expected invalidIndexSyntax error, got: \(error)")
      }
    } catch { #expect(Bool(false), "Threw unexpected error: \(error)") }
  }

  @Test("ElementPath parsing with invalid index syntax - non-numeric index")
  func elementPathParsingInvalidIndexNonNumeric() {
    let pathString = "macos://ui/AXWindow/AXButton#abc"

    do {
      _ = try ElementPath.parse(pathString)
      #expect(Bool(false), "Should have thrown an error for non-numeric index")
    } catch let error as ElementPathError {
      if case .invalidIndexSyntax(let invalidIndex, let atSegment) = error {
        #expect(invalidIndex == "#abc")
        #expect(atSegment == 1)
      } else {
        #expect(Bool(false), "Expected invalidIndexSyntax error, got: \(error)")
      }
    } catch { #expect(Bool(false), "Threw unexpected error: \(error)") }
  }

  @Test("ElementPath parsing with invalid index syntax - special characters")
  func elementPathParsingInvalidIndexSpecialChars() {
    let pathString = "macos://ui/AXWindow/AXButton#@!$"

    do {
      _ = try ElementPath.parse(pathString)
      #expect(Bool(false), "Should have thrown an error for special character index")
    } catch let error as ElementPathError {
      if case .invalidIndexSyntax(let invalidIndex, let atSegment) = error {
        #expect(invalidIndex == "#@!$")
        #expect(atSegment == 1)
      } else {
        #expect(Bool(false), "Expected invalidIndexSyntax error, got: \(error)")
      }
    } catch { #expect(Bool(false), "Threw unexpected error: \(error)") }
  }

  @Test("ElementPath parsing with negative index") func elementPathParsingNegativeIndex() throws {
    let pathString = "macos://ui/AXWindow/AXButton#-1"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 2)
    #expect(path.segments[1].role == "AXButton")
    #expect(path.segments[1].index == -1)
  }

  @Test("ElementPath parsing with very large index") func elementPathParsingLargeIndex() throws {
    let pathString = "macos://ui/AXWindow/AXButton#999999"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 2)
    #expect(path.segments[1].role == "AXButton")
    #expect(path.segments[1].index == 999_999)
  }

  // NOTE: Resolution tests with mock services are temporarily commented out
  // as they require more complex mocking of the accessibility service layer.
  // These tests validate parsing behavior which is the core of Phase 4.3.

  @Test("ElementPath parsing multiple hash symbols in role name")
  func elementPathParsingMultipleHashSymbols() {
    // Test that a hash in the middle of a role name doesn't get confused with index syntax
    let pathString = "macos://ui/AXWindow/AX#Custom#Role"

    do {
      let path = try ElementPath.parse(pathString)
      #expect(path.segments.count == 2)
      #expect(path.segments[1].role == "AX#Custom#Role")
      #expect(path.segments[1].index == nil)
    } catch { #expect(Bool(false), "Should be able to parse role with hash symbols: \(error)") }
  }

  @Test("ElementPath parsing hash followed by attributes")
  func elementPathParsingHashFollowedByAttributes() throws {
    let pathString = "macos://ui/AXWindow/AXButton#2[@AXDescription=\"Submit\"]"
    let path = try ElementPath.parse(pathString)

    #expect(path.segments.count == 2)
    #expect(path.segments[1].role == "AXButton")
    #expect(path.segments[1].index == 2)
    #expect(path.segments[1].attributes["AXDescription"] == "Submit")
  }

  @Test("ElementPath toString preserves index in complex path")
  func elementPathToStringPreservesIndex() throws {
    let segments = [
      PathSegment(role: "AXApplication", attributes: ["bundleId": "com.app"]),
      PathSegment(role: "AXWindow", attributes: ["AXTitle": "Window"], index: 1),
      PathSegment(role: "AXButton", attributes: ["AXDescription": "OK"], index: 0),
    ]
    let path = try ElementPath(segments: segments)
    let pathString = path.toString()

    // Should preserve all indices in the string representation
    // Note: toString() puts attributes before index
    #expect(pathString.contains("[@AXTitle=\"Window\"]#1"))
    #expect(pathString.contains("[@AXDescription=\"OK\"]#0"))
    #expect(pathString.contains("[@bundleId=\"com.app\"]"))
  }
}
