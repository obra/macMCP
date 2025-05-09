// ABOUTME: This file defines the Calculator application model for tests.
// ABOUTME: It provides Calculator-specific interaction methods for test scenarios.

import Foundation
import AppKit
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
            "Delete": "ui:Delete:65de4e64bffd4335"
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
    
    /// Override to provide more robust window detection for Calculator
    /// - Returns: The main Calculator window, or nil if not found
    override public func getMainWindow() async throws -> UIElement? {
        print("🔍 DEBUG: CalculatorModel.getMainWindow - Looking for main Calculator window")
        
        // Try the parent implementation first
        if let parentResult = try await super.getMainWindow() {
            print("✅ DEBUG: CalculatorModel.getMainWindow - Found window via parent implementation")
            return parentResult
        }
        
        // If not found, try other approaches
        print("   - Standard window detection failed, trying alternate approaches")
        
        // Approach 1: Try to find any element with window role
        let windowCriteria = UIElementCriteria(role: "AXWindow")
        if let windowElement = try? await toolChain.findElement(
            matching: windowCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        ) {
            print("✅ DEBUG: CalculatorModel.getMainWindow - Found window via direct role search")
            return windowElement
        }
        
        // Approach 2: Get the application element and assume it's the main container
        let appElement = try await toolChain.accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: false  // Don't get children
        )
        
        print("ℹ️ DEBUG: CalculatorModel.getMainWindow - Using application element as proxy for window")
        return appElement
    }
    
    /// Find the display element in the Calculator
    /// - Returns: The display element, or nil if not found
    public func getDisplayElement() async throws -> UIElement? {
        print("🔍 DEBUG: getDisplayElement - Trying to find calculator display")
        
        // Get the main window first for reference
        let mainWindow = try await getMainWindow()
        if mainWindow == nil {
            print("❌ DEBUG: getDisplayElement - Failed to get main window")
            return nil
        }
        
        print("✅ DEBUG: getDisplayElement - Found main window")
        
        // Try to find the static text element with ID from direct inspection
        let staticTextId = "ui:AXStaticText:6eeecdfeaaf1c80a"
        let directCriteria = UIElementCriteria(identifier: staticTextId)
        
        if let element = try await toolChain.findElement(
            matching: directCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        ) {
            print("✅ DEBUG: getDisplayElement - Found static text by direct ID")
            return element
        } else {
            print("❌ DEBUG: getDisplayElement - Failed to get text by direct ID");
	}
        
        // Look for the scroll area with description "Input"
        let scrollAreaCriteria = UIElementCriteria(
            role: "AXScrollArea",
            description: "Input"
        )
        
        if let scrollArea = try await toolChain.findElement(
            matching: scrollAreaCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 20 
        ) {
            print("✅ DEBUG: getDisplayElement - Found scroll area with description 'Input'")
            
            // Return the first child if available
            if !scrollArea.children.isEmpty {
                return scrollArea.children.first
            }
            
            // Otherwise return the scroll area itself
            return scrollArea
        } else {
        
        	print("❌ DEBUG: getDisplayElement - Failed to find any display element")
        	return nil
	}
    }
    
    /// Get the current value shown in the Calculator display
    /// - Returns: The display value as a string, or nil if not found
    public func getDisplayValue() async throws -> String? {
        print("🔍 DEBUG: getDisplayValue - Trying to read calculator display")


        // First, do a broader search to see all scroll areas
        let allScrollAreas = try await toolChain.findElements(
            matching: UIElementCriteria(role: "AXScrollArea"),
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        )

        print("📊 DEBUG: getDisplayValue - Found \(allScrollAreas.count) total scroll areas")
        for (i, area) in allScrollAreas.enumerated() {
            print("   - ScrollArea #\(i): id=\(area.identifier), desc=\(area.elementDescription ?? "nil")")
        }

        // Now try the specific criteria
        let scrollAreaCriteria = UIElementCriteria(
            role: "AXScrollArea",
            description: "Input"
        )

        if let scrollArea = try await toolChain.findElement(
            matching: scrollAreaCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 15
        ) {
            print("✅ DEBUG: getDisplayValue - Found AXScrollArea with description 'Input'")
            print("   - ScrollArea ID: \(scrollArea.identifier)")
            print("   - Children count: \(scrollArea.children.count)")

            // Check for child elements (the static text element containing the actual value)
            if !scrollArea.children.isEmpty {
                for (i, child) in scrollArea.children.enumerated() {
                    print("   - Child #\(i): role=\(child.role), id=\(child.identifier)")
                    print("   - Child #\(i) value: \(child.value ?? "nil")")
                    print("   - Child #\(i) title: \(child.title ?? "nil")")
                    print("   - Child #\(i) description: \(child.elementDescription ?? "nil")")

                    if let value = child.value {
                        let stringValue = String(describing: value)
                        print("✅ DEBUG: getDisplayValue - Found value in child: \(stringValue)")

                        // Clean up the string - remove invisible characters and whitespace
                        let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                                  .replacingOccurrences(of: "‎", with: "") // Remove invisible character

                        return cleanValue
                    }
                }
            }

            // Even if we don't find a value in the children, try getting the value from the scroll area itself
            if let areaValue = scrollArea.value {
                let stringValue = String(describing: areaValue)
                print("✅ DEBUG: getDisplayValue - Found value in scroll area itself: \(stringValue)")

                // Clean up the string - remove invisible characters and whitespace
                let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                          .replacingOccurrences(of: "‎", with: "") // Remove invisible character

                return cleanValue
            }
        }

        print("❌ DEBUG: getDisplayValue - Failed to find any display value")
        return nil
    }

    /// Helper method to recursively search for display values in the UI hierarchy
    /// - Parameter element: The UI element to search
    /// - Returns: The display value if found, nil otherwise
    private func findDisplayValueInElement(_ element: UIElement) -> String? {
        // Check if this element has a value and is a static text element
        if element.role == "AXStaticText", let value = element.value {
            let stringValue = String(describing: value)

            // Clean up the string - remove invisible characters and whitespace
            let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                      .replacingOccurrences(of: "‎", with: "") // Remove invisible character

            // Validate that it looks like a number (optional)
            if !cleanValue.isEmpty && (Double(cleanValue) != nil || cleanValue == "0") {
                return cleanValue
            }
        }

        // Recursively check children
        for child in element.children {
            if let value = findDisplayValueInElement(child) {
                return value
            }
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
        
        // First try to find all buttons to get a quick sense of what's available
        let buttonElements = try await toolChain.findElements(
            matching: UIElementCriteria(role: "AXButton"),
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        )
        
        print("Found \(buttonElements.count) total buttons in Calculator")
        
        // APPROACH 1: Try direct description match (most reliable in practice)
        // This works because Calculator buttons consistently have descriptions like "1", "2", "+", etc.
        let descCriteria = UIElementCriteria(
            role: "AXButton",
            description: button
        )
        
        if let element = try await toolChain.findElement(
            matching: descCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        ) {
            print("✅ DEBUG: findButton - Found button by description match: \(button)")
            return element
        }
        
        // APPROACH 2: Try exact ID match
        let idCriteria = UIElementCriteria(
            role: "AXButton",
            identifier: exactId
        )
        
        if let element = try await toolChain.findElement(
            matching: idCriteria,
            scope: "application",
            bundleId: bundleId,
            maxDepth: 10
        ) {
            print("✅ DEBUG: findButton - Found button by exact ID match: \(exactId)")
            return element
        }
        
        // APPROACH 3: Try to find by partial ID match
        if exactId.contains(":") {
            let parts = exactId.split(separator: ":")
            if parts.count > 1 {
                let partialId = String(parts[1])
                let partialCriteria = UIElementCriteria(
                    role: "AXButton",
                    identifierContains: partialId
                )
                
                if let element = try await toolChain.findElement(
                    matching: partialCriteria,
                    scope: "application",
                    bundleId: bundleId,
                    maxDepth: 10
                ) {
                    print("✅ DEBUG: findButton - Found button by partial ID match: \(partialId)")
                    return element
                }
            }
        }
        
        // APPROACH 4: Manual search through all buttons
        print("🔍 DEBUG: findButton - Trying manual search through all buttons")
        
        for element in buttonElements {
            // Check button description (most reliable for Calculator)
            if let description = element.elementDescription, description == button {
                print("✅ DEBUG: findButton - Found button via manual description match: \(button)")
                return element
            }
            
            // Check exact ID match
            if element.identifier == exactId {
                print("✅ DEBUG: findButton - Found button via manual exact ID match")
                return element
            }
            
            // Check for the button name/value in any property
            if let title = element.title, title == button {
                print("✅ DEBUG: findButton - Found button via title match: \(button)")
                return element
            }
            
            if let value = element.value, String(describing: value) == button {
                print("✅ DEBUG: findButton - Found button via value match: \(button)")
                return element
            }
        }
        
        print("❌ DEBUG: findButton - Button not found: \(button)")
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
        let result = try await toolChain.pressKey(keyCode: 53) // Escape key
        return result
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
        
        // Use the direct approach for clicking rather than the handler
        // This is more reliable and bypasses any potential parameter handling issues
        print("🖱️ DEBUG: pressButtonViaAccessibility: Using direct click method for element: \(exactId)")
        
        do {
            // Use toolChain.interactionService.clickElement directly
            try await toolChain.interactionService.clickElement(
                identifier: exactId,
                appBundleId: bundleId
            )
            
            print("✅ DEBUG: pressButtonViaAccessibility: Direct click operation succeeded")
            
            // Give the UI time to update after the click
            try await Task.sleep(for: .milliseconds(300))
            
            return true
        } catch {
            print("❌ DEBUG: pressButtonViaAccessibility: Error during click operation: \(error.localizedDescription)")
            let nsError = error as NSError
            print("   - Error domain: \(nsError.domain)")
            print("   - Error code: \(nsError.code)")
            print("   - Error info: \(nsError.userInfo)")
            
            // Fallback to the handler approach if the direct approach fails
            print("⚠️ DEBUG: pressButtonViaAccessibility: Trying fallback with UIInteractionTool.handler")
            
            // Create the parameters with explicit values for safety
            let params: [String: Value] = [
                "action": .string("click"),
                "elementId": .string(exactId),
                "appBundleId": .string(bundleId)
            ]
            
            // Verify params object isn't empty before calling
            if params.isEmpty || params.count < 3 {
                print("❌ DEBUG: pressButtonViaAccessibility: ERROR - Invalid params object")
                return false
            }
            
            do {
                print("🔄 DEBUG: pressButtonViaAccessibility: Sending parameters to handler: \(params)")
                let result = try await toolChain.uiInteractionTool.handler(params)
                
                // Log the result
                if let content = result.first, case .text(let text) = content {
                    print("📝 DEBUG: pressButtonViaAccessibility: Result: \(text)")
                    // Check for success message in the result
                    return text.contains("success") || text.contains("clicked") || text.contains("true")
                } else if !result.isEmpty {
                    print("⚠️ DEBUG: pressButtonViaAccessibility: Got result but no text content: \(result)")
                    return true // Assume success if we got any result
                }
                
                print("⚠️ DEBUG: pressButtonViaAccessibility: No result content returned")
                return false
            } catch {
                print("❌ DEBUG: pressButtonViaAccessibility: Fallback also failed: \(error.localizedDescription)")
                return false
            }
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
    
    /// Override the terminate method to ensure calculator is properly closed
    /// - Returns: True if the application was successfully terminated
    override public func terminate() async throws -> Bool {
        print("🔍 DEBUG: terminate - Terminating calculator application")
        
        // First try to use the applicationService to terminate the application
        let appTerminated = try await super.terminate()
        
        // If that didn't work, try direct approach with force termination
        if !appTerminated {
            print("⚠️ DEBUG: terminate - Normal termination failed, using direct NSRunningApplication approach")
            
            // Terminate any existing calculator instances - use force if needed
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).forEach { app in
                if !app.terminate() {
                    print("⚠️ DEBUG: terminate - Normal termination failed, forcing termination")
                    _ = app.forceTerminate()
                }
            }
            
            // Give the system time to fully close the app
            try await Task.sleep(for: .milliseconds(1000))
            
            // Verify termination was successful
            let stillRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
            if stillRunning {
                print("❌ DEBUG: terminate - Failed to terminate calculator after multiple attempts")
                // One last desperate attempt with force termination
                NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).forEach { app in
                    _ = app.forceTerminate()
                }
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        
        // Check if the app is still running
        let success = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
        print("\(success ? "✅" : "❌") DEBUG: terminate - Calculator termination \(success ? "succeeded" : "failed")")
        return success
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
