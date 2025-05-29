// ABOUTME: ActionLogger.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// An entry in the action log
public struct ActionLogEntry: Codable, Equatable, Identifiable {
  /// Unique identifier for the entry
  public let id: UUID

  /// When the action occurred
  public let timestamp: Date

  /// The category of action (e.g., interaction, screenshot, etc.)
  public let category: String

  /// The specific action performed (e.g., click, type, etc.)
  public let action: String

  /// The target element identifier (if applicable)
  public let targetId: String?

  /// Additional details about the action
  public let details: [String: String]

  /// Whether the action was successful
  public let success: Bool

  /// Error message if the action failed
  public let errorMessage: String?

  /// Create a new action log entry
  /// - Parameters:
  ///   - id: Optional UUID (generates one if not provided)
  ///   - timestamp: When the action occurred (defaults to current date/time)
  ///   - category: The category of action
  ///   - action: The specific action performed
  ///   - targetId: The target element identifier (if applicable)
  ///   - details: Additional details about the action
  ///   - success: Whether the action was successful
  ///   - errorMessage: Error message if the action failed
  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    category: String,
    action: String,
    targetId: String?,
    details: [String: String] = [:],
    success: Bool = true,
    errorMessage: String? = nil
  ) {
    self.id = id
    self.timestamp = timestamp
    self.category = category
    self.action = action
    self.targetId = targetId
    self.details = details
    self.success = success
    self.errorMessage = errorMessage
  }
}

/// Service for logging and retrieving action history
public actor ActionLogService {
  /// The maximum number of log entries to keep
  private let maxEntries: Int

  /// The log entries, newest first
  private var logs: [ActionLogEntry] = []

  /// The logger
  private let logger: Logger

  /// Create a new action log service
  /// - Parameters:
  ///   - maxEntries: Maximum number of log entries to keep (default: 1000)
  ///   - logger: Optional logger to use
  public init(maxEntries: Int = 1000, logger: Logger? = nil) {
    self.maxEntries = maxEntries
    self.logger = logger ?? Logger(label: "mcp.action.log")
  }

  /// Add a new entry to the log
  /// - Parameter entry: The log entry to add
  public func logAction(_ entry: ActionLogEntry) {
    // Add to the beginning of the array (newest first)
    logs.insert(entry, at: 0)

    // Trim the log if it exceeds the maximum size
    if logs.count > maxEntries { logs = Array(logs.prefix(maxEntries)) }

    // Also log to the standard logger for debugging
    if entry.success {
      logger.info(
        "[\(entry.category)] \(entry.action)",
        metadata: ["targetId": "\(entry.targetId ?? "none")", "details": "\(entry.details)"],
      )
    } else {
      logger.error(
        "[\(entry.category)] \(entry.action) - FAILED",
        metadata: [
          "targetId": "\(entry.targetId ?? "none")", "details": "\(entry.details)",
          "error": "\(entry.errorMessage ?? "Unknown error")",
        ],
      )
    }
  }

  /// Log a successful action
  /// - Parameters:
  ///   - category: The category of action
  ///   - action: The specific action performed
  ///   - targetId: The target element identifier (if applicable)
  ///   - details: Additional details about the action
  public func logSuccess(
    category: String, action: String, targetId: String?, details: [String: String] = [:],
  ) {
    let entry = ActionLogEntry(
      timestamp: Date(),
      category: category,
      action: action,
      targetId: targetId,
      details: details,
      success: true,
    )

    logAction(entry)
  }

  /// Log a failed action
  /// - Parameters:
  ///   - category: The category of action
  ///   - action: The specific action performed
  ///   - targetId: The target element identifier (if applicable)
  ///   - error: The error that occurred
  ///   - details: Additional details about the action
  public func logFailure(
    category: String,
    action: String,
    targetId: String?,
    error: Swift.Error,
    details: [String: String] = [:],
  ) {
    let entry = ActionLogEntry(
      timestamp: Date(),
      category: category,
      action: action,
      targetId: targetId,
      details: details,
      success: false,
      errorMessage: error.localizedDescription,
    )

    logAction(entry)
  }

  /// Get filtered log entries
  /// - Parameters:
  ///   - limit: Maximum number of entries to return
  ///   - category: Filter by category
  ///   - action: Filter by action
  ///   - targetId: Filter by target ID
  ///   - successOnly: Only include successful actions
  ///   - failuresOnly: Only include failed actions
  ///   - since: Only include actions after this date
  ///   - until: Only include actions before this date
  /// - Returns: Filtered log entries (newest first)
  public func getLogs(
    limit: Int? = nil,
    category: String? = nil,
    action: String? = nil,
    targetId: String? = nil,
    successOnly: Bool = false,
    failuresOnly: Bool = false,
    since: Date? = nil,
    until: Date? = nil,
  ) -> [ActionLogEntry] {
    var filteredLogs = logs

    // Apply category filter
    if let category { filteredLogs = filteredLogs.filter { $0.category == category } }

    // Apply action filter
    if let action { filteredLogs = filteredLogs.filter { $0.action == action } }

    // Apply target ID filter
    if let targetId { filteredLogs = filteredLogs.filter { $0.targetId == targetId } }

    // Apply success/failure filters
    if successOnly { filteredLogs = filteredLogs.filter(\.success) }

    if failuresOnly { filteredLogs = filteredLogs.filter { !$0.success } }

    // Apply date range filters
    if let since { filteredLogs = filteredLogs.filter { $0.timestamp >= since } }

    if let until { filteredLogs = filteredLogs.filter { $0.timestamp <= until } }

    // Apply limit
    if let limit, limit > 0 { return Array(filteredLogs.prefix(limit)) }

    return filteredLogs
  }

  /// Clear all logs
  public func clearLogs() {
    logs.removeAll()
    logger.info("Action logs cleared")
  }
}
