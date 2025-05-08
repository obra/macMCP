// ABOUTME: This file defines UI element identifiers for the macOS Calculator app.
// ABOUTME: It contains the element IDs needed to interact with Calculator in tests.

import Foundation
import AppKit
@testable import MacMCP

/// Constants representing UI element identifiers in the macOS Calculator app
enum CalculatorElements {
    /// Represents the main Calculator display element
    static let display = "Display"
    
    /// Represents the clear button (All Clear/C)
    static let clear = "AllClear"
    
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

/// Element map for Calculator buttons and display
struct CalculatorElementMap {
    // Display element
    let display = CalculatorElements.display
    
    // Clear button
    let clearButton = CalculatorElements.clear
    
    // Digit buttons
    let zeroButton = CalculatorElements.Digits.zero
    let oneButton = CalculatorElements.Digits.one
    let twoButton = CalculatorElements.Digits.two
    let threeButton = CalculatorElements.Digits.three
    let fourButton = CalculatorElements.Digits.four
    let fiveButton = CalculatorElements.Digits.five
    let sixButton = CalculatorElements.Digits.six
    let sevenButton = CalculatorElements.Digits.seven
    let eightButton = CalculatorElements.Digits.eight
    let nineButton = CalculatorElements.Digits.nine
    
    // Operation buttons
    let plusButton = CalculatorElements.Operations.plus
    let minusButton = CalculatorElements.Operations.minus
    let multiplyButton = CalculatorElements.Operations.multiply
    let divideButton = CalculatorElements.Operations.divide
    let equalsButton = CalculatorElements.Operations.equals
    let decimalButton = CalculatorElements.Operations.decimal
    let percentButton = CalculatorElements.Operations.percent
    let signButton = CalculatorElements.Operations.sign
}

/// Extensions to the CalculatorApp class for interacting with specific elements
extension CalculatorApp {
    /// Element map for Calculator buttons and display
    var elementMap: CalculatorElementMap {
        return CalculatorElementMap()
    }
    
    /// Get the display element of the Calculator
    /// - Returns: The UI element representing the display, or nil if not found
    func getDisplayElement() async throws -> UIElement? {
        print("Searching for calculator display element")
        
        guard let window = try await getMainWindow() else {
            print("Could not get main window to find display")
            return nil
        }
        
        // First try a direct search in the window's children
        for child in window.children {
            if child.identifier.contains(CalculatorElements.display) ||
               (child.role == "AXStaticText" && child.frame.origin.y < 100) {
                print("Found display element directly in window children")
                return child
            }
        }
        
        // Based on observed path: /AXApplication/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXGroup/AXScrollArea/AXStaticText
        // We need to specifically look for this structure
        print("Starting targeted search for display element...")
        
        func findDisplayRecursively(in element: UIElement, depth: Int = 0, path: String = "root") -> UIElement? {
            // Look specifically for AXStaticText elements that might be the display
            if element.role == "AXStaticText" {
                // If it has a numeric value, this is very likely to be the display
                if let value = element.value {
                    print("Found StaticText at \(path) with value: \(value)")
                    
                    // Try to convert the value to a number
                    let valueString = String(describing: value)
                    if let _ = Double(valueString) {
                        print("✅✅ FOUND NUMERIC DISPLAY in StaticText: \(valueString)")
                        return element
                    }
                }
                
                // Check if it's positioned at the top of the UI (calculator display is typically at the top)
                if element.frame.origin.y < 200 {
                    print("✅ Found StaticText positioned at top of UI - likely the display")
                    return element
                }
            }
            
            // Check ScrollArea elements specifically
            if element.role == "AXScrollArea" {
                print("Found ScrollArea at depth \(depth): \(path), children: \(element.children.count)")
                
                // Check direct value of ScrollArea itself
                if let areaValue = element.value {
                    print("ScrollArea value: \(areaValue)")
                    let valueStr = String(describing: areaValue)
                    if let _ = Double(valueStr) {
                        print("✅✅ ScrollArea ITSELF has numeric value: \(valueStr)")
                        return element
                    }
                }
                
                // Position-based check - calculator display is typically at the top of the UI
                let isTopPositioned = element.frame.origin.y < 200
                if isTopPositioned {
                    print("This ScrollArea is positioned at the top of the UI")
                    
                    // Check for an immediately available direct numeric value
                    if let value = element.value {
                        let stringValue = String(describing: value)
                        if let _ = Double(stringValue) {
                            print("✅✅ Top-positioned ScrollArea has numeric value: \(stringValue)")
                            return element
                        }
                    }
                }
                
                // First check for any StaticText children
                for child in element.children {
                    if child.role == "AXStaticText" {
                        print("✅ Found StaticText in ScrollArea")
                        if let value = child.value {
                            print("  StaticText value: \(value)")
                            // Try to convert to number
                            let stringValue = String(describing: value)
                            if let _ = Double(stringValue) {
                                print("✅✅ FOUND NUMERIC DISPLAY in StaticText: \(stringValue)")
                                return child
                            }
                        }
                        
                        // Position-based heuristic - return StaticText at the top of the UI
                        if isTopPositioned {
                            print("✅ Returning top-positioned StaticText as display")
                            return child
                        }
                    }
                    
                    // Recursively check each child's children as well
                    for grandchild in child.children {
                        if grandchild.role == "AXStaticText" {
                            print("✅ Found StaticText grandchild in ScrollArea")
                            if let value = grandchild.value {
                                print("  StaticText grandchild value: \(value)")
                                // Try to convert to number
                                let stringValue = String(describing: value)
                                if let _ = Double(stringValue) {
                                    print("✅✅ FOUND NUMERIC DISPLAY in grandchild StaticText: \(stringValue)")
                                    return grandchild
                                }
                            }
                            
                            // Position-based heuristic for grandchildren too
                            if isTopPositioned {
                                print("✅ Returning top-positioned StaticText grandchild as display")
                                return grandchild
                            }
                        }
                    }
                }
                
                // If we found a ScrollArea positioned at the top, return it even without children
                if isTopPositioned {
                    print("Returning top-positioned ScrollArea as display (no children found)")
                    return element
                }
            }
            
            // Special case for direct number value in any element
            if let value = element.value {
                let stringValue = String(describing: value)
                if let _ = Double(stringValue) {
                    print("✅✅ FOUND NUMERIC VALUE in \(element.role): \(stringValue)")
                    return element
                }
            }
            
            // Special case for title attribute with number (some apps store the display value here)
            if let title = element.title {
                if let _ = Double(title) {
                    print("✅✅ FOUND NUMERIC TITLE in \(element.role): \(title)")
                    return element
                }
            }
            
            // Search all children
            for (i, child) in element.children.enumerated() {
                let childPath = "\(path)/\(i):\(child.role)"
                if let display = findDisplayRecursively(in: child, depth: depth + 1, path: childPath) {
                    return display
                }
            }
            
            return nil
        }
        
        // Attempt to search for and return the calculation result ScrollArea
        // For Calculator, the result is typically in the second ScrollArea
        var foundScrollAreas: [UIElement] = []
        
        // Find all ScrollAreas in the window that might contain the display
        func findScrollAreasWithText(in element: UIElement, depth: Int = 0, path: String = "root") {
            if element.role == "AXScrollArea" && element.children.count > 0 {
                // Check if this ScrollArea contains StaticText
                for child in element.children {
                    if child.role == "AXStaticText" && child.value != nil {
                        print("Found ScrollArea with StaticText at \(path)")
                        foundScrollAreas.append(element)
                        break
                    }
                }
            }
            
            // Search all children
            for (i, child) in element.children.enumerated() {
                let childPath = "\(path)/\(i):\(child.role)"
                findScrollAreasWithText(in: child, depth: depth + 1, path: childPath)
            }
        }
        
        // Search for ScrollAreas with StaticText
        findScrollAreasWithText(in: window)
        
        print("Found \(foundScrollAreas.count) ScrollAreas with StaticText")
        
        // If we have exactly two ScrollAreas, the second one is likely the result display
        if foundScrollAreas.count == 2 {
            // Get the second ScrollArea (which typically contains the result)
            let resultArea = foundScrollAreas[1]
            
            // Make sure it has a StaticText child
            for child in resultArea.children {
                if child.role == "AXStaticText" {
                    print("FOUND RESULT DISPLAY ELEMENT (second ScrollArea)")
                    return child
                }
            }
            
            // If no StaticText child, return the ScrollArea itself
            return resultArea
        }
        // If we only have one ScrollArea, it's the only option
        else if foundScrollAreas.count == 1 {
            // Get the only ScrollArea
            let area = foundScrollAreas[0]
            
            // Make sure it has a StaticText child
            for child in area.children {
                if child.role == "AXStaticText" {
                    print("FOUND DISPLAY ELEMENT (only ScrollArea)")
                    return child
                }
            }
            
            // If no StaticText child, return the ScrollArea itself
            return area
        }
        // If we have more than two ScrollAreas, look for one with a numeric value
        else if foundScrollAreas.count > 2 {
            // Sort ScrollAreas by vertical position (calculator display is typically at the top)
            let sortedAreas = foundScrollAreas.sorted { $0.frame.origin.y < $1.frame.origin.y }
            
            // Check each area for a StaticText child with a numeric value
            for area in sortedAreas {
                for child in area.children {
                    if child.role == "AXStaticText" {
                        let valueString = String(describing: child.value ?? "")
                        
                        // Try to extract numeric characters from the value
                        let numericOnly = valueString.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                        if !numericOnly.isEmpty {
                            print("FOUND NUMERIC DISPLAY ELEMENT")
                            return child
                        }
                    }
                }
            }
            
            // If no numeric values found, return the first area
            if !sortedAreas.isEmpty {
                print("No numeric values found, using first ScrollArea")
                return sortedAreas[0]
            }
        }
        
        // Try regular recursive search as fallback
        if let displayElement = findDisplayRecursively(in: window) {
            print("Found display element via window traversal")
            return displayElement
        }
        
        // Full application search as last resort fallback
        print("Trying application-level search for display element...")
        do {
            let appElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: CalculatorApp.bundleId,
                recursive: true,
                maxDepth: 30
            )
            
            // Find all ScrollAreas in the app element
            foundScrollAreas = []
            findScrollAreasWithText(in: appElement)
            
            if !foundScrollAreas.isEmpty {
                let sortedAreas = foundScrollAreas.sorted { $0.frame.origin.y < $1.frame.origin.y }
                
                // Prefer the second area if there are two or more (result display)
                if sortedAreas.count >= 2 {
                    // Check for StaticText child in the second area
                    for child in sortedAreas[1].children {
                        if child.role == "AXStaticText" {
                            print("FOUND RESULT DISPLAY ELEMENT (app-level, second ScrollArea)")
                            return child
                        }
                    }
                    return sortedAreas[1]
                }
                // Otherwise use the first area
                else if sortedAreas.count == 1 {
                    // Check for StaticText child
                    for child in sortedAreas[0].children {
                        if child.role == "AXStaticText" {
                            print("FOUND DISPLAY ELEMENT (app-level, only ScrollArea)")
                            return child
                        }
                    }
                    return sortedAreas[0]
                }
            }
            
            // Last resort: Use the first StaticText element with any value
            func findAnyStaticText(in element: UIElement) -> UIElement? {
                if element.role == "AXStaticText" && element.value != nil {
                    return element
                }
                
                for child in element.children {
                    if let found = findAnyStaticText(in: child) {
                        return found
                    }
                }
                
                return nil
            }
            
            if let anyText = findAnyStaticText(in: appElement) {
                print("LAST RESORT: Found any StaticText with value")
                return anyText
            }
            
        } catch {
            print("Error searching for display at application level: \(error)")
        }
        
        print("Failed to find calculator display element")
        return nil
    }
    
    /// Get the current value shown in the Calculator display
    /// - Returns: The display value as a string, or nil if not found
    func getDisplayValue() async throws -> String? {
        guard let displayElement = try await getDisplayElement() else {
            print("Could not get display element")
            return nil
        }
        
        // Get the raw value
        let rawValue = displayElement.value
        print("Found display element with value: \(rawValue ?? "nil")")
        
        // If we have a value, try to clean it up and extract the numeric part
        if let value = rawValue {
            // Convert to string if it's not already
            let valueStr = String(describing: value)
            
            // Try to extract numeric portion using a regular expression
            // Handle values with symbols like ‎2‎+‎2 or ‎4
            let cleanedStr = valueStr.trimmingCharacters(in: .whitespacesAndNewlines)
            print("Cleaned value: \(cleanedStr)")
            
            // If the string appears to be a calculation expression (e.g., "2+2"),
            // we need to look further for the result. Let's look for a second display element.
            if cleanedStr.contains("+") || cleanedStr.contains("-") || 
               cleanedStr.contains("×") || cleanedStr.contains("÷") {
                print("Found expression in display, looking for result...")
                
                // Try to find a result by looking for a second display element
                do {
                    if let window = try await getMainWindow() {
                        // Function to find any numeric display element that's not the expression
                        func findResultDisplay(in element: UIElement, expressionValue: String) -> UIElement? {
                            // Check if this element has a numeric value and it's not the expression
                            if let elementValue = element.value {
                                let valueString = String(describing: elementValue)
                                if valueString != expressionValue && (Double(valueString) != nil || valueString.contains("‎")) {
                                    print("✅✅ FOUND RESULT DISPLAY: \(valueString)")
                                    return element
                                }
                            }
                            
                            // Check all children
                            for child in element.children {
                                if let result = findResultDisplay(in: child, expressionValue: cleanedStr) {
                                    return result
                                }
                            }
                            
                            return nil
                        }
                        
                        // Try to find the result display
                        if let resultElement = findResultDisplay(in: window, expressionValue: cleanedStr) {
                            let resultValue = resultElement.value
                            print("Found result display with value: \(resultValue ?? "nil")")
                            
                            // Clean up the result value
                            if let value = resultValue {
                                let resultStr = String(describing: value)
                                // Remove any non-digit characters except for decimal point and minus sign
                                let cleanedResult = resultStr.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
                                print("Returning cleaned result: \(cleanedResult)")
                                if !cleanedResult.isEmpty {
                                    return cleanedResult
                                }
                                return resultStr
                            }
                        } else {
                            print("Could not find separate result display")
                        }
                    }
                } catch {
                    print("Error searching for result display: \(error)")
                }
            }
            
            // For results or single values, clean up by removing non-numeric characters
            // Remove any non-digit characters except for decimal point and minus sign
            let numericValue = cleanedStr.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
            print("Extracted numeric value: \(numericValue)")
            
            if !numericValue.isEmpty {
                return numericValue
            }
            
            // Return the cleaned string if we couldn't extract a numeric value
            return cleanedStr
        }
        
        return nil
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
                
                // EARLY RETURN: Check for direct identifier matches first
                // This is the most reliable way to find buttons
                if element.role == "AXButton" {
                    // For digit buttons, check the built-in patterns
                    let digitPatterns = [
                        "0": "ui:Zero:",
                        "1": "ui:One:",
                        "2": "ui:Two:",
                        "3": "ui:Three:",
                        "4": "ui:Four:",
                        "5": "ui:Five:",
                        "6": "ui:Six:",
                        "7": "ui:Seven:",
                        "8": "ui:Eight:",
                        "9": "ui:Nine:"
                    ]
                    
                    // Operation patterns
                    let operationPatterns = [
                        "+": "ui:Add:",
                        "-": "ui:Subtract:",
                        "×": "ui:Multiply:",
                        "÷": "ui:Divide:",
                        "=": "ui:Equals:",
                        ".": "ui:Decimal:",
                        "%": "ui:Percent:",
                        "±": "ui:Negate:"
                    ]
                    
                    // Clear button patterns
                    let clearPatterns = ["ui:Delete:", "ui:AllClear:", "ui:Clear:"]
                    
                    // Special case for clear buttons
                    if identifier == "Delete" || identifier == "AllClear" || identifier == "C" || identifier == "AC" || identifier == "Clear" {
                        for pattern in clearPatterns {
                            if element.identifier.hasPrefix(pattern) {
                                print("\(indent)MATCHED SPECIAL CLEAR BUTTON: \(element.identifier)")
                                return element
                            }
                        }
                    }
                    
                    // Check for digit pattern matches
                    if let pattern = digitPatterns[identifier], element.identifier.hasPrefix(pattern) {
                        print("\(indent)MATCHED DIGIT BUTTON: \(element.identifier)")
                        return element
                    }
                    
                    // Check for operation pattern matches
                    if let pattern = operationPatterns[identifier], element.identifier.hasPrefix(pattern) {
                        print("\(indent)MATCHED OPERATION BUTTON: \(element.identifier)")
                        return element
                    }
                }
                
                // Print every button regardless of depth
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
                   
                    // ID component match (extract the second component from ui:Component:hash format)
                    let components = element.identifier.split(separator: ":")
                    let hasIdComponentMatch = components.count >= 2 && String(components[1]) == identifier
                    
                    // Print all button info to help with debugging
                    let isMatch = hasIdComponentMatch ||
                                  element.identifier.contains(identifier) ||
                                  element.title?.contains(identifier) == true ||
                                  element.value?.contains(identifier) == true ||
                                  element.elementDescription?.contains(identifier) == true ||
                                  element.description.contains(identifier)
                    
                    let prefix = isMatch ? "POTENTIAL MATCH: " : ""
                    let buttonDetails = "\(prefix)Button: role=\(element.role), id=\(element.identifier), " +
                                       "title=\(element.title ?? "nil"), " +
                                       "value=\(element.value ?? "nil"), " +
                                       "description=\(element.description), " +
                                       "elementDescription=\(element.elementDescription ?? "nil")"
                    
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
                           element.value == identifier ||
                           element.elementDescription == identifier {
                            print("FOUND EXACT MATCH")
                            return element
                        }
                        
                        // Special case for the clear button
                        if (identifier == "Delete" || identifier == "AllClear" || identifier == "C" || identifier == "AC") {
                            // Check if this is a clear button by component name
                            let components = element.identifier.split(separator: ":")
                            if components.count >= 2 {
                                let componentName = String(components[1])
                                if componentName == "Delete" || componentName == "AllClear" || componentName == "Clear" {
                                    print("FOUND CLEAR BUTTON WITH COMPONENT: \(componentName)")
                                    return element
                                }
                            }
                            
                            // Also check by description
                            if element.elementDescription?.contains("Clear") == true ||
                               element.elementDescription?.contains("Delete") == true {
                                print("FOUND CLEAR BUTTON BY DESCRIPTION")
                                return element
                            }
                        }
                        
                        // For special identifiers (like AllClear, Clear), match on component ID or description
                        if identifier.count > 1 {
                            // Extract second component from identifier (format: ui:AllClear:hash)
                            let components = element.identifier.split(separator: ":")
                            let hasComponentMatch = components.count >= 2 && String(components[1]) == identifier
                            
                            let hasDescriptionMatch = element.elementDescription?.contains(identifier) == true ||
                                                     identifier.contains(element.elementDescription ?? "")
                            
                            if hasComponentMatch || hasDescriptionMatch {
                                print("FOUND MATCH BY DESCRIPTION OR IDENTIFIER COMPONENT")
                                return element
                            }
                        }
                        
                        // For single-character identifiers like digits, be more specific
                        if identifier.count == 1 {
                            // Map digit identifiers to their proper calculator button identifiers
                            let digitNames = [
                                "0": "Zero",
                                "1": "One",
                                "2": "Two",
                                "3": "Three",
                                "4": "Four",
                                "5": "Five", 
                                "6": "Six",
                                "7": "Seven",
                                "8": "Eight",
                                "9": "Nine"
                            ]
                            
                            // Only use AXButton elements for digits, not AXMenuButton
                            if element.role == "AXButton" {
                                // Primary strategy: Check for ui:DigitName component pattern (e.g., ui:Five:hash for "5")
                                if let digitName = digitNames[identifier] {
                                    let components = element.identifier.split(separator: ":")
                                    if components.count >= 2 && String(components[1]) == digitName {
                                        print("FOUND DIGIT BUTTON BY NAME: \(digitName)")
                                        return element
                                    }
                                }
                                
                                // Secondary strategy: Match by description
                                if element.elementDescription == identifier {
                                    print("FOUND DIGIT BUTTON BY EXACT DESCRIPTION")
                                    return element
                                }
                            }
                        }
                        
                        // Special case for operation buttons that might have different representations
                        let operationNames = [
                            "+": "Add",
                            "-": "Subtract",
                            "×": "Multiply",
                            "÷": "Divide",
                            "=": "Equals",
                            ".": "Decimal",
                            "%": "Percent",
                            "±": "Negate"
                        ]
                        
                        // First try to match by operation name in UI identifier
                        if let operationName = operationNames[identifier] {
                            let components = element.identifier.split(separator: ":")
                            if components.count >= 2 && String(components[1]) == operationName {
                                print("FOUND MATCH FOR OPERATION BY NAME: \(operationName)")
                                return element
                            }
                        }
                        
                        // Fallback for operations by other attributes
                        let specialOperations = ["+", "-", "×", "÷", "=", ".", "%", "±"]
                        if specialOperations.contains(identifier) &&
                           (element.title?.contains(identifier) == true ||
                            element.value?.contains(identifier) == true ||
                            element.elementDescription?.contains(identifier) == true ||
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
        
        // To clear the calculator fully, we need to use Delete multiple times or find AllClear
        print("Clearing calculator display...")
        
        // First try "Delete" which may need multiple presses to clear everything
        print("Trying 'Delete' button...")
        let deleteSuccess = try await pressButton(identifier: "Delete")
        
        // If we found Delete, press it multiple times to clear everything
        if deleteSuccess {
            print("Delete button found. Pressing multiple times to clear display...")
            
            // Press Delete multiple times to ensure calculator is clear
            // This is safer than trying to read the display and check if it's empty
            for _ in 0..<10 {
                _ = try await pressButton(identifier: "Delete")
                // Short pause between button presses
                try await Task.sleep(for: .milliseconds(100))
            }
            
            print("Calculator should be clear now after multiple Delete presses")
        } else {
            // Try AllClear button which clears everything in one press
            print("Delete button not found, trying 'AllClear'...")
            let clearSuccess = try await pressButton(identifier: "AllClear")
            
            // Last resort - try other clear button variants
            if !clearSuccess {
                print("Trying alternative clear buttons...")
                let clearAlternatives = ["C", "AC", "CE", "Clear"]
                var foundClear = false
                
                for clearId in clearAlternatives {
                    let success = try await pressButton(identifier: clearId)
                    if success {
                        print("Found clear button with identifier: \(clearId)")
                        foundClear = true
                        break
                    }
                }
                
                if !foundClear {
                    print("FAILED: Could not clear calculator with any clear button")
                    return nil
                }
            }
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
