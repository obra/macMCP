// ABOUTME: ClipboardService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import UniformTypeIdentifiers

/// Actor implementing clipboard management capabilities
public actor ClipboardService: ClipboardServiceProtocol {
  /// Initializes a new clipboard service
  public init() {}

  /// Gets the text content from the clipboard
  /// - Returns: The text content if available
  /// - Throws: MacMCPErrorInfo if clipboard access fails or if no text available
  public func getClipboardText() async throws -> String {
    guard let text = NSPasteboard.general.string(forType: .string) else {
      throw createClipboardError(
        code: "NO_TEXT_AVAILABLE",
        message: "No text content available in clipboard",
      )
    }
    return text
  }

  /// Sets text content to the clipboard
  /// - Parameter text: The text to set in the clipboard
  /// - Throws: MacMCPErrorInfo if clipboard access fails
  public func setClipboardText(_ text: String) async throws {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if !pasteboard.setString(text, forType: .string) {
      throw createClipboardError(
        code: "SET_TEXT_FAILED",
        message: "Failed to set text to clipboard",
      )
    }
  }

  /// Gets the image from the clipboard
  /// - Returns: Base64 encoded string of the image data if available
  /// - Throws: MacMCPErrorInfo if clipboard access fails or if no image available
  public func getClipboardImage() async throws -> String {
    let pasteboard = NSPasteboard.general
    guard let imgData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) else {
      throw createClipboardError(
        code: "NO_IMAGE_AVAILABLE",
        message: "No image content available in clipboard",
      )
    }

    let base64String = imgData.base64EncodedString()
    return base64String
  }

  /// Sets an image to the clipboard from base64 encoded string
  /// - Parameter base64Image: Base64 encoded string of the image data
  /// - Throws: MacMCPErrorInfo if clipboard access fails or if invalid image data
  public func setClipboardImage(_ base64Image: String) async throws {
    guard let imageData = Data(base64Encoded: base64Image) else {
      throw createClipboardError(
        code: "INVALID_IMAGE_DATA",
        message: "Invalid base64 image data provided",
      )
    }

    guard NSImage(data: imageData) != nil else {
      throw createClipboardError(
        code: "INVALID_IMAGE_FORMAT",
        message: "Unable to create image from provided data",
      )
    }

    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if !pasteboard.setData(imageData, forType: .png) {
      throw createClipboardError(
        code: "SET_IMAGE_FAILED",
        message: "Failed to set image to clipboard",
      )
    }
  }

  /// Gets the file URLs from the clipboard
  /// - Returns: Array of file URLs as strings
  /// - Throws: MacMCPErrorInfo if clipboard access fails or if no files available
  public func getClipboardFiles() async throws -> [String] {
    let pasteboard = NSPasteboard.general

    // Check for URLs in the pasteboard
    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
      let fileURLs = urls.filter(\.isFileURL).map(\.path)
      if !fileURLs.isEmpty {
        return fileURLs
      }
    }

    throw createClipboardError(
      code: "NO_FILES_AVAILABLE",
      message: "No file URLs available in clipboard",
    )
  }

  /// Sets file URLs to the clipboard
  /// - Parameter paths: Array of file paths to add to clipboard
  /// - Throws: MacMCPErrorInfo if clipboard access fails or if invalid paths
  public func setClipboardFiles(_ paths: [String]) async throws {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()

    // Convert file paths to URLs
    let fileURLs = paths.compactMap { URL(fileURLWithPath: $0) }

    // Check if all paths were valid
    if fileURLs.count != paths.count {
      throw createClipboardError(
        code: "INVALID_FILE_PATHS",
        message: "One or more file paths are invalid",
      )
    }

    // Check if all files exist
    let missingFiles = fileURLs.filter { !FileManager.default.fileExists(atPath: $0.path) }
    if !missingFiles.isEmpty {
      let fileNames = missingFiles.map(\.lastPathComponent).joined(separator: ", ")
      throw createClipboardError(
        code: "FILES_NOT_FOUND",
        message: "The following files were not found: \(fileNames)",
      )
    }

    // Write to pasteboard
    if !pasteboard.writeObjects(fileURLs as [NSURL]) {
      throw createClipboardError(
        code: "SET_FILES_FAILED",
        message: "Failed to set file URLs to clipboard",
      )
    }
  }

  /// Clears the clipboard content
  /// - Throws: MacMCPErrorInfo if clipboard access fails
  public func clearClipboard() async throws {
    NSPasteboard.general.clearContents()
  }
}
