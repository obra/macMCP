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
            identifier: "calculator_window",
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
            identifier: "ui:AXStaticText:6eeecdfeaaf1c80a",
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
        let buttonId = Button.buttonMappings[button] ?? "ui:button"
        return UIElement(
            identifier: buttonId,
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