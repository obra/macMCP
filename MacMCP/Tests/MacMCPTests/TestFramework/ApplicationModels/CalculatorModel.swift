// ABOUTME: This file defines the Calculator application model for tests.
// ABOUTME: It provides Calculator-specific interaction methods for test scenarios.

import Foundation
@testable import MacMCP

/// Model for the macOS Calculator application
public class CalculatorModel: BaseApplicationModel {
    /// Button identifiers on the macOS Calculator
    public enum Button {
        /// Digit buttons (0-9)
        public static let zero = "0"
        public static let one = "1"
        public static let two = "2"
        public static let three = "3"
        public static let four = "4"
        public static let five = "5"
        public static let six = "6"
        public static let seven = "7"
        public static let eight = "8"
        public static let nine = "9"
        
        /// Operation buttons
        public static let plus = "+"
        public static let minus = "-"
        public static let multiply = "×"
        public static let divide = "÷"
        public static let equals = "="
        public static let decimal = "."
        public static let percent = "%"
        public static let sign = "±"
        
        /// Control buttons
        public static let clear = "C"
        public static let allClear = "AC"
        public static let delete = "Delete"
        
        /// Button mappings for modern macOS calculator
        public static let buttonMappings: [String: String] = [
            "0": "ui:Zero:",
            "1": "ui:One:",
            "2": "ui:Two:",
            "3": "ui:Three:",
            "4": "ui:Four:",
            "5": "ui:Five:",
            "6": "ui:Six:",
            "7": "ui:Seven:",
            "8": "ui:Eight:",
            "9": "ui:Nine:",
            "+": "ui:Add:",
            "-": "ui:Subtract:",
            "×": "ui:Multiply:",
            "÷": "ui:Divide:",
            "=": "ui:Equals:",
            ".": "ui:Decimal:",
            "%": "ui:Percent:",
            "±": "ui:Negate:",
            "C": "ui:Clear:",
            "AC": "ui:AllClear:",
            "Delete": "ui:Delete:"
        ]
    }
    
    /// Create a new Calculator model
    /// - Parameter toolChain: ToolChain instance for interacting with the calculator
    public init(toolChain: ToolChain) {
        super.init(
            bundleId: "com.apple.calculator",
            appName: "Calculator",
            toolChain: toolChain
        )
    }
    
    /// Find the display element in the Calculator
    /// - Returns: The display element, or nil if not found
    public func getDisplayElement() async throws -> UIElement? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Try to find a StaticText element that contains the display value
        let displayCriteria = UIElementCriteria(role: "AXStaticText")
        
        // Search all elements in the window to find the display
        let elements = try await toolChain.findElements(
            matching: displayCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 15
        )
        
        // Sort elements by vertical position - display is typically at the top
        let sortedElements = elements.sorted { $0.frame.origin.y < $1.frame.origin.y }
        
        // Take the top element that has a value or title
        for element in sortedElements {
            if element.value != nil || element.title != nil {
                return element
            }
        }
        
        return nil
    }
    
    /// Get the current value shown in the Calculator display
    /// - Returns: The display value as a string, or nil if not found
    public func getDisplayValue() async throws -> String? {
        guard let displayElement = try await getDisplayElement() else {
            return nil
        }
        
        // Get the raw value
        if let value = displayElement.value {
            return String(describing: value)
        }
        
        // Fallback to title if value is not available
        if let title = displayElement.title {
            return title
        }
        
        return nil
    }
    
    /// Find a Calculator button element
    /// - Parameter button: The button identifier
    /// - Returns: The button element, or nil if not found
    public func findButton(_ button: String) async throws -> UIElement? {
        // Check if we have a mapping for this button
        let buttonPattern = Button.buttonMappings[button]
        
        // Try multiple strategies to find the button
        
        // Strategy 1: Look for a button with matching identifier pattern
        if let pattern = buttonPattern {
            let criteria = UIElementCriteria(
                role: "AXButton",
                identifierContains: pattern
            )
            
            if let element = try await toolChain.findElement(
                matching: criteria,
                scope: "application",
                bundleId: bundleId,
                maxDepth: 15
            ) {
                return element
            }
        }
        
        // Strategy 2: Look for a button with matching title
        let titleCriteria = UIElementCriteria(
            role: "AXButton",
            title: button
        )
        
        if let element = try await toolChain.findElement(
            matching: titleCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 15
        ) {
            return element
        }
        
        // Strategy 3: Look for a button with matching description
        let descriptionCriteria = UIElementCriteria(
            role: "AXButton",
            description: button
        )
        
        if let element = try await toolChain.findElement(
            matching: descriptionCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 15
        ) {
            return element
        }
        
        // Strategy 4: Look for a button with matching value
        let valueCriteria = UIElementCriteria(
            role: "AXButton",
            value: button
        )
        
        if let element = try await toolChain.findElement(
            matching: valueCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 15
        ) {
            return element
        }
        
        // Return nil if button not found
        return nil
    }
    
    /// Press a Calculator button using the default interaction method (AXPress)
    /// - Parameter button: The button identifier
    /// - Returns: True if the button was successfully pressed
    public func pressButton(_ button: String) async throws -> Bool {
        // For clear buttons, try to use the escape key as a fallback if needed
        if (button == "Delete" || button == "C" || button == "AC") && 
           (try? await findButton(button)) == nil {
            return try await toolChain.pressKey(keyCode: 53) // Escape key
        }
        
        // Use the accessibility-based interaction by default
        return try await pressButtonViaAccessibility(button)
    }
    
    /// Clear the calculator
    /// - Returns: True if the calculator was successfully cleared
    public func clear() async throws -> Bool {
        // Try multiple clear buttons in order
        let clearButtons = ["Delete", "AC", "C", "Clear", "AllClear"]
        
        for button in clearButtons {
            do {
                if try await pressButton(button) {
                    return true
                }
            } catch {
                // Try the next button
                continue
            }
        }
        
        // If all clear buttons fail, try using the escape key
        return try await toolChain.pressKey(keyCode: 53) // Escape key
    }
    
    /// Enter a sequence of characters using button presses
    /// - Parameter sequence: The sequence to enter (e.g., "123+456=")
    /// - Returns: True if all buttons were successfully pressed
    public func enterSequence(_ sequence: String) async throws -> Bool {
        // Press each button in the sequence
        for char in sequence {
            let buttonId = String(char)
            
            // Map special characters if needed
            let mappedId: String
            switch char {
            case '×': mappedId = Button.multiply
            case '÷': mappedId = Button.divide
            case '-': mappedId = Button.minus
            case '−': mappedId = Button.minus
            default: mappedId = buttonId
            }
            
            if !(try await pressButton(mappedId)) {
                return false
            }
            
            // Brief pause between button presses
            try await Task.sleep(for: .milliseconds(100))
        }
        
        return true
    }
    
    /// Press a button using the AXPress action through accessibility APIs
    /// - Parameter button: The button identifier
    /// - Returns: True if the button was successfully pressed
    public func pressButtonViaAccessibility(_ button: String) async throws -> Bool {
        // Find the button element
        guard let buttonElement = try await findButton(button) else {
            throw NSError(
                domain: "CalculatorModel",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Button not found: \(button)"]
            )
        }
        
        // Use the UIInteractionTool with elementId to click via accessibility
        let params: [String: Value] = [
            "action": .string("click"),
            "elementId": .string(buttonElement.identifier)
        ]
        
        let result = try await toolChain.uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("clicked") || text.contains("true")
        }
        
        return false
    }
    
    /// Click a button using mouse coordinates
    /// - Parameter button: The button identifier
    /// - Returns: True if the button was successfully clicked
    public func clickButtonWithMouse(_ button: String) async throws -> Bool {
        // Find the button element
        guard let buttonElement = try await findButton(button) else {
            throw NSError(
                domain: "CalculatorModel",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Button not found: \(button)"]
            )
        }
        
        // Calculate the center point of the button
        let centerX = buttonElement.frame.origin.x + buttonElement.frame.size.width / 2
        let centerY = buttonElement.frame.origin.y + buttonElement.frame.size.height / 2
        let position = CGPoint(x: centerX, y: centerY)
        
        // Use the UIInteractionTool with coordinates to click via mouse
        let params: [String: Value] = [
            "action": .string("click"),
            "x": .double(Double(position.x)),
            "y": .double(Double(position.y))
        ]
        
        let result = try await toolChain.uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("clicked") || text.contains("true")
        }
        
        return false
    }
    
    /// Type a digit using keyboard input
    /// - Parameter digit: The digit to type
    /// - Returns: True if the key was successfully pressed
    public func typeDigit(_ digit: String) async throws -> Bool {
        guard digit.count == 1, let char = digit.first, char.isNumber else {
            throw NSError(
                domain: "CalculatorModel",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Invalid digit: \(digit)"]
            )
        }
        
        // Map digit to key code
        let keyCodes = [
            "0": 29, // 0 key
            "1": 18, // 1 key
            "2": 19, // 2 key
            "3": 20, // 3 key
            "4": 21, // 4 key
            "5": 23, // 5 key
            "6": 22, // 6 key
            "7": 26, // 7 key
            "8": 28, // 8 key
            "9": 25  // 9 key
        ]
        
        guard let keyCode = keyCodes[digit] else {
            throw NSError(
                domain: "CalculatorModel",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Unknown key code for digit: \(digit)"]
            )
        }
        
        // Use the pressKey method to type the digit
        return try await toolChain.pressKey(keyCode: keyCode)
    }
    
    /// Type an operator key using keyboard input
    /// - Parameter operator: The operator to type (+, -, *, /)
    /// - Returns: True if the key was successfully pressed
    public func typeOperator(_ operator: String) async throws -> Bool {
        // Map operator to key code
        let keyCodes = [
            "+": 24, // + key
            "-": 27, // - key
            "*": 28, // * key
            "/": 75, // / key
            "=": 36  // Return key for equals
        ]
        
        guard let keyCode = keyCodes[`operator`] else {
            throw NSError(
                domain: "CalculatorModel",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Unknown key code for operator: \(`operator`)"]
            )
        }
        
        // Use the pressKey method to type the operator
        return try await toolChain.pressKey(keyCode: keyCode)
    }
}