// ABOUTME: JSONTestUtilities.swift
// ABOUTME: Utilities for testing JSON responses in MacMCP tests

import Foundation
import Testing

@testable import MacMCP

/// Utilities for working with JSON responses in tests
enum JSONTestUtilities {
  /// Error types for JSON parsing
  enum JSONTestError: Error, CustomStringConvertible {
    case invalidJSON(String)
    case missingProperty(String)
    case wrongPropertyType(property: String, expectedType: String, actualType: String)
    case invalidPropertyValue(property: String, expected: String, actual: String)
    case assertionFailed(String)
    var description: String {
      switch self {
        case .invalidJSON(let message): "Invalid JSON: \(message)"
        case .missingProperty(let property): "Missing property: \(property)"
        case .wrongPropertyType(let property, let expectedType, let actualType):
          "Wrong property type for '\(property)': expected \(expectedType), got \(actualType)"
        case .invalidPropertyValue(let property, let expected, let actual):
          "Invalid property value for '\(property)': expected \(expected), got \(actual)"
        case .assertionFailed(let message): "Assertion failed: \(message)"
      }
    }
  }

  /// Parses JSON string into a dictionary or array
  /// - Parameter jsonString: The JSON string to parse
  /// - Returns: The parsed JSON object
  /// - Throws: JSONTestError if parsing fails
  static func parseJSON(_ jsonString: String) throws -> Any {
    guard let jsonData = jsonString.data(using: .utf8) else {
      throw JSONTestError.invalidJSON("Could not convert string to data")
    }
    do { return try JSONSerialization.jsonObject(with: jsonData, options: []) } catch {
      throw JSONTestError.invalidJSON("Parse error: \(error.localizedDescription)")
    }
  }

  /// Parses JSON string into an array of dictionaries
  /// - Parameter jsonString: The JSON string to parse
  /// - Returns: The parsed JSON array
  /// - Throws: JSONTestError if parsing fails or the result is not an array
  static func parseJSONArray(_ jsonString: String) throws -> [[String: Any]] {
    let parsed = try parseJSON(jsonString)
    guard let array = parsed as? [[String: Any]] else {
      throw JSONTestError.invalidJSON("Expected array of objects, got \(type(of: parsed))")
    }
    return array
  }

  /// Parses JSON string into a dictionary
  /// - Parameter jsonString: The JSON string to parse
  /// - Returns: The parsed JSON dictionary
  /// - Throws: JSONTestError if parsing fails or the result is not a dictionary
  static func parseJSONObject(_ jsonString: String) throws -> [String: Any] {
    let parsed = try parseJSON(jsonString)
    guard let dict = parsed as? [String: Any] else {
      throw JSONTestError.invalidJSON("Expected object, got \(type(of: parsed))")
    }
    return dict
  }

  /// Verifies that a JSON object contains a specific property
  /// - Parameters:
  ///   - json: The JSON object to check
  ///   - property: The property name to look for
  /// - Returns: True if the property exists
  /// - Throws: JSONTestError if the property doesn't exist
  @discardableResult static func assertPropertyExists(_ json: [String: Any], property: String)
    throws -> Bool
  {
    guard json[property] != nil else { throw JSONTestError.missingProperty(property) }
    return true
  }

  /// Verifies that a JSON object contains a property with a specific value
  /// - Parameters:
  ///   - json: The JSON object to check
  ///   - property: The property name to check
  ///   - expectedValue: The expected value (as Any)
  ///   - message: Optional message for the assertion
  /// - Returns: True if the property has the expected value
  /// - Throws: JSONTestError if the property doesn't exist or has the wrong value
  @discardableResult static func assertProperty(
    _ json: [String: Any],
    property: String,
    equals expectedValue: Any,
    message: String? = nil,
  ) throws -> Bool {
    // First check if property exists
    try assertPropertyExists(json, property: property)
    let actualValue = json[property]!
    // Check types match (allow String and NSString variants to match, and numeric types with NSNumber)
    let expectedIsString = expectedValue is String
    let actualIsString = actualValue is String
    let expectedIsBool = expectedValue is Bool
    let actualIsBool = actualValue is Bool || actualValue is NSNumber
    let expectedIsNumeric = expectedValue is Int || expectedValue is Double || expectedValue is Float || expectedValue is Bool
    let actualIsNumeric = actualValue is NSNumber || actualValue is Int || actualValue is Double || actualValue is Float || actualValue is Bool
    
    let typesMatch = (expectedIsString && actualIsString) || 
                     (expectedIsNumeric && actualIsNumeric) ||
                     type(of: expectedValue) == type(of: actualValue)
    
    if !typesMatch {
      throw JSONTestError.wrongPropertyType(
        property: property,
        expectedType: "\(type(of: expectedValue))",
        actualType: "\(type(of: actualValue))",
      )
    }
    // Check values match (handle numeric types and NSNumber comparison specially)
    var valuesMatch = false
    
    if expectedIsBool && actualIsBool {
      // Handle Bool vs NSNumber comparison
      let expectedBool = expectedValue as! Bool
      if let actualNSNumber = actualValue as? NSNumber {
        valuesMatch = expectedBool == actualNSNumber.boolValue
      } else {
        valuesMatch = expectedBool == (actualValue as! Bool)
      }
    } else if expectedIsNumeric && actualIsNumeric {
      // Handle numeric vs NSNumber comparison
      if let actualNSNumber = actualValue as? NSNumber {
        if let expectedInt = expectedValue as? Int {
          valuesMatch = expectedInt == actualNSNumber.intValue
        } else if let expectedDouble = expectedValue as? Double {
          valuesMatch = expectedDouble == actualNSNumber.doubleValue
        } else if let expectedFloat = expectedValue as? Float {
          valuesMatch = expectedFloat == actualNSNumber.floatValue
        } else {
          // Default to string comparison for other numeric types
          valuesMatch = "\(expectedValue)" == "\(actualValue)"
        }
      } else {
        // Both are native Swift numeric types
        valuesMatch = "\(expectedValue)" == "\(actualValue)"
      }
    } else {
      // Default string comparison for other types
      let expectedStr = "\(expectedValue)"
      let actualStr = "\(actualValue)"
      valuesMatch = expectedStr == actualStr
    }
    
    if !valuesMatch {
      let expectedStr = "\(expectedValue)"
      let actualStr = "\(actualValue)"
      throw JSONTestError.invalidPropertyValue(
        property: property, expected: expectedStr, actual: actualStr,
      )
    }
    return true
  }

  /// Verifies that a JSON array contains objects with specific property values
  /// - Parameters:
  ///   - jsonArray: The JSON array to check
  ///   - property: The property name to check
  ///   - expectedValue: The expected value
  ///   - message: Optional message for the assertion
  /// - Returns: True if at least one object has the property with the expected value
  /// - Throws: JSONTestError if no objects have the property with the expected value
  @discardableResult static func assertArrayContainsObjectWithProperty(
    _ jsonArray: [[String: Any]],
    property: String,
    equals expectedValue: Any,
    message: String? = nil,
  ) throws -> Bool {
    for item in jsonArray {
      // Skip items that don't have the property or don't match the value
      if item[property] == nil { continue }
      do {
        // Try to match this item
        try assertProperty(item, property: property, equals: expectedValue)
        // If we get here, we found a match
        return true
      } catch {
        // This item didn't match, continue to next one
        continue
      }
    }
    // If we get here, no items matched
    throw JSONTestError.invalidPropertyValue(
      property: property,
      expected: "\(expectedValue)",
      actual: "not found in array",
    )
  }

  /// Performs multiple assertions on a JSON string
  /// - Parameters:
  ///   - jsonString: The JSON string to test
  ///   - assertions: A closure that performs assertions on the parsed JSON
  /// - Returns: True if all assertions pass
  /// - Throws: JSONTestError if parsing fails or any assertion fails
  @discardableResult static func testJSONObject(
    _ jsonString: String, assertions: ([String: Any]) throws -> Void,
  )
    throws -> Bool
  {
    let json = try parseJSONObject(jsonString)
    try assertions(json)
    return true
  }

  /// Performs multiple assertions on a JSON array
  /// - Parameters:
  ///   - jsonString: The JSON string to test
  ///   - assertions: A closure that performs assertions on the parsed JSON array
  /// - Returns: True if all assertions pass
  /// - Throws: JSONTestError if parsing fails or any assertion fails
  @discardableResult static func testJSONArray(
    _ jsonString: String, assertions: ([[String: Any]]) throws -> Void,
  )
    throws -> Bool
  {
    let json = try parseJSONArray(jsonString)
    try assertions(json)
    return true
  }

  // MARK: - Negative Assertion Utilities

  /// Asserts that a JSON string does NOT contain a specific substring
  /// - Parameters:
  ///   - jsonString: The JSON string to test
  ///   - substring: The substring that should NOT be present
  ///   - message: Optional custom error message
  /// - Throws: JSONTestError if the substring is found
  static func assertDoesNotContain(_ jsonString: String, substring: String, message: String? = nil) throws {
    if jsonString.contains(substring) {
      let errorMessage = message ?? "JSON should not contain '\(substring)'"
      throw JSONTestError.assertionFailed(errorMessage)
    }
  }

  /// Asserts that a JSON string does NOT contain any of the specified substrings
  /// - Parameters:
  ///   - jsonString: The JSON string to test
  ///   - substrings: Array of substrings that should NOT be present
  ///   - message: Optional custom error message
  /// - Throws: JSONTestError if any substring is found
  static func assertDoesNotContainAny(_ jsonString: String, substrings: [String], message: String? = nil) throws {
    for substring in substrings {
      if jsonString.contains(substring) {
        let errorMessage = message ?? "JSON should not contain '\(substring)'"
        throw JSONTestError.assertionFailed(errorMessage)
      }
    }
  }

  /// Asserts that a property does NOT exist in a JSON object
  /// - Parameters:
  ///   - json: The JSON object to test
  ///   - property: The property name that should NOT exist
  ///   - message: Optional custom error message
  /// - Throws: JSONTestError if the property exists
  static func assertPropertyDoesNotExist(_ json: [String: Any], property: String, message: String? = nil) throws {
    if json[property] != nil {
      let errorMessage = message ?? "Property '\(property)' should not exist"
      throw JSONTestError.assertionFailed(errorMessage)
    }
  }
}

// MARK: - EnhancedElementDescriptor Testing Utilities

extension JSONTestUtilities {
  /// Tests an EnhancedElementDescriptor's JSON output with structured assertions
  /// - Parameters:
  ///   - descriptor: The descriptor to test
  ///   - assertions: A closure that performs assertions on the parsed JSON
  /// - Returns: True if all assertions pass
  /// - Throws: JSONTestError if encoding/parsing fails or any assertion fails
  @discardableResult static func testElementDescriptor(
    _ descriptor: EnhancedElementDescriptor,
    assertions: ([String: Any]) throws -> Void
  ) throws -> Bool {
    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(descriptor)
    let jsonString = String(data: jsonData, encoding: .utf8)!
    return try testJSONObject(jsonString, assertions: assertions)
  }
  
  /// Asserts that a property does NOT exist in the JSON object
  /// - Parameters:
  ///   - json: The JSON object to check
  ///   - property: The property name that should not exist
  /// - Returns: True if the property doesn't exist
  /// - Throws: JSONTestError if the property exists
  @discardableResult static func assertPropertyDoesNotExist(
    _ json: [String: Any], 
    property: String
  ) throws -> Bool {
    if json[property] != nil {
      throw JSONTestError.missingProperty("Property '\(property)' should not exist but was found")
    }
    return true
  }
  
  /// Asserts that a string property contains a specific substring
  /// - Parameters:
  ///   - json: The JSON object to check
  ///   - property: The property name to check
  ///   - substring: The substring that should be present
  /// - Returns: True if the property contains the substring
  /// - Throws: JSONTestError if the property doesn't exist, isn't a string, or doesn't contain the substring
  @discardableResult static func assertPropertyContains(
    _ json: [String: Any],
    property: String,
    substring: String
  ) throws -> Bool {
    try assertPropertyExists(json, property: property)
    
    guard let stringValue = json[property] as? String else {
      throw JSONTestError.wrongPropertyType(
        property: property,
        expectedType: "String",
        actualType: "\(type(of: json[property]!))"
      )
    }
    
    if !stringValue.contains(substring) {
      throw JSONTestError.invalidPropertyValue(
        property: property,
        expected: "contains '\(substring)'",
        actual: "'\(stringValue)'"
      )
    }
    
    return true
  }
}
