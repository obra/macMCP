// ABOUTME: ClipboardManagementTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP

/// Tool for managing clipboard operations in macOS
public struct ClipboardManagementTool: @unchecked Sendable {
  /// The clipboard service for actual clipboard operations
  private let clipboardService: ClipboardServiceProtocol

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// Initializes the clipboard management tool
  /// - Parameter clipboardService: The service for clipboard operations
  public init(clipboardService: ClipboardServiceProtocol) {
    self.clipboardService = clipboardService

    // Set tool annotations
    annotations = .init(
      title: "macOS Clipboard Management",
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true
    )
  }

  /// The name of the tool
  public var name: String { ToolNames.clipboardManagement }

  /// Description of what the tool does
  public var description: String {
    """
    Manage macOS clipboard content including text, images, and files with comprehensive operations.

    IMPORTANT: Images must be base64-encoded data. Files use absolute file paths.

    Available actions:
    - getInfo: Get information about clipboard content types and status
    - getText: Retrieve text content from clipboard
    - setText: Set text content in clipboard
    - getImage: Get image from clipboard as base64-encoded data
    - setImage: Set image in clipboard from base64-encoded data
    - getFiles: Get file paths from clipboard
    - setFiles: Set file paths in clipboard
    - clear: Clear all clipboard content

    Content types supported:
    - Text: Plain text strings
    - Images: Base64-encoded PNG/JPEG data
    - Files: Array of absolute file paths

    Common workflows:
    1. Check content: getInfo → determine available types
    2. Copy text: setText with text content
    3. Copy image: setImage with base64 imageData
    4. Copy files: setFiles with filePaths array
    5. Paste content: getText/getImage/getFiles to retrieve

    Data formats: Images as base64 strings, files as absolute paths.
    """
  }

  /// The supported actions as an enum
  public enum Action: String, CaseIterable {
    /// Get information about available clipboard content
    case getInfo

    /// Get text from clipboard
    case getText

    /// Set text in clipboard
    case setText

    /// Get image from clipboard
    case getImage

    /// Set image in clipboard
    case setImage

    /// Get files from clipboard
    case getFiles

    /// Set files in clipboard
    case setFiles

    /// Clear clipboard content
    case clear
  }

  /// The schema for the tool input
  public var inputSchema: Value {
    Value.object([
      "type": .string("object"), "required": .array([.string("action")]),
      "properties": .object([
        "action": .object([
          "type": .string("string"), "enum": .array(Action.allCases.map { .string($0.rawValue) }),
          "description": .string(
            "Clipboard operation: get/set text, images, files, or get info/clear"),
        ]),
        "text": .object([
          "type": .string("string"),
          "description": .string("Text content to set in clipboard (required for setText action)"),
        ]),
        "imageData": .object([
          "type": .string("string"),
          "description": .string(
            "Base64-encoded image data (PNG/JPEG) to set in clipboard (required for setImage action)"
          ),
        ]),
        "filePaths": .object([
          "type": .string("array"), "items": .object(["type": .string("string")]),
          "description": .string(
            "Array of absolute file paths to set in clipboard (required for setFiles action)"
          ),
        ]),
      ]), "additionalProperties": .bool(false),
      "examples": .array([
        .object(["action": .string("getInfo")]),
        .object(["action": .string("setText"), "text": .string("Hello, world!")]),
        .object(["action": .string("getText")]),
        .object([
          "action": .string("setImage"),
          "imageData": .string(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
          ),
        ]),
        .object([
          "action": .string("setFiles"),
          "filePaths": .array([
            .string("/Users/username/Documents/file.txt"),
            .string("/Users/username/Pictures/image.png"),
          ]),
        ]), .object(["action": .string("clear")]),
      ]),
    ])
  }

  /// Handles the tool execution
  /// - Parameters:
  ///   - input: The input parameters as JSON
  ///   - env: The environment for execution
  /// - Returns: JSON output of the operation result
  /// - Throws: Error if execution fails
  public func execute(with input: [String: Any], env _: [String: Any]) async throws -> [String: Any]
  {
    guard let actionString = input["action"] as? String, let action = Action(rawValue: actionString)
    else {
      throw MCPError.invalidParams("Invalid or missing 'action' parameter")
    }

    switch action {
    case .getInfo: return try await handleGetInfo()
    case .getText: return try await handleGetText()
    case .setText: return try await handleSetText(input)
    case .getImage: return try await handleGetImage()
    case .setImage: return try await handleSetImage(input)
    case .getFiles: return try await handleGetFiles()
    case .setFiles: return try await handleSetFiles(input)
    case .clear: return try await handleClear()
    }
  }

  // MARK: - Handler Methods

  /// Handles getting clipboard information
  /// - Returns: JSON with the clipboard content info
  /// - Throws: Error if operation fails
  private func handleGetInfo() async throws -> [String: Any] {
    // Get information about clipboard contents from the service
    let info = try await clipboardService.getClipboardInfo()
    // Return a dictionary with the clipboard information
    return ["availableTypes": info.availableTypes.map(\.rawValue), "isEmpty": info.isEmpty]
  }

  /// Handles getting text from clipboard
  /// - Returns: JSON with the text content
  /// - Throws: Error if operation fails
  private func handleGetText() async throws -> [String: Any] {
    let text = try await clipboardService.getClipboardText()
    return ["text": text]
  }

  /// Handles setting text to clipboard
  /// - Parameter input: The input parameters
  /// - Returns: JSON confirming the operation
  /// - Throws: Error if operation fails
  private func handleSetText(_ input: [String: Any]) async throws -> [String: Any] {
    guard let text = input["text"] as? String else {
      throw MCPError.invalidParams("Missing required 'text' parameter for setText action")
    }

    try await clipboardService.setClipboardText(text)
    return ["success": true]
  }

  /// Handles getting image from clipboard
  /// - Returns: JSON with the base64 encoded image
  /// - Throws: Error if operation fails
  private func handleGetImage() async throws -> [String: Any] {
    let base64Image = try await clipboardService.getClipboardImage()
    return ["imageData": base64Image]
  }

  /// Handles setting image to clipboard
  /// - Parameter input: The input parameters
  /// - Returns: JSON confirming the operation
  /// - Throws: Error if operation fails
  private func handleSetImage(_ input: [String: Any]) async throws -> [String: Any] {
    guard let imageData = input["imageData"] as? String else {
      throw MCPError.invalidParams("Missing required 'imageData' parameter for setImage action")
    }

    try await clipboardService.setClipboardImage(imageData)
    return ["success": true]
  }

  /// Handles getting files from clipboard
  /// - Returns: JSON with the file paths
  /// - Throws: Error if operation fails
  private func handleGetFiles() async throws -> [String: Any] {
    let files = try await clipboardService.getClipboardFiles()
    return ["filePaths": files]
  }

  /// Handles setting files to clipboard
  /// - Parameter input: The input parameters
  /// - Returns: JSON confirming the operation
  /// - Throws: Error if operation fails
  private func handleSetFiles(_ input: [String: Any]) async throws -> [String: Any] {
    guard let filePaths = input["filePaths"] as? [String] else {
      throw MCPError.invalidParams("Missing required 'filePaths' parameter for setFiles action")
    }

    if filePaths.isEmpty {
      throw MCPError.invalidParams("The 'filePaths' array cannot be empty for setFiles action")
    }

    try await clipboardService.setClipboardFiles(filePaths)
    return ["success": true]
  }

  /// Handles clearing the clipboard
  /// - Returns: JSON confirming the operation
  /// - Throws: Error if operation fails
  private func handleClear() async throws -> [String: Any] {
    try await clipboardService.clearClipboard()
    return ["success": true]
  }

  /// The MCP handler function for tool invocation
  /// - Parameter params: The parameters from MCP
  /// - Returns: The content to return to the MCP client
  /// - Throws: Errors if operation fails
  public func handler(params: [String: Value]?) async throws -> [Tool.Content] {
    do {
      // Convert MCP Value types to native Swift types
      var processedParams: [String: Any] = [:]

      if let params {
        for (key, value) in params {
          switch value {
          case .string(let stringValue): processedParams[key] = stringValue
          case .bool(let boolValue): processedParams[key] = boolValue
          case .int(let intValue): processedParams[key] = intValue
          case .double(let doubleValue): processedParams[key] = doubleValue
          case .array(let arrayValue):
            // Handle arrays of strings
            let stringArray = arrayValue.compactMap { value -> String? in
              if case .string(let str) = value { return str }
              return nil
            }
            if stringArray.count == arrayValue.count { processedParams[key] = stringArray }
          default: break
          }
        }
      }

      // Execute the tool
      let result = try await execute(with: processedParams, env: [:])

      // Convert result to text for now
      let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted])
      let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

      return [Tool.Content.text(jsonString)]
    } catch {
      // Convert any error to MCP error
      throw error.asMCPError
    }
  }
}
