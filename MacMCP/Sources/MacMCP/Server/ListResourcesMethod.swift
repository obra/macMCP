// ABOUTME: This file defines the ListResources method for the MCP protocol.
// ABOUTME: It provides a way to list available resources.

import Foundation
import MCP

/// The resources/list method for the MCP protocol
public enum ListResources: MCP.Method {
    public static let name = "resources/list"
    
    /// Parameters for resources list
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
    
    /// Result for resources list
    public struct Result: Codable, Hashable, Sendable {
        /// List of resources
        public let resources: [Resource]
        
        /// Optional next cursor for pagination
        public let nextCursor: String?
        
        /// Create a new resources list result
        public init(resources: [Resource], nextCursor: String? = nil) {
            self.resources = resources
            self.nextCursor = nextCursor
        }
    }
    
    /// Resource information
    public struct Resource: Codable, Hashable, Sendable {
        /// Resource ID
        public let id: String
        
        /// Resource name
        public let name: String
        
        /// Resource type
        public let type: String
        
        /// Resource metadata
        public let metadata: [String: Value]?
        
        /// Create a new resource
        public init(id: String, name: String, type: String, metadata: [String: Value]? = nil) {
            self.id = id
            self.name = name
            self.type = type
            self.metadata = metadata
        }
    }
}