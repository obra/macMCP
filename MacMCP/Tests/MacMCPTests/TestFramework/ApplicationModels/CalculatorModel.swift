// ABOUTME: This file defines the Calculator application model for tests.
// ABOUTME: It provides Calculator-specific interaction methods for test scenarios.

import Foundation
@testable import MacMCP
import MCP

/// Model for the macOS Calculator application
public final class CalculatorModel: BaseApplicationModel, @unchecked Sendable {
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
        
        /// Button mappings for modern macOS calculator with exact IDs from MCP
        public static let buttonMappings: [String: String] = [
            "0": "ui:Zero:2e0def8cf4c33a08",
            "1": "ui:One:3de92c2b7df0c0b4",
            "2": "ui:Two:534b00223948a4e9",
            "3": "ui:Three:11bdb56adc9bf20f",
            "4": "ui:Four:e6f538ed5493cf2e",
            "5": "ui:Five:a4a5059f35e656e3",
            "6": "ui:Six:93d83f5e3f2288b6",
            "7": "ui:Seven:8d037607e8f8f393",
            "8": "ui:Eight:f67917dc5cd76a6c",
            "9": "ui:Nine:a5e0cf02072aed2b",
            "+": "ui:Add:9c49141ad15f89b9",
            "-": "ui:Subtract:f5d95b1955041e8e",
            "×": "ui:Multiply:e7d6b0f1c262c7c6",
            "÷": "ui:Divide:a9eaa67eb21185e7",
            "=": "ui:Equals:f2f76903bdbf8d78",
            ".": "ui:Decimal:5662db8ae93a96c6",
            "%": "ui:Percent:ab04fd1e8d536769",
            "±": "ui:Negate:0ecb4655434a67f4",
            "C": "ui:Clear:8c80c300c6c3093e",
            "AC": "ui:AllClear:8c80c300c6c3093e",
            "Delete": "ui:AllClear:8c80c300c6c3093e"
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
        guard try await getMainWindow() != nil else {
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
    
    /// Find a Calculator button element using exact MCP element identifiers
    /// - Parameter button: The button identifier
    /// - Returns: The button element, or nil if not found
    public func findButton(_ button: String) async throws -> UIElement? {
        // Get the exact id mapping for this button
        guard let exactId = Button.buttonMappings[button] else {
            print("No mapping found for button: \(button)")
            return nil
        }
        
        print("Looking for calculator button: \(button) with ID: \(exactId)")
        
        // Use the exact element ID to find the button via UIInteractionService
        let uiCriteria = UIElementCriteria(
            role: "AXButton",
            identifier: exactId  // Use exact ID match
        )
        
        // First try direct exact match
        if let element = try await toolChain.findElement(
            matching: uiCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 25
        ) {
            print("Found button by exact ID match: \(exactId)")
            return element
        }
        
        // If not found, try to search more broadly
        let buttonElements = try await toolChain.findElements(
            matching: UIElementCriteria(role: "AXButton"),
            scope: "application",
            bundleId: bundleId,
            maxDepth: 25
        )
        
        print("Found \(buttonElements.count) total buttons in Calculator")
        
        // Log button information for debugging
        for (index, element) in buttonElements.prefix(5).enumerated() {
            print("Button sample \(index): id=\(element.identifier), desc=\(element.elementDescription ?? "nil")")
        }
        
        // Try matching by partial identifier
        let partialId = exactId.split(separator: ":")[1]
        let partialCriteria = UIElementCriteria(
            role: "AXButton",
            identifierContains: String(partialId)
        )
        
        if let element = try await toolChain.findElement(
            matching: partialCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 25
        ) {
            print("Found button by partial ID match: \(partialId)")
            return element
        }
        
        // Fallback to description match based on the button string
        let descCriteria = UIElementCriteria(
            role: "AXButton",
            description: button
        )
        
        if let element = try await toolChain.findElement(
            matching: descCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 25
        ) {
            print("Found button by description match: \(button)")
            return element
        }
        
        // Try one more method: check all buttons manually
        for element in buttonElements {
            // Check exact ID
            if element.identifier == exactId {
                print("Found button via manual search with exact ID: \(exactId)")
                return element
            }
            
            // Check descriptive part match
            if element.identifier.contains(partialId) {
                print("Found button via manual search with partial ID: \(partialId)")
                return element
            }
            
            // Check description match
            if let description = element.elementDescription, description == button {
                print("Found button via manual search with description: \(button)")
                return element
            }
        }
        
        print("Button not found: \(button)")
        return nil
    }
    
    /// Find the Calculator keypad view container
    /// - Returns: The keypad view element, or nil if not found
    private func findCalculatorKeypadView() async throws -> UIElement? {
        // Look for the group with identifier "CalculatorKeypadView"
        let criteria = UIElementCriteria(
            role: "AXGroup",
            identifierContains: "CalculatorKeypadView"
        )
        
        return try await toolChain.findElement(
            matching: criteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        )
    }
    
    /// Press a Calculator button using the default interaction method (AXPress)
    /// - Parameter button: The button identifier
    /// - Returns: True if the button was successfully pressed
    public func pressButton(_ button: String) async throws -> Bool {
        // For clear buttons, try to use the escape key as a fallback
        if button == "Delete" || button == "C" || button == "AC" {
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
            case "×": mappedId = Button.multiply
            case "÷": mappedId = Button.divide
            case "-": mappedId = Button.minus
            case "−": mappedId = Button.minus
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
        print("🔍 DEBUG: pressButtonViaAccessibility: Trying to press \(button)")
        
        // Get the exact ID mapping for this button directly from our map
        let exactId: String
        if let mappedId = Button.buttonMappings[button] {
            print("✅ DEBUG: pressButtonViaAccessibility: Using direct ID mapping for button \(button): \(mappedId)")
            exactId = mappedId
        } else {
            // If button doesn't have a mapped ID, try to find it via UI
            print("⚠️ DEBUG: pressButtonViaAccessibility: No direct ID mapping found for button \(button), attempting to find it")
            guard let buttonElement = try await findButton(button) else {
                print("❌ DEBUG: pressButtonViaAccessibility: Failed to find button \(button)")
                throw NSError(
                    domain: "CalculatorModel",
                    code: 1000,
                    userInfo: [NSLocalizedDescriptionKey: "Button not found: \(button)"]
                )
            }
            
            print("✅ DEBUG: pressButtonViaAccessibility: Found button via UI search with ID: \(buttonElement.identifier)")
            exactId = buttonElement.identifier
            
            // Log detailed information about the button
            print("   - Identifier: \(buttonElement.identifier)")
            print("   - Role: \(buttonElement.role)")
            print("   - Title: \(buttonElement.title ?? "nil")")
            print("   - Description: \(buttonElement.elementDescription ?? "nil")")
            print("   - Frame: (\(buttonElement.frame.origin.x), \(buttonElement.frame.origin.y), \(buttonElement.frame.size.width), \(buttonElement.frame.size.height))")
            print("   - Clickable: \(buttonElement.isClickable)")
            print("   - Enabled: \(buttonElement.isEnabled)")
            print("   - Visible: \(buttonElement.isVisible)")
            print("   - Actions: \(buttonElement.actions.joined(separator: ", "))")
        }
        
        // Use the UIInteractionTool with elementId to click via accessibility
        print("🖱️ DEBUG: pressButtonViaAccessibility: Attempting to click with elementId: \(exactId)")
        let params: [String: Value] = [
            "action": .string("click"),
            "elementId": .string(exactId),
            "appBundleId": .string(bundleId) // Add the bundle ID to help with targeting
        ]
        
        do {
            let result = try await toolChain.uiInteractionTool.handler(params)
            
            // Log the result
            if let content = result.first, case .text(let text) = content {
                print("📝 DEBUG: pressButtonViaAccessibility: Result: \(text)")
                // Check for success message in the result
                return text.contains("success") || text.contains("clicked") || text.contains("true")
            }
            
            print("⚠️ DEBUG: pressButtonViaAccessibility: No result content returned")
            return false
            
        } catch {
            print("❌ DEBUG: pressButtonViaAccessibility: Error during click operation: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   - Error domain: \(nsError.domain)")
            print("   - Error code: \(nsError.code)")
            print("   - Error info: \(nsError.userInfo)")
            throw error
        }
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
        guard digit.count == 1, let char = digit.first, ("0"..."9").contains(String(char)) else {
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
