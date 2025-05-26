// ABOUTME: Tests for end-to-end opaque ID workflow
// ABOUTME: Verifies that EnhancedElementDescriptor outputs opaque IDs and UIInteractionTool can decode them

import Testing
import Foundation
@testable import MacMCP

@Suite("Opaque ID Workflow Tests")
struct OpaqueIDWorkflowTests {
  
  @Test("End-to-end opaque ID workflow")
  func endToEndOpaqueIDWorkflow() throws {
    // 1. Create an EnhancedElementDescriptor with a complex path (the problematic one from the user)
    let originalPath = #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    
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
      children: nil
    )
    
    // 2. Encode to JSON (should use opaque ID in output)
    let encoder = JSONConfiguration.encoder
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    
    print("Generated JSON with opaque ID:")
    print(jsonString)
    
    // 3. Verify that the JSON contains an opaque ID (not the raw path)
    #expect(!jsonString.contains("macos://ui/"), "JSON should contain opaque ID, not raw path")
    #expect(!jsonString.contains("[@AXTitle="), "JSON should not contain raw element path syntax")
    
    // 4. Extract the opaque ID from the JSON
    let decoder = JSONConfiguration.decoder
    let decodedDescriptor = try decoder.decode(EnhancedElementDescriptor.self, from: jsonData)
    let opaqueID = decodedDescriptor.id
    
    print("Extracted opaque ID: \(opaqueID)")
    
    // 5. Test the decoding functionality directly (simulates what UIInteractionTool would do)
    let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
    #expect(decodedPath == originalPath, "Decoded path should match original")
    
    print("Successfully decoded opaque ID back to: \(decodedPath)")
    
    // 6. Verify the JSON is clean (no escaping issues)
    #expect(!jsonString.contains("\\\""), "JSON should not contain escaped quotes") 
    #expect(!jsonString.contains("\\/"), "JSON should not contain escaped slashes")
  }
  
  @Test("Opaque ID vs raw path JSON comparison")
  func opaqueIDVsRawPathComparison() throws {
    let problematicPath = #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    
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
      children: nil
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
    #expect(!jsonString.contains("\\\""), "Opaque ID JSON should have no escaped quotes")
    #expect(rawJsonString.contains("\\\""), "Raw path JSON should have escaped quotes")
    
    print("Opaque ID successfully eliminates JSON escaping issues!")
  }
}
