// ABOUTME: Protocol defining the interface for application management functionality.
// ABOUTME: Provides methods for opening, activating, and querying applications.

import Foundation

/// Protocol defining the interface for application management functionality.
public protocol ApplicationServiceProtocol: Sendable {
    /// Opens an application by its bundle identifier.
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier of the application to open (e.g., "com.apple.Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    func openApplication(bundleIdentifier: String, arguments: [String]?, hideOthers: Bool?) async throws -> Bool
    
    /// Opens an application by its name.
    /// - Parameters:
    ///   - name: The name of the application to open (e.g., "Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    func openApplication(name: String, arguments: [String]?, hideOthers: Bool?) async throws -> Bool
    
    /// Activates an already running application by bringing it to the foreground.
    /// - Parameter bundleIdentifier: The bundle identifier of the application to activate
    /// - Returns: A boolean indicating whether the application was successfully activated
    /// - Throws: MacMCPErrorInfo if the application could not be activated
    func activateApplication(bundleIdentifier: String) async throws -> Bool
    
    /// Returns a dictionary of running applications.
    /// - Returns: A dictionary mapping bundle identifiers to application names
    /// - Throws: MacMCPErrorInfo if the running applications could not be retrieved
    func getRunningApplications() async throws -> [String: String]
}