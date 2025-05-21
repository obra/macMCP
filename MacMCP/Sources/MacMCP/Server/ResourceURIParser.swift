// ABOUTME: ResourceURIParser.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// An error that occurs when parsing a resource URI
public enum ResourceURIError: Swift.Error, CustomStringConvertible {
    /// Invalid URI format
    case invalidURIFormat(String)
    
    /// Missing required parameter
    case missingParameter(String)
    
    /// Invalid parameter value
    case invalidParameterValue(String, String)
    
    /// Resource not found
    case resourceNotFound(String)
    
    /// Description for the error
    public var description: String {
        switch self {
        case .invalidURIFormat(let uri):
            return "Invalid resource URI format: \(uri)"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameterValue(let param, let value):
            return "Invalid value for parameter \(param): \(value)"
        case .resourceNotFound(let uri):
            return "Resource not found: \(uri)"
        }
    }
    
    /// Convert to MCP error
    var asMCPError: MCPError {
        switch self {
        case .invalidURIFormat, .missingParameter, .invalidParameterValue:
            return MCPError.invalidParams(description)
        case .resourceNotFound:
            return MCPError.invalidRequest("Resource not found: \(description)")
        }
    }
}

/// Parser for resource URIs and query parameters
public struct ResourceURIParser {
    /// Parse a resource URI into components
    /// - Parameter uri: The resource URI to parse
    /// - Returns: A ResourceURIComponents object representing the parsed URI
    /// - Throws: ResourceURIError if the URI is invalid
    public static func parse(_ uri: String) throws -> ResourceURIComponents {
        // Special handling for URIs without a scheme
        // If the URI doesn't have a scheme, it might be a relative path like "applications/bundleId/windows"
        if !uri.contains("://") {
            // Assume it's a macos:// URI with just a path
            let pathComponents = uri.split(separator: "?")
            let path = "/" + pathComponents[0]
            
            // Extract query parameters if present
            var queryParams: [String: String] = [:]
            if pathComponents.count > 1, let queryString = pathComponents.last {
                let queryItems = queryString.split(separator: "&")
                for item in queryItems {
                    let keyValue = item.split(separator: "=")
                    if keyValue.count == 2 {
                        queryParams[String(keyValue[0])] = String(keyValue[1])
                    }
                }
            }
            
            return ResourceURIComponents(
                scheme: "macos",
                path: path,
                queryParameters: queryParams
            )
        }
        
        // Handle URLs with or without a host component
        // Some URLs might be formatted as macos://applications/... instead of macos:///applications/...
        var uriToProcess = uri
        if uri.hasPrefix("macos://") && !uri.hasPrefix("macos:///") {
            // Convert macos://path to macos:///path for proper URLComponents parsing
            uriToProcess = uriToProcess.replacingOccurrences(of: "macos://", with: "macos:///")
        }
        
        // Parse the URI to extract path and query parameters
        guard let components = URLComponents(string: uriToProcess) else {
            throw ResourceURIError.invalidURIFormat(uri)
        }
        
        // Extract the scheme and check if it's valid
        guard let scheme = components.scheme, scheme == "macos" else {
            throw ResourceURIError.invalidURIFormat("Invalid scheme: \(components.scheme ?? "none")")
        }
        
        // Extract the path
        let path = components.path
        
        // Extract the query parameters
        var queryParams: [String: String] = [:]
        if let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    queryParams[item.name] = value
                }
            }
        }
        
        // Create and return the parsed components
        return ResourceURIComponents(
            scheme: scheme,
            path: path,
            queryParameters: queryParams
        )
    }
    
    /// Extract path components from a resource path
    /// - Parameter path: The resource path
    /// - Returns: An array of path components
    public static func pathComponents(from path: String) -> [String] {
        // If the path contains a scheme, extract just the path part
        var pathToProcess = path
        if path.contains("://") {
            if let schemeEnd = path.range(of: "://") {
                pathToProcess = String(path[schemeEnd.upperBound...])
            }
        }
        
        // Remove leading slash if present
        let cleanPath = pathToProcess.hasPrefix("/") ? String(pathToProcess.dropFirst()) : pathToProcess
        
        // Split the path into components
        return cleanPath.split(separator: "/").map(String.init)
    }
    
    /// Parse query parameters
    /// - Parameter params: Query parameters dictionary
    /// - Returns: A ResourceQueryParameters object
    public static func parseQueryParameters(_ params: [String: String]) -> ResourceQueryParameters {
        var result = ResourceQueryParameters()
        
        // Parse maxDepth
        if let maxDepthStr = params["maxDepth"], let maxDepth = Int(maxDepthStr) {
            result.maxDepth = maxDepth
        }
        
        // Parse limit
        if let limitStr = params["limit"], let limit = Int(limitStr) {
            result.limit = limit
        }
        
        // Parse interactable
        if let interactableStr = params["interactable"] {
            result.interactable = interactableStr.lowercased() == "true"
        }
        
        // Add any other parameters as custom
        for (key, value) in params where !["maxDepth", "limit", "interactable"].contains(key) {
            result.custom[key] = value
        }
        
        return result
    }
    
    /// Format a resource URI with path and query parameters
    /// - Parameters:
    ///   - path: The resource path
    ///   - queryParams: Optional query parameters
    /// - Returns: A formatted resource URI string
    public static func formatURI(path: String, queryParams: [String: String]? = nil) -> String {
        var components = URLComponents()
        components.scheme = "macos"
        // Add an empty host to ensure we get macos:// instead of macos:/ 
        components.host = ""
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        
        if let queryParams = queryParams, !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        return components.string ?? "macos://\(path)"
    }
}

/// Components of a parsed resource URI
public struct ResourceURIComponents {
    /// URI scheme (usually "macos")
    public let scheme: String
    
    /// Resource path
    public let path: String
    
    /// Query parameters
    public let queryParameters: [String: String]
    
    /// Path components
    public var pathComponents: [String] {
        ResourceURIParser.pathComponents(from: path)
    }
    
    /// Parsed query parameters
    public var parsedQueryParameters: ResourceQueryParameters {
        ResourceURIParser.parseQueryParameters(queryParameters)
    }
    
    /// Initialize with components
    /// - Parameters:
    ///   - scheme: URI scheme
    ///   - path: Resource path
    ///   - queryParameters: Query parameters
    public init(scheme: String, path: String, queryParameters: [String: String] = [:]) {
        self.scheme = scheme
        self.path = path
        self.queryParameters = queryParameters
    }
}

/// Parsed query parameters for resources
public struct ResourceQueryParameters {
    /// Maximum depth for hierarchical resources
    public var maxDepth: Int = 10
    
    /// Maximum number of items to return
    public var limit: Int = 100
    
    /// Whether to return only interactable elements
    public var interactable: Bool = false
    
    /// Custom query parameters
    public var custom: [String: String] = [:]
    
    /// Initialize with default values
    public init() { }
    
    /// Initialize with specific values
    /// - Parameters:
    ///   - maxDepth: Maximum depth
    ///   - limit: Maximum number of items
    ///   - interactable: Whether to return only interactable elements
    public init(maxDepth: Int = 10, limit: Int = 100, interactable: Bool = false) {
        self.maxDepth = maxDepth
        self.limit = limit
        self.interactable = interactable
    }
}