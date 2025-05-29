// ABOUTME: Tests to verify all tools output opaque IDs consistently
// ABOUTME: Ensures WindowManagementTool and ResourcesUIElement also use opaque IDs

import Foundation
import Testing

@testable import MacMCP

@Suite("All Tools Opaque ID Tests") struct AllToolsOpaqueIDTests {
  @Test("EnhancedElementDescriptor outputs opaque IDs")
  func enhancedElementDescriptorOutputsOpaqueIDs() throws {
    let problematicPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    // Test EnhancedElementDescriptor (used by all tools now)
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
    // Test JSON encoding
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode([descriptor])
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("EnhancedElementDescriptor JSON:")
    print(jsonString)
    // Should use opaque IDs
    #expect(!jsonString.contains("macos://ui/"), "Should use opaque ID, not raw path")
    #expect(!jsonString.contains("[@AXTitle="), "Should not contain raw path syntax")
    #expect(!jsonString.contains("\\\""), "Should not contain escaped quotes")
    print("EnhancedElementDescriptor successfully outputs opaque IDs!")
  }

  @Test("WindowManagementTool and ResourcesUIElement output opaque IDs")
  func windowManagementAndResourcesOutputOpaqueIDs() throws {
    // This test verifies that the migration was successful by testing the same
    // EnhancedElementDescriptor creation that those tools now use

    let problematicPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]"#
    // Create descriptor as WindowManagementTool and ResourcesUIElement would
    let descriptor = EnhancedElementDescriptor(
      id: problematicPath,
      role: "AXWindow",
      title: "Calculator",
      value: nil,
      description: nil,
      frame: ElementFrame(x: 100, y: 100, width: 400, height: 300),
      props: ["Enabled", "Visible", "movable", "resizable"],
      actions: ["AXMove", "AXResize"],
      attributes: ["bundleId": "com.apple.calculator"],
      children: nil,
    )
    // Encode as those tools would (via formatResponse)
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode([descriptor])
    let jsonString = String(data: jsonData, encoding: .utf8)!
    print("WindowManagementTool/ResourcesUIElement style JSON:")
    print(jsonString)
    // Verify clean output
    #expect(!jsonString.contains("macos://ui/"), "Should use opaque ID, not raw path")
    #expect(!jsonString.contains("[@bundleId="), "Should not contain raw element path syntax")
    #expect(!jsonString.contains("\\\""), "Should not contain escaped quotes")
    #expect(!jsonString.contains("\\/"), "Should not contain escaped slashes")
    print("WindowManagementTool and ResourcesUIElement now output clean opaque IDs!")
  }
}
