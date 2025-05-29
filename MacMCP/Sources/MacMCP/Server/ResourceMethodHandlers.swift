// ABOUTME: ResourceMethodHandlers.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Method handler for resources/read
public struct ResourcesReadMethodHandler: Sendable {
  /// The resource registry
  private let registry: ResourceRegistry
  /// Logger for this handler
  private let logger: Logger
  /// Initialize with a resource registry
  /// - Parameters:
  ///   - registry: The resource registry
  ///   - logger: The logger
  public init(registry: ResourceRegistry, logger: Logger) {
    self.registry = registry
    self.logger = logger
  }

  /// Handle a resources/read request
  /// - Parameter params: The request parameters
  /// - Returns: The resources/read result
  /// - Throws: MCPError if an error occurs
  public func handle(_ params: ResourcesRead.Parameters) async throws -> ResourcesRead.Result {
    logger.debug("Handling resources/read request", metadata: ["uri": "\(params.uri)"])
    do {
      // Parse the URI
      let components = try ResourceURIParser.parse(params.uri)
      // Find a handler for this URI
      let handler = try registry.handlerFor(uri: params.uri)
      // Handle the read request
      let (content, metadata) = try await handler.handleRead(
        uri: params.uri, components: components,
      )
      // Convert to MCP Resource.Content
      let resourceContent: MCP.Resource.Content
      if let textContent = content.asText {
        resourceContent = MCP.Resource.Content.text(
          textContent, uri: params.uri, mimeType: metadata?.mimeType,
        )
      } else if let binaryContent = content.asBinary {
        resourceContent = MCP.Resource.Content.binary(
          binaryContent,
          uri: params.uri,
          mimeType: metadata?.mimeType,
        )
      } else {
        throw MCPError.internalError("Invalid content type")
      }
      // Return the result
      return ResourcesRead.Result(contents: [resourceContent])
    } catch let error as ResourceURIError {
      // Convert resource errors to MCP errors
      logger.error("Resource error: \(error.description)")
      throw error.asMCPError
    } catch let error as MCPError {
      // Pass through MCP errors
      logger.error("MCP error: \(error)")
      throw error
    } catch {
      // Convert other errors to MCP errors
      logger.error("Unexpected error: \(error.localizedDescription)")
      throw MCPError.internalError("Unexpected error: \(error.localizedDescription)")
    }
  }
}

/// Method handler for resources/templates/list
public struct ResourcesTemplatesListMethodHandler: Sendable {
  /// The resource registry
  private let registry: ResourceRegistry
  /// Logger for this handler
  private let logger: Logger
  /// Initialize with a resource registry
  /// - Parameters:
  ///   - registry: The resource registry
  ///   - logger: The logger
  public init(registry: ResourceRegistry, logger: Logger) {
    self.registry = registry
    self.logger = logger
  }

  /// Handle a resources/templates/list request
  /// - Parameter params: The request parameters
  /// - Returns: The resources/templates/list result
  /// - Throws: MCPError if an error occurs
  public func handle(_: ListResourceTemplates.Parameters) async throws
    -> ListResourceTemplates.Result
  {
    logger.debug("Handling resources/templates/list request")
    // Get all templates
    let templates = registry.allTemplates()
    // Return using our result format
    return ListResourceTemplates.Result(templates: templates, nextCursor: nil)
  }
}

/// Method handler for resources/list
public struct ResourcesListMethodHandler: Sendable {
  /// The resource registry
  private let registry: ResourceRegistry
  /// Logger for this handler
  private let logger: Logger
  /// Initialize with a resource registry
  /// - Parameters:
  ///   - registry: The resource registry
  ///   - logger: The logger
  public init(registry: ResourceRegistry, logger: Logger) {
    self.registry = registry
    self.logger = logger
  }

  /// Handle a resources/list request
  /// - Parameter params: The request parameters
  /// - Returns: The resources/list result
  /// - Throws: MCPError if an error occurs
  public func handle(_ params: ListResources.Parameters) async throws -> ListResources.Result {
    logger.debug("Handling resources/list request")
    // Get resources from registry
    let (resources, nextCursor) = registry.listResources(cursor: params.cursor, limit: params.limit)
    // Return the result
    return ListResources.Result(resources: resources, nextCursor: nextCursor)
  }
}
