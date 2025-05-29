// ABOUTME: ResourcesTemplatesList.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The resources/templates/list method for the MCP protocol
public enum ListResourceTemplates: MCP.Method {
  public static let name = "resources/templates/list"

  /// Parameters for resource templates list
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

  /// Result for resource templates list
  public struct Result: Codable, Hashable, Sendable {
    /// List of resource templates
    public let templates: [Template]

    /// Optional next cursor for pagination
    public let nextCursor: String?

    /// Create a new resource templates list result
    public init(templates: [Template], nextCursor: String? = nil) {
      self.templates = templates
      self.nextCursor = nextCursor
    }
  }

  /// Resource template
  public struct Template: Codable, Hashable, Sendable {
    /// Template URI pattern
    public let uriTemplate: String

    /// Human-readable template name
    public let name: String

    /// Template description
    public let description: String?
    /// Template MIME type
    public let mimeType: String?

    /// Template parameters
    public let parameters: [Parameter]?

    /// Template metadata
    public let metadata: [String: Value]?

    /// Create a new resource template
    public init(
      uriTemplate: String,
      name: String,
      description: String? = nil,
      mimeType: String? = nil,
      parameters: [Parameter]? = nil,
      metadata: [String: Value]? = nil
    ) {
      self.uriTemplate = uriTemplate
      self.name = name
      self.description = description
      self.mimeType = mimeType
      self.parameters = parameters
      self.metadata = metadata
    }

    /// Convert to MCP Resource.Template
    public func toMCPTemplate() -> MCP.Resource.Template {
      MCP.Resource.Template(
        uriTemplate: uriTemplate,
        name: name,
        description: description,
        mimeType: mimeType,
      )
    }
  }

  /// Resource template parameter
  public struct Parameter: Codable, Hashable, Sendable {
    /// Parameter name
    public let name: String

    /// Parameter description
    public let description: String?

    /// Parameter type (string, number, etc.)
    public let type: String?

    /// Whether the parameter is required
    public let required: Bool?

    /// Parameter default value
    public let defaultValue: Value?

    /// Parameter validation pattern (regex)
    public let pattern: String?

    /// Enumerated valid values
    public let enumValues: [String]?

    /// Parameter metadata
    public let metadata: [String: Value]?

    /// Create a new resource template parameter
    public init(
      name: String,
      description: String? = nil,
      type: String? = nil,
      required: Bool? = nil,
      defaultValue: Value? = nil,
      pattern: String? = nil,
      enumValues: [String]? = nil,
      metadata: [String: Value]? = nil
    ) {
      self.name = name
      self.description = description
      self.type = type
      self.required = required
      self.defaultValue = defaultValue
      self.pattern = pattern
      self.enumValues = enumValues
      self.metadata = metadata
    }
  }
}
