// ABOUTME: Tests for InterfaceExplorerTool opaque ID output
// ABOUTME: Verifies that InterfaceExplorerTool outputs opaque IDs instead of raw paths

import Foundation
import Testing

@testable import MacMCP

@Suite("Interface Explorer Opaque ID Tests") struct InterfaceExplorerOpaqueIDTests {
  @Test("InterfaceExplorerTool outputs opaque IDs") func interfaceExplorerOutputsOpaqueIDs() throws
  {
    // Create an EnhancedElementDescriptor with a complex path
    let problematicPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
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
    // Test direct JSON encoding (what InterfaceExplorerTool.formatResponse does)
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode([descriptor])
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("InterfaceExplorerTool JSON output:")
    print(jsonString)
    // Verify opaque ID is used - should not contain raw path elements
    try JSONTestUtilities.assertDoesNotContainAny(jsonString, substrings: [
      "macos://ui/",
      "[@AXTitle=", 
      "\\\"",
      "\\/"
    ], message: "Should use opaque ID format, not raw paths or escaped characters")
    
    // Extract the opaque ID from the JSON array using robust parsing
    try JSONTestUtilities.testJSONArray(jsonString) { jsonArray in
      #expect(!jsonArray.isEmpty, "Should have at least one element")
      let firstElement = jsonArray[0]
      try JSONTestUtilities.assertPropertyExists(firstElement, property: "id")
      
      // Get the opaque ID for round-trip testing
      guard let opaqueID = firstElement["id"] as? String else {
        #expect(Bool(false), "ID should be a string")
        return
      }
      
      // Test that we can decode the opaque ID back to the original path
      let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
      #expect(decodedPath == problematicPath, "Round-trip should work")
      print("Successfully decoded opaque ID back to original path!")
    }
  }
}
