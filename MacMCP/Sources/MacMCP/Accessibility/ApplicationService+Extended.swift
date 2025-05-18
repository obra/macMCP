// ABOUTME: ApplicationService+Extended.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging

/// Extensions to ApplicationService for enhanced application management
extension ApplicationService {
  /// Launch an application with detailed configuration
  /// - Parameters:
  ///   - name: Optional application name (e.g., "Safari")
  ///   - bundleIdentifier: Optional bundle identifier (e.g., "com.apple.Safari")
  ///   - arguments: Optional array of command-line arguments
  ///   - hideOthers: Whether to hide other applications when opening this one
  ///   - waitForLaunch: Whether to wait for the application to fully launch
  ///   - timeout: Timeout in seconds for waiting for application launch
  /// - Returns: Detailed launch result with process information
  /// - Throws: MacMCPErrorInfo if the application could not be launched
  public func launchApplication(
    name: String?,
    bundleIdentifier: String?,
    arguments: [String] = [],
    hideOthers: Bool = false,
    waitForLaunch: Bool = true,
    timeout: TimeInterval = 30.0,
  ) async throws -> ApplicationLaunchResult {
    // We need at least a bundle ID or name
    guard name != nil || bundleIdentifier != nil else {
      throw createApplicationLaunchError(
        message: "Either application name or bundle identifier must be provided",
        context: [:],
      )
    }

    // Validate and find the application
    let appInfo: ApplicationInfo
    if let bundleId = bundleIdentifier {
      // Try to validate by bundle ID first
      appInfo = try await validateApplication(bundleIdentifier: bundleId)
    } else if let appName = name {
      // Try to validate by name
      appInfo = try await validateApplicationByName(appName)
    } else {
      // This should never happen due to the guard above
      throw createApplicationLaunchError(
        message: "Either application name or bundle identifier must be provided",
        context: [:],
      )
    }

    // If the application is already running, update and return information
    if appInfo.isRunning, let pid = appInfo.processId {
      // If we need to activate the application
      if let runningApp = NSRunningApplication(processIdentifier: pid) {
        // Activate the application
        _ = runningApp.activate(options: [])

        // Hide other applications if requested
        if hideOthers {
          NSWorkspace.shared.hideOtherApplications()
        }

        // Return information about the existing application
        return ApplicationLaunchResult(
          success: true,
          processIdentifier: pid,
          bundleIdentifier: appInfo.bundleIdentifier,
          applicationName: appInfo.name,
        )
      }
    }

    // Launch the application with a configuration
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.arguments = arguments
    configuration.createsNewApplicationInstance = false
    configuration.activates = true

    // Launch the application
    do {
      let runningApplication = try await NSWorkspace.shared.openApplication(
        at: appInfo.url,
        configuration: configuration,
      )

      // Hide other applications if requested
      if hideOthers {
        NSWorkspace.shared.hideOtherApplications()
      }

      // Wait for the application to launch if requested
      if waitForLaunch {
        // Wait for the application to finish launching
        let startTime = Date()
        var isLaunched = runningApplication.isFinishedLaunching

        while !isLaunched, Date().timeIntervalSince(startTime) < timeout {
          // Sleep briefly to avoid spinning
          try await Task.sleep(for: .milliseconds(100))

          // Check if the application has finished launching
          isLaunched = runningApplication.isFinishedLaunching
        }

        // Check if timeout occurred
        if !isLaunched {
          // Application didn't finish launching within timeout but we'll continue
        }
      }

      // Return result with application information
      return ApplicationLaunchResult(
        success: true,
        processIdentifier: runningApplication.processIdentifier,
        bundleIdentifier: runningApplication.bundleIdentifier ?? appInfo.bundleIdentifier,
        applicationName: runningApplication.localizedName ?? appInfo.name,
      )
    } catch {
      logger.error(
        "Failed to launch application",
        metadata: [
          "bundleIdentifier": "\(appInfo.bundleIdentifier)",
          "name": "\(appInfo.name)",
          "error": "\(error.localizedDescription)",
        ])

      throw createApplicationLaunchError(
        message: "Failed to launch application: \(error.localizedDescription)",
        context: [
          "bundleIdentifier": appInfo.bundleIdentifier,
          "applicationName": appInfo.name,
        ],
      )
    }
  }

  /// Terminate an application by its bundle identifier
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier of the application to terminate
  ///   - timeout: Timeout in seconds for waiting for termination completion
  /// - Returns: Whether the application was successfully terminated
  /// - Throws: MacMCPErrorInfo if the application could not be terminated
  public func terminateApplication(
    bundleIdentifier: String,
    timeout: TimeInterval = 10.0,
  ) async throws -> Bool {
    logger.info(
      "Terminating application",
      metadata: [
        "bundleIdentifier": "\(bundleIdentifier)",
        "timeout": "\(timeout)",
      ])

    // First check if the application is running
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier)

    if runningApps.isEmpty {
      logger.info(
        "Application is not running",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
      return true  // Already terminated
    }

    // Track if all instances terminated successfully
    var allTerminated = true

    // Attempt to terminate each instance
    for app in runningApps {
      let success = app.terminate()

      if !success {
        logger.warning(
          "Failed to request termination for application instance",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "processId": "\(app.processIdentifier)",
          ])
        allTerminated = false
      }
    }

    // If all terminate requests were successful, wait for the applications to actually terminate
    if allTerminated {
      logger.debug(
        "Waiting for application instances to terminate",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)",
          "instances": "\(runningApps.count)",
          "timeout": "\(timeout)",
        ])

      // Wait for the application to terminate
      let startTime = Date()
      var isTerminated = NSRunningApplication.runningApplications(
        withBundleIdentifier: bundleIdentifier
      ).isEmpty

      while !isTerminated, Date().timeIntervalSince(startTime) < timeout {
        // Sleep briefly to avoid spinning
        try await Task.sleep(for: .milliseconds(100))

        // Check if the application has terminated
        isTerminated =
          NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
      }

      // If not terminated within timeout, update result
      if !isTerminated {
        logger.warning(
          "Application did not terminate within timeout",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "timeout": "\(timeout)",
          ])
        allTerminated = false
      }
    }

    // If all applications terminated successfully, update our cache
    if allTerminated {
      // If we have this app in our cache, update it
      if var appInfo = await findApplicationByBundleID(bundleIdentifier) {
        // Update to mark as not running
        appInfo.processId = nil
        appCache[bundleIdentifier] = appInfo
      }

      logger.info(
        "Application terminated successfully",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    } else {
      logger.error(
        "Failed to terminate all application instances",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    }

    return allTerminated
  }

  /// Force terminate an application by its bundle identifier
  /// - Parameter bundleIdentifier: The bundle identifier of the application to force terminate
  /// - Returns: Whether the application was successfully terminated
  /// - Throws: MacMCPErrorInfo if the application could not be terminated
  public func forceTerminateApplication(
    bundleIdentifier: String,
  ) async throws -> Bool {
    logger.info(
      "Force terminating application",
      metadata: [
        "bundleIdentifier": "\(bundleIdentifier)"
      ])

    // First check if the application is running
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier)

    if runningApps.isEmpty {
      logger.info(
        "Application is not running",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
      return true  // Already terminated
    }

    // Track if all instances terminated successfully
    var allTerminated = true

    // Attempt to force terminate each instance
    for app in runningApps {
      let success = app.forceTerminate()

      if !success {
        logger.warning(
          "Failed to force terminate application instance",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "processId": "\(app.processIdentifier)",
          ])
        allTerminated = false
      }
    }

    // Wait briefly to ensure the application has time to terminate
    try await Task.sleep(for: .milliseconds(500))

    // Verify that all instances have terminated
    let stillRunning = !NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier
    ).isEmpty

    if stillRunning {
      logger.error(
        "Some application instances are still running after force termination",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
      allTerminated = false
    } else {
      // If we have this app in our cache, update it
      if var appInfo = await findApplicationByBundleID(bundleIdentifier) {
        // Update to mark as not running
        appInfo.processId = nil
        appCache[bundleIdentifier] = appInfo
      }

      logger.info(
        "Application force terminated successfully",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    }

    return allTerminated
  }

  /// Hide an application
  /// - Parameter bundleIdentifier: The bundle identifier of the application to hide
  /// - Returns: Whether the application was successfully hidden
  /// - Throws: MacMCPErrorInfo if the application could not be hidden
  public func hideApplication(
    bundleIdentifier: String,
  ) async throws -> Bool {
    logger.info(
      "Hiding application",
      metadata: [
        "bundleIdentifier": "\(bundleIdentifier)"
      ])

    // First check if the application is running
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier)

    if runningApps.isEmpty {
      logger.warning(
        "Application is not running",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])

      throw createApplicationNotRunningError(
        message: "Application is not running",
        context: ["bundleIdentifier": bundleIdentifier],
      )
    }
    
    // Track if any instances were hidden successfully
    var anyHidden = false
    var atLeastOneFailure = false

    // Attempt to hide each instance
    for app in runningApps {
      // First try to make sure the app is not active before hiding
      if app.isActive {
        // If active, try to activate another app first
        if let anotherApp = NSWorkspace.shared.runningApplications.first(where: { 
          $0.activationPolicy == .regular && 
          $0.bundleIdentifier != bundleIdentifier && 
          !$0.isHidden
        }) {
          _ = anotherApp.activate(options: [])
          // Give it a moment to take effect
          try? await Task.sleep(for: .milliseconds(100))
        }
      }
      
      // Record the initial state
      let wasHidden = app.isHidden
      
      // Try to hide the application
      let hideResult = app.hide()
      
      // Give macOS a moment to process the hide request
      try? await Task.sleep(for: .milliseconds(200))
      
      // Refresh the application state after the hide attempt
      if let updatedApp = NSRunningApplication(processIdentifier: app.processIdentifier) {
        // Check if the app is now actually hidden, regardless of the hide() return value
        if updatedApp.isHidden {
          anyHidden = true
          logger.debug(
            "Application is now hidden, hide() returned \(hideResult)",
            metadata: [
              "bundleIdentifier": "\(bundleIdentifier)",
              "processId": "\(app.processIdentifier)",
              "wasAlreadyHidden": "\(wasHidden)",
            ])
        } else {
          logger.warning(
            "Failed to hide application instance",
            metadata: [
              "bundleIdentifier": "\(bundleIdentifier)",
              "processId": "\(app.processIdentifier)",
              "isActive": "\(app.isActive)",
              "hideResult": "\(hideResult)",
            ])
          atLeastOneFailure = true
        }
      } else {
        // Application is no longer running
        logger.warning(
          "Application is no longer running after hide attempt",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "processId": "\(app.processIdentifier)",
          ])
        atLeastOneFailure = true
      }
    }

    // Consider the operation successful if at least one instance was hidden
    let overallSuccess = anyHidden
    
    if overallSuccess {
      if atLeastOneFailure {
        logger.info(
          "Some application instances were hidden successfully",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)"
          ])
      } else {
        logger.info(
          "All application instances hidden successfully",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)"
          ])
      }
    } else {
      logger.error(
        "Failed to hide any application instances",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    }

    return overallSuccess
  }

  /// Unhide an application
  /// - Parameter bundleIdentifier: The bundle identifier of the application to unhide
  /// - Returns: Whether the application was successfully unhidden
  /// - Throws: MacMCPErrorInfo if the application could not be unhidden
  public func unhideApplication(
    bundleIdentifier: String,
  ) async throws -> Bool {
    logger.info(
      "Unhiding application",
      metadata: [
        "bundleIdentifier": "\(bundleIdentifier)"
      ])

    // First check if the application is running
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleIdentifier)

    if runningApps.isEmpty {
      logger.warning(
        "Application is not running",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])

      throw createApplicationNotRunningError(
        message: "Application is not running",
        context: ["bundleIdentifier": bundleIdentifier],
      )
    }

    // Track if all instances were unhidden successfully
    var allUnhidden = true

    // Attempt to unhide each instance
    for app in runningApps {
      let success = app.unhide()

      if !success {
        logger.warning(
          "Failed to unhide application instance",
          metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "processId": "\(app.processIdentifier)",
          ])
        allUnhidden = false
      }
    }

    if allUnhidden {
      logger.info(
        "Application unhidden successfully",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    } else {
      logger.error(
        "Failed to unhide all application instances",
        metadata: [
          "bundleIdentifier": "\(bundleIdentifier)"
        ])
    }

    return allUnhidden
  }

  /// Hide all applications except the specified one
  /// - Parameter exceptBundleIdentifier: The bundle identifier of the application to keep visible
  /// - Returns: Whether the operation was successful
  /// - Throws: MacMCPErrorInfo if the operation fails
  public func hideOtherApplications(
    exceptBundleIdentifier: String? = nil,
  ) async throws -> Bool {
    logger.info(
      "Hiding other applications",
      metadata: [
        "exceptBundleIdentifier": "\(exceptBundleIdentifier ?? "nil")"
      ])

    // If a specific application is specified, make sure it is activated first
    if let bundleId = exceptBundleIdentifier {
      do {
        // Try to activate the application first to ensure it's the frontmost
        _ = try await activateApplication(bundleIdentifier: bundleId)
      } catch {
        // Just continue with hiding others even if activation fails
      }
    }

    // Use NSWorkspace to hide other applications
    NSWorkspace.shared.hideOtherApplications()

    // Unfortunately, there's no direct way to verify if this succeeded
    // We'll assume it worked if no exceptions were thrown
    return true
  }

  /// Get information about the frontmost (active) application
  /// - Returns: Application state information for the frontmost application, or nil if none is active
  /// - Throws: MacMCPErrorInfo if the information could not be retrieved
  public func getFrontmostApplication() async throws -> ApplicationStateInfo? {
    // Get all running applications
    let runningApps = NSWorkspace.shared.runningApplications

    // Find the active application
    if let frontmostApp = runningApps.first(where: { $0.isActive }) {
      // Create and return application state information
      return ApplicationStateInfo(
        bundleIdentifier: frontmostApp.bundleIdentifier ?? "",
        name: frontmostApp.localizedName ?? "",
        isRunning: true,
        processId: frontmostApp.processIdentifier,
        isActive: frontmostApp.isActive,
        isFinishedLaunching: frontmostApp.isFinishedLaunching,
        url: frontmostApp.bundleURL,
      )
    }

    // No active application found
    return nil
  }
}
