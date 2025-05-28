// ABOUTME: ToolChain.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP

@testable import MacMCP

/// Class that provides access to all MCP tools with a unified interface
public final class ToolChain: @unchecked Sendable {
  // MARK: - Properties

  /// Logger for the tool chain
  public let logger: Logger

  // MARK: - Services

  /// Accessibility service for interacting with macOS accessibility APIs
  public let accessibilityService: AccessibilityService

  /// Application service for launching and managing applications
  public let applicationService: ApplicationService

  /// Screenshot service for taking screenshots
  public let screenshotService: ScreenshotService

  /// UI interaction service for interacting with UI elements
  public let interactionService: UIInteractionService

  /// Menu navigation service for working with menus
  public let menuNavigationService: MenuNavigationService

  // MARK: - Tools

  /// Tool for taking screenshots
  public let screenshotTool: ScreenshotTool

  /// Tool for interacting with UI elements
  public let uiInteractionTool: UIInteractionTool


  /// Tool for managing windows
  public let windowManagementTool: WindowManagementTool

  /// Tool for navigating menus
  public let menuNavigationTool: MenuNavigationTool

  /// Tool for exploring UI interface elements (consolidated tool)
  public let interfaceExplorerTool: InterfaceExplorerTool

  /// Tool for keyboard interactions
  public let keyboardInteractionTool: KeyboardInteractionTool

  /// Tool for managing applications
  public let applicationManagementTool: ApplicationManagementTool

  // MARK: - Initialization

  /// Create a new tool chain with default services
  /// - Parameter logLabel: Label for the logger (defaults to "mcp.toolchain")
  public init(logLabel: String = "mcp.toolchain") {
    // Create logger
    logger = Logger(label: logLabel)

    // Create services
    accessibilityService = AccessibilityService(logger: logger)
    applicationService = ApplicationService(logger: logger)
    screenshotService = ScreenshotService(
      accessibilityService: accessibilityService,
      logger: logger,
    )
    interactionService = UIInteractionService(
      accessibilityService: accessibilityService,
      logger: logger,
    )
    menuNavigationService = MenuNavigationService(
      accessibilityService: accessibilityService,
      logger: logger,
    )

    // Create tools
    screenshotTool = ScreenshotTool(
      screenshotService: screenshotService,
      logger: logger,
    )

    let changeDetectionService = UIChangeDetectionService(accessibilityService: accessibilityService)
    uiInteractionTool = UIInteractionTool(
      interactionService: interactionService,
      accessibilityService: accessibilityService,
      applicationService: applicationService,
      changeDetectionService: changeDetectionService,
      logger: logger,
    )


    windowManagementTool = WindowManagementTool(
      accessibilityService: accessibilityService,
      logger: logger,
    )

    menuNavigationTool = MenuNavigationTool(
      menuNavigationService: menuNavigationService,
      accessibilityService: accessibilityService,
      changeDetectionService: changeDetectionService,
      logger: logger,
    )

    interfaceExplorerTool = InterfaceExplorerTool(
      accessibilityService: accessibilityService,
      logger: logger,
    )

    keyboardInteractionTool = KeyboardInteractionTool(
      interactionService: interactionService,
      accessibilityService: accessibilityService,
      changeDetectionService: changeDetectionService,
      logger: logger,
    )

    applicationManagementTool = ApplicationManagementTool(
      applicationService: applicationService,
      logger: logger,
    )
  }

  // MARK: - Application Operations

  /// Open an application by bundle identifier
  /// - Parameters:
  ///   - bundleId: Bundle identifier of the application to open
  ///   - arguments: Optional command line arguments
  ///   - hideOthers: Whether to hide other applications
  /// - Returns: True if the application was successfully opened
  public func openApp(
    bundleId: String,
    arguments: [String]? = nil,
    hideOthers: Bool = false,
  ) async throws -> Bool {
    // Create parameters for the application management tool
    var params: [String: Value] = [
      "action": .string("launch"),
      "bundleId": .string(bundleId)
    ]

    if let arguments {
      params["arguments"] = .array(arguments.map { .string($0) })
    }

    params["hideOthers"] = .bool(hideOthers)

    // Call the application management tool
    let result = try await applicationManagementTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("opened") || text.contains("true")
    }

    return false
  }

  /// Terminate an application by bundle identifier
  /// - Parameter bundleId: Bundle identifier of the application to terminate
  /// - Returns: True if the application was successfully terminated
  public func terminateApp(bundleId: String) async throws -> Bool {
    // Use a workaround to terminate the application using NSRunningApplication
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

    guard !runningApps.isEmpty else {
      // No running instances found
      return true
    }

    // Terminate all running instances
    var allTerminated = true
    for app in runningApps {
      let terminated = app.terminate()
      allTerminated = allTerminated && terminated
    }

    // Wait for termination to complete
    if !allTerminated {
      try await Task.sleep(for: .milliseconds(3000))
    }

    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
  }

  // MARK: - UI State Operations

  /// Get UI elements matching criteria
  /// - Parameters:
  ///   - criteria: Criteria to match against UI elements
  ///   - scope: Scope of the search ("system", "application", "position")
  ///   - bundleId: Bundle identifier for application scope
  ///   - position: Position for position scope
  ///   - maxDepth: Maximum depth of the element hierarchy
  /// - Returns: Array of matching UI elements
  public func findElements(
    matching criteria: UIElementCriteria,
    scope: String = "system",
    bundleId: String? = nil,
    position: CGPoint? = nil,
    maxDepth: Int = 10,
  ) async throws -> [UIElement] {
    // Create parameters for the tool
    var params: [String: Value] = [
      "scope": .string(scope),
      "maxDepth": .int(maxDepth),
    ]

    if let bundleId {
      params["bundleId"] = .string(bundleId)
    }

    if let position {
      params["x"] = .double(Double(position.x))
      params["y"] = .double(Double(position.y))
    }

    // Create filter object
    var filterObj: [String: Value] = [:]

    // Add filter criteria if applicable
    if criteria.role != nil {
      filterObj["role"] = .string(criteria.role!)
    }

    // Add title contains filter
    if criteria.titleContains != nil {
      filterObj["titleContains"] = .string(criteria.titleContains!)
    }

    // Add value contains filter
    if criteria.valueContains != nil {
      filterObj["valueContains"] = .string(criteria.valueContains!)
    }

    // Add description contains filter
    if criteria.descriptionContains != nil {
      filterObj["descriptionContains"] = .string(criteria.descriptionContains!)
    }
    
    // Add exact description as textContains filter (for compact JSON format compatibility)
    if criteria.description != nil {
      filterObj["textContains"] = .string(criteria.description!)
    }

    // Include main content (windows and their contents) - this is equivalent to --show-window-contents
    filterObj["inMainContent"] = .bool(true)

    // Only add filter if we have filter criteria
    if !filterObj.isEmpty {
      params["filter"] = .object(filterObj)
    }

    // Set hidden elements flag
    if criteria.isVisible != nil {
      params["includeHidden"] = .bool(true)  // We'll filter later based on isVisible
    }
    
    // Always include coordinates since tests need them for clicking
    params["showCoordinates"] = .bool(true)

    // Call the interface explorer tool
    let result = try await interfaceExplorerTool.handler(params)


    // Parse the result
    if let content = result.first, case .text(let jsonString) = content {
      // Parse the JSON into UI elements
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Create UI elements from JSON
      var elements: [UIElement] = []
      for elementJson in json {
        let element = try parseUIElement(from: elementJson)
        elements.append(element)
      }

      // Filter elements by criteria - but skip if we used textContains since InterfaceExplorerTool already filtered
      let matchingElements: [UIElement]
      if criteria.description != nil {
        // We converted description to textContains, so InterfaceExplorerTool already did the filtering
        matchingElements = elements
      } else {
        // Apply our own filtering for other criteria
        matchingElements = elements.filter { criteria.matches($0) }
      }

      return matchingElements
    }

    return []
  }

  /// Find a single UI element matching criteria
  /// - Parameters:
  ///   - criteria: Criteria to match against UI elements
  ///   - scope: Scope of the search ("system", "application", "position")
  ///   - bundleId: Bundle identifier for application scope
  ///   - position: Position for position scope
  ///   - maxDepth: Maximum depth of the element hierarchy
  /// - Returns: Matching UI element or nil if none found
  public func findElement(
    matching criteria: UIElementCriteria,
    scope: String = "system",
    bundleId: String? = nil,
    position: CGPoint? = nil,
    maxDepth: Int = 10,
  ) async throws -> UIElement? {
    let elements = try await findElements(
      matching: criteria,
      scope: scope,
      bundleId: bundleId,
      position: position,
      maxDepth: maxDepth,
    )

    return elements.first
  }

  // MARK: - UI Interaction Operations

  /// Click on a UI element using its element ID with change detection support
  /// - Parameters:
  ///   - elementId: Element ID or path of the element to click  
  ///   - appBundleId: Optional bundle identifier of the application
  ///   - detectChanges: Enable UI change detection (default: false for compatibility)
  ///   - changeDetectionDelay: Delay in milliseconds before capturing changes
  /// - Returns: Array of tool content (may include change detection results)
  public func clickElement(
    elementId: String,
    appBundleId: String? = nil,
    detectChanges: Bool = false,
    changeDetectionDelay: Int = 200
  ) async throws -> [Tool.Content] {
    // Create parameters for the tool
    var params: [String: Value] = [
      "action": .string("click"),
      "id": .string(elementId),
      "detectChanges": .bool(detectChanges),
      "changeDetectionDelay": .int(changeDetectionDelay),
    ]

    if let appBundleId {
      params["appBundleId"] = .string(appBundleId)
    }

    // Call the UI interaction tool and return full result
    return try await uiInteractionTool.handler(params)
  }

  /// Click on a UI element using its path (legacy method for backward compatibility)
  /// - Parameters:
  ///   - elementPath: Path of the element to click in macos://ui/ format
  ///   - bundleId: Optional bundle identifier of the application
  /// - Returns: True if the click was successful
  public func clickElement(
    elementPath: String,
    bundleId: String? = nil,
  ) async throws -> Bool {
    // Create parameters for the tool
    var params: [String: Value] = [
      "action": .string("click"),
      "id": .string(elementPath),
    ]

    if let bundleId {
      params["appBundleId"] = .string(bundleId)
    }

    // Call the UI interaction tool
    let result = try await uiInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("clicked") || text.contains("true")
    }

    return false
  }

  /// Click at a position on the screen
  /// - Parameter position: Position to click
  /// - Returns: True if the click was successful
  public func clickAtPosition(position: CGPoint) async throws -> Bool {
    // Create parameters for the tool
    let params: [String: Value] = [
      "action": .string("click"),
      "x": .double(Double(position.x)),
      "y": .double(Double(position.y)),
    ]

    // Call the UI interaction tool
    let result = try await uiInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("clicked") || text.contains("true")
    }

    return false
  }

  /// Type text into a UI element using its path
  /// - Parameters:
  ///   - elementPath: Path of the element to type into in macos://ui/ format
  ///   - text: Text to type
  ///   - bundleId: Optional bundle identifier of the application
  /// - Returns: True if the text was successfully typed
  public func typeText(
    elementPath: String,
    text: String,
    bundleId: String? = nil,
  ) async throws -> Bool {
    // Create parameters for the tool
    var params: [String: Value] = [
      "action": .string("type"),
      "id": .string(elementPath),
      "text": .string(text),
    ]

    if let bundleId {
      params["appBundleId"] = .string(bundleId)
    }

    // Call the UI interaction tool
    let result = try await uiInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("typed") || text.contains("true")
    }

    return false
  }

  /// Press a key
  /// - Parameter keyCode: Key code to press
  /// - Parameter modifiers: Optional modifier keys (like Command, Shift, etc.)
  /// - Returns: True if the key was successfully pressed
  public func pressKey(keyCode: Int, modifiers: CGEventFlags? = nil) async throws -> Bool {
    // Create a key sequence with a single tap event for the key code
    let keyToPress = String(keyCode)

    // We'll create a simple tap sequence for the key
    var tapEvent: [String: Value] = ["tap": .string(keyToPress)]

    // Add modifiers if present
    if let modifiers, !modifiers.isEmpty {
      // Convert the modifiers to an array of strings
      // This is a simplified approach - in practice, we'd have a proper mapping
      var modifierStrings: [String] = []

      if modifiers.contains(.maskShift) {
        modifierStrings.append("shift")
      }
      if modifiers.contains(.maskCommand) {
        modifierStrings.append("command")
      }
      if modifiers.contains(.maskAlternate) {
        modifierStrings.append("option")
      }
      if modifiers.contains(.maskControl) {
        modifierStrings.append("control")
      }

      if !modifierStrings.isEmpty {
        tapEvent["modifiers"] = .array(modifierStrings.map { .string($0) })
      }
    }

    // Create the full sequence with just the one tap event
    let sequence: [[String: Value]] = [tapEvent]

    // Create the parameters for the tool
    let params: [String: Value] = [
      "action": .string("key_sequence"),
      "sequence": .array(sequence.map { .object($0) }),
    ]

    // Call the keyboard interaction tool
    let result = try await keyboardInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("executed") || text.contains("true")
    }

    return false
  }

  /// Type text using the keyboard interaction tool with change detection support
  /// - Parameters:
  ///   - text: The text to type
  ///   - detectChanges: Enable UI change detection (default: false for compatibility) 
  ///   - changeDetectionDelay: Delay in milliseconds before capturing changes
  /// - Returns: Array of tool content (may include change detection results)
  public func typeTextWithKeyboard(
    text: String,
    detectChanges: Bool = false,
    changeDetectionDelay: Int = 200
  ) async throws -> [Tool.Content] {
    // Create parameters for the tool
    let params: [String: Value] = [
      "action": .string("type_text"),
      "text": .string(text),
      "detectChanges": .bool(detectChanges),
      "changeDetectionDelay": .int(changeDetectionDelay),
    ]

    // Call the keyboard interaction tool and return full result
    return try await keyboardInteractionTool.handler(params)
  }

  /// Type text using the keyboard interaction tool (legacy method for backward compatibility)
  /// - Parameter text: The text to type
  /// - Returns: True if the text was successfully typed
  public func typeTextWithKeyboard(text: String) async throws -> Bool {
    // Create parameters for the tool
    let params: [String: Value] = [
      "action": .string("type_text"),
      "text": .string(text),
    ]

    // Call the keyboard interaction tool
    let result = try await keyboardInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("typed") || text.contains("true")
    }

    return false
  }

  /// Execute a key sequence using the keyboard interaction tool
  /// - Parameter sequence: Array of key sequence events (e.g., tap, press, release, delay)
  /// - Returns: True if the sequence was successfully executed
  public func executeKeySequence(sequence: [[String: Value]]) async throws -> Bool {
    // Create parameters for the tool
    let params: [String: Value] = [
      "action": .string("key_sequence"),
      "sequence": .array(sequence.map { .object($0) }),
    ]

    // Call the keyboard interaction tool
    let result = try await keyboardInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("executed") || text.contains("true")
    }

    return false
  }

  // MARK: - Menu Navigation Operations

  /// Get menu items for a specific menu
  /// - Parameters:
  ///   - bundleId: Application bundle identifier
  ///   - menuTitle: Title of the menu to explore (e.g., "File", "Edit")
  /// - Returns: Array of tool content containing menu items
  public func getMenuItems(
    bundleId: String,
    menuTitle: String
  ) async throws -> [Tool.Content] {
    // Create parameters for the tool
    let params: [String: Value] = [
      "action": .string("showMenu"),
      "bundleId": .string(bundleId),
      "menuPath": .string(menuTitle),
    ]

    // Call the menu navigation tool
    return try await menuNavigationTool.handler(params)
  }

  // MARK: - Interface Explorer

  /// Explore UI elements using the InterfaceExplorerTool
  /// - Parameters:
  ///   - scope: Scope of the search ("system", "application", "position", "element")
  ///   - bundleId: Bundle identifier for application scope
  ///   - elementPath: Element path for element scope (using macos://ui/ notation)
  ///   - position: Position (x,y) for position scope
  ///   - filter: Optional filter criteria for elements
  ///   - elementTypes: Types of elements to find
  ///   - includeHidden: Whether to include hidden elements
  ///   - maxDepth: Maximum depth of the element hierarchy
  ///   - limit: Maximum number of elements to return
  /// - Returns: An array of enhanced element descriptors
  public func exploreInterface(
    scope: String,
    bundleId: String? = nil,
    elementPath: String? = nil,
    position: CGPoint? = nil,
    filter: [String: String]? = nil,
    elementTypes: [String]? = nil,
    includeHidden: Bool = false,
    maxDepth: Int = 10,
    limit: Int = 100,
  ) async throws -> [[String: Any]] {
    // Create parameters for the tool
    var params: [String: Value] = [
      "scope": .string(scope),
      "maxDepth": .int(maxDepth),
      "includeHidden": .bool(includeHidden),
      "limit": .int(limit),
    ]

    // Add parameters based on scope
    if let bundleId {
      params["bundleId"] = .string(bundleId)
    }

    if let elementPath {
      params["id"] = .string(elementPath)
    }

    if let position {
      params["x"] = .double(Double(position.x))
      params["y"] = .double(Double(position.y))
    }

    // Add filter if provided
    if let filter, !filter.isEmpty {
      var filterObj: [String: Value] = [:]
      for (key, value) in filter {
        filterObj[key] = .string(value)
      }
      params["filter"] = .object(filterObj)
    }

    // Add element types if provided
    if let elementTypes, !elementTypes.isEmpty {
      params["elementTypes"] = .array(elementTypes.map { .string($0) })
    }

    // Call the interface explorer tool
    let result = try await interfaceExplorerTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let jsonString) = content {
      let jsonData = jsonString.data(using: .utf8)!
      return try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
    }

    return []
  }

  // MARK: - JSON Parsing Helpers
  
  /// Parse JSON from a tool response
  /// - Parameter content: The content returned from a tool
  /// - Returns: The parsed JSON as a dictionary
  /// - Throws: An error if the content is not valid JSON
  public func parseJsonResponse(_ content: Tool.Content) throws -> [String: Any] {
    guard case .text(let jsonString) = content else {
      throw NSError(
        domain: "ToolChain",
        code: 1010,
        userInfo: [NSLocalizedDescriptionKey: "Tool response is not text content"]
      )
    }
    
    guard let data = jsonString.data(using: .utf8) else {
      throw NSError(
        domain: "ToolChain",
        code: 1011,
        userInfo: [NSLocalizedDescriptionKey: "Failed to convert JSON string to data"]
      )
    }
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw NSError(
        domain: "ToolChain",
        code: 1012,
        userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON or result is not a dictionary"]
      )
    }
    
    return json
  }
  
  /// Get a boolean value from a parsed JSON response
  /// - Parameters:
  ///   - json: The parsed JSON
  ///   - key: The key to look up
  /// - Returns: The boolean value, or false if not found
  public func getBoolValue(from json: [String: Any], forKey key: String) -> Bool {
    return json[key] as? Bool ?? false
  }
  
  // MARK: - Helper Methods

  /// Parse a UI element from JSON
  /// - Parameter json: JSON dictionary representing a UI element (in EnhancedElementDescriptor format)
  /// - Returns: UI element
  private func parseUIElement(from json: [String: Any]) throws -> UIElement {
    // Extract required fields
    // With EnhancedElementDescriptor, the identifier is now "id"
    guard let identifier = json["id"] as? String else {
      throw NSError(
        domain: "ToolChain",
        code: 1000,
        userInfo: [NSLocalizedDescriptionKey: "Missing identifier (id) in UI element JSON"],
      )
    }

    guard let role = json["role"] as? String else {
      throw NSError(
        domain: "ToolChain",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Missing role in UI element JSON"],
      )
    }

    // Extract optional fields
    let title = json["title"] as? String
    let value = json["value"]
    let stringValue: String? =
      value as? String
      ?? {
        if let value {
          return String(describing: value)
        }
        return nil
      }()
    let description = json["description"] as? String

    // Extract frame
    var frame = CGRect.zero
    if let frameDict = json["frame"] as? [String: Any] {
      // Try to get values with different types
      let x = (frameDict["x"] as? CGFloat) ?? CGFloat(frameDict["x"] as? Double ?? 0)
      let y = (frameDict["y"] as? CGFloat) ?? CGFloat(frameDict["y"] as? Double ?? 0)
      let width = (frameDict["width"] as? CGFloat) ?? CGFloat(frameDict["width"] as? Double ?? 0)
      let height = (frameDict["height"] as? CGFloat) ?? CGFloat(frameDict["height"] as? Double ?? 0)

      frame = CGRect(x: x, y: y, width: width, height: height)
    }

    // Extract normalized frame (not directly available in EnhancedElementDescriptor)
    let normalizedFrame: CGRect? = nil

    // Extract children
    var children: [UIElement] = []
    if let childrenJson = json["children"] as? [[String: Any]] {
      for childJson in childrenJson {
        let child = try parseUIElement(from: childJson)
        children.append(child)
      }
    }

    // Extract attributes
    var attributes: [String: Any] = [:]
    if let attributesDict = json["attributes"] as? [String: String] {
      // Convert string-to-string dictionary to string-to-any dictionary
      for (key, value) in attributesDict {
        attributes[key] = value
      }
    }

    // Extract actions
    var actions: [String] = []
    if let actionsArray = json["actions"] as? [String] {
      actions = actionsArray
    }

    // Extract capabilities and state information
    // These fields are new in EnhancedElementDescriptor
    var isEnabled = true
    var isVisible = true
    var isFocused = false
    var isSelected = false

    // Parse state and capabilities from either separate arrays or combined props string
    var allProps: [String] = []
    
    // Check for separate state array (old format)
    if let stateArray = json["state"] as? [String] {
      allProps.append(contentsOf: stateArray)
    }
    
    // Check for separate capabilities array (old format)
    if let capabilitiesArray = json["capabilities"] as? [String] {
      allProps.append(contentsOf: capabilitiesArray)
    }
    
    // Check for combined props string (new EnhancedElementDescriptor format)
    if let propsString = json["props"] as? String {
      let propsArray = propsString.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      allProps.append(contentsOf: propsArray)
    }
    
    // Process all props (state and capabilities together)
    for prop in allProps {
      switch prop.lowercased() {
      // State properties
      case "enabled": isEnabled = true
      case "disabled": isEnabled = false
      case "visible": isVisible = true
      case "hidden": isVisible = false
      case "focused": isFocused = true
      case "unfocused": isFocused = false
      case "selected": isSelected = true
      case "unselected": isSelected = false
      
      // Capability properties
      case "clickable": attributes["clickable"] = true
      case "editable": attributes["editable"] = true
      case "toggleable": attributes["toggleable"] = true
      case "selectable": attributes["selectable"] = true
      case "adjustable": attributes["adjustable"] = true
      case "scrollable": attributes["scrollable"] = true
      case "haschildren": attributes["hasChildren"] = true
      case "hasmenu": attributes["hasMenu"] = true
      case "hashelp": attributes["hasHelp"] = true
      case "hastooltip": attributes["hasTooltip"] = true
      default: break  // Ignore other properties
      }
    }

    // Add state information to attributes
    attributes["enabled"] = isEnabled
    attributes["visible"] = isVisible
    attributes["focused"] = isFocused
    attributes["selected"] = isSelected

    // Create and return the UI element
    return UIElement(
      path: identifier,
      role: role,
      title: title,
      value: stringValue,
      elementDescription: description,
      frame: frame,
      normalizedFrame: normalizedFrame,
      viewportFrame: nil,  // Not included in JSON
      frameSource: .direct,  // Default
      parent: nil,  // Parent relationship not preserved in JSON
      children: children,
      attributes: attributes,
      actions: actions,
    )
  }
}
