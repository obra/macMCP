// ABOUTME: This file contains extensions to the MCP Value type for the MacMCP project.
// ABOUTME: It provides helper methods for working with MCP Value in our application.

import Foundation
import MCP

extension Value {
    /// Convert Value to a Swift-friendly dictionary for JSONSerialization
    public func asAnyDictionary() -> [String: Any] {
        func convertValue(_ value: Value) -> Any {
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
        
        if case let .object(dict) = self {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key] = convertValue(value)
            }
            return result
        }
        
        return [:]
    }
}