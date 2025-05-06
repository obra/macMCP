// ABOUTME: This file contains utilities for checking and requesting accessibility permissions.
// ABOUTME: It's essential for ensuring the app can access accessibility features.

import Foundation
import AppKit

/// Utilities for working with macOS accessibility permissions
public enum AccessibilityPermissions {
    /// Error thrown when there are issues with accessibility permissions
    public enum Error: Swift.Error, LocalizedError {
        case permissionDenied
        case promptFailed
        case timeout
        
        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Accessibility permission denied. The app requires accessibility permissions to function."
            case .promptFailed:
                return "Failed to prompt for accessibility permissions."
            case .timeout:
                return "Timed out waiting for accessibility permissions."
            }
        }
        
        public var recoverySuggestion: String? {
            switch self {
            case .permissionDenied:
                return "Please go to System Settings > Privacy & Security > Accessibility and enable this application."
            case .promptFailed, .timeout:
                return "Try manually enabling accessibility permissions in System Settings > Privacy & Security > Accessibility."
            }
        }
        
        /// Convert to MacMCPErrorInfo
        public var asMacMCPError: MacMCPErrorInfo {
            return MacMCPErrorInfo(
                category: .permissions,
                code: codeValue,
                message: errorDescription ?? "Accessibility permission error",
                context: [:]
                // Cannot include self as underlyingError due to type issues
            )
        }
        
        /// Get a numeric code for the error
        private var codeValue: Int {
            switch self {
            case .permissionDenied: return 1001
            case .promptFailed: return 1002
            case .timeout: return 1003
            }
        }
    }
    
    /// Check if the application has accessibility permissions
    /// - Returns: Boolean indicating if accessibility access is enabled
    public static func isAccessibilityEnabled() -> Bool {
        // AXIsProcessTrusted() is the API call to check if the current process
        // has permission to use accessibility APIs
        return AXIsProcessTrusted()
    }
    
    /// Request accessibility permissions if they aren't already granted
    /// - Parameter timeout: How long to wait for permission (in seconds)
    /// - Throws: AccessibilityPermissions.Error if permission cannot be obtained
    public static func requestAccessibilityPermissions(timeout: TimeInterval = 30.0) async throws {
        // If we already have permission, just return
        if isAccessibilityEnabled() {
            return
        }
        
        // Prompt the user for accessibility permissions
        // Create options with the prompt key
        // Using a literal string since direct access to kAXTrustedCheckOptionPrompt causes threading issues
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        // If the prompt fails or immediate permission is not granted,
        // we need to wait for the user to enable it in System Preferences
        if !trusted {
            // Wait for the user to enable permissions (up to the timeout)
            let startTime = Date()
            while !isAccessibilityEnabled() {
                // Check if we've exceeded the timeout
                if Date().timeIntervalSince(startTime) > timeout {
                    throw Error.timeout
                }
                
                // Sleep briefly to avoid spinning
                try await Task.sleep(for: .milliseconds(250))
            }
        }
        
        // Final check to make sure we have permission
        if !isAccessibilityEnabled() {
            throw Error.permissionDenied
        }
    }
}