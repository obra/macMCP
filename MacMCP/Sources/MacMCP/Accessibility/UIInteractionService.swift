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
    private var elementCache: [String: AXUIElement] = [:]
    
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
    /// - Parameter identifier: The UI element identifier
    public func clickElement(identifier: String) async throws {
        logger.debug("Clicking element", metadata: ["id": "\(identifier)"])
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier)
        
        // Perform the click action
        try performAction(axElement, action: AXAttribute.Action.press)
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
    private func getAXUIElement(for identifier: String) async throws -> AXUIElement {
        // Check the cache first
        if let element = elementCache[identifier] {
            return element
        }
        
        // Try to find the element in the UI hierarchy
        guard let uiElement = try await findUIElement(identifier: identifier) else {
            throw createError("Element not found: \(identifier)", code: 2000)
        }
        
        // For now, we'll need to get the element again from the system-wide element
        // This is because we don't store the actual AXUIElement in our UIElement model
        let systemWide = AccessibilityElement.systemWideElement()
        
        // Get the position of the element
        let position = CGPoint(
            x: uiElement.frame.origin.x + uiElement.frame.size.width / 2,
            y: uiElement.frame.origin.y + uiElement.frame.size.height / 2
        )
        
        // Use AXUIElementCopyElementAtPosition to get the element at the position
        var foundElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(position.x),
            Float(position.y),
            &foundElement
        )
        
        guard error == .success, let axElement = foundElement else {
            throw createError(
                "Failed to get AXUIElement for \(identifier) at position \(position)",
                code: 2000
            )
        }
        
        // Cache the element
        elementCache[identifier] = axElement
        
        return axElement
    }
    
    /// Find a UI element by identifier
    private func findUIElement(identifier: String) async throws -> UIElement? {
        // We need to use a separate task to avoid data races with accessibilityService
        // Create a detached task that doesn't capture 'self'
        let result = await Task.detached {
            // Capture local copies of necessary values
            let localAccessibilityService = self.accessibilityService
            let localIdentifier = identifier
            let localSelf = self
            
            do {
                let systemElement = try await localAccessibilityService.getSystemUIElement(
                    recursive: true,
                    maxDepth: 20
                )
                return await localSelf.findElementById(systemElement, id: localIdentifier)
            } catch {
                return nil
            }
        }.value
        
        return result
    }
    
    /// Recursively find an element by ID
    private func findElementById(_ root: UIElement, id: String) async -> UIElement? {
        if root.identifier == id {
            return root
        }
        
        for child in root.children {
            if let found = await findElementById(child, id: id) {
                return found
            }
        }
        
        return nil
    }
    
    /// Perform an accessibility action on an element
    private func performAction(_ element: AXUIElement, action: String) throws {
        let error = AXUIElementPerformAction(element, action as CFString)
        
        if error != .success {
            throw createError(
                "Failed to perform action \(action), error: \(error.rawValue)",
                code: 1000
            )
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
        return NSError(
            domain: "com.macos.mcp.interaction",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}