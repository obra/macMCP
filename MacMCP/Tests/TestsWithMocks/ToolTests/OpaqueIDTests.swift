// ABOUTME: Tests for OpaqueIDEncoder functionality
// ABOUTME: Verifies compression and encoding of element paths to opaque IDs

import Foundation
import Testing

@testable import MacMCP

@Suite("Opaque ID Encoder Tests") struct OpaqueIDTests {
  @Test("Basic encoding and decoding") func basicEncodingDecoding() throws {
    let originalPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"]/AXButton[@AXDescription="1"]"#
    let opaqueID = try OpaqueIDEncoder.encode(originalPath)
    let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
    #expect(decodedPath == originalPath)
    // Note: For short strings, base64 encoding may be longer than original
    // Opaque IDs are valuable for escaping elimination, not necessarily compression
    print("Original: \(originalPath) (\(originalPath.count) chars)")
    print("Opaque ID: \(opaqueID) (\(opaqueID.count) chars)")
  }
  @Test("Complex path encoding") func complexPathEncoding() throws {
    let complexPath =
      #"macos://ui/AXApplication[@AXTitle="Calculator"][@bundleId="com.apple.calculator"]/AXWindow[@AXTitle="Calculator"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription="All Clear"]"#
    let opaqueID = try OpaqueIDEncoder.encode(complexPath)
    let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
    #expect(decodedPath == complexPath)
    print(
      "Complex path compression ratio: \(String(format: "%.1f", Double(complexPath.count) / Double(opaqueID.count)))x"
    )
  }
  @Test("Special characters handling") func specialCharactersHandling() throws {
    let pathWithSpecialChars =
      #"macos://ui/AXApplication[@AXTitle="My \"Special\" App"]/AXButton[@AXDescription="Click & Save"]"#
    let opaqueID = try OpaqueIDEncoder.encode(pathWithSpecialChars)
    let decodedPath = try OpaqueIDEncoder.decode(opaqueID)
    #expect(decodedPath == pathWithSpecialChars)
  }
  @Test("Invalid opaque ID handling") func invalidOpaqueIDHandling() throws {
    let invalidOpaqueID = "invalid-opaque-id"
    do {
      _ = try OpaqueIDEncoder.decode(invalidOpaqueID)
      #expect(Bool(false), "Should have thrown an error for invalid opaque ID")
    } catch {
      // Expected to throw an error
      #expect(error is OpaqueIDError)
    }
  }
}
