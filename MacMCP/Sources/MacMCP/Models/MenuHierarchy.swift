// ABOUTME: Data structure representing a complete menu hierarchy for an application
// ABOUTME: Used for caching and efficient menu discovery with TTL management

import Foundation

/// Represents a complete menu hierarchy for an application with caching metadata
public struct MenuHierarchy: Codable, Sendable {
    /// Application bundle identifier this hierarchy belongs to
    public let application: String
    
    /// Dictionary mapping top-level menu names to arrays of menu paths
    /// Example: "File" -> ["File > New", "File > Open...", "File > Save"]
    public let menus: [String: [String]]
    
    /// Total number of menu items discovered across all menus
    public let totalItems: Int
    
    /// Maximum depth explored during menu discovery
    public let exploredDepth: Int
    
    /// Timestamp when this hierarchy was generated
    public let generatedAt: Date
    
    /// Timestamp when this cache entry expires
    public let cacheExpiresAt: Date
    
    public init(
        application: String,
        menus: [String: [String]],
        totalItems: Int,
        exploredDepth: Int,
        generatedAt: Date = Date(),
        cacheTimeout: TimeInterval = 300
    ) {
        self.application = application
        self.menus = menus
        self.totalItems = totalItems
        self.exploredDepth = exploredDepth
        self.generatedAt = generatedAt
        self.cacheExpiresAt = generatedAt.addingTimeInterval(cacheTimeout)
    }
    
    /// Check if this cache entry is still valid
    public var isValid: Bool {
        return Date() < cacheExpiresAt
    }
    
    /// Get all menu paths in a flat array
    public var allPaths: [String] {
        return menus.values.flatMap { $0 }
    }
    
    /// Get top-level menu names
    public var topLevelMenus: [String] {
        return Array(menus.keys).sorted()
    }
}