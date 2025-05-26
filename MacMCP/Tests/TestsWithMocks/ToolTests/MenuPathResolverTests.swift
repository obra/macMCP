// ABOUTME: Unit tests for MenuPathResolver utility functions
// ABOUTME: Tests path parsing, validation, and fuzzy matching functionality

import Testing
import Foundation
@testable import MacMCP

@Suite("MenuPathResolver Tests", .serialized)
struct MenuPathResolverTests {
    
    @Test("buildPath creates correct path from components")
    func testBuildPath() async throws {
        let components = ["File", "Save As..."]
        let path = MenuPathResolver.buildPath(from: components)
        #expect(path == "File > Save As...")
        
        let singleComponent = ["Help"]
        let singlePath = MenuPathResolver.buildPath(from: singleComponent)
        #expect(singlePath == "Help")
        
        let emptyComponents: [String] = []
        let emptyPath = MenuPathResolver.buildPath(from: emptyComponents)
        #expect(emptyPath == "")
    }
    
    @Test("parsePath correctly splits path into components")
    func testParsePath() async throws {
        let path = "File > Save As..."
        let components = MenuPathResolver.parsePath(path)
        #expect(components == ["File", "Save As..."])
        
        let singlePath = "Help"
        let singleComponents = MenuPathResolver.parsePath(singlePath)
        #expect(singleComponents == ["Help"])
        
        let pathWithSpaces = "Format > Font > Show Fonts"
        let spacedComponents = MenuPathResolver.parsePath(pathWithSpaces)
        #expect(spacedComponents == ["Format", "Font", "Show Fonts"])
        
        let emptyPath = ""
        let emptyComponents = MenuPathResolver.parsePath(emptyPath)
        #expect(emptyComponents.isEmpty)
    }
    
    @Test("validatePath correctly validates path format")
    func testValidatePath() async throws {
        #expect(MenuPathResolver.validatePath("File > Save"))
        #expect(MenuPathResolver.validatePath("Help"))
        #expect(MenuPathResolver.validatePath("Format > Font > Bold"))
        
        #expect(!MenuPathResolver.validatePath(""))
        #expect(!MenuPathResolver.validatePath(" > "))
        #expect(!MenuPathResolver.validatePath("File > "))
        #expect(!MenuPathResolver.validatePath(" > Save"))
    }
    
    @Test("findMatches returns exact matches")
    func testFindMatches() async throws {
        let hierarchy = createTestHierarchy()
        
        let exactMatches = MenuPathResolver.findMatches("File > Save", in: hierarchy)
        #expect(exactMatches == ["File > Save"])
        
        let noMatches = MenuPathResolver.findMatches("Nonexistent > Menu", in: hierarchy)
        #expect(noMatches.isEmpty)
        
        let multipleMatches = MenuPathResolver.findMatches("Edit > Copy", in: hierarchy)
        #expect(multipleMatches == ["Edit > Copy"])
    }
    
    @Test("findPartialMatches returns relevant partial matches")
    func testFindPartialMatches() async throws {
        let hierarchy = createTestHierarchy()
        
        let saveMatches = MenuPathResolver.findPartialMatches("Save", in: hierarchy)
        #expect(saveMatches.contains("File > Save"))
        #expect(saveMatches.contains("File > Save As..."))
        
        let fileMatches = MenuPathResolver.findPartialMatches("File", in: hierarchy)
        #expect(fileMatches.contains("File > New"))
        #expect(fileMatches.contains("File > Save"))
        #expect(fileMatches.contains("File > Save As..."))
        
        // Test case insensitivity
        let caseMatches = MenuPathResolver.findPartialMatches("file", in: hierarchy)
        #expect(!caseMatches.isEmpty)
    }
    
    @Test("suggestSimilar provides good suggestions")
    func testSuggestSimilar() async throws {
        let hierarchy = createTestHierarchy()
        
        let suggestions = MenuPathResolver.suggestSimilar("Save", in: hierarchy, maxSuggestions: 3)
        #expect(suggestions.contains("File > Save"))
        #expect(suggestions.contains("File > Save As..."))
        #expect(suggestions.count <= 3)
        
        let typoSuggestions = MenuPathResolver.suggestSimilar("Sav", in: hierarchy, maxSuggestions: 2)
        #expect(!typoSuggestions.isEmpty)
        
        let noSuggestions = MenuPathResolver.suggestSimilar("XyzNonexistent", in: hierarchy)
        // Should still work, just might be empty or low relevance
    }
    
    @Test("path parsing handles special characters")
    func testSpecialCharacters() async throws {
        let specialPath = "Format > Text & Formatting > Align Center…"
        let components = MenuPathResolver.parsePath(specialPath)
        #expect(components == ["Format", "Text & Formatting", "Align Center…"])
        
        let rebuiltPath = MenuPathResolver.buildPath(from: components)
        #expect(rebuiltPath == specialPath)
    }
    
    @Test("path parsing handles unicode characters")
    func testUnicodeCharacters() async throws {
        let unicodePath = "文件 > 保存为..."
        #expect(MenuPathResolver.validatePath(unicodePath))
        
        let components = MenuPathResolver.parsePath(unicodePath)
        #expect(components == ["文件", "保存为..."])
    }
    
    // MARK: - Helper Methods
    
    private func createTestHierarchy() -> MenuHierarchy {
        let menus: [String: [String]] = [
            "File": [
                "File > New",
                "File > Open...",
                "File > Save",
                "File > Save As...",
                "File > Export > PDF",
                "File > Export > Web Page"
            ],
            "Edit": [
                "Edit > Undo",
                "Edit > Redo",
                "Edit > Cut",
                "Edit > Copy",
                "Edit > Paste"
            ],
            "Format": [
                "Format > Font > Bold",
                "Format > Font > Italic",
                "Format > Text > Align Left",
                "Format > Text > Align Center"
            ]
        ]
        
        return MenuHierarchy(
            application: "com.test.app",
            menus: menus,
            totalItems: menus.values.flatMap { $0 }.count,
            exploredDepth: 3
        )
    }
}