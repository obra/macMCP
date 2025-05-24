// ABOUTME: Tests for OpaqueIDMapper functionality
// ABOUTME: Verifies UUID-based opaque ID mapping with LRU cache behavior

import Testing
import Foundation
@testable import MacMCP

@Suite("Opaque ID Mapper Tests")
struct OpaqueIDMapperTests {
    
    @Test("Basic mapping functionality")
    func basicMapping() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        let testPath = #"macos://ui/AXApplication[@AXTitle="Calculator"]/AXButton[@AXDescription="1"]"#
        
        // Generate opaque ID
        let opaqueID = mapper.opaqueID(for: testPath)
        
        // Verify ID is compact (22 chars for base64url UUID)
        #expect(opaqueID.count == 22)
        
        // Verify ID contains only valid base64url characters
        let validChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(opaqueID.unicodeScalars.allSatisfy { validChars.contains($0) })
        
        // Verify path can be resolved back
        let resolvedPath = mapper.elementPath(for: opaqueID)
        #expect(resolvedPath == testPath)
    }
    
    @Test("Consistent ID generation")
    func consistentIDGeneration() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        let testPath = #"macos://ui/AXApplication[@AXTitle="Calculator"]/AXButton[@AXDescription="1"]"#
        
        // Generate ID multiple times for same path
        let id1 = mapper.opaqueID(for: testPath)
        let id2 = mapper.opaqueID(for: testPath)
        let id3 = mapper.opaqueID(for: testPath)
        
        // Should return same ID for same path
        #expect(id1 == id2)
        #expect(id2 == id3)
        #expect(mapper.cacheSize == 1)
    }
    
    @Test("Different paths get different IDs")
    func differentPathsDifferentIDs() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        let path1 = #"macos://ui/AXApplication[@AXTitle="Calculator"]/AXButton[@AXDescription="1"]"#
        let path2 = #"macos://ui/AXApplication[@AXTitle="Calculator"]/AXButton[@AXDescription="2"]"#
        
        let id1 = mapper.opaqueID(for: path1)
        let id2 = mapper.opaqueID(for: path2)
        
        #expect(id1 != id2)
        #expect(mapper.cacheSize == 2)
        
        // Verify both can be resolved correctly
        #expect(mapper.elementPath(for: id1) == path1)
        #expect(mapper.elementPath(for: id2) == path2)
    }
    
    @Test("LRU cache eviction")
    func lruCacheEviction() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 3)
        
        // Fill cache to capacity
        let id1 = mapper.opaqueID(for: "path1")
        let id2 = mapper.opaqueID(for: "path2")
        let id3 = mapper.opaqueID(for: "path3")
        
        #expect(mapper.cacheSize == 3)
        
        // All should be resolvable
        #expect(mapper.elementPath(for: id1) == "path1")
        #expect(mapper.elementPath(for: id2) == "path2")
        #expect(mapper.elementPath(for: id3) == "path3")
        
        // Add one more - should evict oldest (path1)
        let id4 = mapper.opaqueID(for: "path4")
        
        #expect(mapper.cacheSize == 3)
        #expect(mapper.elementPath(for: id1) == nil) // Evicted
        #expect(mapper.elementPath(for: id2) == "path2")
        #expect(mapper.elementPath(for: id3) == "path3")
        #expect(mapper.elementPath(for: id4) == "path4")
    }
    
    @Test("LRU access order update")
    func lruAccessOrderUpdate() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 3)
        
        let id1 = mapper.opaqueID(for: "path1")
        let id2 = mapper.opaqueID(for: "path2")
        let id3 = mapper.opaqueID(for: "path3")
        
        // Access path1 again - should move it to end of LRU
        _ = mapper.elementPath(for: id1)
        
        // Add new path - should evict path2 (now oldest)
        let id4 = mapper.opaqueID(for: "path4")
        
        #expect(mapper.elementPath(for: id1) == "path1") // Should still exist
        #expect(mapper.elementPath(for: id2) == nil)     // Should be evicted
        #expect(mapper.elementPath(for: id3) == "path3")
        #expect(mapper.elementPath(for: id4) == "path4")
    }
    
    @Test("Invalid opaque ID handling")
    func invalidOpaqueIDHandling() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        
        // Invalid base64url
        #expect(mapper.elementPath(for: "invalid-id") == nil)
        
        // Valid base64url but not in cache
        #expect(mapper.elementPath(for: "aGVsbG8gd29ybGQ") == nil)
        
        // Wrong length
        #expect(mapper.elementPath(for: "short") == nil)
    }
    
    @Test("Clear all functionality")
    func clearAllFunctionality() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        
        let id1 = mapper.opaqueID(for: "path1")
        let id2 = mapper.opaqueID(for: "path2")
        
        #expect(mapper.cacheSize == 2)
        #expect(mapper.elementPath(for: id1) == "path1")
        
        mapper.clearAll()
        
        #expect(mapper.cacheSize == 0)
        #expect(mapper.elementPath(for: id1) == nil)
        #expect(mapper.elementPath(for: id2) == nil)
    }
    
    @Test("Thread safety basic test")
    func threadSafetyBasicTest() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        var results: [String] = []
        let resultsLock = NSLock()
        
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let path = "path\(i)"
            let id = mapper.opaqueID(for: path)
            let resolved = mapper.elementPath(for: id)
            
            resultsLock.lock()
            if resolved == path {
                results.append(path)
            }
            resultsLock.unlock()
        }
        
        // All operations should succeed
        #expect(results.count == 100)
        #expect(mapper.cacheSize == 100)
    }
    
    @Test("UUID encoding format validation")
    func uuidEncodingFormatValidation() throws {
        let mapper = OpaqueIDMapper(maxCapacity: 1000)
        
        // Generate multiple IDs and verify format
        for i in 0..<10 {
            let id = mapper.opaqueID(for: "path\(i)")
            
            // Should be exactly 22 characters (128-bit UUID in base64url without padding)
            #expect(id.count == 22)
            
            // Should not contain padding or standard base64 chars
            #expect(!id.contains("="))
            #expect(!id.contains("+"))
            #expect(!id.contains("/"))
            
            // Should be unique
            for j in 0..<i {
                let otherId = mapper.opaqueID(for: "path\(j)")
                #expect(id != otherId)
            }
        }
    }
}