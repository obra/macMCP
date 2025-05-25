// ABOUTME: Tests for UI change detection functionality 
// ABOUTME: Verifies that change detection service correctly identifies new, removed, and modified elements

import XCTest
import Testing
@testable import MacMCP

@Suite("UI Change Detection Tests")
struct UIChangeDetectionTests {
    
    @Test("detectChanges finds new elements")
    func testDetectNewElements() async throws {
        let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
        
        // Create before snapshot with one element
        let element1 = UIElement(
            path: "/app/button1",
            role: "AXButton",
            title: "Button 1",
            elementDescription: "First button",
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let beforeSnapshot = ["path1": element1]
        
        // Create after snapshot with additional element
        let element2 = UIElement(
            path: "/app/button2",
            role: "AXButton", 
            title: "Button 2",
            elementDescription: "Second button",
            frame: CGRect(x: 0, y: 60, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let afterSnapshot = ["path1": element1, "path2": element2]
        
        // Detect changes
        let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
        
        // Verify results
        #expect(changes.newElements.count == 1)
        #expect(changes.removedElements.isEmpty)
        #expect(changes.modifiedElements.isEmpty)
        #expect(changes.newElements.first?.path == "/app/button2")
    }
    
    @Test("detectChanges finds removed elements")
    func testDetectRemovedElements() async throws {
        let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
        
        // Create before snapshot with two elements
        let element1 = UIElement(
            path: "/app/button1",
            role: "AXButton",
            title: "Button 1", 
            elementDescription: "First button",
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let element2 = UIElement(
            path: "/app/button2",
            role: "AXButton",
            title: "Button 2",
            elementDescription: "Second button", 
            frame: CGRect(x: 0, y: 60, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let beforeSnapshot = ["path1": element1, "path2": element2]
        
        // Create after snapshot with one element removed
        let afterSnapshot = ["path1": element1]
        
        // Detect changes
        let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
        
        // Verify results
        #expect(changes.newElements.isEmpty)
        #expect(changes.removedElements.count == 1)
        #expect(changes.modifiedElements.isEmpty)
        #expect(changes.removedElements.first == "path2")
    }
    
    @Test("detectChanges finds modified elements")
    func testDetectModifiedElements() async throws {
        let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
        
        // Create before snapshot
        let element1Before = UIElement(
            path: "/app/button1",
            role: "AXButton",
            title: "Button 1",
            elementDescription: "First button",
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let beforeSnapshot = ["path1": element1Before]
        
        // Create after snapshot with modified element (different title)
        let element1After = UIElement(
            path: "/app/button1",
            role: "AXButton",
            title: "Button 1 Modified",
            elementDescription: "First button", 
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let afterSnapshot = ["path1": element1After]
        
        // Detect changes
        let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
        
        // Verify results
        #expect(changes.newElements.isEmpty)
        #expect(changes.removedElements.isEmpty)
        #expect(changes.modifiedElements.count == 1)
        #expect(changes.modifiedElements.first?.after.title == "Button 1 Modified")
    }
    
    @Test("detectChanges returns no changes for identical snapshots")
    func testNoChanges() async throws {
        let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
        
        // Create identical snapshots
        let element1 = UIElement(
            path: "/app/button1",
            role: "AXButton",
            title: "Button 1",
            elementDescription: "First button",
            frame: CGRect(x: 0, y: 0, width: 100, height: 50),
            frameSource: .direct,
            children: [],
            attributes: [:],
            actions: []
        )
        let snapshot = ["path1": element1]
        
        // Detect changes
        let changes = service.detectChanges(before: snapshot, after: snapshot)
        
        // Verify no changes
        #expect(!changes.hasChanges)
        #expect(changes.newElements.isEmpty)
        #expect(changes.removedElements.isEmpty)
        #expect(changes.modifiedElements.isEmpty)
    }
}

