// ABOUTME: JSONConfiguration provides centralized JSONEncoder and JSONDecoder setup
// ABOUTME: Ensures consistent JSON formatting across all MCP tools and responses

import Foundation
import MCP

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
  
  /// Convert Value dictionary to JSON-serializable dictionary
  /// - Parameter valueDict: Dictionary of String to Value to convert
  /// - Returns: Dictionary suitable for JSONSerialization
  public static func valueToJsonDict(_ valueDict: [String: Value]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in valueDict {
      result[key] = convertValue(value)
    }
    return result
  }
  
  /// Convert individual Value to JSON-serializable Any
  /// - Parameter value: The Value to convert
  /// - Returns: JSON-serializable representation
  public static func convertValue(_ value: Value) -> Any {
    switch value {
    case .null:
      return NSNull()
    case .bool(let b):
      return b
    case .int(let i):
      return i
    case .double(let d):
      return d
    case .string(let s):
      return s
    case .data(let mimeType, let data):
      return ["mimeType": mimeType as Any, "data": data.base64EncodedString()]
    case .array(let array):
      return array.map { convertValue($0) }
    case .object(let dict):
      var result: [String: Any] = [:]
      for (key, value) in dict {
        result[key] = convertValue(value)
      }
      return result
    }
  }
}