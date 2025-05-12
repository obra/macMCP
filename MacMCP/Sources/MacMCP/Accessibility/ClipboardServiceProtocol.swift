// ABOUTME: Defines the protocol for clipboard service operations
// ABOUTME: Provides methods for reading and writing different types of clipboard data

import Foundation
import AppKit

/// Protocol defining the clipboard management capabilities
public protocol ClipboardServiceProtocol: Sendable {
    /// Gets the text content from the clipboard
    /// - Returns: The text content if available
    /// - Throws: MacMCPError if clipboard access fails or if no text available
    func getClipboardText() async throws -> String
    
    /// Sets text content to the clipboard
    /// - Parameter text: The text to set in the clipboard
    /// - Throws: MacMCPError if clipboard access fails
    func setClipboardText(_ text: String) async throws
    
    /// Gets the image from the clipboard
    /// - Returns: Base64 encoded string of the image data if available
    /// - Throws: MacMCPError if clipboard access fails or if no image available
    func getClipboardImage() async throws -> String
    
    /// Sets an image to the clipboard from base64 encoded string
    /// - Parameter base64Image: Base64 encoded string of the image data
    /// - Throws: MacMCPError if clipboard access fails or if invalid image data
    func setClipboardImage(_ base64Image: String) async throws
    
    /// Gets the file URLs from the clipboard
    /// - Returns: Array of file URLs as strings
    /// - Throws: MacMCPError if clipboard access fails or if no files available
    func getClipboardFiles() async throws -> [String]
    
    /// Sets file URLs to the clipboard
    /// - Parameter paths: Array of file paths to add to clipboard
    /// - Throws: MacMCPError if clipboard access fails or if invalid paths
    func setClipboardFiles(_ paths: [String]) async throws
    
    /// Clears the clipboard content
    /// - Throws: MacMCPError if clipboard access fails
    func clearClipboard() async throws
}

/// Struct representing clipboard content types
public struct ClipboardContentType: RawRepresentable, Hashable, Sendable, Encodable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Text content type
    public static let text = ClipboardContentType(rawValue: "text")

    /// Image content type
    public static let image = ClipboardContentType(rawValue: "image")

    /// Files content type
    public static let files = ClipboardContentType(rawValue: "files")

    // MARK: - Encodable conformance

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Struct representing clipboard content information
public struct ClipboardContentInfo: Sendable, Encodable {
    /// The types of content available in the clipboard
    public let availableTypes: [ClipboardContentType]
    
    /// Whether the clipboard is empty
    public let isEmpty: Bool
    
    /// Creates clipboard content information
    /// - Parameters:
    ///   - availableTypes: The types of content available in the clipboard
    ///   - isEmpty: Whether the clipboard is empty
    public init(availableTypes: [ClipboardContentType], isEmpty: Bool) {
        self.availableTypes = availableTypes
        self.isEmpty = isEmpty
    }
    
    enum CodingKeys: String, CodingKey {
        case availableTypes
        case isEmpty
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(availableTypes.map { $0.rawValue }, forKey: .availableTypes)
        try container.encode(isEmpty, forKey: .isEmpty)
    }
}

// Extension to make ClipboardServiceProtocol provide additional methods
public extension ClipboardServiceProtocol {
    /// Gets information about the current clipboard content
    /// - Returns: ClipboardContentInfo with available types and empty status
    /// - Throws: MacMCPError if clipboard access fails
    func getClipboardInfo() async throws -> ClipboardContentInfo {
        var availableTypes: [ClipboardContentType] = []
        var isEmpty = true
        
        // Check for text content
        do {
            let text = try await getClipboardText()
            if !text.isEmpty {
                availableTypes.append(.text)
                isEmpty = false
            }
        } catch {
            // Text not available, continue checking other types
        }
        
        // Check for image content
        do {
            _ = try await getClipboardImage()
            availableTypes.append(.image)
            isEmpty = false
        } catch {
            // Image not available, continue checking other types
        }
        
        // Check for file content
        do {
            let files = try await getClipboardFiles()
            if !files.isEmpty {
                availableTypes.append(.files)
                isEmpty = false
            }
        } catch {
            // Files not available, continue
        }
        
        return ClipboardContentInfo(availableTypes: availableTypes, isEmpty: isEmpty)
    }
}