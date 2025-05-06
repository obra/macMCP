import XCTest
import Testing
import Foundation
import AppKit

@testable import MacMCP

@Suite("Accessibility API Tests")
struct AccessibilityTests {
    @Test("System-wide element access")
    func testSystemWideElement() {
        let systemElement = AccessibilityElement.systemWideElement()
        #expect(systemElement !== nil)
    }
    
    @Test("Application element by PID access")
    func testApplicationElementByPID() {
        // Get the current process ID (this test app)
        let pid = ProcessInfo.processInfo.processIdentifier
        
        let appElement = AccessibilityElement.applicationElement(pid: pid)
        #expect(appElement !== nil)
    }
    
    @Test("Get element attributes")
    func testGetAttributes() throws {
        // This test will be skipped if accessibility permissions aren't granted,
        // since we can't automate permission granting in tests
        try XCTSkipIf(!AccessibilityPermissions.isAccessibilityEnabled(),
                      "Accessibility not enabled, skipping test")
        
        // Get the system-wide element
        let systemElement = AccessibilityElement.systemWideElement()
        
        // Try to get the role attribute
        let role = try AccessibilityElement.getAttribute(systemElement, attribute: AXAttribute.role) as? String
        #expect(role != nil)
        
        // Try to get the focused application
        let focusedApp = try AccessibilityElement.getAttribute(
            systemElement,
            attribute: "AXFocusedApplication"
        ) as? AXUIElement
        
        // If we have a focused app, try to get its title
        if let app = focusedApp {
            let appTitle = try? AccessibilityElement.getAttribute(app, attribute: AXAttribute.title) as? String
            #expect(appTitle != nil)
        }
    }
    
    @Test("Convert to UIElement model")
    func testConvertToUIElement() throws {
        // This test will be skipped if accessibility permissions aren't granted
        try XCTSkipIf(!AccessibilityPermissions.isAccessibilityEnabled(),
                      "Accessibility not enabled, skipping test")
        
        // Get a simple UI element - use the system-wide element
        let systemElement = AccessibilityElement.systemWideElement()
        
        // Convert to our model - don't go recursive to keep it simpler for the test
        let uiElement = try AccessibilityElement.convertToUIElement(systemElement, recursive: false)
        
        // Verify basic properties
        #expect(uiElement.role != nil)
        #expect(uiElement.identifier != nil)
    }
    
    @Test("Get element hierarchy (limited depth)")
    func testGetElementHierarchy() throws {
        // This test will be skipped if accessibility permissions aren't granted
        try XCTSkipIf(!AccessibilityPermissions.isAccessibilityEnabled(),
                      "Accessibility not enabled, skipping test")
        
        // Get the system-wide element 
        let systemElement = AccessibilityElement.systemWideElement()
        
        // Convert to our model with a small max depth to keep test fast
        let uiElement = try AccessibilityElement.convertToUIElement(
            systemElement,
            recursive: true,
            maxDepth: 2
        )
        
        // Verify we get at least some elements in the hierarchy
        #expect(!uiElement.children.isEmpty)
        
        // Check if we can navigate the hierarchy
        if let firstChild = uiElement.children.first {
            #expect(firstChild.parent === uiElement)
            
            // Check if we got to the depth limit
            if !firstChild.children.isEmpty {
                let grandchild = firstChild.children.first!
                #expect(grandchild.parent === firstChild)
            }
        }
    }
}