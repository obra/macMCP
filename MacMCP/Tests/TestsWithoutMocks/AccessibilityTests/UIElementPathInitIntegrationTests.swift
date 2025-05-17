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
        let windowPath = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        
        // Create a UIElement from the path
        let windowElement = try await UIElement(fromPath: windowPath, accessibilityService: accessibilityService)
        
        // Verify properties of the created UIElement
        #expect(windowElement.role == "AXWindow")
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
        // Use the same format to match the output of the element initializer's toString() method
        let buttonPath = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
        
        // Get diagnostics on the path before attempting resolution
        print("\n==== PATH DIAGNOSTICS ====")
        print("Attempting to diagnose path resolution for: \(buttonPath)")
        let diagnosis = try await ElementPath.diagnosePathResolutionIssue(buttonPath, using: accessibilityService)
        print(diagnosis)
        print("==== END PATH DIAGNOSTICS ====\n")
        
        // Create a UIElement from the path
        let buttonElement = try await UIElement(fromPath: buttonPath, accessibilityService: accessibilityService)
        
        // Print extensive debug information about the button and resolution process
        print("\n==== BUTTON RESOLUTION DEBUG ====")
        print("1. Input path: \(buttonPath)")
        
        // Check if the AXUIElement is a valid reference
        if let axElement = buttonElement.axElement {
            print("2. AXUIElement resolved: YES (valid reference)")
            
            // Print AXUIElement memory address to verify it's a real object
            print("   - AXUIElement memory address: \(Unmanaged.passUnretained(axElement).toOpaque())")
            
            // Try to get the PID of the element (should be Calculator's PID)
            var pid: pid_t = 0
            let pidStatus = AXUIElementGetPid(axElement, &pid)
            print("   - AXUIElement PID status: \(pidStatus), PID: \(pid)")
            
            // Try to get role directly from AXUIElement (double-check)
            var roleRef: CFTypeRef?
            let roleStatus = AXUIElementCopyAttributeValue(axElement, AXAttribute.role as CFString, &roleRef)
            print("   - Direct role check status: \(roleStatus), Value: \(roleRef as? String ?? "nil")")
            
            // Try to get description directly from AXUIElement (double-check)
            var descRef: CFTypeRef?
            let descStatus = AXUIElementCopyAttributeValue(axElement, AXAttribute.description as CFString, &descRef)
            print("   - Direct description check status: \(descStatus), Value: \(descRef as? String ?? "nil")")
            
            // Try to get actions directly from AXUIElement
            var actionsArrayRef: CFTypeRef?
            let actionsStatus = AXUIElementCopyAttributeValue(axElement, AXAttribute.actions as CFString, &actionsArrayRef)
            if actionsStatus == .success, let actionsArray = actionsArrayRef as? [String] {
                print("   - Direct actions check status: \(actionsStatus), Actions: \(actionsArray)")
            } else {
                print("   - Direct actions check status: \(actionsStatus), Actions: nil")
            }
        } else {
            print("2. AXUIElement resolved: NO (nil reference) - This indicates the path did not resolve to a real UI element")
        }
        
        // Print all the UIElement properties
        print("3. UIElement properties:")
        print("   - Role: \(buttonElement.role)")
        print("   - Description: \(buttonElement.elementDescription ?? "nil")")
        print("   - Title: \(buttonElement.title ?? "nil")")
        print("   - Value: \(buttonElement.value ?? "nil")")
        print("   - Identifier: \(buttonElement.identifier)")
        print("   - Frame: \(buttonElement.frame)")
        print("   - Path: \(buttonElement.path ?? "nil")")
        print("   - Actions array (count: \(buttonElement.actions.count)): \(buttonElement.actions)")
        print("   - Attributes: \(buttonElement.attributes)")
        print("   - isClickable: \(buttonElement.isClickable)")
        print("==== END DEBUG ====\n")
        
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
        let path1 = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        let path2 = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[0]"
        
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
        let windowPath = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
        let buttonPath = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
        
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
        let invalidPath = "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXNonExistentElement"
        
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
