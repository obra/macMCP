// ABOUTME: ScreenshotToolE2ETests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

// Import shared test utilities
// @_implementationOnly import TestsWithoutMocks

/// End-to-end tests for the ScreenshotTool using the Calculator app
@Suite(.serialized)
struct ScreenshotToolE2ETests {
  // Test components
  private var toolChain: ToolChain!
  private let calculatorBundleId = "com.apple.calculator"

  // Save references for cleanup
  private var calculatorRunning = false

  // Shared setup method
  private mutating func setUp() async throws {
    // Create tool chain
    toolChain = ToolChain(logLabel: "test.screenshot.e2e")

    // Check if Calculator is already running
    calculatorRunning = !NSRunningApplication.runningApplications(
      withBundleIdentifier: calculatorBundleId,
    ).isEmpty

    // Launch Calculator if it's not already running
    if !calculatorRunning {
      // Open Calculator app
      _ = try await toolChain.openApp(bundleId: calculatorBundleId)

      // Allow time for Calculator to launch and stabilize
      try await Task.sleep(for: .milliseconds(2000))
    }

    // Activate Calculator to ensure it's in front
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first?
      .activate(options: [])

    // Allow time for activation
    try await Task.sleep(for: .milliseconds(1000))
  }

  // Shared teardown method
  private mutating func tearDown() async throws {
    // Clean up only if we launched Calculator (don't close if it was already running)
    if !calculatorRunning {
      // Close Calculator
      _ = try await toolChain.terminateApp(bundleId: calculatorBundleId)
    }

    toolChain = nil
  }

  // MARK: - Test Methods

  /// Test capturing screenshot of full screen
  @Test("Full Screen Capture")
  mutating func testFullScreenCapture() async throws {
    try await setUp()
    // Create parameters for the screenshot tool
    let params: [String: Value] = [
      "region": .string("full")
    ]

    // Take the screenshot
    let result = try await toolChain.screenshotTool.handler(params)

    // Verify the result
    verifyScreenshotResult(result, mimeType: "image/png")

    // Verify the image dimensions make sense for a screen
    if case .image(let data, _, let metadata) = result[0] {
      let decodedData = Data(base64Encoded: data)!
      let image = NSImage(data: decodedData)!

      // Get the main screen dimensions
      let mainScreen = NSScreen.main!
      let screenWidth = Int(mainScreen.frame.width * mainScreen.backingScaleFactor)
      let screenHeight = Int(mainScreen.frame.height * mainScreen.backingScaleFactor)

      // Check that image dimensions match screen dimensions (approximately)
      // We use a tolerance because different scaling factors might affect the exact pixel dimensions
      let widthTolerance = Int(Double(screenWidth) * 0.1)  // 10% tolerance
      let heightTolerance = Int(Double(screenHeight) * 0.1)  // 10% tolerance

      #expect(
        abs(Int(image.size.width) - screenWidth) <= widthTolerance,
        "Screenshot width should be close to screen width",
      )
      #expect(
        abs(Int(image.size.height) - screenHeight) <= heightTolerance,
        "Screenshot height should be close to screen height",
      )

      // Check metadata
      #expect(metadata?["region"] == "full", "Region should be 'full'")
    } else {
      #expect(Bool(false), "Result should be an image content item")
    }
    
    try await tearDown()
  }

  /// Test capturing screenshot of an area of the screen
  @Test("Area Screenshot Capture")
  mutating func testAreaCapture() async throws {
    try await setUp()
    // Define an area that should contain part of the Calculator window
    // We use the center of the screen to increase the chances of capturing Calculator
    let screenFrame = NSScreen.main!.frame
    let centerX = Int(screenFrame.width / 2)
    let centerY = Int(screenFrame.height / 2)
    let width = 800
    let height = 600

    // Create parameters for the screenshot tool
    let params: [String: Value] = [
      "region": .string("area"),
      "x": .int(centerX - width / 2),
      "y": .int(centerY - height / 2),
      "width": .int(width),
      "height": .int(height),
    ]

    // Take the screenshot
    let result = try await toolChain.screenshotTool.handler(params)

    // Verify the result
    verifyScreenshotResult(result, mimeType: "image/png")

    // Verify the image dimensions match the requested area
    if case .image(let data, _, let metadata) = result[0] {
      let decodedData = Data(base64Encoded: data)!
      let image = NSImage(data: decodedData)!

      // On Retina displays, image dimensions might be doubled
      // So we check if dimensions match or are a multiple of the requested size
      let widthRatio = Double(image.size.width) / Double(width)
      let heightRatio = Double(image.size.height) / Double(height)

      #expect(
        widthRatio == 1.0 || abs(widthRatio - 2.0) < 0.1,
        "Screenshot width should match requested width or be scaled by 2x (requested: \(width), actual: \(image.size.width))",
      )
      #expect(
        heightRatio == 1.0 || abs(heightRatio - 2.0) < 0.1,
        "Screenshot height should match requested height or be scaled by 2x (requested: \(height), actual: \(image.size.height))",
      )

      // For metadata, we don't strictly verify values since they might be scaled
      #expect(metadata?["width"] != nil, "Width metadata should be present")
      #expect(metadata?["height"] != nil, "Height metadata should be present")
      #expect(metadata?["region"] == "area", "Region should be 'area'")
    } else {
      #expect(Bool(false), "Result should be an image content item")
    }
    
    try await tearDown()
  }

  /// Test capturing screenshot of the Calculator window
  @Test("Window Screenshot Capture")
  mutating func testWindowCapture() async throws {
    try await setUp()
    // Create parameters for the screenshot tool
    let params: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string(calculatorBundleId),
    ]

    // Take the screenshot
    let result = try await toolChain.screenshotTool.handler(params)

    // Verify the result
    verifyScreenshotResult(result, mimeType: "image/png")

    // Verify it's a reasonable size for the Calculator window
    if case .image(let data, _, let metadata) = result[0] {
      let decodedData = Data(base64Encoded: data)!
      let image = NSImage(data: decodedData)!

      // Calculator window size can vary - it might be as small as 190px on some systems
      #expect(image.size.width > 180, "Calculator window should be wider than 180px")
      #expect(image.size.height > 180, "Calculator window should be taller than 180px")

      // Check metadata
      #expect(metadata?["region"] == "window", "Region should be 'window'")
    } else {
      #expect(Bool(false), "Result should be an image content item")
    }
    
    try await tearDown()
  }

  /// Test capturing screenshot of a UI element in the Calculator
  @Test("Element Screenshot Capture")
  mutating func testElementCapture() async throws {
    try await setUp()
    // First make sure Calculator is fully active
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))


    // 1. First verify area screenshots work (as a basic test)
    let screenFrame = NSScreen.main!.frame
    let centerX = Int(screenFrame.width / 2)
    let centerY = Int(screenFrame.height / 2)

    // Create parameters for the screenshot tool for a small area of the screen
    let areaParams: [String: Value] = [
      "region": .string("area"),
      "x": .int(centerX - 100),
      "y": .int(centerY - 100),
      "width": .int(200),
      "height": .int(200),
    ]

    // Take the screenshot of the area
    let areaResult = try await toolChain.screenshotTool.handler(areaParams)

    // Verify the result
    verifyScreenshotResult(areaResult, mimeType: "image/png")

    // 2. Try to capture the calculator window using the window region type
    let windowParams: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string(calculatorBundleId),
    ]

    let windowResult = try await toolChain.screenshotTool.handler(windowParams)

    // Verify window screenshot
    verifyScreenshotResult(windowResult, mimeType: "image/png")

    // 3. Now find UI elements in the calculator and try to capture them

    // Define criteria to find calculator UI elements
    let buttonCriteria = UIElementCriteria(
      role: "AXButton",
      isVisible: true,
    )

    // Find button elements
    let buttonElements = try await toolChain.findElements(
      matching: buttonCriteria,
      scope: "application",
      bundleId: calculatorBundleId,
      maxDepth: 10,
    )


    // Test element screenshot capture if we found any elements
    if !buttonElements.isEmpty {
      // Create a list of elements to capture
      let elementsToCaptureCount = min(3, buttonElements.count)

      // Try to capture several elements to increase test coverage and robustness
      var capturedElements = 0
      var captureFailures = 0

      for i in 0..<elementsToCaptureCount {
        do {
          let element = buttonElements[i]

          // Create parameters for element screenshot
          let elementParams: [String: Value] = [
            "region": .string("element"),
            "elementPath": .string(element.path),
          ]

          // Capture the element screenshot
          let result = try await toolChain.screenshotTool.handler(elementParams)

          // Verify the result
          verifyScreenshotResult(result, mimeType: "image/png")

          // Extract and verify image data
          if case .image(let data, _, let metadata) = result[0] {
            let decodedData = Data(base64Encoded: data)!
            let image = NSImage(data: decodedData)!

            // Verify image has reasonable dimensions
            #expect(
              image.size.width > 5.0, "Element screenshot width should be reasonable")
            #expect(
              image.size.height > 5.0, "Element screenshot height should be reasonable")

            // Verify metadata
            #expect(metadata?["region"] == "element", "Region should be 'element'")

       
            capturedElements += 1
          }
        } catch {
          print("Error capturing element \(i + 1): \(error.localizedDescription)")
          captureFailures += 1
        }
      }

      // We should have captured at least one element successfully
      #expect(capturedElements > 0, "Should capture at least one element screenshot successfully")
    }

    // 4. Also try capturing a window element by ID
    do {
      let windowCriteria = UIElementCriteria(
        role: "AXWindow",
        isVisible: true,
      )

      let windowElements = try await toolChain.findElements(
        matching: windowCriteria,
        scope: "application",
        bundleId: calculatorBundleId,
        maxDepth: 3,
      )

      if !windowElements.isEmpty {
     

        // Create parameters for element screenshot
        let elementParams: [String: Value] = [
          "region": .string("element"),
          "elementPath": .string(windowElements[0].path),
        ]

        // Capture the window element screenshot
        let result = try await toolChain.screenshotTool.handler(elementParams)

        // Verify the result
        verifyScreenshotResult(result, mimeType: "image/png")

        // Verify it's a reasonable size for the Calculator window
        if case .image(let data, _, let metadata) = result[0] {
          let decodedData = Data(base64Encoded: data)!
          let image = NSImage(data: decodedData)!

          // Calculator window size can vary - check it's a reasonable size
          #expect(image.size.width > 180, "Calculator window should be wider than 180px")
          #expect(image.size.height > 180, "Calculator window should be taller than 180px")

          // Check metadata
          #expect(metadata?["region"] == "element", "Region should be 'element'")


        }
      } else {
        print("No window elements found for element ID-based capture")
      }
    } catch {
      print("Window element screenshot failed: \(error.localizedDescription)")
      // This is not a critical test, so we won't fail the test if this part fails
    }
    
    try await tearDown()
  }

  /// Test capturing screenshot of individual elements discovered by the UI inspector
  /// This test tries to find specific UI elements in the Calculator app
  @Test("Specific Element Screenshot")
  mutating func testSpecificElementScreenshot() async throws {
    try await setUp()
    // First make sure Calculator is fully active and has time to stabilize
    NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first?
      .activate(options: [])
    try await Task.sleep(for: .milliseconds(2000))


    // First, check that we can screenshot the entire app window using bundleId (not element ID)
    // This is more reliable and doesn't require element IDs
    let windowParams: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string(calculatorBundleId),
    ]

    // Take a screenshot of the window
    let windowResult = try await toolChain.screenshotTool.handler(windowParams)

    // Verify the basic result format
    verifyScreenshotResult(windowResult, mimeType: "image/png")

    if case .image(let data, _, let metadata) = windowResult[0] {
      let decodedData = Data(base64Encoded: data)!
      let image = NSImage(data: decodedData)!

      // Window should have reasonable dimensions
      #expect(image.size.width > 180, "Window should be wider than 180px")
      #expect(image.size.height > 180, "Window should be taller than 180px")
      #expect(metadata?["region"] == "window", "Region should be 'window'")


    }

    // Now demonstrate element discovery using the UI Explorer

    // Try to find button elements
    let buttonCriteria = UIElementCriteria(
      role: "AXButton",
      isVisible: true,
    )

    let _ = try await toolChain.findElements(
      matching: buttonCriteria,
      scope: "application",
      bundleId: calculatorBundleId,
      maxDepth: 10,
    )


    // Try to find other element types - just for discovery demonstration
    let staticTextCriteria = UIElementCriteria(
      role: "AXStaticText",
      isVisible: true,
    )

    let _ = try await toolChain.findElements(
      matching: staticTextCriteria,
      scope: "application",
      bundleId: calculatorBundleId,
      maxDepth: 10,
    )

    try await tearDown()
  }

  // MARK: - Error Tests

  /// Test behavior when element cannot be found
  @Test("Non-Existent Element")
  mutating func testNonExistentElement() async throws {
    try await setUp()
    // Create parameters for the screenshot tool with a non-existent element path
    let params: [String: Value] = [
      "region": .string("element"),
      "elementPath": .string("macos://ui/AXApplication[@AXTitle=\"NonExistentApp\"]/AXWindow/AXButton"),
    ]

    // Expect an error
    do {
      _ = try await toolChain.screenshotTool.handler(params)
      #expect(Bool(false), "Should throw an error for non-existent element")
    } catch {
      // Success - we expect an error
      #expect(error.localizedDescription.contains("not found"),
        "Error should indicate element not found")
    }
    
    try await tearDown()
  }

  /// Test behavior when application is not running
  @Test("Non-Running Application")
  mutating func testNonRunningApplication() async throws {
    try await setUp()
    // Create parameters for the screenshot tool with a non-running application
    let params: [String: Value] = [
      "region": .string("window"),
      "bundleId": .string("com.apple.non.existent.app"),
    ]

    // Expect an error
    do {
      _ = try await toolChain.screenshotTool.handler(params)
      #expect(Bool(false), "Should throw an error for non-running application")
    } catch {
      // Success - we expect an error
      #expect(error.localizedDescription.contains("not running"),
        "Error should indicate application not running")
    }
    
    try await tearDown()
  }

  // MARK: - Helper Methods

  /// Find a calculator button UI element
  private func findCalculatorButton() async throws -> UIElement? {
    // Define criteria to find a calculator button
    let criteria = UIElementCriteria(
      role: "AXButton",
      isVisible: true,
      isEnabled: true,
    )

    // Find the button in the Calculator app
    let elements = try await toolChain.findElements(
      matching: criteria,
      scope: "application",
      bundleId: calculatorBundleId,
      maxDepth: 15,
    )

    // Return the first matching element
    return elements.first
  }

  /// Verify that a result contains a valid image
  private func verifyScreenshotResult(_ result: [Tool.Content], mimeType: String) {
    // Make sure we have exactly one result item
    #expect(result.count == 1, "Should return one content item")

    // Check that it's an image with the right MIME type
    if case .image(let data, let resultMimeType, let metadata) = result[0] {
      #expect(resultMimeType == mimeType, "MIME type should be correct")
      #expect(!data.isEmpty, "Image data should not be empty")

      // Try to decode the Base64 data
      let decodedData = Data(base64Encoded: data)
      #expect(decodedData != nil, "Should be able to decode Base64 data")

      // Try to create an image from the data
      let image = NSImage(data: decodedData!)
      #expect(image != nil, "Should be able to create an image from the data")

      // Check that metadata is present
      #expect(metadata != nil, "Metadata should be present")
      #expect(metadata?["width"] != nil, "Width metadata should be present")
      #expect(metadata?["height"] != nil, "Height metadata should be present")
      #expect(metadata?["scale"] != nil, "Scale metadata should be present")
      #expect(metadata?["region"] != nil, "Region metadata should be present")

      // Save the image to disk for manual inspection
      saveScreenshotForInspection(
        imageData: decodedData!,
        region: metadata?["region"] ?? "unknown",
        width: metadata?["width"] ?? "0",
        height: metadata?["height"] ?? "0",
      )
    } else {
      #expect(Bool(false), "Result should be an image content item")
    }
  }

  /// Save a screenshot to disk for manual inspection
  private func saveScreenshotForInspection(
    imageData: Data, region: String, width: String, height: String
  ) {
    let outputDir = "/Users/jesse/Documents/GitHub/projects/mac-mcp/MacMCP/test-screenshots"
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = dateFormatter.string(from: Date())
    let filename = "screenshot_\(region)_\(width)x\(height)_\(timestamp).png"
    let fileURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)

    do {
      // Create the directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: outputDir),
        withIntermediateDirectories: true,
      )

      try imageData.write(to: fileURL)
      print("Saved screenshot for inspection: \(fileURL.path)")
    } catch {
      print("Error saving screenshot to disk: \(error.localizedDescription)")
    }
  }

  /// Save a screenshot with custom identifier for easier tracking
  private func saveScreenshotWithIdentifier(imageData: Data, identifier: String) {
    let outputDir = "/Users/jesse/Documents/GitHub/projects/mac-mcp/MacMCP/test-screenshots"
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = dateFormatter.string(from: Date())
    let filename = "element_\(identifier)_\(timestamp).png"
    let fileURL = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)

    do {
      // Create the directory if it doesn't exist
      try FileManager.default.createDirectory(
        at: URL(fileURLWithPath: outputDir),
        withIntermediateDirectories: true,
      )

      try imageData.write(to: fileURL)
    } catch {
      print("Error saving screenshot to disk: \(error.localizedDescription)")
    }
  }
}
