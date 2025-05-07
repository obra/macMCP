// ABOUTME: This file contains end-to-end tests for taking screenshots using the macOS Calculator.
// ABOUTME: It validates that MacMCP can correctly capture screenshots of UI elements in real applications.

import XCTest
import Foundation
import MCP
@testable import MacMCP

final class ScreenshotE2ETests: XCTestCase {
    // The Calculator app instance used for testing
    @MainActor static var calculator: CalculatorApp?
    
    // The screenshot tool for capturing images
    @MainActor static var screenshotTool: ScreenshotTool?
    
    // Setup - runs before all tests in the suite
    override class func setUp() {
        super.setUp()
        
        // Launch the Calculator app in a task
        Task { @MainActor in
            do {
                // Create the Calculator app and screenshot tool
                calculator = CalculatorApp()
                let accessibilityService = AccessibilityService()
                let screenshotService = ScreenshotService(accessibilityService: accessibilityService)
                screenshotTool = ScreenshotTool(screenshotService: screenshotService)
                
                // Launch the Calculator app
                _ = try await calculator?.launch()
                
                // Brief pause to ensure UI is fully loaded
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                XCTFail("Failed to set up Calculator app: \(error)")
            }
        }
    }
    
    // Teardown - runs after all tests in the suite
    override class func tearDown() {
        // Terminate the Calculator app
        Task { @MainActor in
            do {
                _ = try await calculator?.terminate()
                calculator = nil
                screenshotTool = nil
            } catch {
                print("Error during teardown: \(error)")
            }
        }
        
        super.tearDown()
    }
    
    // MARK: - Test Cases
    
    // Capture full screen screenshot
    @MainActor
    func testCaptureFullScreenScreenshot() async throws {
        guard let _ = Self.calculator, let screenshotTool = Self.screenshotTool else {
            throw XCTSkip("Calculator app or screenshot tool not available")
        }
        
        // Create input for capturing full screen
        let input: [String: Value] = [
            "region": .string("full")
        ]
        
        // Call the tool handler
        let result = try await screenshotTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Verify the image data
            XCTAssertFalse(data.isEmpty, "Screenshot data should not be empty")
            
            // Verify the MIME type
            XCTAssertEqual(mimeType, "image/png", "Screenshot should be a PNG image")
            
            // Verify metadata
            XCTAssertNotNil(metadata, "Screenshot should have metadata")
            
            if let metadata = metadata {
                // Check for required metadata fields
                XCTAssertNotNil(metadata["width"], "Screenshot should have width metadata")
                XCTAssertNotNil(metadata["height"], "Screenshot should have height metadata")
                
                // Check that dimensions are reasonable
                if let widthStr = metadata["width"], let width = Int(widthStr),
                   let heightStr = metadata["height"], let height = Int(heightStr) {
                    XCTAssertGreaterThan(width, 100, "Screenshot width should be reasonable")
                    XCTAssertGreaterThan(height, 100, "Screenshot height should be reasonable")
                }
            }
        } else {
            XCTFail("Expected image result")
        }
    }
    
    // Capture window screenshot
    @MainActor
    func testCaptureWindowScreenshot() async throws {
        guard let _ = Self.calculator, let screenshotTool = Self.screenshotTool else {
            throw XCTSkip("Calculator app or screenshot tool not available")
        }
        
        // Create input for capturing Calculator window
        let input: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string(CalculatorApp.bundleId)
        ]
        
        // Call the tool handler
        let result = try await screenshotTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Verify the image data
            XCTAssertFalse(data.isEmpty, "Screenshot data should not be empty")
            
            // Verify the MIME type
            XCTAssertEqual(mimeType, "image/png", "Screenshot should be a PNG image")
            
            // Verify metadata
            XCTAssertNotNil(metadata, "Screenshot should have metadata")
            
            if let metadata = metadata {
                // Check for required metadata fields
                XCTAssertNotNil(metadata["width"], "Screenshot should have width metadata")
                XCTAssertNotNil(metadata["height"], "Screenshot should have height metadata")
                
                // Check that dimensions are reasonable for Calculator window
                if let widthStr = metadata["width"], let width = Int(widthStr),
                   let heightStr = metadata["height"], let height = Int(heightStr) {
                    
                    // Calculator window is fairly small but not tiny
                    XCTAssertGreaterThan(width, 50, "Calculator width should be reasonable")
                    XCTAssertGreaterThan(height, 50, "Calculator height should be reasonable")
                    
                    // Calculator window is smaller than the full screen
                    XCTAssertLessThan(width * height, 1920 * 1080, 
                                     "Calculator window should be smaller than full screen")
                }
            }
        } else {
            XCTFail("Expected image result")
        }
    }
    
    // Capture area screenshot
    @MainActor
    func testCaptureAreaScreenshot() async throws {
        guard let calculator = Self.calculator, let screenshotTool = Self.screenshotTool else {
            throw XCTSkip("Calculator app or screenshot tool not available")
        }
        
        // Get the main window to find its position
        guard let window = try await calculator.getMainWindow() else {
            XCTFail("Failed to get Calculator main window")
            return
        }
        
        // Define an area that likely contains the calculator (centered on the window)
        let x = Int(window.frame.origin.x)
        let y = Int(window.frame.origin.y)
        let width = Int(window.frame.size.width)
        let height = Int(window.frame.size.height)
        
        // Create input for capturing area
        let input: [String: Value] = [
            "region": .string("area"),
            "x": .int(x),
            "y": .int(y),
            "width": .int(width),
            "height": .int(height)
        ]
        
        // Call the tool handler
        let result = try await screenshotTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Verify the image data
            XCTAssertFalse(data.isEmpty, "Screenshot data should not be empty")
            
            // Verify the MIME type
            XCTAssertEqual(mimeType, "image/png", "Screenshot should be a PNG image")
            
            // Verify metadata
            XCTAssertNotNil(metadata, "Screenshot should have metadata")
            
            if let metadata = metadata {
                // Check for required metadata fields
                XCTAssertNotNil(metadata["width"], "Screenshot should have width metadata")
                XCTAssertNotNil(metadata["height"], "Screenshot should have height metadata")
                
                // Check dimensions approximately match input
                if let widthStr = metadata["width"], let resultWidth = Int(widthStr),
                   let heightStr = metadata["height"], let resultHeight = Int(heightStr) {
                    
                    // Allow some flexibility in dimensions due to screen scaling
                    XCTAssertEqual(resultWidth, width, accuracy: width / 5, 
                                 "Screenshot width should approximately match requested width")
                    XCTAssertEqual(resultHeight, height, accuracy: height / 5, 
                                 "Screenshot height should approximately match requested height")
                }
            }
        } else {
            XCTFail("Expected image result")
        }
    }
    
    // Capture button element screenshot
    @MainActor
    func testCaptureButtonElementScreenshot() async throws {
        guard let calculator = Self.calculator, let screenshotTool = Self.screenshotTool else {
            throw XCTSkip("Calculator app or screenshot tool not available")
        }
        
        // Try to get the "5" button element
        guard let buttonFive = try await calculator.getButton(identifier: "5") else {
            XCTFail("Failed to find '5' button in Calculator")
            return
        }
        
        // Create input for capturing element
        let input: [String: Value] = [
            "region": .string("element"),
            "elementId": .string(buttonFive.identifier)
        ]
        
        // Call the tool handler
        let result = try await screenshotTool.handler(input)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Expected 1 result item")
        
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Verify the image data
            XCTAssertFalse(data.isEmpty, "Screenshot data should not be empty")
            
            // Verify the MIME type
            XCTAssertEqual(mimeType, "image/png", "Screenshot should be a PNG image")
            
            // Verify metadata
            XCTAssertNotNil(metadata, "Screenshot should have metadata")
            
            if let metadata = metadata {
                // Check for required metadata fields
                XCTAssertNotNil(metadata["width"], "Screenshot should have width metadata")
                XCTAssertNotNil(metadata["height"], "Screenshot should have height metadata")
                
                // Check dimensions are reasonable for a button
                if let widthStr = metadata["width"], let resultWidth = Int(widthStr),
                   let heightStr = metadata["height"], let resultHeight = Int(heightStr) {
                    
                    // Button should be very small compared to the full screen
                    XCTAssertGreaterThan(resultWidth, 5, "Button width should be reasonable")
                    XCTAssertGreaterThan(resultHeight, 5, "Button height should be reasonable")
                    XCTAssertLessThan(resultWidth, 200, "Button width should be reasonable")
                    XCTAssertLessThan(resultHeight, 200, "Button height should be reasonable")
                }
            }
        } else {
            XCTFail("Expected image result")
        }
    }
}