// ABOUTME: Tests for UI change detection functionality
// ABOUTME: Verifies that change detection service correctly identifies new, removed, and modified elements

import Testing
import XCTest

@testable import MacMCP

@Suite("UI Change Detection Tests") struct UIChangeDetectionTests {
  @Test("detectChanges finds new elements") func detectNewElements() async throws {
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
      actions: [],
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
      actions: [],
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

  @Test("detectChanges finds removed elements") func detectRemovedElements() async throws {
    let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
    // Create before snapshot with two root elements (e.g., two windows)
    let element1 = UIElement(
      path: "/app/window1",
      role: "AXWindow",
      title: "Window 1",
      elementDescription: "First window",
      frame: CGRect(x: 0, y: 0, width: 100, height: 50),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: [],
    )
    let element2 = UIElement(
      path: "/app/window2",
      role: "AXWindow",
      title: "Window 2",
      elementDescription: "Second window",
      frame: CGRect(x: 0, y: 60, width: 100, height: 50),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: [],
    )
    let beforeSnapshot = ["/app/window1": element1, "/app/window2": element2]
    // Create after snapshot with one window removed
    let afterSnapshot = ["/app/window1": element1]
    // Detect changes
    let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    // Verify results
    #expect(changes.newElements.isEmpty)
    #expect(changes.removedElements.count == 1)
    #expect(changes.modifiedElements.isEmpty)
    #expect(changes.removedElements.first == "/app/window2")
  }

  @Test("detectChanges finds modified elements") func detectModifiedElements() async throws {
    let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
    // Create before snapshot - use same path for before/after to test modification
    let element1Before = UIElement(
      path: "/app/button1",
      role: "AXButton",
      title: "Button 1",
      elementDescription: "First button",
      frame: CGRect(x: 0, y: 0, width: 100, height: 50),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: [],
    )
    let beforeSnapshot = ["/app/button1": element1Before]
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
      actions: [],
    )
    let afterSnapshot = ["/app/button1": element1After]
    // Detect changes
    let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    // Verify results - with tree-based detection, a modified element shows up in newElements as a changed subtree
    #expect(changes.newElements.count == 1)
    #expect(changes.removedElements.isEmpty)
    #expect(changes.newElements.first?.title == "Button 1 Modified")
  }

  @Test("detectChanges returns no changes for identical snapshots") func noChanges()
    async throws
  {
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
      actions: [],
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

  @Test("Tree-based detection finds new dialog with children") func newDialogWithChildren() async throws {
    let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
    
    // Before: just main window
    let mainWindow = UIElement(
      path: "/app/window",
      role: "AXWindow", 
      title: "Main Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: []
    )
    let beforeSnapshot = ["/app/window": mainWindow]
    
    // After: main window + new dialog with children
    let dialogButton = UIElement(
      path: "/app/dialog/button",
      role: "AXButton",
      title: "OK",
      frame: CGRect(x: 10, y: 10, width: 80, height: 30),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: ["AXPress"]
    )
    
    let dialog = UIElement(
      path: "/app/dialog",
      role: "AXWindow",
      title: "Choose Template", 
      frame: CGRect(x: 100, y: 100, width: 400, height: 300),
      frameSource: .direct,
      children: [dialogButton],
      attributes: [:],
      actions: ["AXRaise"]
    )
    
    // Set parent relationship
    dialogButton.parent = dialog
    
    let afterSnapshot = [
      "/app/window": mainWindow,
      "/app/dialog": dialog,
      "/app/dialog/button": dialogButton
    ]
    
    // Detect changes
    let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    
    // Should find exactly one new element (the dialog tree), not individual elements
    #expect(changes.newElements.count == 1)
    #expect(changes.removedElements.isEmpty)
    #expect(changes.modifiedElements.isEmpty)
    
    // The new element should be the dialog with its children intact
    let newDialog = changes.newElements.first!
    #expect(newDialog.path == "/app/dialog")
    #expect(newDialog.role == "AXWindow")
    #expect(newDialog.children.count == 1)
    #expect(newDialog.children.first?.role == "AXButton")
    #expect(newDialog.children.first?.title == "OK")
  }
  
  @Test("Tree-based detection avoids duplicates") func noDuplicateElements() async throws {
    let service = UIChangeDetectionService(accessibilityService: MockAccessibilityService())
    
    // Create a hierarchy: window -> container -> button
    let button = UIElement(
      path: "/app/window/container/button",
      role: "AXButton",
      title: "Click Me",
      frame: CGRect(x: 10, y: 10, width: 100, height: 30),
      frameSource: .direct,
      children: [],
      attributes: [:],
      actions: ["AXPress"]
    )
    
    let container = UIElement(
      path: "/app/window/container", 
      role: "AXGroup",
      title: "Container",
      frame: CGRect(x: 0, y: 0, width: 200, height: 100),
      frameSource: .direct,
      children: [button],
      attributes: [:],
      actions: []
    )
    
    let window = UIElement(
      path: "/app/window",
      role: "AXWindow",
      title: "App Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      frameSource: .direct,
      children: [container],
      attributes: [:],
      actions: ["AXRaise"]
    )
    
    // Set parent relationships
    button.parent = container
    container.parent = window
    
    let beforeSnapshot: [String: UIElement] = [:]
    let afterSnapshot = [
      "/app/window": window,
      "/app/window/container": container,
      "/app/window/container/button": button
    ]
    
    // Detect changes
    let changes = service.detectChanges(before: beforeSnapshot, after: afterSnapshot)
    
    // Should find exactly one new element (the window tree), not three separate elements
    #expect(changes.newElements.count == 1)
    
    // The new element should be the window with full hierarchy
    let newWindow = changes.newElements.first!
    #expect(newWindow.path == "/app/window")
    #expect(newWindow.children.count == 1)
    #expect(newWindow.children.first?.children.count == 1)
    
    // Verify no duplication - button shouldn't appear as separate top-level element
    let buttonPaths = changes.newElements.map { $0.path }
    #expect(!buttonPaths.contains("/app/window/container/button"))
    #expect(!buttonPaths.contains("/app/window/container"))
  }
}
