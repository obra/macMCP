// ABOUTME: Protocol defining menu caching operations with TTL management
// ABOUTME: Used to cache menu hierarchies for performance optimization

import Foundation

/// Protocol for menu caching service with TTL management
public protocol MenuCacheServiceProtocol: Sendable {
  /// Get cached menu hierarchy for an application
  /// - Parameter bundleId: Application bundle identifier
  /// - Returns: Cached hierarchy if valid, nil if expired or not found
  func getHierarchy(for bundleId: String) async -> MenuHierarchy?
  /// Store menu hierarchy in cache
  /// - Parameters:
  ///   - hierarchy: Menu hierarchy to cache
  ///   - bundleId: Application bundle identifier
  func setHierarchy(_ hierarchy: MenuHierarchy, for bundleId: String) async
  /// Invalidate cache entry for specific application
  /// - Parameter bundleId: Application bundle identifier
  func invalidate(for bundleId: String) async
  /// Invalidate all cache entries
  func invalidateAll() async
  /// Remove expired cache entries to free memory
  func cleanup() async
  /// Get current cache statistics
  /// - Returns: Cache statistics including size and hit rate
  func getStatistics() async -> CacheStatistics
}

/// Statistics about cache performance and usage
public struct CacheStatistics: Sendable {
  /// Number of cache entries currently stored
  public let entryCount: Int
  /// Number of cache hits since last reset
  public let hitCount: Int
  /// Number of cache misses since last reset
  public let missCount: Int
  /// Cache hit rate as a percentage (0.0 to 1.0)
  public var hitRate: Double {
    let total = hitCount + missCount
    return total > 0 ? Double(hitCount) / Double(total) : 0.0
  }
  /// Number of expired entries removed during cleanup
  public let expiredCount: Int
  public init(entryCount: Int, hitCount: Int, missCount: Int, expiredCount: Int) {
    self.entryCount = entryCount
    self.hitCount = hitCount
    self.missCount = missCount
    self.expiredCount = expiredCount
  }
}
