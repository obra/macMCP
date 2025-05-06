// ABOUTME: This file implements the ApplicationService for working with macOS applications.
// ABOUTME: It provides methods to open, activate, and query running applications.

import Foundation
import AppKit
import Logging
import MCP

/// Implementation of the ApplicationServiceProtocol for managing macOS applications
public actor ApplicationService: ApplicationServiceProtocol {
    /// Logger for the application service
    private let logger: Logger
    
    /// Initialize with a logger
    /// - Parameter logger: The logger to use
    public init(logger: Logger) {
        self.logger = logger
    }
    
    /// Opens an application by its bundle identifier.
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier of the application to open (e.g., "com.apple.Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    public func openApplication(bundleIdentifier: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        logger.info("Opening application", metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "arguments": "\(arguments ?? [])",
            "hideOthers": "\(hideOthers ?? false)"
        ])
        
        // Create a configuration for launching the app
        let configuration = NSWorkspace.OpenConfiguration()
        
        // Set app launch arguments if provided
        if let arguments = arguments {
            configuration.arguments = arguments
        }
        
        // Set creation options
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        
        // Create a URL representation for the bundle ID
        let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        
        guard let applicationURL = applicationURL else {
            logger.error("Application not found", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)"
            ])
            
            throw createApplicationNotFoundError(
                message: "Application with bundle identifier '\(bundleIdentifier)' not found",
                context: ["bundleIdentifier": bundleIdentifier]
            )
        }
        
        do {
            // Launch the application
            let runningApplication = try await NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            )
            
            // If successful and hideOthers is true, hide other applications
            if hideOthers == true {
                NSWorkspace.shared.hideOtherApplications()
            }
            
            logger.info("Application opened successfully", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "applicationName": "\(runningApplication.localizedName ?? "Unknown")",
                "processIdentifier": "\(runningApplication.processIdentifier)"
            ])
            
            return true
        } catch {
            logger.error("Failed to open application", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "error": "\(error.localizedDescription)"
            ])
            
            throw createApplicationLaunchError(
                message: "Failed to open application with bundle identifier: \(bundleIdentifier)",
                context: ["bundleIdentifier": bundleIdentifier]
                // Cannot include error due to compatibility issues
            )
        }
    }
    
    /// Opens an application by its name.
    /// - Parameters:
    ///   - name: The name of the application to open (e.g., "Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    public func openApplication(name: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        logger.info("Opening application by name", metadata: [
            "name": "\(name)",
            "arguments": "\(arguments ?? [])",
            "hideOthers": "\(hideOthers ?? false)"
        ])
        
        // Create a configuration for launching the app
        let configuration = NSWorkspace.OpenConfiguration()
        
        // Set app launch arguments if provided
        if let arguments = arguments {
            configuration.arguments = arguments
        }
        
        // Set creation options
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        
        // Find the application URL by name
        let applicationURL: URL?
        
        // NSWorkspace doesn't have a direct method for looking up by name,
        // so we need to search for the application
        let appPath = "/Applications/\(name).app"
        if FileManager.default.fileExists(atPath: appPath) {
            applicationURL = URL(fileURLWithPath: appPath)
        } else {
            // Search in the Applications directory
            applicationURL = try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: "/Applications"),
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).first(where: { url in
                url.lastPathComponent.lowercased().hasPrefix(name.lowercased()) &&
                url.pathExtension == "app"
            })
        }
        
        guard let applicationURL = applicationURL else {
            logger.error("Application not found by name", metadata: [
                "name": "\(name)"
            ])
            
            throw createApplicationNotFoundError(
                message: "Application with name '\(name)' not found",
                context: ["applicationName": name]
            )
        }
        
        do {
            // Launch the application
            let runningApplication = try await NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            )
            
            // If successful and hideOthers is true, hide other applications
            if hideOthers == true {
                NSWorkspace.shared.hideOtherApplications()
            }
            
            logger.info("Application opened successfully by name", metadata: [
                "name": "\(name)",
                "bundleIdentifier": "\(runningApplication.bundleIdentifier ?? "Unknown")",
                "processIdentifier": "\(runningApplication.processIdentifier)"
            ])
            
            return true
        } catch {
            logger.error("Failed to open application by name", metadata: [
                "name": "\(name)",
                "error": "\(error.localizedDescription)"
            ])
            
            throw createApplicationLaunchError(
                message: "Failed to open application with name: \(name)",
                context: ["applicationName": name]
                // Cannot include error due to compatibility issues
            )
        }
    }
    
    /// Activates an already running application by bringing it to the foreground.
    /// - Parameter bundleIdentifier: The bundle identifier of the application to activate
    /// - Returns: A boolean indicating whether the application was successfully activated
    /// - Throws: MacMCPErrorInfo if the application could not be activated
    public func activateApplication(bundleIdentifier: String) async throws -> Bool {
        logger.info("Activating application", metadata: [
            "bundleIdentifier": "\(bundleIdentifier)"
        ])
        
        // Find all running applications with this bundle ID
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        guard !runningApplications.isEmpty else {
            logger.error("No running application found to activate", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)"
            ])
            
            throw createApplicationNotFoundError(
                message: "No running application found with bundle identifier: \(bundleIdentifier)",
                context: ["bundleIdentifier": bundleIdentifier]
            )
        }
        
        // Activate the first running instance (usually there's only one)
        let application = runningApplications.first!
        let success = application.activate(options: [.activateIgnoringOtherApps])
        
        if success {
            logger.info("Application activated successfully", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "applicationName": "\(application.localizedName ?? "Unknown")",
                "processIdentifier": "\(application.processIdentifier)"
            ])
        } else {
            logger.error("Failed to activate application", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)"
            ])
            
            throw createApplicationError(
                message: "Failed to activate application with bundle identifier: \(bundleIdentifier)",
                context: ["bundleIdentifier": bundleIdentifier]
            )
        }
        
        return success
    }
    
    /// Returns a dictionary of running applications.
    /// - Returns: A dictionary mapping bundle identifiers to application names
    /// - Throws: MacMCPErrorInfo if the running applications could not be retrieved
    public func getRunningApplications() async throws -> [String: String] {
        logger.info("Getting running applications")
        
        var runningApps: [String: String] = [:]
        
        // Get all running applications
        let applications = NSWorkspace.shared.runningApplications
        
        // Filter to only user applications and extract bundle ID and name
        for app in applications where app.activationPolicy == .regular {
            if let bundleID = app.bundleIdentifier, let name = app.localizedName {
                runningApps[bundleID] = name
            }
        }
        
        logger.info("Found running applications", metadata: [
            "count": "\(runningApps.count)"
        ])
        
        return runningApps
    }
}