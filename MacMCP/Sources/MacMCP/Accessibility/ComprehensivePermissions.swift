// ABOUTME: ComprehensivePermissions.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import AVFoundation

/// Utilities for checking and requesting all required macOS permissions
public enum ComprehensivePermissions {
    
    /// All the permission types we need to check
    public enum PermissionType: String, CaseIterable {
        case accessibility = "Accessibility"
        case screenRecording = "Screen Recording"
        
        public var description: String {
            switch self {
            case .accessibility:
                return "Accessibility permissions allow the app to interact with UI elements"
            case .screenRecording:
                return "Screen Recording permissions allow the app to capture screen content"
            }
        }
        
        public var systemSettingsPath: String {
            switch self {
            case .accessibility:
                return "Privacy & Security > Accessibility"
            case .screenRecording:
                return "Privacy & Security > Screen Recording"
            }
        }
    }
    
    /// Check if accessibility permissions are granted
    public static func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    
    /// Check if screen recording permissions are granted
    public static func hasScreenRecordingPermissions() -> Bool {
        // On macOS 10.15+, we can check screen recording permissions
        if #available(macOS 10.15, *) {
            let hasPermission = CGPreflightScreenCaptureAccess()
            return hasPermission
        }
        
        // On older versions, assume we have permission
        return true
    }
    
    /// Check all required permissions
    public static func checkAllPermissions() -> [PermissionType: Bool] {
        return [
            .accessibility: hasAccessibilityPermissions(),
            .screenRecording: hasScreenRecordingPermissions()
        ]
    }
    
    /// Get missing permissions
    public static func getMissingPermissions() -> [PermissionType] {
        let status = checkAllPermissions()
        return status.compactMap { permission, granted in
            granted ? nil : permission
        }
    }
    
    /// Request accessibility permissions (with prompt)
    public static func requestAccessibilityPermissions() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    
    /// Request screen recording permissions
    public static func requestScreenRecordingPermissions() {
        if #available(macOS 10.15, *) {
            // Request screen recording access - this will show the system prompt
            _ = CGRequestScreenCaptureAccess()
        }
    }
    
    /// Request all missing permissions
    public static func requestAllMissingPermissions() {
        let missing = getMissingPermissions()
        
        for permission in missing {
            switch permission {
            case .accessibility:
                requestAccessibilityPermissions()
            case .screenRecording:
                requestScreenRecordingPermissions()
            }
        }
    }
    
    /// Generate a user-friendly status report
    public static func generateStatusReport() -> String {
        let status = checkAllPermissions()
        var report = "Permission Status Report:\n"
        report += "=" + String(repeating: "=", count: 25) + "\n\n"
        
        for permission in PermissionType.allCases {
            let granted = status[permission] ?? false
            let icon = granted ? "✅" : "❌"
            let statusText = granted ? "GRANTED" : "MISSING"
            
            report += "\(icon) \(permission.rawValue): \(statusText)\n"
            if !granted {
                report += "   \(permission.description)\n"
                report += "   Grant in: System Settings > \(permission.systemSettingsPath)\n"
            }
            report += "\n"
        }
        
        let missing = getMissingPermissions()
        if missing.isEmpty {
            report += "🎉 All required permissions are granted!\n"
        } else {
            report += "⚠️  Missing \(missing.count) permission(s). Window management may not work properly.\n"
        }
        
        return report
    }
}