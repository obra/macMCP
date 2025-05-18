// ABOUTME: ShutdownMethod.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The shutdown method for the MCP protocol
public enum Shutdown: MCP.Method {
  public static let name = "shutdown"

  /// Empty parameters for shutdown
  public struct Parameters: Codable, Hashable, Sendable {}

  /// Empty result for shutdown
  public struct Result: Codable, Hashable, Sendable {}
}
