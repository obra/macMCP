// ABOUTME: This file provides utilities for interacting with the macOS Calculator app in tests.
// ABOUTME: It handles launching, closing, and basic operations on the Calculator.

import Foundation
import AppKit
import XCTest
import Logging
@testable import MacMCP

/// Wrapper for interacting with the macOS Calculator app in end-to-end tests
@MainActor
class CalculatorApp: @unchecked Sendable {
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
    let interactionService: UIInteractionService
    
    /// The accessibility service for examining Calculator's UI
    let accessibilityService: AccessibilityService
    
    /// Maps keys on the keyboard to calculator functions
    private let keyboardMap = [
        "0": (keyCode: 29, character: "0"),
        "1": (keyCode: 18, character: "1"),
        "2": (keyCode: 19, character: "2"),
        "3": (keyCode: 20, character: "3"),
        "4": (keyCode: 21, character: "4"),
        "5": (keyCode: 23, character: "5"),
        "6": (keyCode: 22, character: "6"),
        "7": (keyCode: 26, character: "7"),
        "8": (keyCode: 28, character: "8"),
        "9": (keyCode: 25, character: "9"),
        "+": (keyCode: 24, character: "+"),
        "-": (keyCode: 27, character: "-"),
        "×": (keyCode: 28, character: "*"), // * for multiplication
        "*": (keyCode: 28, character: "*"), // * for multiplication
        "÷": (keyCode: 75, character: "/"), // / for division
        "/": (keyCode: 75, character: "/"), // / for division
        "=": (keyCode: 36, character: "="), // Return key for equals
        ".": (keyCode: 47, character: "."),
        "c": (keyCode: 8, character: "c")  // c key for clear
    ]
    
    // MARK: - Initialization
    
    /// Create a new Calculator app wrapper
    /// - Parameter services: Optional services to use (created on demand if nil)
    init(
        applicationService: ApplicationService? = nil,
        interactionService: UIInteractionService? = nil,
        accessibilityService: AccessibilityService? = nil
    ) {
        let logger = Logger(label: "com.macos.mcp.calculator")
        self.applicationService = applicationService ?? ApplicationService(logger: logger)
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
            print("Calculator already running, terminating existing instance...")
            // If already running, close existing instance for clean state
            let terminated = try await terminate()
            if !terminated {
                print("Failed to terminate existing Calculator instance, will proceed anyway")
                // Continue anyway rather than failing
            }
            
            // Brief pause after termination
            try await Task.sleep(for: .milliseconds(1000))
        }
        
        print("Launching Calculator app...")
        
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
        
        // Wait longer for app to become ready and fully initialize
        try await Task.sleep(for: .milliseconds(2000))
        
        // Find the running application
        for _ in 1...5 {
            application = NSRunningApplication.runningApplications(
                withBundleIdentifier: CalculatorApp.bundleId
            ).first
            
            if application != nil {
                print("Successfully found Calculator in running applications")
                break
            }
            
            print("Calculator app not found in running applications, retrying...")
            try await Task.sleep(for: .milliseconds(500))
        }
        
        guard application != nil else {
            XCTFail("Calculator app launched but not found in running applications after multiple attempts")
            return false
        }
        
        // Activate the application to ensure it's frontmost
        #if swift(>=5.9) && os(macOS) && canImport(AppKit)
        // Use the newer activation API on macOS 14+
        _ = application?.activate()
        #else
        // Use the deprecated API on older systems
        _ = application?.activate(options: .activateIgnoringOtherApps)
        #endif
        
        try await Task.sleep(for: .milliseconds(500))
        
        print("Calculator app launch completed successfully")
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
    
    /// Scan the Calculator app for all button-like elements
    /// This is useful for debugging and identifying buttons for testing
    func scanForButtons() async throws {
        print("Scanning Calculator app for all buttons:")
        
        // Get the application element with all children
        let appElement = try await accessibilityService.getApplicationUIElement(
            bundleIdentifier: CalculatorApp.bundleId,
            recursive: true,
            maxDepth: 25 // Use extremely deep search to find calculator buttons
        )
        
        print("SCANNING FOR BUTTONS WITH EXTRA VERBOSITY")
        print("=========================================")
        
        var buttonCandidates: [UIElement] = []
        
        // Recursive function to find all buttons
        func findAllButtons(in element: UIElement, depth: Int = 0, path: String = "root") {
            // Limit recursion depth for safety
            guard depth < 20 else { return }
            
            // Check if this is a button-like element
            if element.role.contains("Button") || 
               element.role == "AXButton" || 
               element.role == "AXButtonSubstitute" {
                
                // Log button details with ALL relevant properties
                let prefix = String(repeating: "  ", count: depth)
                let buttonDetails = "\(prefix)BUTTON at \(path): role=\(element.role), id=\(element.identifier), " +
                                   "title=\(element.title ?? "nil"), " +
                                   "value=\(element.value ?? "nil"), " +
                                   "description=\(element.description), " +
                                   "frame=\(element.frame)"
                print(buttonDetails)
                
                // Print additional button attributes that might help with identification
                if let attributes = element.attributes as? [String: Any] {
                    for (key, value) in attributes {
                        print("\(prefix)  Attribute: \(key) = \(value)")
                    }
                }
                
                // Print actions available on this button
                if !element.actions.isEmpty {
                    print("\(prefix)  Actions: \(element.actions.joined(separator: ", "))")
                }
                
                buttonCandidates.append(element)
            }
            
            // Log important container elements that might contain interactive controls
            if depth < 3 && (element.role.contains("Group") || element.role.contains("Container")) {
                let prefix = String(repeating: "  ", count: depth)
                print("\(prefix)CONTAINER: role=\(element.role), id=\(element.identifier), " +
                      "title=\(element.title ?? "nil"), description=\(element.description), " +
                      "children=\(element.children.count)")
            }
            
            // Recursively search children
            for (i, child) in element.children.enumerated() {
                let childPath = "\(path)/\(i):\(child.role)"
                findAllButtons(in: child, depth: depth + 1, path: childPath)
            }
        }
        
        // Start the recursive search from the app element
        findAllButtons(in: appElement)
        
        print("Found \(buttonCandidates.count) button candidates in the Calculator app")
    }
    
    /// Get the main window of the Calculator app
    /// - Returns: The UI element representing the main window
    func getMainWindow() async throws -> UIElement? {
        print("Getting Calculator main window")
        
        // First check if process is running
        if getProcessId() == nil {
            // Process is not running - launch it
            print("Calculator process not found, launching...")
            _ = try await launch()
            try await Task.sleep(for: .milliseconds(2000)) // Longer wait after launch
            
            // Check if launch was successful
            if getProcessId() == nil {
                print("Cannot get Calculator main window, app failed to launch")
                XCTFail("Cannot get Calculator main window, app failed to launch")
                return nil
            }
        }
        
        // Process is now running, get the window
        print("Accessing Calculator via process ID")
        
        do {
            // First, try to activate the Calculator app to bring it to front
            if let app = application {
                print("Activating Calculator application")
                #if swift(>=5.9) && os(macOS) && canImport(AppKit)
                _ = app.activate()
                #else
                _ = app.activate(options: .activateIgnoringOtherApps)
                #endif
                try await Task.sleep(for: .milliseconds(500))
            } else {
                print("No application reference available")
            }
            
            // Try multiple approaches to find the window
            
            // Approach 1: Direct application element lookup with minimal recursion
            print("Trying direct application element lookup...")
            if let pid = getProcessId() {
                print("Using process ID: \(pid)")
            }
            
            // Try multiple times with increasing maxDepth
            for attempt in 1...3 {
                let maxDepth = attempt * 5 // Increase depth with each attempt
                print("Attempt \(attempt) with maxDepth \(maxDepth)")
                
                let appElement = try await accessibilityService.getApplicationUIElement(
                    bundleIdentifier: CalculatorApp.bundleId,
                    recursive: true,
                    maxDepth: maxDepth 
                )
                
                // Check direct children first
                for child in appElement.children {
                    if child.role == "AXWindow" {
                        print("Successfully found Calculator window in direct children")
                        return child
                    }
                }
                
                // Recursive search with clear logging
                func findWindowRecursively(in element: UIElement, depth: Int = 0, path: String = "root") -> UIElement? {
                    // Limit recursion depth
                    guard depth < maxDepth else { return nil }
                    
                    // Check if this is a window
                    if element.role == "AXWindow" {
                        print("Found window at path: \(path)")
                        return element
                    }
                    
                    // Search children
                    for (i, child) in element.children.enumerated() {
                        let childPath = "\(path)/\(i):\(child.role)"
                        if let window = findWindowRecursively(in: child, depth: depth + 1, path: childPath) {
                            return window
                        }
                    }
                    
                    return nil
                }
                
                // Try the recursive search
                if let window = findWindowRecursively(in: appElement) {
                    print("Found Calculator window via search at depth \(maxDepth)")
                    return window
                }
                
                // Small delay before next attempt
                try await Task.sleep(for: .milliseconds(300))
            }
            
            // Last resort: look for any UI element we can use
            print("WARNING: Could not find standard Calculator window, looking for any usable UI element...")
            let lastResortElement = try await accessibilityService.getApplicationUIElement(
                bundleIdentifier: CalculatorApp.bundleId,
                recursive: false
            )
            
            if !lastResortElement.children.isEmpty {
                print("Using application element itself as fallback")
                return lastResortElement
            }
            
            print("No Calculator window found after all attempts")
            return nil
        } catch {
            print("Error getting application element: \(error)")
            throw error
        }
    }
}