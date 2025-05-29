// ABOUTME: Unit tests for MenuCacheService actor implementation
// ABOUTME: Tests TTL expiry, LRU eviction, and cache performance metrics

import Foundation
import Testing

@testable import MacMCP

@Suite("MenuCacheService Tests", .serialized) struct MenuCacheServiceTests {
  @Test("MenuCacheService stores and retrieves hierarchies") func storeAndRetrieve()
    async throws
  {
    let cache = MenuCacheService()
    let hierarchy = createTestHierarchy(bundleId: "com.test.app1")
    // Store hierarchy
    await cache.setHierarchy(hierarchy, for: "com.test.app1")
    // Retrieve hierarchy
    let retrieved = await cache.getHierarchy(for: "com.test.app1")
    #expect(retrieved != nil)
    #expect(retrieved?.application == "com.test.app1")
    #expect(retrieved?.totalItems == hierarchy.totalItems)
  }

  @Test("MenuCacheService returns nil for non-existent entries") func missingEntry()
    async throws
  {
    let cache = MenuCacheService()
    let result = await cache.getHierarchy(for: "com.nonexistent.app")
    #expect(result == nil)
  }

  @Test("MenuCacheService respects TTL expiration") func tTLExpiration() async throws {
    let cache = MenuCacheService()
    // Create hierarchy with short timeout
    let hierarchy = MenuHierarchy(
      application: "com.test.app",
      menus: ["File": ["File > New"]],
      totalItems: 1,
      exploredDepth: 1,
      cacheTimeout: 0.5,
    )
    await cache.setHierarchy(hierarchy, for: "com.test.app")
    // Should be available immediately
    let immediate = await cache.getHierarchy(for: "com.test.app")
    #expect(immediate != nil)
    // Wait for expiration
    try await Task.sleep(for: .seconds(0.6))
    // Should be expired and return nil
    let expired = await cache.getHierarchy(for: "com.test.app")
    #expect(expired == nil)
  }

  @Test("MenuCacheService tracks hit and miss statistics") func statistics() async throws {
    let cache = MenuCacheService()
    await cache.resetStatistics()
    let hierarchy = createTestHierarchy(bundleId: "com.test.app")
    await cache.setHierarchy(hierarchy, for: "com.test.app")
    // Miss case
    _ = await cache.getHierarchy(for: "com.nonexistent.app")
    // Hit case
    _ = await cache.getHierarchy(for: "com.test.app")
    _ = await cache.getHierarchy(for: "com.test.app")
    let stats = await cache.getStatistics()
    #expect(stats.hitCount == 2)
    #expect(stats.missCount == 1)
    #expect(abs(stats.hitRate - (2.0 / 3.0)) < 0.001) // Should be ~0.667
  }

  @Test("MenuCacheService invalidates specific entries") func invalidateSpecific() async throws {
    let cache = MenuCacheService()
    let hierarchy1 = createTestHierarchy(bundleId: "com.test.app1")
    let hierarchy2 = createTestHierarchy(bundleId: "com.test.app2")
    await cache.setHierarchy(hierarchy1, for: "com.test.app1")
    await cache.setHierarchy(hierarchy2, for: "com.test.app2")
    // Both should exist
    #expect(await cache.getHierarchy(for: "com.test.app1") != nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") != nil)
    // Invalidate one
    await cache.invalidate(for: "com.test.app1")
    // Only app1 should be gone
    #expect(await cache.getHierarchy(for: "com.test.app1") == nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") != nil)
  }

  @Test("MenuCacheService invalidates all entries") func testInvalidateAll() async throws {
    let cache = MenuCacheService()
    let hierarchy1 = createTestHierarchy(bundleId: "com.test.app1")
    let hierarchy2 = createTestHierarchy(bundleId: "com.test.app2")
    await cache.setHierarchy(hierarchy1, for: "com.test.app1")
    await cache.setHierarchy(hierarchy2, for: "com.test.app2")
    // Both should exist
    #expect(await cache.getHierarchy(for: "com.test.app1") != nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") != nil)
    // Invalidate all
    await cache.invalidateAll()
    // Statistics should be reset immediately after invalidateAll
    let stats = await cache.getStatistics()
    #expect(stats.hitCount == 0)
    #expect(stats.missCount == 0)
    // Both should be gone (these calls will increment miss count, but that's expected)
    #expect(await cache.getHierarchy(for: "com.test.app1") == nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") == nil)
  }

  @Test("MenuCacheService performs cleanup of expired entries") func testCleanup() async throws {
    let cache = MenuCacheService()
    await cache.resetStatistics()
    // Create hierarchy with short timeout
    let shortTimeout = MenuHierarchy(
      application: "com.test.short",
      menus: ["File": ["File > New"]],
      totalItems: 1,
      exploredDepth: 1,
      cacheTimeout: 0.5,
    )
    // Create hierarchy with long timeout
    let longTimeout = createTestHierarchy(bundleId: "com.test.long")
    await cache.setHierarchy(shortTimeout, for: "com.test.short")
    await cache.setHierarchy(longTimeout, for: "com.test.long")
    // Wait for short timeout to expire
    try await Task.sleep(for: .seconds(0.6))
    // Run cleanup
    await cache.cleanup()
    // Short timeout should be gone, long timeout should remain
    #expect(await cache.getHierarchy(for: "com.test.short") == nil)
    #expect(await cache.getHierarchy(for: "com.test.long") != nil)
    // Statistics should show expired entry
    let stats = await cache.getStatistics()
    #expect(stats.expiredCount >= 1)
  }

  @Test("MenuCacheService enforces maximum cache size with LRU") func lRUEviction() async throws {
    // Create cache with small max size
    let cache = MenuCacheService(maxCacheSize: 3)
    // Fill cache to capacity
    for i in 1 ... 3 {
      let hierarchy = createTestHierarchy(bundleId: "com.test.app\(i)")
      await cache.setHierarchy(hierarchy, for: "com.test.app\(i)")
    }
    // Access app1 to make it most recently used
    _ = await cache.getHierarchy(for: "com.test.app1")
    // Add one more entry (should evict least recently used)
    let newHierarchy = createTestHierarchy(bundleId: "com.test.app4")
    await cache.setHierarchy(newHierarchy, for: "com.test.app4")
    // app2 should be evicted (least recently used)
    // app1, app3, app4 should remain
    #expect(await cache.getHierarchy(for: "com.test.app1") != nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") == nil)
    #expect(await cache.getHierarchy(for: "com.test.app3") != nil)
    #expect(await cache.getHierarchy(for: "com.test.app4") != nil)
  }

  @Test("MenuCacheService updates LRU order on access") func lRUOrderUpdate() async throws {
    let cache = MenuCacheService(maxCacheSize: 2)
    let hierarchy1 = createTestHierarchy(bundleId: "com.test.app1")
    let hierarchy2 = createTestHierarchy(bundleId: "com.test.app2")
    await cache.setHierarchy(hierarchy1, for: "com.test.app1")
    await cache.setHierarchy(hierarchy2, for: "com.test.app2")
    // Access app1 to make it most recently used
    _ = await cache.getHierarchy(for: "com.test.app1")
    // Add app3 (should evict app2, not app1)
    let hierarchy3 = createTestHierarchy(bundleId: "com.test.app3")
    await cache.setHierarchy(hierarchy3, for: "com.test.app3")
    #expect(await cache.getHierarchy(for: "com.test.app1") != nil)
    #expect(await cache.getHierarchy(for: "com.test.app2") == nil)
    #expect(await cache.getHierarchy(for: "com.test.app3") != nil)
  }

  @Test("MenuCacheService provides detailed cache info") func cacheInfo() async throws {
    let cache = MenuCacheService(maxCacheSize: 10, defaultTimeout: 600)
    let hierarchy = createTestHierarchy(bundleId: "com.test.app")
    await cache.setHierarchy(hierarchy, for: "com.test.app")
    let info = await cache.getCacheInfo()
    #expect(info.entryCount == 1)
    #expect(info.maxCacheSize == 10)
    #expect(info.defaultTimeout == 600)
    #expect(info.accessOrder.contains("com.test.app"))
    #expect(info.entries["com.test.app"] != nil)
    #expect(info.entries["com.test.app"]?.application == "com.test.app")
  }

  // MARK: - Helper Methods

  private func createTestHierarchy(bundleId: String, timeout: TimeInterval = 300) -> MenuHierarchy {
    let menus = ["File": ["File > New", "File > Save"], "Edit": ["Edit > Copy", "Edit > Paste"]]
    return MenuHierarchy(
      application: bundleId,
      menus: menus,
      totalItems: 4,
      exploredDepth: 2,
      cacheTimeout: timeout,
    )
  }
}
