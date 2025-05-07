// ABOUTME: This file implements a driver for the macOS Calculator application for testing.
// ABOUTME: It provides methods to perform calculations and interact with the Calculator UI.

import Foundation
import XCTest
@testable import MacMCP

/// Driver for the macOS Calculator app used in tests
public class CalculatorDriver: BaseApplicationDriver, @unchecked Sendable {
    /// Calculator button identifiers
    public enum Button {
        static let zero = "0"
        static let one = "1"
        static let two = "2"
        static let three = "3"
        static let four = "4"
        static let five = "5"
        static let six = "6"
        static let seven = "7"
        static let eight = "8"
        static let nine = "9"
        static let plus = "+"
        static let minus = "-"
        static let multiply = "×"
        static let divide = "÷"
        static let equals = "="
        static let decimal = "."
        static let clear = "C"
        static let allClear = "AC"
    }
    
    /// Calculator display element criteria
    private let displayCriteria = ApplicationDrivers.ElementCriteria(role: "AXStaticText")
    
    /// Create a new Calculator driver
    /// - Parameters:
    ///   - applicationService: The application service to use
    ///   - accessibilityService: The accessibility service to use
    ///   - interactionService: The UI interaction service to use
    public init(
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        super.init(
            bundleIdentifier: "com.apple.calculator",
            appName: "Calculator",
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Get the display value shown on the calculator
    /// - Returns: The current display value or nil if not found
    public func getDisplayValue() async throws -> String? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Find the display element (first one that's a static text)
        for child in window.children {
            if child.role == "AXStaticText" {
                return child.value
            }
        }
        
        return nil
    }
    
    /// Press a specific calculator button
    /// - Parameter button: The button to press
    /// - Returns: True if the button was pressed successfully
    public func pressButton(_ button: String) async throws -> Bool {
        // Find the button element
        guard let window = try await getMainWindow() else {
            throw NSError(
                domain: "CalculatorDriver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not get calculator window"]
            )
        }
        
        // Look for the button in the window
        var buttonElement: UIElement?
        
        // Depth-first search for the button
        func findButton(in element: UIElement) -> UIElement? {
            // Check if this element is the button
            if element.role == "AXButton" && element.title == button {
                return element
            }
            
            // Check children
            for child in element.children {
                if let found = findButton(in: child) {
                    return found
                }
            }
            
            return nil
        }
        
        buttonElement = findButton(in: window)
        
        guard let element = buttonElement else {
            throw NSError(
                domain: "CalculatorDriver",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not find button '\(button)'"]
            )
        }
        
        // Click the button
        try await interactionService.clickElement(identifier: element.identifier)
        return true
    }
    
    /// Perform a calculation
    /// - Parameters:
    ///   - num1: The first number
    ///   - operation: The operation to perform (+, -, ×, ÷)
    ///   - num2: The second number
    /// - Returns: The result of the calculation
    public func calculate(num1: String, operation: String, num2: String) async throws -> String? {
        // Clear first
        try await pressButton(Button.allClear)
        
        // Enter first number
        for digit in num1 {
            try await pressButton(String(digit))
        }
        
        // Press operation
        try await pressButton(operation)
        
        // Enter second number
        for digit in num2 {
            try await pressButton(String(digit))
        }
        
        // Press equals
        try await pressButton(Button.equals)
        
        // Get result
        return try await getDisplayValue()
    }
}