// ABOUTME: ClipboardManagementToolTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import MCP
import Testing

@testable import MacMCP

// Test utilities are directly available in this module

@Suite(.serialized) struct ClipboardManagementToolTests {
  // System under test
  private var tool: ClipboardManagementTool!

  // Mock dependencies
  private var mockClipboardService: MockClipboardService!

  private mutating func setupTest() async throws {
    mockClipboardService = MockClipboardService()
    tool = ClipboardManagementTool(clipboardService: mockClipboardService)
  }

  // MARK: - Tool Configuration Tests

  @Test("Test tool name") mutating func testToolName() async throws {
    try await setupTest()
    #expect(tool.name == ToolNames.clipboardManagement)
  }

  @Test("Test tool description") mutating func testToolDescription() async throws {
    try await setupTest()
    #expect(!tool.description.isEmpty, "Tool should have a description")
  }

  @Test("Test input schema") mutating func testInputSchema() async throws {
    try await setupTest()
    let schema = tool.inputSchema

    // Verify schema is a dictionary with expected properties
    guard case .object = schema else {
      #expect(Bool(false), "Schema should be an object")
      return
    }

    // We know the schema is a Value.object, but the specific structure
    // depends on the MCP library implementation. Since .type and .required
    // aren't directly available, we'll check using the serialized representation.

    // Convert to a string representation to check the content
    let schemaString = String(describing: schema)

    // Verify schema has type: "object"
    #expect(schemaString.contains("object"), "Schema should have type object")

    // Verify schema defines expected actions
    let expectedActions = [
      "getInfo", "getText", "setText", "getImage", "setImage", "getFiles", "setFiles", "clear",
    ]

    for action in expectedActions {
      #expect(schemaString.contains(action), "Schema should support \(action) action")
    }
  }

  // MARK: - Action Validation Tests

  @Test("Test execute with invalid action") mutating func testExecuteWithInvalidAction()
    async throws
  {
    try await setupTest()
    do {
      let input = ["action": "invalidAction"]
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for invalid action")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain action-related information
        // rather than specific error code INVALID_ACTION
        #expect(message?.contains("action") ?? false, "Error should mention 'action'")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  @Test("Test execute with missing action") mutating func testExecuteWithMissingAction()
    async throws
  {
    try await setupTest()
    do {
      let input: [String: Any] = [:]
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for missing action")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain action-related information
        // rather than specific error code INVALID_ACTION
        #expect(message?.contains("action") ?? false, "Error should mention 'action'")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  // MARK: - GetInfo Tests

  @Test("Test getInfo") mutating func testGetInfo() async throws {
    try await setupTest()
    let input = ["action": "getInfo"]

    // Reset the call count to ensure it starts at 0
    await mockClipboardService.resetGetInfoCallCount()

    // Configure mock with 3 types
    await mockClipboardService.setInfoToReturn(
      ClipboardContentInfo(availableTypes: [.text, .image, .files], isEmpty: false, )
    )

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls - should be exactly 1 call
    let infoCallCount = await mockClipboardService.getInfoCallCount
    #expect(infoCallCount == 1, "getClipboardInfo() should be called exactly once")

    // Verify result - should have 3 types
    let availableTypes = result["availableTypes"] as? [String]
    #expect(availableTypes != nil, "Result should contain availableTypes")
    #expect(availableTypes?.count == 3, "Should have 3 types: text, image, files")
    #expect(availableTypes?.contains("text") ?? false, "Available types should include 'text'")
    #expect(availableTypes?.contains("image") ?? false, "Available types should include 'image'")
    #expect(availableTypes?.contains("files") ?? false, "Available types should include 'files'")
    #expect(result["isEmpty"] as? Bool == false, "isEmpty should be false")
  }

  @Test("Test getInfo error") mutating func testGetInfoError() async throws {
    try await setupTest()
    let input = ["action": "getInfo"]

    // Reset the call count
    await mockClipboardService.resetGetInfoCallCount()

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnGetInfo(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error is expected, verify the service was called
      let callCount = await mockClipboardService.getInfoCallCount
      #expect(callCount == 1, "getClipboardInfo() should be called exactly once")

      // We don't need to assert anything about the error itself
      // Just the fact that an error was thrown is sufficient
    }
  }

  // MARK: - GetText Tests

  @Test("Test getText") mutating func testGetText() async throws {
    try await setupTest()
    let input = ["action": "getText"]

    // Configure mock
    await mockClipboardService.setTextToReturn("Test clipboard text")

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let textCallCount = await mockClipboardService.getTextCallCount
    #expect(textCallCount == 1)

    // Verify result
    #expect(result["text"] as? String == "Test clipboard text")
  }

  @Test("Test getText error") mutating func testGetTextError() async throws {
    try await setupTest()
    let input = ["action": "getText"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnGetText(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let textCallCount = await mockClipboardService.getTextCallCount
      #expect(textCallCount == 1)
    }
  }

  // MARK: - SetText Tests

  @Test("Test setText") mutating func testSetText() async throws {
    try await setupTest()
    let input: [String: Any] = ["action": "setText", "text": "New clipboard text"]

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let setTextCallCount = await mockClipboardService.setTextCallCount
    let lastTextSet = await mockClipboardService.lastTextSet
    #expect(setTextCallCount == 1)
    #expect(lastTextSet == "New clipboard text")

    // Verify result
    #expect(result["success"] as? Bool == true)
  }

  @Test("Test setText missing text") mutating func testSetTextMissingText() async throws {
    try await setupTest()
    let input = ["action": "setText"]

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for missing text parameter")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain text-related information
        // rather than specific error code MISSING_TEXT
        #expect(message?.contains("text") ?? false, "Error should mention 'text'")
        // Verify service was not called
        let setTextCallCount = await mockClipboardService.setTextCallCount
        #expect(setTextCallCount == 0, "Service should not be called when parameters are missing")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  @Test("Test setText error") mutating func testSetTextError() async throws {
    try await setupTest()
    let input: [String: Any] = ["action": "setText", "text": "Test text"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnSetText(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let setTextCallCount = await mockClipboardService.setTextCallCount
      #expect(setTextCallCount == 1)
    }
  }

  // MARK: - GetImage Tests

  @Test("Test getImage") mutating func testGetImage() async throws {
    try await setupTest()
    let input = ["action": "getImage"]

    // Configure mock
    let base64Image = "base64EncodedImageDataMock"
    await mockClipboardService.setImageToReturn(base64Image)

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let getImageCallCount = await mockClipboardService.getImageCallCount
    #expect(getImageCallCount == 1)

    // Verify result
    #expect(result["imageData"] as? String == base64Image)
  }

  @Test("Test getImage error") mutating func testGetImageError() async throws {
    try await setupTest()
    let input = ["action": "getImage"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnGetImage(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let getImageCallCount = await mockClipboardService.getImageCallCount
      #expect(getImageCallCount == 1)
    }
  }

  // MARK: - SetImage Tests

  @Test("Test setImage") mutating func testSetImage() async throws {
    try await setupTest()
    let base64Image = "base64EncodedImageData"
    let input: [String: Any] = ["action": "setImage", "imageData": base64Image]

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let setImageCallCount = await mockClipboardService.setImageCallCount
    let lastImageSet = await mockClipboardService.lastImageSet
    #expect(setImageCallCount == 1)
    #expect(lastImageSet == base64Image)

    // Verify result
    #expect(result["success"] as? Bool == true)
  }

  @Test("Test setImage missing imageData") mutating func testSetImageMissingImageData() async throws
  {
    try await setupTest()
    let input = ["action": "setImage"]

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for missing imageData parameter")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain imageData-related information
        // rather than specific error code MISSING_IMAGE_DATA
        #expect(message?.contains("imageData") ?? false, "Error should mention 'imageData'")
        // Verify service was not called
        let setImageCallCount = await mockClipboardService.setImageCallCount
        #expect(setImageCallCount == 0, "Service should not be called when parameters are missing")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  @Test("Test setImage error") mutating func testSetImageError() async throws {
    try await setupTest()
    let input: [String: Any] = ["action": "setImage", "imageData": "testImageData"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnSetImage(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let setImageCallCount = await mockClipboardService.setImageCallCount
      #expect(setImageCallCount == 1)
    }
  }

  // MARK: - GetFiles Tests

  @Test("Test getFiles") mutating func testGetFiles() async throws {
    try await setupTest()
    let input = ["action": "getFiles"]

    // Configure mock
    let filePaths = ["/path/to/file1.txt", "/path/to/file2.txt"]
    await mockClipboardService.setFilesToReturn(filePaths)

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let getFilesCallCount = await mockClipboardService.getFilesCallCount
    #expect(getFilesCallCount == 1)

    // Verify result
    let resultPaths = result["filePaths"] as? [String]
    #expect(resultPaths != nil)
    #expect(resultPaths == filePaths)
  }

  @Test("Test getFiles error") mutating func testGetFilesError() async throws {
    try await setupTest()
    let input = ["action": "getFiles"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnGetFiles(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let getFilesCallCount = await mockClipboardService.getFilesCallCount
      #expect(getFilesCallCount == 1)
    }
  }

  // MARK: - SetFiles Tests

  @Test("Test setFiles") mutating func testSetFiles() async throws {
    try await setupTest()
    let filePaths = ["/path/to/file1.txt", "/path/to/file2.txt"]
    let input: [String: Any] = ["action": "setFiles", "filePaths": filePaths]

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let setFilesCallCount = await mockClipboardService.setFilesCallCount
    let lastFilesSet = await mockClipboardService.lastFilesSet
    #expect(setFilesCallCount == 1)
    #expect(lastFilesSet == filePaths)

    // Verify result
    #expect(result["success"] as? Bool == true)
  }

  @Test("Test setFiles missing filePaths") mutating func testSetFilesMissingFilePaths() async throws
  {
    try await setupTest()
    let input = ["action": "setFiles"]

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for missing filePaths parameter")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain filePaths-related information
        // rather than specific error code MISSING_FILE_PATHS
        #expect(message?.contains("filePaths") ?? false, "Error should mention 'filePaths'")
        // Verify service was not called
        let setFilesCallCount = await mockClipboardService.setFilesCallCount
        #expect(setFilesCallCount == 0, "Service should not be called when parameters are missing")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  @Test("Test setFiles empty array") mutating func testSetFilesEmptyArray() async throws {
    try await setupTest()
    let input: [String: Any] = ["action": "setFiles", "filePaths": []]

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error for empty filePaths array")
    } catch let error as MCPError {
      if case .invalidParams(let message) = error {
        // The error message just needs to contain empty array related information
        // rather than specific error code EMPTY_FILE_PATHS
        #expect(
          message?.contains("empty") ?? false || message?.contains("filePaths") ?? false,
          "Error should mention empty array or filePaths",
        )
        // Verify service was not called
        let setFilesCallCount = await mockClipboardService.setFilesCallCount
        #expect(setFilesCallCount == 0, "Service should not be called with empty array")
      } else {
        #expect(Bool(false), "Wrong error type thrown: \(error)")
      }
    } catch { #expect(Bool(false), "Unexpected error: \(error)") }
  }

  @Test("Test setFiles error") mutating func testSetFilesError() async throws {
    try await setupTest()
    let input: [String: Any] = ["action": "setFiles", "filePaths": ["/path/to/file.txt"]]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnSetFiles(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let setFilesCallCount = await mockClipboardService.setFilesCallCount
      #expect(setFilesCallCount == 1)
    }
  }

  // MARK: - Clear Tests

  @Test("Test clear") mutating func testClear() async throws {
    try await setupTest()
    let input = ["action": "clear"]

    // Execute
    let result = try await tool.execute(with: input, env: [:])

    // Verify service calls
    let clearCallCount = await mockClipboardService.clearCallCount
    #expect(clearCallCount == 1)

    // Verify result
    #expect(result["success"] as? Bool == true)
  }

  @Test("Test clear error") mutating func testClearError() async throws {
    try await setupTest()
    let input = ["action": "clear"]

    // Configure mock to throw
    await mockClipboardService.setShouldThrowOnClear(true)

    do {
      _ = try await tool.execute(with: input, env: [:])
      #expect(Bool(false), "Should have thrown an error")
    } catch {
      // Error expected
      let clearCallCount = await mockClipboardService.clearCallCount
      #expect(clearCallCount == 1)
    }
  }
}
