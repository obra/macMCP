// ABOUTME: Tests for UIElement equality behavior to debug the impossible condition
// ABOUTME: Investigates why element1 == element2 and element1 != element2 can both be true

import Foundation
import Testing

@testable import MacMCP

@Suite(.serialized) struct UIElementEqualityTests {
  @Test("UIElement equality basics - same path should be equal") func basicEquality() throws {
    let element1 = createTestUIElement(path: "macos://ui/AXButton[@AXDescription=\"Test\"]")
    let element2 = createTestUIElement(path: "macos://ui/AXButton[@AXDescription=\"Test\"]")
    print("Element 1 path: \(element1.path)")
    print("Element 2 path: \(element2.path)")
    print("Paths equal: \(element1.path == element2.path)")
    print("Elements equal (==): \(element1 == element2)")
    print("Elements not equal (!=): \(element1 != element2)")
    print("Reference equal (===): \(element1 === element2)")
    // Basic sanity check
    #expect(element1.path == element2.path, "Paths should be equal")
    #expect(element1 == element2, "Elements with same path should be equal")
    #expect(!(element1 != element2), "Negation should be consistent")
  }

  @Test("Investigate impossible condition scenario") func impossibleCondition() throws {
    let element1 = createTestUIElement(path: "macos://ui/AXButton[@AXDescription=\"Test\"]")
    let element2 = createTestUIElement(path: "macos://ui/AXButton[@AXDescription=\"Test\"]")
    // Replicate the exact test from UIChangeDetectionService
    let equal = element1 == element2
    let notEqual = element1 != element2
    print("element1 == element2: \(equal)")
    print("element1 != element2: \(notEqual)")
    print("!(element1 == element2): \(!equal)")
    print("element1 === element2: \(element1 === element2)")
    print("Direct comparison: \(element1 == element2)")
    print("Direct negation: \(element1 != element2)")
    // This should be impossible - if it fails, we've reproduced the bug
    if equal, notEqual {
      print("🚨 IMPOSSIBLE CONDITION REPRODUCED!")
      print("This indicates a fundamental Swift equality issue")
    }
    #expect(!(equal && notEqual), "Cannot have both equal and not equal be true")
  }

  @Test("Test different objects with same path") func differentObjectsSamePath() throws {
    let path = "macos://ui/AXButton[@AXDescription=\"Test\"]"
    // Create multiple UIElement objects with identical paths but different content
    let element1 = UIElement(
      path: path,
      role: "AXButton",
      title: "Test1",
      value: nil,
      elementDescription: "Test",
      identifier: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 20),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
      axElement: nil,
    )
    let element2 = UIElement(
      path: path,
      role: "AXButton",
      title: "Test2", // Different title
      value: nil,
      elementDescription: "Test",
      identifier: nil,
      frame: CGRect(x: 10, y: 10, width: 100, height: 20), // Different frame
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
      axElement: nil,
    )
    print("Element1 title: \(element1.title ?? "nil")")
    print("Element2 title: \(element2.title ?? "nil")")
    print("Element1 frame: \(element1.frame)")
    print("Element2 frame: \(element2.frame)")
    print("Same path: \(element1.path == element2.path)")
    print("Equal: \(element1 == element2)")
    print("Not equal: \(element1 != element2)")
    // These should be equal because equality is path-based
    #expect(
      element1 == element2,
      "Elements with same path should be equal regardless of other properties",
    )
    #expect(!(element1 != element2), "Negation should be consistent")
  }
}

// MARK: - Helper Functions

private func createTestUIElement(path: String) -> UIElement {
  UIElement(
    path: path,
    role: "AXButton",
    title: "Test",
    value: nil,
    elementDescription: "Test element",
    identifier: nil,
    frame: CGRect.zero,
    normalizedFrame: nil,
    viewportFrame: nil,
    frameSource: .unavailable,
    parent: nil,
    children: [],
    attributes: [:],
    actions: [],
    axElement: nil,
  )
}
