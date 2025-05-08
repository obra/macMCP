// ABOUTME: Renders the hierarchical accessibility tree with proper indentation
// ABOUTME: Provides tree visualization with parent-child relationships

import Foundation

/// Visualizes the accessibility tree with proper indentation and formatting
class TreeVisualizer {
    /// Character sets used for drawing the tree structure
    private struct TreeSymbols {
        static let vertical = "│"
        static let branch = "├"
        static let corner = "└"
        static let horizontal = "─"
    }
    
    /// Options for tree visualization
    struct Options {
        var showColor: Bool = true
        var showDetails: Bool = false
        var showAllAttributes: Bool = false
        var indentSize: Int = 3
        var branchPrefix: String = "+"
    }
    
    private let elementPrinter = ElementPrinter()
    private let options: Options
    
    init(options: Options = Options()) {
        self.options = options
    }
    
    /// Visualizes the accessibility tree starting from a root element
    /// - Parameters:
    ///   - rootElement: The root element of the tree
    ///   - withFilters: Optional filters to apply (key-value pairs)
    /// - Returns: A string representation of the tree
    func visualize(_ rootElement: UIElementNode, withFilters: [String: String] = [:]) -> String {
        var output = ""
        
        // Format the root element
        output += elementPrinter.formatElement(rootElement, showColor: options.showColor, showAllData: options.showAllAttributes)
        
        // If root has children, add a visual separator
        if !rootElement.children.isEmpty {
            output += "   │\n"
        }
        
        // Recursively visualize the children
        visualizeChildren(rootElement.children, withFilters: withFilters, prefix: "", isLast: true, intoOutput: &output)
        
        return output
    }
    
    /// Recursively visualizes children of a node
    /// - Parameters:
    ///   - children: The children to visualize
    ///   - withFilters: Filters to apply
    ///   - prefix: Current line prefix for indentation
    ///   - isLast: Whether this is the last child in its parent's children list
    ///   - output: Output string to append to
    private func visualizeChildren(_ children: [UIElementNode], withFilters: [String: String], prefix: String, isLast: Bool, intoOutput output: inout String) {
        // Filter children if needed
        let filteredChildren = filterElements(children, withFilters: withFilters)
        
        // Process each child
        for (index, child) in filteredChildren.enumerated() {
            let isLastChild = index == filteredChildren.count - 1
            
            // Create the branch prefix based on whether this is the last child
            let branchChar = isLastChild ? TreeSymbols.corner : TreeSymbols.branch
            let childPrefix = prefix + "   " + branchChar + TreeSymbols.horizontal + options.branchPrefix
            
            // Add the formatted child with proper indentation
            let elementOutput = elementPrinter.formatElement(child, showColor: options.showColor, showAllData: options.showAllAttributes)
            let indentedOutput = indentLines(elementOutput, withPrefix: childPrefix, continuationPrefix: prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical) + "   ")
            
            output += indentedOutput
            
            // Add a separator if the child has children
            if !child.children.isEmpty {
                output += prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical) + "   " + TreeSymbols.vertical + "\n"
            }
            
            // Recursively visualize grandchildren
            let newPrefix = prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical)
            visualizeChildren(child.children, withFilters: withFilters, prefix: newPrefix, isLast: isLastChild, intoOutput: &output)
        }
    }
    
    /// Applies filters to a list of elements
    /// - Parameters:
    ///   - elements: The elements to filter
    ///   - withFilters: The filters to apply
    /// - Returns: Filtered list of elements
    private func filterElements(_ elements: [UIElementNode], withFilters: [String: String]) -> [UIElementNode] {
        guard !withFilters.isEmpty else {
            return elements // No filters, return all elements
        }
        
        return elements.filter { element in
            // Special case: Always include application elements regardless of visible/enabled state
            if element.role == "AXApplication" {
                // For application elements, only apply filters other than visible/enabled
                for (key, value) in withFilters {
                    let keyLower = key.lowercased()
                    
                    // Skip enabled/visible filters for application elements
                    if keyLower == "enabled" || keyLower == "visible" {
                        continue
                    }
                    
                    // Handle component type filters
                    if keyLower == "component-type" {
                        if !isElementOfComponentType(element, type: value.lowercased()) {
                            return false
                        }
                    } else if keyLower == "component-types" {
                        let types = value.lowercased().split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                        var matchesAny = false
                        for componentType in types {
                            if isElementOfComponentType(element, type: componentType) {
                                matchesAny = true
                                break
                            }
                        }
                        if !matchesAny {
                            return false
                        }
                    }
                    // Handle all other filters
                    else if !applyStandardFilter(element, key: keyLower, value: value) {
                        return false
                    }
                }
                return true
            }
            
            // Special case: Always include top-level windows regardless of enabled state
            if element.role == "AXWindow" {
                // For window elements, only apply filters other than enabled
                for (key, value) in withFilters {
                    let keyLower = key.lowercased()
                    
                    // Skip enabled filters for window elements
                    if keyLower == "enabled" {
                        continue
                    }
                    
                    // Handle component type filters
                    if keyLower == "component-type" {
                        if !isElementOfComponentType(element, type: value.lowercased()) {
                            return false
                        }
                    } else if keyLower == "component-types" {
                        let types = value.lowercased().split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                        var matchesAny = false
                        for componentType in types {
                            if isElementOfComponentType(element, type: componentType) {
                                matchesAny = true
                                break
                            }
                        }
                        if !matchesAny {
                            return false
                        }
                    }
                    // Handle all other filters
                    else if !applyStandardFilter(element, key: keyLower, value: value) {
                        return false
                    }
                }
                return true
            }
            
            // For regular elements, apply all filters
            for (key, value) in withFilters {
                let keyLower = key.lowercased()
                
                // Handle component type filters
                if keyLower == "component-type" {
                    if !isElementOfComponentType(element, type: value.lowercased()) {
                        return false
                    }
                } else if keyLower == "component-types" {
                    let types = value.lowercased().split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                    var matchesAny = false
                    for componentType in types {
                        if isElementOfComponentType(element, type: componentType) {
                            matchesAny = true
                            break
                        }
                    }
                    if !matchesAny {
                        return false
                    }
                }
                // Handle all other filters
                else if !applyStandardFilter(element, key: keyLower, value: value) {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Helper function to apply a standard filter (non-component type)
    private func applyStandardFilter(_ element: UIElementNode, key: String, value: String) -> Bool {
        switch key {
        case "role":
            return element.role.lowercased().contains(value.lowercased())
        case "subrole":
            if let subrole = element.subrole {
                return subrole.lowercased().contains(value.lowercased())
            }
            return false
        case "title":
            if let title = element.title {
                return title.lowercased().contains(value.lowercased())
            }
            return false
        case "id", "identifier":
            if let identifier = element.identifier {
                return identifier.lowercased().contains(value.lowercased())
            }
            return false
        case "enabled":
            let isEnabled = element.isEnabled
            let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
            return isEnabled == valueAsBool
        case "clickable":
            let isClickable = element.isClickable
            let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
            return isClickable == valueAsBool
        case "visible":
            let isVisible = element.isVisible
            let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
            return isVisible == valueAsBool
        case "focused":
            let isFocused = element.focused
            let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
            return isFocused == valueAsBool
        case "selected":
            let isSelected = element.selected
            let valueAsBool = value.lowercased() == "true" || value.lowercased() == "yes"
            return isSelected == valueAsBool
        default:
            // Check if filter key is an attribute
            if let attrValue = element.attributes[key] {
                if let stringValue = attrValue as? String, !stringValue.lowercased().contains(value.lowercased()) {
                    return false
                } else if let numberValue = attrValue as? NSNumber, !numberValue.stringValue.contains(value) {
                    return false
                } else if !(attrValue is String) && !(attrValue is NSNumber) {
                    return false // Non-string/number attributes are filtered out if specified
                }
                return true
            }
            return false
        }
    }
    
    /// Checks if an element matches a specific component type
    /// - Parameters:
    ///   - element: The element to check
    ///   - type: The component type to match ("menu", "window-controls", or "window-contents")
    /// - Returns: Whether the element is of the specified component type
    private func isElementOfComponentType(_ element: UIElementNode, type: String) -> Bool {
        switch type {
        case "menu", "menus":
            // Check if element is menu-related
            let menuRoles = ["AXMenuBar", "AXMenu", "AXMenuItem", "AXMenuBarItem"]
            return menuRoles.contains(element.role)
            
        case "window-control", "window-controls":
            // Check if element is a window control
            let controlRoles = ["AXToolbar", "AXButton", "AXSlider", "AXScrollBar"]
            let controlSubroles = ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", 
                                 "AXToolbarButton", "AXFullScreenButton"]
            
            // Check if it's a control by role
            if controlRoles.contains(element.role) {
                // Accept certain roles regardless of position (like toolbars)
                if ["AXToolbar"].contains(element.role) {
                    return true
                }
                
                // For other controls, check if they're in the window chrome area
                // This is a heuristic - window controls are usually at the top of the window
                if let frame = element.frame, frame.origin.y < 50 {
                    return true
                }
                
                // Otherwise, it's not a window control
                return false
            }
            
            // Check if it's a control by subrole
            if let subrole = element.subrole, controlSubroles.contains(subrole) {
                return true
            }
            
            // Not a window control
            return false
            
        case "window-content", "window-contents":
            // Check if element is window content (not menu or control)
            let menuRoles = ["AXMenuBar", "AXMenu", "AXMenuItem", "AXMenuBarItem"]
            let controlRoles = ["AXToolbar"]
            let controlSubroles = ["AXCloseButton", "AXMinimizeButton", "AXZoomButton", 
                                 "AXToolbarButton", "AXFullScreenButton"]
            
            // Exclude menu elements
            if menuRoles.contains(element.role) {
                return false
            }
            
            // Exclude control elements by role
            if controlRoles.contains(element.role) {
                return false
            }
            
            // Exclude control elements by subrole
            if let subrole = element.subrole, controlSubroles.contains(subrole) {
                return false
            }
            
            // Exclude buttons in the window chrome area
            if element.role == "AXButton", let frame = element.frame, frame.origin.y < 50 {
                return false
            }
            
            // Include everything else
            return true
            
        default:
            return false
        }
    }
    
    /// Indents each line of text with the given prefix
    /// - Parameters:
    ///   - text: The text to indent
    ///   - withPrefix: The prefix for the first line
    ///   - continuationPrefix: The prefix for continuation lines
    /// - Returns: Indented text
    private func indentLines(_ text: String, withPrefix: String, continuationPrefix: String) -> String {
        var result = ""
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        
        for (index, line) in lines.enumerated() {
            if index == 0 {
                result += withPrefix + line + "\n"
            } else {
                result += continuationPrefix + line + "\n"
            }
        }
        
        return result
    }
}