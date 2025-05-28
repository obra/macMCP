// ABOUTME: UIInteractionTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// A tool for interacting with UI elements on macOS
public struct UIInteractionTool {
  /// The name of the tool
  public let name = ToolNames.uiInteraction

  /// Description of the tool
  public let description = """
Interact with UI elements on macOS through clicking, dragging, scrolling, and coordinate-based actions.

IMPORTANT: Use InterfaceExplorerTool first to discover element IDs.

Available actions:
- click: Single click on element or coordinates
- double_click: Double click on element or coordinates  
- right_click: Right click on element or coordinates to open context menus
- drag: Drag from one element to another (file operations, selections)
- scroll: Scroll within scrollable elements or views

Interaction methods:
1. Element-based: Use id from InterfaceExplorerTool (preferred for reliability)
2. Coordinate-based: Use x, y coordinates for direct positioning (when elements unavailable)

Common workflows:
1. Explore UI: InterfaceExplorerTool → find element id
2. Click element: Use id from InterfaceExplorerTool
3. Drag operations: Use source id + target targetId  
4. Scroll content: Use container id + direction + amount
5. Coordinate fallback: Use x, y coordinates when element detection fails

Coordinate system: Screen pixels, (0,0) = top-left corner.
"""

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The UI interaction service
  private let interactionService: any UIInteractionServiceProtocol

  /// The accessibility service
  private let accessibilityService: any AccessibilityServiceProtocol

  /// The application service
  private let applicationService: any ApplicationServiceProtocol

  /// The change detection service
  private let changeDetectionService: UIChangeDetectionServiceProtocol

  /// The interaction wrapper for change detection
  private let interactionWrapper: InteractionWithChangeDetection

  /// The logger
  private let logger: Logger

  /// Create a new UI interaction tool
  /// - Parameters:
  ///   - interactionService: The UI interaction service to use
  ///   - accessibilityService: The accessibility service to use
  ///   - applicationService: The application service to use
  ///   - changeDetectionService: The change detection service to use
  ///   - logger: Optional logger to use
  public init(
    interactionService: any UIInteractionServiceProtocol,
    accessibilityService: any AccessibilityServiceProtocol,
    applicationService: any ApplicationServiceProtocol,
    changeDetectionService: UIChangeDetectionServiceProtocol,
    logger: Logger? = nil
  ) {
    self.interactionService = interactionService
    self.accessibilityService = accessibilityService
    self.applicationService = applicationService
    self.changeDetectionService = changeDetectionService
    self.interactionWrapper = InteractionWithChangeDetection(changeDetectionService: changeDetectionService)
    self.logger = logger ?? Logger(label: "mcp.tool.ui_interact")

    // Set tool annotations first
    annotations = .init(
      title: "macOS UI Interaction",
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: true
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Create the input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    var properties: [String: Value] = [
        "action": .object([
          "type": .string("string"),
          "description": .string("UI interaction type: click/double_click/right_click for buttons/links, drag for file ops, scroll for navigation"),
          "enum": .array([
            .string("click"),
            .string("double_click"),
            .string("right_click"),
            .string("drag"),
            .string("scroll"),
          ]),
        ]),
        "id": .object([
          "type": .string("string"),
          "description": .string("Element ID from \(ToolNames.interfaceExplorer) - preferred method for reliability"),
        ]),
        "appBundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle ID for element context (e.g., 'com.apple.calculator')"),
        ]),
        "x": .object([
          "type": .string("number"),
          "description": .string("X coordinate in screen pixels (0 = left edge) - use when element ID unavailable"),
        ]),
        "y": .object([
          "type": .string("number"),
          "description": .string("Y coordinate in screen pixels (0 = top edge) - use when element ID unavailable"),
        ]),
        "targetId": .object([
          "type": .string("string"),
          "description": .string("Destination element ID for drag operations - required for 'drag' action"),
        ]),
        "direction": .object([
          "type": .string("string"),
          "description": .string("Scroll direction within scrollable element (required for 'scroll' action)"),
          "enum": .array([
            .string("up"),
            .string("down"),
            .string("left"),
            .string("right"),
          ]),
        ]),
        "amount": .object([
          "type": .string("number"),
          "description": .string("Scroll distance: 0.0 (minimal) to 1.0 (full page) - required for scroll action"),
          "minimum": .double(0.0),
          "maximum": .double(1.0),
        ]),
    ]
    
    // Add change detection properties
    properties.merge(ChangeDetectionHelper.addChangeDetectionSchemaProperties()) { _, new in new }
    
    return .object([
      "type": .string("object"),
      "properties": .object(properties),
      "required": .array([.string("action")]),
      "additionalProperties": .bool(false),
      "examples": .array([
        .object([
          "action": .string("click"),
          "id": .string("element-uuid-example"),
        ]),
        .object([
          "action": .string("click"),
          "x": .int(400),
          "y": .int(300),
        ]),
        .object([
          "action": .string("double_click"),
          "id": .string("element-uuid-example"),
        ]),
        .object([
          "action": .string("double_click"),
          "x": .int(400),
          "y": .int(300),
        ]),
        .object([
          "action": .string("right_click"),
          "id": .string("element-uuid-example"),
        ]),
        .object([
          "action": .string("right_click"),
          "x": .int(400),
          "y": .int(300),
        ]),
        .object([
          "action": .string("drag"),
          "id": .string("source-element-uuid"),
          "targetId": .string("target-element-uuid"),
        ]),
        .object([
          "action": .string("scroll"),
          "id": .string("element-uuid-example"),
          "direction": .string("down"),
          "amount": .double(0.5),
        ]),
      ]),
    ])
  }

  /// Tool handler function
  public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
    // Create services on demand to ensure we're in the right context
    let handlerLogger = Logger(label: "mcp.tool.ui_interact")

    let accessibilityService = AccessibilityService(
      logger: Logger(label: "mcp.tool.ui_interact.accessibility"),
    )
    let applicationService = ApplicationService(
      logger: Logger(label: "mcp.tool.ui_interact.application")
    )
    let interactionService = UIInteractionService(
      accessibilityService: accessibilityService,
      logger: Logger(label: "mcp.tool.ui_interact.interaction"),
    )
    let changeDetectionService = UIChangeDetectionService(
      accessibilityService: accessibilityService
    )
    let tool = UIInteractionTool(
      interactionService: interactionService,
      accessibilityService: accessibilityService,
      applicationService: applicationService,
      changeDetectionService: changeDetectionService,
      logger: handlerLogger,
    )

    // Extract and log the key parameters for debugging
    if let params {
      let action = params["action"]?.stringValue ?? "unknown"
      let elementId = params["id"]?.stringValue ?? "none"
      let appBundleId = params["appBundleId"]?.stringValue ?? "none"

      if action == "click" {
        if let x = params["x"]?.doubleValue, let y = params["y"]?.doubleValue {
          handlerLogger.debug("Position details", metadata: ["x": "\(x)", "y": "\(y)"])
        }
      }
    }

    do {
      let result = try await tool.processRequest(params)

      return result
    } catch {
      let nsError = error as NSError
      handlerLogger.error(
        "UIInteractionTool.handler error",
        metadata: [
          "error": "\(error.localizedDescription)",
          "domain": "\(nsError.domain)",
          "code": "\(nsError.code)",
          "info": "\(nsError.userInfo)",
        ])
      throw error
    }
  }

  /// Process a UI interaction request
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else {
      throw createInteractionError(
        message: "Parameters are required",
        context: ["toolName": name],
      ).asMCPError
    }

    // Get the action
    guard let actionValue = params["action"]?.stringValue else {
      throw createInteractionError(
        message: "Action is required",
        context: ["toolName": name],
      ).asMCPError
    }

    // Process based on action type
    switch actionValue {
    case "click":
      return try await handleClick(params)
    case "double_click":
      return try await handleDoubleClick(params)
    case "right_click":
      return try await handleRightClick(params)
    case "drag":
      return try await handleDrag(params)
    case "scroll":
      return try await handleScroll(params)
    default:
      throw createInteractionError(
        message:
          "Invalid action: \(actionValue). Must be one of: click, double_click, right_click, drag, scroll",
        context: [
          "toolName": name,
          "providedAction": actionValue,
          "validActions": "click, double_click, right_click, drag, scroll",
        ],
      ).asMCPError
    }
  }


  
  /// Extract bundle ID from element ID or parameters
  private func extractBundleID(from elementId: String, params: [String: Value]) -> String? {
    // First check if bundleId is explicitly provided in params
    if let appBundleId = params["appBundleId"]?.stringValue {
      return appBundleId
    }
    
    // Try to extract from element ID (elementId is already resolved)
    do {
      let path = try ElementPath.parse(elementId)
      if !path.segments.isEmpty {
        let firstSegment = path.segments[0]
        if firstSegment.role == "AXApplication" {
          return firstSegment.attributes["bundleId"] ?? firstSegment.attributes["@bundleId"]
        }
      }
    } catch {
      logger.debug("Could not parse element ID to extract bundleId: \(error)")
    }
    
    return nil
  }
  
  /// Ensure application is focused before interaction
  private func ensureApplicationFocus(bundleId: String) async throws {
    do {
      logger.debug("Activating application", metadata: ["bundleId": "\(bundleId)"])
      let activated = try await applicationService.activateApplication(bundleId: bundleId)
      if activated {
        logger.debug("Successfully activated application", metadata: ["bundleId": "\(bundleId)"])
        // Give the application a moment to come to the foreground
        try await Task.sleep(for: .milliseconds(100))
      } else {
        logger.warning("Failed to activate application", metadata: ["bundleId": "\(bundleId)"])
      }
    } catch {
      logger.warning("Error activating application", metadata: [
        "bundleId": "\(bundleId)",
        "error": "\(error.localizedDescription)"
      ])
      // Don't fail the entire interaction if activation fails
    }
  }
  
  /// Generic helper for element-based interactions
  private func performElementInteraction(
    elementId: String,
    action: String,
    interactionMethod: (String, String?) async throws -> Void,
    params: [String: Value]
  ) async throws -> [Tool.Content] {
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)
    
    // Resolve the element ID (handles both opaque IDs and raw paths)
    let resolvedElementId = ElementPath.resolveElementId(elementId)
    // Extract bundle ID for focus management and change detection
    let appBundleId = extractBundleID(from: resolvedElementId, params: params)
    
    // Ensure application is focused before interaction
    if let bundleId = appBundleId {
      try await ensureApplicationFocus(bundleId: bundleId)
    }

    // Before interacting, try to look up the element to verify it exists
    do {
      // Try to parse the element ID (resolvedElementId is already resolved)
      let path = try ElementPath.parse(resolvedElementId)

      // Make sure the path is valid
      if path.segments.isEmpty {
        logger.warning("Invalid element ID, no segments found")
      }

      // Check if the path already specifies an application - if so, don't override with appBundleId
      let pathSpecifiesApp: Bool
      if !path.segments.isEmpty {
        let firstSegment = path.segments[0]
        pathSpecifiesApp =
          firstSegment.role == "AXApplication"
          && (firstSegment.attributes["bundleId"] != nil
            || firstSegment.attributes["AXTitle"] != nil)
      } else {
        pathSpecifiesApp = false
      }

      // If path doesn't specify an app but appBundleId is provided, log a message
      if !pathSpecifiesApp, appBundleId != nil {
        logger.info(
          "Using provided appBundleId alongside element ID",
          metadata: ["appBundleId": "\(appBundleId!)"],
        )
      }

      // Attempt to resolve the path to verify it exists (only if path is not empty)
      // This is just for validation - actual resolution happens in interactionService
      if !resolvedElementId.isEmpty {
        do {
          _ = try await path.resolve(using: accessibilityService)
          logger.debug("Element ID verified and resolved successfully")
        } catch {
          logger.warning(
            "Element ID did not resolve, but will still attempt \(action) operation",
            metadata: ["error": "\(error.localizedDescription)"],
          )
        }
      }
    } catch {
      logger.warning(
        "Error parsing or validating element ID, but will still attempt \(action) operation",
        metadata: ["error": "\(error.localizedDescription)"],
      )
    }

    do {
      // Determine scope for change detection
      let scope: UIElementScope = appBundleId != nil ? .application(bundleId: appBundleId!) : .focusedApplication
      
      let result = try await interactionWrapper.performWithChangeDetection(
        scope: scope,
        detectChanges: detectChanges,
        delay: delay,
        maxDepth: 15
      ) {
        try await interactionMethod(resolvedElementId, appBundleId)
        let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
        return "Successfully \(action) element with ID: \(resolvedElementId)\(bundleIdInfo)"
      }

      return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
    } catch {
      let nsError = error as NSError
      logger.error(
        "\(action.capitalized) operation failed",
        metadata: [
          "error": "\(error.localizedDescription)",
          "domain": "\(nsError.domain)",
          "code": "\(nsError.code)",
          "elementId": "\(resolvedElementId)",
        ])
      
      // Create a more informative error that includes the actual ID
      let enhancedError = createInteractionError(
        message: "Failed to \(action) element with ID: \(resolvedElementId). \(error.localizedDescription)",
        context: [
          "toolName": name,
          "action": action,
          "originalElementId": elementId,
          "resolvedElementId": resolvedElementId,
          "originalError": error.localizedDescription,
        ]
      )
      throw enhancedError.asMCPError
    }
  }
  
  /// Generic helper for position-based interactions
  private func performPositionInteraction(
    x: Double,
    y: Double,
    action: String,
    interactionMethod: (CGPoint) async throws -> Void,
    params: [String: Value]
  ) async throws -> [Tool.Content] {
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)
    
    do {
      let result = try await interactionWrapper.performWithChangeDetection(
        detectChanges: detectChanges,
        delay: delay
      ) {
        try await interactionMethod(CGPoint(x: x, y: y))
        return "Successfully \(action) at position (\(x), \(y))"
      }

      return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
    } catch {
      logger.error(
        "Position \(action) operation failed", metadata: ["error": "\(error.localizedDescription)"])
      throw error
    }
  }

  /// Handle click action
  private func handleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    // Element ID click
    if let elementID = params["id"]?.stringValue {
      return try await performElementInteraction(
        elementId: elementID,
        action: "clicked",
        interactionMethod: { path, bundleId in
          try await interactionService.clickElementByPath(path: path, appBundleId: bundleId)
        },
        params: params
      )
    }

    // Position click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      return try await performPositionInteraction(
        x: xDouble,
        y: yDouble,
        action: "clicked",
        interactionMethod: { position in
          try await interactionService.clickAtPosition(position: position)
        },
        params: params
      )
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      return try await performPositionInteraction(
        x: Double(xInt),
        y: Double(yInt),
        action: "clicked",
        interactionMethod: { position in
          try await interactionService.clickAtPosition(position: position)
        },
        params: params
      )
    }

    logger.error(
      "Missing required parameters",
      metadata: ["details": "Click action requires either id or x,y coordinates"],
    )
    throw createInteractionError(
      message: "Click action requires either id or x,y coordinates",
      context: [
        "toolName": name,
        "action": "click",
        "providedParams": "\(params.keys.joined(separator: ", "))",
      ],
    ).asMCPError
  }

  /// Handle double click action
  private func handleDoubleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    // Element ID double click
    if let elementID = params["id"]?.stringValue {
      return try await performElementInteraction(
        elementId: elementID,
        action: "double-clicked",
        interactionMethod: { path, bundleId in
          try await interactionService.doubleClickElementByPath(path: path, appBundleId: bundleId)
        },
        params: params
      )
    }

    // Position double click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      return try await performPositionInteraction(
        x: xDouble,
        y: yDouble,
        action: "double-clicked",
        interactionMethod: { position in
          try await interactionService.doubleClickAtPosition(position: position)
        },
        params: params
      )
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      return try await performPositionInteraction(
        x: Double(xInt),
        y: Double(yInt),
        action: "double-clicked",
        interactionMethod: { position in
          try await interactionService.doubleClickAtPosition(position: position)
        },
        params: params
      )
    }

    logger.error(
      "Missing required parameters",
      metadata: ["details": "Double click action requires either id or x,y coordinates"],
    )
    throw createInteractionError(
      message: "Double click action requires either id or x,y coordinates",
      context: [
        "toolName": name,
        "action": "double_click",
        "providedParams": "\(params.keys.joined(separator: ", "))",
      ],
    ).asMCPError
  }

  /// Handle right click action
  private func handleRightClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    // Element ID right click
    if let elementID = params["id"]?.stringValue {
      return try await performElementInteraction(
        elementId: elementID,
        action: "right-clicked",
        interactionMethod: { path, bundleId in
          try await interactionService.rightClickElementByPath(path: path, appBundleId: bundleId)
        },
        params: params
      )
    }

    // Position right click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      return try await performPositionInteraction(
        x: xDouble,
        y: yDouble,
        action: "right-clicked",
        interactionMethod: { position in
          try await interactionService.rightClickAtPosition(position: position)
        },
        params: params
      )
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      return try await performPositionInteraction(
        x: Double(xInt),
        y: Double(yInt),
        action: "right-clicked",
        interactionMethod: { position in
          try await interactionService.rightClickAtPosition(position: position)
        },
        params: params
      )
    }

    logger.error(
      "Missing required parameters",
      metadata: ["details": "Right click action requires either id or x,y coordinates"],
    )
    throw createInteractionError(
      message: "Right click action requires either id or x,y coordinates",
      context: [
        "toolName": name,
        "action": "right_click",
        "providedParams": "\(params.keys.joined(separator: ", "))",
      ],
    ).asMCPError
  }

  /// Handle drag action
  private func handleDrag(_ params: [String: Value]) async throws -> [Tool.Content] {
    guard let sourceElementID = params["id"]?.stringValue else {
      throw createInteractionError(
        message: "Drag action requires id (source)",
        context: [
          "toolName": name,
          "action": "drag",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    guard let targetElementID = params["targetId"]?.stringValue else {
      throw createInteractionError(
        message: "Drag action requires targetId",
        context: [
          "toolName": name,
          "action": "drag",
          "sourceId": sourceElementID,
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }
    
    // Resolve both element IDs (handles both opaque IDs and raw paths)
    let sourceResolvedElementId = ElementPath.resolveElementId(sourceElementID)
    let targetResolvedElementId = ElementPath.resolveElementId(targetElementID)

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.dragElementByPath(
      sourcePath: sourceResolvedElementId,
      targetPath: targetResolvedElementId,
      appBundleId: appBundleId,
    )
    return [
      .text(
        "Successfully dragged from element \(sourceResolvedElementId) to element \(targetResolvedElementId)")
    ]
  }

  /// Handle scroll action
  private func handleScroll(_ params: [String: Value]) async throws -> [Tool.Content] {
    guard let elementID = params["id"]?.stringValue else {
      throw createInteractionError(
        message: "Scroll action requires id",
        context: [
          "toolName": name,
          "action": "scroll",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }
    
    // Resolve the element ID (handles both opaque IDs and raw paths)
    let resolvedElementId = ElementPath.resolveElementId(elementID)

    guard let directionString = params["direction"]?.stringValue,
      let direction = ScrollDirection(rawValue: directionString)
    else {
      throw createInteractionError(
        message: "Scroll action requires valid direction (up, down, left, right)",
        context: [
          "toolName": name,
          "action": "scroll",
          "id": resolvedElementId,
          "providedDirection": params["direction"]?.stringValue ?? "nil",
          "validDirections": "up, down, left, right",
        ],
      ).asMCPError
    }

    guard let amount = params["amount"]?.doubleValue, amount >= 0.0, amount <= 1.0 else {
      throw createInteractionError(
        message: "Scroll action requires amount between 0.0 and 1.0",
        context: [
          "toolName": name,
          "action": "scroll",
          "id": resolvedElementId,
          "direction": directionString,
          "providedAmount": params["amount"]?
            .doubleValue != nil ? "\(params["amount"]!.doubleValue!)" : "nil",
        ],
      ).asMCPError
    }

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.scrollElementByPath(
      path: resolvedElementId,
      direction: direction,
      amount: amount,
      appBundleId: appBundleId,
    )
    return [
      .text("Successfully scrolled element \(resolvedElementId) in direction \(direction.rawValue)")
    ]
  }
}
