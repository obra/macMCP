// ABOUTME: This file contains utilities for working with the macOS Accessibility API.
// ABOUTME: It provides methods to convert AXUIElement objects to our UIElement model.

import Foundation
import AppKit
import CryptoKit

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
        
        // Get frame with robust error handling
        let frame: CGRect
        do {
            if let axFrame = try getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
                frame = axFrame.rectValue
            } else {
                // Try position and size separately
                do {
                    if let position = try getAttribute(axElement, attribute: AXAttribute.position) as? NSValue,
                       let size = try getAttribute(axElement, attribute: AXAttribute.size) as? NSValue {
                        frame = CGRect(origin: position.pointValue, size: size.sizeValue)
                    } else {
                        frame = .zero
                    }
                } catch {
                    frame = .zero
                }
            }
        } catch {
            frame = .zero
        }
        
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
        
        // Generate a globally unique, stable identifier for this element
        let identifier: String
        do {
            // Step 1: Get the native accessibility identifier if available
            let nativeID = try getAttribute(axElement, attribute: AXAttribute.identifier) as? String
            
            // Check if we have a valid native ID and it meets our requirements
            let validNativeID = nativeID?.isEmpty == false
            
            // We'll use the native ID as part of our identifier structure, but we want
            // to ensure global uniqueness by adding context information
            
            // Create a "fingerprint" of the element using its properties
            var fingerprintParts: [String] = []
            
            // Always include the role as the primary type indicator
            fingerprintParts.append(role)
            
            // Include application context when available - critical for global uniqueness
            if let app = attributes["application"] as? String {
                fingerprintParts.append(app)
            }
            
            // Include position for spatial uniqueness (helpful for grids of similar elements)
            let positionPart = "pos-\(Int(frame.origin.x))-\(Int(frame.origin.y))"
            fingerprintParts.append(positionPart)
            
            // Include size information for additional uniqueness
            let sizePart = "size-\(Int(frame.size.width))-\(Int(frame.size.height))"
            fingerprintParts.append(sizePart)
            
            // Format the element's descriptive information (used for human readability)
            let descriptivePart: String
            if validNativeID {
                // If this element has a native ID, prioritize that as the descriptive part
                descriptivePart = nativeID!
            } else if let title = title, !title.isEmpty {
                // Next priority is the title for common interactive controls
                descriptivePart = title
            } else if let description = description, !description.isEmpty {
                // Next priority is the accessibility description
                descriptivePart = description
            } else if let value = value, !value.isEmpty {
                // Next priority is the value
                descriptivePart = "value-\(value)"
            } else {
                // Fallback to just using role
                descriptivePart = role
            }
            
            // Add the descriptive part to the fingerprint
            fingerprintParts.append("desc-\(descriptivePart)")
            
            // Join all parts and create a hash for the stable part of the identifier
            let fingerprint = fingerprintParts.joined(separator: "::")
            let fingerprintData = fingerprint.data(using: .utf8) ?? Data()
            
            // Generate a hash from the fingerprint
            let hashedID: String
            if #available(macOS 10.15, *) {
                let digest = SHA256.hash(data: fingerprintData)
                let hashBytes = digest.prefix(8)
                hashedID = hashBytes.map { String(format: "%02x", $0) }.joined()
            } else {
                // Fallback for older macOS versions
                let hash = abs(fingerprint.hashValue)
                hashedID = String(format: "%016llx", UInt64(hash))
            }
            
            // Create the final identifier structure
            // Format: [type]:[descriptive-part]:[hash]
            // For common interactive controls like buttons, we include the descriptive part directly
            // in the identifier to make it more recognizable to Claude
            if role == AXAttribute.Role.button || 
               role == AXAttribute.Role.menuItem ||
               role == AXAttribute.Role.checkbox ||
               role == AXAttribute.Role.radioButton ||
               role == AXAttribute.Role.textField {
                
                // For native IDs, preserve them in a consistent format to ensure compatibility
                if validNativeID {
                    identifier = "ui:\(nativeID!):\(hashedID)"
                } else {
                    // Create a more human-readable version for interactive elements
                    identifier = "ui:\(descriptivePart):\(hashedID)"
                }
            } else {
                // For other elements, use a more generic format
                identifier = "ui:\(role):\(hashedID)"
            }
        } catch {
            // On error, generate a fallback UUID with role as prefix
            let fallbackUUID = UUID().uuidString
            let shortUUID = fallbackUUID.prefix(8).lowercased()
            identifier = "ui:\(role):\(shortUUID)"
        }
        
        // Get available actions with robust error handling
        let actions: [String]
        do {
            actions = try getActionNames(for: axElement)
        } catch {
            NSLog("WARNING: Failed to get actions: \(error.localizedDescription)")
            actions = []
        }
        
        // Build the hierarchical path for debugging
        let currentPath = path.isEmpty ? role : "\(path)/\(role)"
        
        // Only log elements at key depths to reduce log spam
        if depth <= 3 || (depth >= 5 && depth <= 6) {
            NSLog("Converting element at depth \(depth): \(currentPath) - \(identifier)")
        }
        
        // Create the element first (without children)
        let element = UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: value, 
            elementDescription: description,
            frame: frame,
            parent: parent,
            attributes: attributes,
            actions: actions
        )
        
        // Recursively get children if requested and we haven't reached max depth
        var children: [UIElement] = []
        
        // Always continue if below the minimum traversal depth (ensures critical controls aren't missed)
        let minimumTraversalDepth = 10
        let shouldTraverse = recursive && (depth < minimumTraversalDepth || depth < maxDepth)
        
        if shouldTraverse {
            do {
                if let axChildren = try getAttribute(axElement, attribute: AXAttribute.children) as? [AXUIElement] {
                    // Prioritize containers with higher depth limits
                    let isLikelyContainer = isControlContainer(role)
                    let isMenuElement = isMenuElement(role)
                    
                    // Use different depth limits based on element type:
                    // - Containers get full depth
                    // - Menus get very shallow depth
                    // - Others get reduced depth
                    let adjustedMaxDepth: Int
                    if isMenuElement {
                        adjustedMaxDepth = min(3, maxDepth) // Very shallow for menus
                    } else if isLikelyContainer {
                        adjustedMaxDepth = maxDepth // Full depth for containers
                    } else {
                        adjustedMaxDepth = maxDepth - 5 // Reduced for other elements
                    }
                    
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
                                let isVisible = (try? getAttribute(axChild, attribute: "AXVisible") as? Bool) ?? true
                                let isEnabled = (try? getAttribute(axChild, attribute: "AXEnabled") as? Bool) ?? true
                                let isHidden = (try? getAttribute(axChild, attribute: "AXHidden") as? Bool) ?? false
                                
                                // For menus, also check if they're actually open
                                let isMenuElement = childRole == "AXMenu" || childRole == "AXMenuBarItem"
                                let isExpanded = isMenuElement ? 
                                    (try? getAttribute(axChild, attribute: "AXExpanded") as? Bool) ?? false : true
                                let isMenuOpened = isMenuElement ? 
                                    (try? getAttribute(axChild, attribute: "AXMenuOpened") as? Bool) ?? false : true
                                
                                // If element isn't visible or available, don't traverse its children
                                let isAvailable = isVisible && isEnabled && !isHidden
                                let isMenuAvailable = !isMenuElement || (isMenuElement && (isExpanded || isMenuOpened))
                                
                                if (!isAvailable || !isMenuAvailable) {
                                    // Only log skips at higher depths to reduce noise
                                    if depth < 3 {
                                        NSLog("SKIPPING invisible element: \(childRole)")
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
                                path: currentPath
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
        return UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: value,
            elementDescription: description,
            frame: frame,
            parent: parent,
            children: children,
            attributes: attributes,
            actions: actions
        )
    }
    
    /// Prioritize children for traversal to find interactive elements more quickly
    private static func prioritizeChildren(_ children: [AXUIElement]) throws -> [AXUIElement] {
        var prioritizedChildren: [(AXUIElement, Int)] = []
        
        for child in children {
            var priority = 5 // Default priority
            
            // Get child role
            if let role = try? getAttribute(child, attribute: AXAttribute.role) as? String {
                // Check if this is a menu element - if so, deprioritize it
                if isMenuElement(role) {
                    priority = 10 // Very low priority - explore after everything else
                }
                // Window elements get highest priority
                else if role == AXAttribute.Role.window {
                    priority = 0
                }
                // Give containers next priority
                else if isControlContainer(role) {
                    priority = 1
                }
                // Interactive controls get next priority
                else if isInteractiveControl(role) {
                    priority = 2
                }
                // Static text and other identifiable elements
                else if role == AXAttribute.Role.staticText || role == AXAttribute.Role.image {
                    priority = 3
                }
                // Everything else
                else {
                    priority = 4
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
                       (element.identifier.lowercased().contains("image") || 
                        element.identifier.lowercased().contains("icon") ||
                        element.identifier.lowercased().contains("picture"))
                
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
            "AXLayoutArea"
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
        
        return skipRoles.contains(role)
    }
    
    /// Create a stub element with basic properties but no children
    /// Used for elements we don't want to fully traverse
    private static func createStubElement(_ axElement: AXUIElement, parent: UIElement?) throws -> UIElement {
        // Get basic properties - with robust error handling
        let role: String = try getAttribute(axElement, attribute: AXAttribute.role) as? String ?? "unknown"
        let title: String? = try? getAttribute(axElement, attribute: AXAttribute.title) as? String
        
        // Just create an identifier from memory address - we won't need deep equality
        let address = UInt(bitPattern: Unmanaged.passUnretained(axElement).toOpaque())
        let identifier = "\(role)_\(title ?? "untitled")_\(address)"
        
        // Get a minimal frame
        let frame: CGRect
        if let axFrame = try? getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
            frame = axFrame.rectValue
        } else {
            frame = .zero
        }
        
        // Create minimal element - no children, empty attributes and actions 
        return UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: nil,
            elementDescription: nil,
            frame: frame,
            parent: parent,
            children: [], // Empty children - don't traverse
            attributes: [:],
            actions: []
        )
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
        // Use try-catch to handle any errors gracefully
        do {
            guard let actionNames = try getAttribute(element, attribute: AXAttribute.actions) as? [String] else {
                return []
            }
            return actionNames
        } catch {
            NSLog("WARNING: Failed to get action names: \(error.localizedDescription)")
            return []
        }
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
}