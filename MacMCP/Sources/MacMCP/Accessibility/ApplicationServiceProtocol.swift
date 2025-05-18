// ABOUTME: ApplicationServiceProtocol.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation

/// Information about an application's state
public struct ApplicationStateInfo: Sendable, Equatable {
  /// The bundle identifier of the application
  public let bundleIdentifier: String

  /// The application's name
  public let name: String

  /// Whether the application is running
  public let isRunning: Bool

  /// The process identifier if the application is running
  public let processId: Int32?

  /// Whether the application is active (has focus)
  public let isActive: Bool

  /// Whether the application has finished launching
  public let isFinishedLaunching: Bool

  /// The application's URL (path)
  public let url: URL?

  /// Create a new application state info
  public init(
    bundleIdentifier: String,
    name: String,
    isRunning: Bool,
    processId: Int32?,
    isActive: Bool,
    isFinishedLaunching: Bool,
    url: URL?
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.isRunning = isRunning
    self.processId = processId
    self.isActive = isActive
    self.isFinishedLaunching = isFinishedLaunching
    self.url = url
  }
}

/// Type of application state change
public enum ApplicationStateChangeType: String, Sendable {
  /// Application was launched
  case launched

  /// Application was terminated
  case terminated

  /// Application became active (got focus)
  case activated

  /// Application lost focus
  case deactivated

  /// Application moved to background
  case hidden

  /// Application was unhidden
  case unhidden
}

/// Information about an application state change
public struct ApplicationStateChange: Sendable, Equatable {
  /// The type of state change
  public let type: ApplicationStateChangeType

  /// Information about the application
  public let application: ApplicationStateInfo

  /// When the change occurred
  public let timestamp: Date

  /// Create a new application state change
  public init(
    type: ApplicationStateChangeType,
    application: ApplicationStateInfo,
    timestamp: Date = Date()
  ) {
    self.type = type
    self.application = application
    self.timestamp = timestamp
  }
}

/// Result of an application launch operation
public struct ApplicationLaunchResult: Sendable, Equatable {
  /// Whether the launch was successful
  public let success: Bool

  /// The process identifier of the launched application
  public let processIdentifier: Int32

  /// The bundle identifier of the launched application
  public let bundleIdentifier: String

  /// The name of the launched application
  public let applicationName: String

  /// Create a new launch result
  public init(
    success: Bool,
    processIdentifier: Int32,
    bundleIdentifier: String,
    applicationName: String
  ) {
    self.success = success
    self.processIdentifier = processIdentifier
    self.bundleIdentifier = bundleIdentifier
    self.applicationName = applicationName
  }
}

/// Protocol defining the interface for application management functionality.
public protocol ApplicationServiceProtocol: Sendable {
  /// Opens an application by its bundle identifier.
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier of the application to open (e.g., "com.apple.Safari")
  ///   - arguments: Optional array of command-line arguments to pass to the application
  ///   - hideOthers: Whether to hide other applications when opening this one
  /// - Returns: A boolean indicating whether the application was successfully opened
  /// - Throws: MacMCPErrorInfo if the application could not be opened
  func openApplication(bundleIdentifier: String, arguments: [String]?, hideOthers: Bool?)
    async throws -> Bool

  /// Opens an application by its name.
  /// - Parameters:
  ///   - name: The name of the application to open (e.g., "Safari")
  ///   - arguments: Optional array of command-line arguments to pass to the application
  ///   - hideOthers: Whether to hide other applications when opening this one
  /// - Returns: A boolean indicating whether the application was successfully opened
  /// - Throws: MacMCPErrorInfo if the application could not be opened
  func openApplication(name: String, arguments: [String]?, hideOthers: Bool?) async throws -> Bool

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
  func launchApplication(
    name: String?,
    bundleIdentifier: String?,
    arguments: [String],
    hideOthers: Bool,
    waitForLaunch: Bool,
    timeout: TimeInterval,
  ) async throws -> ApplicationLaunchResult

  /// Terminate an application by its bundle identifier
  /// - Parameters:
  ///   - bundleIdentifier: The bundle identifier of the application to terminate
  ///   - timeout: Timeout in seconds for waiting for termination completion
  /// - Returns: Whether the application was successfully terminated
  /// - Throws: MacMCPErrorInfo if the application could not be terminated
  func terminateApplication(
    bundleIdentifier: String,
    timeout: TimeInterval,
  ) async throws -> Bool

  /// Force terminate an application by its bundle identifier
  /// - Parameter bundleIdentifier: The bundle identifier of the application to force terminate
  /// - Returns: Whether the application was successfully terminated
  /// - Throws: MacMCPErrorInfo if the application could not be terminated
  func forceTerminateApplication(
    bundleIdentifier: String,
  ) async throws -> Bool

  /// Activates an already running application by bringing it to the foreground.
  /// - Parameter bundleIdentifier: The bundle identifier of the application to activate
  /// - Returns: A boolean indicating whether the application was successfully activated
  /// - Throws: MacMCPErrorInfo if the application could not be activated
  func activateApplication(bundleIdentifier: String) async throws -> Bool

  /// Hide an application
  /// - Parameter bundleIdentifier: The bundle identifier of the application to hide
  /// - Returns: Whether the application was successfully hidden
  /// - Throws: MacMCPErrorInfo if the application could not be hidden
  func hideApplication(
    bundleIdentifier: String,
  ) async throws -> Bool

  /// Unhide an application
  /// - Parameter bundleIdentifier: The bundle identifier of the application to unhide
  /// - Returns: Whether the application was successfully unhidden
  /// - Throws: MacMCPErrorInfo if the application could not be unhidden
  func unhideApplication(
    bundleIdentifier: String,
  ) async throws -> Bool

  /// Hide all applications except the specified one
  /// - Parameter exceptBundleIdentifier: The bundle identifier of the application to keep visible
  /// - Returns: Whether the operation was successful
  /// - Throws: MacMCPErrorInfo if the operation fails
  func hideOtherApplications(
    exceptBundleIdentifier: String?,
  ) async throws -> Bool

  /// Returns a dictionary of running applications.
  /// - Returns: A dictionary mapping bundle identifiers to application names
  /// - Throws: MacMCPErrorInfo if the running applications could not be retrieved
  func getRunningApplications() async throws -> [String: String]

  /// Get information about the frontmost (active) application
  /// - Returns: Application state information for the frontmost application, or nil if none is active
  /// - Throws: MacMCPErrorInfo if the information could not be retrieved
  func getFrontmostApplication() async throws -> ApplicationStateInfo?

  /// Start observing application state changes.
  /// - Parameter notificationHandler: The handler to call when applications launch or terminate
  /// - Returns: A unique identifier for this observation that can be used to stop it
  /// - Throws: MacMCPErrorInfo if the observation could not be started
  func startObservingApplications(
    notificationHandler: @escaping @Sendable (ApplicationStateChange) async
      -> Void,
  ) async throws -> String

  /// Stop observing application state changes.
  /// - Parameter observerId: The identifier of the observation to stop
  /// - Throws: MacMCPErrorInfo if the observation could not be stopped
  func stopObservingApplications(observerId: String) async throws

  /// Check if an application is running.
  /// - Parameter bundleIdentifier: The bundle identifier of the application to check
  /// - Returns: True if the application is running, false otherwise
  /// - Throws: MacMCPErrorInfo if the check fails
  func isApplicationRunning(bundleIdentifier: String) async throws -> Bool

  /// Get information about a running application.
  /// - Parameter bundleIdentifier: The bundle identifier of the application
  /// - Returns: Application information, or nil if the application is not running
  /// - Throws: MacMCPErrorInfo if the information could not be retrieved
  func getApplicationInfo(bundleIdentifier: String) async throws -> ApplicationStateInfo?
}
