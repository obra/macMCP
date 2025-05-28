// ABOUTME: ErrorHandling.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// Domain for MacMCP errors
public let MacMCPErrorDomain = "com.macos.mcp"

/// Error categories for MacMCP
public enum MacMCPErrorCategory: String, Sendable {
  case permissions = "Permissions"
  case accessibility = "Accessibility"
  case interaction = "Interaction"
  case element = "Element"
  case screenshot = "Screenshot"
  case application = "Application"
  case applicationLaunch = "ApplicationLaunch"
  case applicationNotFound = "ApplicationNotFound"
  case network = "Network"
  case parsing = "Parsing"
  case timeout = "Timeout"
  case unknown = "Unknown"
}

/// Detailed error information for MacMCP
public struct MacMCPErrorInfo: Swift.Error, LocalizedError, Sendable {
  /// The error category
  public let category: MacMCPErrorCategory

  /// The specific error code within the category
  public let code: Int

  /// The error message
  public let message: String

  /// Additional context about the error
  public let context: [String: String]

  /// The underlying error, if any
  public let underlyingError: (any Swift.Error)?

  /// Human-readable error description
  public var errorDescription: String? { message }

  /// Human-readable failure reason
  public var failureReason: String? {
    let contextString = context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")

    let baseReason = "[\(category.rawValue)] \(message)"
    return contextString.isEmpty ? baseReason : "\(baseReason) (\(contextString))"
  }

  /// Human-readable recovery suggestion
  public var recoverySuggestion: String? {
    switch category {
    case .permissions:
      "Check System Settings > Privacy & Security > Accessibility to ensure this application has the required permissions."

    case .accessibility:
      "The macOS accessibility API encountered an issue. This may be due to system restrictions or unsupported UI elements."

    case .interaction:
      "The UI element might not support this interaction, or the element might have changed or disappeared. Try getting the current UI state first."

    case .element:
      "The UI element could not be found or accessed. It may have been removed, changed, or might be in a different part of the UI hierarchy."

    case .screenshot:
      "Taking a screenshot failed. Make sure screen recording permissions are granted in System Settings > Privacy & Security."

    case .application:
      "The target application could not be accessed. Make sure it is running and is not in a restricted mode."

    case .applicationLaunch:
      "Failed to launch the application. Check that the application is installed and not damaged. You may need to check system permissions as well."

    case .applicationNotFound:
      "The specified application could not be found. Verify the application name or bundle identifier and ensure the application is installed on the system."

    case .network:
      "Network communication failed. Check your internet connection and firewall settings."

    case .parsing: "Failed to parse data. The format may be invalid or unexpected."

    case .timeout:
      "The operation timed out. The system might be under heavy load or the operation may be too complex."

    case .unknown: "An unexpected error occurred. Please try again or restart the application."
    }
  }

  /// Create a new MacMCP error
  /// - Parameters:
  ///   - category: The error category
  ///   - code: The specific error code
  ///   - message: The error message
  ///   - context: Additional context about the error
  ///   - underlyingError: The underlying error, if any
  public init(
    category: MacMCPErrorCategory,
    code: Int,
    message: String,
    context: [String: String] = [:],
    underlyingError: (any Swift.Error)? = nil
  ) {
    self.category = category
    self.code = code
    self.message = message
    self.context = context
    self.underlyingError = underlyingError
  }

  /// Convert to an NSError
  public var asNSError: NSError {
    // Combine context and error information
    var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]

    // Add failure reason if available
    if let reason = failureReason { userInfo[NSLocalizedFailureReasonErrorKey] = reason }

    // Add recovery suggestion if available
    if let suggestion = recoverySuggestion {
      userInfo[NSLocalizedRecoverySuggestionErrorKey] = suggestion
    }

    // Add error category
    userInfo["category"] = category.rawValue

    // Add context information
    for (key, value) in context { userInfo["context_\(key)"] = value }

    // Add underlying error if available
    if let underlyingError { userInfo[NSUnderlyingErrorKey] = underlyingError }

    // Create a fully-formed domain with category
    let domain = "\(MacMCPErrorDomain).\(category.rawValue.lowercased())"

    return NSError(domain: domain, code: code, userInfo: userInfo)
  }

  /// Convert to MCP error for protocol communication
  public var asMCPError: MCPError {
    // Use the new MCPError.from helper
    MCPError.from(self)
  }
}

/// Create a standard permissions error
public func createPermissionError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .permissions,
    code: MacMCPErrorCode.permissionDenied,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard element error
public func createElementError(
  message: String, context: [String: String] = [:], underlyingError: Swift.Error? = nil,
)
  -> MacMCPErrorInfo
{
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.elementNotFound,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard element not interactive error
public func createElementNotInteractiveError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.elementNotInteractive,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard element zero coordinates error
public func createZeroCoordinatesError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.zeroCoordinatesElement,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an invalid element path error
public func createInvalidPathError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.invalidElementPath,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a path resolution failed error
public func createPathResolutionError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.elementPathResolutionFailed,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an ambiguous element path error
public func createAmbiguousPathError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .element,
    code: MacMCPErrorCode.ambiguousElementPath,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard interaction error
public func createInteractionError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .interaction,
    code: MacMCPErrorCode.actionFailed,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard action not supported error
public func createActionNotSupportedError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .interaction,
    code: MacMCPErrorCode.actionNotSupported,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard screenshot error
public func createScreenshotError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .screenshot,
    code: MacMCPErrorCode.screenshotFailed,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a standard application error
public func createApplicationError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .application,
    code: MacMCPErrorCode.applicationError,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an application launch error
public func createApplicationLaunchError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .applicationLaunch,
    code: MacMCPErrorCode.applicationLaunchFailed,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an application not found error
public func createApplicationNotFoundError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .applicationNotFound,
    code: MacMCPErrorCode.applicationNotFound,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an application not running error
public func createApplicationNotRunningError(
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  MacMCPErrorInfo(
    category: .applicationNotFound,
    code: MacMCPErrorCode.applicationNotRunning,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create an operation timeout error
public func createTimeoutError(
  message: String, context: [String: String] = [:], underlyingError: Swift.Error? = nil,
)
  -> MacMCPErrorInfo
{
  MacMCPErrorInfo(
    category: .timeout,
    code: MacMCPErrorCode.operationTimeout,
    message: message,
    context: context,
    underlyingError: underlyingError,
  )
}

/// Create a clipboard error
public func createClipboardError(
  code: String,
  message: String,
  context: [String: String] = [:],
  underlyingError: Swift.Error? = nil,
) -> MacMCPErrorInfo {
  var contextWithCode = context
  contextWithCode["errorCode"] = code

  return MacMCPErrorInfo(
    category: .interaction,
    code: MacMCPErrorCode.actionFailed,
    message: message,
    context: contextWithCode,
    underlyingError: underlyingError,
  )
}

/// Extension for NSError conversion to MacMCPErrorInfo
extension NSError {
  /// Convert to MacMCPErrorInfo if possible
  var asMacMCPError: MacMCPErrorInfo? {
    // Check if this is already a MacMCP error
    if domain.hasPrefix(MacMCPErrorDomain) {
      // Extract category from domain
      let domainComponents = domain.components(separatedBy: ".")
      let categoryString = domainComponents.count > 1 ? domainComponents[1] : "unknown"

      // Get category
      let category = MacMCPErrorCategory(rawValue: categoryString.capitalized) ?? .unknown

      // Extract context from userInfo
      var context: [String: String] = [:]
      for (key, value) in userInfo where key.hasPrefix("context_") {
        let contextKey = String(key.dropFirst("context_".count))
        if let stringValue = value as? String {
          context[contextKey] = stringValue
        } else {
          context[contextKey] = "\(value)"
        }
      }

      // Get underlying error
      let underlyingError = userInfo[NSUnderlyingErrorKey] as? Swift.Error

      return MacMCPErrorInfo(
        category: category,
        code: code,
        message: localizedDescription,
        context: context,
        underlyingError: underlyingError,
      )
    }

    // For other NSErrors, create a new MacMCP error
    return MacMCPErrorInfo(
      category: .unknown,
      code: code,
      message: localizedDescription,
      context: ["domain": domain],
      underlyingError: self,
    )
  }
}

/// Extension for Swift.Error conversion to MacMCPErrorInfo
extension Swift.Error {
  /// Convert to MacMCPErrorInfo
  var asMacMCPError: MacMCPErrorInfo {
    // If this is already a MacMCPErrorInfo, return it
    if let macMCPError = self as? MacMCPErrorInfo { return macMCPError }

    // All Swift.Error can be converted to NSError
    let nsError = self as NSError

    // Try to convert via NSError
    if let macMCPError = nsError.asMacMCPError { return macMCPError }

    // For other errors, create a new MacMCP error
    return MacMCPErrorInfo(
      category: .unknown,
      code: nsError.code,
      message: nsError.localizedDescription,
      underlyingError: self,
    )
  }

  /// Convert to MCP.MCPError for protocol communication
  var asMCPError: MCPError {
    // If this is already an MCPError, return it
    if let mcpError = self as? MCPError { return mcpError }

    // If this is a MacMCPErrorInfo, convert it
    if let macMCPError = self as? MacMCPErrorInfo { return macMCPError.asMCPError }

    // All Swift.Error can be converted to NSError
    let nsError = self as NSError

    // Try to convert via NSError and MacMCPErrorInfo
    if let macMCPError = nsError.asMacMCPError { return macMCPError.asMCPError }

    // For other errors, create an internal error
    return .internalError(nsError.localizedDescription)
  }
}
