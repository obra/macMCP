// ABOUTME: WindowsResourceE2ETests.swift
// ABOUTME: End-to-end tests for window resources functionality using real macOS applications.

import Foundation
import Testing
import AppKit
import Logging
import MCP
@testable import MacMCP

@Suite(.serialized)
struct WindowsResourceE2ETests {
    // Test components
    private var toolChain: ToolChain!
    private var textEditApp: TextEditModel!
    
    // The TextEdit bundle ID (using TextEdit because it has standard windows)
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
        
        // Launch TextEdit with a new document
        _ = try await textEditApp.launch(hideOthers: false)
        
        // Wait for TextEdit to be ready
        try await Task.sleep(for: .milliseconds(3000))
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
    
    @Test("Test application windows resource lists TextEdit windows")
    mutating func testApplicationWindowsResource() async throws {
        try await setUp()
        
        // Create an ApplicationWindowsResourceHandler
        let accessibilityService = toolChain.accessibilityService
        let logger = Logger(label: "test.windows")
        let handler = ApplicationWindowsResourceHandler(accessibilityService: accessibilityService, logger: logger)
        
        // Create the resource URI - must match the handler's pattern "macos://applications/{bundleId}/windows"
        let resourceURI = "macos://applications/\(textEditBundleId)/windows"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/windows",
            queryParameters: [:]
        )
        
        // Call the handler directly
        let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify the content
        if case let .text(jsonString) = content {
            // Verify basic window properties
            #expect(jsonString.contains("\"id\""), "Response should include window ID")
            #expect(jsonString.contains("\"title\""), "Response should include window title")
            #expect(jsonString.contains("\"frame\""), "Response should include window frame")
            #expect(jsonString.contains("\"isMain\""), "Response should include main window flag")
            
            // TextEdit should have at least one window
            #expect(jsonString.contains("Untitled") || jsonString.contains("TextEdit"), 
                   "Response should include TextEdit window title")
            
            // Verify metadata
            #expect(metadata != nil, "Metadata should be provided")
            #expect(metadata?.mimeType == "application/json", "MIME type should be application/json")
            
            // Verify window count in metadata
            if let windowCountValue = metadata?.additionalMetadata?["windowCount"] {
                if case let .int(count) = windowCountValue {
                    #expect(count > 0, "Window count should be greater than 0")
                }
            }
        } else {
            #expect(false, "Content should be text")
        }
        
        try await tearDown()
    }
    
    @Test("Test application windows resource includes window state")
    mutating func testWindowStateInformation() async throws {
        try await setUp()
        
        // Create an ApplicationWindowsResourceHandler
        let accessibilityService = toolChain.accessibilityService
        let logger = Logger(label: "test.windows")
        let handler = ApplicationWindowsResourceHandler(accessibilityService: accessibilityService, logger: logger)
        
        // Create the resource URI
        let resourceURI = "macos://applications/\(textEditBundleId)/windows"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/windows",
            queryParameters: [:]
        )
        
        // Call the handler directly
        let (content, _) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify the content
        if case let .text(jsonString) = content {
            // Parse the JSON string to an array
            guard let jsonData = jsonString.data(using: .utf8) else {
                #expect(Bool(false), "Could not convert JSON string to data")
                return
            }
            
            do {
                // Parse the JSON array
                guard let windowsArray = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] else {
                    #expect(Bool(false), "JSON is not an array of objects")
                    return
                }
                
                // Check basic structural properties
                #expect(windowsArray.count > 0, "Should have at least one window")
                
                // Check that the first window has all the required state properties
                if let firstWindow = windowsArray.first {
                    #expect(firstWindow["isMinimized"] != nil, "Window should have minimized state")
                    #expect(firstWindow["isVisible"] != nil, "Window should have visibility state") 
                    #expect(firstWindow["isMain"] != nil, "Window should have main window state")
                }
                
                // Check for a window that isn't minimized (at least one window should not be minimized)
                let hasNonMinimizedWindow = windowsArray.contains { window in
                    window["isMinimized"] as? Bool == false
                }
                #expect(hasNonMinimizedWindow, "There should be at least one non-minimized window")
                
                // Check for a visible window (at least one window should be visible)
                let hasVisibleWindow = windowsArray.contains { window in
                    window["isVisible"] as? Bool == true
                }
                #expect(hasVisibleWindow, "There should be at least one visible window")
                
            } catch {
                #expect(Bool(false), "Failed to parse JSON: \(error.localizedDescription)")
            }
        } else {
            #expect(Bool(false), "Content should be text")
        }
        
        try await tearDown()
    }
    
    @Test("Test application windows resource with includeMinimized parameter")
    mutating func testWindowsWithIncludeMinimized() async throws {
        try await setUp()
        
        // Create a second TextEdit window
        _ = try await textEditApp.createNewDocument()
        try await Task.sleep(for: .milliseconds(2000))
        
        // Create an ApplicationWindowsResourceHandler
        let accessibilityService = toolChain.accessibilityService
        let logger = Logger(label: "test.windows")
        let handler = ApplicationWindowsResourceHandler(accessibilityService: accessibilityService, logger: logger)
        
        // First get the windows (should have at least two)
        let resourceURI = "macos://applications/\(textEditBundleId)/windows"
        let components = ResourceURIComponents(
            scheme: "macos",
            path: "/applications/\(textEditBundleId)/windows",
            queryParameters: [:]
        )
        
        let (initialContent, _) = try await handler.handleRead(uri: resourceURI, components: components)
        
        // Verify we have at least one window
        if case let .text(jsonString) = initialContent {
            // Count window entries by counting "id" occurrences
            let windowCount = jsonString.components(separatedBy: "\"id\"").count - 1
            #expect(windowCount >= 1, "Should have at least one window")
            
            // Use the Window Management Tool to minimize the first window if possible
            if windowCount >= 1 {
                // Try to minimize one window using the toolChain
                let minimizeParams: [String: Value] = [
                    "action": .string("minimizeWindow"),
                    "bundleId": .string(textEditBundleId),
                    "windowIndex": .int(0)  // First window
                ]
                
                _ = try? await toolChain.windowManagementTool.handler(minimizeParams)
                try await Task.sleep(for: .milliseconds(2000))
                
                // Now test with includeMinimized parameter
                
                // First get windows without including minimized (default)
                let (contentWithoutMinimized, metadataWithoutMinimized) = try await handler.handleRead(
                    uri: resourceURI,
                    components: components
                )
                
                // Then get windows with includeMinimized=true
                let componentsWithMinimized = ResourceURIComponents(
                    scheme: "macos",
                    path: "/applications/\(textEditBundleId)/windows",
                    queryParameters: ["includeMinimized": "true"]
                )
                
                let (contentWithMinimized, metadataWithMinimized) = try await handler.handleRead(
                    uri: resourceURI,
                    components: componentsWithMinimized
                )
                
                // Compare results
                if case let .text(jsonWithoutMinimized) = contentWithoutMinimized,
                   case let .text(jsonWithMinimized) = contentWithMinimized {
                    
                    // Count windows in each response
                    let countWithoutMinimized = jsonWithoutMinimized.components(separatedBy: "\"id\"").count - 1
                    let countWithMinimized = jsonWithMinimized.components(separatedBy: "\"id\"").count - 1
                    
                    // When includeMinimized=true, we should see the same or more windows
                    #expect(countWithMinimized >= countWithoutMinimized, 
                           "Including minimized windows should return at least as many windows")
                    
                    // Also check metadata counts if available
                    if let countWithoutValue = metadataWithoutMinimized?.additionalMetadata?["windowCount"],
                       let countWithValue = metadataWithMinimized?.additionalMetadata?["windowCount"],
                       case let .int(countWithout) = countWithoutValue,
                       case let .int(countWith) = countWithValue {
                        #expect(countWith >= countWithout, 
                               "Including minimized windows should show more windows in metadata")
                    }
                }
            }
        } else {
            #expect(false, "Content should be text")
        }
        
        try await tearDown()
    }
}
