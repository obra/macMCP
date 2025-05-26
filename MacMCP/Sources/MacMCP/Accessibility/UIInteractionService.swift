// ABOUTME: UIInteractionService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
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

  /// Double-click at a specific screen position
  /// - Parameter position: The screen position to double-click
  /// - Note: Implemented as two rapid clicks with a short delay between them
  public func doubleClickAtPosition(position: CGPoint) async throws {
    logger.debug(
      "Double-clicking at position",
      metadata: [
        "x": "\(position.x)", "y": "\(position.y)",
      ])

    // Perform two clicks in rapid succession to simulate a double-click
    try await clickAtPosition(position: position)
    try await Task.sleep(for: .milliseconds(100))
    try await clickAtPosition(position: position)
  }

  /// Right-click at a specific screen position
  /// - Parameter position: The screen position to right-click
  public func rightClickAtPosition(position: CGPoint) async throws {
    logger.debug(
      "Right-clicking at position",
      metadata: [
        "x": "\(position.x)", "y": "\(position.y)",
      ])

    // Get the element at the position (if any) using a separate task to avoid data races
    let elementAtPosition = await Task.detached {
      let localAccessibilityService = self.accessibilityService
      let localPosition = position

      do {
        return try await localAccessibilityService.getUIElementAtPosition(
          position: localPosition,
          recursive: false,
          maxDepth: 1,
        )
      } catch {
        return nil
      }
    }.value

    if let element = elementAtPosition {
      if let axElement = element.axElement {
        // Try accessibility action directly on the element, but fall back to mouse simulation if it fails
        do {
          let actions = try getActionNames(for: axElement)
          if actions.contains(AXAttribute.Action.showMenu) {
            try AccessibilityElement.performAction(axElement, action: AXAttribute.Action.showMenu)
            logger.debug("AXShowMenu succeeded for position-based right-click")
            return
          }
        } catch {
          logger.debug(
            "Accessibility right-click failed for position-based click, falling back to mouse simulation",
            metadata: ["error": "\(error.localizedDescription)"]
          )
          // Fall through to mouse simulation
        }
      }
      
      // Fallback to position-based right clicking
      try simulateMouseRightClick(at: position)
    } else {
      // If no element found, use the lower-level mouse event API
      try simulateMouseRightClick(at: position)
    }
  }

  public func clickAtPosition(position: CGPoint) async throws {
    logger.debug(
      "Clicking at position",
      metadata: [
        "x": "\(position.x)", "y": "\(position.y)",
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
          maxDepth: 1,
        )
      } catch {
        return nil
      }
    }.value

    if let element = elementAtPosition {
      if let axElement = element.axElement {
        // Try AXPress on the element, but fall back to mouse simulation if it fails
        do {
          try AccessibilityElement.performAction(axElement, action: "AXPress")
          logger.debug("AXPress succeeded for position-based click")
          return
        } catch {
          logger.debug(
            "AXPress failed for position-based click, falling back to mouse simulation",
            metadata: ["error": "\(error.localizedDescription)"]
          )
          // Fall through to mouse simulation
        }
      }

      // Fallback to position-based clicking
      try simulateMouseClick(at: position)
    } else {
      // If no element found, use the lower-level mouse event API
      try simulateMouseClick(at: position)
    }
  }

  /// Press a specific key on the keyboard
  /// - Parameters:
  ///   - keyCode: The key code to press
  ///   - modifiers: Optional modifier flags to apply
  public func pressKey(keyCode: Int, modifiers: CGEventFlags? = nil) async throws {
    logger.debug(
      "Pressing key",
      metadata: [
        "keyCode": "\(keyCode)",
        "modifiers": modifiers != nil ? "\(modifiers!)" : "none",
      ])

    // Get the event source
    let eventSource = CGEventSource(stateID: .combinedSessionState)

    // Create key events
    let keyDownEvent = CGEvent(
      keyboardEventSource: eventSource,
      virtualKey: CGKeyCode(keyCode),
      keyDown: true,
    )

    let keyUpEvent = CGEvent(
      keyboardEventSource: eventSource,
      virtualKey: CGKeyCode(keyCode),
      keyDown: false,
    )

    guard let keyDownEvent, let keyUpEvent else {
      throw createError("Failed to create key events", code: 2003)
    }

    // Apply modifiers if provided
    if let modifiers {
      keyDownEvent.flags = modifiers
      keyUpEvent.flags = modifiers

      logger.debug(
        "Applied modifiers to key events",
        metadata: [
          "keyCode": "\(keyCode)",
          "modifiers": "\(modifiers)",
        ])
    }

    // Post the events
    keyDownEvent.post(tap: .cghidEventTap)
    try await Task.sleep(for: .milliseconds(50))
    keyUpEvent.post(tap: .cghidEventTap)
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
  // Legacy element identifier methods have been removed

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

      logger.debug(
        "Cleaned \(entriesToRemove.count) old elements from cache",
        metadata: [
          "remainingCacheSize": "\(elementCache.count)"
        ])
    }
  }

  // Legacy element identifier methods have been removed

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
      "AXLayoutArea",
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
      "AXMenuButton",
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
      "AXTabButton",
    ]

    return interactiveRoles.contains(element.role) || !element.actions.isEmpty
  }

  /// Perform an accessibility action on an element
  private func performAction(_ element: AXUIElement, action: String) throws {
    // Get available actions first to check if the action is supported
    var actionNames: CFArray?
    let actionsResult = AXUIElementCopyActionNames(element, &actionNames)

    logger.debug(
      "Performing accessibility action",
      metadata: [
        "action": "\(action)",
        "actionsResult": "\(actionsResult.rawValue)",
        "actionsAvailable":
          "\(actionNames != nil ? (actionNames as? [String])?.joined(separator: ", ") ?? "nil" : "nil")",
      ])

    // Check if the action is supported by the element
    var actionSupported = false
    if actionsResult == .success, let actionsList = actionNames as? [String] {
      actionSupported = actionsList.contains(action)

      // Detailed logging of available actions

      if !actionSupported {
        logger.warning(
          "Action not supported by element",
          metadata: [
            "action": "\(action)",
            "availableActions": "\(actionsList.joined(separator: ", "))",
          ])
      }
    } else {
      logger.warning("Failed to get actions list for element")
    }

    // Try to get element role to see what we're working with
    var role: CFTypeRef?
    let roleResult = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &role)
    if roleResult == .success {
      logger.debug(
        "Element role",
        metadata: [
          "role": "\(role as? String ?? "unknown")"
        ])
    } else {
      logger.warning("Failed to get element role")
    }

    // Try to get element's enabled state
    var enabled: CFTypeRef?
    let enabledResult = AXUIElementCopyAttributeValue(element, "AXEnabled" as CFString, &enabled)
    if enabledResult == .success {
      let isEnabled = enabled as? Bool ?? false

      if !isEnabled {
        logger.warning("Element is disabled, action may fail")
      }
    }

    // Set a longer timeout for the action
    let timeoutResult = AXUIElementSetMessagingTimeout(element, 1.0)  // 1 second timeout
    if timeoutResult != .success {
      logger.warning(
        "Failed to set messaging timeout",
        metadata: [
          "error": "\(timeoutResult.rawValue)"
        ])
    }

    // Perform the action
    let error = AXUIElementPerformAction(element, action as CFString)

    if error == .success {
    } else {
      // Log details about the error
      logger.trace(
        "Accessibility action failed",
        metadata: [
          "action": .string(action),
          "error": .string("\(error.rawValue)"),
          "errorName": .string(getAXErrorName(error)),
          "actionSupported": .string("\(actionSupported)"),
        ])

      // Print specific advice based on error code
      switch error {
      case .illegalArgument:
        logger.trace("Illegal argument - The action name might be incorrect")
      case .invalidUIElement:
        logger.trace("Invalid UI element - The element might no longer exist or be invalid")
      case .cannotComplete:
        logger.trace("Cannot complete - The operation timed out or could not be completed")
      case .actionUnsupported:
        logger.trace("Action unsupported - The element does not support this action")
      case .notImplemented:
        logger.trace("Not implemented - The application has not implemented this action")
      case .apiDisabled:
        logger.trace("API disabled - Accessibility permissions might be missing")
      default:
        logger.trace("Unknown error code - Consult macOS Accessibility API documentation")
      }

      // If action not supported, try fallback to mouse click for button elements
      // We don't want to fall back to mouse clicks - if AXPress isn't supported,
      // we should fail gracefully with a clear error message
      if !actionSupported {
        let availableActions: String =
          if let actions = actionNames as? [String] {
            actions.joined(separator: ", ")
          } else {
            "none"
          }

        logger.warning(
          "Element does not support the requested action",
          metadata: [
            "role": "\(role as? String ?? "unknown")",
            "availableActions": "\(availableActions)",
          ])

        logger.trace(
          "Element does not support AXPress action and no fallback is allowed",
          metadata: [
            "role": .string(role as? String ?? "unknown"),
            "actions": .string(availableActions),
          ])
      }

      // Create a specific error based on error code
      let context: [String: String] = [
        "action": action,
        "axErrorCode": "\(error.rawValue)",
        "axErrorName": getAXErrorName(error),
        "actionSupported": "\(actionSupported)",
      ]

      throw createInteractionError(
        message: "Failed to perform action \(action): \(getAXErrorName(error)) (\(error.rawValue))",
        context: context,
      )
    }
  }

  /// Get a human-readable name for an AXError code
  private func getAXErrorName(_ error: AXError) -> String {
    switch error {
    case .success: "Success"
    case .failure: "Failure"
    case .illegalArgument: "Illegal Argument"
    case .invalidUIElement: "Invalid UI Element"
    case .invalidUIElementObserver: "Invalid UI Element Observer"
    case .cannotComplete: "Cannot Complete"
    case .attributeUnsupported: "Attribute Unsupported"
    case .actionUnsupported: "Action Unsupported"
    case .notificationUnsupported: "Notification Unsupported"
    case .notImplemented: "Not Implemented"
    case .notificationAlreadyRegistered: "Notification Already Registered"
    case .notificationNotRegistered: "Notification Not Registered"
    case .apiDisabled: "API Disabled"
    case .noValue: "No Value"
    case .parameterizedAttributeUnsupported: "Parameterized Attribute Unsupported"
    case .notEnoughPrecision: "Not Enough Precision"
    default: "Unknown Error (\(error.rawValue))"
    }
  }

  /// Get available action names for an element
  private func getActionNames(for element: AXUIElement) throws -> [String] {
    guard
      let actionNames = try AccessibilityElement.getAttribute(
        element,
        attribute: AXAttribute.actions,
      ) as? [String]
    else {
      return []
    }
    return actionNames
  }

  /// Simulate a mouse click at a specific position
  private func simulateMouseClick(at position: CGPoint) throws {
    let eventSource = CGEventSource(stateID: .combinedSessionState)

    guard
      let mouseDown = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseDown,
        mouseCursorPosition: position,
        mouseButton: .left,
      )
    else {
      throw createError("Failed to create mouse down event", code: 1001)
    }

    guard
      let mouseUp = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseUp,
        mouseCursorPosition: position,
        mouseButton: .left,
      )
    else {
      throw createError("Failed to create mouse up event", code: 1002)
    }

    // Post the events
    mouseDown.post(tap: .cghidEventTap)
    // delay for 100ms
    Thread.sleep(forTimeInterval: 0.5) // 100 milliseconds
    mouseUp.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.5) // 100 milliseconds

  }

  /// Simulate a right mouse click at a specific position
  private func simulateMouseRightClick(at position: CGPoint) throws {
    let eventSource = CGEventSource(stateID: .combinedSessionState)

    guard
      let mouseDown = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .rightMouseDown,
        mouseCursorPosition: position,
        mouseButton: .right,
      )
    else {
      throw createError("Failed to create right mouse down event", code: 1003)
    }

    guard
      let mouseUp = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .rightMouseUp,
        mouseCursorPosition: position,
        mouseButton: .right,
      )
    else {
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
    guard
      let mouseDown = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseDown,
        mouseCursorPosition: start,
        mouseButton: .left,
      )
    else {
      throw createError("Failed to create mouse down event for drag", code: 1005)
    }

    // Create drag event to end position
    guard
      let mouseDrag = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseDragged,
        mouseCursorPosition: end,
        mouseButton: .left,
      )
    else {
      throw createError("Failed to create mouse drag event", code: 1006)
    }

    // Create mouse up event at end position
    guard
      let mouseUp = CGEvent(
        mouseEventSource: eventSource,
        mouseType: .leftMouseUp,
        mouseCursorPosition: end,
        mouseButton: .left,
      )
    else {
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

    guard
      let scrollEvent = CGEvent(
        scrollWheelEvent2Source: eventSource,
        units: .pixel,
        wheelCount: 2,
        wheel1: Int32(deltaY),
        wheel2: Int32(deltaX),
        wheel3: 0,
      )
    else {
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
    guard
      let keyDown = CGEvent(
        keyboardEventSource: eventSource,
        virtualKey: CGKeyCode(keyCode),
        keyDown: true,
      )
    else {
      throw createError("Failed to create key down event", code: 1010)
    }

    guard
      let keyUp = CGEvent(
        keyboardEventSource: eventSource,
        virtualKey: CGKeyCode(keyCode),
        keyDown: false,
      )
    else {
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
    case 97...122:  // a-z
      keyCode = Int(character) - 97 + 0
    case 65...90:  // A-Z
      keyCode = Int(character) - 65 + 0
      modifiers.insert(.maskShift)
    case 48...57:  // 0-9
      keyCode = Int(character) - 48 + 29
    // Whitespace
    case 32:  // space
      keyCode = 49
    case 9:  // tab
      keyCode = 48
    case 13:  // return
      keyCode = 36
    // Punctuation
    case 33:  // !
      keyCode = 18
      modifiers.insert(.maskShift)
    case 64:  // @
      keyCode = 19
      modifiers.insert(.maskShift)
    case 35:  // #
      keyCode = 20
      modifiers.insert(.maskShift)
    case 36:  // $
      keyCode = 21
      modifiers.insert(.maskShift)
    case 37:  // %
      keyCode = 23
      modifiers.insert(.maskShift)
    case 94:  // ^
      keyCode = 22
      modifiers.insert(.maskShift)
    case 38:  // &
      keyCode = 26
      modifiers.insert(.maskShift)
    case 42:  // *
      keyCode = 28
      modifiers.insert(.maskShift)
    case 40:  // (
      keyCode = 25
      modifiers.insert(.maskShift)
    case 41:  // )
      keyCode = 29
      modifiers.insert(.maskShift)
    case 45:  // -
      keyCode = 27
    case 95:  // _
      keyCode = 27
      modifiers.insert(.maskShift)
    case 61:  // =
      keyCode = 24
    case 43:  // +
      keyCode = 24
      modifiers.insert(.maskShift)
    case 91, 123:  // [ {
      keyCode = 33
      if character == 123 { modifiers.insert(.maskShift) }
    case 93, 125:  // ] }
      keyCode = 30
      if character == 125 { modifiers.insert(.maskShift) }
    case 92, 124:  // \ |
      keyCode = 42
      if character == 124 { modifiers.insert(.maskShift) }
    case 59, 58:  // ; :
      keyCode = 41
      if character == 58 { modifiers.insert(.maskShift) }
    case 39, 34:  // ' "
      keyCode = 39
      if character == 34 { modifiers.insert(.maskShift) }
    case 44, 60:  // , <
      keyCode = 43
      if character == 60 { modifiers.insert(.maskShift) }
    case 46, 62:  // . >
      keyCode = 47
      if character == 62 { modifiers.insert(.maskShift) }
    case 47, 63:  // / ?
      keyCode = 44
      if character == 63 { modifiers.insert(.maskShift) }
    default:
      throw createError("Unsupported character: \(character)", code: 1012)
    }

    return (keyCode, modifiers)
  }

  /// Create a standard error with a code
  private func createError(_ message: String, code: Int) -> Error {
    createInteractionError(
      message: message,
      context: ["internalErrorCode": "\(code)"],
    )
  }
  
}

// MARK: - Path-based Element Interaction Methods Extension

extension UIInteractionService {
  /// Click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  public func clickElementByPath(path: String, appBundleId: String?) async throws {
    logger.debug(
      "Clicking element by path",
      metadata: [
        "path": "\(path)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])
    

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }
    
    // Perform the click using the AXUIElement directly
    try await clickElementDirectly(element)
  }

  /// Double click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  public func doubleClickElementByPath(path: String, appBundleId: String?) async throws {
    logger.debug(
      "Double-clicking element by path",
      metadata: [
        "path": "\(path)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }

    // Perform the double click using the AXUIElement directly
    try await doubleClickElementDirectly(element)
  }

  /// Right click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  public func rightClickElementByPath(path: String, appBundleId: String?) async throws {
    logger.debug(
      "Right-clicking element by path",
      metadata: [
        "path": "\(path)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }

    // Perform the right click using the AXUIElement directly
    try await rightClickElementDirectly(element)
  }

  /// Type text into a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - text: The text to type
  ///   - appBundleId: Optional bundle ID of the application containing the element
  public func typeTextByPath(path: String, text: String, appBundleId: String?) async throws {
    logger.debug(
      "Typing text into element by path",
      metadata: [
        "path": "\(path)",
        "textLength": "\(text.count)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }

    // Get the element's role to determine how to handle text input
    let role =
      try AccessibilityElement.getAttribute(element, attribute: AXAttribute.role) as? String

    if role == AXAttribute.Role.textField || role == AXAttribute.Role.textArea {
      // For text fields, set the value directly
      try AccessibilityElement.setAttribute(
        element,
        attribute: AXAttribute.value,
        value: text,
      )
    } else {
      // For other elements, try to set focus and use key events
      let focusParams = AXUIElementSetMessagingTimeout(element, 1.0)
      guard focusParams == .success else {
        throw createError("Failed to set messaging timeout", code: 2002)
      }

      // Set focus to the element
      try AccessibilityElement.setAttribute(
        element,
        attribute: "AXFocused",
        value: true,
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

  /// Drag and drop from one element to another using paths
  /// - Parameters:
  ///   - sourcePath: The source element path using macos://ui/ notation
  ///   - targetPath: The target element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the elements
  public func dragElementByPath(sourcePath: String, targetPath: String, appBundleId: String?)
    async throws
  {
    logger.debug(
      "Dragging element by path",
      metadata: [
        "sourcePath": "\(sourcePath)",
        "targetPath": "\(targetPath)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the paths
    let sourceElementPath = try ElementPath.parse(sourcePath)
    let targetElementPath = try ElementPath.parse(targetPath)

    // Resolve the paths to get the AXUIElements
    let sourceElement = try await accessibilityService.run {
      try await sourceElementPath.resolve(using: accessibilityService)
    }
    let targetElement = try await accessibilityService.run {
      try await targetElementPath.resolve(using: accessibilityService)
    }

    // Get positions for drag operation
    var sourcePosition = CGPoint.zero
    var targetPosition = CGPoint.zero

    // Get source position
    var positionRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(sourceElement, "AXPosition" as CFString, &positionRef)
      == .success,
      CFGetTypeID(positionRef!) == AXValueGetTypeID()
    {
      let value = positionRef as! AXValue
      AXValueGetValue(value, .cgPoint, &sourcePosition)
    }

    // Get source size to calculate center
    var sizeRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(sourceElement, "AXSize" as CFString, &sizeRef) == .success,
      CFGetTypeID(sizeRef!) == AXValueGetTypeID()
    {
      let value = sizeRef as! AXValue
      var size = CGSize.zero
      AXValueGetValue(value, .cgSize, &size)

      // Calculate center point
      sourcePosition.x += size.width / 2
      sourcePosition.y += size.height / 2
    }

    // Get target position
    positionRef = nil
    if AXUIElementCopyAttributeValue(targetElement, "AXPosition" as CFString, &positionRef)
      == .success,
      CFGetTypeID(positionRef!) == AXValueGetTypeID()
    {
      let value = positionRef as! AXValue
      AXValueGetValue(value, .cgPoint, &targetPosition)
    }

    // Get target size to calculate center
    sizeRef = nil
    if AXUIElementCopyAttributeValue(targetElement, "AXSize" as CFString, &sizeRef) == .success,
      CFGetTypeID(sizeRef!) == AXValueGetTypeID()
    {
      let value = sizeRef as! AXValue
      var size = CGSize.zero
      AXValueGetValue(value, .cgSize, &size)

      // Calculate center point
      targetPosition.x += size.width / 2
      targetPosition.y += size.height / 2
    }

    // Perform the drag operation
    try simulateMouseDrag(from: sourcePosition, to: targetPosition)
  }

  /// Scroll a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - direction: The scroll direction
  ///   - amount: The amount to scroll (normalized 0-1)
  ///   - appBundleId: Optional bundle ID of the application containing the element
  public func scrollElementByPath(
    path: String,
    direction: ScrollDirection,
    amount: Double,
    appBundleId: String?,
  ) async throws {
    logger.debug(
      "Scrolling element by path",
      metadata: [
        "path": "\(path)",
        "direction": "\(direction)",
        "amount": "\(amount)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }

    // Check for scroll actions
    let actions = try getActionNames(for: element)

    // Map direction to scroll action
    let scrollAction =
      switch direction {
      case .up:
        "AXScrollUp"
      case .down:
        "AXScrollDown"
      case .left:
        "AXScrollLeft"
      case .right:
        "AXScrollRight"
      }

    // Check if the element supports the specific scroll action
    if actions.contains(scrollAction) {
      // Convert normalized amount to number of actions (1-10)
      let scrollCount = max(1, min(10, Int(amount * 10)))

      // Perform the scroll action the calculated number of times
      for _ in 0..<scrollCount {
        try performAction(element, action: scrollAction)
        try await Task.sleep(for: .milliseconds(50))
      }
    } else if actions.contains(AXAttribute.Action.scrollToVisible) {
      // If only scroll to visible is available, use it
      try performAction(element, action: AXAttribute.Action.scrollToVisible)
    } else {
      // If no scroll actions, try to simulate a scroll event

      // Get element position
      var position = CGPoint.zero
      var positionRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
        CFGetTypeID(positionRef!) == AXValueGetTypeID()
      {
        let value = positionRef as! AXValue
        AXValueGetValue(value, .cgPoint, &position)
      }

      // Get element size to calculate center
      var size = CGSize.zero
      var sizeRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
        CFGetTypeID(sizeRef!) == AXValueGetTypeID()
      {
        let value = sizeRef as! AXValue
        AXValueGetValue(value, .cgSize, &size)

        // Calculate center point
        position.x += size.width / 2
        position.y += size.height / 2
      }

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

  /// Perform a specific accessibility action on an element by path
  /// - Parameters:
  ///   - path: The element path using macos://ui/ notation
  ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
  ///   - appBundleId: Optional application bundle ID
  public func performActionByPath(path: String, action: String, appBundleId: String?) async throws {
    logger.debug(
      "Performing accessibility action by path",
      metadata: [
        "path": "\(path)",
        "action": "\(action)",
        "appBundleId": appBundleId != nil ? "\(appBundleId!)" : "nil",
      ])

    // Parse the path
    let elementPath = try ElementPath.parse(path)

    // Resolve the path to get the AXUIElement
    let element = try await accessibilityService.run {
      try await elementPath.resolve(using: accessibilityService)
    }

    // Perform the action
    try performAction(element, action: action)
  }

  // MARK: - Helper Methods for Path-Based Interaction

  /// Click an AXUIElement directly
  /// - Parameter element: The AXUIElement to click
  private func clickElementDirectly(_ element: AXUIElement) async throws {
    // Check if the element supports AXPress action
    var supportsPress = false
    var availableActions: [String] = []

    do {
      availableActions = try getActionNames(for: element)
      supportsPress = availableActions.contains(AXAttribute.Action.press)
    } catch {
      logger.warning("Failed to get actions for element, assuming AXPress not supported")
      supportsPress = false
    }

    // Try AXPress first if supported, otherwise fallback to mouse click
    if supportsPress {
      do {
        try performAction(element, action: AXAttribute.Action.press)
        logger.debug("AXPress succeeded for path-based element")
        return
      } catch {
        // AXPress failed, we'll fallback to mouse click below
        let nsError = error as NSError
        logger.warning(
          "AXPress failed for path-based element, will try mouse simulation fallback",
          metadata: [
            "error": .string(error.localizedDescription),
            "code": .string("\(nsError.code)"),
          ])
      }
    } else {
      logger.debug(
        "Element doesn't support AXPress, will use mouse simulation",
        metadata: ["availableActions": .string(availableActions.joined(separator: ", "))],
      )
    }

    // If we got here, either the element doesn't support AXPress or AXPress failed
    // Fallback to mouse simulation by clicking at the center of the element

    // Get element position
    var position = CGPoint.zero
    var positionRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
      CFGetTypeID(positionRef!) == AXValueGetTypeID()
    {
      let value = positionRef as! AXValue
      AXValueGetValue(value, .cgPoint, &position)
    }

    // Get element size to calculate center
    var size = CGSize.zero
    var sizeRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
      CFGetTypeID(sizeRef!) == AXValueGetTypeID()
    {
      let value = sizeRef as! AXValue
      AXValueGetValue(value, .cgSize, &size)
    }

    // Calculate center point
    let centerPoint = CGPoint(
      x: position.x + size.width / 2,
      y: position.y + size.height / 2,
    )

    logger.debug(
      "Using mouse simulation fallback for path-based element",
      metadata: [
        "x": .string("\(centerPoint.x)"),
        "y": .string("\(centerPoint.y)"),
      ],
    )

    do {
      try simulateMouseClick(at: centerPoint)
      logger.debug("Mouse simulation click succeeded for path-based element")
    } catch {
      // Both AXPress and mouse simulation failed
      let nsError = error as NSError

      logger.trace(
        "Both AXPress and mouse simulation failed for path-based element",
        metadata: [
          "error": .string(error.localizedDescription),
          "domain": .string(nsError.domain),
          "code": .string("\(nsError.code)"),
        ])

      // Create a more informative error with context
      let context: [String: String] = [
        "errorCode": "\(nsError.code)",
        "errorDomain": nsError.domain,
        "position": "{\(centerPoint.x), \(centerPoint.y)}",
        "size": "{\(size.width), \(size.height)}",
      ]

      throw createInteractionError(
        message: "Failed to click element by path - both AXPress and mouse simulation failed",
        context: context,
        underlyingError: error,
      )
    }
  }

  /// Double click an AXUIElement directly
  /// - Parameter element: The AXUIElement to double click
  private func doubleClickElementDirectly(_ element: AXUIElement) async throws {
    // For double click, we check if the element has a dedicated action
    let actions = try getActionNames(for: element)

    if actions.contains("AXDoubleClick") {
      // Use the dedicated action if available
      try performAction(element, action: "AXDoubleClick")
      logger.debug("AXDoubleClick succeeded for path-based element")
      return
    } else if actions.contains(AXAttribute.Action.press) {
      // If AXPress is supported, use it twice in rapid succession
      try performAction(element, action: AXAttribute.Action.press)
      try await Task.sleep(for: .milliseconds(50))
      try performAction(element, action: AXAttribute.Action.press)
      logger.debug("Double AXPress succeeded for path-based element")
      return
    }

    // If neither AXDoubleClick nor AXPress is supported, fall back to mouse simulation
    // Get element position
    var position = CGPoint.zero
    var positionRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
      CFGetTypeID(positionRef!) == AXValueGetTypeID()
    {
      let value = positionRef as! AXValue
      AXValueGetValue(value, .cgPoint, &position)
    }

    // Get element size to calculate center
    var size = CGSize.zero
    var sizeRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
      CFGetTypeID(sizeRef!) == AXValueGetTypeID()
    {
      let value = sizeRef as! AXValue
      AXValueGetValue(value, .cgSize, &size)
    }

    // Calculate center point
    let centerPoint = CGPoint(
      x: position.x + size.width / 2,
      y: position.y + size.height / 2,
    )

    logger.debug(
      "Element doesn't support AXDoubleClick or AXPress action, falling back to mouse simulation",
      metadata: [
        "x": .string("\(centerPoint.x)"),
        "y": .string("\(centerPoint.y)"),
      ],
    )

    // Simulate two mouse clicks in rapid succession
    try simulateMouseClick(at: centerPoint)
    try await Task.sleep(for: .milliseconds(50))
    try simulateMouseClick(at: centerPoint)
    logger.debug("Mouse simulation double-click succeeded for path-based element")
  }

  /// Right click an AXUIElement directly
  /// - Parameter element: The AXUIElement to right click
  private func rightClickElementDirectly(_ element: AXUIElement) async throws {
    // Check for a show menu action, which is typically equivalent to right-click
    let actions = try getActionNames(for: element)

    if actions.contains(AXAttribute.Action.showMenu) {
      try performAction(element, action: AXAttribute.Action.showMenu)
      logger.debug("AXShowMenu succeeded for path-based element")
      return
    }

    // If no show menu action, get the position and simulate a right click
    // Get element position
    var position = CGPoint.zero
    var positionRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
      CFGetTypeID(positionRef!) == AXValueGetTypeID()
    {
      let value = positionRef as! AXValue
      AXValueGetValue(value, .cgPoint, &position)
    }

    // Get element size to calculate center
    var size = CGSize.zero
    var sizeRef: CFTypeRef?
    if AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &sizeRef) == .success,
      CFGetTypeID(sizeRef!) == AXValueGetTypeID()
    {
      let value = sizeRef as! AXValue
      AXValueGetValue(value, .cgSize, &size)
    }

    // Calculate center point
    let centerPoint = CGPoint(
      x: position.x + size.width / 2,
      y: position.y + size.height / 2,
    )

    logger.debug(
      "Element doesn't support AXShowMenu action, falling back to mouse simulation",
      metadata: [
        "x": .string("\(centerPoint.x)"),
        "y": .string("\(centerPoint.y)"),
      ],
    )

    try simulateMouseRightClick(at: centerPoint)
    logger.debug("Mouse simulation right-click succeeded for path-based element")
  }
}
