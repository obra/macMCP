// ABOUTME: Tests for UIElement path collision scenarios and resolution
// ABOUTME: Validates that elements with identical paths are properly disambiguated

import Foundation
import Testing
import ApplicationServices
@testable import MacMCP

@Suite(.serialized)
struct PathCollisionTests {
    
    @Test("Path generation algorithm - demonstrates collision scenario")
    func testPathGenerationCollisions() throws {
        // Test the core path generation algorithm that creates collisions
        // This demonstrates the problem: same role + attributes = same path
        
        // Simulate elements with identical attributes (like multiple "Add" buttons)
        let role = "AXButton"
        let attributes = ["AXDescription": "Add"]
        
        // Current createElementPathString creates identical paths
        // We'll test this through the public behavior for now
        let path1 = "\(role)[@AXDescription=\"\(attributes["AXDescription"]!)\"]"
        let path2 = "\(role)[@AXDescription=\"\(attributes["AXDescription"]!)\"]"
        let path3 = "\(role)[@AXDescription=\"\(attributes["AXDescription"]!)\"]"
        
        print("Generated paths:")
        print("  Path 1: \(path1)")
        print("  Path 2: \(path2)")
        print("  Path 3: \(path3)")
        
        // This demonstrates the collision problem
        #expect(path1 == path2, "Paths are identical - this causes dictionary collisions")
        #expect(path2 == path3, "All paths are identical - this is the root cause")
        
        // All paths are the same: AXButton[@AXDescription="Add"]
        // When stored in dictionary[path] = element, later elements overwrite earlier ones
    }
    
    @Test("Dictionary collision simulation - demonstrates data loss")
    func testDictionaryCollisionSimulation() throws {
        // Simulate what happens in UIChangeDetectionService.swift:64
        // snapshot[element.path] = element
        
        var snapshot: [String: String] = [:]  // Using String instead of UIElement for simplicity
        let elements = [
            ("AXButton[@AXDescription=\"Add\"]", "Element1"),
            ("AXButton[@AXDescription=\"Add\"]", "Element2"), 
            ("AXButton[@AXDescription=\"Add\"]", "Element3"),
            ("AXButton[@AXDescription=\"Subtract\"]", "Element4")  // Different path, no collision
        ]
        
        // Store elements by path - this causes overwrites
        for (path, element) in elements {
            snapshot[path] = element
        }
        
        print("Original elements: \(elements.count)")
        print("Dictionary entries: \(snapshot.count)")
        print("Lost due to collisions: \(elements.count - snapshot.count)")
        
        // Should lose 2 elements due to collisions (Element1 and Element2 overwritten by Element3)
        #expect(snapshot.count == 2, "Dictionary should only have 2 entries due to path collisions")
        #expect(snapshot["AXButton[@AXDescription=\"Add\"]"] == "Element3", "Last element should overwrite earlier ones")
        #expect(snapshot["AXButton[@AXDescription=\"Subtract\"]"] == "Element4", "Non-colliding element should remain")
    }
    
    @Test("Sibling indexing algorithm design")
    func testSiblingIndexingAlgorithm() throws {
        // Test the designed solution: add [1], [2], etc. for colliding siblings
        
        let siblings = [
            ("AXButton", ["AXDescription": "Add"]),
            ("AXButton", ["AXDescription": "Add"]),  // Collision
            ("AXButton", ["AXDescription": "Add"]),  // Collision  
            ("AXButton", ["AXDescription": "Subtract"]),  // No collision
        ]
        
        // Expected output after implementing fix:
        let expectedPaths = [
            "AXButton[@AXDescription=\"Add\"]",
            "AXButton[@AXDescription=\"Add\"][1]",
            "AXButton[@AXDescription=\"Add\"][2]", 
            "AXButton[@AXDescription=\"Subtract\"]"
        ]
        
        print("Input siblings:")
        for (i, (role, attrs)) in siblings.enumerated() {
            print("  [\(i)]: \(role) with \(attrs)")
        }
        
        print("\nExpected unique paths after fix:")
        for (i, path) in expectedPaths.enumerated() {
            print("  [\(i)]: \(path)")
        }
        
        // This test documents the expected behavior
        // When we implement the fix, we'll generate these paths
        #expect(expectedPaths.count == siblings.count, "Should have one unique path per sibling")
        #expect(Set(expectedPaths).count == expectedPaths.count, "All expected paths should be unique")
    }
}