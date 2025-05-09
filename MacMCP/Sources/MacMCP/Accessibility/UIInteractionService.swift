// ABOUTME: This file implements UI interaction capabilities for macOS applications.
// ABOUTME: It provides methods to interact with UI elements through accessibility APIs.

import Foundation
import AppKit
import Logging

/// Service for interacting with UI elements
public actor UIInteractionService: UIInteractionServiceProtocol {
    /// The logger
    private let logger: Logger
    
    /// The accessibility service for element access
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// A cache of AXUIElements by ID
    private var elementCache: [String: (AXUIElement, Date)] = [:]
    
    /// Maximum age of cached elements in seconds
    private let cacheMaxAge: TimeInterval = 5.0
    
    /// Maximum size of element cache
    private let cacheMaxSize: Int = 50
    
    /// Create a new UI interaction service
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: any AccessibilityServiceProtocol,
        logger: Logger? = nil
    ) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.interaction")
    }
    
    /// Click on a UI element by its identifier
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - appBundleId: Optional bundle ID of the application containing the element
    public func clickElement(identifier: String, appBundleId: String? = nil) async throws {
        print("🖱️ DEBUG: UIInteractionService.clickElement - Starting click operation")
        print("   - Element ID: \(identifier)")
        print("   - App Bundle ID: \(appBundleId ?? "nil")")
        
        logger.debug("Clicking element", metadata: [
            "id": "\(identifier)",
            "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil"
        ])
        
        // Get the matching UIElement for diagnostics before getting the AXUIElement
        var elementContext: [String: String] = [:]
        if let uiElement = try? await findUIElement(identifier: identifier, appBundleId: appBundleId) {
            elementContext = [
                "role": uiElement.role,
                "frame": "\(uiElement.frame)",
                "title": uiElement.title ?? "nil",
                "description": uiElement.elementDescription ?? "nil"
            ]
            
            print("🔍 DEBUG: UIInteractionService.clickElement - Found matching UIElement:")
            print("   - Role: \(uiElement.role)")
            print("   - Frame: (\(uiElement.frame.origin.x), \(uiElement.frame.origin.y), \(uiElement.frame.size.width), \(uiElement.frame.size.height))")
            print("   - Title: \(uiElement.title ?? "nil")")
            print("   - Description: \(uiElement.elementDescription ?? "nil")")
            print("   - Clickable: \(uiElement.isClickable)")
            print("   - Enabled: \(uiElement.isEnabled)")
            print("   - Actions: \(uiElement.actions.joined(separator: ", "))")
            
            // Additional diagnostics for elements that might be problematic
            if !uiElement.isEnabled {
                print("⚠️ DEBUG: UIInteractionService.clickElement - WARNING: Element is NOT enabled, click may fail")
            }
            
            if !uiElement.isClickable {
                print("⚠️ DEBUG: UIInteractionService.clickElement - WARNING: Element is NOT marked as clickable, click may fail")
            }
            
            if uiElement.frame.size.width <= 0 || uiElement.frame.size.height <= 0 {
                print("⚠️ DEBUG: UIInteractionService.clickElement - WARNING: Element has invalid dimensions, click may fail")
            }
            
            // Log children count if any
            if !uiElement.children.isEmpty {
                elementContext["childrenCount"] = "\(uiElement.children.count)"
                print("   - Children count: \(uiElement.children.count)")
            }
            
            // Log parent application if available
            if let app = uiElement.attributes["application"] as? String {
                elementContext["application"] = app
                print("   - Application: \(app)")
            }
            
            // Convert String dictionary to Logger.Metadata
            var elementMetadata: Logger.Metadata = [:]
            for (key, value) in elementContext {
                elementMetadata[key] = .string(value)
            }
            logger.debug("UIElement details", metadata: elementMetadata)
        } else {
            print("⚠️ DEBUG: UIInteractionService.clickElement - WARNING: Could not find UIElement for diagnostics")
        }
        
        print("🔄 DEBUG: UIInteractionService.clickElement - Getting AXUIElement for ID: \(identifier)")
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier, appBundleId: appBundleId)
        print("✅ DEBUG: UIInteractionService.clickElement - Successfully retrieved AXUIElement")
        
        // Log detailed AXUIElement information before interaction
        do {
            // Try to get an attribute that might throw
            _ = try AccessibilityElement.getAttribute(axElement, attribute: "AXRole")
            
            // Start with basic attributes
            let attributes = [
                "AXRole", "AXActions", "AXEnabled", "AXFocused", "AXFrame", 
                "AXTitle", "AXDescription", "AXHelp", "AXParent",
                "AXChildren", "AXIdentifier", "AXWindow"
            ]
            
            var attributeValues: [String: String] = [:]
            
            // Try to get each attribute
            for attribute in attributes {
                var value: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(axElement, attribute as CFString, &value)
                
                if result == .success {
                    if value == nil {
                        attributeValues[attribute] = "nil"
                    } else if let stringValue = value as? String {
                        attributeValues[attribute] = stringValue
                    } else if let boolValue = value as? Bool {
                        attributeValues[attribute] = boolValue ? "true" : "false"
                    } else if let arrayValue = value as? [AXUIElement] {
                        attributeValues[attribute] = "[\(arrayValue.count) elements]"
                    } else if CFGetTypeID(value!) == AXUIElementGetTypeID() {
                        attributeValues[attribute] = "AXUIElement"
                    } else {
                        attributeValues[attribute] = "\(value!)"
                    }
                } else {
                    attributeValues[attribute] = "Error: \(getAXErrorName(result)) (\(result.rawValue))"
                }
            }
            
            // Check if the element has a position
            if let frameString = attributeValues["AXFrame"], frameString != "nil" {
                // Try to get the element's position and size
                var frame: CFTypeRef?
                let frameResult = AXUIElementCopyAttributeValue(axElement, "AXFrame" as CFString, &frame)
                if frameResult == .success, let axFrame = frame as? [String: Any],
                   let x = axFrame["x"] as? CGFloat, let y = axFrame["y"] as? CGFloat,
                   let width = axFrame["width"] as? CGFloat, let height = axFrame["height"] as? CGFloat {
                    attributeValues["AXPosition"] = "{\(x), \(y)}"
                    attributeValues["AXSize"] = "{\(width), \(height)}"
                }
            }
            
            // Try to get the process ID of the element
            var pid: pid_t = 0
            let pidResult = AXUIElementGetPid(axElement, &pid)
            if pidResult == .success {
                attributeValues["ProcessID"] = "\(pid)"
                
                // Try to get the application name
                if let app = NSRunningApplication(processIdentifier: pid) {
                    attributeValues["ApplicationName"] = app.localizedName ?? "unknown"
                    attributeValues["BundleID"] = app.bundleIdentifier ?? "unknown"
                }
            }
            
            // Log all the attributes we found
            // Convert attribute values to Logger.Metadata
            var attributesMetadata: Logger.Metadata = [:]
            for (key, value) in attributeValues {
                attributesMetadata[key] = .string(value)
            }
            logger.debug("AXUIElement attributes", metadata: attributesMetadata)
            
            // Get available actions if possible
            var actions: CFTypeRef?
            let actionsResult = AXUIElementCopyAttributeValue(axElement, "AXActions" as CFString, &actions)
            
            if actionsResult == .success, let actionsList = actions as? [String] {
                logger.debug("Available actions", metadata: [
                    "id": .string(identifier),
                    "actions": .string(actionsList.joined(separator: ", "))
                ])
            }
        } catch {
            logger.warning("Error retrieving element details", metadata: [
                "id": .string(identifier),
                "error": .string(error.localizedDescription)
            ])
        }
        
        // Try to perform the click action
        do {
            try performAction(axElement, action: AXAttribute.Action.press)
            logger.debug("AXPress succeeded", metadata: ["id": .string(identifier)])
        } catch {
            // Get detailed error info
            let nsError = error as NSError
            
            logger.error("AXPress failed", metadata: [
                "id": .string(identifier),
                "error": .string(error.localizedDescription),
                "domain": .string(nsError.domain),
                "code": .string("\(nsError.code)"),
                "userInfo": .string("\(nsError.userInfo)")
            ])
            
            // Create a more informative error with context and suggestions
            var context: [String: String] = [
                "elementId": identifier,
                "errorCode": "\(nsError.code)",
                "errorDomain": nsError.domain
            ]
            
            // Merge in element context if available
            for (key, value) in elementContext {
                context["element_\(key)"] = value
            }
            
            // Add specific details for known error codes
            var errorMessage = "Failed to perform click action on element"
            if nsError.code == -25200 {
                errorMessage = "Element not pressable (AXError -25200). This commonly occurs when the element doesn't support direct interaction or has an incorrect role."
            } else if nsError.code == -25204 {
                errorMessage = "Operation timed out (AXError -25204). The element might be busy or unresponsive."
            } else if nsError.code == -25205 {
                errorMessage = "Element not enabled (AXError -25205). The element might be disabled in the UI."
            } else if nsError.code == -25208 {
                errorMessage = "Element not visible (AXError -25208). The element might be off-screen or hidden."
            }
            
            throw createInteractionError(
                message: errorMessage,
                context: context,
                underlyingError: error
            )
        }
    }
    
    /// Click at a specific screen position
    /// - Parameter position: The screen position to click
    public func clickAtPosition(position: CGPoint) async throws {
        logger.debug("Clicking at position", metadata: [
            "x": "\(position.x)", "y": "\(position.y)"
        ])
        
        // Get the element at the position (if any) using a separate task to avoid data races
        // Create a detached task that doesn't capture 'self'
        let elementAtPosition = await Task.detached {
            // Capture a local copy of the service
            let localAccessibilityService = self.accessibilityService
            let localPosition = position
            
            do {
                // Use a local copy of the service
                return try await localAccessibilityService.getUIElementAtPosition(
                    position: localPosition,
                    recursive: false,
                    maxDepth: 1
                )
            } catch {
                return nil
            }
        }.value
        
        if let element = elementAtPosition {
            // If we found an element, click it
            try await clickElement(identifier: element.identifier)
        } else {
            // If no element found, use the lower-level mouse event API
            try simulateMouseClick(at: position)
        }
    }
    
    /// Double click on a UI element
    /// - Parameter identifier: The UI element identifier
    public func doubleClickElement(identifier: String) async throws {
        logger.debug("Double-clicking element", metadata: ["id": "\(identifier)"])
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier)
        
        // For double click, we check if the element has a dedicated action
        let actions = try getActionNames(for: axElement)
        
        if actions.contains("AXDoubleClick") {
            // Use the dedicated action if available
            try performAction(axElement, action: "AXDoubleClick")
        } else {
            // Otherwise, simulate two rapid clicks
            try performAction(axElement, action: AXAttribute.Action.press)
            try await Task.sleep(for: .milliseconds(50))
            try performAction(axElement, action: AXAttribute.Action.press)
        }
    }
    
    /// Right click on a UI element
    /// - Parameter identifier: The UI element identifier
    public func rightClickElement(identifier: String) async throws {
        logger.debug("Right-clicking element", metadata: ["id": "\(identifier)"])
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier)
        
        // Check for a show menu action, which is typically equivalent to right-click
        let actions = try getActionNames(for: axElement)
        
        if actions.contains(AXAttribute.Action.showMenu) {
            try performAction(axElement, action: AXAttribute.Action.showMenu)
        } else {
            // If no show menu action, get the position and simulate a right click
            guard let element = try await findUIElement(identifier: identifier) else {
                throw createError("Element not found for right-click", code: 2001)
            }
            
            let position = CGPoint(
                x: element.frame.origin.x + element.frame.size.width / 2,
                y: element.frame.origin.y + element.frame.size.height / 2
            )
            
            try simulateMouseRightClick(at: position)
        }
    }
    
    /// Type text into a UI element
    /// - Parameters:
    ///   - elementIdentifier: The UI element identifier
    ///   - text: The text to type
    public func typeText(elementIdentifier: String, text: String) async throws {
        logger.debug("Typing text into element", metadata: [
            "id": "\(elementIdentifier)", 
            "textLength": "\(text.count)"
        ])
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: elementIdentifier)
        
        // Check if the element accepts text input
        let role = try AccessibilityElement.getAttribute(axElement, attribute: AXAttribute.role) as? String
        
        if role == AXAttribute.Role.textField || role == AXAttribute.Role.textArea {
            // For text fields, set the value directly
            try AccessibilityElement.setAttribute(
                axElement,
                attribute: AXAttribute.value,
                value: text
            )
        } else {
            // For other elements, try to set focus and use key events
            let focusParams = AXUIElementSetMessagingTimeout(axElement, 1.0)
            guard focusParams == .success else {
                throw createError("Failed to set messaging timeout", code: 2002)
            }
            
            // Set focus to the element
            try AccessibilityElement.setAttribute(
                axElement,
                attribute: "AXFocused",
                value: true
            )
            
            // Give UI time to update focus
            try await Task.sleep(for: .milliseconds(100))
            
            // Type the text character by character using key events
            for char in text {
                try simulateKeyPress(character: char)
                try await Task.sleep(for: .milliseconds(20))
            }
        }
    }
    
    /// Press a specific key on the keyboard
    /// - Parameter keyCode: The key code to press
    public func pressKey(keyCode: Int) async throws {
        logger.debug("Pressing key", metadata: ["keyCode": "\(keyCode)"])
        
        let keyDownEvent = CGEvent(
            keyboardEventSource: CGEventSource(stateID: .combinedSessionState),
            virtualKey: CGKeyCode(keyCode),
            keyDown: true
        )
        
        let keyUpEvent = CGEvent(
            keyboardEventSource: CGEventSource(stateID: .combinedSessionState),
            virtualKey: CGKeyCode(keyCode),
            keyDown: false
        )
        
        guard let keyDownEvent = keyDownEvent, let keyUpEvent = keyUpEvent else {
            throw createError("Failed to create key events", code: 2003)
        }
        
        keyDownEvent.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(50))
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    /// Drag and drop from one element to another
    /// - Parameters:
    ///   - sourceIdentifier: The source element identifier
    ///   - targetIdentifier: The target element identifier
    public func dragElement(sourceIdentifier: String, targetIdentifier: String) async throws {
        logger.debug("Dragging element", metadata: [
            "sourceId": "\(sourceIdentifier)",
            "targetId": "\(targetIdentifier)"
        ])
        
        // Get source and target elements
        guard let sourceElement = try await findUIElement(identifier: sourceIdentifier) else {
            throw createError("Source element not found for drag", code: 2004)
        }
        
        guard let targetElement = try await findUIElement(identifier: targetIdentifier) else {
            throw createError("Target element not found for drag", code: 2005)
        }
        
        // Calculate source and target center points
        let sourceCenter = CGPoint(
            x: sourceElement.frame.origin.x + sourceElement.frame.size.width / 2,
            y: sourceElement.frame.origin.y + sourceElement.frame.size.height / 2
        )
        
        let targetCenter = CGPoint(
            x: targetElement.frame.origin.x + targetElement.frame.size.width / 2,
            y: targetElement.frame.origin.y + targetElement.frame.size.height / 2
        )
        
        // Perform the drag operation
        try simulateMouseDrag(from: sourceCenter, to: targetCenter)
    }
    
    /// Scroll a UI element
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - direction: The scroll direction
    ///   - amount: The amount to scroll (normalized 0-1)
    public func scrollElement(identifier: String, direction: ScrollDirection, amount: Double) async throws {
        logger.debug("Scrolling element", metadata: [
            "id": "\(identifier)",
            "direction": "\(direction)",
            "amount": "\(amount)"
        ])
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier)
        
        // Check for scroll actions
        let actions = try getActionNames(for: axElement)
        
        // Map direction to scroll action
        let scrollAction: String
        switch direction {
        case .up:
            scrollAction = "AXScrollUp"
        case .down:
            scrollAction = "AXScrollDown"
        case .left:
            scrollAction = "AXScrollLeft"
        case .right:
            scrollAction = "AXScrollRight"
        }
        
        // Check if the element supports the specific scroll action
        if actions.contains(scrollAction) {
            // Convert normalized amount to number of actions (1-10)
            let scrollCount = max(1, min(10, Int(amount * 10)))
            
            // Perform the scroll action the calculated number of times
            for _ in 0..<scrollCount {
                try performAction(axElement, action: scrollAction)
                try await Task.sleep(for: .milliseconds(50))
            }
        } else if actions.contains(AXAttribute.Action.scrollToVisible) {
            // If only scroll to visible is available, use it
            try performAction(axElement, action: AXAttribute.Action.scrollToVisible)
        } else {
            // If no scroll actions, try to simulate a scroll event
            guard let element = try await findUIElement(identifier: identifier) else {
                throw createError("Element not found for scrolling", code: 2006)
            }
            
            let position = CGPoint(
                x: element.frame.origin.x + element.frame.size.width / 2,
                y: element.frame.origin.y + element.frame.size.height / 2
            )
            
            // Convert direction and amount to scroll units
            let scrollDeltaX: Int
            let scrollDeltaY: Int
            
            switch direction {
            case .up:
                scrollDeltaX = 0
                scrollDeltaY = -Int(amount * 10)
            case .down:
                scrollDeltaX = 0
                scrollDeltaY = Int(amount * 10)
            case .left:
                scrollDeltaX = -Int(amount * 10)
                scrollDeltaY = 0
            case .right:
                scrollDeltaX = Int(amount * 10)
                scrollDeltaY = 0
            }
            
            try simulateScrollWheel(at: position, deltaX: scrollDeltaX, deltaY: scrollDeltaY)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the AXUIElement for an element identifier
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - appBundleId: Optional bundle ID of the application containing the element
    private func getAXUIElement(for identifier: String, appBundleId: String? = nil) async throws -> AXUIElement {
        // Clean old entries from cache if it's getting too large
        cleanCache()
        
        // Generate cache key - include app bundle ID if provided
        let cacheKey = appBundleId != nil ? "\(appBundleId!):\(identifier)" : identifier
        
        // Check the cache first
        if let (element, timestamp) = elementCache[cacheKey] {
            // Check if the cached element is too old
            let now = Date()
            if now.timeIntervalSince(timestamp) > cacheMaxAge {
                logger.debug("Cached element is too old, removing from cache", metadata: [
                    "id": "\(identifier)",
                    "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
                    "age": "\(now.timeIntervalSince(timestamp))"
                ])
                elementCache.removeValue(forKey: cacheKey)
            } 
            // Verify the cached element is still valid before returning
            else if AccessibilityPermissions.isAccessibilityEnabled() {
                // Basic validity check - this isn't foolproof but helps catch some cases
                var dummy: CFTypeRef?
                let error = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &dummy)
                
                if error != .invalidUIElement {
                    // Element appears to be valid, refresh its timestamp and return it
                    logger.debug("Using cached element", metadata: ["id": "\(identifier)"])
                    elementCache[cacheKey] = (element, Date())
                    return element
                } else {
                    // Element is no longer valid, remove from cache
                    logger.debug("Cached element is no longer valid, removing from cache", metadata: ["id": "\(identifier)"])
                    elementCache.removeValue(forKey: cacheKey)
                }
            }
        }
        
        // Log what we're doing
        logger.debug("Looking up UI element by identifier", metadata: [
            "id": "\(identifier)",
            "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil"
        ])
        
        // Try to find the element in the UI hierarchy - specifically looking for elements with valid frames
        guard let uiElement = try await findInteractableUIElement(identifier: identifier, appBundleId: appBundleId) else {
            logger.error("Element not found in UI hierarchy", metadata: [
                "id": "\(identifier)",
                "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil"
            ])
            throw createError("Element not found: \(identifier)", code: 2000)
        }
        
        logger.debug("Found element in UI hierarchy", metadata: [
            "id": "\(identifier)",
            "role": "\(uiElement.role)",
            "frameOriginX": "\(uiElement.frame.origin.x)",
            "frameOriginY": "\(uiElement.frame.origin.y)",
            "frameWidth": "\(uiElement.frame.size.width)",
            "frameHeight": "\(uiElement.frame.size.height)"
        ])
        
        // For now, we'll need to get the element again from the system-wide element
        // This is because we don't store the actual AXUIElement in our UIElement model
        let systemWide = AccessibilityElement.systemWideElement()
        
        // Get the position of the element
        let position = CGPoint(
            x: uiElement.frame.origin.x + uiElement.frame.size.width / 2,
            y: uiElement.frame.origin.y + uiElement.frame.size.height / 2
        )
        
        // Log the position we're querying
        logger.debug("Querying element at position", metadata: [
            "id": "\(identifier)",
            "x": "\(position.x)",
            "y": "\(position.y)"
        ])
        
        // Verify the position is valid - coordinates at (0,0) with zero size are definitely invalid
        // But elements at screen edges (x=0 or y=0) with non-zero size can be valid
        if (position.x <= 0 && position.y <= 0) && (uiElement.frame.size.width <= 0 || uiElement.frame.size.height <= 0) {
            logger.error("Element has invalid position and size. Cannot use this element.", metadata: [
                "id": "\(identifier)",
                "x": "\(position.x)",
                "y": "\(position.y)",
                "width": "\(uiElement.frame.size.width)",
                "height": "\(uiElement.frame.size.height)",
                "role": "\(uiElement.role)"
            ])
            
            // Reject elements with zero coordinates and size
            throw createError(
                "Element \(identifier) has invalid position (x=\(position.x), y=\(position.y)) and size.",
                code: 2010
            )
        }
        
        // Use AXUIElementCopyElementAtPosition to get the element at the position
        var foundElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(position.x),
            Float(position.y),
            &foundElement
        )
        
        if error != .success || foundElement == nil {
            logger.warning("Failed to get element at position, trying direct application search", metadata: [
                "id": "\(identifier)",
                "x": "\(position.x)",
                "y": "\(position.y)",
                "error": "\(error.rawValue)"
            ])
            
            // Try a second approach - get all the windows from the application and search them
            if let applicationTitle = uiElement.attributes["application"] as? String,
               let applicationElement = try? await findApplicationByTitle(applicationTitle) {
                
                logger.debug("Trying to find element by searching application", metadata: [
                    "id": "\(identifier)",
                    "application": "\(applicationTitle)"
                ])
                
                // Get windows and search through them
                if let axElement = try await searchApplicationForElement(applicationElement, matchingId: identifier) {
                    // Before using this element, verify it has BOTH a valid frame AND is interactable
                    
                    // 1. Check for valid frame
                    var validFrame = false
                    var positionValue: CFTypeRef?
                    var sizeValue: CFTypeRef?
                    
                    if AXUIElementCopyAttributeValue(axElement, "AXPosition" as CFString, &positionValue) == .success,
                       AXUIElementCopyAttributeValue(axElement, "AXSize" as CFString, &sizeValue) == .success {
                        
                        // Extract position and size values
                        var point = CGPoint.zero
                        var size = CGSize.zero
                        
                        if CFGetTypeID(positionValue!) == AXValueGetTypeID() &&
                           CFGetTypeID(sizeValue!) == AXValueGetTypeID() &&
                           AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) &&
                           AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                            
                            // Check if position and size are valid
                            if (point.x > 0 || point.y > 0) && size.width > 0 && size.height > 0 {
                                validFrame = true
                                
                                // Log the valid frame we found
                                logger.debug("Found element with valid frame via application search", metadata: [
                                    "id": "\(identifier)",
                                    "x": "\(point.x)",
                                    "y": "\(point.y)",
                                    "width": "\(size.width)",
                                    "height": "\(size.height)"
                                ])
                            }
                        }
                    }
                    
                    if !validFrame {
                        logger.warning("Element found via application search has invalid frame", metadata: ["id": "\(identifier)"])
                        // Cannot use this element, throw error
                        throw createError(
                            "Element \(identifier) has invalid frame.",
                            code: 2011
                        )
                    }
                    
                    // 2. Check if the element is interactable
                    var isInteractable = false
                    
                    // Check role
                    var roleValue: CFTypeRef?
                    if AXUIElementCopyAttributeValue(axElement, "AXRole" as CFString, &roleValue) == .success,
                       let roleString = roleValue as? String,
                       roleString == uiElement.role {
                        isInteractable = true
                    }
                    
                    // Check actions
                    var actionNames: CFArray?
                    if AXUIElementCopyActionNames(axElement, &actionNames) == .success,
                       let actions = actionNames as? [String],
                       actions.contains(AXAttribute.Action.press) {
                        isInteractable = true
                    }
                    
                    if !isInteractable {
                        logger.warning("Element found via application search is not interactable", metadata: ["id": "\(identifier)"])
                        // Cannot use this element, throw error
                        throw createError(
                            "Element \(identifier) is not interactable.",
                            code: 2012
                        )
                    }
                    
                    // If we got here, this is a good element to use
                    logger.debug("Using element found via application search", metadata: ["id": "\(identifier)"])
                    elementCache[identifier] = (axElement, Date())
                    return axElement
                }
            }
            
            throw createError(
                "Failed to get AXUIElement for \(identifier) at position \(position), error: \(error.rawValue)",
                code: 2000
            )
        }
        
        guard let axElement = foundElement else {
            logger.error("No element found at position", metadata: [
                "id": "\(identifier)",
                "x": "\(position.x)",
                "y": "\(position.y)"
            ])
            throw createError(
                "No element found at position \(position) for \(identifier)",
                code: 2000
            )
        }
        
        // Verify the element we found is what we expect
        var role: CFTypeRef?
        let roleError = AXUIElementCopyAttributeValue(axElement, "AXRole" as CFString, &role)
        
        if roleError == .success, let roleString = role as? String {
            logger.debug("Found element at position", metadata: [
                "id": "\(identifier)",
                "role": "\(roleString)"
            ])
            
            // Verify the role matches what we expect
            if roleString != uiElement.role {
                logger.warning("Element role mismatch", metadata: [
                    "id": "\(identifier)",
                    "expectedRole": "\(uiElement.role)",
                    "actualRole": "\(roleString)"
                ])
            }
        } else {
            logger.warning("Could not verify element role", metadata: [
                "id": "\(identifier)",
                "error": "\(roleError.rawValue)"
            ])
        }
        
        // Check if the element supports AXPress action
        var actionNames: CFArray?
        let actionResult = AXUIElementCopyActionNames(axElement, &actionNames)
        
        if actionResult == .success, let actions = actionNames as? [String] {
            if !actions.contains(AXAttribute.Action.press) {
                logger.warning("Element does not support AXPress action", metadata: [
                    "id": "\(identifier)",
                    "availableActions": "\(actions.joined(separator: ", "))"
                ])
            }
        }
        
        // Cache the element with current timestamp
        elementCache[identifier] = (axElement, Date())
        
        return axElement
    }
    
    /// Find an application element by its title
    private func findApplicationByTitle(_ title: String) async throws -> AXUIElement? {
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Find the application with the matching title
        for app in runningApps {
            if app.localizedName == title {
                return AccessibilityElement.applicationElement(pid: app.processIdentifier)
            }
        }
        
        return nil
    }
    
    /// Search an application for an element with a specific ID
    private func searchApplicationForElement(_ application: AXUIElement, matchingId id: String) async throws -> AXUIElement? {
        // Get the windows from the application
        var windowsRef: CFTypeRef?
        let windowsError = AXUIElementCopyAttributeValue(application, "AXWindows" as CFString, &windowsRef)
        
        if windowsError != .success || windowsRef == nil {
            logger.warning("Failed to get windows from application", metadata: [
                "id": "\(id)",
                "error": "\(windowsError.rawValue)"
            ])
            return nil
        }
        
        guard let windows = windowsRef as? [AXUIElement] else {
            logger.warning("Windows not in expected format", metadata: ["id": "\(id)"])
            return nil
        }
        
        // Search through each window
        for window in windows {
            if let element = try await searchElementAndChildren(window, matchingId: id) {
                return element
            }
        }
        
        return nil
    }
    
    /// Clean old or excessive entries from the cache
    private func cleanCache() {
        // If the cache is relatively small, don't bother cleaning
        if elementCache.count < cacheMaxSize / 2 {
            return
        }
        
        // Current time for age checks
        let now = Date()
        
        // First, remove any expired entries
        for (id, (_, timestamp)) in elementCache {
            if now.timeIntervalSince(timestamp) > cacheMaxAge {
                elementCache.removeValue(forKey: id)
            }
        }
        
        // If still too many entries, remove oldest ones
        if elementCache.count > cacheMaxSize {
            let sortedEntries = elementCache.sorted { $0.value.1 < $1.value.1 }
            let entriesToRemove = sortedEntries.prefix(elementCache.count - cacheMaxSize / 2)
            
            for (id, _) in entriesToRemove {
                elementCache.removeValue(forKey: id)
            }
            
            logger.debug("Cleaned \(entriesToRemove.count) old elements from cache", metadata: [
                "remainingCacheSize": "\(elementCache.count)"
            ])
        }
    }
    
    /// Recursively search an element and its children for an element with a specific ID
    private func searchElementAndChildren(_ element: AXUIElement, matchingId id: String) async throws -> AXUIElement? {
        // Check if this element matches the ID
        var identifier: CFTypeRef?
        let idError = AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &identifier)
        
        if idError == .success, let elementId = identifier as? String, elementId == id {
            return element
        }
        
        // Get the children
        var childrenRef: CFTypeRef?
        let childrenError = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        
        if childrenError != .success || childrenRef == nil {
            return nil
        }
        
        guard let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        // Search through each child
        for child in children {
            if let match = try await searchElementAndChildren(child, matchingId: id) {
                return match
            }
        }
        
        return nil
    }
    
    /// Find a UI element by identifier
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - appBundleId: Optional bundle ID of the application containing the element
    private func findUIElement(identifier: String, appBundleId: String? = nil) async throws -> UIElement? {
        logger.debug("Searching for UI element", metadata: [
            "id": "\(identifier)",
            "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil"
        ])
        
        // Try multiple search strategies for more robust element finding
        
        // Strategy 0 (if app bundle ID provided): Search directly in the specified application
        if let bundleId = appBundleId {
            do {
                logger.debug("Strategy 0: Searching in specific application", metadata: ["bundleId": "\(bundleId)"])
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 25
                )
                
                if let element = await findElementById(appElement, id: identifier) {
                    logger.debug("Found element in specified app", metadata: [
                        "id": "\(identifier)", 
                        "bundleId": "\(bundleId)"
                    ])
                    return element
                }
            } catch {
                // If this fails, continue to the next strategy
                logger.warning("Strategy 0 (specified app) failed: \(error.localizedDescription)")
            }
        }
        
        // Strategy 1: Search the focused application first (most likely to contain the element)
        do {
            let focusedApp = try await accessibilityService.getFocusedApplicationUIElement(
                recursive: true,
                maxDepth: 25
            )
            
            if let element = await findElementById(focusedApp, id: identifier) {
                logger.debug("Found element in focused app", metadata: ["id": "\(identifier)"])
                return element
            }
        } catch {
            // If this fails, continue to the next strategy
            logger.warning("Strategy 1 (focused app) failed: \(error.localizedDescription)")
        }
        
        // Strategy 2: Try system-wide search with deeper traversal
        do {
            let systemElement = try await accessibilityService.getSystemUIElement(
                recursive: true,
                maxDepth: 25 
            )
            
            if let element = await findElementById(systemElement, id: identifier) {
                logger.debug("Found element in system-wide search", metadata: ["id": "\(identifier)"])
                return element
            }
        } catch {
            // If this fails, continue to the next strategy
            logger.warning("Strategy 2 (system element) failed: \(error.localizedDescription)")
        }
        
        // We've tried standard methods, search is complete
        
        logger.warning("Element not found in any location", metadata: ["id": "\(identifier)"])
        return nil
    }
    
    /// Find an interactable UI element by identifier with valid frame and clickable properties
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - appBundleId: Optional bundle ID of the application containing the element
    private func findInteractableUIElement(identifier: String, appBundleId: String? = nil) async throws -> UIElement? {
        logger.debug("Searching for interactable UI element", metadata: [
            "id": "\(identifier)",
            "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil"
        ])
        
        // First, get all possible matches for the identifier
        var possibleMatches: [UIElement] = []
        
        // If we have a specific app bundle ID, search within that application first
        if let bundleId = appBundleId {
            do {
                logger.debug("Searching within specific application", metadata: ["bundleId": "\(bundleId)"])
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 25
                )
                
                // Collect all possible matches
                await collectElementsById(appElement, id: identifier, into: &possibleMatches)
                
                if !possibleMatches.isEmpty {
                    logger.debug("Found \(possibleMatches.count) matches in application", metadata: ["bundleId": "\(bundleId)"])
                }
            } catch {
                logger.warning("Failed to search application: \(error.localizedDescription)", metadata: ["bundleId": "\(bundleId)"])
            }
        }
        
        // If we still don't have matches or no app bundle ID was provided, try the focused application
        if possibleMatches.isEmpty {
            do {
                let focusedApp = try await accessibilityService.getFocusedApplicationUIElement(
                    recursive: true,
                    maxDepth: 25
                )
                
                // Collect all possible matches
                await collectElementsById(focusedApp, id: identifier, into: &possibleMatches)
            } catch {
                logger.warning("Failed to search focused app: \(error.localizedDescription)")
            }
        }
        
        // If we still didn't find any matches, try system-wide
        if possibleMatches.isEmpty {
            do {
                let systemElement = try await accessibilityService.getSystemUIElement(
                    recursive: true,
                    maxDepth: 25
                )
                
                // Collect all possible matches
                await collectElementsById(systemElement, id: identifier, into: &possibleMatches)
            } catch {
                logger.warning("Failed to search system element: \(error.localizedDescription)")
            }
        }
        
        // Filter out elements with zero coordinates or zero-sized frames
        let validMatches = possibleMatches.filter { element in
            // Never include elements with zero coordinates or zero-sized frames
            let hasValidPosition = element.frame.origin.x != 0 || element.frame.origin.y != 0
            let hasValidSize = element.frame.size.width > 0 && element.frame.size.height > 0
            
            return hasValidPosition && hasValidSize
        }
        
        // Log the filtering results
        logger.debug("Found \(possibleMatches.count) total matches, \(validMatches.count) have valid frames", 
                    metadata: ["id": "\(identifier)"])
        
        // If we don't have any valid matches after filtering, return nil
        if validMatches.isEmpty {
            logger.warning("No valid matches found for element (all have zero coordinates or frames)", 
                          metadata: ["id": "\(identifier)"])
            
            // Additional debug info about the invalid matches
            for (index, element) in possibleMatches.prefix(5).enumerated() {
                logger.debug("Invalid match \(index+1)", metadata: [
                    "id": "\(element.identifier)",
                    "role": "\(element.role)",
                    "frame": "{\(element.frame.origin.x), \(element.frame.origin.y), \(element.frame.size.width), \(element.frame.size.height)}",
                    "clickable": "\(element.isClickable)",
                    "enabled": "\(element.isEnabled)"
                ])
            }
            
            return nil
        }
        
        // Sort valid matches by priority:
        // 1. Elements that are considered clickable
        // 2. Elements with expected role (button, etc.)
        // 3. Elements from the expected application
        
        let sortedMatches = validMatches.sorted { (a, b) in
            // First priority: clickable status
            if a.isClickable && !b.isClickable {
                return true
            } else if !a.isClickable && b.isClickable {
                return false
            }
            
            // Second priority: button-like role
            let aIsButton = a.role == AXAttribute.Role.button || 
                           a.role == AXAttribute.Role.checkbox || 
                           a.role == AXAttribute.Role.radioButton || 
                           a.role == AXAttribute.Role.menuItem
            
            let bIsButton = b.role == AXAttribute.Role.button ||
                           b.role == AXAttribute.Role.checkbox ||
                           b.role == AXAttribute.Role.radioButton ||
                           b.role == AXAttribute.Role.menuItem
            
            if aIsButton && !bIsButton {
                return true
            } else if !aIsButton && bIsButton {
                return false
            }
            
            // Third priority: enabled status
            if a.isEnabled && !b.isEnabled {
                return true
            } else if !a.isEnabled && b.isEnabled {
                return false
            }
            
            // Fourth priority: frame size (larger frames might be more visible/significant)
            let aFrameArea = a.frame.size.width * a.frame.size.height
            let bFrameArea = b.frame.size.width * b.frame.size.height
            
            return aFrameArea > bFrameArea
        }
        
        // Return the best match (first element after sorting)
        if let bestMatch = sortedMatches.first {
            logger.debug("Selected best match for element", metadata: [
                "id": "\(identifier)",
                "role": "\(bestMatch.role)",
                "frame": "{\(bestMatch.frame.origin.x), \(bestMatch.frame.origin.y), \(bestMatch.frame.size.width), \(bestMatch.frame.size.height)}",
                "clickable": "\(bestMatch.isClickable)",
                "enabled": "\(bestMatch.isEnabled)"
            ])
            return bestMatch
        }
        
        return nil
    }
    
    /// Collect all elements matching an ID into the provided array
    private func collectElementsById(_ root: UIElement, id: String, into matches: inout [UIElement]) async {
        // Check if this element matches the ID
        if isMatchingElement(root, id: id) {
            matches.append(root)
        }
        
        // Search children
        for child in root.children {
            await collectElementsById(child, id: id, into: &matches)
        }
    }
    
    /// Check if an element matches the specified ID
    private func isMatchingElement(_ element: UIElement, id: String) -> Bool {
        // Exact match
        if element.identifier == id {
            return true
        }
        
        // Handle structured ID format
        if id.hasPrefix("ui:") && element.identifier.hasPrefix("ui:") {
            let idParts = id.split(separator: ":")
            let elementIdParts = element.identifier.split(separator: ":")
            
            if idParts.count >= 3 && elementIdParts.count >= 3 {
                // Match by descriptive part
                if idParts[1] == elementIdParts[1] {
                    return true
                }
                
                // Match by hash part
                if idParts.count > 2 && elementIdParts.count > 2 && idParts[2] == elementIdParts[2] {
                    return true
                }
            }
        }
        
        // For button-like elements, match by title or description
        if element.role == AXAttribute.Role.button || 
           element.role == AXAttribute.Role.menuItem || 
           element.role == AXAttribute.Role.checkbox || 
           element.role == AXAttribute.Role.radioButton {
            
            if let title = element.title, title == id {
                return true
            }
            
            if let desc = element.elementDescription, desc == id {
                return true
            }
        }
        
        return false
    }
    
    /// Recursively find an element by ID
    private func findElementById(_ root: UIElement, id: String, path: String = "") async -> UIElement? {
        // Build the current path for logging
        let currentPath = path.isEmpty ? root.role : "\(path)/\(root.role)"
        
        // Check if this is the element we're looking for - with comprehensive ID matching
        // First, try exact ID match
        if root.identifier == id {
            logger.debug("Found element by exact ID match", metadata: [
                "id": "\(id)",
                "path": "\(currentPath)",
                "role": "\(root.role)",
                "title": "\(root.title ?? "untitled")"
            ])
            return root
        }
        
        // Handle our structured ID format
        if id.hasPrefix("ui:") && root.identifier.hasPrefix("ui:") {
            // Both IDs use our structured format ui:[descriptive-part]:[hash]
            // Split the parts and compare
            let idParts = id.split(separator: ":")
            let rootIdParts = root.identifier.split(separator: ":")
            
            // Check if we have valid structured IDs with 3 parts 
            if idParts.count >= 3 && rootIdParts.count >= 3 {
                // For identical descriptor parts, consider it a match
                if idParts[1] == rootIdParts[1] {
                    logger.debug("Found element by matching descriptive part in structured ID", metadata: [
                        "requestedId": "\(id)",
                        "actualId": "\(root.identifier)",
                        "descriptivePart": "\(idParts[1])",
                        "path": "\(currentPath)",
                        "role": "\(root.role)"
                    ])
                    return root
                }
                
                // For interactive controls like buttons, also check descriptor part against title/description
                if let title = root.title, !title.isEmpty, idParts[1] == title {
                    logger.debug("Found element by matching title to ID descriptive part", metadata: [
                        "requestedId": "\(id)",
                        "actualId": "\(root.identifier)",
                        "title": "\(title)",
                        "path": "\(currentPath)",
                        "role": "\(root.role)"
                    ])
                    return root
                }
                
                // Check description field too
                if let desc = root.elementDescription, !desc.isEmpty, idParts[1] == desc {
                    logger.debug("Found element by matching description to ID descriptive part", metadata: [
                        "requestedId": "\(id)",
                        "actualId": "\(root.identifier)",
                        "description": "\(desc)",
                        "path": "\(currentPath)",
                        "role": "\(root.role)"
                    ])
                    return root
                }
                
                // For hash-based matching, compare hash parts
                if idParts.count > 2 && rootIdParts.count > 2 && idParts[2] == rootIdParts[2] {
                    logger.debug("Found element by matching hash part in structured ID", metadata: [
                        "requestedId": "\(id)",
                        "actualId": "\(root.identifier)",
                        "hashPart": "\(idParts[2])",
                        "path": "\(currentPath)",
                        "role": "\(root.role)"
                    ])
                    return root
                }
            }
        }
        
        // Backward compatibility for legacy ID formats
        if root.identifier.contains(id) || id.contains(root.identifier) {
            // For small IDs (likely from accessibility AXIdentifier), require exact substring match
            if id.count < 20 || root.identifier.count < 20 {
                if root.identifier == id || 
                   (root.identifier.contains(id) && id.count > 3) ||
                   (id.contains(root.identifier) && root.identifier.count > 3) {
                    logger.debug("Found element by substring ID match", metadata: [
                        "requestedId": "\(id)",
                        "actualId": "\(root.identifier)",
                        "path": "\(currentPath)",
                        "role": "\(root.role)"
                    ])
                    return root
                }
            }
        }
        
        // Special handling for button types with exact title/description match
        if (root.role == AXAttribute.Role.button || 
            root.role == AXAttribute.Role.menuItem || 
            root.role == AXAttribute.Role.checkbox || 
            root.role == AXAttribute.Role.radioButton) {
            
            // For buttons, check if ID exactly matches title or description
            if let title = root.title, title == id {
                logger.debug("Found button with exact title match", metadata: [
                    "requestedId": "\(id)",
                    "actualId": "\(root.identifier)",
                    "title": "\(title)",
                    "path": "\(currentPath)",
                    "role": "\(root.role)"
                ])
                return root
            }
            
            // Also check description for exact match
            if let desc = root.elementDescription, desc == id {
                logger.debug("Found button with exact description match", metadata: [
                    "requestedId": "\(id)",
                    "actualId": "\(root.identifier)",
                    "description": "\(desc)",
                    "path": "\(currentPath)",
                    "role": "\(root.role)"
                ])
                return root
            }
        }
        
        // Log that we're examining this element
        logger.debug("Examining: role=\(root.role), id=\(root.identifier)")
        
        // Show child counts for debugging
        if !root.children.isEmpty {
            logger.debug("This element has \(root.children.count) children")
            
            // Log some details about the children for debugging
            for (index, child) in root.children.prefix(5).enumerated() {
                logger.debug("  Child \(index): role=\(child.role), id=\(child.identifier)")
                if !child.children.isEmpty {
                    logger.debug("    Child \(index) has \(child.children.count) children")
                }
            }
        }
        
        // Optimize traversal by prioritizing containers and interactive elements
        var sortedChildren = root.children
        
        // Sort children to prioritize application windows and containers over menus
        sortedChildren.sort { (a, b) -> Bool in
            // First, deprioritize menu elements
            let aIsMenu = isMenuElement(a)
            let bIsMenu = isMenuElement(b)
            
            if aIsMenu && !bIsMenu {
                return false
            } else if !aIsMenu && bIsMenu {
                return true
            }
            
            // Then prioritize window elements
            let aIsWindow = a.role == AXAttribute.Role.window
            let bIsWindow = b.role == AXAttribute.Role.window
            
            if aIsWindow && !bIsWindow {
                return true
            } else if !aIsWindow && bIsWindow {
                return false
            }
            
            // Then prioritize known container elements
            let aIsContainer = isContainer(a)
            let bIsContainer = isContainer(b)
            
            if aIsContainer && !bIsContainer {
                return true
            } else if !aIsContainer && bIsContainer {
                return false
            }
            
            // Then prioritize interactive elements
            let aIsInteractive = isInteractive(a)
            let bIsInteractive = isInteractive(b)
            
            if aIsInteractive && !bIsInteractive {
                return true
            } else if !aIsInteractive && bIsInteractive {
                return false
            }
            
            // Default to standard order
            return true
        }
        
        // Search through the prioritized children
        for child in sortedChildren {
            if let found = await findElementById(child, id: id, path: currentPath) {
                return found
            }
        }
        
        return nil
    }
    
    /// Check if an element is likely a container of interactive elements
    private func isContainer(_ element: UIElement) -> Bool {
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
        
        return containerRoles.contains(element.role)
    }
    
    /// Check if an element is a menu-related element that should be deprioritized
    private func isMenuElement(_ element: UIElement) -> Bool {
        let menuRoles = [
            "AXMenu",
            "AXMenuBar",
            "AXMenuBarItem",
            "AXMenuItem",
            "AXMenuButton"
        ]
        
        return menuRoles.contains(element.role)
    }
    
    /// Check if an element is likely interactive
    private func isInteractive(_ element: UIElement) -> Bool {
        let interactiveRoles = [
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
        
        return interactiveRoles.contains(element.role) || !element.actions.isEmpty
    }
    
    /// Perform an accessibility action on an element
    private func performAction(_ element: AXUIElement, action: String) throws {
        print("🔄 DEBUG: UIInteractionService.performAction - Starting action: \(action)")
        
        // Get available actions first to check if the action is supported
        var actionNames: CFArray?
        let actionsResult = AXUIElementCopyActionNames(element, &actionNames)
        
        print("   - Actions result code: \(actionsResult.rawValue) (\(getAXErrorName(actionsResult)))")
        
        logger.debug("Performing accessibility action", metadata: [
            "action": "\(action)",
            "actionsResult": "\(actionsResult.rawValue)",
            "actionsAvailable": "\(actionNames != nil ? (actionNames as? [String])?.joined(separator: ", ") ?? "nil" : "nil")"
        ])
        
        // Check if the action is supported by the element
        var actionSupported = false
        if actionsResult == .success, let actionsList = actionNames as? [String] {
            actionSupported = actionsList.contains(action)
            
            // Detailed logging of available actions
            print("   - Available actions: \(actionsList.joined(separator: ", "))")
            print("   - Action \(action) supported: \(actionSupported ? "YES" : "NO")")
            
            if !actionSupported {
                print("⚠️ DEBUG: UIInteractionService.performAction - WARNING: Action not supported by element")
                logger.warning("Action not supported by element", metadata: [
                    "action": "\(action)",
                    "availableActions": "\(actionsList.joined(separator: ", "))"
                ])
            }
        } else {
            print("⚠️ DEBUG: UIInteractionService.performAction - WARNING: Failed to get actions list")
        }
        
        // Try to get element role to see what we're working with
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &role)
        if roleResult == .success {
            print("   - Element role: \(role as? String ?? "unknown")")
            logger.debug("Element role", metadata: [
                "role": "\(role as? String ?? "unknown")"
            ])
        } else {
            print("⚠️ DEBUG: UIInteractionService.performAction - WARNING: Failed to get element role")
        }
        
        // Try to get element's enabled state
        var enabled: CFTypeRef?
        let enabledResult = AXUIElementCopyAttributeValue(element, "AXEnabled" as CFString, &enabled)
        if enabledResult == .success {
            let isEnabled = enabled as? Bool ?? false
            print("   - Element enabled: \(isEnabled)")
            
            if !isEnabled {
                print("⚠️ DEBUG: UIInteractionService.performAction - WARNING: Element is disabled, action may fail")
            }
        }
        
        // Set a longer timeout for the action
        print("   - Setting messaging timeout to 1.0 seconds")
        let timeoutResult = AXUIElementSetMessagingTimeout(element, 1.0) // 1 second timeout
        if timeoutResult != .success {
            print("⚠️ DEBUG: UIInteractionService.performAction - WARNING: Failed to set messaging timeout")
            logger.warning("Failed to set messaging timeout", metadata: [
                "error": "\(timeoutResult.rawValue)"
            ])
        }
        
        // Perform the action
        print("🖱️ DEBUG: UIInteractionService.performAction - Executing \(action) now...")
        let error = AXUIElementPerformAction(element, action as CFString)
        
        if error == .success {
            print("✅ DEBUG: UIInteractionService.performAction - Action \(action) succeeded!")
        } else {
            print("❌ DEBUG: UIInteractionService.performAction - Action \(action) FAILED with error: \(error.rawValue) (\(getAXErrorName(error)))")
            
            // Log details about the error
            logger.error("Accessibility action failed", metadata: [
                "action": .string(action),
                "error": .string("\(error.rawValue)"),
                "errorName": .string(getAXErrorName(error)),
                "actionSupported": .string("\(actionSupported)")
            ])
            
            // Print specific advice based on error code
            switch error {
            case .illegalArgument:
                print("   - Error detail: Illegal argument - The action name might be incorrect")
            case .invalidUIElement:
                print("   - Error detail: Invalid UI element - The element might no longer exist or be invalid")
            case .cannotComplete:
                print("   - Error detail: Cannot complete - The operation timed out or could not be completed")
            case .actionUnsupported:
                print("   - Error detail: Action unsupported - The element does not support this action")
            case .notImplemented:
                print("   - Error detail: Not implemented - The application has not implemented this action")
            case .apiDisabled:
                print("   - Error detail: API disabled - Accessibility permissions might be missing")
            default:
                print("   - Error detail: Unknown error code - Consult macOS Accessibility API documentation")
            }
            
            // If action not supported, try fallback to mouse click for button elements
            // We don't want to fall back to mouse clicks - if AXPress isn't supported,
            // we should fail gracefully with a clear error message
            if !actionSupported {
                let availableActions: String
                if let actions = actionNames as? [String] {
                    availableActions = actions.joined(separator: ", ")
                } else {
                    availableActions = "none"
                }
                
                print("⚠️ DEBUG: UIInteractionService.performAction - Element does not support the requested action")
                print("   - Role: \(role as? String ?? "unknown")")
                print("   - Available actions: \(availableActions)")
                
                logger.error("Element does not support AXPress action and no fallback is allowed", metadata: [
                    "role": .string(role as? String ?? "unknown"),
                    "actions": .string(availableActions)
                ])
            }
            
            // Create a specific error based on error code
            let context: [String: String] = [
                "action": action,
                "axErrorCode": "\(error.rawValue)",
                "axErrorName": getAXErrorName(error),
                "actionSupported": "\(actionSupported)"
            ]
            
            throw createInteractionError(
                message: "Failed to perform action \(action): \(getAXErrorName(error)) (\(error.rawValue))",
                context: context
            )
        }
    }
    
    /// Get a human-readable name for an AXError code
    private func getAXErrorName(_ error: AXError) -> String {
        switch error {
        case .success: return "Success"
        case .failure: return "Failure"
        case .illegalArgument: return "Illegal Argument"
        case .invalidUIElement: return "Invalid UI Element"
        case .invalidUIElementObserver: return "Invalid UI Element Observer"
        case .cannotComplete: return "Cannot Complete"
        case .attributeUnsupported: return "Attribute Unsupported"
        case .actionUnsupported: return "Action Unsupported"
        case .notificationUnsupported: return "Notification Unsupported"
        case .notImplemented: return "Not Implemented"
        case .notificationAlreadyRegistered: return "Notification Already Registered"
        case .notificationNotRegistered: return "Notification Not Registered"
        case .apiDisabled: return "API Disabled"
        case .noValue: return "No Value"
        case .parameterizedAttributeUnsupported: return "Parameterized Attribute Unsupported"
        case .notEnoughPrecision: return "Not Enough Precision"
        default: return "Unknown Error (\(error.rawValue))"
        }
    }
    
    /// Get available action names for an element
    private func getActionNames(for element: AXUIElement) throws -> [String] {
        guard let actionNames = try AccessibilityElement.getAttribute(
            element, 
            attribute: AXAttribute.actions
        ) as? [String] else {
            return []
        }
        return actionNames
    }
    
    /// Simulate a mouse click at a specific position
    private func simulateMouseClick(at position: CGPoint) throws {
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        
        guard let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else {
            throw createError("Failed to create mouse down event", code: 1001)
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: position,
            mouseButton: .left
        ) else {
            throw createError("Failed to create mouse up event", code: 1002)
        }
        
        // Post the events
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    /// Simulate a right mouse click at a specific position
    private func simulateMouseRightClick(at position: CGPoint) throws {
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        
        guard let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .rightMouseDown,
            mouseCursorPosition: position,
            mouseButton: .right
        ) else {
            throw createError("Failed to create right mouse down event", code: 1003)
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .rightMouseUp,
            mouseCursorPosition: position,
            mouseButton: .right
        ) else {
            throw createError("Failed to create right mouse up event", code: 1004)
        }
        
        // Post the events
        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    /// Simulate a mouse drag from one position to another
    private func simulateMouseDrag(from start: CGPoint, to end: CGPoint) throws {
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        
        // Create mouse down event at start position
        guard let mouseDown = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDown,
            mouseCursorPosition: start,
            mouseButton: .left
        ) else {
            throw createError("Failed to create mouse down event for drag", code: 1005)
        }
        
        // Create drag event to end position
        guard let mouseDrag = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseDragged,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else {
            throw createError("Failed to create mouse drag event", code: 1006)
        }
        
        // Create mouse up event at end position
        guard let mouseUp = CGEvent(
            mouseEventSource: eventSource,
            mouseType: .leftMouseUp,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else {
            throw createError("Failed to create mouse up event for drag", code: 1007)
        }
        
        // Post the events
        mouseDown.post(tap: .cghidEventTap)
        mouseDrag.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
    }
    
    /// Simulate a scroll wheel event
    private func simulateScrollWheel(at position: CGPoint, deltaX: Int, deltaY: Int) throws {
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        ) else {
            throw createError("Failed to create scroll wheel event", code: 1008)
        }
        
        // Set the position for the scroll event
        scrollEvent.location = position
        
        // Post the event
        scrollEvent.post(tap: .cghidEventTap)
    }
    
    /// Simulate a key press for a character
    private func simulateKeyPress(character: Character) throws {
        // Convert character to Unicode scalar value
        guard let scalar = String(character).unicodeScalars.first else {
            throw createError("Invalid character", code: 1009)
        }
        
        // Get key code and modifiers from the character
        let (keyCode, modifiers) = try keyCodeAndModifiersForCharacter(scalar.value)
        
        // Get event source
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        
        // Create key events
        guard let keyDown = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(keyCode),
            keyDown: true
        ) else {
            throw createError("Failed to create key down event", code: 1010)
        }
        
        guard let keyUp = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: CGKeyCode(keyCode),
            keyDown: false
        ) else {
            throw createError("Failed to create key up event", code: 1011)
        }
        
        // Apply modifiers
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        
        // Post the events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
    
    /// Get key code and modifiers for a character
    private func keyCodeAndModifiersForCharacter(_ character: UInt32) throws -> (Int, CGEventFlags) {
        // This is a simplified implementation that handles common characters
        // For a complete implementation, a full keyboard layout mapping would be needed
        
        var modifiers: CGEventFlags = []
        var keyCode: Int
        
        switch character {
        // Common characters
        case 97...122: // a-z
            keyCode = Int(character) - 97 + 0
        case 65...90: // A-Z
            keyCode = Int(character) - 65 + 0
            modifiers.insert(.maskShift)
        case 48...57: // 0-9
            keyCode = Int(character) - 48 + 29
        
        // Whitespace
        case 32: // space
            keyCode = 49
        case 9: // tab
            keyCode = 48
        case 13: // return
            keyCode = 36
        
        // Punctuation
        case 33: // !
            keyCode = 18
            modifiers.insert(.maskShift)
        case 64: // @
            keyCode = 19
            modifiers.insert(.maskShift)
        case 35: // #
            keyCode = 20
            modifiers.insert(.maskShift)
        case 36: // $
            keyCode = 21
            modifiers.insert(.maskShift)
        case 37: // %
            keyCode = 23
            modifiers.insert(.maskShift)
        case 94: // ^
            keyCode = 22
            modifiers.insert(.maskShift)
        case 38: // &
            keyCode = 26
            modifiers.insert(.maskShift)
        case 42: // *
            keyCode = 28
            modifiers.insert(.maskShift)
        case 40: // (
            keyCode = 25
            modifiers.insert(.maskShift)
        case 41: // )
            keyCode = 29
            modifiers.insert(.maskShift)
        case 45: // -
            keyCode = 27
        case 95: // _
            keyCode = 27
            modifiers.insert(.maskShift)
        case 61: // =
            keyCode = 24
        case 43: // +
            keyCode = 24
            modifiers.insert(.maskShift)
        case 91, 123: // [ {
            keyCode = 33
            if character == 123 { modifiers.insert(.maskShift) }
        case 93, 125: // ] }
            keyCode = 30
            if character == 125 { modifiers.insert(.maskShift) }
        case 92, 124: // \ |
            keyCode = 42
            if character == 124 { modifiers.insert(.maskShift) }
        case 59, 58: // ; :
            keyCode = 41
            if character == 58 { modifiers.insert(.maskShift) }
        case 39, 34: // ' "
            keyCode = 39
            if character == 34 { modifiers.insert(.maskShift) }
        case 44, 60: // , <
            keyCode = 43
            if character == 60 { modifiers.insert(.maskShift) }
        case 46, 62: // . >
            keyCode = 47
            if character == 62 { modifiers.insert(.maskShift) }
        case 47, 63: // / ?
            keyCode = 44
            if character == 63 { modifiers.insert(.maskShift) }
            
        default:
            throw createError("Unsupported character: \(character)", code: 1012)
        }
        
        return (keyCode, modifiers)
    }
    
    /// Create a standard error with a code
    private func createError(_ message: String, code: Int) -> Error {
        return createInteractionError(
            message: message,
            context: ["internalErrorCode": "\(code)"]
        )
    }
}