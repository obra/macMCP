// ABOUTME: InterfaceExplorerTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import MacMCPUtilities
import CoreGraphics

private let elementDescriptorLogger = Logger(label: "mcp.tool.interface_explorer_descriptor")

/// A tool for exploring UI elements and their capabilities in macOS applications
public struct InterfaceExplorerTool: @unchecked Sendable {
  /// The name of the tool
  public let name = ToolNames.interfaceExplorer

  /// Description of the tool
  public let description = """
Explore and examine UI elements and their capabilities in macOS applications - essential for discovering elements to interact with.

IMPORTANT: This tool is critical for finding element IDs needed by UIInteractionTool and other tools. Always explore before interacting.

Available scope types:
- application: Specific app by bundleId (when you know the target app)
- system: All applications (very broad, use sparingly)
- position: Element at screen coordinates (x, y required)
- element: Specific element by ID (advanced usage)
- element: Element by ID (for detailed exploration)

Common workflows:
1. Initial exploration: Use 'application' scope with specific bundleId and maxDepth 15-20
2. Find interactive elements: Use filter by role (AXButton, AXTextField, etc.)
3. Search by content: Use titleContains or descriptionContains filters
4. Navigate hierarchy: Use 'element' scope to explore specific elements deeper
5. Performance optimization: Reduce maxDepth for faster responses

Filtering capabilities:
- role: Element type (AXButton, AXTextField, AXWindow, etc.)
- title/titleContains: Element titles or partial matches
- value/valueContains: Element values or partial matches  
- description/descriptionContains: Element descriptions or partial matches
- textContains: Universal text search across all text fields (title, description, value, identifier)
- isInteractable: Filter for elements that can be acted upon (clickable, editable, etc.)
- isEnabled: Filter by enabled/disabled state
- inMenus/inMainContent: Location context filtering (menu system vs main content)

Performance tips: Start with 'application' scope for specific apps, use filters to narrow results, adjust maxDepth based on needs.
"""

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The accessibility service to use
  private let accessibilityService: any AccessibilityServiceProtocol

  /// Tool handler function that uses this instance's accessibility service
  public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [self] params in
      return try await self.processRequest(params)
    }
  }

  /// The logger
  private let logger: Logger

  /// Create a new interface explorer tool
  /// - Parameters:
  ///   - accessibilityService: The accessibility service to use
  ///   - logger: Optional logger to use
  public init(
    accessibilityService: any AccessibilityServiceProtocol,
    logger: Logger? = nil
  ) {
    self.accessibilityService = accessibilityService
    self.logger = logger ?? Logger(label: "mcp.tool.interface_explorer")

    // Set tool annotations
    annotations = .init(
      title: "macOS UI Explorer",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Now create the full input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "scope": .object([
          "type": .string("string"),
          "description": .string("Exploration scope: 'application' (specific app), 'system' (all apps), 'position' (coordinates), 'element' (specific element)"),
          "enum": .array([
            .string("system"),
            .string("application"),
            .string("position"),
            .string("element"),
            .string("element"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle identifier (required for 'application' scope, e.g., 'com.apple.calculator')"),
        ]),
        "id": .object([
          "type": .string("string"),
          "description": .string("Element ID (required for 'element' scope) for detailed element exploration"),
        ]),
        "x": .object([
          "type": .array([.string("number"), .string("integer")]),
          "description": .string("X screen coordinate for 'position' scope (0 = left edge)"),
        ]),
        "y": .object([
          "type": .array([.string("number"), .string("integer")]),
          "description": .string("Y screen coordinate for 'position' scope (0 = top edge)"),
        ]),
        "maxDepth": .object([
          "type": .string("number"),
          "description": .string("UI hierarchy depth: 10-15 for performance, 20+ for comprehensive exploration (default: 15)"),
          "default": .double(15),
        ]),
        "filter": .object([
          "type": .string("object"),
          "description": .string("Filter elements by properties (role, title, value, description) with exact or partial matching"),
          "properties": .object([
            "role": .object([
              "type": .string("string"),
              "description": .string("Filter by accessibility role (e.g., 'AXButton', 'AXTextField', 'AXWindow')"),
            ]),
            "title": .object([
              "type": .string("string"),
              "description": .string("Filter by exact title match"),
            ]),
            "titleContains": .object([
              "type": .string("string"),
              "description": .string("Filter by title containing this text (case-sensitive)"),
            ]),
            "value": .object([
              "type": .string("string"),
              "description": .string("Filter by exact value match"),
            ]),
            "valueContains": .object([
              "type": .string("string"),
              "description": .string("Filter by value containing this text"),
            ]),
            "description": .object([
              "type": .string("string"),
              "description": .string("Filter by exact description match"),
            ]),
            "descriptionContains": .object([
              "type": .string("string"),
              "description": .string("Filter by description containing this text"),
            ]),
            "textContains": .object([
              "type": .string("string"),
              "description": .string("Filter by text containing this string in any text field (title, description, value, identifier)"),
            ]),
            "anyFieldContains": .object([
              "type": .string("string"),
              "description": .string("Search across all text fields simultaneously (title, description, value, identifier, role)"),
            ]),
            "isInteractable": .object([
              "type": .string("boolean"),
              "description": .string("Filter for elements that can be acted upon (clickable, editable, etc.)"),
            ]),
            "isEnabled": .object([
              "type": .string("boolean"),
              "description": .string("Filter by enabled state"),
            ]),
            "inMenus": .object([
              "type": .string("boolean"),
              "description": .string("Filter for elements in menu system"),
            ]),
            "inMainContent": .object([
              "type": .string("boolean"),
              "description": .string("Filter for elements in main content area (not menus)"),
            ]),
          ]),
        ]),
        "elementTypes": .object([
          "type": .string("array"),
          "description": .string("Interactive element types to discover: button, textfield, dropdown, etc. (default: any)"),
          "items": .object([
            "type": .string("string"),
            "enum": .array([
              .string("button"),
              .string("checkbox"),
              .string("radio"),
              .string("textfield"),
              .string("dropdown"),
              .string("slider"),
              .string("link"),
              .string("tab"),
              .string("any"),
            ]),
          ]),
          "default": .array([.string("any")]),
        ]),
        "includeHidden": .object([
          "type": .string("boolean"),
          "description": .string("Include hidden/invisible elements in results (default: false for cleaner output)"),
          "default": .bool(false),
        ]),
        "includeDisabled": .object([
          "type": .string("boolean"),
          "description": .string("Include disabled elements in results (default: false for cleaner output)"),
          "default": .bool(false),
        ]),
        "includeNonInteractable": .object([
          "type": .string("boolean"),
          "description": .string("Include non-interactable elements in results (default: false for cleaner output)"),
          "default": .bool(false),
        ]),
        "showCoordinates": .object([
          "type": .string("boolean"),
          "description": .string("Include position and size information in results (default: false for cleaner output)"),
          "default": .bool(false),
        ]),
        "limit": .object([
          "type": .string("integer"),
          "description": .string("Maximum elements to return (default: 100, increase for comprehensive exploration)"),
          "default": .int(100),
        ]),
      ]),
      "required": .array([.string("scope")]),
      "additionalProperties": .bool(false),
      "examples": .array([
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.calculator"),
        ]),
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.calculator"),
          "maxDepth": .int(20),
          "filter": .object([
            "role": .string("AXButton")
          ]),
        ]),
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.calculator"),
          "maxDepth": .int(15),
        ]),
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.textedit"),
          "filter": .object([
            "titleContains": .string("Save")
          ]),
        ]),
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.calculator"),
          "filter": .object([
            "textContains": .string("5")
          ]),
        ]),
        .object([
          "scope": .string("application"),
          "bundleId": .string("com.apple.calculator"),
          "filter": .object([
            "isInteractable": .bool(true)
          ]),
        ]),
        .object([
          "scope": .string("position"),
          "x": .int(400),
          "y": .int(300),
        ]),
        .object([
          "scope": .string("element"),
          "id": .string("element-uuid-example"),
          "maxDepth": .int(10),
        ]),
      ]),
    ])
  }

  /// Process a request for the tool
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else {
      throw MCPError.invalidParams("Parameters are required")
    }

    // Get the scope
    guard let scopeValue = params["scope"]?.stringValue else {
      throw MCPError.invalidParams("Scope is required")
    }

    // Get common parameters
    let maxDepth = params["maxDepth"]?.intValue ?? 10
    let includeHidden = params["includeHidden"]?.boolValue ?? false
    let includeDisabled = params["includeDisabled"]?.boolValue ?? false
    let includeNonInteractable = params["includeNonInteractable"]?.boolValue ?? false
    let showCoordinates = params["showCoordinates"]?.boolValue ?? false
    let limit = params["limit"]?.intValue ?? 100

    // Get element types if specified
    var elementTypes: [String] = []
    if case .array(let types)? = params["elementTypes"] {
      for typeValue in types {
        if let typeStr = typeValue.stringValue {
          elementTypes.append(typeStr)
        }
      }
    }
    if elementTypes.isEmpty {
      elementTypes = ["any"]
    }

    // Extract filter criteria
    var role: String?
    var title: String?
    var titleContains: String?
    var value: String?
    var valueContains: String?
    var description: String?
    var descriptionContains: String?
    var textContains: String?
    var anyFieldContains: String?
    var isInteractable: Bool?
    var isEnabled: Bool?
    var inMenus: Bool?
    var inMainContent: Bool?

    if case .object(let filterObj)? = params["filter"] {
      role = filterObj["role"]?.stringValue
      title = filterObj["title"]?.stringValue
      titleContains = filterObj["titleContains"]?.stringValue
      value = filterObj["value"]?.stringValue
      valueContains = filterObj["valueContains"]?.stringValue
      description = filterObj["description"]?.stringValue
      descriptionContains = filterObj["descriptionContains"]?.stringValue
      textContains = filterObj["textContains"]?.stringValue
      anyFieldContains = filterObj["anyFieldContains"]?.stringValue
      isInteractable = filterObj["isInteractable"]?.boolValue
      isEnabled = filterObj["isEnabled"]?.boolValue
      inMenus = filterObj["inMenus"]?.boolValue
      inMainContent = filterObj["inMainContent"]?.boolValue
    }

    // Process based on scope
    switch scopeValue {
    case "system":
      return try await handleSystemScope(
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        includeDisabled: includeDisabled,
        includeNonInteractable: includeNonInteractable,
        showCoordinates: showCoordinates,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
      )

    case "application":
      // Validate bundle ID
      guard let bundleId = params["bundleId"]?.stringValue else {
        throw MCPError.invalidParams("bundleId is required when scope is 'application'")
      }

      return try await handleApplicationScope(
        bundleId: bundleId,
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        includeDisabled: includeDisabled,
        includeNonInteractable: includeNonInteractable,
        showCoordinates: showCoordinates,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
      )

    case "position":
      // Get coordinates
      let xCoord: Double
      let yCoord: Double

      if let xDouble = params["x"]?.doubleValue {
        xCoord = xDouble
      } else if let xInt = params["x"]?.intValue {
        xCoord = Double(xInt)
      } else {
        throw MCPError.invalidParams("x coordinate is required when scope is 'position'")
      }

      if let yDouble = params["y"]?.doubleValue {
        yCoord = yDouble
      } else if let yInt = params["y"]?.intValue {
        yCoord = Double(yInt)
      } else {
        throw MCPError.invalidParams("y coordinate is required when scope is 'position'")
      }

      return try await handlePositionScope(
        x: xCoord,
        y: yCoord,
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        includeDisabled: includeDisabled,
        includeNonInteractable: includeNonInteractable,
        showCoordinates: showCoordinates,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
      )

    case "element":
      // Validate element ID
      guard let elementPath = params["id"]?.stringValue else {
        throw MCPError.invalidParams("id is required when scope is 'element'")
      }

      // Bundle ID is optional for element scope
      let bundleId = params["bundleId"]?.stringValue

      return try await handleElementScope(
        elementPath: elementPath,
        bundleId: bundleId,
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        includeDisabled: includeDisabled,
        includeNonInteractable: includeNonInteractable,
        showCoordinates: showCoordinates,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
      )


    default:
      throw MCPError.invalidParams("Invalid scope: \(scopeValue)")
    }
  }

  /// Handle system scope
  private func handleSystemScope(
    maxDepth: Int,
    includeHidden: Bool,
    includeDisabled: Bool,
    includeNonInteractable: Bool,
    showCoordinates: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Get system-wide UI state
    let systemElement = try await accessibilityService.getSystemUIElement(
      recursive: true,
      maxDepth: maxDepth,
    )

    // Apply filters if specified
    var elements: [UIElement]
    if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
      || description != nil || descriptionContains != nil || textContains != nil || anyFieldContains != nil || isInteractable != nil
      || isEnabled != nil || inMenus != nil || inMainContent != nil || !elementTypes.contains("any")
    {
      // Use findUIElements for filtered results
      elements = try await accessibilityService.findUIElements(
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        scope: .systemWide,
        recursive: true,
        maxDepth: maxDepth,
      )

      // Apply additional filters that weren't directly supported by findUIElements
      elements = applyAdditionalFilters(
        elements: elements,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        includeNonInteractable: includeNonInteractable,
        limit: limit,
      )
    } else {
      elements = [systemElement]

      // Apply visibility, enabled, and interactability filters if specified
      if !includeHidden {
        elements = filterVisibleElements(elements)
      }
      if !includeDisabled {
        elements = filterEnabledElements(elements)
      }
      // Note: includeNonInteractable filter will be implemented in next iteration
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth, showCoordinates: showCoordinates)

    // Apply limit
    let limitedDescriptors = descriptors.prefix(limit)

    // Return formatted response
    return try formatResponse(Array(limitedDescriptors))
  }

  /// Handle application scope
  private func handleApplicationScope(
    bundleId: String,
    maxDepth: Int,
    includeHidden: Bool,
    includeDisabled: Bool,
    includeNonInteractable: Bool,
    showCoordinates: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Get application-specific UI state
    var elements: [UIElement]

    if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
      || description != nil || descriptionContains != nil || textContains != nil || isInteractable != nil
      || isEnabled != nil || inMenus != nil || inMainContent != nil || !elementTypes.contains("any")
    {
      // Use findUIElements for filtered results
      elements = try await accessibilityService.findUIElements(
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        scope: .application(bundleId: bundleId),
        recursive: true,
        maxDepth: maxDepth,
      )

      // Apply additional filters if needed (if not handled by findUIElements)
      elements = applyAdditionalFilters(
        elements: elements,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        includeNonInteractable: includeNonInteractable,
        limit: limit,
      )
    } else {
      // Get the full application element
      let appElement = try await accessibilityService.getApplicationUIElement(
        bundleId: bundleId,
        recursive: true,
        maxDepth: maxDepth,
      )
      elements = [appElement]

      // Apply visibility, enabled, and interactability filters if specified
      if !includeHidden {
        elements = filterVisibleElements(elements)
      }
      if !includeDisabled {
        elements = filterEnabledElements(elements)
      }
      if !includeNonInteractable {
        elements = filterInteractableElements(elements)
      }
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth, showCoordinates: showCoordinates)

    // Apply limit
    let limitedDescriptors = descriptors.prefix(limit)

    // Return formatted response
    return try formatResponse(Array(limitedDescriptors))
  }


  /// Handle position scope
  private func handlePositionScope(
    x: Double,
    y: Double,
    maxDepth: Int,
    includeHidden: Bool,
    includeDisabled: Bool,
    includeNonInteractable: Bool,
    showCoordinates: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Get UI element at the specified position
    guard
      let element = try await accessibilityService.getUIElementAtPosition(
        position: CGPoint(x: x, y: y),
        recursive: true,
        maxDepth: maxDepth,
      )
    else {
      // No element found at position
      return try formatResponse([EnhancedElementDescriptor]())
    }

    var elements = [element]

    // Apply filters if needed
    if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
      || description != nil || descriptionContains != nil || textContains != nil || isInteractable != nil
      || isEnabled != nil || inMenus != nil || inMainContent != nil || !elementTypes.contains("any")
      || !includeHidden
    {
      elements = applyAdditionalFilters(
        elements: elements,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        textContains: textContains,
        anyFieldContains: anyFieldContains,
        isInteractable: isInteractable,
        isEnabled: isEnabled,
        inMenus: inMenus,
        inMainContent: inMainContent,
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        includeNonInteractable: includeNonInteractable,
        limit: limit,
      )
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth, showCoordinates: showCoordinates)

    // Apply limit
    let limitedDescriptors = descriptors.prefix(limit)

    // Return formatted response
    return try formatResponse(Array(limitedDescriptors))
  }

  /// Handle element scope
  private func handleElementScope(
    elementPath: String,
    bundleId: String?,
    maxDepth: Int,
    includeHidden: Bool,
    includeDisabled: Bool,
    includeNonInteractable: Bool,
    showCoordinates: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // First check if the path is valid
    guard ElementPath.isElementPath(elementPath) else {
      throw MCPError.invalidParams("Invalid element path format: \(elementPath)")
    }

    // Parse and resolve the path
    do {
      let parsedPath = try ElementPath.parse(elementPath)
      let axElement = try await parsedPath.resolve(using: accessibilityService)

      // Convert to UIElement
      let element = try AccessibilityElement.convertToUIElement(
        axElement,
        recursive: true,
        maxDepth: maxDepth,
      )

      // If we're searching within this element, we need to apply filters to its children
      var resultElements: [UIElement] = []

      if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
        || description != nil || descriptionContains != nil || textContains != nil || isInteractable != nil
        || isEnabled != nil || inMenus != nil || inMainContent != nil || !elementTypes.contains("any")
      {
        // For filtering, we need to process the element and its descendants
        // Now search within this element for matching elements
        resultElements = findMatchingDescendants(
          in: element,
          role: role,
          title: title,
          titleContains: titleContains,
          value: value,
          valueContains: valueContains,
          description: description,
          descriptionContains: descriptionContains,
          textContains: textContains,
          anyFieldContains: anyFieldContains,
          isInteractable: isInteractable,
          isEnabled: isEnabled,
          inMenus: inMenus,
          inMainContent: inMainContent,
          elementTypes: elementTypes,
          includeHidden: includeHidden,
          maxDepth: maxDepth,
          limit: limit,
        )
      } else {
        // If no filters, just use the element as is
        resultElements = [element]

        // Apply visibility, enabled, and interactability filters if specified
        if !includeHidden {
          resultElements = filterVisibleElements(resultElements)
        }
        if !includeDisabled {
          resultElements = filterEnabledElements(resultElements)
        }
        if !includeNonInteractable {
          resultElements = filterInteractableElements(resultElements)
        }
      }

      // Convert to enhanced element descriptors
      let descriptors = convertToEnhancedDescriptors(elements: resultElements, maxDepth: maxDepth, showCoordinates: showCoordinates)

      // Apply limit
      let limitedDescriptors = descriptors.prefix(limit)

      // Return formatted response
      return try formatResponse(Array(limitedDescriptors))
    } catch let pathError as ElementPathError {
      // If there's a path resolution error, provide specific information
      throw MCPError.internalError("Failed to resolve element path: \(pathError.description)")
    } catch {
      // For other errors
      throw MCPError.internalError("Error finding element by path: \(error.localizedDescription)")
    }
  }

  /// Find matching descendants in an element hierarchy
  private func findMatchingDescendants(
    in element: UIElement,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
    includeHidden: Bool,
    maxDepth: Int,
    limit: Int,
  ) -> [UIElement] {
    // Create a filter criteria from the parameters
    let criteria = UIElement.FilterCriteria(
      role: role,
      title: title,
      titleContains: titleContains,
      value: value,
      valueContains: valueContains,
      description: description,
      descriptionContains: descriptionContains,
      textContains: textContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes,
      includeHidden: includeHidden
    )
    
    // Use the UIElement's findMatchingDescendants method
    return element.findMatchingDescendants(
      criteria: criteria,
      maxDepth: maxDepth,
      limit: limit
    )
  }

  /// Apply additional filters not handled by the accessibility service
  private func applyAdditionalFilters(
    elements: [UIElement],
    valueContains: String? = nil,
    descriptionContains: String? = nil,
    elementTypes: [String]? = nil,
    includeHidden: Bool = true,
    includeNonInteractable: Bool = true,
    limit: Int = 100,
  ) -> [UIElement] {
    applyAdditionalFilters(
      elements: elements,
      role: nil,
      title: nil,
      titleContains: nil,
      value: valueContains,
      valueContains: valueContains,
      description: descriptionContains,
      descriptionContains: descriptionContains,
      textContains: nil,
      isInteractable: nil,
      isEnabled: nil,
      inMenus: nil,
      inMainContent: nil,
      elementTypes: elementTypes,
      includeHidden: includeHidden,
      includeNonInteractable: includeNonInteractable,
      limit: limit,
    )
  }

  /// Apply filters to elements
  private func applyAdditionalFilters(
    elements: [UIElement],
    role: String? = nil,
    title: String? = nil,
    titleContains: String? = nil,
    value: String? = nil,
    valueContains: String? = nil,
    description: String? = nil,
    descriptionContains: String? = nil,
    textContains: String? = nil,
    anyFieldContains: String? = nil,
    isInteractable: Bool? = nil,
    isEnabled: Bool? = nil,
    inMenus: Bool? = nil,
    inMainContent: Bool? = nil,
    elementTypes: [String]? = nil,
    includeHidden: Bool = true,
    includeNonInteractable: Bool = true,
    limit: Int = 100,
  ) -> [UIElement] {
    // Create filter criteria from the parameters
    let criteria = UIElement.FilterCriteria(
      role: role,
      title: title,
      titleContains: titleContains,
      value: value,
      valueContains: valueContains,
      description: description,
      descriptionContains: descriptionContains,
      textContains: textContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes ?? ["any"],
      includeHidden: includeHidden
    )
    
    // Use the static UIElement filterElements method
    var filteredElements = UIElement.filterElements(
      elements: elements,
      criteria: criteria,
      limit: limit
    )
    
    // Apply anyFieldContains filter if specified
    if let searchText = anyFieldContains, !searchText.isEmpty {
      filteredElements = filteredElements.filter { element in
        // Search across all string fields
        let searchFields = [
          element.role,
          element.title,
          element.elementDescription,
          element.value,
          element.identifier
        ].compactMap { $0 }
        
        return searchFields.contains { field in
          field.localizedCaseInsensitiveContains(searchText)
        }
      }
    }
    
    return filteredElements
  }

  /// Filter to only include visible elements
  private func filterVisibleElements(_ elements: [UIElement]) -> [UIElement] {
    elements.filter { element in
      // If this element isn't visible, exclude it
      if !element.isVisible {
        return false
      }

      // Include visible elements
      return true
    }
  }

  /// Filter to only include enabled elements
  private func filterEnabledElements(_ elements: [UIElement]) -> [UIElement] {
    elements.filter { element in
      // Include only enabled elements
      return element.isEnabled
    }
  }

  /// Filter to only include interactable elements
  private func filterInteractableElements(_ elements: [UIElement]) -> [UIElement] {
    elements.filter { element in
      // Include only elements that can be interacted with
      return element.isClickable || element.isEditable || element.isToggleable || 
             element.isSelectable || element.isAdjustable
    }
  }

  /// Convert UI elements to enhanced element descriptors
  private func convertToEnhancedDescriptors(elements: [UIElement], maxDepth: Int, showCoordinates: Bool)
    -> [EnhancedElementDescriptor]
  {
    elements.map { element in
      // Before converting to descriptor, ensure the element has a properly calculated path
      if element.path.isEmpty {
        do {
          // Generate a path based on the element's position in the hierarchy
          // This uses parent relationships to build a fully qualified path
          element.path = try element.generatePath()
          elementDescriptorLogger.debug(
            "Generated fully qualified path",
            metadata: ["path": .string(element.path)],
          )
        } catch {
          // Log any path generation errors but continue
          logger.warning(
            "Could not generate fully qualified path for element: \(error.localizedDescription)")
        }
      } else if !element.path.hasPrefix("macos://ui/") {
        // Path exists but isn't fully qualified - try to generate a proper one
        do {
          element.path = try element.generatePath()
          elementDescriptorLogger.debug(
            "Replaced non-qualified path with fully qualified path",
            metadata: ["path": .string(element.path)],
          )
        } catch {
          logger.warning("Could not replace non-qualified path: \(error.localizedDescription)")
        }
      } else if !element.path.contains("/") {
        // Path has macos://ui/ prefix but doesn't contain hierarchy separators
        // This indicates it's a partial path, not a fully qualified one
        do {
          // Try to generate a more complete path
          let fullPath = try element.generatePath()
          elementDescriptorLogger.debug(
            "Replacing partial path with fully qualified path",
            metadata: [
              "old": .string(element.path),
              "new": .string(fullPath),
            ])
          element.path = fullPath
        } catch {
          logger
            .warning(
              "Could not generate fully qualified path from partial path: \(error.localizedDescription)",
            )
        }
      } else {
        // Element already has a fully qualified path (likely from path filtering)
        // Log it to help with debugging
        elementDescriptorLogger.debug(
          "Element already has fully qualified path",
          metadata: ["path": .string(element.path)],
        )
      }

      // Verify the path is fully qualified
      if !element.path.hasPrefix("macos://ui/") || !element.path.contains("/") {
        logger.warning("Path may not be fully qualified", metadata: ["path": .string(element.path)])
      }

      // Use the EnhancedElementDescriptor from the Models directory
      return EnhancedElementDescriptor.from(element: element, maxDepth: maxDepth, showCoordinates: showCoordinates)
    }
  }

  /// Format a response as JSON
  /// - Parameter data: The data to format
  /// - Returns: The formatted tool content
  private func formatResponse(_ data: some Encodable) throws -> [Tool.Content] {
    let encoder = JSONConfiguration.encoder

    do {
      let jsonData = try encoder.encode(data)
      guard let jsonString = String(data: jsonData, encoding: .utf8) else {
        throw MCPError.internalError("Failed to encode response as JSON")
      }

      return [.text(jsonString)]
    } catch {
      logger.error(
        "Error encoding response as JSON",
        metadata: [
          "error": "\(error.localizedDescription)"
        ])
      throw MCPError.internalError(
        "Failed to encode response as JSON: \(error.localizedDescription)")
    }
  }
}
