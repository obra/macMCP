// ABOUTME: This file contains integration tests for ElementPath resolution with real applications
// ABOUTME: It validates that paths can correctly identify and locate UI elements in macOS applications

import XCTest
import Testing
import Foundation

@testable import MacMCP

@Suite("ElementPath Integration Tests")
struct ElementPathIntegrationTests {
    
    @Test("Calculate with title-based path resolution")
    func testCalculatorTitlePathResolution() async throws {
        // This test uses the macOS Calculator app and path-based element access to perform a calculation
        // using title-based application resolution
        
        // First, create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = try await CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create paths based on the actual UI structure using title-based app resolution
        // Using paths that target each button specifically by description
        // Adding indices to solve ambiguous groups
        let button1Path = try ElementPath.parse("ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"1\"]")
        let button2Path = try ElementPath.parse("ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"2\"]")
        let plusPath = try ElementPath.parse("ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"Add\"]")
        let equalsPath = try ElementPath.parse("ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"Equals\"]")
        let displayPath = try ElementPath.parse("ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup[0]/AXGroup/AXScrollArea[@description=\"Input\"]/AXStaticText")
        
        // Show the paths in the log for debugging
        print("Using title-based element paths for Calculator UI:")
        print(" - Button 1: \(button1Path.toString())")
        print(" - Button 2: \(button2Path.toString())")
        
        // Attempt to resolve the first button to test our path resolution
        let path1UIElement = try await button1Path.resolve(using: accessibilityService)
        print("Successfully resolved Button 1 with title-based path")
        
        // Perform the calculation:
        
        // Press 1 - using the resolved element directly
        let button1Element = try await button1Path.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(button1Element, action: "AXPress")
        print("Successfully pressed Button 1")
        
        // Press + - using the resolved element directly
        let plusElement = try await plusPath.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(plusElement, action: "AXPress")
        print("Successfully pressed Plus button")
        
        // Press 2 - using the resolved element directly
        let button2Element = try await button2Path.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(button2Element, action: "AXPress")
        print("Successfully pressed Button 2")
        
        // Press = - using the resolved element directly
        let equalsElement = try await equalsPath.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(equalsElement, action: "AXPress")
        print("Successfully pressed Equals button")
        
        // Short delay to allow the calculation to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Read the result using path-based resolution
        let resultElement = try await displayPath.resolve(using: accessibilityService)
        
        var valueRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(resultElement, "AXValue" as CFString, &valueRef)
        
        if status == .success, let value = valueRef as? String {
            // Verify the result is "3"
            #expect(value == "3" || value.contains("3"))
            print("Successfully read result via title-based path resolution: \(value)")
        } else {
            XCTFail("Could not read calculator result via title-based path resolution")
        }
        
        // Cleanup - close calculator
        try await calculator.terminate()
    }
    
    @Test("Calculate with bundleId-based path resolution")
    func testCalculatorBundleIdPathResolution() async throws {
        // This test uses the macOS Calculator app and path-based element access to perform a calculation
        // using bundleIdentifier-based application resolution
        
        // First, create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = try await CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Create paths based on the actual UI structure using bundleId-based app resolution
        // Using paths that target each button specifically by description
        // Adding indices to solve ambiguous groups
        let button1Path = try ElementPath.parse("ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"1\"]")
        let button2Path = try ElementPath.parse("ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"2\"]")
        let plusPath = try ElementPath.parse("ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"Add\"]")
        let equalsPath = try ElementPath.parse("ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"Equals\"]")
        let displayPath = try ElementPath.parse("ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup[0]/AXGroup/AXScrollArea[@description=\"Input\"]/AXStaticText")
        
        // Show the paths in the log for debugging
        print("Using bundleId-based element paths for Calculator UI:")
        print(" - Button 1: \(button1Path.toString())")
        print(" - Button 2: \(button2Path.toString())")
        
        // Attempt to resolve the first button to test our path resolution
        let path1UIElement = try await button1Path.resolve(using: accessibilityService)
        print("Successfully resolved Button 1 with bundleId-based path")
        
        // Perform the calculation:
        
        // Press 1 - using the resolved element directly
        let button1Element = try await button1Path.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(button1Element, action: "AXPress")
        print("Successfully pressed Button 1")
        
        // Press + - using the resolved element directly
        let plusElement = try await plusPath.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(plusElement, action: "AXPress")
        print("Successfully pressed Plus button")
        
        // Press 2 - using the resolved element directly
        let button2Element = try await button2Path.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(button2Element, action: "AXPress")
        print("Successfully pressed Button 2")
        
        // Press = - using the resolved element directly
        let equalsElement = try await equalsPath.resolve(using: accessibilityService)
        try AccessibilityElement.performAction(equalsElement, action: "AXPress")
        print("Successfully pressed Equals button")
        
        // Short delay to allow the calculation to complete
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Read the result using path-based resolution
        let resultElement = try await displayPath.resolve(using: accessibilityService)
        
        var valueRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(resultElement, "AXValue" as CFString, &valueRef)
        
        if status == .success, let value = valueRef as? String {
            // Verify the result is "3"
            #expect(value == "3" || value.contains("3"))
            print("Successfully read result via bundleId-based path resolution: \(value)")
        } else {
            XCTFail("Could not read calculator result via bundleId-based path resolution")
        }
        
        // Cleanup - close calculator
        try await calculator.terminate()
    }
    
    @Test("Test fallback to focused application")
    func testFallbackToFocusedApp() async throws {
        // This test verifies that path resolution can fallback to the focused application
        // when no specific application attribute is provided
        
        // First, create an AccessibilityService
        let accessibilityService = AccessibilityService()
        
        try Task.checkCancellation()
        
        // Create a Calculator helper to launch the app
        let calculator = try await CalculatorApp(accessibilityService: accessibilityService)
        
        // Ensure the Calculator app is launched
        try await calculator.launch()
        
        // Delay to allow the UI to stabilize and ensure Calculator is frontmost
        try await Task.sleep(nanoseconds: 1_000_000_000)
        NSRunningApplication.runningApplications(withBundleIdentifier: calculator.bundleIdentifier).first?.activate(options: .activateIgnoringOtherApps)
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Create path using a generic application path without specific identification
        // This will rely on the focused application fallback
        // Using a path that targets the button specifically by description
        let button1Path = try ElementPath.parse("ui://AXApplication/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@description=\"1\"]")
        
        // Attempt to resolve the button to test focused app fallback
        let buttonElement = try await button1Path.resolve(using: accessibilityService)
        print("Successfully resolved button with focused app fallback")
        
        // Press the button to verify we found the right element - using direct element
        try AccessibilityElement.performAction(buttonElement, action: "AXPress")
        print("Successfully pressed button with focused app fallback")
        
        // Cleanup - close calculator
        try await calculator.terminate()
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
            app.activate(options: .activateIgnoringOtherApps)
        } else {
            // Launch the app
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            guard let appURL = url else {
                throw NSError(domain: "com.macos.mcp.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Calculator app not found"])
            }
            
            try NSWorkspace.shared.launchApplication(at: appURL, options: .default, configuration: [:])
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
