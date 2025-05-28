// ABOUTME: UIElementPathInitIntegrationTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
import Logging
import Testing

@testable @preconcurrency import MacMCP

@Suite(.serialized) struct UIElementPathInitIntegrationTests {
  @Test("Initialize UIElement from simple Calculator path") func initFromSimplePath() async throws {
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
    let windowPath =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"

    // Create a UIElement from the path
    let windowElement = try await UIElement(
      fromPath: windowPath, accessibilityService: accessibilityService)

    // Verify properties of the created UIElement
    #expect(windowElement.role == "AXWindow")
    #expect(windowElement.path == windowPath)
    #expect(windowElement.axElement != nil)

    // Cleanup - close calculator
    try await calculator.terminate()

    // Ensure all Calculator processes are terminated
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator"
    ).first {
      app.terminate()
    }

    // Give time for the app to fully terminate
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }

  @Test("Initialize UIElement from complex Calculator path with multiple attributes")
  func initFromComplexPath()
    async throws
  {
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
    let buttonPath =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"

    // Get diagnostics on the path before attempting resolution
    _ = try await ElementPath.diagnosePathResolutionIssue(buttonPath, using: accessibilityService)
    // Create a UIElement from the path
    let buttonElement = try await UIElement(
      fromPath: buttonPath, accessibilityService: accessibilityService)

    // Check if the AXUIElement is a valid reference
    if let axElement = buttonElement.axElement {

      // Try to get role directly from AXUIElement (double-check)
      var roleRef: CFTypeRef?
      _ = AXUIElementCopyAttributeValue(axElement, AXAttribute.role as CFString, &roleRef)

      // Try to get description directly from AXUIElement (double-check)
      var descRef: CFTypeRef?
      _ = AXUIElementCopyAttributeValue(axElement, AXAttribute.description as CFString, &descRef)

      // Try to get actions directly from AXUIElement
      var actionsArrayRef: CFTypeRef?
      _ = AXUIElementCopyAttributeValue(
        axElement, AXAttribute.actions as CFString, &actionsArrayRef)
    } else {
      print(
        "2. AXUIElement resolved: NO (nil reference) - This indicates the path did not resolve to a real UI element"
      )
    }

    // Verify properties of the created UIElement
    #expect(buttonElement.role == "AXButton")
    #expect(buttonElement.elementDescription == "1")
    #expect(buttonElement.path == buttonPath)
    #expect(buttonElement.axElement != nil)
    #expect(buttonElement.isClickable == true)

    // Cleanup - close calculator
    try await calculator.terminate()

    // Ensure all Calculator processes are terminated
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator"
    ).first {
      app.terminate()
    }

    // Give time for the app to fully terminate
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }

  @Test("Compare two paths resolving to the same element") func sameElementComparison() async throws
  {
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
    let path1 =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
    let path2 = "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[0]"

    // Compare the paths
    let areSame = try await UIElement.areSameElement(
      path1: path1,
      path2: path2,
      accessibilityService: accessibilityService
    )

    // Verify the paths resolve to the same element
    #expect(areSame == true)

    // Cleanup - close calculator
    try await calculator.terminate()

    // Ensure all Calculator processes are terminated
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator"
    ).first {
      app.terminate()
    }

    // Give time for the app to fully terminate
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }

  @Test("Compare two paths resolving to different elements") func differentElementComparison()
    async throws
  {
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
    let windowPath =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
    let buttonPath =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"

    // Compare the paths
    let areSame = try await UIElement.areSameElement(
      path1: windowPath,
      path2: buttonPath,
      accessibilityService: accessibilityService
    )

    // Verify the paths resolve to different elements
    #expect(areSame == false)

    // Cleanup - close calculator
    try await calculator.terminate()

    // Ensure all Calculator processes are terminated
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator"
    ).first {
      app.terminate()
    }

    // Give time for the app to fully terminate
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }

  @Test("Handle error when initializing from invalid path") func initFromInvalidPath() async throws
  {
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
    let invalidPath =
      "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXNonExistentElement"

    // Attempt to create a UIElement (should throw)
    do {
      _ = try await UIElement(fromPath: invalidPath, accessibilityService: accessibilityService)
      #expect(Bool(false), "Expected an error but none was thrown")
    } catch let error as ElementPathError {
      // Verify we got an appropriate error
      switch error {
      case .noMatchingElements, .segmentResolutionFailed:
        // These are the expected error types
        break
      default: #expect(Bool(false), "Unexpected error type: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }

    // Cleanup - close calculator
    try await calculator.terminate()

    // Ensure all Calculator processes are terminated
    if let app = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.calculator"
    ).first {
      app.terminate()
    }

    // Give time for the app to fully terminate
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }
}

// Helper class for managing the Calculator app during tests
private class CalculatorApp {
  let bundleId = "com.apple.calculator"
  let accessibilityService: AccessibilityService

  init(accessibilityService: AccessibilityService) {
    self.accessibilityService = accessibilityService
  }

  func launch() async throws {
    // Check if the app is already running
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

    if let app = runningApps.first, app.isTerminated == false {
      // App is already running, just activate it
      app.activate()
    } else {
      // Launch the app
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
      guard let appURL = url else {
        throw NSError(
          domain: "com.macos.mcp.test",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Calculator app not found"]
        )
      }

      let config = NSWorkspace.OpenConfiguration()
      try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    // Wait for the app to become fully active
    try await Task.sleep(nanoseconds: 1_000_000_000)
  }

  func terminate() async throws {
    // Find the running app
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)

    if let app = runningApps.first, app.isTerminated == false {
      // Terminate the app
      app.terminate()
    }
  }
}
