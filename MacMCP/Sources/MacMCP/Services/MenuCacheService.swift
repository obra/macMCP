// ABOUTME: Actor-based menu cache implementation with TTL and LRU eviction
// ABOUTME: Provides thread-safe caching for menu hierarchies with performance monitoring

import Foundation

/// Actor-based menu cache service with TTL management and LRU eviction
public actor MenuCacheService: MenuCacheServiceProtocol {
    /// Cache storage for menu hierarchies
    private var cache: [String: MenuHierarchy] = [:]
    
    /// LRU tracking - most recently accessed bundle IDs
    private var accessOrder: [String] = []
    
    /// Performance statistics
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var expiredCount: Int = 0
    
    /// Maximum cache size (number of entries)
    private let maxCacheSize: Int
    
    /// Default cache timeout for new entries (5 minutes)
    private let defaultTimeout: TimeInterval
    
    public init(maxCacheSize: Int = 50, defaultTimeout: TimeInterval = 300) {
        self.maxCacheSize = maxCacheSize
        self.defaultTimeout = defaultTimeout
    }
    
    public func getHierarchy(for bundleId: String) async -> MenuHierarchy? {
        // Check if hierarchy exists and is valid
        guard let hierarchy = cache[bundleId] else {
            missCount += 1
            return nil
        }
        
        // Check if hierarchy is still valid
        guard hierarchy.isValid else {
            // Remove expired entry
            cache.removeValue(forKey: bundleId)
            removeFromAccessOrder(bundleId)
            expiredCount += 1
            missCount += 1
            return nil
        }
        
        // Update LRU order
        updateAccessOrder(for: bundleId)
        hitCount += 1
        
        return hierarchy
    }
    
    public func setHierarchy(_ hierarchy: MenuHierarchy, for bundleId: String) async {
        // Ensure we don't exceed max cache size
        if cache.count >= maxCacheSize && cache[bundleId] == nil {
            await evictLeastRecentlyUsed()
        }
        
        // Store hierarchy
        cache[bundleId] = hierarchy
        updateAccessOrder(for: bundleId)
    }
    
    public func invalidate(for bundleId: String) async {
        cache.removeValue(forKey: bundleId)
        removeFromAccessOrder(bundleId)
    }
    
    public func invalidateAll() async {
        cache.removeAll()
        accessOrder.removeAll()
        
        // Reset statistics but keep expired count for historical tracking
        hitCount = 0
        missCount = 0
    }
    
    public func cleanup() async {
        var expiredKeys: [String] = []
        
        // Find expired entries
        for (bundleId, hierarchy) in cache {
            if !hierarchy.isValid {
                expiredKeys.append(bundleId)
            }
        }
        
        // Remove expired entries
        for key in expiredKeys {
            cache.removeValue(forKey: key)
            removeFromAccessOrder(key)
            expiredCount += 1
        }
    }
    
    public func getStatistics() async -> CacheStatistics {
        return CacheStatistics(
            entryCount: cache.count,
            hitCount: hitCount,
            missCount: missCount,
            expiredCount: expiredCount
        )
    }
    
    // MARK: - Private Methods
    
    /// Update LRU access order for a bundle ID
    private func updateAccessOrder(for bundleId: String) {
        // Remove from current position
        removeFromAccessOrder(bundleId)
        
        // Add to front (most recently used)
        accessOrder.insert(bundleId, at: 0)
    }
    
    /// Remove bundle ID from access order tracking
    private func removeFromAccessOrder(_ bundleId: String) {
        accessOrder.removeAll { $0 == bundleId }
    }
    
    /// Evict the least recently used entry to make room
    private func evictLeastRecentlyUsed() async {
        guard !accessOrder.isEmpty else {
            // Fallback: remove arbitrary entry if access order is somehow empty
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
            return
        }
        
        // Remove least recently used entry
        let lruBundleId = accessOrder.removeLast()
        cache.removeValue(forKey: lruBundleId)
    }
    
    /// Reset performance statistics (useful for testing)
    public func resetStatistics() async {
        hitCount = 0
        missCount = 0
        expiredCount = 0
    }
    
    /// Get basic cache information for debugging
    public func getCacheInfo() async -> CacheInfo {
        var entryDetails: [String: EntryInfo] = [:]
        for (bundleId, hierarchy) in cache {
            entryDetails[bundleId] = EntryInfo(
                application: hierarchy.application,
                totalItems: hierarchy.totalItems,
                exploredDepth: hierarchy.exploredDepth,
                generatedAt: hierarchy.generatedAt,
                expiresAt: hierarchy.cacheExpiresAt,
                isValid: hierarchy.isValid,
                topLevelMenus: hierarchy.topLevelMenus
            )
        }
        
        return CacheInfo(
            entryCount: cache.count,
            maxCacheSize: maxCacheSize,
            defaultTimeout: defaultTimeout,
            accessOrder: accessOrder,
            entries: entryDetails
        )
    }
}

/// Sendable structure for cache information
public struct CacheInfo: Sendable {
    public let entryCount: Int
    public let maxCacheSize: Int
    public let defaultTimeout: TimeInterval
    public let accessOrder: [String]
    public let entries: [String: EntryInfo]
}

/// Sendable structure for individual cache entry information
public struct EntryInfo: Sendable {
    public let application: String
    public let totalItems: Int
    public let exploredDepth: Int
    public let generatedAt: Date
    public let expiresAt: Date
    public let isValid: Bool
    public let topLevelMenus: [String]
}