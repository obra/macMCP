// ABOUTME: LayeredWindowMoveDebugTest.swift - Comprehensive test of window movement at each layer
// ABOUTME: Tests from WindowManagementTool down to raw AX APIs to isolate the failure point

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

/// Debug test that tests window movement at each layer to isolate the failure point
@Suite(.serialized) struct LayeredWindowMoveDebugTest {
  private var toolChain: ToolChain!
  private var logger: Logger!
  private var textEditApp: NSRunningApplication?
  private mutating func setUp() async throws {
    // Set up logging
    (logger, _) = TestLogger.create(
      label: "mcp.test.layered_debug", testName: "LayeredWindowMoveDebugTest",
    )
    TestLogger.configureEnvironment(logger: logger)
    logger.info("Setting up LayeredWindowMoveDebugTest")
    // Create toolchain
    toolChain = ToolChain()
    // Ensure TextEdit is running
    textEditApp = NSWorkspace.shared.runningApplications.first(where: {
      $0.bundleIdentifier == "com.apple.TextEdit"
    })
    if textEditApp == nil {
      logger.info("Launching TextEdit...")
      let task = Process()
      task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      task.arguments = ["-a", "TextEdit"]
      try task.run()
      task.waitUntilExit()
      // Wait for launch
      try await Task.sleep(for: .milliseconds(3000))
      textEditApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == "com.apple.TextEdit"
      })
    }
    guard textEditApp != nil else { throw TestError.setupFailed("TextEdit could not be launched") }
    logger.info("TextEdit running with PID: \(textEditApp!.processIdentifier)")
    // Create a new document to ensure we have a window
    logger.info("Creating new TextEdit document...")
    let scriptTask = Process()
    scriptTask.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    scriptTask.arguments = ["-e", "tell application \"TextEdit\" to make new document"]
    try scriptTask.run()
    scriptTask.waitUntilExit()
    // Wait for window to appear
    try await Task.sleep(for: .milliseconds(1000))
  }

  private mutating func tearDown() async throws {
    logger.info("Tearing down LayeredWindowMoveDebugTest")
    toolChain = nil
    textEditApp = nil
  }

  @Test("Layered window movement debug") mutating func layeredWindowMovement() async throws {
    try await setUp()
    guard let app = textEditApp else { throw TestError.setupFailed("TextEdit app not available") }
    logger.info("🚀 Starting layered window movement test")
    // ==== LAYER 1: Raw AX API (Direct window access) ====
    logger.info("\n📍 LAYER 1: Raw AX API (Direct Window Access)")
    let appElement = AXUIElementCreateApplication(app.processIdentifier)
    var windowsRef: CFTypeRef?
    let windowsResult = AXUIElementCopyAttributeValue(
      appElement, kAXWindowsAttribute as CFString, &windowsRef,
    )
    guard windowsResult == .success else {
      throw TestError.testFailed("Failed to get windows via raw AX API: \(windowsResult)")
    }
    guard let windows = windowsRef as? [AXUIElement], let directWindow = windows.first else {
      throw TestError.testFailed("No windows found via raw AX API")
    }
    let directElementID = CFHash(directWindow)
    logger.info("   ✅ Direct window element ID: \(directElementID)")
    // Get window title for path construction
    var directTitleRef: CFTypeRef?
    AXUIElementCopyAttributeValue(directWindow, kAXTitleAttribute as CFString, &directTitleRef)
    let directTitle = (directTitleRef as? String) ?? "No title"
    logger.info("   ✅ Direct window title: '\(directTitle)'")
    // Test direct movement
    let testPoint1 = CGPoint(x: 100, y: 100)
    var mutableTestPoint1 = testPoint1
    guard let pointValue1 = AXValueCreate(AXValueType.cgPoint, &mutableTestPoint1) else {
      throw TestError.testFailed("Failed to create point value for direct test")
    }
    let directMoveResult = AXUIElementSetAttributeValue(
      directWindow, kAXPositionAttribute as CFString, pointValue1,
    )
    logger.info(
      "   📊 Direct move result: \(directMoveResult) (\(directMoveResult == .success ? "SUCCESS" : "FAILURE"))",
    )
    if directMoveResult != .success {
      throw TestError.testFailed(
        "LAYER 1 FAILED: Direct AX API movement failed with \(directMoveResult)",
      )
    }
    // ==== LAYER 2: ElementPath.resolve() ====
    logger.info("\n📍 LAYER 2: ElementPath.resolve()")
    let pathString =
      "macos://ui/AXApplication[@AXTitle=\"TextEdit\"][@bundleId=\"com.apple.TextEdit\"]/AXWindow[@AXTitle=\"\(directTitle)\"]"
    logger.info("   🔍 Testing path: \(pathString)")
    let elementPath: ElementPath
    do {
      elementPath = try ElementPath.parse(pathString)
      logger.info("   ✅ ElementPath parsed successfully")
    } catch { throw TestError.testFailed("LAYER 2 FAILED: ElementPath parsing failed: \(error)") }
    let resolvedElement: AXUIElement
    do {
      resolvedElement = try await elementPath.resolve(using: toolChain.accessibilityService)
      logger.info("   ✅ ElementPath resolved successfully")
    } catch {
      throw TestError.testFailed("LAYER 2 FAILED: ElementPath resolution failed: \(error)")
    }
    let resolvedElementID = CFHash(resolvedElement)
    logger.info("   📊 Resolved element ID: \(resolvedElementID)")
    logger.info(
      "   📊 Element ID comparison: Direct=\(directElementID), Resolved=\(resolvedElementID)",
    )
    if directElementID != resolvedElementID {
      logger.error("   ❌ CRITICAL: Element IDs differ! ElementPath returned different element.")
      // Continue testing but note the difference
    } else {
      logger.info("   ✅ Element IDs match - same element reference")
    }
    // Test resolved element movement
    let testPoint2 = CGPoint(x: 150, y: 150)
    var mutableTestPoint2 = testPoint2
    guard let pointValue2 = AXValueCreate(AXValueType.cgPoint, &mutableTestPoint2) else {
      throw TestError.testFailed("Failed to create point value for resolved element test")
    }
    let resolvedMoveResult = AXUIElementSetAttributeValue(
      resolvedElement,
      kAXPositionAttribute as CFString,
      pointValue2,
    )
    logger.info(
      "   📊 Resolved element move result: \(resolvedMoveResult) (\(resolvedMoveResult == .success ? "SUCCESS" : "FAILURE"))",
    )
    if resolvedMoveResult != .success {
      logger.error(
        "   ❌ LAYER 2 FAILED: ElementPath resolved element movement failed with \(resolvedMoveResult)",
      )
    }
    // ==== LAYER 3: AccessibilityService.moveWindow() ====
    logger.info("\n📍 LAYER 3: AccessibilityService.moveWindow()")
    let testPoint3 = CGPoint(x: 200, y: 200)
    do {
      try await toolChain.accessibilityService.moveWindow(withPath: pathString, to: testPoint3)
      logger.info("   ✅ AccessibilityService.moveWindow() succeeded")
    } catch {
      logger.error("   ❌ LAYER 3 FAILED: AccessibilityService.moveWindow() failed: \(error)")
      logger.error("   📊 Error details: \(error)")
    }
    // ==== LAYER 4: WindowManagementTool ====
    logger.info("\n📍 LAYER 4: WindowManagementTool")
    let toolParams: [String: Value] = [
      "action": .string("moveWindow"), "windowId": .string(pathString), "x": .double(250),
      "y": .double(250),
    ]
    do {
      let result = try await toolChain.windowManagementTool.handler(toolParams)
      logger.info("   ✅ WindowManagementTool succeeded")
      logger.info("   📊 Result: \(result)")
    } catch {
      logger.error("   ❌ LAYER 4 FAILED: WindowManagementTool failed: \(error)")
      logger.error("   📊 Error details: \(error)")
    }
    // ==== FINAL ANALYSIS ====
    logger.info("\n📊 FINAL ANALYSIS:")
    logger.info(
      "   Layer 1 (Raw AX API): \(directMoveResult == .success ? "✅ SUCCESS" : "❌ FAILED")",
    )
    logger.info(
      "   Layer 2 (ElementPath): \(resolvedMoveResult == .success ? "✅ SUCCESS" : "❌ FAILED")",
    )
    logger.info(
      "   Element ID Match: \(directElementID == resolvedElementID ? "✅ SAME" : "❌ DIFFERENT")",
    )
    // Get final window position
    var finalPositionRef: CFTypeRef?
    AXUIElementCopyAttributeValue(directWindow, kAXPositionAttribute as CFString, &finalPositionRef)
    if let finalPosition = finalPositionRef {
      logger.info("   🏁 Final window position: \(finalPosition)")
    }
    logger.info("🏁 Layered test complete")
    // Manual cleanup since defer doesn't work with async
    try await tearDown()
  }
}

// MARK: - Helper Types

struct TestError: Swift.Error {
  let message: String
  static func setupFailed(_ message: String) -> TestError {
    TestError(message: "Setup failed: \(message)")
  }

  static func testFailed(_ message: String) -> TestError {
    TestError(message: "Test failed: \(message)")
  }
}
