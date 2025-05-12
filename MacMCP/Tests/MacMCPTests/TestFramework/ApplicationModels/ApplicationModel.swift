// ABOUTME: This file defines the base application model for test applications.
// ABOUTME: It provides a common interface for interacting with applications in tests.

import Foundation
@testable import MacMCP
import AppKit

/// Protocol for modeling applications in test scenarios
public protocol ApplicationModel {
    /// Bundle identifier of the application
    var bundleId: String { get }
    
    /// Human-readable name of the application
    var appName: String { get }
    
    /// ToolChain instance for interacting with the application
    var toolChain: ToolChain { get }
    
    /// Launch the application
    /// - Parameters:
    ///   - arguments: Optional command line arguments
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: True if the application was successfully launched
    func launch(arguments: [String]?, hideOthers: Bool) async throws -> Bool
    
    /// Terminate the application
    /// - Returns: True if the application was successfully terminated
    func terminate() async throws -> Bool
    
    /// Check if the application is running
    /// - Returns: True if the application is running
    func isRunning() async throws -> Bool
    
    /// Get the main window of the application
    /// - Returns: The main window element, or nil if not found
    func getMainWindow() async throws -> UIElement?
    
    /// Get all windows of the application
    /// - Returns: Array of window elements
    func getAllWindows() async throws -> [UIElement]
    
    /// Wait for a UI element matching criteria to appear
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - timeout: Maximum time to wait
    /// - Returns: Matching UI element if found
    func waitForElement(matching criteria: UIElementCriteria, timeout: TimeInterval) async throws -> UIElement?
}

/// Base implementation of ApplicationModel with common functionality
open class BaseApplicationModel: ApplicationModel, @unchecked Sendable {
    /// Bundle identifier of the application
    public let bundleId: String
    
    /// Human-readable name of the application
    public let appName: String
    
    /// ToolChain instance for interacting with the application
    public let toolChain: ToolChain
    
    /// Create a new application model
    /// - Parameters:
    ///   - bundleId: Bundle identifier of the application
    ///   - appName: Human-readable name of the application
    ///   - toolChain: ToolChain instance
    public init(bundleId: String, appName: String, toolChain: ToolChain) {
        self.bundleId = bundleId
        self.appName = appName
        self.toolChain = toolChain
    }
    
    /// Launch the application
    /// - Parameters:
    ///   - arguments: Optional command line arguments
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: True if the application was successfully launched
    open func launch(
        arguments: [String]? = nil,
        hideOthers: Bool = false
    ) async throws -> Bool {
        // Check if the application is already running
        if try await isRunning() {
            // If it's already running, try to terminate it, but don't fail if we can't
            do {
                _ = try await terminate()
                // Brief pause after termination
                try await Task.sleep(for: .milliseconds(1000))
            } catch {
                // Log but continue - we'll try to use the existing instance
                print("Warning: Could not terminate existing instance of \(appName): \(error). Continuing with existing instance.")
            }
        }
        
        // Launch the application using the tool chain
        let success = try await toolChain.openApp(
            bundleId: bundleId,
            arguments: arguments,
            hideOthers: hideOthers
        )
        
        if !success {
            throw NSError(
                domain: "ApplicationModel",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to launch \(appName)"]
            )
        }
        
        // Wait for the application to initialize
        try await Task.sleep(for: .milliseconds(2000))
        
        return true
    }
    
    /// Terminate the application
    /// - Returns: True if the application was successfully terminated
    open func terminate() async throws -> Bool {
        // Use the tool chain to terminate the application
        return try await toolChain.terminateApp(bundleId: bundleId)
    }
    
    /// Check if the application is running
    /// - Returns: True if the application is running
    open func isRunning() async throws -> Bool {
        // Get running applications directly from NSRunningApplication
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        return !runningApps.isEmpty
    }
    
    /// Get the main window of the application
    /// - Returns: The main window element, or nil if not found
    open func getMainWindow() async throws -> UIElement? {
        // Get all windows
        let windows = try await getAllWindows()
        
        // Return the first window, if any
        return windows.first
    }
    
    /// Get all windows of the application
    /// - Returns: Array of window elements
    open func getAllWindows() async throws -> [UIElement] {
        // Use the tool chain to get application UI elements
        let element = try await toolChain.accessibilityService.getApplicationUIElement(
            bundleIdentifier: bundleId,
            recursive: true,
            maxDepth: 5
        )
        
        // Filter for window elements
        var windows: [UIElement] = []
        for child in element.children {
            if child.role == "AXWindow" {
                windows.append(child)
            }
        }
        
        return windows
    }
    
    /// Wait for a UI element matching criteria to appear
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - timeout: Maximum time to wait
    /// - Returns: Matching UI element if found
    open func waitForElement(
        matching criteria: UIElementCriteria,
        timeout: TimeInterval
    ) async throws -> UIElement? {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            // Search for the element
            let element = try await toolChain.findElement(
                matching: criteria,
                scope: "application",
                bundleId: bundleId
            )
            
            if let element = element {
                return element
            }
            
            // Pause before trying again
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // Element not found within timeout
        return nil
    }
}