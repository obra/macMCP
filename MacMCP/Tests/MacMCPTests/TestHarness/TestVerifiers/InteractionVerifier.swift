// ABOUTME: This file provides utilities for verifying UI interactions in tests.
// ABOUTME: It helps validate that UI interactions result in expected state changes.

import Foundation
import XCTest
@testable import MacMCP

/// Verifies UI interaction results from tool operations
public struct InteractionVerifier {
    /// The type of verification to perform
    public enum VerificationType {
        /// Verify that an element exists
        case elementExists(ElementCriteria)
        
        /// Verify that an element does not exist
        case elementDoesNotExist(ElementCriteria)
        
        /// Verify that an element has a specific value
        case elementHasValue(ElementCriteria, String)
        
        /// Verify that an element has a specific capability
        case elementHasCapability(ElementCriteria, String, Bool)
        
        /// Verify that an element is selected
        case elementIsSelected(ElementCriteria)
        
        /// Verify that an element is focused
        case elementIsFocused(ElementCriteria)
        
        /// Verify that an element has a specific title
        case elementHasTitle(ElementCriteria, String)
        
        /// Verify that a specific count of elements match criteria
        case elementCount(ElementCriteria, Int)
        
        /// Custom verification with closure
        case custom((UIStateResult) -> Bool, String)
    }
    
    /// Result of an interaction verification
    public struct VerificationResult {
        /// Whether the verification passed
        public let success: Bool
        
        /// The verification type that was performed
        public let verificationType: VerificationType
        
        /// Description of the verification result
        public let message: String
        
        /// UI state before the interaction
        public let beforeState: UIStateResult?
        
        /// UI state after the interaction
        public let afterState: UIStateResult
        
        /// Create a new verification result
        /// - Parameters:
        ///   - success: Whether the verification passed
        ///   - verificationType: The verification type
        ///   - message: Description of the result
        ///   - beforeState: Optional UI state before interaction
        ///   - afterState: UI state after interaction
        public init(
            success: Bool,
            verificationType: VerificationType,
            message: String,
            beforeState: UIStateResult? = nil,
            afterState: UIStateResult
        ) {
            self.success = success
            self.verificationType = verificationType
            self.message = message
            self.beforeState = beforeState
            self.afterState = afterState
        }
    }
    
    /// Verifies that a UI interaction had the expected effect
    /// - Parameters:
    ///   - beforeState: The UI state before the interaction
    ///   - afterState: The UI state after the interaction
    ///   - verification: The verification to perform
    ///   - file: Source file location
    ///   - line: Source line number
    /// - Returns: Verification result
    @discardableResult
    public static func verifyInteraction(
        before beforeState: UIStateResult?,
        after afterState: UIStateResult,
        verification: VerificationType,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> VerificationResult {
        let result: VerificationResult
        
        switch verification {
        case .elementExists(let criteria):
            let exists = afterState.hasElement(matching: criteria)
            let message = exists ? 
                "Element matching criteria exists" : 
                "Element matching criteria does not exist"
            
            result = VerificationResult(
                success: exists,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertTrue(exists, "Expected element to exist after interaction", file: file, line: line)
            
        case .elementDoesNotExist(let criteria):
            let exists = afterState.hasElement(matching: criteria)
            let message = !exists ? 
                "Element matching criteria does not exist" : 
                "Element matching criteria exists"
            
            result = VerificationResult(
                success: !exists,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertFalse(exists, "Expected element to not exist after interaction", file: file, line: line)
            
        case .elementHasValue(let criteria, let expectedValue):
            let element = afterState.findElement(matching: criteria)
            let hasValue = element?.value == expectedValue
            let message: String
            
            if let foundElement = element {
                message = hasValue ? 
                    "Element has expected value '\(expectedValue)'" : 
                    "Element value is '\(foundElement.value ?? "nil")' but expected '\(expectedValue)'"
            } else {
                message = "Element matching criteria not found"
            }
            
            result = VerificationResult(
                success: hasValue && element != nil,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertNotNil(element, "Element should exist after interaction", file: file, line: line)
            if element != nil {
                XCTAssertEqual(element!.value, expectedValue, "Element should have expected value", file: file, line: line)
            }
            
        case .elementHasCapability(let criteria, let capability, let expectedValue):
            let element = afterState.findElement(matching: criteria)
            let hasCapability = element?.capabilities[capability] == expectedValue
            let message: String
            
            if let foundElement = element {
                if let capabilityValue = foundElement.capabilities[capability] {
                    message = hasCapability ? 
                        "Element has capability '\(capability)' with expected value '\(expectedValue)'" : 
                        "Element capability '\(capability)' is '\(capabilityValue)' but expected '\(expectedValue)'"
                } else {
                    message = "Element does not have capability '\(capability)'"
                }
            } else {
                message = "Element matching criteria not found"
            }
            
            result = VerificationResult(
                success: hasCapability && element != nil,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertNotNil(element, "Element should exist after interaction", file: file, line: line)
            if element != nil {
                XCTAssertEqual(
                    element!.capabilities[capability], 
                    expectedValue, 
                    "Element should have expected capability value", 
                    file: file, 
                    line: line
                )
            }
            
        case .elementIsSelected(let criteria):
            let element = afterState.findElement(matching: criteria)
            let isSelected = element?.capabilities["selected"] == true
            let message: String
            
            if element != nil {
                message = isSelected ? 
                    "Element is selected" : 
                    "Element is not selected"
            } else {
                message = "Element matching criteria not found"
            }
            
            result = VerificationResult(
                success: isSelected && element != nil,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertNotNil(element, "Element should exist after interaction", file: file, line: line)
            if element != nil {
                XCTAssertEqual(
                    element!.capabilities["selected"], 
                    true, 
                    "Element should be selected", 
                    file: file, 
                    line: line
                )
            }
            
        case .elementIsFocused(let criteria):
            let element = afterState.findElement(matching: criteria)
            let isFocused = element?.capabilities["focused"] == true
            let message: String
            
            if element != nil {
                message = isFocused ? 
                    "Element is focused" : 
                    "Element is not focused"
            } else {
                message = "Element matching criteria not found"
            }
            
            result = VerificationResult(
                success: isFocused && element != nil,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertNotNil(element, "Element should exist after interaction", file: file, line: line)
            if element != nil {
                XCTAssertEqual(
                    element!.capabilities["focused"], 
                    true, 
                    "Element should be focused", 
                    file: file, 
                    line: line
                )
            }
            
        case .elementHasTitle(let criteria, let expectedTitle):
            let element = afterState.findElement(matching: criteria)
            let hasTitle = element?.title == expectedTitle
            let message: String
            
            if let element = element {
                message = hasTitle ? 
                    "Element has expected title '\(expectedTitle)'" : 
                    "Element title is '\(element.title ?? "nil")' but expected '\(expectedTitle)'"
            } else {
                message = "Element matching criteria not found"
            }
            
            result = VerificationResult(
                success: hasTitle && element != nil,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertNotNil(element, "Element should exist after interaction", file: file, line: line)
            if element != nil {
                XCTAssertEqual(
                    element!.title, 
                    expectedTitle, 
                    "Element should have expected title", 
                    file: file, 
                    line: line
                )
            }
            
        case .elementCount(let criteria, let expectedCount):
            let elements = afterState.findElements(matching: criteria)
            let countMatches = elements.count == expectedCount
            let message = countMatches ? 
                "Found expected count of \(expectedCount) elements" : 
                "Found \(elements.count) elements but expected \(expectedCount)"
            
            result = VerificationResult(
                success: countMatches,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertEqual(
                elements.count, 
                expectedCount, 
                "Expected to find \(expectedCount) matching elements", 
                file: file, 
                line: line
            )
            
        case .custom(let verificationFunc, let description):
            let success = verificationFunc(afterState)
            let message = success ? 
                "Custom verification passed: \(description)" : 
                "Custom verification failed: \(description)"
            
            result = VerificationResult(
                success: success,
                verificationType: verification,
                message: message,
                beforeState: beforeState,
                afterState: afterState
            )
            
            XCTAssertTrue(
                success, 
                "Custom verification should pass: \(description)", 
                file: file, 
                line: line
            )
        }
        
        return result
    }
    
    /// Verifies state change from a UI interaction
    /// - Parameters:
    ///   - beforeState: The UI state before the interaction
    ///   - afterState: The UI state after the interaction
    ///   - criteria: The criteria to match the element
    ///   - beforeValueSelector: Function to extract value before interaction
    ///   - afterValueSelector: Function to extract value after interaction
    ///   - file: Source file location
    ///   - line: Source line number
    /// - Returns: True if state changed as expected
    @discardableResult
    public static func verifyStateChange<T: Equatable>(
        before beforeState: UIStateResult,
        after afterState: UIStateResult,
        elementMatching criteria: ElementCriteria,
        beforeValue expectedBeforeValue: T?,
        afterValue expectedAfterValue: T?,
        valueExtractor: (UIElementRepresentation) -> T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        guard let beforeElement = beforeState.findElement(matching: criteria) else {
            XCTFail("Element not found in before state", file: file, line: line)
            return false
        }
        
        guard let afterElement = afterState.findElement(matching: criteria) else {
            XCTFail("Element not found in after state", file: file, line: line)
            return false
        }
        
        let beforeValue = valueExtractor(beforeElement)
        let afterValue = valueExtractor(afterElement)
        
        // Verify before value matches expected
        if let expectedBeforeValue = expectedBeforeValue {
            XCTAssertEqual(
                beforeValue, 
                expectedBeforeValue, 
                "Element before value doesn't match expected", 
                file: file, 
                line: line
            )
            
            if beforeValue != expectedBeforeValue {
                return false
            }
        }
        
        // Verify after value matches expected
        if let expectedAfterValue = expectedAfterValue {
            XCTAssertEqual(
                afterValue, 
                expectedAfterValue, 
                "Element after value doesn't match expected", 
                file: file, 
                line: line
            )
            
            if afterValue != expectedAfterValue {
                return false
            }
        }
        
        return true
    }
    
    /// Verify that an element appeared after an interaction
    /// - Parameters:
    ///   - beforeState: UI state before interaction
    ///   - afterState: UI state after interaction
    ///   - criteria: Criteria to match the element
    ///   - file: Source file location
    ///   - line: Source line number
    /// - Returns: True if element appeared
    @discardableResult
    public static func verifyElementAppeared(
        before beforeState: UIStateResult,
        after afterState: UIStateResult,
        elementMatching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let beforeExists = beforeState.hasElement(matching: criteria)
        let afterExists = afterState.hasElement(matching: criteria)
        
        XCTAssertFalse(beforeExists, "Element should not exist before interaction", file: file, line: line)
        XCTAssertTrue(afterExists, "Element should exist after interaction", file: file, line: line)
        
        return !beforeExists && afterExists
    }
    
    /// Verify that an element disappeared after an interaction
    /// - Parameters:
    ///   - beforeState: UI state before interaction
    ///   - afterState: UI state after interaction
    ///   - criteria: Criteria to match the element
    ///   - file: Source file location
    ///   - line: Source line number
    /// - Returns: True if element disappeared
    @discardableResult
    public static func verifyElementDisappeared(
        before beforeState: UIStateResult,
        after afterState: UIStateResult,
        elementMatching criteria: ElementCriteria,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let beforeExists = beforeState.hasElement(matching: criteria)
        let afterExists = afterState.hasElement(matching: criteria)
        
        XCTAssertTrue(beforeExists, "Element should exist before interaction", file: file, line: line)
        XCTAssertFalse(afterExists, "Element should not exist after interaction", file: file, line: line)
        
        return beforeExists && !afterExists
    }
    
    /// Verify multiple conditions at once
    /// - Parameters:
    ///   - beforeState: UI state before interaction
    ///   - afterState: UI state after interaction
    ///   - verifications: List of verifications to perform
    ///   - file: Source file location
    ///   - line: Source line number
    /// - Returns: Array of verification results
    @discardableResult
    public static func verifyAll(
        before beforeState: UIStateResult? = nil,
        after afterState: UIStateResult,
        verifications: [VerificationType],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> [VerificationResult] {
        var results: [VerificationResult] = []
        
        for verification in verifications {
            let result = verifyInteraction(
                before: beforeState,
                after: afterState,
                verification: verification,
                file: file,
                line: line
            )
            results.append(result)
        }
        
        let allSucceeded = results.allSatisfy { $0.success }
        if !allSucceeded {
            let failedVerifications = results
                .filter { !$0.success }
                .map { $0.message }
                .joined(separator: ", ")
            
            XCTFail("Multiple verifications failed: \(failedVerifications)", file: file, line: line)
        }
        
        return results
    }
}