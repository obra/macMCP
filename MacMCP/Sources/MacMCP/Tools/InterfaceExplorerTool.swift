// ABOUTME: InterfaceExplorerTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import CoreGraphics
import Foundation
import Logging
import MacMCPUtilities
import MCP

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
  3. Search by content: Use textContains to search across all element fields
  4. Navigate hierarchy: Use 'element' scope to explore specific elements deeper
  5. Performance optimization: Reduce maxDepth for faster responses

  Filtering capabilities:
  - role: Element type (AXButton, AXTextField, AXWindow, etc.)
  - value/valueContains: Element values or partial matches  
  - textContains: Universal text search across all text fields (now includes role, identifier, title, description)
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
    { [self] params in try await self.processRequest(params) }
  }

  /// The logger
  private let logger: Logger

  /// Create a new interface explorer tool
  /// - Parameters:
  ///   - accessibilityService: The accessibility service to use
  ///   - logger: Optional logger to use
  public init(accessibilityService: any AccessibilityServiceProtocol, logger: Logger? = nil) {
    self.accessibilityService = accessibilityService
    self.logger = logger ?? Logger(label: "mcp.tool.interface_explorer")

    // Set tool annotations
    annotations = .init(
      title: "macOS UI Explorer",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
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
          "description": .string(
            "Exploration scope: 'application' (specific app), 'system' (all apps), 'position' (coordinates), 'element' (specific element)",
          ),
          "enum": .array([
            .string("system"), .string("application"), .string("position"), .string("element"),
            .string("element"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string(
            "Application bundle identifier (required for 'application' scope, e.g., 'com.apple.calculator')",
          ),
        ]),
        "id": .object([
          "type": .string("string"),
          "description": .string(
            "Element ID (required for 'element' scope) for detailed element exploration",
          ),
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
          "description": .string(
            "UI hierarchy depth: 10-15 for performance, 20+ for comprehensive exploration (default: 15)",
          ), "default": .double(15),
        ]),
        "filter": .object([
          "type": .string("object"),
          "description": .string(
            "Filter elements by properties (role, title, value, description) with exact or partial matching",
          ),
          "properties": .object([
            "role": .object([
              "type": .string("string"),
              "description": .string(
                "Filter by accessibility role (e.g., 'AXButton', 'AXTextField', 'AXWindow')",
              ),
            ]),
            "value": .object([
              "type": .string("string"), "description": .string("Filter by exact value match"),
            ]),
            "valueContains": .object([
              "type": .string("string"),
              "description": .string("Filter by value containing this text"),
            ]),
            "textContains": .object([
              "type": .string("string"),
              "description": .string(
                "Filter by text containing this string in any text field (role, title, description, value, identifier)",
              ),
            ]),
            "anyFieldContains": .object([
              "type": .string("string"),
              "description": .string(
                "Search across all text fields simultaneously (title, description, value, identifier, role)",
              ),
            ]),
            "isInteractable": .object([
              "type": .string("boolean"),
              "description": .string(
                "Filter for elements that can be acted upon (clickable, editable, etc.)",
              ),
            ]),
            "isEnabled": .object([
              "type": .string("boolean"), "description": .string("Filter by enabled state"),
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
          "description": .string(
            "Interactive element types to discover: button, textfield, dropdown, etc. (default: any)",
          ),
          "items": .object([
            "type": .string("string"),
            "enum": .array([
              .string("button"), .string("checkbox"), .string("radio"), .string("textfield"),
              .string("dropdown"), .string("slider"), .string("link"), .string("tab"),
              .string("any"),
            ]),
          ]), "default": .array([.string("any")]),
        ]),
        "includeHidden": .object([
          "type": .string("boolean"),
          "description": .string(
            "Include hidden/invisible elements in results (default: false for cleaner output)",
          ), "default": .bool(false),
        ]),
        "includeDisabled": .object([
          "type": .string("boolean"),
          "description": .string(
            "Include disabled elements in results (default: false for cleaner output)"),
          "default": .bool(false),
        ]),
        "includeNonInteractable": .object([
          "type": .string("boolean"),
          "description": .string(
            "Include non-interactable elements in results (default: false for cleaner output)",
          ), "default": .bool(false),
        ]),
        "showCoordinates": .object([
          "type": .string("boolean"),
          "description": .string(
            "Include position and size information in results (default: false for cleaner output)",
          ), "default": .bool(false),
        ]),
        "limit": .object([
          "type": .string("integer"),
          "description": .string(
            "Maximum elements to return (default: 100, increase for comprehensive exploration)",
          ), "default": .int(100),
        ]),
      ]), "required": .array([.string("scope")]), "additionalProperties": .bool(false),
      "examples": .array([
        .object(["scope": .string("application"), "bundleId": .string("com.apple.calculator")]),
        .object([
          "scope": .string("application"), "bundleId": .string("com.apple.calculator"),
          "maxDepth": .int(20),
          "filter": .object(["role": .string("AXButton")]),
        ]),
        .object([
          "scope": .string("application"), "bundleId": .string("com.apple.calculator"),
          "maxDepth": .int(15),
        ]),
        .object([
          "scope": .string("application"), "bundleId": .string("com.apple.textedit"),
          "filter": .object(["titleContains": .string("Save")]),
        ]),
        .object([
          "scope": .string("application"), "bundleId": .string("com.apple.calculator"),
          "filter": .object(["textContains": .string("5")]),
        ]),
        .object([
          "scope": .string("application"), "bundleId": .string("com.apple.calculator"),
          "filter": .object(["isInteractable": .bool(true)]),
        ]), .object(["scope": .string("position"), "x": .int(400), "y": .int(300)]),
        .object([
          "scope": .string("element"), "id": .string("element-uuid-example"), "maxDepth": .int(10),
        ]),
      ]),
    ])
  }

  /// Process a request for the tool
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else { throw MCPError.invalidParams("Parameters are required") }

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
        if let typeStr = typeValue.stringValue { elementTypes.append(typeStr) }
      }
    }
    if elementTypes.isEmpty { elementTypes = ["any"] }

    // Extract filter criteria
    var role: String?
    var value: String?
    var valueContains: String?
    var textContains: String?
    var anyFieldContains: String?
    var isInteractable: Bool?
    var isEnabled: Bool?
    var inMenus: Bool?
    var inMainContent: Bool?

    if case .object(let filterObj)? = params["filter"] {
      role = filterObj["role"]?.stringValue
      value = filterObj["value"]?.stringValue
      valueContains = filterObj["valueContains"]?.stringValue
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
          value: value,
          valueContains: valueContains,
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
          value: value,
          valueContains: valueContains,
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
          value: value,
          valueContains: valueContains,
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
        guard let elementId = params["id"]?.stringValue else {
          throw MCPError.invalidParams("id is required when scope is 'element'")
        }

        // Bundle ID is optional for element scope
        let bundleId = params["bundleId"]?.stringValue

        return try await handleElementScope(
          elementId: elementId,
          bundleId: bundleId,
          maxDepth: maxDepth,
          includeHidden: includeHidden,
          includeDisabled: includeDisabled,
          includeNonInteractable: includeNonInteractable,
          showCoordinates: showCoordinates,
          limit: limit,
          role: role,
          value: value,
          valueContains: valueContains,
          textContains: textContains,
          anyFieldContains: anyFieldContains,
          isInteractable: isInteractable,
          isEnabled: isEnabled,
          inMenus: inMenus,
          inMainContent: inMainContent,
          elementTypes: elementTypes,
        )

      default: throw MCPError.invalidParams("Invalid scope: \(scopeValue)")
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
    value: String?,
    valueContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Always use AccessibilityService filtering now that it supports all filters
    var elements = try await accessibilityService.findUIElements(
      role: role,
      title: nil,
      titleContains: nil,
      value: value,
      valueContains: valueContains,
      description: nil,
      descriptionContains: nil,
      textContains: textContains,
      anyFieldContains: anyFieldContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes,
      scope: .systemWide,
      recursive: true,
      maxDepth: maxDepth,
    )

    // Apply limit if needed
    if elements.count > limit { elements = Array(elements.prefix(limit)) }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(
      elements: elements,
      maxDepth: maxDepth,
      showCoordinates: showCoordinates,
    )

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
    value: String?,
    valueContains: String?,
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

    // Always use AccessibilityService filtering now that it supports all filters
    elements = try await accessibilityService.findUIElements(
      role: role,
      title: nil,
      titleContains: nil,
      value: value,
      valueContains: valueContains,
      description: nil,
      descriptionContains: nil,
      textContains: textContains,
      anyFieldContains: anyFieldContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes,
      scope: .application(bundleId: bundleId),
      recursive: true,
      maxDepth: maxDepth,
    )

    // Apply limit if needed
    if elements.count > limit { elements = Array(elements.prefix(limit)) }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(
      elements: elements,
      maxDepth: maxDepth,
      showCoordinates: showCoordinates,
    )

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
    value: String?,
    valueContains: String?,
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
    if role != nil || value != nil || valueContains != nil || textContains != nil
      || anyFieldContains != nil
      || isInteractable != nil || isEnabled != nil || inMenus != nil || inMainContent != nil
      || !elementTypes.contains("any") || !includeHidden
    {
      elements = applyAdditionalFilters(
        elements: elements,
        role: role,
        value: value,
        valueContains: valueContains,
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
    let descriptors = convertToEnhancedDescriptors(
      elements: elements,
      maxDepth: maxDepth,
      showCoordinates: showCoordinates,
    )

    // Apply limit
    let limitedDescriptors = descriptors.prefix(limit)

    // Return formatted response
    return try formatResponse(Array(limitedDescriptors))
  }

  /// Handle element scope
  private func handleElementScope(
    elementId: String,
    bundleId: String?,
    maxDepth: Int,
    includeHidden: Bool,
    includeDisabled: Bool,
    includeNonInteractable: Bool,
    showCoordinates: Bool,
    limit: Int,
    role: String?,
    value: String?,
    valueContains: String?,
    textContains: String?,
    anyFieldContains: String?,
    isInteractable: Bool?,
    isEnabled: Bool?,
    inMenus: Bool?,
    inMainContent: Bool?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Parse and resolve the element ID (handles both opaque IDs and raw paths)
    do {
      let parsedPath = try ElementPath.parseElementId(elementId)
      let axElement = try await parsedPath.resolve(using: accessibilityService)

      // Convert to UIElement
      let element = try AccessibilityElement.convertToUIElement(
        axElement, recursive: true, maxDepth: maxDepth,
      )

      // If we're searching within this element, we need to apply filters to its children
      var resultElements: [UIElement] = []

      if role != nil || value != nil || valueContains != nil || textContains != nil
        || anyFieldContains != nil
        || isInteractable != nil || isEnabled != nil || inMenus != nil || inMainContent != nil
        || !elementTypes.contains("any")
      {
        // For filtering, we need to process the element and its descendants
        // Now search within this element for matching elements
        resultElements = findMatchingDescendants(
          in: element,
          role: role,
          value: value,
          valueContains: valueContains,
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
        if !includeHidden { resultElements = filterVisibleElements(resultElements) }
        if !includeDisabled { resultElements = filterEnabledElements(resultElements) }
        if !includeNonInteractable { resultElements = filterInteractableElements(resultElements) }
      }

      // Convert to enhanced element descriptors
      let descriptors = convertToEnhancedDescriptors(
        elements: resultElements,
        maxDepth: maxDepth,
        showCoordinates: showCoordinates,
      )

      // Apply limit
      let limitedDescriptors = descriptors.prefix(limit)

      // Return formatted response
      return try formatResponse(Array(limitedDescriptors))
    } catch let pathError as ElementPathError {
      // If there's a path resolution error, provide specific information
      throw MCPError.internalError("Failed to resolve element ID: \(pathError.description)")
    } catch {
      // For other errors
      throw MCPError.internalError("Error finding element by path: \(error.localizedDescription)")
    }
  }

  /// Find matching descendants in an element hierarchy
  private func findMatchingDescendants(
    in element: UIElement,
    role: String?,
    value: String?,
    valueContains: String?,
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
      title: nil,
      titleContains: nil,
      value: value,
      valueContains: valueContains,
      description: nil,
      descriptionContains: nil,
      textContains: textContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes,
      includeHidden: includeHidden,
    )
    // Use the UIElement's findMatchingDescendants method
    return element.findMatchingDescendants(criteria: criteria, maxDepth: maxDepth, limit: limit)
  }

  /// Apply additional filters not handled by the accessibility service
  private func applyAdditionalFilters(
    elements: [UIElement],
    valueContains: String? = nil,
    elementTypes: [String]? = nil,
    includeHidden: Bool = true,
    includeNonInteractable: Bool = true,
    limit: Int = 100,
  ) -> [UIElement] {
    applyAdditionalFilters(
      elements: elements,
      role: nil,
      value: valueContains,
      valueContains: valueContains,
      textContains: nil,
      anyFieldContains: nil,
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
    value: String? = nil,
    valueContains: String? = nil,
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
      title: nil, // No longer supported at tool level, rely on textContains
      titleContains: nil, // No longer supported at tool level, rely on textContains
      value: value,
      valueContains: valueContains,
      description: nil, // No longer supported at tool level, rely on textContains
      descriptionContains: nil, // No longer supported at tool level, rely on textContains
      textContains: textContains,
      isInteractable: isInteractable,
      isEnabled: isEnabled,
      inMenus: inMenus,
      inMainContent: inMainContent,
      elementTypes: elementTypes ?? ["any"],
      includeHidden: includeHidden,
    )
    // Use the static UIElement filterElements method
    var filteredElements = UIElement.filterElements(
      elements: elements, criteria: criteria, limit: limit,
    )
    // Apply anyFieldContains filter if specified
    if let searchText = anyFieldContains, !searchText.isEmpty {
      filteredElements = filteredElements.filter { element in
        // Search across all string fields
        let searchFields = [
          element.role, element.title, element.elementDescription, element.value,
          element.identifier,
        ].compactMap(\.self)
        return searchFields.contains { field in field.localizedCaseInsensitiveContains(searchText) }
      }
    }
    return filteredElements
  }

  /// Filter to only include visible elements
  private func filterVisibleElements(_ elements: [UIElement]) -> [UIElement] {
    elements.filter { element in
      // If this element isn't visible, exclude it
      if !element.isVisible { return false }

      // Include visible elements
      return true
    }
  }

  /// Filter to only include enabled elements
  private func filterEnabledElements(_ elements: [UIElement]) -> [UIElement] {
    elements.filter { element in
      // Include only enabled elements
      element.isEnabled
    }
  }

  /// Filter to only include main content elements (exclude menu bars and menu items)
  private func filterMainContentElements(_ elements: [UIElement]) -> [UIElement] {
    filterWithHierarchyPreservation(elements) { element in
      // Exclude elements in menu context
      !element.isInMenuContext()
    }
  }

  /// Filter to only include interactable elements
  private func filterInteractableElements(_ elements: [UIElement]) -> [UIElement] {
    filterWithHierarchyPreservation(elements) { element in element.isInteractable }
  }

  /// Smart hierarchy preservation with chain skipping.
  /// Keeps containers if they have descendants that match the predicate,
  /// and skips unnecessary single-child container chains.
  private func filterWithHierarchyPreservation(
    _ elements: [UIElement],
    keepIf predicate: @escaping (UIElement) -> Bool = { $0.isInteractable },
  ) -> [UIElement] {
    let filteredElements = elements.compactMap { element in
      processElementForHierarchyPreservation(element, keepIf: predicate)
    }
    // Post-process to flatten display structure while preserving paths
    return flattenDisplayStructure(filteredElements)
  }

  /// Post-processing step that reparents children to skip useless containers
  /// while preserving their original element paths for resolution
  private func flattenDisplayStructure(_ elements: [UIElement]) -> [UIElement] {
    elements.compactMap { element in flattenElementDisplayStructure(element) }
  }

  /// Flatten a single element's display structure by reparenting children of useless containers
  private func flattenElementDisplayStructure(_ element: UIElement) -> UIElement? {
    // First, recursively process children
    let processedChildren = element.children.compactMap { child in
      flattenElementDisplayStructure(child)
    }
    // Check if this element is a "useless" container that should be flattened
    // A useless container is:
    // 1. Non-interactable
    // 2. Has exactly one child
    // 3. That child has meaningful content
    if !element.isInteractable, processedChildren.count == 1 {
      let onlyChild = processedChildren[0]
      // If the child is interactable or has multiple children, reparent its children to skip this
      // container
      if onlyChild.isInteractable || onlyChild.children.count > 1 {
        // Return the child but with this element's parent relationship
        return UIElement(
          path: onlyChild.path, // Keep the child's original path!
          role: onlyChild.role,
          title: onlyChild.title,
          value: onlyChild.value,
          elementDescription: onlyChild.elementDescription,
          identifier: onlyChild.identifier,
          frame: onlyChild.frame,
          normalizedFrame: onlyChild.normalizedFrame,
          viewportFrame: onlyChild.viewportFrame,
          frameSource: onlyChild.frameSource,
          parent: element.parent, // Use this element's parent to skip the container
          children: onlyChild.children,
          attributes: onlyChild.attributes,
          actions: onlyChild.actions,
          axElement: onlyChild.axElement,
        )
      }
    }
    // Normal case: return element with processed children
    return UIElement(
      path: element.path,
      role: element.role,
      title: element.title,
      value: element.value,
      elementDescription: element.elementDescription,
      identifier: element.identifier,
      frame: element.frame,
      normalizedFrame: element.normalizedFrame,
      viewportFrame: element.viewportFrame,
      frameSource: element.frameSource,
      parent: element.parent,
      children: processedChildren,
      attributes: element.attributes,
      actions: element.actions,
      axElement: element.axElement,
    )
  }

  /// Process a single element for hierarchy preservation and chain skipping
  private func processElementForHierarchyPreservation(
    _ element: UIElement,
    keepIf predicate: @escaping (UIElement) -> Bool = { $0.isInteractable },
  ) -> UIElement? {
    // If the element matches the predicate, always keep it
    if predicate(element) { return element }
    // If the element has no descendants that match the predicate, remove it
    if !element.hasDescendantsMatching(predicate) { return nil }
    // NOTE: Removed path-breaking tree flattening from here
    // Tree flattening now happens in post-processing to preserve element paths

    // Normal case: keep the container but filter its children
    // Recursively process children first
    let processedChildren = element.children.compactMap { child in
      processElementForHierarchyPreservation(child, keepIf: predicate)
    }
    guard !processedChildren.isEmpty else { return nil }
    let processedElement = UIElement(
      path: element.path,
      role: element.role,
      title: element.title,
      value: element.value,
      elementDescription: element.elementDescription,
      identifier: element.identifier,
      frame: element.frame,
      normalizedFrame: element.normalizedFrame,
      viewportFrame: element.viewportFrame,
      frameSource: element.frameSource,
      parent: element.parent,
      children: processedChildren,
      attributes: element.attributes,
      actions: element.actions,
      axElement: element.axElement,
    )
    return processedElement
  }

  /// Convert UI elements to enhanced element descriptors
  private func convertToEnhancedDescriptors(
    elements: [UIElement], maxDepth: Int, showCoordinates: Bool,
  )
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
            "Could not generate fully qualified path for element: \(error.localizedDescription)",
          )
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
            metadata: ["old": .string(element.path), "new": .string(fullPath)],
          )
          element.path = fullPath
        } catch {
          logger.warning(
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
      return EnhancedElementDescriptor.from(
        element: element,
        maxDepth: maxDepth,
        showCoordinates: showCoordinates,
      )
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
        "Error encoding response as JSON", metadata: ["error": "\(error.localizedDescription)"],
      )
      throw MCPError.internalError(
        "Failed to encode response as JSON: \(error.localizedDescription)",
      )
    }
  }
}
