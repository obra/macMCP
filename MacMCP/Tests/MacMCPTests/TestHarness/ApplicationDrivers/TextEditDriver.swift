// ABOUTME: This file implements a driver for the macOS TextEdit application for testing.
// ABOUTME: It provides methods to create and edit text documents using TextEdit.

import Foundation
import XCTest
@testable import MacMCP

/// Driver for the macOS TextEdit app used in tests
public class TextEditDriver: BaseApplicationDriver, @unchecked Sendable {
    /// TextEdit UI element roles
    public enum ElementRole {
        static let textArea = "AXTextArea"
        static let scrollArea = "AXScrollArea"
        static let menuButton = "AXMenuButton"
        static let menuBarItem = "AXMenuBarItem"
        static let menu = "AXMenu"
        static let menuItem = "AXMenuItem"
    }
    
    /// TextEdit menu items
    public enum MenuItem {
        static let file = "File"
        static let edit = "Edit"
        static let format = "Format"
        static let new = "New"
        static let open = "Open..."
        static let save = "Save..."
        static let saveAs = "Save As..."
        static let close = "Close"
        static let undo = "Undo"
        static let redo = "Redo"
        static let cut = "Cut"
        static let copy = "Copy"
        static let paste = "Paste"
        static let selectAll = "Select All"
        static let find = "Find"
    }
    
    /// Create a new TextEdit driver
    /// - Parameters:
    ///   - applicationService: The application service to use
    ///   - accessibilityService: The accessibility service to use
    ///   - interactionService: The UI interaction service to use
    public init(
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        super.init(
            bundleIdentifier: "com.apple.TextEdit",
            appName: "TextEdit",
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Get the main text area in the current document
    /// - Returns: The text area element or nil if not found
    public func getTextArea() async throws -> UIElement? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Find scroll area (container of text area)
        var scrollArea: UIElement? = nil
        for child in window.children {
            if child.role == ElementRole.scrollArea {
                scrollArea = child
                break
            }
        }
        
        guard let scrollArea = scrollArea else {
            return nil
        }
        
        // Find text area inside scroll area
        for child in scrollArea.children {
            if child.role == ElementRole.textArea {
                return child
            }
        }
        
        return nil
    }
    
    /// Get the current text content
    /// - Returns: The text content or nil if not available
    public func getTextContent() async throws -> String? {
        guard let textArea = try await getTextArea() else {
            return nil
        }
        
        return textArea.value
    }
    
    /// Type text into the document
    /// - Parameter text: The text to type
    /// - Returns: True if typing was successful
    public func typeText(_ text: String) async throws -> Bool {
        guard let textArea = try await getTextArea() else {
            throw NSError(
                domain: "TextEditDriver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find text area"]
            )
        }
        
        // Focus the text area
        try await interactionService.clickElement(identifier: textArea.identifier)
        
        // Type the text
        try await interactionService.typeText(text: text)
        return true
    }
    
    /// Select all text in the document
    /// - Returns: True if selection was successful
    public func selectAll() async throws -> Bool {
        guard try await getMainWindow() != nil else {
            throw NSError(
                domain: "TextEditDriver",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not get TextEdit window"]
            )
        }
        
        // Use keyboard shortcut Command+A to select all
        try await interactionService.pressKey(keyCode: 0, modifiers: [.command])
        return true
    }
    
    /// Create a new document
    /// - Returns: True if successful
    public func newDocument() async throws -> Bool {
        // Use keyboard shortcut Command+N for new document
        try await interactionService.pressKey(keyCode: 45, modifiers: [.command])
        
        // Wait for the new document window
        let criteria = ApplicationDrivers.ElementCriteria(role: "AXWindow", title: "Untitled")
        return try await waitForElement(matching: criteria, timeout: 5) != nil
    }
    
    /// Click a menu item
    /// - Parameters:
    ///   - menu: The main menu item (e.g., "File", "Edit")
    ///   - item: The submenu item (e.g., "New", "Save")
    /// - Returns: True if the menu item was clicked successfully
    public func clickMenuItem(menu: String, item: String) async throws -> Bool {
        // First click the menu bar item
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleIdentifier,
            recursive: true,
            maxDepth: 5
        )
        
        // Find the menu bar
        var menuBar: UIElement? = nil
        for child in appElement.children {
            if child.role == "AXMenuBar" {
                menuBar = child
                break
            }
        }
        
        guard let menuBar = menuBar else {
            throw NSError(
                domain: "TextEditDriver",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not find menu bar"]
            )
        }
        
        // Find the requested menu
        var menuBarItem: UIElement? = nil
        for child in menuBar.children {
            if child.role == ElementRole.menuBarItem && child.title == menu {
                menuBarItem = child
                break
            }
        }
        
        guard let menuBarItem = menuBarItem else {
            throw NSError(
                domain: "TextEditDriver",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not find menu: \(menu)"]
            )
        }
        
        // Click menu bar item to open menu
        try await interactionService.clickElement(identifier: menuBarItem.identifier)
        
        // Wait briefly for menu to appear
        try await Task.sleep(for: .milliseconds(300))
        
        // Now find the menu item
        let menuCriteria = ApplicationDrivers.ElementCriteria(role: ElementRole.menu)
        guard let menuElement = try await waitForElement(matching: menuCriteria, timeout: 2) else {
            throw NSError(
                domain: "TextEditDriver",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Menu did not appear after clicking \(menu)"]
            )
        }
        
        // Find the requested menu item
        var menuItem: UIElement? = nil
        for child in menuElement.children {
            if child.role == ElementRole.menuItem && child.title == item {
                menuItem = child
                break
            }
        }
        
        guard let menuItem = menuItem else {
            // Close menu by clicking elsewhere and return failure
            try await interactionService.clickGlobalPoint(CGPoint(x: 10, y: 10))
            return false
        }
        
        // Click the menu item
        try await interactionService.clickElement(identifier: menuItem.identifier)
        return true
    }
    
    /// Save the current document with a given filename
    /// - Parameter filename: The filename to save as
    /// - Returns: True if save was successful
    public func saveAs(_ filename: String) async throws -> Bool {
        // Open Save As dialog
        try await clickMenuItem(menu: MenuItem.file, item: MenuItem.saveAs)
        
        // Wait for save dialog
        let dialogCriteria = ApplicationDrivers.ElementCriteria(role: "AXSheet")
        guard let saveDialog = try await waitForElement(matching: dialogCriteria, timeout: 3) else {
            return false
        }
        
        // Find filename field
        var filenameField: UIElement? = nil
        func findTextField(in element: UIElement) -> UIElement? {
            if element.role == "AXTextField" {
                return element
            }
            
            for child in element.children {
                if let field = findTextField(in: child) {
                    return field
                }
            }
            
            return nil
        }
        
        filenameField = findTextField(in: saveDialog)
        
        guard let filenameField = filenameField else {
            // Cancel dialog
            try await interactionService.pressKey(keyCode: 53, modifiers: []) // Escape key
            return false
        }
        
        // Click the filename field and enter the filename
        try await interactionService.clickElement(identifier: filenameField.identifier)
        try await interactionService.typeText(text: filename)
        
        // Press Return to save
        try await interactionService.pressKey(keyCode: 36, modifiers: []) // Return key
        return true
    }
    
    /// Open a document from a path
    /// - Parameter path: The file path to open
    /// - Returns: True if open was successful
    public func openDocument(path: String) async throws -> Bool {
        // Use command line argument to open document when launching
        if !isRunning() {
            return try await applicationService.openApplication(
                bundleIdentifier: bundleIdentifier,
                arguments: [path],
                hideOthers: false
            )
        } else {
            // App is already running, use Open dialog
            try await clickMenuItem(menu: MenuItem.file, item: MenuItem.open)
            
            // TODO: Implement dialog interaction for selecting existing file
            // For now, return false as this requires complex dialog interaction
            return false
        }
    }
    
    /// Clear the document content
    /// - Returns: True if clearing was successful
    public func clearDocument() async throws -> Bool {
        // Select all text
        try await selectAll()
        
        // Delete selected text
        try await interactionService.pressKey(keyCode: 51, modifiers: []) // Delete key
        return true
    }
}