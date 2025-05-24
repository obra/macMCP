// ABOUTME: OpaqueIDEncoder provides compact encoding/decoding of element paths to opaque IDs
// ABOUTME: Uses gzip compression + Z85 encoding for maximum compactness and safety in JSON

import Foundation
import Compression

/// Encodes element paths as compact opaque IDs using gzip + Z85 encoding
public enum OpaqueIDEncoder {
    
    /// Encode an element path string to an opaque ID
    /// - Parameter path: The element path string to encode
    /// - Returns: Compact opaque ID string
    /// - Throws: Error if encoding fails
    public static func encode(_ path: String) throws -> String {
        // 1. Convert string to data
        guard let data = path.data(using: .utf8) else {
            throw OpaqueIDError.encodingFailed("Failed to convert path to UTF-8 data")
        }
        
        // 2. Try compression, fall back to raw data if compression fails or isn't beneficial
        let dataToEncode: Data
        do {
            let compressedData = try data.compressed(using: .zlib)
            // Only use compression if it actually saves space
            dataToEncode = compressedData.count < data.count ? compressedData : data
        } catch {
            // Compression failed, use raw data
            dataToEncode = data
        }
        
        // 3. Encode with URL-safe base64
        let opaqueID = dataToEncode.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        return opaqueID
    }
    
    /// Decode an opaque ID back to an element path string
    /// - Parameter opaqueID: The opaque ID to decode
    /// - Returns: Original element path string
    /// - Throws: Error if decoding fails
    public static func decode(_ opaqueID: String) throws -> String {
        // 1. Reverse URL-safe base64 encoding
        let base64String = opaqueID
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddedBase64 = base64String + String(repeating: "=", count: (4 - base64String.count % 4) % 4)
        
        // 2. Decode from base64
        guard let encodedData = Data(base64Encoded: paddedBase64) else {
            throw OpaqueIDError.decodingFailed("Failed to decode base64 data")
        }
        
        // 3. Try decompression first, fall back to treating as raw data
        let decodedData: Data
        do {
            decodedData = try encodedData.decompressed(using: .zlib)
        } catch {
            // Not compressed or decompression failed, treat as raw data
            decodedData = encodedData
        }
        
        // 4. Convert back to string
        guard let path = String(data: decodedData, encoding: .utf8) else {
            throw OpaqueIDError.decodingFailed("Failed to convert data to UTF-8 string")
        }
        
        return path
    }
}

/// Errors that can occur during opaque ID encoding/decoding
public enum OpaqueIDError: Error, LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let message):
            return "Opaque ID encoding failed: \(message)"
        case .decodingFailed(let message):
            return "Opaque ID decoding failed: \(message)"
        }
    }
}

/// Extension to add compression support
extension Data {
    func compressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        return try self.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, algorithm.rawValue
            )
            
            guard compressedSize > 0 else {
                throw OpaqueIDError.encodingFailed("Compression failed")
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
        return try self.withUnsafeBytes { bytes in
            // Estimate decompressed size (4x compressed size should be safe)
            let estimatedSize = count * 4
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: estimatedSize)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, estimatedSize,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, algorithm.rawValue
            )
            
            guard decompressedSize > 0 else {
                throw OpaqueIDError.decodingFailed("Decompression failed")
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
}

extension NSData.CompressionAlgorithm {
    var rawValue: compression_algorithm {
        switch self {
        case .lzfse:
            return COMPRESSION_LZFSE
        case .lz4:
            return COMPRESSION_LZ4
        case .lzma:
            return COMPRESSION_LZMA
        case .zlib:
            return COMPRESSION_ZLIB
        @unknown default:
            return COMPRESSION_ZLIB
        }
    }
}