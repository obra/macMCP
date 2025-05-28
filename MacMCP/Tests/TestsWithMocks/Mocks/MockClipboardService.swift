// ABOUTME: MockClipboardService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP
import MacMCP

/// Mock implementation of ClipboardServiceProtocol for testing
public actor MockClipboardService: ClipboardServiceProtocol {
  // Call tracking
  public var getTextCallCount = 0
  public var setTextCallCount = 0
  public var getImageCallCount = 0
  public var setImageCallCount = 0
  public var getFilesCallCount = 0
  public var setFilesCallCount = 0
  public var clearCallCount = 0
  public var getInfoCallCount = 0

  // Parameter tracking
  public var lastTextSet: String?
  public var lastImageSet: String?
  public var lastFilesSet: [String]?

  // Mock responses - private variables
  private var _textToReturn: String = "Mock clipboard text"
  private var _imageToReturn: String = "Mock base64 image data"
  private var _filesToReturn: [String] = ["/path/to/file1.txt", "/path/to/file2.txt"]
  private var _infoToReturn: ClipboardContentInfo = .init(
    availableTypes: [.text, .image], isEmpty: false, )

  // Error simulation - private variables
  private var _shouldThrowOnGetText = false
  private var _shouldThrowOnSetText = false
  private var _shouldThrowOnGetImage = false
  private var _shouldThrowOnSetImage = false
  private var _shouldThrowOnGetFiles = false
  private var _shouldThrowOnSetFiles = false
  private var _shouldThrowOnClear = false
  private var _shouldThrowOnGetInfo = false

  public init() {}

  // MARK: - Setter methods for configuring mock behavior

  // Counter reset methods
  public func resetGetInfoCallCount() { getInfoCallCount = 0 }

  public func resetAllCallCounts() {
    getTextCallCount = 0
    setTextCallCount = 0
    getImageCallCount = 0
    setImageCallCount = 0
    getFilesCallCount = 0
    setFilesCallCount = 0
    clearCallCount = 0
    getInfoCallCount = 0
  }

  // Mock response setters
  public func setTextToReturn(_ text: String) { _textToReturn = text }

  public func setImageToReturn(_ image: String) { _imageToReturn = image }

  public func setFilesToReturn(_ files: [String]) { _filesToReturn = files }

  public func setInfoToReturn(_ info: ClipboardContentInfo) { _infoToReturn = info }

  // Error simulation setters
  public func setShouldThrowOnGetText(_ value: Bool) { _shouldThrowOnGetText = value }

  public func setShouldThrowOnSetText(_ value: Bool) { _shouldThrowOnSetText = value }

  public func setShouldThrowOnGetImage(_ value: Bool) { _shouldThrowOnGetImage = value }

  public func setShouldThrowOnSetImage(_ value: Bool) { _shouldThrowOnSetImage = value }

  public func setShouldThrowOnGetFiles(_ value: Bool) { _shouldThrowOnGetFiles = value }

  public func setShouldThrowOnSetFiles(_ value: Bool) { _shouldThrowOnSetFiles = value }

  public func setShouldThrowOnClear(_ value: Bool) { _shouldThrowOnClear = value }

  public func setShouldThrowOnGetInfo(_ value: Bool) { _shouldThrowOnGetInfo = value }

  // MARK: - ClipboardServiceProtocol Implementation

  /// Gets the text content from the clipboard
  public func getClipboardText() async throws -> String {
    getTextCallCount += 1

    if _shouldThrowOnGetText {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error getting text").asMCPError
    }

    return _textToReturn
  }

  /// Sets text content to the clipboard
  public func setClipboardText(_ text: String) async throws {
    setTextCallCount += 1
    lastTextSet = text

    if _shouldThrowOnSetText {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error setting text").asMCPError
    }
  }

  /// Gets the image from the clipboard
  public func getClipboardImage() async throws -> String {
    getImageCallCount += 1

    if _shouldThrowOnGetImage {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error getting image").asMCPError
    }

    return _imageToReturn
  }

  /// Sets an image to the clipboard from base64 encoded string
  public func setClipboardImage(_ base64Image: String) async throws {
    setImageCallCount += 1
    lastImageSet = base64Image

    if _shouldThrowOnSetImage {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error setting image").asMCPError
    }
  }

  /// Gets the file URLs from the clipboard
  public func getClipboardFiles() async throws -> [String] {
    getFilesCallCount += 1

    if _shouldThrowOnGetFiles {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error getting files").asMCPError
    }

    return _filesToReturn
  }

  /// Sets file URLs to the clipboard
  public func setClipboardFiles(_ paths: [String]) async throws {
    setFilesCallCount += 1
    lastFilesSet = paths

    if _shouldThrowOnSetFiles {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error setting files").asMCPError
    }
  }

  /// Clears the clipboard content
  public func clearClipboard() async throws {
    clearCallCount += 1

    if _shouldThrowOnClear {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error clearing clipboard")
        .asMCPError
    }
  }

  /// Gets information about the current clipboard content
  public func getClipboardInfo() async throws -> ClipboardContentInfo {
    getInfoCallCount += 1

    if _shouldThrowOnGetInfo {
      throw createClipboardError(code: "TEST_ERROR", message: "Mock error getting clipboard info")
        .asMCPError
    }

    return _infoToReturn
  }
}
