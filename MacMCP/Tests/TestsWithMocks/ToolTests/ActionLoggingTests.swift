// ABOUTME: ActionLoggingTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import Testing
import XCTest

@testable import MacMCP

@Suite(.serialized)
struct ActionLoggingTests {
  @Test("Log capture and retrieval")
  func logCaptureAndRetrieval() async throws {
    // Create a log capture service
    let logService = LogService()

    // Create a tool with the log service
    let tool = ActionLogTool(logService: logService)

    // Execute some actions that should be logged
    let entry1 = ActionLogEntry(
      timestamp: Date(),
      category: "interaction",
      action: "click",
      targetId: "button-123",
      details: ["position": "10,20"],
      success: true,
    )

    let entry2 = ActionLogEntry(
      timestamp: Date().addingTimeInterval(1),
      category: "interaction",
      action: "type",
      targetId: "textfield-456",
      details: ["text": "Hello, world!"],
      success: true,
    )

    let entry3 = ActionLogEntry(
      timestamp: Date().addingTimeInterval(2),
      category: "screenshot",
      action: "capture",
      targetId: nil,
      details: ["region": "full"],
      success: true,
    )

    // Add the log entries
    logService.addLogEntry(entry1)
    logService.addLogEntry(entry2)
    logService.addLogEntry(entry3)

    // Retrieve all logs
    let input: [String: Value] = [
      "limit": .int(10)
    ]

    let result = try await tool.handler(input)

    // Verify the result is text containing log entries
    #expect(result.count == 1)
    guard case .text(let json) = result[0] else {
      #expect(false, "Expected text result")
      return
    }
    
    #expect(json.contains("interaction"))
    #expect(json.contains("click"))
    #expect(json.contains("button-123"))
    #expect(json.contains("type"))
    #expect(json.contains("textfield-456"))
    #expect(json.contains("screenshot"))
    #expect(json.contains("capture"))
  }

  @Test("Log filtering by category")
  func logFilteringByCategory() async throws {
    // Create a log capture service
    let logService = LogService()

    // Create a tool with the log service
    let tool = ActionLogTool(logService: logService)

    // Add log entries with different categories
    logService.addLogEntry(
      ActionLogEntry(
        timestamp: Date(),
        category: "interaction",
        action: "click",
        targetId: "button-123",
        success: true,
      ))

    logService.addLogEntry(
      ActionLogEntry(
        timestamp: Date(),
        category: "screenshot",
        action: "capture",
        targetId: nil,
        success: true,
      ))

    // Retrieve filtered logs by category
    let input: [String: Value] = [
      "category": .string("interaction")
    ]

    let result = try await tool.handler(input)

    // Verify the result only contains interaction logs
    #expect(result.count == 1)
    guard case .text(let json) = result[0] else {
      #expect(false, "Expected text result")
      return
    }
    
    #expect(json.contains("interaction"))
    #expect(json.contains("click"))
    #expect(json.contains("button-123"))
    #expect(!json.contains("screenshot"))
    #expect(!json.contains("capture"))
  }

  @Test("Log filtering by action")
  func logFilteringByAction() async throws {
    // Create a log capture service
    let logService = LogService()

    // Create a tool with the log service
    let tool = ActionLogTool(logService: logService)

    // Add log entries with different actions
    logService.addLogEntry(
      ActionLogEntry(
        timestamp: Date(),
        category: "interaction",
        action: "click",
        targetId: "button-123",
        success: true,
      ))

    logService.addLogEntry(
      ActionLogEntry(
        timestamp: Date(),
        category: "interaction",
        action: "type",
        targetId: "textfield-456",
        success: true,
      ))

    // Retrieve filtered logs by action
    let input: [String: Value] = [
      "action": .string("click")
    ]

    let result = try await tool.handler(input)

    // Verify the result only contains click logs
    #expect(result.count == 1)
    guard case .text(let json) = result[0] else {
      #expect(false, "Expected text result")
      return
    }
    
    #expect(json.contains("interaction"))
    #expect(json.contains("click"))
    #expect(json.contains("button-123"))
    #expect(!json.contains("type"))
    #expect(!json.contains("textfield-456"))
  }

  @Test("Log filtering by time range")
  func logFilteringByTimeRange() async throws {
    // Create a log capture service
    let logService = LogService()

    // Create a tool with the log service
    let tool = ActionLogTool(logService: logService)

    // Create timestamps spaced 1 minute apart
    let now = Date()
    let oneMinuteAgo = now.addingTimeInterval(-60)
    let twoMinutesAgo = now.addingTimeInterval(-120)

    // Add log entries with different timestamps
    logService.addLogEntry(
      ActionLogEntry(
        timestamp: twoMinutesAgo,
        category: "interaction",
        action: "click",
        targetId: "old-button",
        success: true,
      ))

    logService.addLogEntry(
      ActionLogEntry(
        timestamp: now,
        category: "interaction",
        action: "click",
        targetId: "new-button",
        success: true,
      ))

    // Retrieve filtered logs by time range (last minute)
    let input: [String: Value] = [
      "since": .int(Int(oneMinuteAgo.timeIntervalSince1970))
    ]

    let result = try await tool.handler(input)

    // Verify the result only contains recent logs
    #expect(result.count == 1)
    guard case .text(let json) = result[0] else {
      #expect(false, "Expected text result")
      return
    }
    
    #expect(json.contains("new-button"))
    #expect(!json.contains("old-button"))
  }
}

// Mock action log entry for testing
struct ActionLogEntry: Codable, Equatable {
  let timestamp: Date
  let category: String
  let action: String
  let targetId: String?
  let details: [String: String]
  let success: Bool

  init(
    timestamp: Date,
    category: String,
    action: String,
    targetId: String?,
    details: [String: String] = [:],
    success: Bool
  ) {
    self.timestamp = timestamp
    self.category = category
    self.action = action
    self.targetId = targetId
    self.details = details
    self.success = success
  }
}

// Mock log service for testing
class LogService: @unchecked Sendable {
  private var logs: [ActionLogEntry] = []

  func addLogEntry(_ entry: ActionLogEntry) {
    logs.append(entry)
  }

  func getLogs(
    limit: Int? = nil,
    category: String? = nil,
    action: String? = nil,
    since: Date? = nil,
  ) -> [ActionLogEntry] {
    var filteredLogs = logs

    // Apply category filter
    if let category {
      filteredLogs = filteredLogs.filter { $0.category == category }
    }

    // Apply action filter
    if let action {
      filteredLogs = filteredLogs.filter { $0.action == action }
    }

    // Apply timestamp filter
    if let since {
      filteredLogs = filteredLogs.filter { $0.timestamp >= since }
    }

    // Sort by timestamp (newest first)
    filteredLogs.sort { $0.timestamp > $1.timestamp }

    // Apply limit
    if let limit, limit > 0 {
      return Array(filteredLogs.prefix(limit))
    }

    return filteredLogs
  }
}

// Mock action log tool for testing
struct ActionLogTool: @unchecked Sendable {
  let name = "macos/action_log"
  let description = "Retrieve action logs from the macOS MCP server"

  private let logService: LogService

  init(logService: LogService) {
    self.logService = logService
  }

  // Handler property that captures self
  var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [self] params in
      try await self.processRequest(params)
    }
  }

  // Private method to do the actual work
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    // Get filter parameters
    let limit = params?["limit"]?.intValue
    let category = params?["category"]?.stringValue
    let action = params?["action"]?.stringValue
    let since = params?["since"]?.intValue.map { Date(timeIntervalSince1970: TimeInterval($0)) }

    // Get filtered logs
    let logs = logService.getLogs(
      limit: limit,
      category: category,
      action: action,
      since: since,
    )

    // Convert to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let jsonData = try encoder.encode(logs)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw MCPError.internalError("Failed to encode logs as JSON")
    }

    return [.text(jsonString)]
  }
}
