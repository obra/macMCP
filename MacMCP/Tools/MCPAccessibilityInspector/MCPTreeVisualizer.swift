// ABOUTME: Renders hierarchical accessibility trees using MCP-based element structure
// ABOUTME: Provides tree visualization with parent-child relationships from MCP data

import Foundation

/// Visualizes the accessibility tree with proper indentation and formatting
class MCPTreeVisualizer {
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
        var highlightPaths: Bool = false
        var indentSize: Int = 3
        var branchPrefix: String = "+"
    }
    
    private let elementPrinter = MCPElementPrinter()
    private let options: Options
    
    init(options: Options = Options()) {
        self.options = options
    }
    
    /// Visualizes the accessibility tree starting from a root element
    /// - Parameters:
    ///   - rootElement: The root element of the tree
    ///   - withFilters: Optional filters to apply (key-value pairs)
    ///   - pathPattern: Optional path pattern to filter elements by
    /// - Returns: A string representation of the tree
    func visualize(_ rootElement: MCPUIElementNode, withFilters: [String: String] = [:], pathPattern: String? = nil) -> String {
        var output = ""
        
        // Format the root element
        output += elementPrinter.formatElement(rootElement, showColor: options.showColor, showAllData: options.showAllAttributes, highlightPath: options.highlightPaths)
        
        // If root has children, add a visual separator
        if !rootElement.children.isEmpty {
            output += "   │\n"
        }
        
        // Recursively visualize the children
        visualizeChildren(rootElement.children, withFilters: withFilters, pathPattern: pathPattern, prefix: "", isLast: true, intoOutput: &output)
        
        return output
    }
    
    /// Recursively visualizes children of a node
    /// - Parameters:
    ///   - children: The children to visualize
    ///   - withFilters: Filters to apply
    ///   - pathPattern: Optional path pattern to filter elements by
    ///   - prefix: Current line prefix for indentation
    ///   - isLast: Whether this is the last child in its parent's children list
    ///   - output: Output string to append to
    private func visualizeChildren(_ children: [MCPUIElementNode], withFilters: [String: String], pathPattern: String? = nil, prefix: String, isLast: Bool, intoOutput output: inout String) {
        // Filter children if needed
        let filteredChildren = filterElements(children, withFilters: withFilters, pathPattern: pathPattern)
        
        // Process each child
        for (index, child) in filteredChildren.enumerated() {
            let isLastChild = index == filteredChildren.count - 1
            
            // Create the branch prefix based on whether this is the last child
            let branchChar = isLastChild ? TreeSymbols.corner : TreeSymbols.branch
            let childPrefix = prefix + "   " + branchChar + TreeSymbols.horizontal + options.branchPrefix
            
            // Add the formatted child with proper indentation
            let elementOutput = elementPrinter.formatElement(child, showColor: options.showColor, showAllData: options.showAllAttributes, highlightPath: options.highlightPaths)
            let indentedOutput = indentLines(elementOutput, withPrefix: childPrefix, continuationPrefix: prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical) + "   ")
            
            output += indentedOutput
            
            // Add a separator if the child has children
            if !child.children.isEmpty {
                output += prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical) + "   " + TreeSymbols.vertical + "\n"
            }
            
            // Recursively visualize grandchildren
            let newPrefix = prefix + (isLastChild ? "   " : "   " + TreeSymbols.vertical)
            visualizeChildren(child.children, withFilters: withFilters, pathPattern: pathPattern, prefix: newPrefix, isLast: isLastChild, intoOutput: &output)
        }
    }
    
    /// Applies filters to a list of elements
    /// - Parameters:
    ///   - elements: The elements to filter
    ///   - withFilters: The filters to apply
    ///   - pathPattern: Optional path pattern to filter elements by path
    /// - Returns: Filtered list of elements
    private func filterElements(_ elements: [MCPUIElementNode], withFilters: [String: String], pathPattern: String? = nil) -> [MCPUIElementNode] {
        // First check if we have any filters at all
        let noStandardFilters = withFilters.isEmpty
        let noPathFilter = pathPattern == nil || pathPattern!.isEmpty
        
        // If there are no filters of any kind, return all elements
        if noStandardFilters && noPathFilter {
            return elements
        }
        
        return elements.filter { element in
            // Check path filter first if specified
            if let pattern = pathPattern, !pattern.isEmpty {
                // Get the element's path to match against
                let elementPath = element.elementPath ?? element.generateSyntheticPath() ?? ""
                
                // Simple substring match for now (enhanced version would use pattern matching)
                // We'll use case-insensitive matching for better usability
                if !elementPath.lowercased().contains(pattern.lowercased()) {
                    // No path match, check if we should include special elements regardless
                    let isApplicationElement = element.role == "AXApplication"
                    let isTopLevelWindow = element.role == "AXWindow"
                    
                    // Always keep application and top-level window elements for context
                    if !isApplicationElement && !isTopLevelWindow {
                        return false
                    }
                }
            }
            
            // If there are no standard filters, at this point the element passed the path filter
            if noStandardFilters {
                return true
            }
            
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
                    // Handle path filter
                    else if keyLower == "path" {
                        let elementPath = element.elementPath ?? element.generateSyntheticPath() ?? ""
                        if !elementPath.lowercased().contains(value.lowercased()) {
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
                    // Handle path filter
                    else if keyLower == "path" {
                        let elementPath = element.elementPath ?? element.generateSyntheticPath() ?? ""
                        if !elementPath.lowercased().contains(value.lowercased()) {
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
                // Handle path filter
                else if keyLower == "path" {
                    let elementPath = element.elementPath ?? element.generateSyntheticPath() ?? ""
                    if !elementPath.lowercased().contains(value.lowercased()) {
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
    private func applyStandardFilter(_ element: MCPUIElementNode, key: String, value: String) -> Bool {
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
        case "description":
            // Search in all possible description fields
            if let desc = element.description, desc.lowercased().contains(value.lowercased()) {
                return true
            }
            return false
        case "id", "identifier":
            return element.identifier.lowercased().contains(value.lowercased())
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
    ///   - type: The component type to match ("menu", "window-controls", "window-contents", or "interactive")
    /// - Returns: Whether the element is of the specified component type
    private func isElementOfComponentType(_ element: MCPUIElementNode, type: String) -> Bool {
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
            
        case "interactive", "interactable":
            // Check for common interactive element roles
            let interactiveRoles = [
                "AXButton", 
                "AXCheckBox", 
                "AXRadioButton", 
                "AXPopUpButton", 
                "AXMenuItem", 
                "AXLink", 
                "AXSlider",
                "AXTextField",
                "AXTextArea",
                "AXComboBox"
            ]
            
            // First check role
            if interactiveRoles.contains(element.role) {
                return true
            }
            
            // Check clickable state
            if element.isClickable {
                return true
            }
            
            // Check action capability
            if element.actions.contains("AXPress") {
                return true
            }
            
            // Check general capabilities
            if let capabilities = (element.attributes["capabilities"] as? [String]) ?? (element.attributes["capabilities"] as? String)?.components(separatedBy: ", ") {
                let interactiveCapabilities = ["clickable", "editable", "toggleable", "selectable", "adjustable"]
                for capability in interactiveCapabilities {
                    if capabilities.contains(capability) {
                        return true
                    }
                }
            }
            
            // Not an interactive element
            return false
            
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