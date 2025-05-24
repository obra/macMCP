// ABOUTME: OpaqueIDMapper provides genuinely opaque UUID-based element ID mapping  
// ABOUTME: Uses LRU cache with compact base64url encoding to prevent path manipulation

import Foundation

/// Thread-safe mapper that converts element paths to genuinely opaque UUIDs
/// Uses LRU cache to maintain bidirectional mapping for up to 128k elements
public final class OpaqueIDMapper: @unchecked Sendable {
    private let lock = NSLock()
    private var pathToID: [String: UUID] = [:]
    private var idToPath: [UUID: String] = [:]
    private var accessOrder: [UUID] = []
    private let maxCapacity: Int
    
    /// Shared singleton instance
    public static let shared = OpaqueIDMapper()
    
    /// Initialize with specified capacity (default 128k)
    public init(maxCapacity: Int = 128_000) {
        self.maxCapacity = maxCapacity
    }
    
    /// Generate opaque ID for element path
    /// Returns existing ID if path already mapped, creates new UUID otherwise
    public func opaqueID(for path: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        
        // Check if we already have an ID for this path
        if let existingID = pathToID[path] {
            // Move to end of access order (most recently used)
            updateAccessOrder(existingID)
            return compactEncode(existingID)
        }
        
        // Generate new UUID
        let newID = UUID()
        
        // Evict oldest if at capacity
        if pathToID.count >= maxCapacity {
            evictOldest()
        }
        
        // Store bidirectional mapping
        pathToID[path] = newID
        idToPath[newID] = path
        accessOrder.append(newID)
        
        return compactEncode(newID)
    }
    
    /// Resolve opaque ID back to element path
    /// Returns nil if ID not found in cache
    public func elementPath(for opaqueID: String) -> String? {
        guard let uuid = compactDecode(opaqueID) else { return nil }
        
        lock.lock()
        defer { lock.unlock() }
        
        guard let path = idToPath[uuid] else { return nil }
        
        // Update access order
        updateAccessOrder(uuid)
        return path
    }
    
    /// Clear all mappings
    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
        pathToID.removeAll()
        idToPath.removeAll()
        accessOrder.removeAll()
    }
    
    /// Get current cache size
    public var cacheSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return pathToID.count
    }
    
    // MARK: - Private Implementation
    
    private func updateAccessOrder(_ uuid: UUID) {
        if let index = accessOrder.firstIndex(of: uuid) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(uuid)
    }
    
    private func evictOldest() {
        guard let oldestID = accessOrder.first else { return }
        
        accessOrder.removeFirst()
        
        if let path = idToPath.removeValue(forKey: oldestID) {
            pathToID.removeValue(forKey: path)
        }
    }
    
    /// Encode UUID as compact base64url string (22 chars)
    private func compactEncode(_ uuid: UUID) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = withUnsafeBytes(of: uuid) { uuidBytes in
            bytes.withUnsafeMutableBufferPointer { buffer in
                uuidBytes.copyBytes(to: buffer)
            }
        }
        
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Decode compact base64url string back to UUID
    private func compactDecode(_ encoded: String) -> UUID? {
        // Add padding back
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        
        // Convert back from base64url
        let base64 = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              data.count == 16 else { return nil }
        
        return data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> UUID in
            bytes.load(as: UUID.self)
        }
    }
}