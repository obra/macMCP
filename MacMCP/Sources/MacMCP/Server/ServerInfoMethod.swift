// ABOUTME: ServerInfoMethod.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The server/info method for the MCP protocol
public enum ServerInfo: MCP.Method {
  public static let name = "server/info"

  /// Empty parameters for server info
  public struct Parameters: Codable, Hashable, Sendable {}

  /// Result for server info
  public struct Result: Codable, Hashable, Sendable {
    /// The server name
    public let name: String

    /// The server version
    public let version: String

    /// Server capabilities
    public let capabilities: Capabilities

    /// Information about the server
    public let info: ServerInfoDetails

    /// Supported protocol versions
    public let supportedVersions: [String]

    /// Create a new server info result
    public init(
      name: String,
      version: String,
      capabilities: Capabilities,
      info: ServerInfoDetails,
      supportedVersions: [String]
    ) {
      self.name = name
      self.version = version
      self.capabilities = capabilities
      self.info = info
      self.supportedVersions = supportedVersions
    }
  }

  /// Server capabilities
  public struct Capabilities: Codable, Hashable, Sendable {
    /// Whether the server has an API explorer
    public let apiExplorer: Bool

    /// Create new capabilities
    public init(apiExplorer: Bool) { self.apiExplorer = apiExplorer }
  }

  /// Server info details
  public struct ServerInfoDetails: Codable, Hashable, Sendable {
    /// The platform the server is running on
    public let platform: String

    /// Operating system information
    public let operatingSystem: String

    /// Create new server info details
    public init(platform: String, os operatingSystem: String) {
      self.platform = platform
      self.operatingSystem = operatingSystem
    }
  }
}
