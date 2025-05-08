// ABOUTME: Provides different output format options for the Accessibility Inspector
// ABOUTME: Supports various output formats including plain text, JSON, and XML

import Foundation

/// Protocol for output formatters
protocol OutputFormatter {
    /// Convert a UI element tree to a specific output format
    /// - Parameters:
    ///   - rootElement: The root element to format
    ///   - withFilters: Optional filters to apply
    /// - Returns: A formatted string
    func format(_ rootElement: UIElementNode, withFilters: [String: String]) -> String
}

/// Plain text formatter using the TreeVisualizer
class PlainTextFormatter: OutputFormatter {
    private let treeVisualizer: TreeVisualizer
    
    init(showColor: Bool = true, showDetails: Bool = false) {
        var options = TreeVisualizer.Options()
        options.showColor = showColor
        options.showDetails = showDetails
        self.treeVisualizer = TreeVisualizer(options: options)
    }
    
    func format(_ rootElement: UIElementNode, withFilters: [String: String]) -> String {
        return treeVisualizer.visualize(rootElement, withFilters: withFilters)
    }
}

/// JSON formatter
class JSONFormatter: OutputFormatter {
    func format(_ rootElement: UIElementNode, withFilters: [String: String]) -> String {
        // Convert to JSON
        let jsonObject = convertElementToJSON(rootElement, withFilters: withFilters)
        
        // Serialize to string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            return "Error serializing to JSON: \(error.localizedDescription)"
        }
        
        return "{}" // Default empty object if serialization fails
    }
    
    /// Converts a UI element to a JSON-compatible dictionary
    private func convertElementToJSON(_ element: UIElementNode, withFilters: [String: String]) -> [String: Any] {
        var result: [String: Any] = [
            "index": element.index,
            "role": element.role
        ]
        
        // Add basic properties if available
        if let title = element.title {
            result["title"] = title
        }
        
        if let identifier = element.identifier {
            result["identifier"] = identifier
        }
        
        if let description = element.description {
            result["description"] = description
        }
        
        if let frame = element.frame {
            result["frame"] = [
                "x": Int(frame.origin.x),
                "y": Int(frame.origin.y),
                "width": Int(frame.size.width),
                "height": Int(frame.size.height)
            ]
        }
        
        // Add actions
        result["actions"] = element.actions
        
        // Add computed properties
        result["enabled"] = element.isEnabled
        result["clickable"] = element.isClickable
        
        // Add value if it's a simple type
        if let value = element.value {
            if let stringValue = value as? String {
                result["value"] = stringValue
            } else if let numberValue = value as? NSNumber {
                result["value"] = numberValue
            } else if let boolValue = value as? Bool {
                result["value"] = boolValue
            }
        }
        
        // Add attributes dictionary (only for JSON-compatible values)
        var attributes: [String: Any] = [:]
        for (key, value) in element.attributes {
            if let stringValue = value as? String {
                attributes[key] = stringValue
            } else if let numberValue = value as? NSNumber {
                attributes[key] = numberValue
            } else if let boolValue = value as? Bool {
                attributes[key] = boolValue
            } else if let arrayValue = value as? [Any], isJSONCompatible(arrayValue) {
                attributes[key] = arrayValue
            } else if let dictValue = value as? [String: Any], isJSONCompatible(dictValue) {
                attributes[key] = dictValue
            }
        }
        result["attributes"] = attributes
        
        // Add children
        let filteredChildren = filterElements(element.children, withFilters: withFilters)
        result["children"] = filteredChildren.map { convertElementToJSON($0, withFilters: withFilters) }
        
        return result
    }
    
    /// Checks if a value is JSON-compatible
    private func isJSONCompatible(_ value: Any) -> Bool {
        switch value {
        case is String, is NSNumber, is Bool, is NSNull:
            return true
        case let array as [Any]:
            return array.allSatisfy { isJSONCompatible($0) }
        case let dict as [String: Any]:
            return dict.values.allSatisfy { isJSONCompatible($0) }
        default:
            return false
        }
    }
    
    /// Filters elements based on the provided filter criteria
    private func filterElements(_ elements: [UIElementNode], withFilters: [String: String]) -> [UIElementNode] {
        guard !withFilters.isEmpty else {
            return elements
        }
        
        return elements.filter { element in
            for (key, value) in withFilters {
                switch key.lowercased() {
                case "role":
                    if !element.role.lowercased().contains(value.lowercased()) {
                        return false
                    }
                case "title":
                    if let title = element.title, !title.lowercased().contains(value.lowercased()) {
                        return false
                    } else if element.title == nil {
                        return false
                    }
                case "id", "identifier":
                    if let identifier = element.identifier, !identifier.lowercased().contains(value.lowercased()) {
                        return false
                    } else if element.identifier == nil {
                        return false
                    }
                case "enabled":
                    let isEnabled = element.isEnabled
                    let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
                    if isEnabled != valueAsBool {
                        return false
                    }
                case "clickable":
                    let isClickable = element.isClickable
                    let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
                    if isClickable != valueAsBool {
                        return false
                    }
                default:
                    if let attrValue = element.attributes[key] {
                        if let stringValue = attrValue as? String, !stringValue.lowercased().contains(value.lowercased()) {
                            return false
                        } else if let numberValue = attrValue as? NSNumber, !numberValue.stringValue.contains(value) {
                            return false
                        } else if !(attrValue is String) && !(attrValue is NSNumber) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            return true
        }
    }
}

/// XML formatter
class XMLFormatter: OutputFormatter {
    func format(_ rootElement: UIElementNode, withFilters: [String: String]) -> String {
        var output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        output += "<accessibility-tree>\n"
        output += formatElementAsXML(rootElement, withFilters: withFilters, indent: "  ")
        output += "</accessibility-tree>"
        return output
    }
    
    /// Formats a UI element as XML
    private func formatElementAsXML(_ element: UIElementNode, withFilters: [String: String], indent: String) -> String {
        var output = indent + "<element"
        output += " index=\"\(element.index)\""
        output += " role=\"\(escapeXML(element.role))\""
        
        if let title = element.title {
            output += " title=\"\(escapeXML(title))\""
        }
        
        if let identifier = element.identifier {
            output += " identifier=\"\(escapeXML(identifier))\""
        }
        
        output += ">\n"
        
        // Add description if available
        if let description = element.description {
            output += indent + "  <description>\(escapeXML(description))</description>\n"
        }
        
        // Add frame if available
        if let frame = element.frame {
            output += indent + "  <frame"
            output += " x=\"\(Int(frame.origin.x))\""
            output += " y=\"\(Int(frame.origin.y))\""
            output += " width=\"\(Int(frame.size.width))\""
            output += " height=\"\(Int(frame.size.height))\""
            output += " />\n"
        }
        
        // Add actions
        if !element.actions.isEmpty {
            output += indent + "  <actions>\n"
            for action in element.actions {
                output += indent + "    <action>\(escapeXML(action))</action>\n"
            }
            output += indent + "  </actions>\n"
        }
        
        // Add state information
        output += indent + "  <state enabled=\"\(element.isEnabled)\" clickable=\"\(element.isClickable)\" />\n"
        
        // Add value if it's a simple type
        if let value = element.value {
            if let stringValue = value as? String {
                output += indent + "  <value>\(escapeXML(stringValue))</value>\n"
            } else if let numberValue = value as? NSNumber {
                output += indent + "  <value>\(numberValue)</value>\n"
            } else if let boolValue = value as? Bool {
                output += indent + "  <value>\(boolValue)</value>\n"
            }
        }
        
        // Add attributes
        if !element.attributes.isEmpty {
            output += indent + "  <attributes>\n"
            let sortedKeys = element.attributes.keys.sorted()
            
            for key in sortedKeys {
                if let value = element.attributes[key] {
                    let valueString = formatValueForXML(value)
                    if !valueString.isEmpty {
                        output += indent + "    <attribute name=\"\(escapeXML(key))\">\(valueString)</attribute>\n"
                    }
                }
            }
            
            output += indent + "  </attributes>\n"
        }
        
        // Add children
        let filteredChildren = filterElements(element.children, withFilters: withFilters)
        if !filteredChildren.isEmpty {
            output += indent + "  <children>\n"
            for child in filteredChildren {
                output += formatElementAsXML(child, withFilters: withFilters, indent: indent + "    ")
            }
            output += indent + "  </children>\n"
        }
        
        output += indent + "</element>\n"
        return output
    }
    
    /// Escapes special characters for XML
    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    /// Formats a value for XML output
    private func formatValueForXML(_ value: Any) -> String {
        switch value {
        case let stringValue as String:
            return escapeXML(stringValue)
        case let numberValue as NSNumber:
            return escapeXML(numberValue.stringValue)
        case let boolValue as Bool:
            return escapeXML(boolValue ? "true" : "false")
        case let arrayValue as [Any]:
            if arrayValue.isEmpty {
                return "[]"
            } else {
                return "[Array with \(arrayValue.count) elements]"
            }
        case let dictValue as [String: Any]:
            if dictValue.isEmpty {
                return "{}"
            } else {
                return "{Dictionary with \(dictValue.count) entries}"
            }
        default:
            return "[Type: \(type(of: value))]"
        }
    }
    
    /// Filters elements based on provided criteria
    private func filterElements(_ elements: [UIElementNode], withFilters: [String: String]) -> [UIElementNode] {
        guard !withFilters.isEmpty else {
            return elements
        }
        
        return elements.filter { element in
            for (key, value) in withFilters {
                switch key.lowercased() {
                case "role":
                    if !element.role.lowercased().contains(value.lowercased()) {
                        return false
                    }
                case "title":
                    if let title = element.title, !title.lowercased().contains(value.lowercased()) {
                        return false
                    } else if element.title == nil {
                        return false
                    }
                case "id", "identifier":
                    if let identifier = element.identifier, !identifier.lowercased().contains(value.lowercased()) {
                        return false
                    } else if element.identifier == nil {
                        return false
                    }
                case "enabled":
                    let isEnabled = element.isEnabled
                    let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
                    if isEnabled != valueAsBool {
                        return false
                    }
                case "clickable":
                    let isClickable = element.isClickable
                    let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
                    if isClickable != valueAsBool {
                        return false
                    }
                default:
                    if let attrValue = element.attributes[key] {
                        if let stringValue = attrValue as? String, !stringValue.lowercased().contains(value.lowercased()) {
                            return false
                        } else if let numberValue = attrValue as? NSNumber, !numberValue.stringValue.contains(value) {
                            return false
                        } else if !(attrValue is String) && !(attrValue is NSNumber) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            return true
        }
    }
}