// ABOUTME: ListPromptsMethod.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The prompts/list method for the MCP protocol
public enum ListPrompts: MCP.Method {
  public static let name = "prompts/list"

  /// Parameters for prompts list
  public struct Parameters: Codable, Hashable, Sendable {
    /// Optional cursor for pagination
    public let cursor: String?

    /// Optional limit for number of results
    public let limit: Int?

    /// Create new parameters
    public init(cursor: String? = nil, limit: Int? = nil) {
      self.cursor = cursor
      self.limit = limit
    }
  }

  /// Result for prompts list
  public struct Result: Codable, Hashable, Sendable {
    /// List of prompts
    public let prompts: [Prompt]

    /// Optional next cursor for pagination
    public let nextCursor: String?

    /// Create a new prompts list result
    public init(prompts: [Prompt], nextCursor: String? = nil) {
      self.prompts = prompts
      self.nextCursor = nextCursor
    }
  }

  /// Prompt information
  public struct Prompt: Codable, Hashable, Sendable {
    /// Prompt ID
    public let id: String

    /// Prompt name
    public let name: String

    /// Prompt description
    public let description: String

    /// Prompt input schema
    public let inputSchema: Value?

    /// Prompt annotations
    public let annotations: Value?

    /// Create a new prompt
    public init(
      id: String,
      name: String,
      description: String,
      inputSchema: Value? = nil,
      annotations: Value? = nil
    ) {
      self.id = id
      self.name = name
      self.description = description
      self.inputSchema = inputSchema
      self.annotations = annotations
    }
  }
}
