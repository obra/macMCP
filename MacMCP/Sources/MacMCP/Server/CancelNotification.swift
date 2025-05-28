// ABOUTME: CancelNotification.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The cancel notification for aborting in-progress operations
public struct CancelNotification: MCP.Notification {
  public static let name = "$/cancelRequest"

  /// Parameters for cancel notification
  public struct Parameters: Codable, Hashable, Sendable {
    /// The ID of the request to cancel
    public let id: String

    /// Create new parameters
    public init(id: String) { self.id = id }
  }
}
