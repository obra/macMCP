// ABOUTME: This file provides a simplified CalculatorModel used for mocked tests.
// ABOUTME: It includes just enough functionality to test tools in isolation.

import Foundation
import CoreGraphics
import MCP
@testable import MacMCP

/// Simplified CalculatorModel for unit tests with mocks
public final class CalculatorModel {
    /// Bundle ID for Calculator app
    public let bundleId = "com.apple.calculator"
    
    /// ToolChain instance
    public let toolChain: ToolChain
    
    /// Window ID for Calculator window
    public var windowId: String?
    
    /// Track if the app is running
    private var _isRunning = false
    
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
        
        /// Button mappings for modern macOS calculator with path-based identifiers
        public static let buttonMappings: [String: String] = [
            "0": "ui://AXButton[@AXDescription=\"0\"]",
            "1": "ui://AXButton[@AXDescription=\"1\"]",
            "2": "ui://AXButton[@AXDescription=\"2\"]",
            "3": "ui://AXButton[@AXDescription=\"3\"]",
            "4": "ui://AXButton[@AXDescription=\"4\"]",
            "5": "ui://AXButton[@AXDescription=\"5\"]",
            "6": "ui://AXButton[@AXDescription=\"6\"]",
            "7": "ui://AXButton[@AXDescription=\"7\"]",
            "8": "ui://AXButton[@AXDescription=\"8\"]",
            "9": "ui://AXButton[@AXDescription=\"9\"]",
            "+": "ui://AXButton[@AXDescription=\"+\"]",
            "-": "ui://AXButton[@AXDescription=\"-\"]",
            "×": "ui://AXButton[@AXDescription=\"×\"]",
            "÷": "ui://AXButton[@AXDescription=\"÷\"]",
            "=": "ui://AXButton[@AXDescription=\"=\"]",
            ".": "ui://AXButton[@AXDescription=\".\"]",
            "%": "ui://AXButton[@AXDescription=\"%\"]",
            "±": "ui://AXButton[@AXDescription=\"±\"]",
            "C": "ui://AXButton[@AXDescription=\"C\"]",
            "AC": "ui://AXButton[@AXDescription=\"AC\"]",
            "Delete": "ui://AXButton[@AXDescription=\"Delete\"]"
        ]
    }
    
    /// Initialize with a tool chain
    public init(toolChain: ToolChain) {
        self.toolChain = toolChain
    }
    
    /// Mock launch method
    public func launch() async throws -> Bool {
        _isRunning = true
        return true
    }
    
    /// Mock isRunning method
    public func isRunning() async throws -> Bool {
        return _isRunning
    }
    
    /// Mock terminate method
    public func terminate() async throws -> Bool {
        _isRunning = false
        return true
    }
    
    /// Mock clear method
    public func clear() async throws -> Bool {
        return true
    }
    
    /// Mock press button method
    public func pressButton(_ button: String) async throws -> Bool {
        return true
    }
    
    /// Mock press button via accessibility
    public func pressButtonViaAccessibility(_ button: String) async throws -> Bool {
        return true
    }
    
    /// Mock click button with mouse method
    public func clickButtonWithMouse(_ button: String) async throws -> Bool {
        return true
    }
    
    /// Mock get main window method
    public func getMainWindow() async throws -> UIElement? {
        return createMockCalculatorWindow()
    }
    
    /// Mock get display element method
    public func getDisplayElement() async throws -> UIElement? {
        return createMockDisplayElement()
    }
    
    /// Mock get display value method
    public func getDisplayValue() async throws -> String? {
        return "0"
    }
    
    /// Mock find button method
    public func findButton(_ button: String) async throws -> UIElement? {
        return createMockButtonElement(button)
    }
    
    /// Mock enter sequence method
    public func enterSequence(_ sequence: String) async throws -> Bool {
        return true
    }
    
    /// Mock type digit method
    public func typeDigit(_ digit: String) async throws -> Bool {
        return true
    }
    
    /// Mock type operator method
    public func typeOperator(_ operator: String) async throws -> Bool {
        return true
    }
    
    /// Mock type text method
    public func typeText(_ text: String) async throws -> Bool {
        return true
    }
    
    /// Mock execute key sequence method
    public func executeKeySequence(_ sequence: [[String: Value]]) async throws -> Bool {
        return true
    }
    
    // MARK: - Helper Methods
    
    private func createMockCalculatorWindow() -> UIElement {
        return UIElement(
            path: "ui://AXWindow[@AXTitle=\"Calculator\"]",
            role: "AXWindow",
            title: "Calculator",
            frame: CGRect(x: 0, y: 0, width: 300, height: 400),
            frameSource: .direct,
            attributes: ["enabled": true, "visible": true],
            actions: []
        )
    }
    
    private func createMockDisplayElement() -> UIElement {
        return UIElement(
            path: "ui://AXStaticText[@AXTitle=\"Display\"]",
            role: "AXStaticText",
            title: "Display",
            value: "0",
            frame: CGRect(x: 10, y: 10, width: 280, height: 50),
            frameSource: .direct,
            attributes: ["enabled": true, "visible": true],
            actions: []
        )
    }
    
    private func createMockButtonElement(_ button: String) -> UIElement {
        let path = Button.buttonMappings[button] ?? "ui://AXButton[@AXDescription=\"button\"]"
        return UIElement(
            path: path,
            role: "AXButton",
            title: button,
            elementDescription: button,
            frame: CGRect(x: 50, y: 100, width: 40, height: 40),
            frameSource: .direct,
            attributes: ["enabled": true, "visible": true],
            actions: ["AXPress"]
        )
    }
}