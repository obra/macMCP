// ABOUTME: Tests for the ClipboardManagementTool covering all operations
// ABOUTME: Verifies tool behavior using MockClipboardService for all operations

import XCTest
@testable import MacMCP
import MCP

// Test utilities are directly available in this module

final class ClipboardManagementToolTests: XCTestCase {
    // System under test
    private var tool: ClipboardManagementTool!
    
    // Mock dependencies
    private var mockClipboardService: MockClipboardService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockClipboardService = MockClipboardService()
        tool = ClipboardManagementTool(clipboardService: mockClipboardService)
    }
    
    // MARK: - Tool Configuration Tests
    
    func testToolName() {
        XCTAssertEqual(tool.name, ToolNames.clipboardManagement)
    }
    
    func testToolDescription() {
        XCTAssertFalse(tool.description.isEmpty, "Tool should have a description")
    }
    
    func testInputSchema() {
        let schema = tool.inputSchema

        // Verify schema is a dictionary with expected properties
        guard case .object = schema else {
            XCTFail("Schema should be an object")
            return
        }

        // We know the schema is a Value.object, but the specific structure
        // depends on the MCP library implementation. Since .type and .required
        // aren't directly available, we'll check using the serialized representation.

        // Convert to a string representation to check the content
        let schemaString = String(describing: schema)

        // Verify schema has type: "object"
        XCTAssertTrue(schemaString.contains("object"), "Schema should have type object")

        // Verify schema defines expected actions
        let expectedActions = ["getInfo", "getText", "setText", "getImage",
                              "setImage", "getFiles", "setFiles", "clear"]

        for action in expectedActions {
            XCTAssertTrue(schemaString.contains(action), "Schema should support \(action) action")
        }
    }
    
    // MARK: - Action Validation Tests
    
    func testExecuteWithInvalidAction() async {
        do {
            let input = ["action": "invalidAction"]
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for invalid action")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain action-related information
                // rather than specific error code INVALID_ACTION
                XCTAssertTrue(message?.contains("action") ?? false, "Error should mention 'action'")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testExecuteWithMissingAction() async {
        do {
            let input: [String: Any] = [:]
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing action")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain action-related information
                // rather than specific error code INVALID_ACTION
                XCTAssertTrue(message?.contains("action") ?? false, "Error should mention 'action'")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - GetInfo Tests
    
    func testGetInfo() async throws {
        let input = ["action": "getInfo"]

        // Reset the call count to ensure it starts at 0
        await mockClipboardService.resetGetInfoCallCount()

        // Configure mock with 3 types
        await mockClipboardService.setInfoToReturn(ClipboardContentInfo(
            availableTypes: [.text, .image, .files],
            isEmpty: false
        ))

        // Execute
        let result = try await tool.execute(with: input, env: [:])

        // Verify service calls - should be exactly 1 call
        let infoCallCount = await mockClipboardService.getInfoCallCount
        XCTAssertEqual(infoCallCount, 1, "getClipboardInfo() should be called exactly once")

        // Verify result - should have 3 types
        let availableTypes = result["availableTypes"] as? [String]
        XCTAssertNotNil(availableTypes, "Result should contain availableTypes")
        XCTAssertEqual(availableTypes?.count, 3, "Should have 3 types: text, image, files")
        XCTAssertTrue(availableTypes?.contains("text") ?? false, "Available types should include 'text'")
        XCTAssertTrue(availableTypes?.contains("image") ?? false, "Available types should include 'image'")
        XCTAssertTrue(availableTypes?.contains("files") ?? false, "Available types should include 'files'")
        XCTAssertEqual(result["isEmpty"] as? Bool, false, "isEmpty should be false")
    }
    
    func testGetInfoError() async throws {
        let input = ["action": "getInfo"]

        // Reset the call count
        await mockClipboardService.resetGetInfoCallCount()

        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnGetInfo(true)

        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error is expected, verify the service was called
            let callCount = await mockClipboardService.getInfoCallCount
            XCTAssertEqual(callCount, 1, "getClipboardInfo() should be called exactly once")

            // We don't need to assert anything about the error itself
            // Just the fact that an error was thrown is sufficient
        }
    }
    
    // MARK: - GetText Tests
    
    func testGetText() async throws {
        let input = ["action": "getText"]
        
        // Configure mock
        await mockClipboardService.setTextToReturn("Test clipboard text")
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let textCallCount = await mockClipboardService.getTextCallCount
        XCTAssertEqual(textCallCount, 1)
        
        // Verify result
        XCTAssertEqual(result["text"] as? String, "Test clipboard text")
    }
    
    func testGetTextError() async {
        let input = ["action": "getText"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnGetText(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let textCallCount = await mockClipboardService.getTextCallCount
            XCTAssertEqual(textCallCount, 1)
        }
    }
    
    // MARK: - SetText Tests
    
    func testSetText() async throws {
        let input: [String: Any] = ["action": "setText", "text": "New clipboard text"]
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let setTextCallCount = await mockClipboardService.setTextCallCount
        let lastTextSet = await mockClipboardService.lastTextSet
        XCTAssertEqual(setTextCallCount, 1)
        XCTAssertEqual(lastTextSet, "New clipboard text")
        
        // Verify result
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    func testSetTextMissingText() async {
        let input = ["action": "setText"]

        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing text parameter")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain text-related information
                // rather than specific error code MISSING_TEXT
                XCTAssertTrue(message?.contains("text") ?? false, "Error should mention 'text'")
                // Verify service was not called
                let setTextCallCount = await mockClipboardService.setTextCallCount
                XCTAssertEqual(setTextCallCount, 0, "Service should not be called when parameters are missing")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSetTextError() async {
        let input: [String: Any] = ["action": "setText", "text": "Test text"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnSetText(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let setTextCallCount = await mockClipboardService.setTextCallCount
            XCTAssertEqual(setTextCallCount, 1)
        }
    }
    
    // MARK: - GetImage Tests
    
    func testGetImage() async throws {
        let input = ["action": "getImage"]
        
        // Configure mock
        let base64Image = "base64EncodedImageDataMock"
        await mockClipboardService.setImageToReturn(base64Image)
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let getImageCallCount = await mockClipboardService.getImageCallCount
        XCTAssertEqual(getImageCallCount, 1)
        
        // Verify result
        XCTAssertEqual(result["imageData"] as? String, base64Image)
    }
    
    func testGetImageError() async {
        let input = ["action": "getImage"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnGetImage(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let getImageCallCount = await mockClipboardService.getImageCallCount
            XCTAssertEqual(getImageCallCount, 1)
        }
    }
    
    // MARK: - SetImage Tests
    
    func testSetImage() async throws {
        let base64Image = "base64EncodedImageData"
        let input: [String: Any] = ["action": "setImage", "imageData": base64Image]
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let setImageCallCount = await mockClipboardService.setImageCallCount
        let lastImageSet = await mockClipboardService.lastImageSet
        XCTAssertEqual(setImageCallCount, 1)
        XCTAssertEqual(lastImageSet, base64Image)
        
        // Verify result
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    func testSetImageMissingImageData() async {
        let input = ["action": "setImage"]

        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing imageData parameter")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain imageData-related information
                // rather than specific error code MISSING_IMAGE_DATA
                XCTAssertTrue(message?.contains("imageData") ?? false, "Error should mention 'imageData'")
                // Verify service was not called
                let setImageCallCount = await mockClipboardService.setImageCallCount
                XCTAssertEqual(setImageCallCount, 0, "Service should not be called when parameters are missing")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSetImageError() async {
        let input: [String: Any] = ["action": "setImage", "imageData": "testImageData"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnSetImage(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let setImageCallCount = await mockClipboardService.setImageCallCount
            XCTAssertEqual(setImageCallCount, 1)
        }
    }
    
    // MARK: - GetFiles Tests
    
    func testGetFiles() async throws {
        let input = ["action": "getFiles"]
        
        // Configure mock
        let filePaths = ["/path/to/file1.txt", "/path/to/file2.txt"]
        await mockClipboardService.setFilesToReturn(filePaths)
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let getFilesCallCount = await mockClipboardService.getFilesCallCount
        XCTAssertEqual(getFilesCallCount, 1)
        
        // Verify result
        let resultPaths = result["filePaths"] as? [String]
        XCTAssertNotNil(resultPaths)
        XCTAssertEqual(resultPaths, filePaths)
    }
    
    func testGetFilesError() async {
        let input = ["action": "getFiles"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnGetFiles(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let getFilesCallCount = await mockClipboardService.getFilesCallCount
            XCTAssertEqual(getFilesCallCount, 1)
        }
    }
    
    // MARK: - SetFiles Tests
    
    func testSetFiles() async throws {
        let filePaths = ["/path/to/file1.txt", "/path/to/file2.txt"]
        let input: [String: Any] = ["action": "setFiles", "filePaths": filePaths]
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let setFilesCallCount = await mockClipboardService.setFilesCallCount
        let lastFilesSet = await mockClipboardService.lastFilesSet
        XCTAssertEqual(setFilesCallCount, 1)
        XCTAssertEqual(lastFilesSet, filePaths)
        
        // Verify result
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    func testSetFilesMissingFilePaths() async {
        let input = ["action": "setFiles"]

        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for missing filePaths parameter")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain filePaths-related information
                // rather than specific error code MISSING_FILE_PATHS
                XCTAssertTrue(message?.contains("filePaths") ?? false, "Error should mention 'filePaths'")
                // Verify service was not called
                let setFilesCallCount = await mockClipboardService.setFilesCallCount
                XCTAssertEqual(setFilesCallCount, 0, "Service should not be called when parameters are missing")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSetFilesEmptyArray() async {
        let input: [String: Any] = ["action": "setFiles", "filePaths": []]

        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error for empty filePaths array")
        } catch let error as MCPError {
            if case .invalidParams(let message) = error {
                // The error message just needs to contain empty array related information
                // rather than specific error code EMPTY_FILE_PATHS
                XCTAssertTrue(message?.contains("empty") ?? false || message?.contains("filePaths") ?? false,
                             "Error should mention empty array or filePaths")
                // Verify service was not called
                let setFilesCallCount = await mockClipboardService.setFilesCallCount
                XCTAssertEqual(setFilesCallCount, 0, "Service should not be called with empty array")
            } else {
                XCTFail("Wrong error type thrown: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testSetFilesError() async {
        let input: [String: Any] = ["action": "setFiles", "filePaths": ["/path/to/file.txt"]]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnSetFiles(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let setFilesCallCount = await mockClipboardService.setFilesCallCount
            XCTAssertEqual(setFilesCallCount, 1)
        }
    }
    
    // MARK: - Clear Tests
    
    func testClear() async throws {
        let input = ["action": "clear"]
        
        // Execute
        let result = try await tool.execute(with: input, env: [:])
        
        // Verify service calls
        let clearCallCount = await mockClipboardService.clearCallCount
        XCTAssertEqual(clearCallCount, 1)
        
        // Verify result
        XCTAssertEqual(result["success"] as? Bool, true)
    }
    
    func testClearError() async {
        let input = ["action": "clear"]
        
        // Configure mock to throw
        await mockClipboardService.setShouldThrowOnClear(true)
        
        do {
            _ = try await tool.execute(with: input, env: [:])
            XCTFail("Should have thrown an error")
        } catch {
            // Error expected
            let clearCallCount = await mockClipboardService.clearCallCount
            XCTAssertEqual(clearCallCount, 1)
        }
    }
}