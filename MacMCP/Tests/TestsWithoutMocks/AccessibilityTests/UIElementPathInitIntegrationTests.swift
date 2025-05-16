// ABOUTME: This file contains integration tests for UIElement initialization from ElementPaths
// ABOUTME: It validates that UIElements can be correctly created from paths in real applications

import XCTest
import Testing
import Foundation
import Logging
@preconcurrency import AppKit
@preconcurrency import ApplicationServices

@testable @preconcurrency import MacMCP
@testable @preconcurrency import TestsWithoutMocks

@Suite(.serialized)
struct UIElementPathInitIntegrationTests {
    
    @Test("Initialize UIElement from simple Calculator path")
    func testInitFromSimplePath() async throws {
        // This test creates a UIElement from a simple path in Calculator
        
        // Create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create a simple path to the Calculator window
        let windowPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        
        // Create a UIElement from the path
        let windowElement = try await UIElement(fromPath: windowPath, accessibilityService: accessibilityService)
        
        // Verify properties of the created UIElement
        #expect(windowElement.role == "AXWindow")
        #expect(windowElement.title == "Calculator")
        #expect(windowElement.path == windowPath)
        #expect(windowElement.axElement != nil)
        
        // Cleanup - close calculator
        try await calculator.terminate()
        
        // Ensure all Calculator processes are terminated
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").first {
            app.terminate()
        }
        
        // Give time for the app to fully terminate
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @Test("Initialize UIElement from complex Calculator path with multiple attributes")
    func testInitFromComplexPath() async throws {
        // This test creates a UIElement from a complex path with multiple attributes
        
        // Create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create a complex path to a button in Calculator
        // The exact path structure might need adjustment based on the macOS version
        let buttonPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
        
        // Create a UIElement from the path
        let buttonElement = try await UIElement(fromPath: buttonPath, accessibilityService: accessibilityService)
        
        // Verify properties of the created UIElement
        #expect(buttonElement.role == "AXButton")
        #expect(buttonElement.elementDescription == "1")
        #expect(buttonElement.path == buttonPath)
        #expect(buttonElement.axElement != nil)
        #expect(buttonElement.isClickable == true)
        
        // Cleanup - close calculator
        try await calculator.terminate()
        
        // Ensure all Calculator processes are terminated
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").first {
            app.terminate()
        }
        
        // Give time for the app to fully terminate
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @Test("Compare two paths resolving to the same element")
    func testSameElementComparison() async throws {
        // This test verifies that two different paths to the same element are properly compared
        
        // Create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create two different paths to the same window
        let path1 = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        let path2 = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[0]"
        
        // Compare the paths
        let areSame = try await UIElement.areSameElement(path1: path1, path2: path2, accessibilityService: accessibilityService)
        
        // Verify the paths resolve to the same element
        #expect(areSame == true)
        
        // Cleanup - close calculator
        try await calculator.terminate()
        
        // Ensure all Calculator processes are terminated
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").first {
            app.terminate()
        }
        
        // Give time for the app to fully terminate
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @Test("Compare two paths resolving to different elements")
    func testDifferentElementComparison() async throws {
        // This test verifies that paths to different elements are correctly identified as different
        
        // Create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create paths to different elements
        let windowPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        let buttonPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
        
        // Compare the paths
        let areSame = try await UIElement.areSameElement(path1: windowPath, path2: buttonPath, accessibilityService: accessibilityService)
        
        // Verify the paths resolve to different elements
        #expect(areSame == false)
        
        // Cleanup - close calculator
        try await calculator.terminate()
        
        // Ensure all Calculator processes are terminated
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").first {
            app.terminate()
        }
        
        // Give time for the app to fully terminate
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    @Test("Handle error when initializing from invalid path")
    func testInitFromInvalidPath() async throws {
        // This test verifies proper error handling when initializing from an invalid path
        
        // Create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create an invalid path
        let invalidPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXNonExistentElement"
        
        // Attempt to create a UIElement (should throw)
        do {
            let _ = try await UIElement(fromPath: invalidPath, accessibilityService: accessibilityService)
            XCTFail("Expected an error but none was thrown")
        } catch let error as ElementPathError {
            // Verify we got an appropriate error
            switch error {
            case .noMatchingElements, .segmentResolutionFailed:
                // These are the expected error types
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Cleanup - close calculator
        try await calculator.terminate()
        
        // Ensure all Calculator processes are terminated
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator").first {
            app.terminate()
        }
        
        // Give time for the app to fully terminate
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// Helper class for managing the Calculator app during tests
fileprivate class CalculatorApp {
    let bundleIdentifier = "com.apple.calculator"
    let accessibilityService: AccessibilityService
    
    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
    }
    
    func launch() async throws {
        // Check if the app is already running
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        if let app = runningApps.first, app.isTerminated == false {
            // App is already running, just activate it
            app.activate()
        } else {
            // Launch the app
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            guard let appURL = url else {
                throw NSError(domain: "com.macos.mcp.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calculator app not found"])
            }
            
            try NSWorkspace.shared.launchApplication(at: appURL, configuration: [:])
        }
        
        // Wait for the app to become fully active
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    func terminate() async throws {
        // Find the running app
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        if let app = runningApps.first, app.isTerminated == false {
            // Terminate the app
            app.terminate()
        }
    }
}