// ABOUTME: This file defines the screenshot tool for capturing screen images.
// ABOUTME: It allows LLMs to capture and analyze UI state visually.

import Foundation
import MCP
import Logging

/// A tool for capturing screenshots on macOS
public struct ScreenshotTool {
    /// The name of the tool
    public let name = ToolNames.screenshot
    
    /// Description of the tool
    public let description = "Capture screenshot of macOS screen, window, or UI element for visual inspection and analysis"
    
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
        self.annotations = .init(
            title: "Screenshot",
            description: """
            Tool for capturing visual information about UI state. Useful for:
            1. Examining application UI details
            2. Capturing specific UI elements for analysis
            3. Documenting current UI state
            4. Visual debugging of layout issues

            IMPORTANT: For element screenshots, first use InterfaceExplorerTool to discover element IDs.
            """,
            readOnlyHint: true,
            openWorldHint: true,
            usageHint: """
            Best practices:
            - For window screenshots, use the window region with app's bundle ID (e.g., com.apple.calculator)
            - For UI elements, first use InterfaceExplorerTool to get the element ID, then capture with element region
            - Full screen screenshots are useful for overall context, but may be large
            """
        )
        
        // Set schema to empty initially, then assign the real value
        self.inputSchema = .object([:])
        // Now set the real schema
        self.inputSchema = createInputSchema()
    }
    
    /// Create the input schema for the tool
    private func createInputSchema() -> Value {
        return .object([
            "type": .string("object"),
            "properties": .object([
                "region": .object([
                    "type": .string("string"),
                    "description": .string("The region to capture: full (entire screen), area (specific coordinates), window (app window by bundleId), element (UI element by elementId from InterfaceExplorerTool)"),
                    "enum": .array([
                        .string("full"),
                        .string("area"),
                        .string("window"),
                        .string("element")
                    ])
                ]),
                "x": .object([
                    "type": .string("number"),
                    "description": .string("X coordinate for area screenshots (required when region is 'area')")
                ]),
                "y": .object([
                    "type": .string("number"),
                    "description": .string("Y coordinate for area screenshots (required when region is 'area')")
                ]),
                "width": .object([
                    "type": .string("number"),
                    "description": .string("Width for area screenshots (required when region is 'area')")
                ]),
                "height": .object([
                    "type": .string("number"),
                    "description": .string("Height for area screenshots (required when region is 'area')")
                ]),
                "bundleId": .object([
                    "type": .string("string"),
                    "description": .string("The bundle identifier of the application window to capture (required when region is 'window') - e.g., 'com.apple.calculator' for Calculator")
                ]),
                "elementId": .object([
                    "type": .string("string"),
                    "description": .string("The ID of the UI element to capture (required when region is 'element') - MUST be obtained from InterfaceExplorerTool first")
                ])
            ]),
            "required": .array([.string("region")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Tool handler function
    public let handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] = { params in
        // Create services - we do this in the handler to avoid initialization issues
        // and to make sure we're running in the right context
        let accessibilityService = AccessibilityService(
            logger: Logger(label: "mcp.tool.screenshot.accessibility")
        )
        let screenshotService = ScreenshotService(
            accessibilityService: accessibilityService,
            logger: Logger(label: "mcp.tool.screenshot")
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
    /// 3. User uses ScreenshotTool with region=element and elementId=<discovered ID>
    /// 4. Service finds the element (with several fallback approaches for reliability)
    /// 5. Service captures the element with padding to ensure the full element is visible
    /// 6. Result is returned as base64-encoded PNG with metadata
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw createScreenshotError(
                message: "Parameters are required",
                context: ["toolName": name]
            ).asMCPError
        }
        
        // Get the region
        guard let regionValue = params["region"]?.stringValue else {
            throw createScreenshotError(
                message: "Region is required",
                context: [
                    "toolName": name,
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
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
                        "height": params["height"]?.intValue != nil ? "\(params["height"]!.intValue!)" : "missing"
                    ]
                ).asMCPError
            }
            
            result = try await screenshotService.captureArea(
                x: x,
                y: y,
                width: width,
                height: height
            )
            
        case "window":
            // Extract required bundle ID
            guard let bundleId = params["bundleId"]?.stringValue else {
                throw createScreenshotError(
                    message: "Window screenshots require a bundleId parameter",
                    context: [
                        "toolName": name,
                        "region": regionValue,
                        "providedParams": "\(params.keys.joined(separator: ", "))"
                    ]
                ).asMCPError
            }
            
            result = try await screenshotService.captureWindow(
                bundleIdentifier: bundleId
            )
            
        case "element":
            // Extract required element ID
            guard let elementId = params["elementId"]?.stringValue else {
                throw createScreenshotError(
                    message: "Element screenshots require an elementId parameter",
                    context: [
                        "toolName": name,
                        "region": regionValue,
                        "providedParams": "\(params.keys.joined(separator: ", "))"
                    ]
                ).asMCPError
            }
            
            result = try await screenshotService.captureElement(
                elementId: elementId
            )
            
        default:
            throw createScreenshotError(
                message: "Invalid region: \(regionValue). Must be one of: full, area, window, element",
                context: [
                    "toolName": name,
                    "providedRegion": regionValue,
                    "validRegions": "full, area, window, element"
                ]
            ).asMCPError
        }
        
        // Convert to base64 string
        let base64Data = result.data.base64EncodedString()
        
        // Create a metadata object with dimensions
        let metadata: [String: String] = [
            "width": "\(result.width)",
            "height": "\(result.height)",
            "scale": String(format: "%.2f", result.scale),
            "region": regionValue
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
    
    func captureArea(x: Int, y: Int, width: Int, height: Int) async throws -> ScreenshotResult {
        fatalError("This is a stub that should never be called")
    }
    
    func captureWindow(bundleIdentifier: String) async throws -> ScreenshotResult {
        fatalError("This is a stub that should never be called")
    }
    
    func captureElement(elementId: String) async throws -> ScreenshotResult {
        fatalError("This is a stub that should never be called")
    }
}