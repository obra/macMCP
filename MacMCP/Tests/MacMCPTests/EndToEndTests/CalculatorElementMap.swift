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
        print("Searching for button with identifier: \(identifier)")
        
        // Get main window - with single focused attempt
        guard let window = try await getMainWindow() else {
            print("Could not get main window")
            return nil
        }
            
            // Try a multi-level recursive search to find the button
            // This works better with modern macOS calculator which has a more complex hierarchy
            func searchForButtonRecursively(in element: UIElement, depth: Int = 0) -> UIElement? {
                // Increased recursion depth to find deeper elements like calculator buttons
                guard depth < 20 else { return nil }
                
                // Print info about the current element at higher levels to help with debugging
                let indent = String(repeating: "  ", count: depth)
                
                // Print every button regardless of depth
                if element.role == "AXButton" || element.role.contains("Button") {
                    print("\(indent)BUTTON FOUND: role=\(element.role), id=\(element.identifier), " +
                          "title=\(element.title ?? "nil"), value=\(element.value ?? "nil"), " +
                          "description=\(element.elementDescription ?? "nil"), frame=\(element.frame)")
                }
                // Print detailed info only at higher levels
                else if depth < 2 {
                    print("\(indent)Examining: role=\(element.role), id=\(element.identifier)")
                    
                    if !element.children.isEmpty && depth == 0 {
                        print("\(indent)This element has \(element.children.count) children")
                        
                        // Print the first few direct children for visibility
                        for (i, child) in element.children.enumerated().prefix(3) {
                            print("\(indent)  Child \(i): role=\(child.role), id=\(child.identifier), " +
                                  "title=\(child.title ?? "nil"), description=\(child.elementDescription ?? "nil")")
                            if !child.children.isEmpty {
                                print("\(indent)    Child \(i) has \(child.children.count) children")
                            }
                        }
                    }
                }
                
                // Check if this is a button
                if element.role == "AXButton" || 
                   element.role == "AXButtonSubstitute" || 
                   element.role.contains("Button") {
                   
                    // Print all button info to help with debugging
                    let isMatch = element.identifier.contains(identifier) ||
                                  element.title?.contains(identifier) == true ||
                                  element.value?.contains(identifier) == true ||
                                  element.description.contains(identifier)
                    
                    let prefix = isMatch ? "POTENTIAL MATCH: " : ""
                    let buttonDetails = "\(prefix)Button: role=\(element.role), id=\(element.identifier), " +
                                       "title=\(element.title ?? "nil"), " +
                                       "value=\(element.value ?? "nil"), " +
                                       "description=\(element.description)"
                    
                    // Only print detailed info if it's a potential match to reduce log noise
                    if isMatch {
                        print(buttonDetails)
                        
                        // Also print any available actions
                        if !element.actions.isEmpty {
                            print("  Actions: \(element.actions.joined(separator: ", "))")
                        }
                                   
                        // Check for exact matches in different button properties
                        if element.identifier == identifier ||
                           element.title == identifier ||
                           element.value == identifier {
                            print("FOUND EXACT MATCH")
                            return element
                        }
                        
                        // For single-character identifiers like digits, be more lenient
                        if identifier.count == 1 &&
                           (element.title?.contains(identifier) == true ||
                            element.value?.contains(identifier) == true ||
                            element.identifier.contains(identifier)) {
                            print("FOUND MATCH FOR DIGIT OR OPERATOR")
                            return element
                        }
                        
                        // Special case for operation buttons that might have different representations
                        let specialOperations = ["+", "-", "×", "÷", "=", ".", "%", "±"]
                        if specialOperations.contains(identifier) &&
                           (element.title?.contains(identifier) == true ||
                            element.value?.contains(identifier) == true ||
                            element.description.contains(identifier)) {
                            print("FOUND MATCH FOR SPECIAL OPERATION")
                            return element
                        }
                    }
                }
                
                // Recursively search children
                for child in element.children {
                    if let match = searchForButtonRecursively(in: child, depth: depth + 1) {
                        return match
                    }
                }
                
                return nil
            }
            
            // First try searching in the window hierarchy
            if let button = searchForButtonRecursively(in: window) {
                print("Found button '\(identifier)' in window hierarchy")
                return button
            }
            
            // If not found in window, try a direct app-level search that can see more elements
            print("Button '\(identifier)' not found in window hierarchy, trying app-level search")
            
            do {
                // Get the application element directly - using deep search
                print("Trying app-level search for button '\(identifier)'")
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: CalculatorApp.bundleId,
                    recursive: true,
                    maxDepth: 20 // Search much deeper to ensure we find buttons
                )
                
                // Print high-level info about the app element
                print("App element: role=\(appElement.role), children=\(appElement.children.count)")
                
                // Search through the entire app hierarchy
                if let button = searchForButtonRecursively(in: appElement) {
                    print("Found button '\(identifier)' via app-level search")
                    return button
                }
            } catch {
                print("Error in app-level search: \(error)")
            }
            
            print("Button '\(identifier)' not found after exhaustive search")
        return nil
    }
    
    /// Press a Calculator button by its identifier
    /// - Parameter identifier: The button identifier (e.g., "1", "+", "=")
    /// - Returns: True if the button was successfully pressed
    func pressButton(identifier: String) async throws -> Bool {
        // Single attempt with improved UI element discovery
        print("Attempting to press button '\(identifier)'")
        
        // Use our enhanced getButton method which already does deep searching
        guard let button = try await getButton(identifier: identifier) else {
            print("Button with identifier '\(identifier)' not found")
            return false
        }
        
        do {
            // Try to click the button
            try await interactionService.clickElement(identifier: button.identifier)
            
            // Wait longer for UI update - calculator can be slow to respond
            try await Task.sleep(for: .milliseconds(300))
            
            print("Successfully pressed button '\(identifier)'")
            return true
        } catch {
            print("Error clicking button '\(identifier)': \(error)")
            throw error
        }
    }
    
    /// Type a sequence of characters using button presses
    /// - Parameter sequence: The sequence to enter (e.g., "123+456=")
    /// - Returns: True if all buttons were successfully pressed
    func enterSequence(_ sequence: String) async throws -> Bool {
        // Clear the calculator first
        let clearSuccess = try await pressButton(identifier: CalculatorElements.clear)
        if !clearSuccess {
            return false
        }
        
        // Press each button in sequence
        for char in sequence {
            let buttonId = String(char)
            
            // Map specific characters to button identifiers if needed
            let mappedId: String
            switch char {
            case "×": mappedId = CalculatorElements.Operations.multiply
            case "÷": mappedId = CalculatorElements.Operations.divide
            case "-": mappedId = CalculatorElements.Operations.minus
            case "−": mappedId = CalculatorElements.Operations.minus
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
        print("Starting calculation: \(num1) \(operation) \(num2)")
        
        // Clear the calculator - try multiple button identifiers that might work
        print("Attempting to clear calculator")
        var clearSuccess = try await pressButton(identifier: CalculatorElements.clear)
        if !clearSuccess {
            print("Failed to clear with AC, trying alternative 'C' button")
            clearSuccess = try await pressButton(identifier: "C")
        }
        if !clearSuccess {
            print("Failed to clear with C, trying CE button")
            clearSuccess = try await pressButton(identifier: "CE")
        }
        if !clearSuccess {
            print("FAILED: Could not clear calculator with any clear button")
            return nil
        }
        
        // Enter the first number
        print("Entering first number: \(num1)")
        for digit in num1 {
            print("Pressing digit: \(digit)")
            let digitSuccess = try await pressButton(identifier: String(digit))
            if !digitSuccess {
                print("FAILED: Could not press digit \(digit)")
                return nil
            }
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
        
        print("Pressing operation: \(operationId)")
        let opSuccess = try await pressButton(identifier: operationId)
        if !opSuccess {
            print("FAILED: Could not press operation \(operationId)")
            return nil
        }
        
        // Enter the second number
        print("Entering second number: \(num2)")
        for digit in num2 {
            print("Pressing digit: \(digit)")
            let digitSuccess = try await pressButton(identifier: String(digit))
            if !digitSuccess {
                print("FAILED: Could not press digit \(digit)")
                return nil
            }
        }
        
        // Press equals
        print("Pressing equals")
        let equalsSuccess = try await pressButton(identifier: CalculatorElements.Operations.equals)
        if !equalsSuccess {
            print("FAILED: Could not press equals button")
            return nil
        }
        
        // Get the result - allow some time for UI to update
        print("Getting display value")
        try await Task.sleep(for: .milliseconds(300))
        let result = try await getDisplayValue()
        
        if result == nil {
            print("FAILED: Could not get display value")
            return nil
        }
        
        print("Calculation complete, result: \(result ?? "nil")")
        return result
    }
}