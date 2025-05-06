// ABOUTME: This file defines UI element identifiers for the macOS Calculator app.
// ABOUTME: It contains the element IDs needed to interact with Calculator in tests.

import Foundation
import AppKit
@testable import MacMCP

/// Constants representing UI element identifiers in the macOS Calculator app
enum CalculatorElements {
    /// Represents the main Calculator display element
    static let display = "Display"
    
    /// Represents the clear button (AC/C)
    static let clear = "AC"
    
    /// Represents digit buttons (0-9)
    struct Digits {
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
    }
    
    /// Represents operation buttons
    struct Operations {
        static let plus = "+"
        static let minus = "−"
        static let multiply = "×"
        static let divide = "÷"
        static let equals = "="
        static let decimal = "."
        static let percent = "%"
        static let sign = "±"
    }
}

/// Extensions to the CalculatorApp class for interacting with specific elements
extension CalculatorApp {
    /// Get the display element of the Calculator
    /// - Returns: The UI element representing the display, or nil if not found
    func getDisplayElement() async throws -> UIElement? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Traverse the UI hierarchy to find the display element
        for child in window.children {
            if child.identifier.contains(CalculatorElements.display) ||
               (child.role == "AXStaticText" && child.frame.origin.y < 100) {
                return child
            }
        }
        
        // If display not found by ID, look for criteria that might identify it
        for child in window.children {
            if child.role == "AXStaticText" || child.role == "AXTextField" {
                return child
            }
        }
        
        return nil
    }
    
    /// Get the current value shown in the Calculator display
    /// - Returns: The display value as a string, or nil if not found
    func getDisplayValue() async throws -> String? {
        guard let displayElement = try await getDisplayElement() else {
            return nil
        }
        
        return displayElement.value
    }
    
    /// Get a button element by its identifier
    /// - Parameter identifier: The button identifier (e.g., "1", "+", "=")
    /// - Returns: The UI element representing the button, or nil if not found
    func getButton(identifier: String) async throws -> UIElement? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Look for direct button match
        for child in window.children {
            if child.role == "AXButton" && (child.identifier.contains(identifier) || 
                                           child.title?.contains(identifier) == true ||
                                           child.value?.contains(identifier) == true) {
                return child
            }
        }
        
        // If the window has a group containing buttons, search there
        for child in window.children {
            if child.role == "AXGroup" {
                for button in child.children {
                    if button.role == "AXButton" && (button.identifier.contains(identifier) || 
                                                   button.title?.contains(identifier) == true ||
                                                   button.value?.contains(identifier) == true) {
                        return button
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Press a Calculator button by its identifier
    /// - Parameter identifier: The button identifier (e.g., "1", "+", "=")
    /// - Returns: True if the button was successfully pressed
    func pressButton(identifier: String) async throws -> Bool {
        guard let button = try await getButton(identifier: identifier) else {
            print("Button with identifier '\(identifier)' not found")
            return false
        }
        
        try await interactionService.clickElement(identifier: button.identifier)
        try await Task.sleep(for: .milliseconds(100)) // Brief pause for UI update
        return true
    }
    
    /// Type a sequence of characters using button presses
    /// - Parameter sequence: The sequence to enter (e.g., "123+456=")
    /// - Returns: True if all buttons were successfully pressed
    func enterSequence(_ sequence: String) async throws -> Bool {
        // Clear the calculator first
        try await pressButton(identifier: CalculatorElements.clear)
        
        // Press each button in sequence
        for char in sequence {
            let buttonId = String(char)
            
            // Map specific characters to button identifiers if needed
            let mappedId: String
            switch char {
            case '×': mappedId = CalculatorElements.Operations.multiply
            case '÷': mappedId = CalculatorElements.Operations.divide
            case '-': mappedId = CalculatorElements.Operations.minus
            case '−': mappedId = CalculatorElements.Operations.minus
            default: mappedId = buttonId
            }
            
            if !(try await pressButton(identifier: mappedId)) {
                return false
            }
            
            // Brief pause between button presses
            try await Task.sleep(for: .milliseconds(100))
        }
        
        return true
    }
    
    /// Perform a simple calculation and return the result
    /// - Parameters:
    ///   - num1: First number
    ///   - operation: Operation symbol ("+", "-", "×", "÷")
    ///   - num2: Second number
    /// - Returns: The result as shown on Calculator's display, or nil on failure
    func calculate(num1: String, operation: String, num2: String) async throws -> String? {
        // Clear the calculator
        try await pressButton(identifier: CalculatorElements.clear)
        
        // Enter the first number
        for digit in num1 {
            try await pressButton(identifier: String(digit))
        }
        
        // Press the operation button
        let operationId: String
        switch operation {
        case "+": operationId = CalculatorElements.Operations.plus
        case "-": operationId = CalculatorElements.Operations.minus
        case "×": operationId = CalculatorElements.Operations.multiply
        case "÷": operationId = CalculatorElements.Operations.divide
        default: operationId = operation
        }
        try await pressButton(identifier: operationId)
        
        // Enter the second number
        for digit in num2 {
            try await pressButton(identifier: String(digit))
        }
        
        // Press equals
        try await pressButton(identifier: CalculatorElements.Operations.equals)
        
        // Get the result
        return try await getDisplayValue()
    }
}