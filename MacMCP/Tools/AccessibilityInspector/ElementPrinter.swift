// ABOUTME: Formats UI element information for display in various formats
// ABOUTME: Converts raw UI element data into human-readable representations

import Foundation
import Cocoa

/// Responsible for formatting element data into strings
class ElementPrinter {
    /// ANSI color codes for terminal output
    private enum TerminalColor: String {
        case reset = "\u{001B}[0m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case blue = "\u{001B}[34m"
        case magenta = "\u{001B}[35m"
        case cyan = "\u{001B}[36m"
        case white = "\u{001B}[37m"
        case boldWhite = "\u{001B}[1;37m"
        case boldGreen = "\u{001B}[1;32m"
        case boldBlue = "\u{001B}[1;34m"
    }
    
    /// Maps element roles to terminal colors
    private static let roleColors: [String: TerminalColor] = [
        "AXApplication": .boldGreen,
        "AXWindow": .boldBlue,
        "AXButton": .green,
        "AXCheckBox": .green,
        "AXRadioButton": .green,
        "AXMenuItem": .cyan,
        "AXMenu": .cyan,
        "AXMenuBar": .cyan,
        "AXTextField": .yellow,
        "AXTextArea": .yellow,
        "AXGroup": .magenta,
        "AXImage": .white,
        "AXList": .blue,
        "AXTable": .blue
    ]
    
    /// Formats a UI element for display
    /// - Parameter element: The element to format
    /// - Parameter showColor: Whether to use color in the output
    /// - Returns: A formatted string representation of the element
    func formatElement(_ element: UIElementNode, showColor: Bool = true, showAllData: Bool = false) -> String {
        var output = ""
        
        // Add header with node index and role
        let headerText = "[\(element.index)] \(element.role): \(element.title ?? "Untitled")"
        if showColor {
            let color = ElementPrinter.roleColors[element.role] ?? .white
            output += "\(color.rawValue)\(headerText)\(TerminalColor.reset.rawValue)\n"
        } else {
            output += "\(headerText)\n"
        }
        
        // Add standard properties
        if let title = element.title {
            output += "   Title: \(title)\n"
        }
        
        if let identifier = element.identifier {
            output += "   Identifier: \(identifier)\n"
        }
        
        if let frame = element.frame {
            output += "   Frame: (x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.size.width)), h:\(Int(frame.size.height)))\n"
        }
        
        output += "   Role: \(element.role)\n"
        
        if let roleDescription = element.role_description {
            output += "   Role Description: \(roleDescription)\n"
        }
        
        if let subrole = element.subrole {
            output += "   Subrole: \(subrole)\n"
        }
        
        if let description = element.description, !description.isEmpty {
            output += "   Description: \(description)\n"
        }
        
        if let help = element.help, !help.isEmpty {
            output += "   Help: \(help)\n"
        }
        
        // Add value information
        if let value = element.value {
            let valueString = formatValue(value)
            if !valueString.isEmpty {
                output += "   Value: \(valueString)\n"
            }
        }
        
        if let valueDescription = element.valueDescription, !valueDescription.isEmpty {
            output += "   Value Description: \(valueDescription)\n"
        }
        
        if let placeholder = element.placeholder, !placeholder.isEmpty {
            output += "   Placeholder: \(placeholder)\n"
        }
        
        if let label = element.label, !label.isEmpty {
            output += "   Label: \(label)\n"
        }
        
        // Add state information
        output += "   Enabled: \(element.isEnabled ? "Yes" : "No")\n"
        output += "   Visible: \(element.isVisible ? "Yes" : "No")\n"
        
        if element.isClickable {
            output += "   Clickable: Yes\n"
        }
        
        output += "   Focused: \(element.focused ? "Yes" : "No")\n"
        output += "   Selected: \(element.selected ? "Yes" : "No")\n"
        
        if let expanded = element.expanded {
            output += "   Expanded: \(expanded ? "Yes" : "No")\n"
        }
        
        if let required = element.required {
            output += "   Required: \(required ? "Yes" : "No")\n"
        }
        
        // Add relationship information
        output += "   Children Count: \(element.childrenCount)\n"
        
        if element.hasParent {
            output += "   Has Parent: Yes\n"
        }
        
        if element.hasWindow {
            output += "   Has Window: Yes\n"
        }
        
        if element.hasTopLevelUIElement {
            output += "   Has Top Level UI Element: Yes\n"
        }
        
        // Add actions if available
        if !element.actions.isEmpty {
            output += "   Actions: \(element.actions.joined(separator: ", "))\n"
        }
        
        // Add parameterized attributes if available and requested
        if showAllData && !element.parameterizedAttributes.isEmpty {
            output += "   Parameterized Attributes: \(element.parameterizedAttributes.joined(separator: ", "))\n"
        }
        
        // Add all attributes if requested
        if showAllData {
            output += "\n   All Attributes:\n"
            let sortedKeys = element.attributes.keys.sorted()
            
            for key in sortedKeys {
                if let value = element.attributes[key] {
                    let valueString = formatValue(value)
                    if !valueString.isEmpty {
                        output += "      \(key): \(valueString)\n"
                    }
                }
            }
        }
        
        return output
    }
    
    /// Formats a detailed view of an element including all attributes
    /// - Parameter element: The element to format
    /// - Returns: A detailed string representation of the element
    func formatDetailedElement(_ element: UIElementNode) -> String {
        var output = formatElement(element)
        
        // Add all attributes
        output += "\n   Attributes:\n"
        let sortedKeys = element.attributes.keys.sorted()
        
        for key in sortedKeys {
            if let value = element.attributes[key] {
                let valueString = formatValue(value)
                if !valueString.isEmpty {
                    output += "      \(key): \(valueString)\n"
                }
            }
        }
        
        return output
    }
    
    /// Formats a value for display, handling different types appropriately
    /// - Parameter value: The value to format
    /// - Returns: A string representation of the value
    private func formatValue(_ value: Any) -> String {
        switch value {
        case let stringValue as String:
            return stringValue
        case let numberValue as NSNumber:
            return numberValue.stringValue
        case let arrayValue as [Any]:
            if arrayValue.isEmpty {
                return "[]"
            } else {
                return "[Array with \(arrayValue.count) elements]"
            }
        case let pointValue as NSValue where String(cString: pointValue.objCType) == "{CGPoint=dd}":
            var point = CGPoint.zero
            pointValue.getValue(&point)
            return "(\(Int(point.x)), \(Int(point.y)))"
        case let sizeValue as NSValue where String(cString: sizeValue.objCType) == "{CGSize=dd}":
            var size = CGSize.zero
            sizeValue.getValue(&size)
            return "(\(Int(size.width))×\(Int(size.height)))"
        case let rectValue as NSValue where String(cString: rectValue.objCType) == "{CGRect={CGPoint=dd}{CGSize=dd}}":
            var rect = CGRect.zero
            rectValue.getValue(&rect)
            return "(x:\(Int(rect.origin.x)), y:\(Int(rect.origin.y)), w:\(Int(rect.size.width)), h:\(Int(rect.size.height)))"
        case let boolValue as Bool:
            return boolValue ? "Yes" : "No"
        case is AXUIElement:
            return "[Element reference]"
        case let dictValue as [String: Any]:
            if dictValue.isEmpty {
                return "{}"
            } else {
                return "{Dictionary with \(dictValue.count) entries}"
            }
        case let urlValue as URL:
            return urlValue.absoluteString
        case let dateValue as Date:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: dateValue)
        case let colorValue as NSColor:
            return "Color(r:\(Int(colorValue.redComponent * 255)), g:\(Int(colorValue.greenComponent * 255)), b:\(Int(colorValue.blueComponent * 255)))"
        case let error as NSError:
            return "Error: \(error.localizedDescription)"
        case let unknown:
            return "[Type: \(type(of: unknown))]"
        }
    }
}