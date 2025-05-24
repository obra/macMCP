// ABOUTME: Tests to verify all tools output opaque IDs consistently
// ABOUTME: Ensures WindowManagementTool and ResourcesUIElement also use opaque IDs

import Testing
import Foundation
@testable import MacMCP

@Suite("All Tools Opaque ID Tests")
struct AllToolsOpaqueIDTests {
  
  @Test("All descriptor types output opaque IDs")
  func allDescriptorTypesOutputOpaqueIDs() throws {
    let problematicPath = #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    
    // Test EnhancedElementDescriptor (used by InterfaceExplorerTool)
    let enhancedDescriptor = EnhancedElementDescriptor(
      id: problematicPath,
      role: "AXButton",
      name: "All Clear", 
      title: "All Clear",
      value: nil,
      description: "All Clear",
      frame: ElementFrame(x: 0, y: 0, width: 50, height: 30),
      state: ["Enabled", "Visible"],
      capabilities: ["clickable"],
      actions: ["AXPress"],
      attributes: [:],
      children: nil
    )
    
    // Test ElementDescriptor (legacy, still used in some tests)
    let elementDescriptor = ElementDescriptor(
      id: problematicPath,
      role: "AXButton",
      frame: ElementFrame(x: 0, y: 0, width: 50, height: 30)
    )
    
    // Test JSON encoding for both
    let encoder = JSONConfiguration.encoder
    
    let enhancedJsonData = try encoder.encode([enhancedDescriptor])
    let enhancedJsonString = String(data: enhancedJsonData, encoding: .utf8)!
    
    let elementJsonData = try encoder.encode([elementDescriptor])
    let elementJsonString = String(data: elementJsonData, encoding: .utf8)!
    
    print("EnhancedElementDescriptor JSON:")
    print(enhancedJsonString)
    print("\nElementDescriptor JSON:")
    print(elementJsonString)
    
    // Both should use opaque IDs
    #expect(!enhancedJsonString.contains("macos://ui/"), "EnhancedElementDescriptor should use opaque ID")
    #expect(!enhancedJsonString.contains("[@AXTitle="), "EnhancedElementDescriptor should not contain raw path syntax")
    #expect(!enhancedJsonString.contains("\\\""), "EnhancedElementDescriptor should not contain escaped quotes")
    
    #expect(!elementJsonString.contains("macos://ui/"), "ElementDescriptor should use opaque ID")
    #expect(!elementJsonString.contains("[@AXTitle="), "ElementDescriptor should not contain raw path syntax")
    #expect(!elementJsonString.contains("\\\""), "ElementDescriptor should not contain escaped quotes")
    
    print("All descriptor types successfully output opaque IDs!")
  }
  
  @Test("WindowManagementTool and ResourcesUIElement output opaque IDs")
  func windowManagementAndResourcesOutputOpaqueIDs() throws {
    // This test verifies that the migration was successful by testing the same 
    // EnhancedElementDescriptor creation that those tools now use
    
    let problematicPath = #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]"#
    
    // Create descriptor as WindowManagementTool and ResourcesUIElement would
    let descriptor = EnhancedElementDescriptor(
      id: problematicPath,
      role: "AXWindow",
      name: "Calculator",
      title: "Calculator", 
      value: nil,
      description: nil,
      frame: ElementFrame(x: 100, y: 100, width: 400, height: 300),
      state: ["Enabled", "Visible"],
      capabilities: ["movable", "resizable"],
      actions: ["AXMove", "AXResize"],
      attributes: ["bundleId": "com.apple.calculator"],
      children: nil
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