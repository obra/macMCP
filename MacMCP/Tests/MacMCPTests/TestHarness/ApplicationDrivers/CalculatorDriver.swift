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
        static let allClear = "AllClear"
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
        
        // Find all ScrollAreas that might contain the display
        var displayElement: UIElement?
        var scrollAreas: [UIElement] = []
        
        // Function to gather all ScrollAreas which might contain the display
        func findScrollAreas(in element: UIElement, depth: Int = 0) {
            if element.role == "AXScrollArea" {
                scrollAreas.append(element)
            }
            
            // Also check for any StaticText that might be the display
            if element.role == "AXStaticText" && element.value != nil {
                // If the value can be converted to a number, this is likely the display
                let valueStr = String(describing: element.value!)
                if let _ = Double(valueStr.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)) {
                    displayElement = element
                }
            }
            
            // Continue searching children
            for child in element.children {
                findScrollAreas(in: child, depth: depth + 1)
            }
        }
        
        // Start the search
        findScrollAreas(in: window)
        
        // If we already found a display element with a numeric value, return it
        if let display = displayElement, let value = display.value {
            let strValue = String(describing: value)
            
            // Clean up any non-numeric characters
            let cleanValue = strValue.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
            return cleanValue.isEmpty ? strValue : cleanValue
        }
        
        // If we found ScrollAreas, check them for StaticText children
        if !scrollAreas.isEmpty {
            
            // Sort ScrollAreas by position - display is typically at the top
            let sortedAreas = scrollAreas.sorted { $0.frame.origin.y < $1.frame.origin.y }
            
            // If we found exactly two ScrollAreas, the second one is typically the result display
            if sortedAreas.count >= 2 {
                let resultArea = sortedAreas[1]
                
                // Check for StaticText child in the result area
                for child in resultArea.children {
                    if child.role == "AXStaticText", let value = child.value {
                        let strValue = String(describing: value)
                        
                        // Clean up any non-numeric characters
                        let cleanValue = strValue.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
                        return cleanValue.isEmpty ? strValue : cleanValue
                    }
                }
            }
            
            // If no result in the second area or only one area, check all areas
            for area in sortedAreas {
                for child in area.children {
                    if child.role == "AXStaticText", let value = child.value {
                        let strValue = String(describing: value)
                        
                        // Clean up any non-numeric characters
                        let cleanValue = strValue.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
                        return cleanValue.isEmpty ? strValue : cleanValue
                    }
                }
            }
        }
        
        // Fallback: Find any StaticText element with a value
        func findStaticText(in element: UIElement) -> UIElement? {
            if element.role == "AXStaticText" && element.value != nil {
                return element
            }
            
            for child in element.children {
                if let found = findStaticText(in: child) {
                    return found
                }
            }
            
            return nil
        }
        
        if let staticText = findStaticText(in: window), let value = staticText.value {
            let strValue = String(describing: value)
            
            // Clean up any non-numeric characters
            let cleanValue = strValue.replacingOccurrences(of: "[^0-9.-]", with: "", options: .regularExpression)
            return cleanValue.isEmpty ? strValue : cleanValue
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
            if element.role == "AXButton" {                
                // Various matching strategies
                var matches = [String: Bool]()
                
                // 1. Title match
                matches["title"] = element.title == button
                
                // 2. Description match (useful for Calculator buttons)
                matches["description"] = element.elementDescription == button
                
                // 3. Component match for format "ui:Component:hash"
                let components = element.identifier.split(separator: ":")
                let isUiComponent = components.count >= 2 && components[0] == "ui"
                matches["component"] = isUiComponent && components.count >= 2 && String(components[1]) == button
                
                // 4. Description contains match for numeric buttons
                matches["descriptionContains"] = element.elementDescription?.contains(button) == true
                
                // An element matches if ANY of these conditions are true
                if matches.values.contains(true) {
                    return element
                }
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
        
        // Add a small delay before interacting with the button
        
        // Add a small delay to ensure UI is ready
        try await Task.sleep(for: .milliseconds(500))
        
        // Click the button - pass the bundle ID to help with element location
        try await interactionService.clickElement(identifier: element.identifier, appBundleId: bundleIdentifier)
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
        let _ = try await pressButton(Button.allClear)
        
        // Enter first number
        for digit in num1 {
            let _ = try await pressButton(String(digit))
        }
        
        // Press operation
        let _ = try await pressButton(operation)
        
        // Enter second number
        for digit in num2 {
            let _ = try await pressButton(String(digit))
        }
        
        // Press equals
        let _ = try await pressButton(Button.equals)
        
        // Get result
        return try await getDisplayValue()
    }
}
