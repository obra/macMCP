// ABOUTME: This file provides utilities for interacting with the macOS Calculator app in tests.
// ABOUTME: It handles launching, closing, and basic operations on the Calculator.

import Foundation
import AppKit
import XCTest
@testable import MacMCP

/// Wrapper for interacting with the macOS Calculator app in end-to-end tests
class CalculatorApp {
    // MARK: - Constants
    
    /// Bundle ID of the Calculator app
    static let bundleId = "com.apple.calculator"
    
    /// Application name for the Calculator app
    static let appName = "Calculator"
    
    /// Timeout values
    enum Timeout {
        static let launch: TimeInterval = 5.0
        static let termination: TimeInterval = 3.0
        static let uiOperation: TimeInterval = 2.0
    }
    
    // MARK: - Properties
    
    /// The running Calculator application instance
    private var application: NSRunningApplication?
    
    /// The application service for launching and terminating apps
    private let applicationService: ApplicationService
    
    /// The UI interaction service for manipulating Calculator
    private let interactionService: UIInteractionService
    
    /// The accessibility service for examining Calculator's UI
    private let accessibilityService: AccessibilityService
    
    // MARK: - Initialization
    
    /// Create a new Calculator app wrapper
    /// - Parameter services: Optional services to use (created on demand if nil)
    init(
        applicationService: ApplicationService? = nil,
        interactionService: UIInteractionService? = nil,
        accessibilityService: AccessibilityService? = nil
    ) {
        self.applicationService = applicationService ?? ApplicationService()
        self.interactionService = interactionService ?? UIInteractionService(
            accessibilityService: accessibilityService ?? AccessibilityService()
        )
        self.accessibilityService = accessibilityService ?? AccessibilityService()
    }
    
    /// Launch the Calculator app if it's not already running
    /// - Parameter arguments: Optional command line arguments to pass
    /// - Returns: True if successful
    func launch(arguments: [String]? = nil) async throws -> Bool {
        // Check if Calculator is already running
        if isRunning() {
            // If already running, just bring it to the front
            try await terminate() // Close existing instance for clean state
        }
        
        // Launch the app
        let success = try await applicationService.openApplication(
            bundleIdentifier: CalculatorApp.bundleId,
            arguments: arguments,
            hideOthers: false
        )
        
        guard success else {
            XCTFail("Failed to launch Calculator app")
            return false
        }
        
        // Wait for app to become ready
        try await Task.sleep(for: .milliseconds(500))
        
        // Find the running application
        application = NSRunningApplication.runningApplications(
            withBundleIdentifier: CalculatorApp.bundleId
        ).first
        
        guard application != nil else {
            XCTFail("Calculator app launched but not found in running applications")
            return false
        }
        
        return true
    }
    
    /// Check if Calculator is currently running
    /// - Returns: True if Calculator is running
    func isRunning() -> Bool {
        return NSRunningApplication.runningApplications(
            withBundleIdentifier: CalculatorApp.bundleId
        ).first != nil
    }
    
    /// Terminate the Calculator app if it's running
    /// - Returns: True if termination was successful or app was not running
    func terminate() async throws -> Bool {
        // If we have a reference to the application, terminate it
        if let app = application {
            if app.terminate() {
                // Wait for termination to complete
                let startTime = Date()
                while app.isTerminated == false {
                    if Date().timeIntervalSince(startTime) > Timeout.termination {
                        if app.forceTerminate() {
                            break
                        }
                        return false
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                application = nil
                return true
            }
            return false
        }
        
        // Find running Calculator instances and terminate them
        let runningApps = NSRunningApplication.runningApplications(
            withBundleIdentifier: CalculatorApp.bundleId
        )
        
        guard !runningApps.isEmpty else {
            // No running Calculator instances found
            return true
        }
        
        // Terminate all running Calculator instances
        var allTerminated = true
        for app in runningApps {
            if !app.terminate() {
                app.forceTerminate()
            }
            allTerminated = allTerminated && app.isTerminated
        }
        
        // Wait for termination to complete
        if !allTerminated {
            try await Task.sleep(for: .milliseconds(Int64(Timeout.termination * 1000)))
        }
        
        return true
    }
    
    /// Get the process ID of the running Calculator app
    /// - Returns: The process ID, or nil if not running
    func getProcessId() -> pid_t? {
        return application?.processIdentifier ?? NSRunningApplication.runningApplications(
            withBundleIdentifier: CalculatorApp.bundleId
        ).first?.processIdentifier
    }
    
    /// Get the main window of the Calculator app
    /// - Returns: The UI element representing the main window
    func getMainWindow() async throws -> UIElement? {
        guard let pid = getProcessId() else {
            XCTFail("Cannot get Calculator main window, app is not running")
            return nil
        }
        
        // Get the application element
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: CalculatorApp.bundleId,
            recursive: true,
            maxDepth: 3
        )
        
        // Find the main window (typically the first window)
        for child in appElement.children {
            if child.role == "AXWindow" {
                return child
            }
        }
        
        return nil
    }
}