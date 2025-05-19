// ABOUTME: ApplicationLookupTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Testing
import XCTest // Kept for XCTestError

@testable import MacMCP

@Suite(.serialized)
struct ApplicationLookupTests {
  private var accessibilityService: AccessibilityService!
  private var calculatorBundleId = "com.apple.calculator"
  private var calculatorTitle = "Calculator"
  private var app: NSRunningApplication?

  // Shared setup method
  private mutating func setUp() async throws {
    // Create accessibility service
    accessibilityService = AccessibilityService()

    // Launch Calculator app using the synchronous approach
    app = await launchCalculatorSync()
    #expect(app != nil, "Failed to launch Calculator app")

    // Give time for app to fully load
    try await Task.sleep(for: .seconds(2))
  }
  
  // Shared teardown method
  private mutating func tearDown() async throws {
    // Terminate Calculator
    app?.terminate()
    app = nil

    // Wait for termination
    try await Task.sleep(for: .seconds(1))
  }

  // Helper method that wraps the MainActor-isolated method in a synchronous call
  private func launchCalculatorSync() async -> NSRunningApplication? {
    // Capture the bundleId to avoid self reference in the closure
    let bundleId = calculatorBundleId
    
    // Launch using the calculator helper on the main actor
    let calcHelper = await CalculatorTestHelper.sharedHelper()
    do {
      _ = try await calcHelper.ensureAppIsRunning(forceRelaunch: true)
      return NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    } catch {
      return nil
    }
  }

  // Helper to ensure the app is in foreground
  private func bringCalculatorToForeground() async throws {
    guard let app else {
      // Create a custom error rather than using XCTestError
      throw NSError(
        domain: "ApplicationLookupTests",
        code: 1000,
        userInfo: [NSLocalizedDescriptionKey: "Calculator app not running"]
      )
    }

    let activated = app.activate(options: [])
    #expect(activated, "Failed to bring Calculator to foreground")
    try await Task.sleep(for: .seconds(1))
  }

  // Helper to test application lookup using ElementPath
  private func testApplicationLookup(
    path: String, description: String, shouldForeground: Bool = false
  ) async throws {
    print("\n=== TEST: \(description) ===")
    print("Path: \(path)")

    if shouldForeground {
      print("Bringing Calculator to foreground first...")
      try await bringCalculatorToForeground()
      try await Task.sleep(for: .milliseconds(500))
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
      #expect(status == .success, "Failed to get role from application element")
      #expect(roleRef as? String == "AXApplication", "Element is not an application")

      print(
        "✅ SUCCESS: Application lookup succeeded in \(String(format: "%.3f", timeElapsed)) seconds."
      )

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
          print(
            "Application: \(app.localizedName ?? "unknown") (Bundle ID: \(app.bundleIdentifier ?? "unknown"))"
          )
          #expect(app.bundleIdentifier == calculatorBundleId, "Wrong application was found")
        } else {
          print("Application process: \(pid) (no NSRunningApplication available)")
        }
      }
    } catch {
      print("❌ FAILED: \(description) failed with error: \(error)")
      throw error
    }
  }

  // MARK: - Tests

  @Test("Application Lookup By Title Only")
  mutating func testApplicationLookupByTitleOnly() async throws {
    try await setUp()
    
    let path = "ui://AXApplication[@AXTitle=\"Calculator\"]"
    try await testApplicationLookup(path: path, description: "Lookup by title only")
    
    try await tearDown()
  }

  @Test("Application Lookup By BundleId Only")
  mutating func testApplicationLookupByBundleIdOnly() async throws {
    try await setUp()
    
    let path = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]"
    try await testApplicationLookup(path: path, description: "Lookup by bundleId only")
    
    try await tearDown()
  }

  @Test("Application Lookup By Title And BundleId")
  mutating func testApplicationLookupByTitleAndBundleId() async throws {
    try await setUp()
    
    let path =
      "ui://AXApplication[@AXTitle=\"Calculator\"][@bundleIdentifier=\"com.apple.calculator\"]"
    try await testApplicationLookup(
      path: path, description: "Lookup by title and bundleId (title first)")
      
    try await tearDown()
  }

  @Test("Application Lookup By BundleId And Title")
  mutating func testApplicationLookupByBundleIdAndTitle() async throws {
    try await setUp()
    
    let path =
      "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"][@AXTitle=\"Calculator\"]"
    try await testApplicationLookup(
      path: path, description: "Lookup by bundleId and title (bundleId first)")
      
    try await tearDown()
  }

  @Test("Application Lookup By Title With AXBundleId")
  mutating func testApplicationLookupByTitleWithAXBundleId() async throws {
    try await setUp()
    
    let path =
      "ui://AXApplication[@AXTitle=\"Calculator\"][@AXbundleIdentifier=\"com.apple.calculator\"]"
    try await testApplicationLookup(
      path: path, description: "Lookup by title and AX-prefixed bundleId")
      
    try await tearDown()
  }

  // Tests with foreground activation

  @Test("Application Lookup By Title Only With Foreground")
  mutating func testApplicationLookupByTitleOnlyWithForeground() async throws {
    try await setUp()
    
    let path = "ui://AXApplication[@AXTitle=\"Calculator\"]"
    try await testApplicationLookup(
      path: path,
      description: "Lookup by title only (with foreground)",
      shouldForeground: true
    )
    
    try await tearDown()
  }

  @Test("Application Lookup By BundleId Only With Foreground")
  mutating func testApplicationLookupByBundleIdOnlyWithForeground() async throws {
    try await setUp()
    
    let path = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]"
    try await testApplicationLookup(
      path: path,
      description: "Lookup by bundleId only (with foreground)",
      shouldForeground: true
    )
    
    try await tearDown()
  }

  // Extreme test - is the app running but just can't be found with AX?
  @Test("Application Is Running")
  mutating func testApplicationIsRunning() async throws {
    try await setUp()
    
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId)
    #expect(!apps.isEmpty, "Calculator not found in running applications")

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
    
    try await tearDown()
  }

  // Test accessibility permissions
  @Test("Accessibility Permissions Check")
  mutating func testAccessibilityPermissionsCheck() async throws {
    try await setUp()
    
    // Check if we can access any accessibility API as a permissions test
    let systemWideElement = AXUIElementCreateSystemWide()
    var roleRef: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(systemWideElement, "AXRole" as CFString, &roleRef)

    let permissionsGranted = (status == .success)
    print("Accessibility permissions status: \(permissionsGranted)")
    #expect(permissionsGranted, "Accessibility permissions are not granted")
    
    try await tearDown()
  }
}