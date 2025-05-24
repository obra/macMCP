// ABOUTME: JSONConfiguration provides centralized JSONEncoder and JSONDecoder setup
// ABOUTME: Ensures consistent JSON formatting across all MCP tools and responses

import Foundation

/// Centralized JSON configuration for consistent encoding/decoding across the MCP server
public enum JSONConfiguration {
  
  /// Standard JSONEncoder with MCP-specific formatting
  public static var encoder: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return encoder
  }
  
  /// Standard JSONDecoder with MCP-specific configuration
  public static var decoder: JSONDecoder {
    let decoder = JSONDecoder()
    // Add any standard decoder configuration here
    return decoder
  }
}