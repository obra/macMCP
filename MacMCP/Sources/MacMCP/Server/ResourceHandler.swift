// ABOUTME: ResourceHandler.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// Protocol for handling resource requests
public protocol ResourceHandler: Sendable {
    /// Resource URI pattern (e.g., "macos://applications")
    var uriPattern: String { get }
    
    /// Human-readable name for the resource
    var name: String { get }
    
    /// Description of the resource
    var description: String { get }
    
    /// MIME type for the resource content
    var mimeType: String { get }
    
    /// Whether the resource can match the given URI
    /// - Parameter uri: The URI to match
    /// - Returns: Whether this handler can handle the URI
    func canHandle(uri: String) -> Bool
    
    /// Handle a resource read request
    /// - Parameters:
    ///   - uri: The resource URI
    ///   - components: Parsed URI components
    /// - Returns: The resource content and metadata
    /// - Throws: Error if the resource cannot be read
    func handleRead(uri: String, components: ResourceURIComponents) async throws -> (ResourcesRead.ResourceContent, ResourcesRead.ResourceMetadata?)
}

/// Default implementation for common resource handler functionality
extension ResourceHandler {
    /// Default MIME type for JSON content
    public var mimeType: String {
        "application/json"
    }
    
    /// Default implementation for checking if a handler can handle a URI
    public func canHandle(uri: String) -> Bool {
        // Parse the URI
        guard let components = try? ResourceURIParser.parse(uri) else {
            return false
        }
        
        // Get the pattern components
        let patternComponents = ResourceURIParser.pathComponents(from: uriPattern)
        
        // Get the URI path components
        let uriComponents = components.pathComponents
        
        // Check if the number of components match
        if patternComponents.count != uriComponents.count {
            return false
        }
        
        // Check each component
        for (pattern, component) in zip(patternComponents, uriComponents) {
            // If the pattern component is a parameter (enclosed in {}), it matches anything
            if pattern.hasPrefix("{") && pattern.hasSuffix("}") {
                continue
            }
            
            // Otherwise, the component should match exactly
            if pattern != component {
                return false
            }
        }
        
        return true
    }
    
    /// Extract parameter values from a URI based on the pattern
    /// - Parameters:
    ///   - uri: The URI
    ///   - pattern: The pattern to match against
    /// - Returns: Dictionary of parameter names to values
    /// - Throws: ResourceURIError if the URI doesn't match the pattern
    public func extractParameters(from uri: String, pattern: String) throws -> [String: String] {
        // Debug mode removed
        
        // Check if the URI is missing a scheme, and if the pattern has one
        var normalizedUri = uri
        if !uri.contains("://") && pattern.contains("://") {
            // The pattern has a scheme (e.g., macos://) but the URI doesn't
            // Extract the scheme from the pattern and add it to the URI
            if let schemeEnd = pattern.range(of: "://") {
                let scheme = pattern[..<schemeEnd.upperBound]
                normalizedUri = String(scheme) + normalizedUri
            }
        }
        
        // Parse the URI
        do {
            let components = try ResourceURIParser.parse(normalizedUri)
            
            
            // Get the pattern components
            let patternComponents = ResourceURIParser.pathComponents(from: pattern)
            
            
            // Get the URI path components
            let uriComponents = components.pathComponents
            
            
            // Check if the number of components match
            if patternComponents.count != uriComponents.count {
                throw ResourceURIError.invalidURIFormat(uri)
            }
            
            var parameters: [String: String] = [:]
            
            // Extract parameter values
            for (pattern, component) in zip(patternComponents, uriComponents) {
                
                // If the pattern component is a parameter (enclosed in {}), extract its value
                if pattern.hasPrefix("{") && pattern.hasSuffix("}") {
                    let paramName = String(pattern.dropFirst().dropLast())
                    parameters[paramName] = component
                } else if pattern != component {
                    // If this is not a parameter, the components should match exactly
                    throw ResourceURIError.invalidURIFormat(uri)
                }
            }
            
            return parameters
            
        } catch {
            throw error
        }
    }
}

/// Registry for resource handlers
public class ResourceRegistry: @unchecked Sendable {
    /// Registered resource handlers
    private var handlers: [ResourceHandler] = []
    
    /// Resource templates
    private var templates: [ListResourceTemplates.Template] = []
    
    /// Initialize a new empty registry
    public init() { }
    
    /// Register a resource handler
    /// - Parameter handler: The handler to register
    public func register(_ handler: ResourceHandler) {
        handlers.append(handler)
    }
    
    /// Register a resource template
    /// - Parameter template: The template to register
    public func registerTemplate(_ template: ListResourceTemplates.Template) {
        templates.append(template)
    }
    
    /// Find a handler for the given URI
    /// - Parameter uri: The URI to handle
    /// - Returns: The handler if found
    /// - Throws: ResourceURIError if no handler is found
    public func handlerFor(uri: String) throws -> ResourceHandler {
        for handler in handlers {
            if handler.canHandle(uri: uri) {
                return handler
            }
        }
        
        throw ResourceURIError.resourceNotFound(uri)
    }
    
    /// Get all registered resource handlers
    /// - Returns: Array of resource handlers
    public func allHandlers() -> [ResourceHandler] {
        return handlers
    }
    
    /// Get all registered resource templates
    /// - Returns: Array of resource templates
    public func allTemplates() -> [ListResourceTemplates.Template] {
        return templates
    }
    
    /// List all available resources
    /// - Parameters:
    ///   - cursor: Optional pagination cursor
    ///   - limit: Maximum number of resources to return
    /// - Returns: Array of resources and optional next cursor
    public func listResources(cursor: String? = nil, limit: Int? = nil) -> ([ListResources.Resource], String?) {
        let actualLimit = limit ?? 100
        
        // Convert handlers to resources
        let resources = handlers.map { handler in
            ListResources.Resource(
                id: handler.uriPattern,
                name: handler.name,
                type: handler.mimeType
            )
        }
        
        // Simple pagination based on cursor
        if let cursor = cursor, let index = resources.firstIndex(where: { $0.id == cursor }) {
            let startIndex = resources.index(after: index)
            if startIndex < resources.endIndex {
                let endIndex = min(startIndex + actualLimit, resources.endIndex)
                let slice = resources[startIndex..<endIndex]
                
                // Determine next cursor
                let nextCursor: String?
                if endIndex < resources.endIndex {
                    nextCursor = resources[endIndex].id
                } else {
                    nextCursor = nil
                }
                
                return (Array(slice), nextCursor)
            }
        }
        
        // No cursor or cursor not found - return from beginning
        let endIndex = min(actualLimit, resources.count)
        let slice = resources[0..<endIndex]
        
        // Determine next cursor
        let nextCursor: String?
        if endIndex < resources.count {
            nextCursor = resources[endIndex].id
        } else {
            nextCursor = nil
        }
        
        return (Array(slice), nextCursor)
    }
}