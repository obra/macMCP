// ABOUTME: MenusResourceE2ETests.swift
// ABOUTME: End-to-end tests for menu resources functionality using real macOS applications.

import Foundation
import Testing
import AppKit
import Logging
import MCP
@testable import MacMCP

@Suite(.serialized)
struct MenusResourceE2ETests {
    // Test components
    private var toolChain: ToolChain!
    private var textEditApp: TextEditModel!
    
    // The TextEdit bundle ID (using TextEdit because it has standard menus)
    private let textEditBundleId = "com.apple.TextEdit"
    
    // Setup method
    private mutating func setUp() async throws {
        // Create tool chain
        toolChain = ToolChain()
        
        // Create TextEdit app model
        textEditApp = TextEditModel(toolChain: toolChain)
        
        // Terminate any existing TextEdit instances
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId)
        for runningApp in runningApps {
            _ = runningApp.terminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
        
        // Launch TextEdit
        _ = try await textEditApp.launch(hideOthers: false)
        
        // Wait for TextEdit to be ready
        try await Task.sleep(for: .milliseconds(2000))
    }
    
    // Teardown method
    private mutating func tearDown() async throws {
        // Terminate the TextEdit application
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: textEditBundleId)
        for runningApp in runningApps {
            _ = runningApp.terminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    @Test("Test application menus resource shows TextEdit menus")
    mutating func testApplicationMenusResource() async throws {
        try await setUp()
        
        // Create an ApplicationMenusResourceHandler
        let menuNavigationService = toolChain.menuNavigationService
        let logger = Logger(label: "test.menus")
        let handler = ApplicationMenusResourceHandler(menuNavigationService: menuNavigationService, logger: logger)
        
        // Create the resource URI
        let resourceURI = "macos://applications/\(textEditBundleId)/menus"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/menus",
            queryParameters: [:]
        )
        
        // Call the handler directly
        let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify the content
        if case let .text(jsonString) = content {
            // Verify basic menu structure
            #expect(jsonString.contains("File"), "Response should include File menu")
            #expect(jsonString.contains("Edit"), "Response should include Edit menu")
            #expect(jsonString.contains("Format"), "Response should include Format menu")
            
            // Verify metadata
            #expect(metadata != nil, "Metadata should be provided")
            #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
            
            // Verify menu count in metadata
            if let menuCountValue = metadata?.additionalMetadata?["menuCount"] {
                if case let .int(count) = menuCountValue {
                    #expect(count > 0, "Menu count should be greater than 0")
                }
            }
        } else {
            #expect(false, "Content should be text")
        }
        
        try await tearDown()
    }
    
    @Test("Test specific menu items resource for TextEdit File menu")
    mutating func testSpecificMenuItemsResource() async throws {
        try await setUp()
        
        // Create an ApplicationMenusResourceHandler
        let menuNavigationService = toolChain.menuNavigationService
        let logger = Logger(label: "test.menus")
        let handler = ApplicationMenusResourceHandler(menuNavigationService: menuNavigationService, logger: logger)
        
        // Create the resource URI with query param for specific menu
        let resourceURI = "macos://applications/\(textEditBundleId)/menus"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/menus",
            queryParameters: ["menuTitle": "File"]
        )
        
        // Call the handler directly
        let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify the content
        if case let .text(jsonString) = content {
            // Verify File menu items
            #expect(jsonString.contains("New"), "Response should include New item")
            #expect(jsonString.contains("Open"), "Response should include Open item")
            #expect(jsonString.contains("Save"), "Response should include Save item")
            
            // Verify metadata
            #expect(metadata != nil, "Metadata should be provided")
            if let metadata = metadata {
                #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
                
                // Check the menu title in metadata
                if let menuTitleValue = metadata.additionalMetadata?["menuTitle"] {
                    if case let .string(menuTitle) = menuTitleValue {
                        #expect(menuTitle == "File", "Menu title should be File")
                    }
                }
                
                // Verify item count
                if let itemCountValue = metadata.additionalMetadata?["itemCount"] {
                    if case let .int(count) = itemCountValue {
                        #expect(count > 0, "Item count should be greater than 0")
                    }
                }
            }
        } else {
            #expect(false, "Content should be text")
        }
        
        try await tearDown()
    }
    
    @Test("Test menu items with submenus included")
    mutating func testMenuItemsWithSubmenus() async throws {
        try await setUp()
        
        // Create an ApplicationMenusResourceHandler
        let menuNavigationService = toolChain.menuNavigationService
        let logger = Logger(label: "test.menus")
        let handler = ApplicationMenusResourceHandler(menuNavigationService: menuNavigationService, logger: logger)
        
        // Create the resource URI with query params for specific menu and include submenus
        let resourceURI = "macos://applications/\(textEditBundleId)/menus"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/menus",
            queryParameters: ["menuTitle": "Format", "includeSubmenus": "true"]
        )
        
        // Call the handler directly
        let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify the content
        if case let .text(jsonString) = content {
            // Format menu typically has Font submenu
            #expect(jsonString.contains("Font"), "Response should include Font item")
            
            // Since we requested includeSubmenus=true, we should see Font submenu items
            #expect(jsonString.contains("submenuItems"), "Response should include submenu items")
            
            // Look for common Font submenu items
            #expect(jsonString.contains("Bold") || jsonString.contains("Italic"), 
                   "Response should include Font submenu items like Bold or Italic")
            
            // Verify metadata
            #expect(metadata != nil, "Metadata should be provided")
            if let metadata = metadata {
                #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
                
                // Check the menu title in metadata
                if let menuTitleValue = metadata.additionalMetadata?["menuTitle"] {
                    if case let .string(menuTitle) = menuTitleValue {
                        #expect(menuTitle == "Format", "Menu title should be Format")
                    }
                }
            }
        } else {
            #expect(false, "Content should be text")
        }
        
        try await tearDown()
    }
}