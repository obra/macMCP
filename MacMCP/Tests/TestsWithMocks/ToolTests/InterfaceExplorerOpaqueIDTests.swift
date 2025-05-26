// ABOUTME: Tests for InterfaceExplorerTool opaque ID output
// ABOUTME: Verifies that InterfaceExplorerTool outputs opaque IDs instead of raw paths

import Testing
import Foundation
@testable import MacMCP

@Suite("Interface Explorer Opaque ID Tests")
struct InterfaceExplorerOpaqueIDTests {
  
  @Test("InterfaceExplorerTool outputs opaque IDs")
  func interfaceExplorerOutputsOpaqueIDs() throws {
    // Create an EnhancedElementDescriptor with a complex path
    let problematicPath = #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    
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
      children: nil
    )
    
    // Test direct JSON encoding (what InterfaceExplorerTool.formatResponse does)
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode([descriptor])
    let jsonString = String(data: jsonData, encoding: .utf8)!
    
    print("InterfaceExplorerTool JSON output:")
    print(jsonString)
    
    // Verify opaque ID is used
    #expect(!jsonString.contains("macos://ui/"), "Should use opaque ID, not raw path")
    #expect(!jsonString.contains("[@AXTitle="), "Should not contain raw element path syntax")
    #expect(!jsonString.contains("\\\""), "Should not contain escaped quotes")
    #expect(!jsonString.contains("\\/"), "Should not contain escaped slashes")
    
    // Verify the output can be decoded back
    let decodedDescriptors = try JSONDecoder().decode([EnhancedElementDescriptor].self, from: jsonData)
    let opaqueID = decodedDescriptors[0].id
    
    // Test that we can decode the opaque ID back to the original path
    let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
    #expect(decodedPath == problematicPath, "Round-trip should work")
    
    print("Successfully decoded opaque ID back to original path!")
  }
}
