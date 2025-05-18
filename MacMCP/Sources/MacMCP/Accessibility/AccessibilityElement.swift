// ABOUTME: This file contains utilities for working with the macOS Accessibility API.
// ABOUTME: It provides methods to convert AXUIElement objects to our UIElement model.

import Foundation
@preconcurrency import AppKit
@preconcurrency import ApplicationServices

/// Utility for working with AXUIElement objects
public class AccessibilityElement {
    /// Convert an AXUIElement to our UIElement model
    /// - Parameters:
    ///   - axElement: The AXUIElement to convert
    ///   - recursive: Whether to recursively get children
    ///   - maxDepth: Maximum depth for recursion (to prevent infinite loops)
    /// - Returns: A UIElement representation
    public static func convertToUIElement(
        _ axElement: AXUIElement,
        recursive: Bool = true,
        maxDepth: Int = 25
    ) throws -> UIElement {
        return try _convertToUIElement(axElement, recursive: recursive, maxDepth: maxDepth, depth: 0)
    }
    
    private static func _convertToUIElement(
        _ axElement: AXUIElement,
        recursive: Bool,
        maxDepth: Int,
        depth: Int,
        parent: UIElement? = nil,
        path: String = ""
    ) throws -> UIElement {
        // Get basic properties - with robust error handling
        // If we can't get the role attribute, use "unknown" and continue rather than fail completely
        let role: String
        do {
            role = try getAttribute(axElement, attribute: AXAttribute.role) as? String ?? "unknown"
        } catch {
            // On error, set a generic role and continue rather than failing
            NSLog("WARNING: Failed to get AXRole attribute: \(error.localizedDescription). Continuing with generic role.")
            role = "unknown"
        }
        
        // Similarly robust handling for other attributes
        let title: String?
        do {
            title = try getAttribute(axElement, attribute: AXAttribute.title) as? String
        } catch {
            title = nil
        }
        
        let value: String?
        do {
            value = try getStringValue(for: axElement)
        } catch {
            value = nil
        }
        
        let description: String?
        do {
            description = try getAttribute(axElement, attribute: AXAttribute.description) as? String
        } catch {
            description = nil
        }
        
        // Get the frame information with robust error handling
        let frame: CGRect
        let frameSource: FrameSource
        var normalizedFrame: CGRect? = nil
        var viewportFrame: CGRect? = nil
        
        // Get the frame information with all the enhanced detections
        (frame, frameSource, normalizedFrame, viewportFrame) = getFrameInformation(
            axElement: axElement,
            role: role,
            title: title
        )
        
        // Get additional attributes - continue even if we encounter errors
        var attributes: [String: Any] = [:]
        
        // Common boolean attributes
        if let focused = try? getAttribute(axElement, attribute: AXAttribute.focused) as? Bool {
            attributes["focused"] = focused
        }
        
        if let enabled = try? getAttribute(axElement, attribute: AXAttribute.enabled) as? Bool {
            attributes["enabled"] = enabled
        }
        
        if let selected = try? getAttribute(axElement, attribute: AXAttribute.selected) as? Bool {
            attributes["selected"] = selected
        }
        
        // Try to get application title for context
        if role == AXAttribute.Role.application {
            if let appElement = try? getAttribute(axElement, attribute: "AXTitle") as? String {
                attributes["application"] = appElement
            }
        } else if let parentApp = parent?.attributes["application"] as? String {
            // Inherit application context from parent
            attributes["application"] = parentApp
        }
        
        // Generate an ElementPath-based identifier for this element
        // Build the current path segment
        var attributePairs: [String: String] = [:]
        
        // Don't include identifiers in paths as they can change between runs
        // and make paths too specific for reliable element matching
        
        // Add title if available and not empty - use AXTitle for proper accessibility attribute name
        if let title = title, !title.isEmpty {
            attributePairs["AXTitle"] = title
        }
        
        // Add description if available and not empty - use AXDescription for proper accessibility attribute name
        if let description = description, !description.isEmpty {
            attributePairs["AXDescription"] = description
        }
        
        // For application elements, add bundle identifier if possible
        // Keep bundleIdentifier without AX prefix as it's a special case
        if role == AXAttribute.Role.application {
            var pid: pid_t = 0
            let pidResult = AXUIElementGetPid(axElement, &pid)
            if pidResult == .success && pid != 0 {
                if let app = NSRunningApplication(processIdentifier: pid), 
                   let bundleID = app.bundleIdentifier {
                    attributePairs["bundleIdentifier"] = bundleID
                }
            }
        }
        
        // Construct the element-only path segment - format: AXRole[@attr="value"]
        let elementPathSegment = createElementPathString(role: role, attributes: attributePairs)
        
        // Build the complete hierarchical path for this element
        let hierarchicalPath = path.isEmpty ? elementPathSegment : "\(path)/\(elementPathSegment)"
        
        // Use the hierarchical path as the identifier, prefixed with ui://
        let fullHierarchicalPath = "ui://\(hierarchicalPath.hasPrefix("AX") ? hierarchicalPath : "AX\(hierarchicalPath)")"
        let identifier = fullHierarchicalPath
        
        // Now that we have an identifier, we'll use the frame-related variables that are already defined

        // Get available actions with robust error handling
        let actions: [String]
        do {
            actions = try getActionNames(for: axElement)
        } catch {
            NSLog("WARNING: Failed to get actions: \(error.localizedDescription)")
            actions = []
        }
        
        // Log at all depths for better debugging visibility
        // NSLog("Converting element at depth \(depth): \(hierarchicalPath) - \(identifier)")
        
        // Create the element first (without children)
        let element = UIElement(
            path: identifier,
            role: role,
            title: title,
            value: value, 
            elementDescription: description,
            frame: frame,
            normalizedFrame: normalizedFrame,
            viewportFrame: viewportFrame,
            frameSource: frameSource,
            parent: parent,
            attributes: attributes,
            actions: actions
        )
        
        // Set the path property to ensure it's available
        element.path = identifier
        
        // Recursively get children if requested and we haven't reached max depth
        var children: [UIElement] = []
        
        // Always continue if below the minimum traversal depth (ensures critical controls aren't missed)
        // Increased to 30 to better find deeply nested elements like those in ScrollAreas
        let minimumTraversalDepth = 30
        let shouldTraverse = recursive && (depth < minimumTraversalDepth || depth < maxDepth)
        
        if shouldTraverse {
            do {
                if let axChildren = try getAttribute(axElement, attribute: AXAttribute.children) as? [AXUIElement] {
                    // All elements get full depth - don't limit menu traversal
                    let adjustedMaxDepth = maxDepth
                    
                    // Sort children to prioritize likely interactive elements and containers
                    let prioritizedChildren = try prioritizeChildren(axChildren)
                    
                    // Process each child
                    for axChild in prioritizedChildren {
                        do {
                            // Check child's role to determine if it's worth exploring
                            var childRole = "unknown"
                            if let role = try? getAttribute(axChild, attribute: AXAttribute.role) as? String {
                                childRole = role
                            }
                            
                            // Skip traversal of certain non-interactive elements at deeper levels
                            if depth > minimumTraversalDepth && shouldSkipDeepTraversal(childRole) {
                                continue
                            }
                            
                            // Skip invisible or unavailable elements when they're not the primary interface
                            if depth > 1 {
                                // Check various visibility attributes
                                let visibilityAttr = try? getAttribute(axChild, attribute: "AXVisible")
                                let isVisible = (visibilityAttr as? Bool) ?? true
                                
                                let isEnabled = (try? getAttribute(axChild, attribute: "AXEnabled") as? Bool) ?? true
                                let isHidden = (try? getAttribute(axChild, attribute: "AXHidden") as? Bool) ?? false
                                
                                // Check frame dimensions - elements with zero size are likely not visible
                                let frame: CGRect
                                if let positionValue = try? getAttribute(axChild, attribute: AXAttribute.position) as? NSValue,
                                   let sizeValue = try? getAttribute(axChild, attribute: AXAttribute.size) as? NSValue {
                                    frame = CGRect(origin: positionValue.pointValue, size: sizeValue.sizeValue)
                                } else if let axFrame = try? getAttribute(axChild, attribute: AXAttribute.frame) as? NSValue {
                                    frame = axFrame.rectValue
                                } else {
                                    frame = .zero
                                }
                                
                                let hasZeroSize = frame.size.width <= 0 || frame.size.height <= 0
                                
                                // Special case for interactive elements - don't filter them out based on zero size
                                let isInteractiveElement = childRole == "AXButton" ||
                                                          childRole == "AXMenuItem" ||
                                                          childRole == "AXCheckBox" ||
                                                          childRole == "AXRadioButton" ||
                                                          childRole == "AXTextField" ||
                                                          childRole == "AXLink"

                                // Always include menu elements regardless of state
                                let isMenuElement = childRole == "AXMenu" ||
                                                 childRole == "AXMenuBar" ||
                                                 childRole == "AXMenuBarItem" ||
                                                 childRole == "AXMenuItem"

                                // Identify important container and content elements
                                let isImportantContainer = childRole == "AXSplitGroup" ||
                                                        childRole == "AXGroup" ||
                                                        childRole == "AXScrollArea"

                                // Identify elements that might contain important text/values
                                let isValueElement = childRole == "AXStaticText" ||
                                                   childRole == "AXTextField" ||
                                                   childRole == "AXTextArea"

                                // Less strict filtering - include menu elements always
                                let isAvailable: Bool
                                if isMenuElement {
                                    // Always include menu elements regardless of state
                                    isAvailable = true
                                } else if isImportantContainer {
                                    // For containers: don't filter based on zero size, but respect enabled/hidden state
                                    isAvailable = isVisible && !isHidden
                                } else if isValueElement {
                                    // For text elements: similarly don't filter on size or enabled state
                                    isAvailable = isVisible && !isHidden
                                } else {
                                    // For other elements: use the normal stringent checks
                                    isAvailable = isVisible && isEnabled && !isHidden && (!hasZeroSize || isInteractiveElement)
                                }

                                if (!isAvailable) {
                                    // Only log skips at higher depths to reduce noise
                                    if depth < 3 {
                                      //  NSLog("SKIPPING invisible element: \(childRole)")
                                    }
                                    
                                    // Create a stub element without children
                                    do {
                                        let stubElement = try createStubElement(axChild, parent: element)
                                        children.append(stubElement)
                                    } catch {
                                        // Only log failures at higher levels
                                        if depth < 3 {
                                            NSLog("WARNING: Failed to create stub: \(error.localizedDescription)")
                                        }
                                    }
                                    continue
                                }
                            }
                            
                            let child = try _convertToUIElement(
                                axChild,
                                recursive: recursive,
                                maxDepth: adjustedMaxDepth,
                                depth: depth + 1,
                                parent: element,
                                path: hierarchicalPath
                            )
                            children.append(child)
                        } catch {
                            // Log but continue with other children
                            NSLog("WARNING: Failed to convert child element: \(error.localizedDescription)")
                            continue
                        }
                    }
                }
            } catch {
                // Log but continue
                NSLog("WARNING: Failed to get children: \(error.localizedDescription)")
            }
        }
        
        // Create a new element with the same properties but with children
        let uiElement = UIElement(
            path: identifier,
            role: role,
            title: title,
            value: value,
            elementDescription: description,
            frame: frame,
            normalizedFrame: normalizedFrame,
            viewportFrame: viewportFrame,
            frameSource: frameSource,
            parent: parent,
            children: children,
            attributes: attributes,
            actions: actions
        )
        
        // Store the AXUIElement for reference
        uiElement.axElement = axElement
        
        // Set the path property to ensure it's available
        uiElement.path = identifier
        
        return uiElement
    }
    
    /// Prioritize children for traversal to find interactive elements more quickly
    private static func prioritizeChildren(_ children: [AXUIElement]) throws -> [AXUIElement] {
        var prioritizedChildren: [(AXUIElement, Int)] = []
        
        for child in children {
            var priority = 5 // Default priority
            
            // Get child role
            if let role = try? getAttribute(child, attribute: AXAttribute.role) as? String {
                // Window elements get highest priority
                if role == AXAttribute.Role.window {
                    priority = 0
                }
                // Menu elements get high priority too (no longer deprioritized)
                else if isMenuElement(role) {
                    priority = 1 // High priority for menus
                }
                // Give containers next priority
                else if isControlContainer(role) {
                    priority = 2
                }
                // Interactive controls get next priority
                else if isInteractiveControl(role) {
                    priority = 3
                }
                // Static text and other identifiable elements
                else if role == AXAttribute.Role.staticText || role == AXAttribute.Role.image {
                    priority = 4
                }
                // Everything else
                else {
                    priority = 5
                }
                
                // Check for useful button titles
                if role == AXAttribute.Role.button {
                    if let title = try? getAttribute(child, attribute: AXAttribute.title) as? String {
                        // Boost priority for buttons with short titles (likely to be interactive controls)
                        if title.count <= 3 {
                            // Boost priority for short-titled buttons
                            priority -= 1
                        }
                    }
                }
                
                // Further boost priority for elements with actions
                if let actions = try? getActionNames(for: child), !actions.isEmpty {
                    if actions.contains(AXAttribute.Action.press) {
                        // Elements with press action are highly interactive
                        priority = min(priority, 2)
                    } else if !actions.isEmpty {
                        // Any actionable element gets priority boost
                        priority = min(priority, 3)
                    }
                }
                
                // Boost elements that are visible and enabled
                let isVisible = (try? getAttribute(child, attribute: "AXVisible") as? Bool) ?? true
                let isEnabled = (try? getAttribute(child, attribute: "AXEnabled") as? Bool) ?? true
                
                if isVisible && isEnabled {
                    // Give a slight boost to visible, enabled elements
                    priority = max(0, priority - 1)
                } else {
                    // Deprioritize invisible or disabled elements
                    priority += 3
                }
            }
            
            prioritizedChildren.append((child, priority))
        }
        
        // Sort by priority (lower number = higher priority)
        return prioritizedChildren.sorted { $0.1 < $1.1 }.map { $0.0 }
    }
    
    /// Filter elements by element type
    /// - Parameters:
    ///   - elements: Array of UI elements to filter
    ///   - elementType: The type of element to filter for (e.g., "button", "textfield")
    /// - Returns: Filtered array of elements matching the type
    public static func filterElementsByType(_ elements: [UIElement], type elementType: String) -> [UIElement] {
        // Map of element types to role patterns
        let typeToRoles: [String: [String]] = [
            "button": [AXAttribute.Role.button, "AXButtonSubstitute"],
            "checkbox": [AXAttribute.Role.checkbox],
            "radio": [AXAttribute.Role.radioButton, "AXRadioGroup"],
            "textfield": [AXAttribute.Role.textField, AXAttribute.Role.textArea, "AXSecureTextField"],
            "dropdown": [AXAttribute.Role.popUpButton, "AXComboBox", "AXPopover"],
            "slider": ["AXSlider", "AXScrollBar"],
            "link": [AXAttribute.Role.link],
            "tab": ["AXTabGroup", "AXTab", "AXTabButton"],
            "menu": [AXAttribute.Role.menu, AXAttribute.Role.menuItem, "AXMenuBarItem"],
            "image": [AXAttribute.Role.image, "AXGroup"],
            "text": [AXAttribute.Role.staticText],
            "window": [AXAttribute.Role.window],
            "any": [] // Special case - will match any element
        ]
        
        // If "any" type is requested or invalid type, return all elements
        if elementType == "any" || !typeToRoles.keys.contains(elementType) {
            return elements
        }
        
        // Get the roles that match this element type
        let matchingRoles = typeToRoles[elementType] ?? []
        
        // Filter elements by role
        return elements.filter { element in
            // Direct role match
            if matchingRoles.contains(element.role) {
                return true
            }
            
            // Handle special cases based on element type
            switch elementType {
            case "button":
                // Consider any element with a "press" action to be a button
                return element.actions.contains(AXAttribute.Action.press)
                
            case "textfield":
                // Consider any editable element to be a text field
                return element.attributes["editable"] as? Bool == true
                
            case "image":
                // Consider groups that contain images or have image-like names
                return element.role == AXAttribute.Role.group && 
                       (element.path.lowercased().contains("image") || 
                        element.path.lowercased().contains("icon") ||
                        element.path.lowercased().contains("picture"))
                
            case "any":
                return true
                
            default:
                return false
            }
        }
    }
    
    /// Check if an element role represents a container that likely contains controls
    private static func isControlContainer(_ role: String) -> Bool {
        let containerRoles = [
            AXAttribute.Role.group,
            AXAttribute.Role.toolbar,
            "AXTabGroup",
            "AXSplitGroup",
            "AXNavigationBar",
            "AXDrawer",
            "AXContentView",
            "AXList",
            "AXOutline",
            "AXGrid",
            "AXScrollArea",
            "AXLayoutArea",
            "AXColumn",
            "AXRow",
            "AXTable",
            "AXDisclosureTriangle",
            "AXSplitter"
        ]
        
        return containerRoles.contains(role)
    }
    
    /// Check if an element is a menu-related element that should be deprioritized
    private static func isMenuElement(_ role: String) -> Bool {
        let menuRoles = [
            "AXMenu",
            "AXMenuBar",
            "AXMenuBarItem",
            "AXMenuItem",
            "AXMenuButton"
        ]
        
        return menuRoles.contains(role)
    }
    
    /// Check if an element role represents an interactive control
    private static func isInteractiveControl(_ role: String) -> Bool {
        let controlRoles = [
            AXAttribute.Role.button,
            AXAttribute.Role.popUpButton,
            AXAttribute.Role.checkbox,
            AXAttribute.Role.radioButton,
            AXAttribute.Role.textField,
            AXAttribute.Role.menu,
            AXAttribute.Role.menuItem,
            AXAttribute.Role.link,
            "AXSlider",
            "AXStepper",
            "AXSwitch",
            "AXToggle",
            "AXTabButton"
        ]
        
        return controlRoles.contains(role)
    }
    
    /// Determine if we should skip traversing this element at deeper levels
    private static func shouldSkipDeepTraversal(_ role: String) -> Bool {
        let skipRoles = [
            // Non-interactive elements
            "AXUnknown",
            "AXLayoutItem",
            "AXLevelIndicator",
            "AXColorWell",
            "AXSpacer",
            "AXDivider",
            
            // Menu-related elements beyond a certain depth
            "AXMenu",
            "AXMenuBar",
            "AXMenuBarItem",
            "AXMenuItem",
            "AXMenuButton"
        ]
        
        // Never skip traversal of important roles that might contain meaningful content
        let neverSkipRoles = [
            "AXScrollArea",
            "AXStaticText",
            "AXTextField"
        ]
        
        if neverSkipRoles.contains(role) {
            return false
        }
        
        return skipRoles.contains(role)
    }
    
    /// Create a stub element with basic properties but no children
    /// Used for elements we don't want to fully traverse
    private static func createStubElement(_ axElement: AXUIElement, parent: UIElement?) throws -> UIElement {
        // Get basic properties - with robust error handling
        let role: String = try getAttribute(axElement, attribute: AXAttribute.role) as? String ?? "unknown"
        let title: String? = try? getAttribute(axElement, attribute: AXAttribute.title) as? String
        
        // Create attributes dictionary for path creation
        var attributePairs: [String: String] = [:]
        
        // Add title if available
        if let title = title, !title.isEmpty {
            attributePairs["title"] = title
        }
        
        // Add a memory address as an additional identifier to ensure uniqueness for stubs
        let address = UInt(bitPattern: Unmanaged.passUnretained(axElement).toOpaque())
        attributePairs["memoryAddress"] = String(address)
        
        // Create the path-based identifier
        let elementPath = createElementPathString(role: role, attributes: attributePairs)
        
        // Get a minimal frame
        let frame: CGRect
        if let axFrame = try? getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
            frame = axFrame.rectValue
        } else {
            frame = .zero
        }
        
        // Create minimal element - no children, empty attributes and actions 
        let element = UIElement(
            path: elementPath,
            role: role,
            title: title,
            value: nil,
            elementDescription: nil,
            frame: frame,
            normalizedFrame: nil,
            viewportFrame: nil,
            frameSource: frame == .zero ? .unavailable : .attribute,
            parent: parent,
            children: [], // Empty children - don't traverse
            attributes: [:],
            actions: []
        )
        
        // Set the path property to ensure it's available
        element.path = elementPath
        
        return element
    }
    
    /// Get frame information for an accessibility element with multiple detection methods
    /// - Parameters:
    ///   - axElement: The accessibility element
    ///   - role: The role of the element
    ///   - title: The title of the element (if available)
    /// - Returns: A tuple containing (frame, source, normalizedFrame, viewportFrame)
    private static func getFrameInformation(
        axElement: AXUIElement,
        role: String,
        title: String?
    ) -> (CGRect, FrameSource, CGRect?, CGRect?) {
        // Initialize with default values
        var frame: CGRect = .zero
        var frameSource: FrameSource = .unavailable
        var normalizedFrame: CGRect? = nil
        var viewportFrame: CGRect? = nil
        
        // Method 1: Try to get position and size directly (most reliable)
        // First get the position
        var origin = CGPoint.zero
        var size = CGSize.zero
        var hasValidPosition = false
        var hasValidSize = false
        
        // Get position
        if let positionValue = try? getAttribute(axElement, attribute: AXAttribute.position) {
            // Check for both NSValue and AXValue types since different macOS versions return different types
            if let nsValue = positionValue as? NSValue {
                origin = nsValue.pointValue
                hasValidPosition = true
            } else if CFGetTypeID(positionValue as CFTypeRef) == AXValueGetTypeID() {
                // It's an AXValue, extract the CGPoint
                AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
                hasValidPosition = true
            }
        }
        
        // Get size
        if let sizeValue = try? getAttribute(axElement, attribute: AXAttribute.size) {
            // Check for both NSValue and AXValue types
            if let nsValue = sizeValue as? NSValue {
                size = nsValue.sizeValue
                hasValidSize = true
            } else if CFGetTypeID(sizeValue as CFTypeRef) == AXValueGetTypeID() {
                // It's an AXValue, extract the CGSize
                AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                hasValidSize = true
            }
        }
        
        if hasValidPosition && hasValidSize {
            frame = CGRect(origin: origin, size: size)
            frameSource = .direct
        }
        // Method 2: Try to get frame as a single value
        else if let axFrame = try? getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
            frame = axFrame.rectValue
            frameSource = .attribute
        }
        
        // Method 3: For elements in scrollable containers, try to get viewport information
        // This is especially useful for elements in scroll views, web content, etc.
        if role == "AXScrollArea" || role == AXAttribute.Role.webArea || role.contains("AXScroll") {
            // Try to get visible area
            if let visibleArea = try? getAttribute(axElement, attribute: AXAttribute.visibleArea) as? NSValue {
                viewportFrame = visibleArea.rectValue
                
                // If we don't have a frame yet, use the visible area
                if frameSource == .unavailable {
                    frame = viewportFrame!
                    frameSource = .viewport
                }
            }
        }
        
        // If we still don't have valid frame information, try parent-based calculations
        if frameSource == .unavailable || (frame.origin.x == 0 && frame.origin.y == 0 && 
                                          frame.size.width == 0 && frame.size.height == 0) {
            
            // Get parent element, if available
            if let parentElementObj = try? getAttribute(axElement, attribute: AXAttribute.parent) {
                // Make sure this is an AXUIElement
                if CFGetTypeID(parentElementObj as CFTypeRef) == AXUIElementGetTypeID() {
                    let parentElement = parentElementObj as! AXUIElement
                    
                    // Get parent frame information
                    var parentFrame: CGRect = .zero
                    var hasParentFrame = false
                    
                    // Try to get parent position and size
                    if let parentPosition = try? getAttribute(parentElement, attribute: AXAttribute.position) as? NSValue,
                       let parentSize = try? getAttribute(parentElement, attribute: AXAttribute.size) as? NSValue {
                        parentFrame = CGRect(origin: parentPosition.pointValue, size: parentSize.sizeValue)
                        hasParentFrame = true
                    }
                    // Try to get parent frame as a single value
                    else if let parentFrameValue = try? getAttribute(parentElement, attribute: AXAttribute.frame) as? NSValue {
                        parentFrame = parentFrameValue.rectValue
                        hasParentFrame = true
                    }
                    
                    if hasParentFrame && !parentFrame.isEmpty {
                        // Calculate a relative position within parent based on index among siblings
                        // This is a rough guess - better than nothing
                        if let siblings = try? getAttribute(parentElement, attribute: AXAttribute.children) as? [AXUIElement] {
                            var index: CGFloat = 0
                            let totalSiblings = CGFloat(siblings.count)
                            
                            // Find index of this element among siblings
                            for (i, sibling) in siblings.enumerated() {
                                if CFEqual(sibling, axElement) {
                                    index = CGFloat(i)
                                    break
                                }
                            }
                            
                            if totalSiblings > 0 {
                                // Divide parent into grid of cells and place this element in appropriate cell
                                // This is very rough but better than zero coordinates
                                let cellWidth = parentFrame.width / min(4, totalSiblings)
                                let cellHeight = parentFrame.height / min(4, totalSiblings)
                                let colIndex = floor(index.truncatingRemainder(dividingBy: 4))
                                let rowIndex = floor(index / 4)
                                
                                let cellX = parentFrame.origin.x + (colIndex * cellWidth)
                                let cellY = parentFrame.origin.y + (rowIndex * cellHeight)
                                
                                frame = CGRect(x: cellX, y: cellY, width: cellWidth, height: cellHeight)
                                frameSource = .calculated
                                
                                // Store the normalized position (0.0-1.0 within parent bounds)
                                normalizedFrame = CGRect(
                                    x: colIndex / min(4, totalSiblings),
                                    y: rowIndex / min(4, totalSiblings),
                                    width: 1.0 / min(4, totalSiblings),
                                    height: 1.0 / min(4, totalSiblings)
                                )
                            }
                        }
                    }
                }
            }
        }
        
        // If we have a valid frame but no normalized coordinates, calculate them
        if frameSource != .unavailable && normalizedFrame == nil {
            // Try to get parent element to calculate normalized coordinates
            if let parentElementObj = try? getAttribute(axElement, attribute: AXAttribute.parent) {
                // Make sure this is an AXUIElement
                if CFGetTypeID(parentElementObj as CFTypeRef) == AXUIElementGetTypeID() {
                    let parentElement = parentElementObj as! AXUIElement
                    
                    // Get parent frame information
                    var parentFrame: CGRect = .zero
                    var hasParentFrame = false
                    
                    // Try to get parent position and size
                    if let parentPosition = try? getAttribute(parentElement, attribute: AXAttribute.position) as? NSValue,
                       let parentSize = try? getAttribute(parentElement, attribute: AXAttribute.size) as? NSValue {
                        parentFrame = CGRect(origin: parentPosition.pointValue, size: parentSize.sizeValue)
                        hasParentFrame = true
                    }
                    // Try to get parent frame as a single value
                    else if let parentFrameValue = try? getAttribute(parentElement, attribute: AXAttribute.frame) as? NSValue {
                        parentFrame = parentFrameValue.rectValue
                        hasParentFrame = true
                    }
                    
                    if hasParentFrame && !parentFrame.isEmpty {
                        // Calculate normalized coordinates relative to parent
                        // This helps position elements when parent coordinates change
                        let normX = (frame.origin.x - parentFrame.origin.x) / parentFrame.width
                        let normY = (frame.origin.y - parentFrame.origin.y) / parentFrame.height
                        let normWidth = frame.width / parentFrame.width
                        let normHeight = frame.height / parentFrame.height
                        
                        normalizedFrame = CGRect(x: normX, y: normY, width: normWidth, height: normHeight)
                    }
                }
            }
        }
        
        // Special handling for menu items - sometimes they don't report proper coordinates
        if role == AXAttribute.Role.menuItem {
            // For menu items without valid frames, see if we can derive position from parent menu
            if frameSource == .unavailable || frame.isEmpty {
                if let parentElementObj = try? getAttribute(axElement, attribute: AXAttribute.parent) {
                    if CFGetTypeID(parentElementObj as CFTypeRef) == AXUIElementGetTypeID() {
                        let parentElement = parentElementObj as! AXUIElement
                        
                        // Get parent role to confirm it's a menu
                        if let parentRole = try? getAttribute(parentElement, attribute: AXAttribute.role) as? String,
                           parentRole == AXAttribute.Role.menu {
                            // Get parent frame
                            if let parentFrame = try? getAttribute(parentElement, attribute: AXAttribute.frame) as? NSValue {
                                // Get all menu items and find this item's index
                                if let menuItems = try? getAttribute(parentElement, attribute: AXAttribute.children) as? [AXUIElement] {
                                    // Find our position in the menu
                                    for (index, item) in menuItems.enumerated() {
                                        if CFEqual(item, axElement) {
                                            // Calculate position based on index
                                            // Standard menu item height is around 22-24 points
                                            let menuRect = parentFrame.rectValue
                                            let itemHeight: CGFloat = 24.0
                                            let estimatedY = menuRect.origin.y + CGFloat(index) * itemHeight
                                            
                                            frame = CGRect(
                                                x: menuRect.origin.x,
                                                y: estimatedY,
                                                width: menuRect.width,
                                                height: itemHeight
                                            )
                                            frameSource = .inferred
                                            
                                            // Create normalized coordinates
                                            normalizedFrame = CGRect(
                                                x: 0,
                                                y: CGFloat(index) / CGFloat(menuItems.count),
                                                width: 1.0,
                                                height: 1.0 / CGFloat(menuItems.count)
                                            )
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return (frame, frameSource, normalizedFrame, viewportFrame)
    }
    
    /// Get an attribute from an AXUIElement
    /// - Parameters:
    ///   - element: The AXUIElement to query
    ///   - attribute: The attribute name
    /// - Returns: The attribute value or nil if not available
    public static func getAttribute(_ element: AXUIElement, attribute: String) throws -> Any? {
        // Safety check - validate the element is valid before trying to access it
        // CFGetTypeID doesn't throw, but we're being defensive here
        if CFGetTypeID(element) != AXUIElementGetTypeID() {
            NSLog("WARNING: Invalid AXUIElement passed to getAttribute")
            return nil
        }
        
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if error == .success {
            return value
        } else if error == .attributeUnsupported || error == .noValue || error == .parameterizedAttributeUnsupported {
            // Extended list of "not an error" cases - just means attribute doesn't exist
            return nil
        } else if error == .notImplemented {
            // This specific element doesn't implement this attribute
            NSLog("WARNING: Attribute \(attribute) not implemented for this element")
            return nil
        } else if error == .cannotComplete {
            // Often happens when app is busy or accessibility isn't responding properly
            NSLog("WARNING: Accessibility operation couldn't complete for attribute \(attribute)")
            return nil
        } else if error == .invalidUIElement {
            // The element is no longer valid (window closed, etc.)
            NSLog("WARNING: Invalid UI element when accessing attribute \(attribute)")
            return nil
        } else {
            // Create detailed error with the actual error code and message
            let errorMessage = "Failed to get attribute \(attribute) (code: \(error.rawValue))"
            NSLog("ERROR: \(errorMessage)")
            
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
            )
        }
    }
    
    /// Get the string value for an element, converting non-string values if needed
    private static func getStringValue(for element: AXUIElement) throws -> String? {
        // Use try-catch to handle errors gracefully
        do {
            guard let value = try getAttribute(element, attribute: AXAttribute.value) else { return nil }
            
            // Handle different types of values
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            } else if let boolValue = value as? Bool {
                return boolValue ? "true" : "false"
            } else {
                // Convert other types to a description
                return String(describing: value)
            }
        } catch {
            NSLog("WARNING: Failed to get string value: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get the available action names for an element
    private static func getActionNames(for element: AXUIElement) throws -> [String] {
        // Always use direct API call as it's more reliable
        var actionNamesRef: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionNamesRef)
        
        if result == .success, let actions = actionNamesRef as? [String] {
            return actions
        }
        
        // Fallback to attribute method only if direct API call fails
        if let actionNames = try? getAttribute(element, attribute: AXAttribute.actions) as? [String],
           !actionNames.isEmpty {
            NSLog("Fallback to getAttribute for actions succeeded where AXUIElementCopyActionNames failed")
            return actionNames
        }
        
        // If we get here, no actions were found by either method
        return []
    }
    
    /// Perform an action on an element
    /// - Parameters:
    ///   - element: The element to act on
    ///   - action: The action name
    public static func performAction(_ element: AXUIElement, action: String) throws {
        // Safety check - validate the element is valid before trying to access it
        if CFGetTypeID(element) != AXUIElementGetTypeID() {
            NSLog("WARNING: Invalid AXUIElement passed to performAction")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid element reference"]
            )
        }
        
        // Check that the action is supported by this element
        let actionNames = try? getActionNames(for: element)
        if let actionNames = actionNames, !actionNames.contains(action) {
            NSLog("WARNING: Element does not support action \(action). Available actions: \(actionNames.joined(separator: ", "))")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Element does not support action \(action)"]
            )
        }
        
        // Set a timeout for the action to prevent hanging
        let timeoutStatus = AXUIElementSetMessagingTimeout(element, 1.0) // 1 second timeout
        if timeoutStatus != .success {
            NSLog("WARNING: Failed to set messaging timeout for action \(action)")
        }
        
        // Perform the action
        let error = AXUIElementPerformAction(element, action as CFString)
        
        if error == .success {
            return
        } else if error == .invalidUIElement {
            NSLog("ERROR: Invalid UI element when performing action \(action)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Invalid UI element (may have been destroyed)"]
            )
        } else if error == .cannotComplete {
            NSLog("ERROR: Could not complete action \(action) (element may be busy or unresponsive)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Could not complete action (element busy or unresponsive)"]
            )
        } else if error == .actionUnsupported {
            NSLog("ERROR: Action \(action) is unsupported by this element")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Action \(action) is not supported by this element"]
            )
        } else {
            NSLog("ERROR: Failed to perform action \(action) with error code \(error.rawValue)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to perform action \(action) (error code: \(error.rawValue))"]
            )
        }
    }
    
    /// Set an attribute value
    /// - Parameters:
    ///   - element: The element to modify
    ///   - attribute: The attribute name
    ///   - value: The new value
    public static func setAttribute(
        _ element: AXUIElement,
        attribute: String,
        value: Any
    ) throws {
        // Safety check - validate the element is valid before trying to access it
        if CFGetTypeID(element) != AXUIElementGetTypeID() {
            NSLog("WARNING: Invalid AXUIElement passed to setAttribute")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid element reference"]
            )
        }
        
        // Check if the attribute can be written to
        var isSettable: DarwinBoolean = false
        let settableError = AXUIElementIsAttributeSettable(element, attribute as CFString, &isSettable)
        
        if settableError != .success {
            // If we can't even determine if it's settable, that's a bad sign
            NSLog("WARNING: Could not determine if attribute \(attribute) is settable (error: \(settableError.rawValue))")
        } else if !isSettable.boolValue {
            NSLog("ERROR: Attribute \(attribute) is not settable on this element")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Attribute \(attribute) is not settable"]
            )
        }
        
        // Set a timeout to prevent hanging
        let timeoutStatus = AXUIElementSetMessagingTimeout(element, 1.0) // 1 second timeout
        if timeoutStatus != .success {
            NSLog("WARNING: Failed to set messaging timeout for setAttribute \(attribute)")
        }
        
        // Attempt to set the attribute value
        let error = AXUIElementSetAttributeValue(
            element,
            attribute as CFString,
            value as CFTypeRef
        )
        
        if error == .success {
            return
        } else if error == .attributeUnsupported {
            NSLog("ERROR: Attribute \(attribute) is not supported by this element")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Attribute \(attribute) is not supported"]
            )
        } else if error == .illegalArgument {
            NSLog("ERROR: Illegal argument when setting attribute \(attribute): value type may be incorrect")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Invalid value for attribute \(attribute)"]
            )
        } else if error == .invalidUIElement {
            NSLog("ERROR: Invalid UI element when setting attribute \(attribute)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Invalid UI element (may have been destroyed)"]
            )
        } else if error == .cannotComplete {
            NSLog("ERROR: Could not complete setting attribute \(attribute) (element may be busy)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Could not complete setting attribute (element busy or unresponsive)"]
            )
        } else {
            NSLog("ERROR: Failed to set attribute \(attribute) with error code \(error.rawValue)")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: "Failed to set attribute \(attribute) (error code: \(error.rawValue))"]
            )
        }
    }
    
    /// Get the system-wide element (root of accessibility hierarchy)
    /// - Returns: The system-wide AXUIElement
    public static func systemWideElement() -> AXUIElement {
        return AXUIElementCreateSystemWide()
    }
    
    /// Get an application element by its process ID
    /// - Parameter pid: The process ID
    /// - Returns: The application AXUIElement
    public static func applicationElement(pid: pid_t) -> AXUIElement {
        return AXUIElementCreateApplication(pid)
    }
    
    /// Set a value for an attribute
    /// - Parameters:
    ///   - value: The value to set
    ///   - attribute: The attribute name
    ///   - element: The element to modify
    public static func setValue(
        _ value: Any,
        forAttribute attribute: String,
        ofElement element: AXUIElement
    ) throws {
        try setAttribute(element, attribute: attribute, value: value)
    }

    /// Creates a path segment string for an accessibility element
    /// - Parameters:
    ///   - role: The accessibility role of the element
    ///   - attributes: Key-value pairs of attributes to include in the path
    /// - Returns: A properly formatted path segment string (role[@attr="value"]) without ui:// prefix
    private static func createElementPathString(role: String, attributes: [String: String]) -> String {
        var pathString = role
        
        // Add attributes in format [@key="value"]
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            // Escape quotes in the value to maintain valid syntax
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            pathString += "[@\(key)=\"\(escapedValue)\"]"
        }
        
        return pathString
    }
}