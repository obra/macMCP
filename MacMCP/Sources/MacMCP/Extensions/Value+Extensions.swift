// ABOUTME: Value+Extensions.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

extension Value {
  /// Convert Value to a Swift-friendly dictionary for JSONSerialization
  public func asAnyDictionary() -> [String: Any] {
    func convertValue(_ value: Value) -> Any {
      switch value {
        case .null: return NSNull()
        case .bool(let boolValue): return boolValue
        case .int(let i): return i
        case .double(let doubleValue): return doubleValue
        case .string(let stringValue): return stringValue
        case .data(let mimeType, let data):
          return ["mimeType": mimeType as Any, "data": data.base64EncodedString()]
        case .array(let array): return array.map { convertValue($0) }
        case .object(let dict):
          var result: [String: Any] = [:]
          for (key, value) in dict {
            result[key] = convertValue(value)
          }
          return result
      }
    }

    if case .object(let dict) = self {
      var result: [String: Any] = [:]
      for (key, value) in dict {
        result[key] = convertValue(value)
      }
      return result
    }

    return [:]
  }
}
