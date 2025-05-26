// ABOUTME: Unit tests for CompactMenuItem data structure
// ABOUTME: Tests serialization, deserialization, and hierarchy navigation

import Testing
import Foundation
@testable import MacMCP

@Suite("CompactMenuItem Tests", .serialized)
struct CompactMenuItemTests {
    
    @Test("CompactMenuItem initializes correctly")
    func testInitialization() async throws {
        let item = CompactMenuItem(
            path: "File > Save",
            title: "Save",
            enabled: true,
            shortcut: "⌘S",
            hasSubmenu: false,
            children: nil,
            elementPath: "element-123"
        )
        
        #expect(item.path == "File > Save")
        #expect(item.title == "Save")
        #expect(item.enabled == true)
        #expect(item.shortcut == "⌘S")
        #expect(item.hasSubmenu == false)
        #expect(item.children == nil)
        #expect(item.elementPath == "element-123")
    }
    
    @Test("CompactMenuItem calculates depth correctly")
    func testDepthCalculation() async throws {
        let topLevel = CompactMenuItem(
            path: "File",
            title: "File",
            enabled: true,
            elementPath: "element-1"
        )
        #expect(topLevel.depth == 0)
        
        let firstLevel = CompactMenuItem(
            path: "File > Save",
            title: "Save",
            enabled: true,
            elementPath: "element-2"
        )
        #expect(firstLevel.depth == 1)
        
        let secondLevel = CompactMenuItem(
            path: "Format > Font > Bold",
            title: "Bold",
            enabled: true,
            elementPath: "element-3"
        )
        #expect(secondLevel.depth == 2)
    }
    
    @Test("findChild locates correct child by path")
    func testFindChild() async throws {
        let hierarchy = createTestMenuHierarchy()
        
        // Test finding self
        let found = hierarchy.findChild(withPath: "File")
        #expect(found?.path == "File")
        
        // Test finding direct child
        let saveFound = hierarchy.findChild(withPath: "File > Save")
        #expect(saveFound?.path == "File > Save")
        #expect(saveFound?.title == "Save")
        
        // Test finding grandchild
        let exportPdfFound = hierarchy.findChild(withPath: "File > Export > PDF")
        #expect(exportPdfFound?.path == "File > Export > PDF")
        #expect(exportPdfFound?.title == "PDF")
        
        // Test not found
        let notFound = hierarchy.findChild(withPath: "Nonexistent > Menu")
        #expect(notFound == nil)
    }
    
    @Test("allDescendantPaths returns all paths in hierarchy")
    func testAllDescendantPaths() async throws {
        let hierarchy = createTestMenuHierarchy()
        let allPaths = hierarchy.allDescendantPaths
        
        #expect(allPaths.contains("File"))
        #expect(allPaths.contains("File > New"))
        #expect(allPaths.contains("File > Save"))
        #expect(allPaths.contains("File > Export"))
        #expect(allPaths.contains("File > Export > PDF"))
        #expect(allPaths.contains("File > Export > Web Page"))
        
        // Should have 6 total paths
        #expect(allPaths.count == 6)
    }
    
    @Test("CompactMenuItem serialization works correctly")
    func testSerialization() async throws {
        let originalItem = CompactMenuItem(
            path: "File > Save As...",
            title: "Save As...",
            enabled: true,
            shortcut: "⌘⇧S",
            hasSubmenu: false,
            children: nil,
            elementPath: "element-save-as"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalItem)
        #expect(!data.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedItem = try decoder.decode(CompactMenuItem.self, from: data)
        
        #expect(decodedItem.path == originalItem.path)
        #expect(decodedItem.title == originalItem.title)
        #expect(decodedItem.enabled == originalItem.enabled)
        #expect(decodedItem.shortcut == originalItem.shortcut)
        #expect(decodedItem.hasSubmenu == originalItem.hasSubmenu)
        #expect(decodedItem.elementPath == originalItem.elementPath)
    }
    
    @Test("CompactMenuItem with children serializes correctly")
    func testSerializationWithChildren() async throws {
        let hierarchy = createTestMenuHierarchy()
        
        // Test encoding with nested children
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(hierarchy)
        #expect(!data.isEmpty)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedHierarchy = try decoder.decode(CompactMenuItem.self, from: data)
        
        #expect(decodedHierarchy.path == hierarchy.path)
        #expect(decodedHierarchy.children?.count == hierarchy.children?.count)
        
        // Test that children are preserved
        let foundChild = decodedHierarchy.findChild(withPath: "File > Export > PDF")
        #expect(foundChild?.title == "PDF")
    }
    
    @Test("CompactMenuItem handles special characters")
    func testSpecialCharacters() async throws {
        let item = CompactMenuItem(
            path: "Format > Text & Formatting > Align Center…",
            title: "Align Center…",
            enabled: true,
            shortcut: "⌘⌥C",
            hasSubmenu: false,
            elementPath: "element-align-center"
        )
        
        #expect(item.path.contains("&"))
        #expect(item.path.contains("…"))
        #expect(item.title == "Align Center…")
        #expect(item.depth == 2)
    }
    
    @Test("CompactMenuItem handles unicode characters")
    func testUnicodeCharacters() async throws {
        let item = CompactMenuItem(
            path: "文件 > 保存为...",
            title: "保存为...",
            enabled: true,
            shortcut: "⌘⇧S",
            hasSubmenu: false,
            elementPath: "element-save-as-unicode"
        )
        
        #expect(item.path == "文件 > 保存为...")
        #expect(item.title == "保存为...")
        #expect(item.depth == 1)
        
        // Test serialization with unicode
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CompactMenuItem.self, from: data)
        
        #expect(decoded.path == item.path)
        #expect(decoded.title == item.title)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMenuHierarchy() -> CompactMenuItem {
        let exportChildren = [
            CompactMenuItem(
                path: "File > Export > PDF",
                title: "PDF",
                enabled: true,
                elementPath: "element-pdf"
            ),
            CompactMenuItem(
                path: "File > Export > Web Page",
                title: "Web Page",
                enabled: true,
                elementPath: "element-webpage"
            )
        ]
        
        let fileChildren = [
            CompactMenuItem(
                path: "File > New",
                title: "New",
                enabled: true,
                shortcut: "⌘N",
                elementPath: "element-new"
            ),
            CompactMenuItem(
                path: "File > Save",
                title: "Save",
                enabled: true,
                shortcut: "⌘S",
                elementPath: "element-save"
            ),
            CompactMenuItem(
                path: "File > Export",
                title: "Export",
                enabled: true,
                hasSubmenu: true,
                children: exportChildren,
                elementPath: "element-export"
            )
        ]
        
        return CompactMenuItem(
            path: "File",
            title: "File",
            enabled: true,
            hasSubmenu: true,
            children: fileChildren,
            elementPath: "element-file"
        )
    }
}