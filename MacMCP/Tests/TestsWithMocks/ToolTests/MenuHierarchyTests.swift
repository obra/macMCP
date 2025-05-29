// ABOUTME: Unit tests for MenuHierarchy data structure
// ABOUTME: Tests caching behavior, serialization, and hierarchy management

import Foundation
import Testing

@testable import MacMCP

@Suite("MenuHierarchy Tests", .serialized) struct MenuHierarchyTests {
  @Test("MenuHierarchy initializes correctly") func initialization() async throws {
    let menus = ["File": ["File > New", "File > Save"], "Edit": ["Edit > Copy", "Edit > Paste"]]
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: menus, totalItems: 4, exploredDepth: 2,
    )
    #expect(hierarchy.application == "com.test.app")
    #expect(hierarchy.menus.count == 2)
    #expect(hierarchy.totalItems == 4)
    #expect(hierarchy.exploredDepth == 2)
    #expect(hierarchy.isValid) // Should be valid initially
  }

  @Test("MenuHierarchy cache expiration works correctly") func cacheExpiration() async throws {
    let menus = ["File": ["File > New"]]
    // Create hierarchy with 1 second timeout
    let hierarchy = MenuHierarchy(
      application: "com.test.app",
      menus: menus,
      totalItems: 1,
      exploredDepth: 1,
      cacheTimeout: 1.0,
    )
    #expect(hierarchy.isValid)
    // Wait for expiration
    try await Task.sleep(for: .seconds(1.1))
    #expect(!hierarchy.isValid)
  }

  @Test("allPaths returns flattened paths array") func testAllPaths() async throws {
    let menus = [
      "File": ["File > New", "File > Save", "File > Export > PDF"],
      "Edit": ["Edit > Copy", "Edit > Paste"],
    ]
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: menus, totalItems: 5, exploredDepth: 3,
    )
    let allPaths = hierarchy.allPaths
    #expect(allPaths.count == 5)
    #expect(allPaths.contains("File > New"))
    #expect(allPaths.contains("File > Save"))
    #expect(allPaths.contains("File > Export > PDF"))
    #expect(allPaths.contains("Edit > Copy"))
    #expect(allPaths.contains("Edit > Paste"))
  }

  @Test("topLevelMenus returns sorted menu names") func testTopLevelMenus() async throws {
    let menus = [
      "View": ["View > Zoom In"], "File": ["File > New"], "Edit": ["Edit > Copy"],
      "Help": ["Help > About"],
    ]
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: menus, totalItems: 4, exploredDepth: 1,
    )
    let topLevel = hierarchy.topLevelMenus
    #expect(topLevel == ["Edit", "File", "Help", "View"]) // Should be sorted
  }

  @Test("MenuHierarchy serialization works correctly") func serialization() async throws {
    let menus = ["File": ["File > New", "File > Save"], "Edit": ["Edit > Copy"]]
    let originalHierarchy = MenuHierarchy(
      application: "com.test.app",
      menus: menus,
      totalItems: 3,
      exploredDepth: 2,
    )
    // Test encoding
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(originalHierarchy)
    #expect(!data.isEmpty)
    // Test decoding
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedHierarchy = try decoder.decode(MenuHierarchy.self, from: data)
    #expect(decodedHierarchy.application == originalHierarchy.application)
    #expect(decodedHierarchy.menus.count == originalHierarchy.menus.count)
    #expect(decodedHierarchy.totalItems == originalHierarchy.totalItems)
    #expect(decodedHierarchy.exploredDepth == originalHierarchy.exploredDepth)
    // Check menu contents
    #expect(decodedHierarchy.menus["File"] == originalHierarchy.menus["File"])
    #expect(decodedHierarchy.menus["Edit"] == originalHierarchy.menus["Edit"])
  }

  @Test("MenuHierarchy handles empty menus") func emptyMenus() async throws {
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: [:], totalItems: 0, exploredDepth: 0,
    )
    #expect(hierarchy.menus.isEmpty)
    #expect(hierarchy.allPaths.isEmpty)
    #expect(hierarchy.topLevelMenus.isEmpty)
    #expect(hierarchy.totalItems == 0)
  }

  @Test("MenuHierarchy handles special characters in menu names") func specialCharacters()
    async throws
  {
    let menus = [
      "File & Documents": ["File & Documents > New Document"], "Tools…": ["Tools… > Preferences…"],
    ]
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: menus, totalItems: 2, exploredDepth: 1,
    )
    let topLevel = hierarchy.topLevelMenus
    #expect(topLevel.contains("File & Documents"))
    #expect(topLevel.contains("Tools…"))
    let allPaths = hierarchy.allPaths
    #expect(allPaths.contains("File & Documents > New Document"))
    #expect(allPaths.contains("Tools… > Preferences…"))
  }

  @Test("MenuHierarchy handles unicode characters") func unicodeCharacters() async throws {
    let menus = ["文件": ["文件 > 新建", "文件 > 保存"], "编辑": ["编辑 > 复制", "编辑 > 粘贴"]]
    let hierarchy = MenuHierarchy(
      application: "com.test.app", menus: menus, totalItems: 4, exploredDepth: 1,
    )
    #expect(hierarchy.menus.count == 2)
    #expect(hierarchy.allPaths.contains("文件 > 新建"))
    #expect(hierarchy.allPaths.contains("编辑 > 复制"))
    // Test serialization with unicode
    let encoder = JSONEncoder()
    let data = try encoder.encode(hierarchy)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(MenuHierarchy.self, from: data)
    #expect(decoded.menus["文件"] == hierarchy.menus["文件"])
    #expect(decoded.menus["编辑"] == hierarchy.menus["编辑"])
  }

  @Test("MenuHierarchy cache validation dates") func cacheValidationDates() async throws {
    let now = Date()
    let menus = ["File": ["File > New"]]
    let hierarchy = MenuHierarchy(
      application: "com.test.app",
      menus: menus,
      totalItems: 1,
      exploredDepth: 1,
      generatedAt: now,
      cacheTimeout: 300,
    )
    #expect(hierarchy.generatedAt == now)
    #expect(hierarchy.cacheExpiresAt == now.addingTimeInterval(300))
    // Test that it's valid immediately
    #expect(hierarchy.isValid)
    // Test with past generation date
    let pastDate = now.addingTimeInterval(-400)
    let expiredHierarchy = MenuHierarchy(
      application: "com.test.app",
      menus: menus,
      totalItems: 1,
      exploredDepth: 1,
      generatedAt: pastDate,
      cacheTimeout: 300,
    )
    #expect(!expiredHierarchy.isValid)
  }
}
