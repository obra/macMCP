// ABOUTME: OpaqueIDEncoder provides genuinely opaque UUID-based element ID mapping
// ABOUTME: Delegates to OpaqueIDMapper for secure, non-reversible element identification

import Compression
import Foundation

/// Encodes element paths as compact opaque IDs using gzip + Z85 encoding
public enum OpaqueIDEncoder {
  /// Encode an element path string to an opaque ID
  /// - Parameter path: The element path string to encode
  /// - Returns: Compact opaque ID string
  /// - Throws: Error if encoding fails
  public static func encode(_ path: String) throws -> String {
    OpaqueIDMapper.shared.opaqueID(for: path)
  }

  /// Decode an opaque ID back to an element path string
  /// - Parameter opaqueID: The opaque ID to decode
  /// - Returns: Original element path string
  /// - Throws: Error if decoding fails
  public static func decode(_ opaqueID: String) throws -> String {
    guard let path = OpaqueIDMapper.shared.elementPath(for: opaqueID) else {
      throw OpaqueIDError.decodingFailed("Opaque ID not found in mapping cache")
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
      case .encodingFailed(let message): "Opaque ID encoding failed: \(message)"
      case .decodingFailed(let message): "Opaque ID decoding failed: \(message)"
    }
  }
}

/// Extension to add compression support
extension Data {
  func compressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
    try withUnsafeBytes { bytes in
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
      defer { buffer.deallocate() }
      guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
        throw OpaqueIDError.encodingFailed("Failed to get buffer base address")
      }
      let compressedSize = compression_encode_buffer(
        buffer,
        count,
        baseAddress,
        count,
        nil,
        algorithm.rawValue,
      )
      guard compressedSize > 0 else { throw OpaqueIDError.encodingFailed("Compression failed") }
      return Data(bytes: buffer, count: compressedSize)
    }
  }

  func decompressed(using algorithm: NSData.CompressionAlgorithm) throws -> Data {
    try withUnsafeBytes { bytes in
      // Estimate decompressed size (4x compressed size should be safe)
      let estimatedSize = count * 4
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: estimatedSize)
      defer { buffer.deallocate() }
      guard let baseAddress = bytes.bindMemory(to: UInt8.self).baseAddress else {
        throw OpaqueIDError.decodingFailed("Failed to get buffer base address")
      }
      let decompressedSize = compression_decode_buffer(
        buffer,
        estimatedSize,
        baseAddress,
        count,
        nil,
        algorithm.rawValue,
      )
      guard decompressedSize > 0 else { throw OpaqueIDError.decodingFailed("Decompression failed") }
      return Data(bytes: buffer, count: decompressedSize)
    }
  }
}

extension NSData.CompressionAlgorithm {
  var rawValue: compression_algorithm {
    switch self {
      case .lzfse: return COMPRESSION_LZFSE
      case .lz4: return COMPRESSION_LZ4
      case .lzma: return COMPRESSION_LZMA
      case .zlib: return COMPRESSION_ZLIB
      @unknown default: return COMPRESSION_ZLIB
    }
  }
}
