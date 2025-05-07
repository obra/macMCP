// ABOUTME: This file provides utilities for verifying UI state results in tests.
// ABOUTME: It contains methods for checking that UI elements match expectations.

import Foundation
import XCTest
@testable import MacMCP

/// Verifies UI state results from tool operations
public struct UIStateVerifier {
    /// Verifies that an element matching the criteria exists in the UI state
    /// - Parameters:
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if a matching element exists
    @discardableResult
    public static func verifyElementExists(
        in uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let exists = uiState.hasElement(matching: criteria)
        XCTAssertTrue(exists, "Expected to find element matching criteria", file: file, line: line)
        return exists
    }
    
    /// Verifies that no element matching the criteria exists in the UI state
    /// - Parameters:
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if no matching element exists
    @discardableResult
    public static func verifyElementDoesNotExist(
        in uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let exists = uiState.hasElement(matching: criteria)
        XCTAssertFalse(exists, "Expected not to find element matching criteria", file: file, line: line)
        return !exists
    }
    
    /// Verifies that the exact number of elements matching the criteria exist
    /// - Parameters:
    ///   - count: The expected number of matching elements
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if the number of matching elements matches the expectation
    @discardableResult
    public static func verifyElementCount(
        _ count: Int,
        in uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let actualCount = uiState.countElements(matching: criteria)
        XCTAssertEqual(
            actualCount,
            count,
            "Expected \(count) elements matching criteria, found \(actualCount)",
            file: file,
            line: line
        )
        return actualCount == count
    }
    
    /// Verifies that an element with the specified value exists
    /// - Parameters:
    ///   - value: The expected value
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if a matching element with the specified value exists
    @discardableResult
    public static func verifyElementHasValue(
        _ value: String,
        in uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let element = uiState.findElement(matching: criteria) else {
            XCTFail("No element matching criteria found", file: file, line: line)
            return false
        }
        
        XCTAssertEqual(
            element.value,
            value,
            "Element value \(element.value ?? "nil") did not match expected \(value)",
            file: file,
            line: line
        )
        return element.value == value
    }
    
    /// Verifies that an element has a specific capability
    /// - Parameters:
    ///   - capability: The capability name
    ///   - expected: The expected value
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: True if a matching element with the specified capability exists
    @discardableResult
    public static func verifyElementHasCapability(
        _ capability: String,
        value expected: Bool,
        in uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let element = uiState.findElement(matching: criteria) else {
            XCTFail("No element matching criteria found", file: file, line: line)
            return false
        }
        
        guard let actual = element.capabilities[capability] else {
            XCTFail("Element does not have capability \(capability)", file: file, line: line)
            return false
        }
        
        XCTAssertEqual(
            actual,
            expected,
            "Element capability \(capability) value \(actual) did not match expected \(expected)",
            file: file,
            line: line
        )
        return actual == expected
    }
    
    /// Gets an element matching the criteria
    /// - Parameters:
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    ///   - file: Source file
    ///   - line: Source line
    /// - Returns: The matching element or nil
    public static func getElement(
        from uiState: UIStateResult,
        matching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIElementRepresentation? {
        let element = uiState.findElement(matching: criteria)
        if element == nil {
            XCTFail("No element matching criteria found", file: file, line: line)
        }
        return element
    }
    
    /// Gets all elements matching the criteria
    /// - Parameters:
    ///   - uiState: The UI state to check
    ///   - criteria: The criteria to match
    /// - Returns: Array of matching elements
    public static func getElements(
        from uiState: UIStateResult,
        matching criteria: ElementCriteria
    ) -> [UIElementRepresentation] {
        return uiState.findElements(matching: criteria)
    }
}