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
  public let description = "Interact with UI elements on macOS - click, type, scroll and more"

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The UI interaction service
  private let interactionService: any UIInteractionServiceProtocol

  /// The accessibility service
  private let accessibilityService: any AccessibilityServiceProtocol

  /// The logger
  private let logger: Logger

  /// Create a new UI interaction tool
  /// - Parameters:
  ///   - interactionService: The UI interaction service to use
  ///   - accessibilityService: The accessibility service to use
  ///   - logger: Optional logger to use
  public init(
    interactionService: any UIInteractionServiceProtocol,
    accessibilityService: any AccessibilityServiceProtocol,
    logger: Logger? = nil
  ) {
    self.interactionService = interactionService
    self.accessibilityService = accessibilityService
    self.logger = logger ?? Logger(label: "mcp.tool.ui_interact")

    // Set tool annotations first
    annotations = .init(
      title: "UI Interaction",
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: true,
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Create the input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "action": .object([
          "type": .string("string"),
          "description": .string("The interaction action to perform"),
          "enum": .array([
            .string("click"),
            .string("double_click"),
            .string("right_click"),
            .string("drag"),
            .string("scroll"),
          ]),
        ]),
        "elementPath": .object([
          "type": .string("string"),
          "description": .string(
            "The path of the UI element to interact with (in macos://ui/ path format)"),
        ]),
        "appBundleId": .object([
          "type": .string("string"),
          "description": .string(
            "Optional bundle ID of the application containing the element (helps with finding elements in specific apps)"
          ),
        ]),
        "x": .object([
          "type": .string("number"),
          "description": .string(
            "X coordinate for positional actions (required for position-based clicking)"),
        ]),
        "y": .object([
          "type": .string("number"),
          "description": .string(
            "Y coordinate for positional actions (required for position-based clicking)"),
        ]),
        "targetElementPath": .object([
          "type": .string("string"),
          "description": .string(
            "Target element path for drag action (required for drag action, in macos://ui/ path format)"),
        ]),
        "direction": .object([
          "type": .string("string"),
          "description": .string("Scroll direction (required for scroll action)"),
          "enum": .array([
            .string("up"),
            .string("down"),
            .string("left"),
            .string("right"),
          ]),
        ]),
        "amount": .object([
          "type": .string("number"),
          "description": .string("Scroll amount from 0.0 to 1.0 (required for scroll action)"),
          "minimum": .double(0.0),
          "maximum": .double(1.0),
        ]),
      ]),
      "required": .array([.string("action")]),
      "additionalProperties": .bool(false),
    ])
  }

  /// Tool handler function
  public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
    // Create services on demand to ensure we're in the right context
    let handlerLogger = Logger(label: "mcp.tool.ui_interact")

    let accessibilityService = AccessibilityService(
      logger: Logger(label: "mcp.tool.ui_interact.accessibility"),
    )
    let interactionService = UIInteractionService(
      accessibilityService: accessibilityService,
      logger: Logger(label: "mcp.tool.ui_interact.interaction"),
    )
    let tool = UIInteractionTool(
      interactionService: interactionService,
      accessibilityService: accessibilityService,
      logger: handlerLogger,
    )

    // Extract and log the key parameters for debugging
    if let params {
      let action = params["action"]?.stringValue ?? "unknown"
      let elementPath = params["elementPath"]?.stringValue ?? "none"
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

  /// Handle click action
  private func handleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    // Element path click
    if let elementPath = params["elementPath"]?.stringValue {
      // Check if app bundle ID is provided
      let appBundleId = params["appBundleId"]?.stringValue

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
        try await interactionService.clickElementByPath(path: elementPath, appBundleId: appBundleId)

        let bundleIdInfo = appBundleId != nil ? " in app \(appBundleId!)" : ""
        return [.text("Successfully clicked element with path: \(elementPath)\(bundleIdInfo)")]
      } catch {
        let nsError = error as NSError
        logger.error(
          "Click operation failed",
          metadata: [
            "error": "\(error.localizedDescription)",
            "domain": "\(nsError.domain)",
            "code": "\(nsError.code)",
          ])
        throw error
      }
    }

    // Position click
    // Check for double first, then fall back to int for backward compatibility
    if let xDouble = params["x"]?.doubleValue, let yDouble = params["y"]?.doubleValue {
      let x = xDouble
      let y = yDouble

      do {
        try await interactionService.clickAtPosition(position: CGPoint(x: x, y: y))
        return [.text("Successfully clicked at position (\(x), \(y))")]
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
        try await interactionService.clickAtPosition(position: CGPoint(x: x, y: y))
        return [.text("Successfully clicked at position (\(x), \(y))")]
      } catch {
        logger.error(
          "Position click operation failed", metadata: ["error": "\(error.localizedDescription)"])
        throw error
      }
    }

    logger.error(
      "Missing required parameters",
      metadata: ["details": "Click action requires either elementPath or x,y coordinates"],
    )
    throw createInteractionError(
      message: "Click action requires either elementPath or x,y coordinates",
      context: [
        "toolName": name,
        "action": "click",
        "providedParams": "\(params.keys.joined(separator: ", "))",
      ],
    ).asMCPError
  }

  /// Handle double click action
  private func handleDoubleClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    guard let elementPath = params["elementPath"]?.stringValue else {
      throw createInteractionError(
        message: "Double click action requires elementPath",
        context: [
          "toolName": name,
          "action": "double_click",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.doubleClickElementByPath(
      path: elementPath, appBundleId: appBundleId)
    return [.text("Successfully double-clicked element with path: \(elementPath)")]
  }

  /// Handle right click action
  private func handleRightClick(_ params: [String: Value]) async throws -> [Tool.Content] {
    guard let elementPath = params["elementPath"]?.stringValue else {
      throw createInteractionError(
        message: "Right click action requires elementPath",
        context: [
          "toolName": name,
          "action": "right_click",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    // Check if app bundle ID is provided
    let appBundleId = params["appBundleId"]?.stringValue

    try await interactionService.rightClickElementByPath(
      path: elementPath, appBundleId: appBundleId)
    return [.text("Successfully right-clicked element with path: \(elementPath)")]
  }

  /// Handle drag action
  private func handleDrag(_ params: [String: Value]) async throws -> [Tool.Content] {
    guard let sourceElementPath = params["elementPath"]?.stringValue else {
      throw createInteractionError(
        message: "Drag action requires elementPath (source)",
        context: [
          "toolName": name,
          "action": "drag",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    guard let targetElementPath = params["targetElementPath"]?.stringValue else {
      throw createInteractionError(
        message: "Drag action requires targetElementPath",
        context: [
          "toolName": name,
          "action": "drag",
          "sourceElementPath": sourceElementPath,
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

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
    guard let elementPath = params["elementPath"]?.stringValue else {
      throw createInteractionError(
        message: "Scroll action requires elementPath",
        context: [
          "toolName": name,
          "action": "scroll",
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    guard let directionString = params["direction"]?.stringValue,
      let direction = ScrollDirection(rawValue: directionString)
    else {
      throw createInteractionError(
        message: "Scroll action requires valid direction (up, down, left, right)",
        context: [
          "toolName": name,
          "action": "scroll",
          "elementPath": elementPath,
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
          "elementPath": elementPath,
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
