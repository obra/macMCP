// ABOUTME: JSONTestUtilities.swift
// ABOUTME: Utilities for testing JSON responses in MacMCP tests

import Foundation
import Testing

/// Utilities for working with JSON responses in tests
struct JSONTestUtilities {
    
    /// Error types for JSON parsing
    enum JSONTestError: Error, CustomStringConvertible {
        case invalidJSON(String)
        case missingProperty(String)
        case wrongPropertyType(property: String, expectedType: String, actualType: String)
        case invalidPropertyValue(property: String, expected: String, actual: String)
        
        var description: String {
            switch self {
            case .invalidJSON(let message):
                return "Invalid JSON: \(message)"
            case .missingProperty(let property):
                return "Missing property: \(property)"
            case .wrongPropertyType(let property, let expectedType, let actualType):
                return "Wrong property type for '\(property)': expected \(expectedType), got \(actualType)"
            case .invalidPropertyValue(let property, let expected, let actual):
                return "Invalid property value for '\(property)': expected \(expected), got \(actual)"
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
        
        do {
            return try JSONSerialization.jsonObject(with: jsonData, options: [])
        } catch {
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
    @discardableResult
    static func assertPropertyExists(_ json: [String: Any], property: String) throws -> Bool {
        guard json[property] != nil else {
            throw JSONTestError.missingProperty(property)
        }
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
    @discardableResult
    static func assertProperty(_ json: [String: Any], property: String, equals expectedValue: Any, message: String? = nil) throws -> Bool {
        // First check if property exists
        try assertPropertyExists(json, property: property)
        
        let actualValue = json[property]!
        
        // Check types match
        if type(of: expectedValue) != type(of: actualValue) {
            throw JSONTestError.wrongPropertyType(
                property: property,
                expectedType: "\(type(of: expectedValue))",
                actualType: "\(type(of: actualValue))"
            )
        }
        
        // Check values match (converted to strings for comparison)
        let expectedStr = "\(expectedValue)"
        let actualStr = "\(actualValue)"
        
        if expectedStr != actualStr {
            throw JSONTestError.invalidPropertyValue(
                property: property,
                expected: expectedStr,
                actual: actualStr
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
    @discardableResult
    static func assertArrayContainsObjectWithProperty(_ jsonArray: [[String: Any]], property: String, equals expectedValue: Any, message: String? = nil) throws -> Bool {
        for item in jsonArray {
            // Skip items that don't have the property or don't match the value
            if item[property] == nil {
                continue
            }
            
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
            actual: "not found in array"
        )
    }
    
    /// Performs multiple assertions on a JSON string
    /// - Parameters:
    ///   - jsonString: The JSON string to test
    ///   - assertions: A closure that performs assertions on the parsed JSON
    /// - Returns: True if all assertions pass
    /// - Throws: JSONTestError if parsing fails or any assertion fails
    @discardableResult
    static func testJSONObject(_ jsonString: String, assertions: ([String: Any]) throws -> Void) throws -> Bool {
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
    @discardableResult
    static func testJSONArray(_ jsonString: String, assertions: ([[String: Any]]) throws -> Void) throws -> Bool {
        let json = try parseJSONArray(jsonString)
        try assertions(json)
        return true
    }
}

// Extension methods can be added later if needed