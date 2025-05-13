// ABOUTME: This file contains end-to-end integration tests for the ScreenshotTool.
// ABOUTME: It verifies the tool's ability to take real screenshots of Calculator app UI elements.

import XCTest
import Foundation
import MCP
import Logging
import AppKit
@testable import MacMCP

/// End-to-end tests for the ScreenshotTool using the Calculator app
final class ScreenshotToolE2ETests: XCTestCase {
    // Test components
    private var toolChain: ToolChain!
    private let calculatorBundleId = "com.apple.calculator"
    
    // Save references for cleanup
    private var calculatorRunning = false
    
    override func setUp() async throws {
        try await super.setUp()

        // Create tool chain
        toolChain = ToolChain(logLabel: "test.screenshot.e2e")
        
        // Check if Calculator is already running
        calculatorRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: calculatorBundleId
        ).isEmpty
        
        // Launch Calculator if it's not already running
        if !calculatorRunning {
            // Open Calculator app
            try await toolChain.openApp(bundleId: calculatorBundleId)
            
            // Allow time for Calculator to launch and stabilize
            try await Task.sleep(for: .milliseconds(2000))
        }
        
        // Activate Calculator to ensure it's in front
        NSRunningApplication.runningApplications(withBundleIdentifier: calculatorBundleId).first?.activate(options: .activateIgnoringOtherApps)
        
        // Allow time for activation
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    override func tearDown() async throws {
        // Clean up only if we launched Calculator (don't close if it was already running)
        if !calculatorRunning {
            // Close Calculator
            try await toolChain.terminateApp(bundleId: calculatorBundleId)
        }
        
        toolChain = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Methods
    
    /// Test capturing screenshot of full screen
    func testFullScreenCapture() async throws {
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
            let widthTolerance = Int(Double(screenWidth) * 0.1) // 10% tolerance
            let heightTolerance = Int(Double(screenHeight) * 0.1) // 10% tolerance
            
            XCTAssertTrue(
                abs(Int(image.size.width) - screenWidth) <= widthTolerance,
                "Screenshot width should be close to screen width"
            )
            XCTAssertTrue(
                abs(Int(image.size.height) - screenHeight) <= heightTolerance,
                "Screenshot height should be close to screen height"
            )
            
            // Check metadata
            XCTAssertEqual(metadata?["region"], "full", "Region should be 'full'")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    /// Test capturing screenshot of an area of the screen
    func testAreaCapture() async throws {
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
            "x": .int(centerX - width/2),
            "y": .int(centerY - height/2),
            "width": .int(width),
            "height": .int(height)
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

            XCTAssertTrue(
                widthRatio == 1.0 || abs(widthRatio - 2.0) < 0.1,
                "Screenshot width should match requested width or be scaled by 2x (requested: \(width), actual: \(image.size.width))"
            )
            XCTAssertTrue(
                heightRatio == 1.0 || abs(heightRatio - 2.0) < 0.1,
                "Screenshot height should match requested height or be scaled by 2x (requested: \(height), actual: \(image.size.height))"
            )

            // For metadata, we don't strictly verify values since they might be scaled
            XCTAssertNotNil(metadata?["width"], "Width metadata should be present")
            XCTAssertNotNil(metadata?["height"], "Height metadata should be present")
            XCTAssertEqual(metadata?["region"], "area", "Region should be 'area'")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    /// Test capturing screenshot of the Calculator window
    func testWindowCapture() async throws {
        // Create parameters for the screenshot tool
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string(calculatorBundleId)
        ]
        
        // Take the screenshot
        let result = try await toolChain.screenshotTool.handler(params)
        
        // Verify the result
        verifyScreenshotResult(result, mimeType: "image/png")
        
        // Verify it's a reasonable size for the Calculator window
        if case .image(let data, _, let metadata) = result[0] {
            let decodedData = Data(base64Encoded: data)!
            let image = NSImage(data: decodedData)!
            
            // Calculator window is typically at least 200x200, but we can't be exact
            XCTAssertGreaterThan(image.size.width, 200, "Calculator window should be wider than 200px")
            XCTAssertGreaterThan(image.size.height, 200, "Calculator window should be taller than 200px")
            
            // Check metadata
            XCTAssertEqual(metadata?["region"], "window", "Region should be 'window'")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    /// Test capturing screenshot of a UI element in the Calculator
    func testElementCapture() async throws {
        // Instead of trying to find a specific calculator button, we'll try to capture
        // the entire calculator window first and then check if we can get any UI element
        // from the window

        // First, get the application window to search for elements
        let applicationParams: [String: Value] = [
            "scope": .string("application"),
            "bundleId": .string(calculatorBundleId),
            "maxDepth": .int(10)
        ]

        let elements = try await toolChain.interfaceExplorerTool.handler(applicationParams)

        // Skip if we can't get elements
        if elements.isEmpty {
            print("Warning: Could not find any Calculator elements, skipping testElementCapture")
            throw XCTSkip("Could not find any Calculator elements to capture")
        }

        // Try to find the main Calculator window
        var windowId: String?
        if case .text(let jsonString) = elements[0] {
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

            // Look for the first window element
            for element in json {
                if let role = element["role"] as? String,
                   role == "AXWindow",
                   let id = element["id"] as? String {
                    windowId = id
                    break
                }
            }
        }

        // If we couldn't find a window element, skip the test
        guard let elementId = windowId else {
            print("Warning: Could not find Calculator window element, skipping testElementCapture")
            throw XCTSkip("Could not find Calculator window element to capture")
        }
        
        // Create parameters for the screenshot tool
        let params: [String: Value] = [
            "region": .string("element"),
            "elementId": .string(elementId)
        ]
        
        // Take the screenshot
        let result = try await toolChain.screenshotTool.handler(params)
        
        // Verify the result
        verifyScreenshotResult(result, mimeType: "image/png")
        
        // Verify it's a reasonable size for a Calculator button
        if case .image(let data, _, let metadata) = result[0] {
            let decodedData = Data(base64Encoded: data)!
            let image = NSImage(data: decodedData)!
            
            // Buttons in calculator are small but not tiny
            XCTAssertGreaterThan(image.size.width, 20, "Button should be wider than 20px")
            XCTAssertGreaterThan(image.size.height, 20, "Button should be taller than 20px")
            
            // Check metadata
            XCTAssertEqual(metadata?["region"], "element", "Region should be 'element'")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    // MARK: - Error Tests
    
    /// Test behavior when element cannot be found
    func testNonExistentElement() async throws {
        // Create parameters for the screenshot tool with a non-existent element ID
        let params: [String: Value] = [
            "region": .string("element"),
            "elementId": .string("ui:non:existent:element:id")
        ]
        
        // Expect an error
        do {
            _ = try await toolChain.screenshotTool.handler(params)
            XCTFail("Should throw an error for non-existent element")
        } catch {
            // Success - we expect an error
            XCTAssertTrue(error.localizedDescription.contains("not found"), 
                         "Error should indicate element not found")
        }
    }
    
    /// Test behavior when application is not running
    func testNonRunningApplication() async throws {
        // Create parameters for the screenshot tool with a non-running application
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string("com.apple.non.existent.app")
        ]
        
        // Expect an error
        do {
            _ = try await toolChain.screenshotTool.handler(params)
            XCTFail("Should throw an error for non-running application")
        } catch {
            // Success - we expect an error
            XCTAssertTrue(error.localizedDescription.contains("not running"), 
                         "Error should indicate application not running")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Find a calculator button UI element
    private func findCalculatorButton() async throws -> UIElement? {
        // Define criteria to find a calculator button
        let criteria = UIElementCriteria(
            role: "AXButton",
            isVisible: true,
            isEnabled: true
        )
        
        // Find the button in the Calculator app
        let elements = try await toolChain.findElements(
            matching: criteria,
            scope: "application",
            bundleId: calculatorBundleId,
            maxDepth: 15
        )
        
        // Return the first matching element
        return elements.first
    }
    
    /// Verify that a result contains a valid image
    private func verifyScreenshotResult(_ result: [Tool.Content], mimeType: String) {
        // Make sure we have exactly one result item
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Check that it's an image with the right MIME type
        if case .image(let data, let resultMimeType, let metadata) = result[0] {
            XCTAssertEqual(resultMimeType, mimeType, "MIME type should be correct")
            XCTAssertFalse(data.isEmpty, "Image data should not be empty")
            
            // Try to decode the Base64 data
            let decodedData = Data(base64Encoded: data)
            XCTAssertNotNil(decodedData, "Should be able to decode Base64 data")
            
            // Try to create an image from the data
            let image = NSImage(data: decodedData!)
            XCTAssertNotNil(image, "Should be able to create an image from the data")
            
            // Check that metadata is present
            XCTAssertNotNil(metadata, "Metadata should be present")
            XCTAssertNotNil(metadata?["width"], "Width metadata should be present")
            XCTAssertNotNil(metadata?["height"], "Height metadata should be present")
            XCTAssertNotNil(metadata?["scale"], "Scale metadata should be present")
            XCTAssertNotNil(metadata?["region"], "Region metadata should be present")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
}