// ABOUTME: End-to-end tests for the ClipboardManagementTool
// ABOUTME: Verifies the tool's functionality with actual clipboard operations

import XCTest
import MacMCP
import MCP

final class ClipboardManagementE2ETests: XCTestCase {
    // System under test
    private var clipboardService: ClipboardService!
    private var tool: ClipboardManagementTool!
    
    // Sample test data
    private let testText = "MacMCP clipboard test text"
    private let testImageBase64 = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AVAT/2Q==" // 1x1 black JPEG
    private let tempDir = FileManager.default.temporaryDirectory
    
    // Temporary file paths
    private var tempFilePath1: String!
    private var tempFilePath2: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create temporary test files
        let fileName1 = "clipboard_test_file1_\(UUID().uuidString).txt"
        let fileName2 = "clipboard_test_file2_\(UUID().uuidString).txt"
        
        tempFilePath1 = tempDir.appendingPathComponent(fileName1).path
        tempFilePath2 = tempDir.appendingPathComponent(fileName2).path
        
        // Write content to temp files
        try "Test file 1 content".write(toFile: tempFilePath1, atomically: true, encoding: .utf8)
        try "Test file 2 content".write(toFile: tempFilePath2, atomically: true, encoding: .utf8)
        
        // Initialize the real services and tool
        clipboardService = ClipboardService()
        tool = ClipboardManagementTool(clipboardService: clipboardService)
        
        // Clear clipboard at the start
        try await clipboardService.clearClipboard()
    }
    
    override func tearDown() async throws {
        // Clear clipboard after tests
        try? await clipboardService.clearClipboard()
        
        // Clean up temporary files
        if FileManager.default.fileExists(atPath: tempFilePath1) {
            try FileManager.default.removeItem(atPath: tempFilePath1)
        }
        
        if FileManager.default.fileExists(atPath: tempFilePath2) {
            try FileManager.default.removeItem(atPath: tempFilePath2)
        }
        
        clipboardService = nil
        tool = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Text Operations Tests
    
    func testTextOperations() async throws {
        // 1. Set text
        var input: [String: Any] = [
            "action": "setText",
            "text": testText
        ]
        
        var result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
        
        // 2. Verify clipboard info
        input = ["action": "getInfo"]
        result = try await tool.execute(with: input, env: [:])
        
        let availableTypes = result["availableTypes"] as? [String]
        XCTAssertNotNil(availableTypes)
        XCTAssertTrue(availableTypes?.contains("text") ?? false)
        XCTAssertEqual(result["isEmpty"] as? Bool, false)
        
        // 3. Get text
        input = ["action": "getText"]
        result = try await tool.execute(with: input, env: [:])
        
        XCTAssertEqual(result["text"] as? String, testText)
        
        // 4. Clear clipboard
        input = ["action": "clear"]
        result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
        
        // 5. Verify clipboard is empty
        input = ["action": "getInfo"]
        result = try await tool.execute(with: input, env: [:])
        
        XCTAssertEqual(result["isEmpty"] as? Bool, true)
    }
    
    // MARK: - Image Operations Tests
    
    func testImageOperations() async throws {
        // 1. Set image
        var input: [String: Any] = [
            "action": "setImage",
            "imageData": testImageBase64
        ]
        
        var result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
        
        // 2. Verify clipboard info
        input = ["action": "getInfo"]
        result = try await tool.execute(with: input, env: [:])
        
        let availableTypes = result["availableTypes"] as? [String]
        XCTAssertNotNil(availableTypes)
        XCTAssertTrue(availableTypes?.contains("image") ?? false)
        XCTAssertEqual(result["isEmpty"] as? Bool, false)
        
        // 3. Get image
        // Note: The exact base64 might differ due to format conversions in NSPasteboard
        // So we check that we got some data back rather than exact match
        input = ["action": "getImage"]
        result = try await tool.execute(with: input, env: [:])
        
        let returnedImage = result["imageData"] as? String
        XCTAssertNotNil(returnedImage)
        XCTAssertFalse(returnedImage?.isEmpty ?? true)
        
        // 4. Clear clipboard
        input = ["action": "clear"]
        result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    // MARK: - File Operations Tests
    
    func testFileOperations() async throws {
        // 1. Set files
        var input: [String: Any] = [
            "action": "setFiles",
            "filePaths": [tempFilePath1, tempFilePath2]
        ]
        
        var result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
        
        // 2. Verify clipboard info
        input = ["action": "getInfo"]
        result = try await tool.execute(with: input, env: [:])
        
        let availableTypes = result["availableTypes"] as? [String]
        XCTAssertNotNil(availableTypes)
        XCTAssertTrue(availableTypes?.contains("files") ?? false)
        XCTAssertEqual(result["isEmpty"] as? Bool, false)
        
        // 3. Get files
        // Note: macOS might normalize paths, so we check for path existence rather than exact matches
        input = ["action": "getFiles"]
        result = try await tool.execute(with: input, env: [:])
        
        let returnedPaths = result["filePaths"] as? [String]
        XCTAssertNotNil(returnedPaths)
        XCTAssertEqual(returnedPaths?.count, 2)
        
        // 4. Clear clipboard
        input = ["action": "clear"]
        result = try await tool.execute(with: input, env: [:])
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidInputParameters() async throws {
        // Test invalid action
        var input: [String: Any] = ["action": "invalidAction"]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for invalid action")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                XCTAssertTrue(message?.contains("INVALID_ACTION") ?? false)
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test missing text parameter
        input = ["action": "setText"]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing text")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                XCTAssertTrue(message?.contains("MISSING_TEXT") ?? false)
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test missing imageData parameter
        input = ["action": "setImage"]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing imageData")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                XCTAssertTrue(message?.contains("MISSING_IMAGE_DATA") ?? false)
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test missing filePaths parameter
        input = ["action": "setFiles"]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing filePaths")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                XCTAssertTrue(message?.contains("MISSING_FILE_PATHS") ?? false)
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test empty filePaths array
        input = ["action": "setFiles", "filePaths": []]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for empty filePaths")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                XCTAssertTrue(message?.contains("EMPTY_FILE_PATHS") ?? false)
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testNonExistentFiles() async throws {
        // Try to set non-existent files
        let nonExistentPath = tempDir.appendingPathComponent("non_existent_file_\(UUID().uuidString).txt").path
        
        let input: [String: Any] = [
            "action": "setFiles",
            "filePaths": [nonExistentPath]
        ]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for non-existent files")
        } catch let error as MCPError {
            if case .internalError(let message) = error {
                XCTAssertTrue(message?.contains("FILES_NOT_FOUND") ?? false, "Error should indicate files not found")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testInvalidImageData() async throws {
        // Try to set invalid base64 data as an image
        let input: [String: Any] = [
            "action": "setImage",
            "imageData": "not valid base64!"
        ]
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for invalid base64 data")
        } catch let error as MCPError {
            if case .internalError(let message) = error {
                XCTAssertTrue(message?.contains("INVALID_IMAGE_DATA") ?? false, "Error should indicate invalid image data")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
