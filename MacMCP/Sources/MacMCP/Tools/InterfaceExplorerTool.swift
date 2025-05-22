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
  public let description =
    "Explore and examine UI elements and their capabilities in macOS applications - essential for discovering elements to interact with"

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
      title: "Interface Explorer",
      readOnlyHint: true,
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
            "The scope of UI elements to retrieve: system (all apps, very broad), application (specific app by bundleId), focused (currently active app, RECOMMENDED), position (element at screen coordinates), element (specific element by ID), path (element by path)"
          ),
          "enum": .array([
            .string("system"),
            .string("application"),
            .string("focused"),
            .string("position"),
            .string("element"),
            .string("path"),
          ]),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string(
            "The bundle identifier of the application to retrieve (required for 'application' scope)"
          ),
        ]),
        "elementPath": .object([
          "type": .string("string"),
          "description": .string(
            "The path of a specific element to retrieve using macos://ui/ notation (required for 'path' scope)"
          ),
        ]),
        "x": .object([
          "type": .array([.string("number"), .string("integer")]),
          "description": .string("X coordinate for position scope"),
        ]),
        "y": .object([
          "type": .array([.string("number"), .string("integer")]),
          "description": .string("Y coordinate for position scope"),
        ]),
        "maxDepth": .object([
          "type": .string("number"),
          "description": .string(
            "Maximum depth of the element hierarchy to retrieve (higher values provide more detail but slower response)"
          ),
          "default": .double(15),
        ]),
        "filter": .object([
          "type": .string("object"),
          "description": .string("Filter criteria for elements"),
          "properties": .object([
            "role": .object([
              "type": .string("string"),
              "description": .string("Filter by accessibility role"),
            ]),
            "title": .object([
              "type": .string("string"),
              "description": .string("Filter by title (exact match)"),
            ]),
            "titleContains": .object([
              "type": .string("string"),
              "description": .string("Filter by title containing this text"),
            ]),
            "value": .object([
              "type": .string("string"),
              "description": .string("Filter by value (exact match)"),
            ]),
            "valueContains": .object([
              "type": .string("string"),
              "description": .string("Filter by value containing this text"),
            ]),
            "description": .object([
              "type": .string("string"),
              "description": .string("Filter by description (exact match)"),
            ]),
            "descriptionContains": .object([
              "type": .string("string"),
              "description": .string("Filter by description containing this text"),
            ]),
          ]),
        ]),
        "elementTypes": .object([
          "type": .string("array"),
          "description": .string(
            "Types of interactive elements to find (when discovering interactive elements)"),
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
          "description": .string("Whether to include hidden elements"),
          "default": .bool(false),
        ]),
        "limit": .object([
          "type": .string("integer"),
          "description": .string("Maximum number of elements to return"),
          "default": .int(100),
        ]),
      ]),
      "required": .array([.string("scope")]),
      "additionalProperties": .bool(false),
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

    if case .object(let filterObj)? = params["filter"] {
      role = filterObj["role"]?.stringValue
      title = filterObj["title"]?.stringValue
      titleContains = filterObj["titleContains"]?.stringValue
      value = filterObj["value"]?.stringValue
      valueContains = filterObj["valueContains"]?.stringValue
      description = filterObj["description"]?.stringValue
      descriptionContains = filterObj["descriptionContains"]?.stringValue
    }

    // Process based on scope
    switch scopeValue {
    case "system":
      return try await handleSystemScope(
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
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
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        elementTypes: elementTypes,
      )

    case "focused":
      return try await handleFocusedScope(
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
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
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        elementTypes: elementTypes,
      )

    case "element":
      // Validate element ID
      guard let elementPath = params["elementPath"]?.stringValue else {
        throw MCPError.invalidParams("elementPath is required when scope is 'element'")
      }

      // Bundle ID is optional for element scope
      let bundleId = params["bundleId"]?.stringValue

      return try await handleElementScope(
        elementPath: elementPath,
        bundleId: bundleId,
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        elementTypes: elementTypes,
      )

    case "path":
      // Validate element path
      guard let elementPath = params["elementPath"]?.stringValue else {
        throw MCPError.invalidParams("elementPath is required when scope is 'path'")
      }

      return try await handlePathScope(
        elementPath: elementPath,
        maxDepth: maxDepth,
        includeHidden: includeHidden,
        limit: limit,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
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
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
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
      || description != nil || descriptionContains != nil || !elementTypes.contains("any")
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
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        limit: limit,
      )
    } else {
      elements = [systemElement]

      // Apply hidden filter if specified
      if !includeHidden {
        elements = filterVisibleElements(elements)
      }
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)

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
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Get application-specific UI state
    var elements: [UIElement]

    if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
      || description != nil || descriptionContains != nil || !elementTypes.contains("any")
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
        elementTypes: elementTypes,
        includeHidden: includeHidden,
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

      // Apply hidden filter if specified
      if !includeHidden {
        elements = filterVisibleElements(elements)
      }
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)

    // Apply limit
    let limitedDescriptors = descriptors.prefix(limit)

    // Return formatted response
    return try formatResponse(Array(limitedDescriptors))
  }

  /// Handle focused application scope
  private func handleFocusedScope(
    maxDepth: Int,
    includeHidden: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    elementTypes: [String],
  ) async throws -> [Tool.Content] {
    // Get focused application UI state
    var elements: [UIElement]

    if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
      || description != nil || descriptionContains != nil || !elementTypes.contains("any")
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
        scope: .focusedApplication,
        recursive: true,
        maxDepth: maxDepth,
      )

      // Apply additional filters
      elements = applyAdditionalFilters(
        elements: elements,
        role: role,
        title: title,
        titleContains: titleContains,
        value: value,
        valueContains: valueContains,
        description: description,
        descriptionContains: descriptionContains,
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        limit: limit,
      )
    } else {
      // Get the full focused application element
      let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(
        recursive: true,
        maxDepth: maxDepth,
      )
      elements = [focusedElement]

      // Apply hidden filter if specified
      if !includeHidden {
        elements = filterVisibleElements(elements)
      }
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)

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
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
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
      || description != nil || descriptionContains != nil || !elementTypes.contains("any")
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
        elementTypes: elementTypes,
        includeHidden: includeHidden,
        limit: limit,
      )
    }

    // Convert to enhanced element descriptors
    let descriptors = convertToEnhancedDescriptors(elements: elements, maxDepth: maxDepth)

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
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
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
        || description != nil || descriptionContains != nil || !elementTypes.contains("any")
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
          elementTypes: elementTypes,
          includeHidden: includeHidden,
          maxDepth: maxDepth,
          limit: limit,
        )
      } else {
        // If no filters, just use the element as is
        resultElements = [element]

        // Apply hidden filter if specified
        if !includeHidden {
          resultElements = filterVisibleElements(resultElements)
        }
      }

      // Convert to enhanced element descriptors
      let descriptors = convertToEnhancedDescriptors(elements: resultElements, maxDepth: maxDepth)

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

  /// Handle path scope
  private func handlePathScope(
    elementPath: String,
    maxDepth: Int,
    includeHidden: Bool,
    limit: Int,
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
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

      // Don't set element.path here
      // We'll calculate accurate hierarchical paths for each element instead

      // If we're searching within this element, apply filters to it and its children
      var resultElements: [UIElement] = []

      if role != nil || title != nil || titleContains != nil || value != nil || valueContains != nil
        || description != nil || descriptionContains != nil || !elementTypes.contains("any")
      {
        // Find matching elements within the hierarchy
        resultElements = findMatchingDescendants(
          in: element,
          role: role,
          title: title,
          titleContains: titleContains,
          value: value,
          valueContains: valueContains,
          description: description,
          descriptionContains: descriptionContains,
          elementTypes: elementTypes,
          includeHidden: includeHidden,
          maxDepth: maxDepth,
          limit: limit,
        )

        // When using path filter, ensure we have proper full paths
        // This ensures we have complete hierarchy information
        for resultElement in resultElements {
          // For path filtering, we need to handle both fully qualified and partial paths
          if elementPath.hasPrefix("macos://ui/"), elementPath.contains("/") {
            // This appears to be a fully qualified path, so use it directly
            resultElement.path = elementPath
            logger.debug(
              "PATH FILTER - Using provided fully qualified path",
              metadata: ["path": "\(elementPath)"],
            )
          } else {
            // Try to generate a fully qualified path
            do {
              let fullPath = try resultElement.generatePath()
              resultElement.path = fullPath
              logger.debug(
                "PATH FILTER - Generated fully qualified path",
                metadata: [
                  "original": "\(elementPath)",
                  "fully_qualified": "\(fullPath)",
                ])
            } catch {
              // Fall back to using the provided path if generation fails
              resultElement.path = elementPath
              logger.warning(
                "PATH FILTER - Using partial path due to generation failure",
                metadata: ["path": "\(elementPath)"],
              )
            }
          }
        }
      } else {
        // If no filters, just use the element itself
        resultElements = [element]

        // Apply visibility filter if needed
        if !includeHidden {
          resultElements = filterVisibleElements(resultElements)
        }

        // When using path-based filtering, set the base path for each element
        // This ensures clients have the proper context for each element
        for resultElement in resultElements {
          // For path filtering, we set a base path that the element will extend
          // when creating its fully qualified path
          if elementPath.hasPrefix("macos://ui/"), elementPath.contains("/") {
            // This appears to be a fully qualified path, so use it directly
            resultElement.path = elementPath
            logger.debug(
              "Using provided fully qualified path", metadata: ["path": "\(elementPath)"])
          } else {
            // Try to generate a fully qualified path
            do {
              let fullPath = try resultElement.generatePath()
              resultElement.path = fullPath
              logger.debug(
                "Generated fully qualified path for element",
                metadata: ["path": "\(fullPath)"],
              )
            } catch {
              // Fall back to using the provided path if generation fails
              resultElement.path = elementPath
              logger.warning(
                "Using partial path due to path generation failure",
                metadata: ["path": "\(elementPath)"],
              )
            }
          }
        }
      }

      // Convert to enhanced element descriptors
      let descriptors = convertToEnhancedDescriptors(elements: resultElements, maxDepth: maxDepth)

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
      elementTypes: elementTypes,
      includeHidden: includeHidden,
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
    elementTypes: [String]? = nil,
    includeHidden: Bool = true,
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
      elementTypes: elementTypes ?? ["any"],
      includeHidden: includeHidden
    )
    
    // Use the static UIElement filterElements method
    return UIElement.filterElements(
      elements: elements,
      criteria: criteria,
      limit: limit
    )
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

  /// Convert UI elements to enhanced element descriptors
  private func convertToEnhancedDescriptors(elements: [UIElement], maxDepth: Int)
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
      return EnhancedElementDescriptor.from(element: element, maxDepth: maxDepth)
    }
  }

  /// Format a response as JSON
  /// - Parameter data: The data to format
  /// - Returns: The formatted tool content
  private func formatResponse(_ data: some Encodable) throws -> [Tool.Content] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

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
