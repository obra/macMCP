// ABOUTME: This file defines the interface for application drivers used in testing.
// ABOUTME: It provides a consistent way to interact with applications during tests.

import Foundation
import XCTest
@testable import MacMCP

/// Namespace for application driver related types
public enum ApplicationDrivers {
    /// Criteria for matching elements in applications
    public struct ElementCriteria {
        /// The role to match (e.g., "AXButton")
        public let role: String?
        
        /// The title to match
        public let title: String?
        
        /// The identifier to match
        public let identifier: String?
        
        /// Create new element criteria
        /// - Parameters:
        ///   - role: Optional role to match
        ///   - title: Optional title to match
        ///   - identifier: Optional identifier to match
        public init(role: String? = nil, title: String? = nil, identifier: String? = nil) {
            self.role = role
            self.title = title
            self.identifier = identifier
        }
    }
    
    /// Available test application types
    public enum TestApplicationType {
        /// macOS Calculator
        case calculator
        
        /// macOS TextEdit
        case textEdit
        
        /// macOS Safari
        case safari
    }
}

/// Base protocol for application drivers used in tests
public protocol TestApplicationDriver: Sendable {
    /// Bundle ID of the application
    var bundleIdentifier: String { get }
    
    /// Application service for launching and terminating
    var applicationService: ApplicationService { get }
    
    /// Accessibility service for interacting with UI
    var accessibilityService: AccessibilityService { get }
    
    /// UI interaction service for clicks and typing
    var interactionService: UIInteractionService { get }
    
    /// Launch the application
    /// - Returns: True if the application was launched successfully
    func launch() async throws -> Bool
    
    /// Terminate the application
    /// - Returns: True if the application was terminated successfully
    func terminate() async throws -> Bool
    
    /// Get the main window of the application
    /// - Returns: The main window element or nil if not found
    func getMainWindow() async throws -> UIElement?
    
    /// Get all windows of the application
    /// - Returns: Array of window elements
    func getAllWindows() async throws -> [UIElement]
    
    /// Check if the application is running
    /// - Returns: True if the application is running
    func isRunning() -> Bool
    
    /// Wait for a specific element to appear
    /// - Parameters:
    ///   - criteria: The criteria to match
    ///   - timeout: Maximum time to wait in seconds
    /// - Returns: The matching element or nil if not found
    func waitForElement(matching criteria: ApplicationDrivers.ElementCriteria, timeout: TimeInterval) async throws -> UIElement?
}

/// Base implementation of TestApplicationDriver with common functionality
open class BaseApplicationDriver: TestApplicationDriver, @unchecked Sendable {
    /// Bundle ID of the application
    public let bundleIdentifier: String
    
    /// Application service for launching and terminating
    public let applicationService: ApplicationService
    
    /// Accessibility service for interacting with UI
    public let accessibilityService: AccessibilityService
    
    /// UI interaction service for clicks and typing
    public let interactionService: UIInteractionService
    
    /// Name of the application (for logging)
    private let appName: String
    
    /// Create a new application driver
    /// - Parameters:
    ///   - bundleIdentifier: The bundle ID of the application
    ///   - appName: The human-readable name of the application
    ///   - applicationService: The application service to use
    ///   - accessibilityService: The accessibility service to use
    ///   - interactionService: The UI interaction service to use
    public init(
        bundleIdentifier: String,
        appName: String,
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.applicationService = applicationService
        self.accessibilityService = accessibilityService
        self.interactionService = interactionService
    }
    
    /// Launch the application
    /// - Returns: True if the application was launched successfully
    open func launch() async throws -> Bool {
        // Check if app is already running
        if isRunning() {
            try await terminate()
            
            // Brief pause after termination
            try await Task.sleep(for: .milliseconds(1000))
        }
        
        // Launch the app
        return try await applicationService.openApplication(
            bundleIdentifier: bundleIdentifier,
            arguments: nil,
            hideOthers: false
        )
    }
    
    /// Terminate the application
    /// - Returns: True if the application was terminated successfully
    open func terminate() async throws -> Bool {
        guard isRunning() else {
            // App is not running
            return true
        }
        
        // First try gentle termination
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        
        guard !runningApps.isEmpty else {
            // No running instances found
            return true
        }
        
        // Terminate all running instances
        var allTerminated = true
        for app in runningApps {
            if !app.terminate() {
                app.forceTerminate()
            }
            allTerminated = allTerminated && app.isTerminated
        }
        
        // Wait for termination to complete
        if !allTerminated {
            try await Task.sleep(for: .milliseconds(3000))
        }
        
        return !isRunning()
    }
    
    /// Get the main window of the application
    /// - Returns: The main window element or nil if not found
    open func getMainWindow() async throws -> UIElement? {
        // Ensure app is running
        if !isRunning() {
            // App is not running, try to launch it
            let launched = try await launch()
            guard launched else {
                return nil
            }
            
            // Wait after launch
            try await Task.sleep(for: .milliseconds(1000))
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleIdentifier,
            recursive: true,
            maxDepth: 10
        )
        
        // Find the main window (typically the first window)
        for child in appElement.children {
            if child.role == "AXWindow" {
                return child
            }
        }
        
        return nil
    }
    
    /// Get all windows of the application
    /// - Returns: Array of window elements
    open func getAllWindows() async throws -> [UIElement] {
        // Ensure app is running
        if !isRunning() {
            return []
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleIdentifier,
            recursive: true,
            maxDepth: 5
        )
        
        // Find all windows
        var windows: [UIElement] = []
        for child in appElement.children {
            if child.role == "AXWindow" {
                windows.append(child)
            }
        }
        
        return windows
    }
    
    /// Check if the application is running
    /// - Returns: True if the application is running
    open func isRunning() -> Bool {
        return NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).first != nil
    }
    
    /// Wait for a specific element to appear
    /// - Parameters:
    ///   - criteria: The criteria to match
    ///   - timeout: Maximum time to wait in seconds
    /// - Returns: The matching element or nil if not found
    open func waitForElement(matching criteria: ApplicationDrivers.ElementCriteria, timeout: TimeInterval) async throws -> UIElement? {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Get the application element
            let appElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: bundleIdentifier,
                recursive: true,
                maxDepth: 10
            )
            
            // Search for the element
            if let element = try await findElement(in: appElement, matching: criteria) {
                return element
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Element not found within timeout
        return nil
    }
    
    /// Find an element matching criteria in the element hierarchy
    /// - Parameters:
    ///   - element: The root element to search in
    ///   - criteria: The criteria to match
    /// - Returns: The matching element or nil if not found
    private func findElement(in element: UIElement, matching criteria: ApplicationDrivers.ElementCriteria) async throws -> UIElement? {
        // Check if current element matches
        var isMatch = true
        
        if let role = criteria.role {
            isMatch = isMatch && element.role == role
        }
        
        if let title = criteria.title {
            isMatch = isMatch && element.title == title
        }
        
        if let identifier = criteria.identifier {
            isMatch = isMatch && element.identifier == identifier
        }
        
        if isMatch {
            return element
        }
        
        // Recursively search children
        for child in element.children {
            if let match = try await findElement(in: child, matching: criteria) {
                return match
            }
        }
        
        return nil
    }
}