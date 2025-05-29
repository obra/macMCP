// ABOUTME: ApplicationManagementTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Tool for managing and controlling macOS applications
public struct ApplicationManagementTool: @unchecked Sendable {
  /// The name of the tool
  public let name = ToolNames.applicationManagement

  /// Description of what the tool does
  public let description = """
  Manage macOS applications with comprehensive launch, termination, and monitoring capabilities.

  IMPORTANT: Use bundleId for precise application identification when possible.

  Available actions:
  - launch: Start an application by name or bundle ID
  - terminate: Gracefully quit an application 
  - forceTerminate: Force quit an unresponsive application
  - isRunning: Check if an application is currently running
  - getRunningApplications: List all currently running applications
  - activateApplication: Bring an application to the foreground
  - hideApplication: Hide an application
  - unhideApplication: Unhide a previously hidden application
  - hideOtherApplications: Hide all applications except the current one
  - getFrontmostApplication: Get the currently active application

  App identification methods:
  - applicationName: Human-readable name (e.g., "Calculator", "Safari")
  - bundleId: Unique identifier (e.g., "com.apple.calculator", "com.apple.Safari")

  Security note: Some actions may require user permission or accessibility access.
  """

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The application service
  private let applicationService: ApplicationServiceProtocol

  /// Logger for the tool
  private let logger: Logger

  /// Core functionality actions
  enum Action: String, Codable {
    case launch
    case terminate
    case forceTerminate
    case isRunning
    case getRunningApplications
    case activateApplication
    case hideApplication
    case unhideApplication
    case hideOtherApplications
    case getFrontmostApplication
  }

  /// Initialize with required services
  /// - Parameters:
  ///   - applicationService: The service to use for application interactions
  ///   - logger: The logger to use
  public init(applicationService: ApplicationServiceProtocol, logger: Logger? = nil) {
    self.applicationService = applicationService
    self.logger = logger ?? Logger(label: "mcp.tool.application_management")

    // Set tool annotations
    annotations = .init(
      title: "macOS Application Management",
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
      openWorldHint: true,
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Create the full input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "action": .object([
          "type": .string("string"),
          "description": .string(
            "Application management action: launch/terminate apps, check status, control visibility",
          ),
          "enum": .array([
            .string("launch"), .string("terminate"), .string("forceTerminate"),
            .string("isRunning"),
            .string("getRunningApplications"), .string("activateApplication"),
            .string("hideApplication"),
            .string("unhideApplication"), .string("hideOtherApplications"),
            .string("getFrontmostApplication"),
          ]),
        ]),
        "applicationName": .object([
          "type": .string("string"),
          "description": .string(
            "Human-readable application name (e.g., 'Calculator', 'Safari', 'TextEdit')",
          ),
        ]),
        "bundleId": .object([
          "type": .string("string"),
          "description": .string(
            "Application bundle identifier for precise targeting (e.g., 'com.apple.calculator', 'com.apple.Safari')",
          ),
        ]),
        "arguments": .object([
          "type": .string("array"),
          "description": .string(
            "Command-line arguments to pass when launching application (optional)"),
          "items": .object(["type": .string("string")]),
        ]),
        "hideOthers": .object([
          "type": .string("boolean"),
          "description": .string(
            "Hide other applications when launching (use sparingly, default: false)"),
          "default": .bool(false),
        ]),
        "waitForLaunch": .object([
          "type": .string("boolean"),
          "description": .string(
            "Wait for application to fully launch before returning (default: true)"),
          "default": .bool(true),
        ]),
        "launchTimeout": .object([
          "type": .string("number"),
          "description": .string("Maximum seconds to wait for application launch (default: 30)"),
          "default": .double(30.0),
        ]),
        "terminateTimeout": .object([
          "type": .string("number"),
          "description": .string("Maximum seconds to wait for graceful termination (default: 10)"),
          "default": .double(10.0),
        ]),
      ]), "required": .array([.string("action")]), "additionalProperties": .bool(false),
      "examples": .array([
        .object(["action": .string("launch"), "applicationName": .string("Calculator")]),
        .object(["action": .string("launch"), "bundleId": .string("com.apple.calculator")]),
        .object(["action": .string("terminate"), "bundleId": .string("com.apple.calculator")]),
        .object(["action": .string("isRunning"), "applicationName": .string("Safari")]),
        .object(["action": .string("getRunningApplications")]),
        .object([
          "action": .string("activateApplication"), "bundleId": .string("com.apple.TextEdit"),
        ]),
      ]),
    ])
  }

  /// Tool handler function
  public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [applicationService, logger] params in
      guard let params else { throw MCPError.invalidParams("Parameters are required") }

      // Get the action
      guard let actionString = params["action"]?.stringValue,
            let action = Action(rawValue: actionString)
      else {
        throw MCPError.invalidParams("Valid action is required")
      }

      // Process based on action type
      switch action {
        case .launch:
          return try await ApplicationManagementTool.handleLaunch(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .terminate:
          return try await ApplicationManagementTool.handleTerminate(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .forceTerminate:
          return try await ApplicationManagementTool.handleForceTerminate(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .isRunning:
          return try await ApplicationManagementTool.handleIsRunning(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .getRunningApplications:
          return try await ApplicationManagementTool.handleGetRunningApplications(
            applicationService: applicationService,
            logger: logger,
          )

        case .activateApplication:
          return try await ApplicationManagementTool.handleActivateApplication(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .hideApplication:
          return try await ApplicationManagementTool.handleHideApplication(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .unhideApplication:
          return try await ApplicationManagementTool.handleUnhideApplication(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .hideOtherApplications:
          return try await ApplicationManagementTool.handleHideOtherApplications(
            params,
            applicationService: applicationService,
            logger: logger,
          )

        case .getFrontmostApplication:
          return try await ApplicationManagementTool.handleGetFrontmostApplication(
            applicationService: applicationService,
            logger: logger,
          )
      }
    }
  }

  /// Handle launch action
  private static func handleLaunch(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling launch action", metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Extract application identifier (name or bundle ID)
    let applicationName = params["applicationName"]?.stringValue
    let bundleId = params["bundleId"]?.stringValue

    if applicationName == nil, bundleId == nil {
      throw MCPError.invalidParams("Either applicationName or bundleId is required")
    }

    // Extract optional parameters
    let arguments = params["arguments"]?.arrayValue?.compactMap(\.stringValue) ?? []
    let hideOthers = params["hideOthers"]?.boolValue ?? false
    let waitForLaunch = params["waitForLaunch"]?.boolValue ?? true
    let launchTimeout = params["launchTimeout"]?.doubleValue ?? 30.0

    do {
      let result = try await applicationService.launchApplication(
        name: applicationName,
        bundleId: bundleId,
        arguments: arguments,
        hideOthers: hideOthers,
        waitForLaunch: waitForLaunch,
        timeout: launchTimeout,
      )

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": true,
              "processIdentifier": \(result.processIdentifier),
              "bundleId": "\(result.bundleId)",
              "applicationName": "\(result.applicationName)"
          }
          """,
        ),
      ]
    } catch {
      logger.error("Launch failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError("Failed to launch application: \(error.localizedDescription)")
    }
  }

  /// Handle terminate action
  private static func handleTerminate(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling terminate action", metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for terminate action")
    }

    // Extract optional parameters
    let terminateTimeout = params["terminateTimeout"]?.doubleValue ?? 10.0

    do {
      let terminated = try await applicationService.terminateApplication(
        bundleId: bundleId,
        timeout: terminateTimeout,
      )

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": \(terminated),
              "bundleId": "\(bundleId)"
          }
          """,
        ),
      ]
    } catch {
      logger.error("Terminate failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError("Failed to terminate application: \(error.localizedDescription)")
    }
  }

  /// Handle force terminate action
  private static func handleForceTerminate(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling force terminate action",
      metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for forceTerminate action")
    }

    do {
      let terminated = try await applicationService.forceTerminateApplication(bundleId: bundleId)

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": \(terminated),
              "bundleId": "\(bundleId)"
          }
          """,
        ),
      ]
    } catch {
      logger.error("Force terminate failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError(
        "Failed to force terminate application: \(error.localizedDescription)",
      )
    }
  }

  /// Handle isRunning action
  private static func handleIsRunning(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling isRunning action", metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for isRunning action")
    }

    do {
      let isRunning = try await applicationService.isApplicationRunning(bundleId: bundleId)

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": true,
              "bundleId": "\(bundleId)",
              "isRunning": \(isRunning)
          }
          """,
        ),
      ]
    } catch {
      logger.error("isRunning check failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError(
        "Failed to check if application is running: \(error.localizedDescription)",
      )
    }
  }

  /// Handle getRunningApplications action
  private static func handleGetRunningApplications(
    applicationService: ApplicationServiceProtocol, logger: Logger,
  )
    async throws -> [Tool.Content]
  {
    logger.debug("Handling getRunningApplications action")

    do {
      let runningApps = try await applicationService.getRunningApplications()

      // Convert to a JSON-friendly array of objects
      var appArray: [String] = []
      for (bundleId, name) in runningApps {
        appArray.append(
          """
          {
              "bundleId": "\(bundleId)",
              "applicationName": "\(name)"
          }
          """,
        )
      }

      // Format the result as JSON array
      return [
        .text(
          """
          {
              "success": true,
              "applications": [
                  \(appArray.joined(separator: ",\n        "))
              ]
          }
          """,
        ),
      ]
    } catch {
      logger.error(
        "getRunningApplications failed", metadata: ["error": "\(error.localizedDescription)"],
      )
      throw MCPError.internalError(
        "Failed to get running applications: \(error.localizedDescription)",
      )
    }
  }

  /// Handle activateApplication action
  private static func handleActivateApplication(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling activateApplication action",
      metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for activateApplication action")
    }

    do {
      let activated = try await applicationService.activateApplication(bundleId: bundleId)

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": \(activated),
              "bundleId": "\(bundleId)"
          }
          """,
        ),
      ]
    } catch {
      logger.error(
        "activateApplication failed", metadata: ["error": "\(error.localizedDescription)"],
      )
      throw MCPError.internalError("Failed to activate application: \(error.localizedDescription)")
    }
  }

  /// Handle hideApplication action
  private static func handleHideApplication(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling hideApplication action",
      metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for hideApplication action")
    }

    do {
      let hidden = try await applicationService.hideApplication(bundleId: bundleId)

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": \(hidden),
              "bundleId": "\(bundleId)"
          }
          """,
        ),
      ]
    } catch {
      logger.error("hideApplication failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError("Failed to hide application: \(error.localizedDescription)")
    }
  }

  /// Handle unhideApplication action
  private static func handleUnhideApplication(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling unhideApplication action",
      metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Validate bundle ID
    guard let bundleId = params["bundleId"]?.stringValue else {
      throw MCPError.invalidParams("bundleId is required for unhideApplication action")
    }

    do {
      let unhidden = try await applicationService.unhideApplication(bundleId: bundleId)

      // Format the result as JSON
      return [
        .text(
          """
          {
              "success": \(unhidden),
              "bundleId": "\(bundleId)"
          }
          """,
        ),
      ]
    } catch {
      logger.error("unhideApplication failed", metadata: ["error": "\(error.localizedDescription)"])
      throw MCPError.internalError("Failed to unhide application: \(error.localizedDescription)")
    }
  }

  /// Handle hideOtherApplications action
  private static func handleHideOtherApplications(
    _ params: [String: Value],
    applicationService: ApplicationServiceProtocol,
    logger: Logger,
  ) async throws -> [Tool.Content] {
    logger.debug(
      "Handling hideOtherApplications action",
      metadata: ["params": "\(params.keys.joined(separator: ", "))"],
    )

    // Extract optional bundle ID
    let bundleId = params["bundleId"]?.stringValue

    do {
      _ = try await applicationService.hideOtherApplications(exceptBundleIdentifier: bundleId)

      // Format the result as JSON
      let exceptInfo = if let bundleId {
        """
        ,
            "exceptBundleIdentifier": "\(bundleId)"
        """
      } else {
        ""
      }

      return [
        .text(
          """
          {
              "success": true\(exceptInfo)
          }
          """,
        ),
      ]
    } catch {
      logger.error(
        "hideOtherApplications failed", metadata: ["error": "\(error.localizedDescription)"],
      )
      throw MCPError.internalError(
        "Failed to hide other applications: \(error.localizedDescription)",
      )
    }
  }

  /// Handle getFrontmostApplication action
  private static func handleGetFrontmostApplication(
    applicationService: ApplicationServiceProtocol, logger: Logger,
  )
    async throws -> [Tool.Content]
  {
    logger.debug("Handling getFrontmostApplication action")

    do {
      if let frontmost = try await applicationService.getFrontmostApplication() {
        // Format the result as JSON
        return [
          .text(
            """
            {
                "success": true,
                "bundleId": "\(frontmost.bundleId)",
                "applicationName": "\(frontmost.name)",
                "processIdentifier": \(frontmost.processId ?? 0),
                "isActive": \(frontmost.isActive),
                "isFinishedLaunching": \(frontmost.isFinishedLaunching)
            }
            """,
          ),
        ]
      } else {
        // No frontmost application
        return [
          .text(
            """
            {
                "success": true,
                "hasFrontmostApplication": false
            }
            """,
          ),
        ]
      }
    } catch {
      logger.error(
        "getFrontmostApplication failed", metadata: ["error": "\(error.localizedDescription)"],
      )
      throw MCPError.internalError(
        "Failed to get frontmost application: \(error.localizedDescription)",
      )
    }
  }

  /// Escape a string for JSON
  private static func escapeJsonString(_ string: String) -> String {
    var escaped = string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
      of: "\"", with: "\\\"",
    )
    .replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
    .replacingOccurrences(of: "\t", with: "\\t")

    // Handle non-printable characters
    for i in 0 ..< 32 {
      if let scalar = UnicodeScalar(i) {
        let character = String(Character(scalar))
        let replacement = "\\u" + String(format: "%04x", i)
        escaped = escaped.replacingOccurrences(of: character, with: replacement)
      }
    }

    return escaped
  }
}
