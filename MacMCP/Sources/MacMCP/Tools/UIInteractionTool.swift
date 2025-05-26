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
1. Explore UI: InterfaceExplorerTool → find id
2. Click element: UIInteractionTool with id
3. Drag operations: Source id + target targetId  
4. Scroll content: Container id + direction + amount
5. Position clicks: Use x, y coordinates when element detection fails

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
          "description": .string("Element ID from InterfaceExplorerTool - preferred method for reliability"),
        ]),
        "appBundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle ID to help locate elements (e.g., 'com.apple.calculator')"),
        ]),
        "x": .object([
          "type": .string("number"),
          "description": .string("X coordinate in screen pixels for position-based actions (0 = left edge)"),
        ]),
        "y": .object([
          "type": .string("number"),
          "description": .string("Y coordinate in screen pixels for position-based actions (0 = top edge)"),
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
          "description": .string("Scroll distance from 0.0 (minimal) to 1.0 (full) - required for 'scroll' action"),
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
      let elementPath = params["id"]?.stringValue ?? "none"
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


  /// Decode element ID - handles both opaque IDs and raw paths
  private func decodeElementID(_ elementID: String) -> String {
    // Try to decode as opaque ID first, fall back to treating as raw path
    do {
      return try OpaqueIDEncoder.decode(elementID)
    } catch {
      // Not an opaque ID or decoding failed, treat as raw path
      return elementID
    }
  }
  
  /// Extract bundle ID from element path or parameters
  private func extractBundleID(from elementPath: String, params: [String: Value]) -> String? {
    // First check if bundleId is explicitly provided in params
    if let appBundleId = params["appBundleId"]?.stringValue {
      return appBundleId
    }
    
    // Try to extract from element path
    do {
      let path = try ElementPath.parse(elementPath)
      if !path.segments.isEmpty {
        let firstSegment = path.segments[0]
        if firstSegment.role == "AXApplication" {
          return firstSegment.attributes["bundleId"] ?? firstSegment.attributes["@bundleId"]
        }
      }
    } catch {
      logger.debug("Could not parse element path to extract bundleId: \(error)")
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
  
  /// Handle click action
  private func handleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)
    // Element path click
    if let elementID = params["id"]?.stringValue {
      // Decode the element ID (handles both opaque IDs and raw paths)
      let elementPath = decodeElementID(elementID)
      // Extract bundle ID for focus management and change detection
      let appBundleId = extractBundleID(from: elementPath, params: params)
      
      // Ensure application is focused before interaction
      if let bundleId = appBundleId {
        try await ensureApplicationFocus(bundleId: bundleId)
      }

      // Before clicking, try to look up the element to verify it exists
      do {
        // Try to parse the path first
        let path = try ElementPath.parse(elementPath)

        // Make sure the path is valid
        if path.segments.isEmpty {
          logger.warning("Invalid element path, no segments found")
        }

        // Check if the path already specifies an application - if so, don't override with appBundleId
        let firstSegment = path.segments[0]
        let pathSpecifiesApp =
          firstSegment.role == "AXApplication"
          && (firstSegment.attributes["bundleId"] != nil
            || firstSegment.attributes["AXTitle"] != nil)

        // If path doesn't specify an app but appBundleId is provided, log a message
        if !pathSpecifiesApp, appBundleId != nil {
          logger.info(
            "Using provided appBundleId alongside element path",
            metadata: ["appBundleId": "\(appBundleId!)"],
          )
        }

        // Attempt to resolve the path to verify it exists (only if path is not empty)
        // This is just for validation - actual resolution happens in interactionService
        if !elementPath.isEmpty {
          do {
            _ = try await path.resolve(using: accessibilityService)
            logger.debug("Element path verified and resolved successfully")
          } catch {
            logger.warning(
              "Element path did not resolve, but will still attempt click operation",
              metadata: ["error": "\(error.localizedDescription)"],
            )
          }
        }
      } catch {
        logger.warning(
          "Error parsing or validating element path, but will still attempt click operation",
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
          try await interactionService.clickElementByPath(path: elementPath, appBundleId: appBundleId)
          let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
          return "Successfully clicked element with path: \(elementPath)\(bundleIdInfo)"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        let nsError = error as NSError
        logger.error(
          "Click operation failed",
          metadata: [
            "error": "\(error.localizedDescription)",
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)",
            "elementPath": "\(elementPath)",
          ])
        
        // Create a more informative error that includes the actual path
        let enhancedError = createInteractionError(
          message: "Failed to click element at path: \(elementPath). \(error.localizedDescription)",
          context: [
            "toolName": name,
            "action": "click",
            "elementID": elementID,
            "elementPath": elementPath,
            "originalError": error.localizedDescription,
          ]
        )
        throw enhancedError.asMCPError
      }
    }

    // Position click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      let x = xDouble
      let y = yDouble

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.clickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      // Fallback to integers if doubles are not provided
      let x = Double(xInt)
      let y = Double(yInt)

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.clickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
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
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)
    // Element path double click
    if let elementID = params["id"]?.stringValue {
      // Decode the element ID (handles both opaque IDs and raw paths)
      let elementPath = decodeElementID(elementID)
      // Extract bundle ID for focus management and change detection
      let appBundleId = extractBundleID(from: elementPath, params: params)
      
      // Ensure application is focused before interaction
      if let bundleId = appBundleId {
        try await ensureApplicationFocus(bundleId: bundleId)
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
          try await interactionService.doubleClickElementByPath(path: elementPath, appBundleId: appBundleId)
          let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
          return "Successfully double-clicked element with path: \(elementPath)\(bundleIdInfo)"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        let nsError = error as NSError
        logger.error(
          "Double click operation failed",
          metadata: [
            "error": "\(error.localizedDescription)",
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)",
            "elementPath": "\(elementPath)",
          ])
        
        // Create a more informative error that includes the actual path
        let enhancedError = createInteractionError(
          message: "Failed to double-click element at path: \(elementPath). \(error.localizedDescription)",
          context: [
            "toolName": name,
            "action": "double_click",
            "elementID": elementID,
            "elementPath": elementPath,
            "originalError": error.localizedDescription,
          ]
        )
        throw enhancedError.asMCPError
      }
    }

    // Position double click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      let x = xDouble
      let y = yDouble

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.doubleClickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully double-clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position double click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      // Fallback to integers if doubles are not provided
      let x = Double(xInt)
      let y = Double(yInt)

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.doubleClickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully double-clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position double click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
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
    let (detectChanges, delay) = ChangeDetectionHelper.extractChangeDetectionParams(params)
    // Element path right click
    if let elementID = params["id"]?.stringValue {
      // Decode the element ID (handles both opaque IDs and raw paths)
      let elementPath = decodeElementID(elementID)
      // Extract bundle ID for focus management and change detection
      let appBundleId = extractBundleID(from: elementPath, params: params)
      
      // Ensure application is focused before interaction
      if let bundleId = appBundleId {
        try await ensureApplicationFocus(bundleId: bundleId)
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
          try await interactionService.rightClickElementByPath(path: elementPath, appBundleId: appBundleId)
          let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
          return "Successfully right-clicked element with path: \(elementPath)\(bundleIdInfo)"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        let nsError = error as NSError
        logger.error(
          "Right click operation failed",
          metadata: [
            "error": "\(error.localizedDescription)",
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)",
            "elementPath": "\(elementPath)",
          ])
        
        // Create a more informative error that includes the actual path
        let enhancedError = createInteractionError(
          message: "Failed to right-click element at path: \(elementPath). \(error.localizedDescription)",
          context: [
            "toolName": name,
            "action": "right_click",
            "elementID": elementID,
            "elementPath": elementPath,
            "originalError": error.localizedDescription,
          ]
        )
        throw enhancedError.asMCPError
      }
    }

    // Position right click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      let x = xDouble
      let y = yDouble

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.rightClickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully right-clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position right click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
    } else if let xInt = params["x"]?.intValue, let yInt = params["y"]?.intValue {
      // Fallback to integers if doubles are not provided
      let x = Double(xInt)
      let y = Double(yInt)

      do {
        let result = try await interactionWrapper.performWithChangeDetection(
          detectChanges: detectChanges,
          delay: delay
        ) {
          try await interactionService.rightClickAtPosition(position: CGPoint(x: x, y: y))
          return "Successfully right-clicked at position (\(x), \(y))"
        }

        return ChangeDetectionHelper.formatResponse(message: result.result, uiChanges: result.uiChanges, logger: logger)
      } catch {
        logger.error(
          "Position right click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
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
    
    // Decode both element IDs (handles both opaque IDs and raw paths)
    let sourceElementPath = decodeElementID(sourceElementID)
    let targetElementPath = decodeElementID(targetElementID)

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.dragElementByPath(
      sourcePath: sourceElementPath,
      targetPath: targetElementPath,
      appBundleId: appBundleId,
    )
    return [
      .text(
        "Successfully dragged from element \(sourceElementPath) to element \(targetElementPath)")
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
    
    // Decode the element ID (handles both opaque IDs and raw paths)
    let elementPath = decodeElementID(elementID)

    guard let directionString = params["direction"]?.stringValue,
      let direction = ScrollDirection(rawValue: directionString)
    else {
      throw createInteractionError(
        message: "Scroll action requires valid direction (up, down, left, right)",
        context: [
          "toolName": name,
          "action": "scroll",
          "id": elementPath,
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
          "id": elementPath,
          "direction": directionString,
          "providedAmount": params["amount"]?
            .doubleValue != nil ? "\(params["amount"]!.doubleValue!)" : "nil",
        ],
      ).asMCPError
    }

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.scrollElementByPath(
      path: elementPath,
      direction: direction,
      amount: amount,
      appBundleId: appBundleId,
    )
    return [
      .text("Successfully scrolled element \(elementPath) in direction \(direction.rawValue)")
    ]
  }
}
