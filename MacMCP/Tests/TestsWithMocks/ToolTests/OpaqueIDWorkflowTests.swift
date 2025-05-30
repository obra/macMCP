// ABOUTME: Tests for end-to-end opaque ID workflow
// ABOUTME: Verifies that EnhancedElementDescriptor outputs opaque IDs and UIInteractionTool can decode them

import Foundation
import Testing

@testable import MacMCP

@Suite("Opaque ID Workflow Tests") struct OpaqueIDWorkflowTests {
  @Test("End-to-end opaque ID workflow") func endToEndOpaqueIDWorkflow() throws {
    // 1. Create an EnhancedElementDescriptor with a complex path (the problematic one from the
    // user)
    let originalPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    let descriptor = EnhancedElementDescriptor(
      id: originalPath,
      role: "AXButton",
      title: "All Clear",
      value: nil,
      description: "All Clear",
      frame: ElementFrame(x: 0, y: 0, width: 50, height: 30),
      props: ["Enabled", "Visible", "clickable"],
      actions: ["AXPress"],
      attributes: [:],
      children: nil,
    )
    // 2. Encode to JSON (should use opaque ID in output)
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("Generated JSON with opaque ID:")
    print(jsonString)
    // 3. Verify that the JSON contains an opaque ID (not the raw path)
    try JSONTestUtilities.assertDoesNotContainAny(jsonString, substrings: [
      "macos://ui/",
      "[@AXTitle="
    ], message: "JSON should contain opaque ID, not raw path elements")
    
    // 4. Extract the opaque ID from the JSON using robust parsing
    try JSONTestUtilities.testJSONObject(jsonString) { json in
      try JSONTestUtilities.assertPropertyExists(json, property: "id")
      guard let opaqueID = json["id"] as? String else {
        #expect(Bool(false), "ID should be a string")
        return
      }
      
      print("Extracted opaque ID: \(opaqueID)")
      // 5. Test the decoding functionality directly (simulates what UIInteractionTool would do)
      let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
      #expect(decodedPath == originalPath, "Decoded path should match original")
      print("Successfully decoded opaque ID back to: \(decodedPath)")
    }
    
    // 6. Verify the JSON is clean (no escaping issues)
    try JSONTestUtilities.assertDoesNotContainAny(jsonString, substrings: [
      "\\\"",
      "\\/"
    ], message: "JSON should not contain escaped characters")
  }

  @Test("Opaque ID vs raw path JSON comparison") func opaqueIDVsRawPathComparison() throws {
    let problematicPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    // Create descriptor with opaque ID encoding
    let descriptor = EnhancedElementDescriptor(
      id: problematicPath,
      role: "AXButton",
      title: "All Clear",
      value: nil,
      description: "All Clear",
      frame: ElementFrame(x: 0, y: 0, width: 50, height: 30),
      props: ["Enabled", "Visible", "clickable"],
      actions: ["AXPress"],
      attributes: [:],
      children: nil,
    )
    let jsonData = try JSONConfiguration.encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("Opaque ID JSON (clean, no escaping):")
    print(jsonString)
    // Test what the old approach would have looked like
    struct RawPathDescriptor: Codable {
      let id: String
      let role: String
    }
    let rawDescriptor = RawPathDescriptor(id: problematicPath, role: "AXButton")
    let rawJsonData = try JSONConfiguration.encoder.encode(rawDescriptor)
    let rawJsonString = String(data: rawJsonData, encoding: .utf8)!
    print("Raw path JSON (with escaping issues):")
    print(rawJsonString)
    // Verify opaque approach eliminates escaping
    try JSONTestUtilities.assertDoesNotContain(jsonString, substring: "\\\"", message: "Opaque ID JSON should have no escaped quotes")
    #expect(rawJsonString.contains("\\\""), "Raw path JSON should have escaped quotes for comparison")
    print("Opaque ID successfully eliminates JSON escaping issues!")
  }
}
