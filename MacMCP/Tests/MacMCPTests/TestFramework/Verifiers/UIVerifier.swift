// ABOUTME: This file defines the UI verification system for MacMCP tests.
// ABOUTME: It provides methods to verify UI elements and states.

import Foundation
import XCTest
@testable import MacMCP

/// Class for verifying UI states and elements in tests
public class UIVerifier {
    /// ToolChain instance for interacting with the UI
    private let toolChain: ToolChain
    
    /// Create a new UI verifier
    /// - Parameter toolChain: ToolChain instance
    public init(toolChain: ToolChain) {
        self.toolChain = toolChain
    }
    
    /// Verify that an element matching criteria exists
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - timeout: Maximum time to wait for the element to appear
    /// - Returns: The matching element
    /// - Throws: XCTest failure if the element is not found
    public func verifyElementExists(
        matching criteria: UIElementCriteria,
        in scope: String = "system",
        bundleId: String? = nil,
        timeout: TimeInterval = 5.0
    ) async throws -> UIElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Try to find the element
            if let element = try await toolChain.findElement(
                matching: criteria,
                scope: scope,
                bundleId: bundleId
            ) {
                return element
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Element not found within timeout - fail the test
        XCTFail("Element matching \(criteria.debugDescription) not found within \(timeout) seconds")
        
        // This will never be reached due to XCTFail, but is needed for compilation
        throw NSError(
            domain: "UIVerifier",
            code: 1000,
            userInfo: [NSLocalizedDescriptionKey: "Element not found"]
        )
    }
    
    /// Verify that an element matching criteria does not exist
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - timeout: Time to wait to ensure the element does not appear
    /// - Throws: XCTest failure if the element is found
    public func verifyElementDoesNotExist(
        matching criteria: UIElementCriteria,
        in scope: String = "system",
        bundleId: String? = nil,
        timeout: TimeInterval = 2.0
    ) async throws {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Try to find the element
            if let _ = try await toolChain.findElement(
                matching: criteria,
                scope: scope,
                bundleId: bundleId
            ) {
                // Element found - fail the test
                XCTFail("Element matching \(criteria.debugDescription) was found, but should not exist")
                return
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Element not found within timeout - this is what we want
    }
    
    /// Verify that an element has a specific property value
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - property: The property to check ("title", "value", "description", etc.)
    ///   - expectedValue: The expected value of the property
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - timeout: Maximum time to wait for the condition to be true
    /// - Returns: The matching element
    /// - Throws: XCTest failure if the condition is not met
    public func verifyElementProperty(
        matching criteria: UIElementCriteria,
        property: String,
        equals expectedValue: String,
        in scope: String = "system",
        bundleId: String? = nil,
        timeout: TimeInterval = 5.0
    ) async throws -> UIElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Try to find the element
            if let element = try await toolChain.findElement(
                matching: criteria,
                scope: scope,
                bundleId: bundleId
            ) {
                // Check the property value
                let actualValue: String?
                
                switch property.lowercased() {
                case "title":
                    actualValue = element.title
                case "value":
                    actualValue = element.value
                case "description":
                    actualValue = element.elementDescription
                case "role":
                    actualValue = element.role
                case "identifier":
                    actualValue = element.identifier
                default:
                    throw NSError(
                        domain: "UIVerifier",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown property: \(property)"]
                    )
                }
                
                // If the property matches, return the element
                if actualValue == expectedValue {
                    return element
                }
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Property not matching within timeout - fail the test
        if let element = try await toolChain.findElement(
            matching: criteria,
            scope: scope,
            bundleId: bundleId
        ) {
            // Element found, but property doesn't match
            let actualValue: String?
            
            switch property.lowercased() {
            case "title":
                actualValue = element.title
            case "value":
                actualValue = element.value
            case "description":
                actualValue = element.elementDescription
            case "role":
                actualValue = element.role
            case "identifier":
                actualValue = element.identifier
            default:
                actualValue = nil
            }
            
            XCTFail("Element found, but \(property) value mismatch. Expected: \"\(expectedValue)\", Actual: \"\(actualValue ?? "nil")\"")
        } else {
            // Element not found
            XCTFail("Element matching \(criteria.debugDescription) not found within \(timeout) seconds")
        }
        
        // This will never be reached due to XCTFail, but is needed for compilation
        throw NSError(
            domain: "UIVerifier",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Property verification failed"]
        )
    }
    
    /// Verify that an element has a property containing a string
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - property: The property to check ("title", "value", "description", etc.)
    ///   - substring: The string that should be contained in the property
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - timeout: Maximum time to wait for the condition to be true
    /// - Returns: The matching element
    /// - Throws: XCTest failure if the condition is not met
    public func verifyElementPropertyContains(
        matching criteria: UIElementCriteria,
        property: String,
        contains substring: String,
        in scope: String = "system",
        bundleId: String? = nil,
        timeout: TimeInterval = 5.0
    ) async throws -> UIElement {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Try to find the element
            if let element = try await toolChain.findElement(
                matching: criteria,
                scope: scope,
                bundleId: bundleId
            ) {
                // Check the property value
                let actualValue: String?
                
                switch property.lowercased() {
                case "title":
                    actualValue = element.title
                case "value":
                    actualValue = element.value
                case "description":
                    actualValue = element.elementDescription
                case "role":
                    actualValue = element.role
                case "identifier":
                    actualValue = element.identifier
                default:
                    throw NSError(
                        domain: "UIVerifier",
                        code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown property: \(property)"]
                    )
                }
                
                // If the property contains the substring, return the element
                if let actualValue = actualValue, actualValue.contains(substring) {
                    return element
                }
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Property not containing substring within timeout - fail the test
        if let element = try await toolChain.findElement(
            matching: criteria,
            scope: scope,
            bundleId: bundleId
        ) {
            // Element found, but property doesn't contain substring
            let actualValue: String?
            
            switch property.lowercased() {
            case "title":
                actualValue = element.title
            case "value":
                actualValue = element.value
            case "description":
                actualValue = element.elementDescription
            case "role":
                actualValue = element.role
            case "identifier":
                actualValue = element.identifier
            default:
                actualValue = nil
            }
            
            XCTFail("Element found, but \(property) value doesn't contain \"\(substring)\". Actual: \"\(actualValue ?? "nil")\"")
        } else {
            // Element not found
            XCTFail("Element matching \(criteria.debugDescription) not found within \(timeout) seconds")
        }
        
        // This will never be reached due to XCTFail, but is needed for compilation
        throw NSError(
            domain: "UIVerifier",
            code: 1003,
            userInfo: [NSLocalizedDescriptionKey: "Property verification failed"]
        )
    }
}