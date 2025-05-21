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
            let (content, metadata) = try await handler.handleRead(uri: params.uri, components: components)
            
            // Return the result
            return ResourcesRead.Result(content: content, metadata: metadata)
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
    public func handle(_ params: ListResourceTemplates.Parameters) async throws -> ListResourceTemplates.Result {
        logger.debug("Handling resources/templates/list request")
        
        // Get all templates
        let templates = registry.allTemplates()
        
        // Apply pagination
        let limit = params.limit ?? 100
        let allTemplates = templates
        
        // If there's a cursor, start from there
        if let cursor = params.cursor, let index = allTemplates.firstIndex(where: { $0.id == cursor }) {
            let startIndex = allTemplates.index(after: index)
            if startIndex < allTemplates.endIndex {
                let endIndex = min(startIndex + limit, allTemplates.endIndex)
                let slice = allTemplates[startIndex..<endIndex]
                
                // Determine next cursor
                let nextCursor: String?
                if endIndex < allTemplates.endIndex {
                    nextCursor = allTemplates[endIndex].id
                } else {
                    nextCursor = nil
                }
                
                return ListResourceTemplates.Result(templates: Array(slice), nextCursor: nextCursor)
            }
        }
        
        // No cursor or cursor not found - return from beginning
        let endIndex = min(limit, allTemplates.count)
        let slice = allTemplates[0..<endIndex]
        
        // Determine next cursor
        let nextCursor: String?
        if endIndex < allTemplates.count {
            nextCursor = allTemplates[endIndex].id
        } else {
            nextCursor = nil
        }
        
        return ListResourceTemplates.Result(templates: Array(slice), nextCursor: nextCursor)
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