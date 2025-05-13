// ABOUTME: This file contains tests for the ScreenshotTool functionality.
// ABOUTME: It verifies the tool's ability to capture screenshots of different regions and types.

import XCTest
import Foundation
import MCP
import Logging
import AppKit
@testable import MacMCP

/// Mock of the ScreenshotService for testing ScreenshotTool
private class MockScreenshotService: ScreenshotServiceProtocol {
    // MARK: - Test Control Properties
    
    // Mock data to return
    var mockFullScreenResult: ScreenshotResult?
    var mockAreaResult: ScreenshotResult?
    var mockWindowResult: ScreenshotResult?
    var mockElementResult: ScreenshotResult?
    
    // Tracking properties
    var captureFullScreenCalled = false
    var captureAreaCalled = false
    var captureWindowCalled = false
    var captureElementCalled = false
    
    // Captured parameters
    var capturedAreaX: Int?
    var capturedAreaY: Int?
    var capturedAreaWidth: Int?
    var capturedAreaHeight: Int?
    var capturedWindowBundleIdentifier: String?
    var capturedElementId: String?
    
    // Error control
    var shouldFailOperations = false
    var errorToThrow: MCPError?
    
    // MARK: - ScreenshotServiceProtocol Implementation
    
    func captureFullScreen() async throws -> ScreenshotResult {
        captureFullScreenCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error for test")
        }
        
        return mockFullScreenResult ?? createMockScreenshotResult(width: 1920, height: 1080)
    }
    
    func captureArea(x: Int, y: Int, width: Int, height: Int) async throws -> ScreenshotResult {
        captureAreaCalled = true
        capturedAreaX = x
        capturedAreaY = y
        capturedAreaWidth = width
        capturedAreaHeight = height
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error for test")
        }
        
        return mockAreaResult ?? createMockScreenshotResult(width: width, height: height)
    }
    
    func captureWindow(bundleIdentifier: String) async throws -> ScreenshotResult {
        captureWindowCalled = true
        capturedWindowBundleIdentifier = bundleIdentifier
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error for test")
        }
        
        return mockWindowResult ?? createMockScreenshotResult(width: 800, height: 600)
    }
    
    func captureElement(elementId: String) async throws -> ScreenshotResult {
        captureElementCalled = true
        capturedElementId = elementId
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error for test")
        }
        
        return mockElementResult ?? createMockScreenshotResult(width: 200, height: 100)
    }
    
    // MARK: - Helper Methods
    
    private func createMockScreenshotResult(width: Int, height: Int) -> ScreenshotResult {
        // Create a simple 1x1 pixel image
        let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        // Fill it with a basic color so we can identify it
        let nsImage = NSImage(size: NSSize(width: width, height: height))
        nsImage.addRepresentation(imageRep)
        
        // Draw a simple pattern in the image to make it unique and verifiable
        nsImage.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSColor.black.setFill()
        NSRect(x: 10, y: 10, width: min(width - 20, 50), height: min(height - 20, 50)).fill()
        nsImage.unlockFocus()
        
        // Get the PNG representation
        let imageData = nsImage.tiffRepresentation!
        let bitmapRep = NSBitmapImageRep(data: imageData)!
        let pngData = bitmapRep.representation(using: .png, properties: [:])!
        
        return ScreenshotResult(
            data: pngData, 
            width: width, 
            height: height, 
            scale: 1.0
        )
    }
}

/// Tests for the ScreenshotTool
final class ScreenshotToolTests: XCTestCase {
    // Test components
    private var mockScreenshotService: MockScreenshotService!
    private var screenshotTool: ScreenshotTool!
    
    override func setUp() {
        super.setUp()
        mockScreenshotService = MockScreenshotService()
        screenshotTool = ScreenshotTool(
            screenshotService: mockScreenshotService,
            logger: Logger(label: "test.screenshot")
        )
    }
    
    override func tearDown() {
        screenshotTool = nil
        mockScreenshotService = nil
        super.tearDown()
    }
    
    // MARK: - Test Methods
    
    /// Test capturing a full screen screenshot
    func testFullScreenCapture() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 1920, height: 1080),
            width: 1920,
            height: 1080,
            scale: 1.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockFullScreenResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("full")
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockScreenshotService.captureFullScreenCalled, "Should call captureFullScreen")
        
        // Verify the result content
        verifyImageResult(result, expectedWidth: 1920, expectedHeight: 1080, expectedRegion: "full")
    }
    
    /// Test capturing a screenshot of a specific area
    func testAreaCapture() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 500, height: 300),
            width: 500,
            height: 300,
            scale: 1.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockAreaResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("area"),
            "x": .int(100),
            "y": .int(200),
            "width": .int(500),
            "height": .int(300)
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockScreenshotService.captureAreaCalled, "Should call captureArea")
        XCTAssertEqual(mockScreenshotService.capturedAreaX, 100, "Wrong X coordinate")
        XCTAssertEqual(mockScreenshotService.capturedAreaY, 200, "Wrong Y coordinate")
        XCTAssertEqual(mockScreenshotService.capturedAreaWidth, 500, "Wrong width")
        XCTAssertEqual(mockScreenshotService.capturedAreaHeight, 300, "Wrong height")
        
        // Verify the result content
        verifyImageResult(result, expectedWidth: 500, expectedHeight: 300, expectedRegion: "area")
    }
    
    /// Test capturing a screenshot of an application window
    func testWindowCapture() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 800, height: 600),
            width: 800,
            height: 600,
            scale: 1.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockWindowResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockScreenshotService.captureWindowCalled, "Should call captureWindow")
        XCTAssertEqual(mockScreenshotService.capturedWindowBundleIdentifier, "com.apple.calculator", "Wrong bundle identifier")
        
        // Verify the result content
        verifyImageResult(result, expectedWidth: 800, expectedHeight: 600, expectedRegion: "window")
    }
    
    /// Test capturing a screenshot of a specific UI element
    func testElementCapture() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 200, height: 100),
            width: 200,
            height: 100,
            scale: 1.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockElementResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("element"),
            "elementId": .string("ui:AXButton:123456")
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockScreenshotService.captureElementCalled, "Should call captureElement")
        XCTAssertEqual(mockScreenshotService.capturedElementId, "ui:AXButton:123456", "Wrong element ID")
        
        // Verify the result content
        verifyImageResult(result, expectedWidth: 200, expectedHeight: 100, expectedRegion: "element")
    }
    
    // MARK: - Parameter Validation Tests
    
    /// Test missing region parameter
    func testMissingRegion() async throws {
        // Create parameters without region
        let params: [String: Value] = [:]
        
        // Test that parameter validation works
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error for missing region")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Region is required") ?? false, "Error should indicate missing region")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test invalid region parameter
    func testInvalidRegion() async throws {
        // Create parameters with invalid region
        let params: [String: Value] = [
            "region": .string("invalid")
        ]
        
        // Test that parameter validation works
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error for invalid region")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Invalid region") ?? false, "Error should indicate invalid region")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test missing area coordinates
    func testMissingAreaCoordinates() async throws {
        // Create parameters without coordinates
        let params: [String: Value] = [
            "region": .string("area")
        ]
        
        // Test that parameter validation works
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error for missing coordinates")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Area screenshots require x, y, width, and height parameters") ?? false, "Error should indicate missing coordinates")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test missing bundle ID for window screenshots
    func testMissingBundleId() async throws {
        // Create parameters without bundle ID
        let params: [String: Value] = [
            "region": .string("window")
        ]
        
        // Test that parameter validation works
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error for missing bundle ID")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Window screenshots require a bundleId parameter") ?? false, "Error should indicate missing bundle ID")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test missing element ID for element screenshots
    func testMissingElementId() async throws {
        // Create parameters without element ID
        let params: [String: Value] = [
            "region": .string("element")
        ]
        
        // Test that parameter validation works
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error for missing element ID")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Element screenshots require an elementId parameter") ?? false, "Error should indicate missing element ID")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test service error handling
    func testServiceErrors() async throws {
        // Configure mock to fail with a specific error
        mockScreenshotService.shouldFailOperations = true
        mockScreenshotService.errorToThrow = MCPError.internalError("Test error message")
        
        // Create parameters for a full screen screenshot
        let params: [String: Value] = [
            "region": .string("full")
        ]
        
        // Test that the error is propagated
        do {
            _ = try await screenshotTool.handler(params)
            XCTFail("Should throw an error")
        } catch let error as MCPError {
            // For MCPError we can check the specific case
            switch error {
            case .internalError(let message):
                XCTAssertTrue(message?.contains("Test error message") ?? false,
                              "Error should include the original error message")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Real-World Testing
    
    /// Test MCP message format - all critical fields should be present
    func testMcpMessageFormat() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 800, height: 600),
            width: 800,
            height: 600,
            scale: 2.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockWindowResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("window"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify we have an image content item
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Check the basics
            XCTAssertFalse(data.isEmpty, "Image data should not be empty")
            XCTAssertEqual(mimeType, "image/png", "MIME type should be PNG")
            
            // Check the required metadata fields
            XCTAssertNotNil(metadata?["width"], "Width metadata should be present")
            XCTAssertNotNil(metadata?["height"], "Height metadata should be present")
            XCTAssertNotNil(metadata?["scale"], "Scale metadata should be present")
            XCTAssertNotNil(metadata?["region"], "Region metadata should be present")
            
            // Check the values
            XCTAssertEqual(metadata?["width"], "800", "Width should be correct")
            XCTAssertEqual(metadata?["height"], "600", "Height should be correct")
            XCTAssertEqual(metadata?["scale"], "2.00", "Scale should be correct")
            XCTAssertEqual(metadata?["region"], "window", "Region should be correct")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    /// Tests creation of decodable PNG data
    func testImageDataValidity() async throws {
        // Create a mock screenshot result with specific dimensions to verify
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 640, height: 480),
            width: 640,
            height: 480,
            scale: 1.0
        )
        
        // Set up the mock service to return our result
        mockScreenshotService.mockFullScreenResult = mockResult
        
        // Create parameters for the tool
        let params: [String: Value] = [
            "region": .string("full")
        ]
        
        // Execute the test
        let result = try await screenshotTool.handler(params)
        
        // Verify we have an image content item
        if case .image(let data, let mimeType, _) = result[0] {
            // Check MIME type
            XCTAssertEqual(mimeType, "image/png", "MIME type should be PNG")
            
            // Try to decode the Base64 data
            let decodedData = Data(base64Encoded: data)
            XCTAssertNotNil(decodedData, "Should be able to decode Base64 data")
            
            // Try to create an image from the data
            let image = NSImage(data: decodedData!)
            XCTAssertNotNil(image, "Should be able to create an image from the data")
            
            // Verify image dimensions
            XCTAssertEqual(Int(image!.size.width), 640, "Image width should match")
            XCTAssertEqual(Int(image!.size.height), 480, "Image height should match")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    // MARK: - Integration with stdio transport
    
    /// Test whether the tool works correctly with the stdio MCP transport protocol
    func testStdioTransportCompatibility() async throws {
        // This test checks that the image data can be properly serialized to JSON
        // for the stdio transport, by comparing a serialized content item with
        // what would be returned from the actual handler
        
        // Create a mock screenshot result
        let mockResult = ScreenshotResult(
            data: createTestImage(width: 320, height: 240),
            width: 320,
            height: 240,
            scale: 1.0
        )
        
        // Set it in our mock service
        mockScreenshotService.mockFullScreenResult = mockResult
        
        // Call the handler to get the content
        let params: [String: Value] = ["region": .string("full")]
        let result = try await screenshotTool.handler(params)
        
        // Convert the content item to JSON
        if case .image(let base64Data, let mimeType, let metadata) = result[0] {
            // Create a dictionary representation of the content item
            let contentDict: [String: Any] = [
                "type": "image", 
                "data": base64Data,
                "mime_type": mimeType,
                "metadata": metadata ?? [:]
            ]
            
            // Try to serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: contentDict)
            
            // Make sure it's valid JSON
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: jsonData), 
                            "Should be able to parse the JSON")
            
            // Deserialize to verify structure
            let parsedDict = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            // Verify all fields are present and have the right types
            XCTAssertEqual(parsedDict["type"] as? String, "image", "Type should be image")
            XCTAssertEqual(parsedDict["mime_type"] as? String, "image/png", "MIME type should be PNG")
            XCTAssertNotNil(parsedDict["data"], "Data should be present")
            XCTAssertNotNil(parsedDict["metadata"], "Metadata should be present")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a test image with the specified dimensions
    private func createTestImage(width: Int, height: Int) -> Data {
        let imageRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        
        let nsImage = NSImage(size: NSSize(width: width, height: height))
        nsImage.addRepresentation(imageRep)
        
        // Draw something in the image to make it non-empty
        nsImage.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        NSColor.systemBlue.setFill()
        NSRect(x: 20, y: 20, width: width - 40, height: height - 40).fill()
        nsImage.unlockFocus()
        
        let imageData = nsImage.tiffRepresentation!
        let bitmapRep = NSBitmapImageRep(data: imageData)!
        return bitmapRep.representation(using: .png, properties: [:])!
    }
    
    /// Verify that a result contains an image with the expected properties
    private func verifyImageResult(_ result: [Tool.Content], expectedWidth: Int, expectedHeight: Int, expectedRegion: String) {
        if case .image(let data, let mimeType, let metadata) = result[0] {
            // Check the basics
            XCTAssertFalse(data.isEmpty, "Image data should not be empty")
            XCTAssertEqual(mimeType, "image/png", "MIME type should be PNG")
            
            // Check the metadata
            XCTAssertEqual(metadata?["width"], "\(expectedWidth)", "Width should match")
            XCTAssertEqual(metadata?["height"], "\(expectedHeight)", "Height should match")
            XCTAssertEqual(metadata?["region"], expectedRegion, "Region should match")
        } else {
            XCTFail("Result should be an image content item")
        }
    }
}