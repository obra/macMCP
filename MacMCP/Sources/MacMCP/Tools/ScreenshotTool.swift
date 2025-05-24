// ABOUTME: ScreenshotTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// A tool for capturing screenshots on macOS
public struct ScreenshotTool {
  /// The name of the tool
  public let name = ToolNames.screenshot

  /// Description of the tool
  public let description = """
Capture screenshots of macOS screen, windows, or UI elements for visual inspection and analysis.

IMPORTANT: For element screenshots, use InterfaceExplorerTool first to discover element IDs.

Region types and requirements:
- full: Capture entire screen (no additional parameters)
- area: Capture specific coordinates (requires x, y, width, height)
- window: Capture application window (requires bundleId)
- element: Capture UI element (requires id from InterfaceExplorerTool)

Common use cases:
- Debugging UI layout issues
- Documenting current application state
- Capturing specific UI elements for analysis
- Visual verification during testing

Coordinate system: Screen coordinates start at (0,0) in top-left corner.
"""

  /// Input schema for the tool
  public var inputSchema: Value

  /// Tool annotations
  public var annotations: Tool.Annotations

  /// The screenshot service to use
  private let screenshotService: any ScreenshotServiceProtocol

  /// The logger
  private let logger: Logger

  /// Create a new screenshot tool
  /// - Parameters:
  ///   - screenshotService: The screenshot service to use (optional, created on demand if nil)
  ///   - logger: Optional logger to use
  public init(
    screenshotService: (any ScreenshotServiceProtocol)? = nil,
    logger: Logger? = nil
  ) {
    // If no service provided, it will be created lazily in the handler
    self.screenshotService = screenshotService ?? MockScreenshotService()
    self.logger = logger ?? Logger(label: "mcp.tool.screenshot")

    // Set tool annotations first
    // Tool description:
    // Tool for capturing visual information about UI state. Useful for:
    // 1. Examining application UI details
    // 2. Capturing specific UI elements for analysis
    // 3. Documenting current UI state
    // 4. Visual debugging of layout issues
    //
    // IMPORTANT: For element screenshots, first use InterfaceExplorerTool to discover element IDs.
    //
    // Best practices:
    // - For window screenshots, use the window region with app's bundle ID (e.g., com.apple.calculator)
    // - For UI elements, first use InterfaceExplorerTool to get the element ID, then capture with element region
    // - Full screen screenshots are useful for overall context, but may be large

    annotations = .init(
      title: "macOS Screenshot Capture",
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true
    )

    // Set schema to empty initially, then assign the real value
    inputSchema = .object([:])
    // Now set the real schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "region": .object([
          "type": .string("string"),
          "description": .string("Screenshot region type: 'full' for entire screen, 'area' for coordinates, 'window' for app window, 'element' for UI element"),
          "enum": .array([
            .string("full"),
            .string("area"),
            .string("window"),
            .string("element"),
          ]),
        ]),
        "x": .object([
          "type": .string("number"),
          "description": .string("X coordinate in screen pixels (required for 'area' region, top-left origin)"),
        ]),
        "y": .object([
          "type": .string("number"),
          "description": .string("Y coordinate in screen pixels (required for 'area' region, top-left origin)"),
        ]),
        "width": .object([
          "type": .string("number"),
          "description": .string("Width in pixels (required for 'area' region)"),
        ]),
        "height": .object([
          "type": .string("number"),
          "description": .string("Height in pixels (required for 'area' region)"),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string("Application bundle identifier (required for 'window' region) - e.g., 'com.apple.calculator'"),
        ]),
        "id": .object([
          "type": .string("string"),
          "description": .string("UI element ID from InterfaceExplorerTool (required for 'element' region)"),
        ]),
      ]),
      "required": .array([.string("region")]),
      "additionalProperties": .bool(false),
      "examples": .array([
        .object([
          "region": .string("full"),
        ]),
        .object([
          "region": .string("area"),
          "x": .int(100),
          "y": .int(200),
          "width": .int(400),
          "height": .int(300),
        ]),
        .object([
          "region": .string("window"),
          "bundleId": .string("com.apple.calculator"),
        ]),
        .object([
          "region": .string("element"),
          "id": .string("element-uuid-example"),
        ]),
      ]),
    ])
  }

  /// Tool handler function
  public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
    // Create services - we do this in the handler to avoid initialization issues
    // and to make sure we're running in the right context
    let accessibilityService = AccessibilityService(
      logger: Logger(label: "mcp.tool.screenshot.accessibility"),
    )
    let screenshotService = ScreenshotService(
      accessibilityService: accessibilityService,
      logger: Logger(label: "mcp.tool.screenshot"),
    )
    let tool = ScreenshotTool(screenshotService: screenshotService)

    return try await tool.processRequest(params)
  }

  /// Process a screenshot request
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  ///
  /// Screenshot workflow for element screenshots:
  /// 1. User discovers UI elements with InterfaceExplorerTool
  /// 2. User gets element IDs from the explorer results
  /// 3. User uses ScreenshotTool with region=element and id=<element ID>
  /// 4. Service finds the element (with several fallback approaches for reliability)
  /// 5. Service captures the element with padding to ensure the full element is visible
  /// 6. Result is returned as base64-encoded PNG with metadata
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else {
      throw createScreenshotError(
        message: "Parameters are required",
        context: ["toolName": name],
      ).asMCPError
    }

    // Get the region
    guard let regionValue = params["region"]?.stringValue else {
      throw createScreenshotError(
        message: "Region is required",
        context: [
          "toolName": name,
          "providedParams": "\(params.keys.joined(separator: ", "))",
        ],
      ).asMCPError
    }

    let result: ScreenshotResult

    switch regionValue {
    case "full":
      // Capture full screen
      result = try await screenshotService.captureFullScreen()

    case "area":
      // Extract required coordinates
      guard
        let x = params["x"]?.intValue,
        let y = params["y"]?.intValue,
        let width = params["width"]?.intValue,
        let height = params["height"]?.intValue
      else {
        throw createScreenshotError(
          message: "Area screenshots require x, y, width, and height parameters",
          context: [
            "toolName": name,
            "region": regionValue,
            "providedParams": "\(params.keys.joined(separator: ", "))",
            "x": params["x"]?.intValue != nil ? "\(params["x"]!.intValue!)" : "missing",
            "y": params["y"]?.intValue != nil ? "\(params["y"]!.intValue!)" : "missing",
            "width": params["width"]?.intValue != nil ? "\(params["width"]!.intValue!)" : "missing",
            "height": params["height"]?.intValue != nil
              ? "\(params["height"]!.intValue!)" : "missing",
          ],
        ).asMCPError
      }

      result = try await screenshotService.captureArea(
        x: x,
        y: y,
        width: width,
        height: height,
      )

    case "window":
      // Extract required bundle ID
      guard let bundleId = params["bundleId"]?.stringValue else {
        throw createScreenshotError(
          message: "Window screenshots require a bundleId parameter",
          context: [
            "toolName": name,
            "region": regionValue,
            "providedParams": "\(params.keys.joined(separator: ", "))",
          ],
        ).asMCPError
      }

      result = try await screenshotService.captureWindow(
        bundleId: bundleId,
      )

    case "element":
      // Extract required element path
      guard let elementPath = params["id"]?.stringValue else {
        throw createScreenshotError(
          message: "Element screenshots require an id parameter",
          context: [
            "toolName": name,
            "region": regionValue,
            "providedParams": "\(params.keys.joined(separator: ", "))",
          ],
        ).asMCPError
      }

      result = try await screenshotService.captureElementByPath(
        elementPath: elementPath,
      )

    default:
      throw createScreenshotError(
        message: "Invalid region: \(regionValue). Must be one of: full, area, window, element",
        context: [
          "toolName": name,
          "providedRegion": regionValue,
          "validRegions": "full, area, window, element",
        ],
      ).asMCPError
    }

    // Convert to base64 string
    let base64Data = result.data.base64EncodedString()

    // Create a metadata object with dimensions
    let metadata: [String: String] = [
      "width": "\(result.width)",
      "height": "\(result.height)",
      "scale": String(format: "%.2f", result.scale),
      "region": regionValue,
    ]

    // Return as image content
    return [.image(data: base64Data, mimeType: "image/png", metadata: metadata)]
  }
}

/// Temporary stub for initialization
private class MockScreenshotService: ScreenshotServiceProtocol {
  func captureFullScreen() async throws -> ScreenshotResult {
    fatalError("This is a stub that should never be called")
  }

  func captureArea(x _: Int, y _: Int, width _: Int, height _: Int) async throws -> ScreenshotResult
  {
    fatalError("This is a stub that should never be called")
  }

  func captureWindow(bundleId _: String) async throws -> ScreenshotResult {
    fatalError("This is a stub that should never be called")
  }

  func captureElementByPath(elementPath _: String) async throws -> ScreenshotResult {
    fatalError("This is a stub that should never be called")
  }
}
