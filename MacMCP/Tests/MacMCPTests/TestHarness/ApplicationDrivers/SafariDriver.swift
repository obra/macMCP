// ABOUTME: This file implements a driver for the macOS Safari application for testing.
// ABOUTME: It provides methods to navigate web pages and interact with Safari.

import Foundation
import XCTest
@testable import MacMCP

/// Driver for the macOS Safari browser used in tests
public class SafariDriver: BaseApplicationDriver, @unchecked Sendable {
    /// Safari UI element roles
    public enum ElementRole {
        static let tabGroup = "AXTabGroup"
        static let button = "AXButton"
        static let textField = "AXTextField"
        static let webArea = "AXWebArea"
    }
    
    /// Safari UI element identifiers
    public enum ElementIdentifier {
        static let urlField = "WEB_BROWSER_ADDRESS_AND_SEARCH_FIELD"
        static let backButton = "BACK"
        static let forwardButton = "FORWARD"
        static let reloadButton = "RELOAD"
    }
    
    /// Create a new Safari driver
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
            bundleIdentifier: "com.apple.Safari",
            appName: "Safari",
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Navigate to a URL
    /// - Parameter url: The URL to navigate to
    /// - Returns: True if navigation was initiated successfully
    public func navigateTo(url: String) async throws -> Bool {
        // Ensure Safari is running
        if !isRunning() {
            let success = try await launch()
            if !success {
                return false
            }
            try await Task.sleep(for: .milliseconds(1000))
        }
        
        // Find URL field
        guard let window = try await getMainWindow() else {
            return false
        }
        
        // Find the URL text field
        var urlField: UIElement? = nil
        func findURLField(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.textField && 
               element.identifier.contains(ElementIdentifier.urlField) {
                return element
            }
            
            for child in element.children {
                if let field = findURLField(in: child) {
                    return field
                }
            }
            
            return nil
        }
        
        urlField = findURLField(in: window)
        
        guard let urlField = urlField else {
            return false
        }
        
        // Click the URL field
        try await interactionService.clickElement(identifier: urlField.identifier)
        
        // Select all text (Command+A)
        try await interactionService.pressKey(keyCode: 0, modifiers: [.command])
        
        // Type the URL
        try await interactionService.typeText(text: url)
        
        // Press Return to navigate
        try await interactionService.pressKey(keyCode: 36, modifiers: [])
        return true
    }
    
    /// Get the current URL from the address bar
    /// - Returns: The current URL or nil if not available
    public func getCurrentURL() async throws -> String? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Find the URL text field
        var urlField: UIElement? = nil
        func findURLField(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.textField && 
               element.identifier.contains(ElementIdentifier.urlField) {
                return element
            }
            
            for child in element.children {
                if let field = findURLField(in: child) {
                    return field
                }
            }
            
            return nil
        }
        
        urlField = findURLField(in: window)
        
        guard let urlField = urlField else {
            return nil
        }
        
        return urlField.value
    }
    
    /// Get the web content area
    /// - Returns: The web area element or nil if not found
    public func getWebArea() async throws -> UIElement? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Find the web area recursively
        func findWebArea(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.webArea {
                return element
            }
            
            for child in element.children {
                if let webArea = findWebArea(in: child) {
                    return webArea
                }
            }
            
            return nil
        }
        
        return findWebArea(in: window)
    }
    
    /// Get the page title
    /// - Returns: The page title or nil if not available
    public func getPageTitle() async throws -> String? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        return window.title
    }
    
    /// Click a link on the page by its text
    /// - Parameter linkText: The text of the link to click
    /// - Returns: True if the link was clicked successfully
    public func clickLink(linkText: String) async throws -> Bool {
        guard let webArea = try await getWebArea() else {
            return false
        }
        
        // Find link elements
        var linkElement: UIElement? = nil
        func findLink(in element: UIElement) -> UIElement? {
            if element.role == "AXLink" && element.title == linkText {
                return element
            }
            
            for child in element.children {
                if let link = findLink(in: child) {
                    return link
                }
            }
            
            return nil
        }
        
        linkElement = findLink(in: webArea)
        
        guard let linkElement = linkElement else {
            return false
        }
        
        // Click the link
        try await interactionService.clickElement(identifier: linkElement.identifier)
        return true
    }
    
    /// Go back to the previous page
    /// - Returns: True if navigation was successful
    public func goBack() async throws -> Bool {
        guard let window = try await getMainWindow() else {
            return false
        }
        
        // Find the back button
        var backButton: UIElement? = nil
        func findBackButton(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.button && 
               element.identifier.contains(ElementIdentifier.backButton) {
                return element
            }
            
            for child in element.children {
                if let button = findBackButton(in: child) {
                    return button
                }
            }
            
            return nil
        }
        
        backButton = findBackButton(in: window)
        
        guard let backButton = backButton else {
            return false
        }
        
        // Click the back button
        try await interactionService.clickElement(identifier: backButton.identifier)
        return true
    }
    
    /// Go forward to the next page
    /// - Returns: True if navigation was successful
    public func goForward() async throws -> Bool {
        guard let window = try await getMainWindow() else {
            return false
        }
        
        // Find the forward button
        var forwardButton: UIElement? = nil
        func findForwardButton(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.button && 
               element.identifier.contains(ElementIdentifier.forwardButton) {
                return element
            }
            
            for child in element.children {
                if let button = findForwardButton(in: child) {
                    return button
                }
            }
            
            return nil
        }
        
        forwardButton = findForwardButton(in: window)
        
        guard let forwardButton = forwardButton else {
            return false
        }
        
        // Click the forward button
        try await interactionService.clickElement(identifier: forwardButton.identifier)
        return true
    }
    
    /// Reload the current page
    /// - Returns: True if reload was successful
    public func reload() async throws -> Bool {
        guard let window = try await getMainWindow() else {
            return false
        }
        
        // Find the reload button
        var reloadButton: UIElement? = nil
        func findReloadButton(in element: UIElement) -> UIElement? {
            if element.role == ElementRole.button && 
               element.identifier.contains(ElementIdentifier.reloadButton) {
                return element
            }
            
            for child in element.children {
                if let button = findReloadButton(in: child) {
                    return button
                }
            }
            
            return nil
        }
        
        reloadButton = findReloadButton(in: window)
        
        guard let reloadButton = reloadButton else {
            // Use keyboard shortcut Command+R as fallback
            try await interactionService.pressKey(keyCode: 15, modifiers: [.command])
            return true
        }
        
        // Click the reload button
        try await interactionService.clickElement(identifier: reloadButton.identifier)
        return true
    }
    
    /// Wait for page load to complete
    /// - Parameter timeout: Maximum time to wait in seconds
    /// - Returns: True if page loaded within timeout
    public func waitForPageLoad(timeout: TimeInterval = 30) async throws -> Bool {
        let startTime = Date()
        var lastURL: String? = nil
        var stableTime: TimeInterval = 0
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Get current URL
            let currentURL = try await getCurrentURL()
            
            // If URL is stable for 1 second, consider page loaded
            if currentURL == lastURL {
                stableTime += 0.1
                if stableTime >= 1.0 {
                    return true
                }
            } else {
                stableTime = 0
                lastURL = currentURL
            }
            
            // Brief pause before checking again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        return false
    }
}