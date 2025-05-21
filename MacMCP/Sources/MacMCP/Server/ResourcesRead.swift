// ABOUTME: ResourcesRead.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// The resources/read method for the MCP protocol
public enum ResourcesRead: MCP.Method {
    public static let name = "resources/read"

    /// Parameters for resource reading
    public struct Parameters: Codable, Hashable, Sendable {
        /// Resource URI to read
        public let uri: String

        /// Create new parameters
        public init(uri: String) {
            self.uri = uri
        }
    }

    /// Result for resource reading
    public struct Result: Codable, Hashable, Sendable {
        /// Array of resource contents
        public let contents: [MCP.Resource.Content]

        /// Create a new resource read result
        public init(contents: [MCP.Resource.Content]) {
            self.contents = contents
        }
        
        /// Create a new resource read result from legacy format
        public init(content: ResourceContent, metadata: ResourceMetadata? = nil) {
            // Create MCP resource content from our ResourceContent format
            let resourceContent: MCP.Resource.Content
            if let textContent = content.asText {
                resourceContent = MCP.Resource.Content.text(textContent, uri: "", mimeType: metadata?.mimeType)
            } else if let binaryContent = content.asBinary {
                resourceContent = MCP.Resource.Content.binary(binaryContent, uri: "", mimeType: metadata?.mimeType)
            } else {
                // Default to empty text if neither text nor binary
                resourceContent = MCP.Resource.Content.text("", uri: "", mimeType: "text/plain")
            }
            self.contents = [resourceContent]
        }
    }

    /// Resource content
    public enum ResourceContent: Codable, Hashable, Sendable {
        /// Text content
        case text(String)

        /// Binary content
        case binary(Data)

        /// The text content if available
        public var asText: String? {
            if case .text(let text) = self {
                return text
            }
            return nil
        }

        /// The binary content if available
        public var asBinary: Data? {
            if case .binary(let data) = self {
                return data
            }
            return nil
        }

        /// Encoding and decoding for resource content
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if container.contains(.text) {
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            } else if container.contains(.binary) {
                let base64 = try container.decode(String.self, forKey: .binary)
                guard let data = Data(base64Encoded: base64) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .binary,
                        in: container,
                        debugDescription: "Invalid base64 data"
                    )
                }
                self = .binary(data)
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Resource content must be text or binary"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .binary(let data):
                try container.encode("binary", forKey: .type)
                try container.encode(data.base64EncodedString(), forKey: .binary)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case type
            case text
            case binary
        }
    }

    /// Resource metadata
    public struct ResourceMetadata: Codable, Hashable, Sendable {
        /// Resource MIME type
        public let mimeType: String?

        /// Resource language
        public let language: String?

        /// Resource creation time
        public let createdAt: String?

        /// Resource update time
        public let updatedAt: String?

        /// Resource size in bytes
        public let size: Int?

        /// Additional metadata
        public let additionalMetadata: [String: Value]?

        /// Create new resource metadata
        public init(
            mimeType: String? = nil,
            language: String? = nil,
            createdAt: String? = nil,
            updatedAt: String? = nil,
            size: Int? = nil,
            additionalMetadata: [String: Value]? = nil
        ) {
            self.mimeType = mimeType
            self.language = language
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.size = size
            self.additionalMetadata = additionalMetadata
        }
    }
}