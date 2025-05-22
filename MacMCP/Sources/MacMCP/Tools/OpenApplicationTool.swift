// ABOUTME: OpenApplicationTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Tool for opening and managing macOS applications
public struct OpenApplicationTool: Sendable {
  /// The name of the tool
  public let name = ToolNames.openApplication

  /// Description of what the tool does
  public let description = "Open a macOS application by name or bundle identifier"

  /// The application service
  private let applicationService: ApplicationServiceProtocol

  /// Logger for the tool
  private let logger: Logger

  /// Initialize with required services
  /// - Parameters:
  ///   - applicationService: The service to use for application interactions
  ///   - logger: The logger to use
  public init(applicationService: ApplicationServiceProtocol, logger: Logger) {
    self.applicationService = applicationService
    self.logger = logger
  }

  /// The JSON schema for the tool's input parameters
  public var inputSchema: Value {
    // We need to create a JSON Schema structure
    // This is a common pattern in the MCP SDK
    let schema: [String: Value] = [
      "type": .string("object"),
      "properties": .object([
        "bundleId": .object([
          "type": .string("string"),
          "description": .string(
            "The bundle identifier of the application to open (e.g., 'com.apple.Safari')"),
        ]),
        "applicationName": .object([
          "type": .string("string"),
          "description": .string("The name of the application to open (e.g., 'Safari')"),
        ]),
        "arguments": .object([
          "type": .string("array"),
          "description": .string(
            "Optional array of command-line arguments to pass to the application"),
          "items": .object([
            "type": .string("string")
          ]),
        ]),
        "hideOthers": .object([
          "type": .string("boolean"),
          "description": .string("Whether to hide other applications when opening this one"),
        ]),
      ]),
    ]

    return .object(schema)
  }

  /// Annotations for the tool
  public var annotations: Tool.Annotations {
    .init(
      title: "Open Application",
      readOnlyHint: false,
    )
  }

  /// Helper method to convert Value dictionary to JSON-serializable dictionary
  private func valueToJsonDict(_ valueDict: [String: Value]) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in valueDict {
      result[key] = value.asAnyDictionary()
    }
    return result
  }

  /// Handler for tool calls
  public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [applicationService, logger] params in
      guard let params else {
        return [.text("Please provide either a bundle identifier or application name")]
      }

      // Extract parameters
      let bundleId: String? =
        if case .string(let value) = params["bundleId"] {
          value
        } else {
          nil
        }

      let applicationName: String? =
        if case .string(let value) = params["applicationName"] {
          value
        } else {
          nil
        }

      let arguments: [String]? =
        if case .array(let values) = params["arguments"] {
          values.compactMap {
            if case .string(let value) = $0 {
              return value
            }
            return nil
          }
        } else {
          nil
        }

      let hideOthers: Bool? =
        if case .bool(let value) = params["hideOthers"] {
          value
        } else {
          nil
        }

      // Validate that at least one identifier is provided
      guard bundleId != nil || applicationName != nil else {
        return [.text("Please provide either a bundle identifier or application name")]
      }

      do {
        var success = false
        var resultInfo: [String: Value] = [:]

        // Try to open by bundle identifier if provided
        if let bundleId {
          success = try await applicationService.openApplication(
            bundleId: bundleId,
            arguments: arguments,
            hideOthers: hideOthers,
          )
          resultInfo["bundleId"] = .string(bundleId)
        }
        // Otherwise, try to open by application name
        else if let applicationName {
          success = try await applicationService.openApplication(
            name: applicationName,
            arguments: arguments,
            hideOthers: hideOthers,
          )
          resultInfo["applicationName"] = .string(applicationName)
        }

        // Include arguments and hideOthers in result if provided
        if let arguments {
          resultInfo["arguments"] = .array(arguments.map { .string($0) })
        }

        if let hideOthers {
          resultInfo["hideOthers"] = .bool(hideOthers)
        }

        // Add success status
        resultInfo["success"] = .bool(success)

        // Convert result to JSON string and return as text
        let jsonDict = self.valueToJsonDict(resultInfo)
        let jsonData = try JSONSerialization.data(
          withJSONObject: jsonDict, options: [.prettyPrinted])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return [.text(jsonString)]
      } catch let error as MacMCPErrorInfo {
        // Handle MacMCP errors with detailed information
        logger.error(
          "Error opening application",
          metadata: [
            "bundleId": "\(bundleId ?? "nil")",
            "applicationName": "\(applicationName ?? "nil")",
            "category": "\(error.category.rawValue)",
            "message": "\(error.message)",
          ])

        // Create error result
        let errorInfo: [String: Value] = [
          "success": .bool(false),
          "error": .object([
            "category": .string(error.category.rawValue),
            "code": .double(Double(error.code)),
            "message": .string(error.message),
            "suggestion": .string(error.recoverySuggestion ?? ""),
          ]),
        ]

        // Convert error to JSON string
        let jsonDict = self.valueToJsonDict(errorInfo)
        let jsonData = try JSONSerialization.data(
          withJSONObject: jsonDict, options: [.prettyPrinted])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return [.text(jsonString)]
      } catch {
        // Handle other errors
        logger.error(
          "Unexpected error opening application",
          metadata: [
            "bundleId": "\(bundleId ?? "nil")",
            "applicationName": "\(applicationName ?? "nil")",
            "error": "\(error.localizedDescription)",
          ])

        // Convert to MacMCP error and create error result
        let macError = error.asMacMCPError
        let errorInfo: [String: Value] = [
          "success": .bool(false),
          "error": .object([
            "category": .string(macError.category.rawValue),
            "code": .double(Double(macError.code)),
            "message": .string(macError.message),
            "suggestion": .string(macError.recoverySuggestion ?? ""),
          ]),
        ]

        // Convert error to JSON string
        let jsonDict = self.valueToJsonDict(errorInfo)
        let jsonData = try JSONSerialization.data(
          withJSONObject: jsonDict, options: [.prettyPrinted])
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        return [.text(jsonString)]
      }
    }
  }
}
