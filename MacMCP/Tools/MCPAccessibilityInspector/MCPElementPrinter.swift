// ABOUTME: Formats MCP UI element information for display in terminal
// ABOUTME: Converts MCP UI element data into human-readable representations

import Foundation
import Cocoa

/// Responsible for formatting element data into strings
class MCPElementPrinter {
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
    /// - Parameter showAllData: Whether to show all detailed data
    /// - Parameter highlightPath: Whether to highlight the element path prominently
    /// - Returns: A formatted string representation of the element
    func formatElement(_ element: MCPUIElementNode, showColor: Bool = true, showAllData: Bool = true, highlightPath: Bool = false) -> String {
        var output = ""
        
        // Create a more informative header for interactive elements
        let headerText: String
        
        // For elements that typically have meaningful descriptions (buttons, etc.)
        if element.role == "AXButton" || element.role == "AXCheckBox" || element.role == "AXMenuItem" {
            if let description = element.description, !description.isEmpty {
                // If the element has a description, show it in the header
                headerText = "[\(element.index)] \(element.role): \(description)"
            } else if let title = element.title, !title.isEmpty {
                // Fall back to title if available
                headerText = "[\(element.index)] \(element.role): \(title)"
            } else {
                // Last resort
                headerText = "[\(element.index)] \(element.role): Untitled"
            }
        } else {
            // For other elements, use the standard header format
            headerText = "[\(element.index)] \(element.role): \(element.title ?? "Untitled")"
        }
        if showColor {
            let color = MCPElementPrinter.roleColors[element.role] ?? .white
            output += "\(color.rawValue)\(headerText)\(TerminalColor.reset.rawValue)\n"
        } else {
            output += "\(headerText)\n"
        }
        
        // SECTION 1: Basic identification and geometry
        output += "   Identifier: \(element.identifier)\n"
        
        // Display the element path with highlighting if requested
        if highlightPath {
            // Prioritize showing the full path for maximum clarity
            if let fullPath = element.fullPath {
                if showColor {
                    output += "   \(TerminalColor.boldGreen.rawValue)Path: \(fullPath)\(TerminalColor.reset.rawValue)\n"
                } else {
                    output += "   Path: \(fullPath)\n"
                }
            } 
            // Otherwise generate a synthetic path if possible
            else if let syntheticPath = element.generateSyntheticPath() {
                if showColor {
                    output += "   \(TerminalColor.yellow.rawValue)Path (generated): \(syntheticPath)\(TerminalColor.reset.rawValue)\n"
                } else {
                    output += "   Path (generated): \(syntheticPath)\n"
                }
            }
            
        } else {
            // Standard path display when not highlighting - still prioritize full path
            if let fullPath = element.fullPath {
                output += "   Path: \(fullPath)\n"
            } else if let syntheticPath = element.generateSyntheticPath() {
                output += "   Path (generated): \(syntheticPath)\n"
            }
        }
        
        if let frame = element.frame {
            output += "   Frame: (x:\(Int(frame.origin.x)), y:\(Int(frame.origin.y)), w:\(Int(frame.size.width)), h:\(Int(frame.size.height)))\n"
        }
        
        if let description = element.description, !description.isEmpty {
            output += "   Description: \(description)\n"
        }
        
        // SECTION 2: State as compact boolean list
        var stateTokens = [String]()
        
        // Basic state
        stateTokens.append(element.isEnabled ? "Enabled" : "Disabled")
        stateTokens.append(element.isVisible ? "Visible" : "Invisible")
        stateTokens.append(element.isClickable ? "Clickable" : "Not clickable")
        stateTokens.append(element.focused ? "Focused" : "Unfocused")
        stateTokens.append(element.selected ? "Selected" : "Unselected")
        
        // Optional state
        if let expanded = element.expanded {
            stateTokens.append(expanded ? "Expanded" : "Collapsed")
        }
        
        if let required = element.required {
            stateTokens.append(required ? "Required" : "Optional")
        }
        
        output += "   State: " + stateTokens.joined(separator: ", ") + "\n"

        // SECTION 2.5: Capabilities from InterfaceExplorerTool
        if let capabilities = (element.attributes["capabilities"] as? [String]) ?? (element.attributes["capabilities"] as? String)?.components(separatedBy: ", "),
           !capabilities.isEmpty {
            output += "   Capabilities: " + capabilities.joined(separator: ", ") + "\n"
        }

        // SECTION 3: Role details
        output += "   Role: \(element.role)"
        if let roleDescription = element.roleDescription {
            output += " (\(roleDescription))"
        }
        output += "\n"

        if let subrole = element.subrole {
            output += "   Subrole: \(subrole)\n"
        }
        
        // SECTION 4: Content/value information
        if let value = element.value {
            let valueString = formatValue(value)
            if !valueString.isEmpty {
                output += "   Value: \(valueString)\n"
            }
        }
        
        if let valueDescription = element.valueDescription, !valueDescription.isEmpty {
            output += "   Value Description: \(valueDescription)\n"
        }
        
        // SECTION 5: Relationships as compact list
        var relationshipTokens = [String]()
        relationshipTokens.append("Children: \(element.childrenCount)")
        if element.hasParent {
            relationshipTokens.append("Has Parent")
        }
        if element.attributes["AXWindow"] != nil {
            relationshipTokens.append("Has Window")
        }
        
        output += "   Relationships: " + relationshipTokens.joined(separator: ", ") + "\n"
        
        // SECTION 6: Actions
        if !element.actions.isEmpty {
            output += "   Actions: \(element.actions.joined(separator: ", "))\n"
        }
        
        // SECTION 7: All raw attributes (excluding already displayed ones)
        // Create a set of attribute keys to exclude (since they're shown above)
        let excludedAttributes = Set([
            "AXRole", "AXRoleDescription", "AXSubrole", 
            "AXTitle", "AXDescription", "AXValue", "AXValueDescription",
            "AXHelp", "AXLabel", "AXPlaceholderValue",  
            "AXEnabled", "AXFocused", "AXSelected", "AXExpanded", "AXRequired",
            "AXParent", "AXWindow", "AXTopLevelUIElement", "AXChildren",
            "AXPosition", "AXSize", "AXFrame", "AXIdentifier",
            // Additional commonly redundant attributes
            "application", // Remove application attribute which is added to all elements
            "enabled", // Already shown in state section
            "focused", // Already shown in state section
            "selected", // Already shown in state section
            "clickable", // Already shown in state section
            "visible", // Already shown in state section
            "path" // Already shown in path section
        ])
        
        // Filter attributes to find non-excluded ones
        let filteredAttributes = element.attributes.filter { key, value in
            !excludedAttributes.contains(key) && formatValue(value).isEmpty == false
        }
        
        // Only show the section if there are attributes to display
        if !filteredAttributes.isEmpty {
            output += "\n   Additional Attributes:\n"
            
            // Display the remaining attributes in sorted order
            for key in filteredAttributes.keys.sorted() {
                if let value = filteredAttributes[key] {
                    let valueString = formatValue(value)
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
