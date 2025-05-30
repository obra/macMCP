// ABOUTME: MenusResourceE2ETests.swift
// ABOUTME: End-to-end tests for menu resources functionality using real macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct MenusResourceE2ETests {
  // The TextEdit bundle ID (using TextEdit because it has standard menus)
  private let textEditBundleId = "com.apple.TextEdit"
  /// Ensure TextEdit is running and ready for tests
  @MainActor private func setUp() async throws {
    let helper = TextEditTestHelper.shared()
    let isRunning = try await helper.ensureAppIsRunning()
    #expect(isRunning, "TextEdit should be running for menu tests")
  }

  /// Reset TextEdit state after tests
  @MainActor private func tearDown() async {
    let helper = TextEditTestHelper.shared()
    try? await helper.resetAppState()
  }

  @Test("Test application menus resource shows TextEdit menus") func applicationMenusResource()
    async throws
  {
    try await setUp()
    // Get shared helper and create handler
    let helper = await TextEditTestHelper.shared()
    let menuNavigationService = helper.toolChain.menuNavigationService
    let logger = Logger(label: "test.menus")
    let handler = ApplicationMenusResourceHandler(
      menuNavigationService: menuNavigationService, logger: logger,
    )
    // Create the resource URI
    let resourceURI = "macos://applications/\(textEditBundleId)/menus"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/\(textEditBundleId)/menus",
      queryParameters: [:],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { menus in
        #expect(!menus.isEmpty, "Should have at least one menu")
        
        // Verify basic menu structure
        let menuTitles = menus.compactMap { $0["title"] as? String }
        #expect(menuTitles.contains("File"), "Response should include File menu")
        #expect(menuTitles.contains("Edit"), "Response should include Edit menu")
        #expect(menuTitles.contains("Format"), "Response should include Format menu")
      }
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
      // Verify menu count in metadata
      if let menuCountValue = metadata?.additionalMetadata?["menuCount"] {
        if case .int(let count) = menuCountValue {
          #expect(count > 0, "Menu count should be greater than 0")
        }
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    await tearDown()
  }

  @Test("Test specific menu items resource for TextEdit File menu")
  func specificMenuItemsResource() async throws {
    try await setUp()
    // Get shared helper and create handler
    let helper = await TextEditTestHelper.shared()
    let menuNavigationService = helper.toolChain.menuNavigationService
    let logger = Logger(label: "test.menus")
    let handler = ApplicationMenusResourceHandler(
      menuNavigationService: menuNavigationService, logger: logger,
    )
    // Create the resource URI with query param for specific menu
    let resourceURI = "macos://applications/\(textEditBundleId)/menus"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/\(textEditBundleId)/menus",
      queryParameters: ["menuTitle": "File"],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { menuItems in
        #expect(!menuItems.isEmpty, "Should have File menu items")
        
        // Verify File menu items
        let itemTitles = menuItems.compactMap { $0["title"] as? String }
        #expect(itemTitles.contains("New"), "Response should include New item")
        #expect(itemTitles.contains("Open"), "Response should include Open item")
        #expect(itemTitles.contains("Save"), "Response should include Save item")
      }
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      if let metadata {
        #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
        // Check the menu title in metadata
        if let menuTitleValue = metadata.additionalMetadata?["menuTitle"] {
          if case .string(let menuTitle) = menuTitleValue {
            #expect(menuTitle == "File", "Menu title should be File")
          }
        }
        // Verify item count
        if let itemCountValue = metadata.additionalMetadata?["itemCount"] {
          if case .int(let count) = itemCountValue {
            #expect(count > 0, "Item count should be greater than 0")
          }
        }
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    await tearDown()
  }

  @Test("Test menu items with submenus included") func menuItemsWithSubmenus() async throws {
    try await setUp()
    // Get shared helper and create handler
    let helper = await TextEditTestHelper.shared()
    let menuNavigationService = helper.toolChain.menuNavigationService
    let logger = Logger(label: "test.menus")
    let handler = ApplicationMenusResourceHandler(
      menuNavigationService: menuNavigationService, logger: logger,
    )
    // Create the resource URI with query params for specific menu and include submenus
    let resourceURI = "macos://applications/\(textEditBundleId)/menus"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/\(textEditBundleId)/menus",
      queryParameters: ["menuTitle": "Format", "includeSubmenus": "true"],
    )
    // Call the handler directly
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Verify the content
    if case .text(let jsonString) = content {
      try JSONTestUtilities.testJSONArray(jsonString) { formatMenuItems in
        #expect(!formatMenuItems.isEmpty, "Should have Format menu items")
        
        // Format menu typically has Font submenu
        let itemTitles = formatMenuItems.compactMap { $0["title"] as? String }
        #expect(itemTitles.contains("Font"), "Response should include Font item")
        
        // Since we requested includeSubmenus=true, we should see Font submenu items
        let hasSubmenuItems = formatMenuItems.contains { item in
          item["submenuItems"] != nil
        }
        #expect(hasSubmenuItems, "Response should include submenu items")
        
        // Look for common Font submenu items in any submenu
        var foundFontItem = false
        for item in formatMenuItems {
          if let submenuItems = item["submenuItems"] as? [[String: Any]] {
            let submenuTitles = submenuItems.compactMap { $0["title"] as? String }
            if submenuTitles.contains("Bold") || submenuTitles.contains("Italic") {
              foundFontItem = true
              break
            }
          }
        }
        #expect(foundFontItem, "Response should include Font submenu items like Bold or Italic")
      }
      // Verify metadata
      #expect(metadata != nil, "Metadata should be provided")
      if let metadata {
        #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
        // Check the menu title in metadata
        if let menuTitleValue = metadata.additionalMetadata?["menuTitle"] {
          if case .string(let menuTitle) = menuTitleValue {
            #expect(menuTitle == "Format", "Menu title should be Format")
          }
        }
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    await tearDown()
  }
}
