// ABOUTME: Tests specifically focused on application element lookup methods in ElementPath.
// ABOUTME: Tests different lookup strategies with title, bundleId, and foreground activation.

import XCTest
import Foundation
@testable import MacMCP

final class ApplicationLookupTests: XCTestCase {
    private var accessibilityService: AccessibilityService!
    private var calculatorBundleId = "com.apple.calculator"
    private var calculatorTitle = "Calculator"
    private var app: NSRunningApplication?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create accessibility service
        accessibilityService = AccessibilityService()
        
        // Launch Calculator app
        app = launchCalculator()
        XCTAssertNotNil(app, "Failed to launch Calculator app")
        
        // Give time for app to fully load
        Thread.sleep(forTimeInterval: 2.0)
    }
    
    override func tearDownWithError() throws {
        // Terminate Calculator
        app?.terminate()
        app = nil
        
        // Wait for termination
        Thread.sleep(forTimeInterval: 1.0)
        
        try super.tearDownWithError()
    }
    
    private func launchCalculator() -> NSRunningApplication? {
        let calcURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: calculatorBundleId)
        guard let url = calcURL else {
            XCTFail("Could not find Calculator app")
            return nil
        }
        
        return try? NSWorkspace.shared.launchApplication(
            at: url,
            options: .default,
            configuration: [:]
        )
    }
    
    // Helper to ensure the app is in foreground
    private func bringCalculatorToForeground() async throws {
        guard let app = app else {
            XCTFail("Calculator app not running")
            return
        }
        
        XCTAssertTrue(app.activate(options: []), "Failed to bring Calculator to foreground")
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
    }
    
    // Helper to test application lookup using ElementPath
    private func testApplicationLookup(path: String, description: String, shouldForeground: Bool = false) async throws {
        print("\n=== TEST: \(description) ===")
        print("Path: \(path)")
        
        if shouldForeground {
            print("Bringing Calculator to foreground first...")
            try await bringCalculatorToForeground()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        do {
            // Parse the path
            let elementPath = try ElementPath.parse(path)
            
            // Try to resolve just the first segment (the application)
            // We use a hack to extract just the application element by passing a path with only the first segment
            let truncatedPath = try ElementPath(segments: [elementPath.segments[0]])
            
            // Time the resolution for performance comparison
            let startTime = Date()
            let appElement = try await truncatedPath.resolve(using: accessibilityService)
            let timeElapsed = Date().timeIntervalSince(startTime)
            
            // Basic validation - we don't have much we can check, but we can get the role
            var roleRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, "AXRole" as CFString, &roleRef)
            XCTAssertEqual(status, .success, "Failed to get role from application element")
            XCTAssertEqual(roleRef as? String, "AXApplication", "Element is not an application")
            
            print("✅ SUCCESS: Application lookup succeeded in \(String(format: "%.3f", timeElapsed)) seconds.")
            
            // Get additional details for debugging
            var titleRef: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(appElement, "AXTitle" as CFString, &titleRef)
            if titleStatus == .success, let title = titleRef as? String {
                print("Application title: \(title)")
            }
            
            // Try to get a pid to validate it's the right app
            var pid: pid_t = 0
            let pidStatus = AXUIElementGetPid(appElement, &pid)
            if pidStatus == .success {
                if let app = NSRunningApplication(processIdentifier: pid) {
                    print("Application: \(app.localizedName ?? "unknown") (Bundle ID: \(app.bundleIdentifier ?? "unknown"))")
                    XCTAssertEqual(app.bundleIdentifier, calculatorBundleId, "Wrong application was found")
                } else {
                    print("Application process: \(pid) (no NSRunningApplication available)")
                }
            }
        } catch {
            print("❌ FAILED: \(description) failed with error: \(error)")
            XCTFail("Application lookup failed: \(error)")
        }
    }
    
    // MARK: - Tests
    
    func testApplicationLookupByTitleOnly() async throws {
        let path = "ui://AXApplication[@AXTitle=\"Calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by title only")
    }
    
    func testApplicationLookupByBundleIdOnly() async throws {
        let path = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by bundleId only")
    }
    
    func testApplicationLookupByTitleAndBundleId() async throws {
        let path = "ui://AXApplication[@AXTitle=\"Calculator\"][@bundleIdentifier=\"com.apple.calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by title and bundleId (title first)")
    }
    
    func testApplicationLookupByBundleIdAndTitle() async throws {
        let path = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"][@AXTitle=\"Calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by bundleId and title (bundleId first)")
    }
    
    func testApplicationLookupByTitleWithAXBundleId() async throws {
        let path = "ui://AXApplication[@AXTitle=\"Calculator\"][@AXbundleIdentifier=\"com.apple.calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by title and AX-prefixed bundleId")
    }
    
    // Tests with foreground activation
    
    func testApplicationLookupByTitleOnlyWithForeground() async throws {
        let path = "ui://AXApplication[@AXTitle=\"Calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by title only (with foreground)", shouldForeground: true)
    }
    
    func testApplicationLookupByBundleIdOnlyWithForeground() async throws {
        let path = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]"
        try await testApplicationLookup(path: path, description: "Lookup by bundleId only (with foreground)", shouldForeground: true)
    }
    
    // Extreme test - is the app running but just can't be found with AX?
    func testApplicationIsRunning() async throws {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId)
        XCTAssertFalse(apps.isEmpty, "Calculator not found in running applications")
        
        if let app = apps.first {
            print("Calculator is running:")
            print("- PID: \(app.processIdentifier)")
            print("- Name: \(app.localizedName ?? "unknown")")
            print("- Bundle ID: \(app.bundleIdentifier ?? "unknown")")
            print("- Is active: \(app.isActive)")
            print("- Is hidden: \(app.isHidden)")
            
            // Try raw AX API approach
            let axElement = AXUIElementCreateApplication(app.processIdentifier)
            
            var roleRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(axElement, "AXRole" as CFString, &roleRef)
            
            print("AX API direct check result: \(status == .success ? "Success" : "Failed")")
            if status == .success {
                print("AX Role: \(roleRef as? String ?? "unknown")")
            }
            
            var titleRef: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(axElement, "AXTitle" as CFString, &titleRef)
            if titleStatus == .success {
                print("AX Title: \(titleRef as? String ?? "unknown")")
            }
        }
    }
    
    // Test accessibility permissions
    func testAccessibilityPermissionsCheck() async throws {
        // Check if we can access any accessibility API as a permissions test
        let systemWideElement = AXUIElementCreateSystemWide()
        var roleRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(systemWideElement, "AXRole" as CFString, &roleRef)
        
        let permissionsGranted = (status == .success)
        print("Accessibility permissions status: \(permissionsGranted)")
        XCTAssertTrue(permissionsGranted, "Accessibility permissions are not granted")
    }
}