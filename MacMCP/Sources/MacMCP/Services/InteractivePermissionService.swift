// ABOUTME: InteractivePermissionService.swift
// ABOUTME: Provides interactive permission checking and user guidance workflows

import Foundation
import AppKit

/// Service for interactive permission checking and user guidance
public class InteractivePermissionService {
    
    /// Configuration for permission checking behavior
    public struct Configuration: Sendable {
        public let checkOnStartup: Bool
        public let showGuidanceForMissing: Bool
        public let offerToOpenSettings: Bool
        public let timeoutForPermissionRequest: TimeInterval
        
        public init(
            checkOnStartup: Bool = true,
            showGuidanceForMissing: Bool = true,
            offerToOpenSettings: Bool = true,
            timeoutForPermissionRequest: TimeInterval = 30.0
        ) {
            self.checkOnStartup = checkOnStartup
            self.showGuidanceForMissing = showGuidanceForMissing
            self.offerToOpenSettings = offerToOpenSettings
            self.timeoutForPermissionRequest = timeoutForPermissionRequest
        }
        
        public static let `default` = Configuration()
    }
    
    /// Perform comprehensive permission check with interactive guidance
    public static func performStartupPermissionCheck(configuration: Configuration = .default) {
        guard configuration.checkOnStartup else { return }
        
        // Only check for accessibility at startup - it's needed for most tools
        // Screen recording will be checked when screenshot tools are used
        if !ComprehensivePermissions.hasAccessibilityPermissions() {
            showPermissionSetupDialogForAccessibility()
        }
    }
    
    /// Show permission setup dialog (called manually or when features fail)
    public static func showPermissionSetupDialog() {
        let missingPermissions = ComprehensivePermissions.getMissingPermissions()
        if missingPermissions.isEmpty {
            return
        }
        
        let hostInfo = HostProcessDetectionService.detectHostProcess()
        
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
            showSimplePermissionDialog(hostInfo: hostInfo, missingPermissions: missingPermissions)
        }
    }
    
    /// Show permission setup dialog specifically for accessibility (startup check)
    public static func showPermissionSetupDialogForAccessibility() {
        let hostInfo = HostProcessDetectionService.detectHostProcess()
        
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
            showSimplePermissionDialog(hostInfo: hostInfo, missingPermissions: [.accessibility])
        }
    }
    
    /// Show permission setup dialog for screen recording (when screenshot tools are used)
    public static func showPermissionSetupDialogForScreenRecording() {
        let hostInfo = HostProcessDetectionService.detectHostProcess()
        
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
            showSimplePermissionDialog(hostInfo: hostInfo, missingPermissions: [.screenRecording])
        }
    }
    
    /// Handle permission error from a tool - show setup dialog if needed
    public static func handlePermissionError() {
        let missingPermissions = ComprehensivePermissions.getMissingPermissions()
        if !missingPermissions.isEmpty {
            showPermissionSetupDialog()
        }
    }
    
    /// Request permissions with prompts and wait for user action
    public static func requestPermissionsWithPrompts(timeout: TimeInterval = 30.0) async throws {
        let missingPermissions = ComprehensivePermissions.getMissingPermissions()
        
        for permission in missingPermissions {
            print("🔄 Requesting \(permission.rawValue) permission...")
            
            switch permission {
            case .accessibility:
                try await requestAccessibilityWithPrompt(timeout: timeout)
            case .screenRecording:
                requestScreenRecordingWithPrompt()
            }
            
            // Brief pause between permission requests
            try await Task.sleep(for: .milliseconds(500))
        }
    }
    
    /// Request accessibility permission with user prompt
    private static func requestAccessibilityWithPrompt(timeout: TimeInterval) async throws {
        if ComprehensivePermissions.hasAccessibilityPermissions() {
            return
        }
        
        print("📝 Accessibility permission prompt will appear...")
        ComprehensivePermissions.requestAccessibilityPermissions()
        
        // Wait for permission to be granted
        let startTime = Date()
        while !ComprehensivePermissions.hasAccessibilityPermissions() {
            if Date().timeIntervalSince(startTime) > timeout {
                print("⏰ Timeout waiting for accessibility permission.")
                break
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        
        if ComprehensivePermissions.hasAccessibilityPermissions() {
            print("✅ Accessibility permission granted!")
        }
    }
    
    
    /// Request screen recording permission with user prompt
    private static func requestScreenRecordingWithPrompt() {
        if ComprehensivePermissions.hasScreenRecordingPermissions() {
            return
        }
        
        print("📝 Screen recording permission prompt will appear...")
        ComprehensivePermissions.requestScreenRecordingPermissions()
        
        // Brief check after request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if ComprehensivePermissions.hasScreenRecordingPermissions() {
                print("✅ Screen recording permission granted!")
            } else {
                print("⚠️  Screen recording permission may need manual setup in System Settings.")
            }
        }
    }
    
    /// Show simple permission dialog (better UX - just opens System Settings)
    @MainActor
    private static func showSimplePermissionDialog(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        missingPermissions: [ComprehensivePermissions.PermissionType]
    ) {
        let alert = NSAlert()
        alert.messageText = "MacMCP Needs Additional Permissions"
        
        let permissionList = missingPermissions.map { "• \($0.rawValue)" }.joined(separator: "\n")
        
        alert.informativeText = """
        MacMCP requires these permissions to function and cannot operate without them:
        
        \(permissionList)
        
        These permissions must be granted to \(hostInfo.displayName) in System Settings.
        
        Click "Open System Settings" to grant these permissions now.
        """
        
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        if let icon = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings") {
            alert.icon = icon
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // Open to the first missing permission's settings
            if let firstPermission = missingPermissions.first {
                HostProcessDetectionService.openSystemSettings(for: firstPermission)
            }
        } else {
            // User chose to quit - exit the application
            exit(1)
        }
    }
    
    /// Show permission dialogs in sequence, one at a time (legacy - now using simple dialog)
    @MainActor
    private static func showPermissionDialogSequence(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        missingPermissions: [ComprehensivePermissions.PermissionType],
        currentIndex: Int,
        configuration: Configuration
    ) {
        // If we've shown all permissions, we're done
        guard currentIndex < missingPermissions.count else { return }
        
        let permission = missingPermissions[currentIndex]
        
        let alert = NSAlert()
        alert.messageText = "\(permission.rawValue) Permission Required"
        
        let remaining = missingPermissions.count - currentIndex
        let progressText = remaining > 1 ? " (\(remaining) permissions remaining)" : ""
        
        alert.informativeText = """
        MacMCP needs \(permission.rawValue) permission to function properly\(progressText).
        
        \(permission.description)
        
        This permission will be granted to: \(hostInfo.displayName)
        
        Would you like to grant this permission now?
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Permission")
        alert.addButton(withTitle: "Skip for Now")
        alert.addButton(withTitle: "More Info")
        
        // Set icon based on permission type
        if let icon = getPermissionIcon(for: permission) {
            alert.icon = icon
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Grant Permission
            grantIndividualPermission(permission: permission, hostInfo: hostInfo) {
                // After granting, continue to next permission
                showPermissionDialogSequence(
                    hostInfo: hostInfo,
                    missingPermissions: missingPermissions,
                    currentIndex: currentIndex + 1,
                    configuration: configuration
                )
            }
            
        case .alertSecondButtonReturn: // Skip for Now
            // User declined, continue to next permission
            showPermissionDialogSequence(
                hostInfo: hostInfo,
                missingPermissions: missingPermissions,
                currentIndex: currentIndex + 1,
                configuration: configuration
            )
            
        case .alertThirdButtonReturn: // More Info
            showIndividualPermissionInfo(hostInfo: hostInfo, permission: permission) {
                // After showing info, return to the same permission dialog
                showPermissionDialogSequence(
                    hostInfo: hostInfo,
                    missingPermissions: missingPermissions,
                    currentIndex: currentIndex,
                    configuration: configuration
                )
            }
            
        default:
            // User cancelled, continue to next permission
            showPermissionDialogSequence(
                hostInfo: hostInfo,
                missingPermissions: missingPermissions,
                currentIndex: currentIndex + 1,
                configuration: configuration
            )
        }
    }
    
    /// Show individual permission dialog for a specific permission
    @MainActor
    private static func showIndividualPermissionDialog(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        permission: ComprehensivePermissions.PermissionType,
        configuration: Configuration
    ) {
        let alert = NSAlert()
        alert.messageText = "\(permission.rawValue) Permission Required"
        
        alert.informativeText = """
        MacMCP needs \(permission.rawValue) permission to function properly.
        
        \(permission.description)
        
        This permission will be granted to: \(hostInfo.displayName)
        
        Would you like to grant this permission now?
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Permission")
        alert.addButton(withTitle: "Skip for Now")
        alert.addButton(withTitle: "More Info")
        
        // Set icon based on permission type
        if let icon = getPermissionIcon(for: permission) {
            alert.icon = icon
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Grant Permission
            grantIndividualPermission(permission: permission, hostInfo: hostInfo)
            
        case .alertSecondButtonReturn: // Skip for Now
            // User declined, continue without this permission
            break
            
        case .alertThirdButtonReturn: // More Info
            showIndividualPermissionInfo(hostInfo: hostInfo, permission: permission)
            
        default:
            break
        }
    }
    
    /// Get appropriate icon for permission type
    @MainActor
    private static func getPermissionIcon(for permission: ComprehensivePermissions.PermissionType) -> NSImage? {
        switch permission {
        case .accessibility:
            return NSImage(systemSymbolName: "accessibility", accessibilityDescription: "Accessibility")
        case .screenRecording:
            return NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Screen Recording")
        }
    }
    
    /// Grant individual permission with auto-population
    @MainActor
    private static func grantIndividualPermission(
        permission: ComprehensivePermissions.PermissionType,
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        completion: @escaping () -> Void = {}
    ) {
        // First, trigger the permission request to auto-populate the app in System Settings
        switch permission {
        case .accessibility:
            ComprehensivePermissions.requestAccessibilityPermissions()
            
        case .screenRecording:
            ComprehensivePermissions.requestScreenRecordingPermissions()
        }
        
        // Small delay to let the system register the request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Then open System Settings to the specific permission pane
            HostProcessDetectionService.openSystemSettings(for: permission)
            
            // Show follow-up guidance
            showIndividualPermissionFollowUp(hostInfo: hostInfo, permission: permission) {
                completion()
            }
        }
    }
    
    /// Show follow-up dialog for individual permission
    @MainActor
    private static func showIndividualPermissionFollowUp(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        permission: ComprehensivePermissions.PermissionType,
        completion: @escaping () -> Void = {}
    ) {
        let alert = NSAlert()
        alert.messageText = "\(permission.rawValue) Settings Opened"
        alert.informativeText = """
        System Settings has been opened to the \(permission.rawValue) section.
        
        Steps to complete:
        1. Look for "\(hostInfo.displayName)" in the list
        2. Check the box next to it to enable \(permission.rawValue)
        3. The app should now appear in the list since we requested permission
        
        If you don't see the app, click the (+) button to add it manually.
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Done")
        alert.runModal()
        completion()
    }
    
    /// Show detailed information for individual permission
    @MainActor
    private static func showIndividualPermissionInfo(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        permission: ComprehensivePermissions.PermissionType,
        completion: @escaping () -> Void = {}
    ) {
        let alert = NSAlert()
        alert.messageText = "\(permission.rawValue) Permission Details"
        
        var details = """
        \(permission.description)
        
        Location: System Settings > \(permission.systemSettingsPath)
        Host Application: \(hostInfo.displayName)
        
        """
        
        switch permission {
        case .accessibility:
            details += """
            Why MacMCP needs this:
            • Read UI element information
            • Click buttons and interact with controls
            • Navigate application interfaces
            • Automate user workflows
            """
            
        case .screenRecording:
            details += """
            Why MacMCP needs this:
            • Capture screenshots for analysis
            • Take pictures of UI elements
            • Document application states
            • Visual verification of actions
            """
        }
        
        alert.informativeText = details
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Grant Permission")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            grantIndividualPermission(permission: permission, hostInfo: hostInfo) {
                completion()
            }
        } else {
            completion()
        }
    }
    
    /// Show native macOS permission dialog (legacy - now using individual dialogs)
    @MainActor
    private static func showPermissionDialog(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        missingPermissions: [ComprehensivePermissions.PermissionType],
        configuration: Configuration
    ) {
        let alert = NSAlert()
        alert.messageText = "MacMCP Permissions Required"
        
        // Build permission list for display
        let permissionList = missingPermissions.map { "• \($0.rawValue)" }.joined(separator: "\n")
        
        alert.informativeText = """
        MacMCP needs the following permissions to function properly:
        
        \(permissionList)
        
        These permissions will be granted to: \(hostInfo.displayName)
        
        Would you like to open System Settings to grant these permissions now?
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "More Info")
        
        // Set icon to system privacy icon if available
        if let privacyIcon = NSImage(named: "NSUserGroup") {
            alert.icon = privacyIcon
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn: // Open System Settings
            openSystemSettingsForMissingPermissions(missingPermissions)
            
            // Show follow-up dialog
            showPermissionFollowUpDialog(hostInfo: hostInfo)
            
        case .alertSecondButtonReturn: // Not Now
            // User declined, continue without permissions
            break
            
        case .alertThirdButtonReturn: // More Info
            showDetailedPermissionInfo(hostInfo: hostInfo, missingPermissions: missingPermissions)
            
        default:
            break
        }
    }
    
    /// Show follow-up dialog after opening System Settings
    @MainActor
    private static func showPermissionFollowUpDialog(hostInfo: HostProcessDetectionService.HostProcessInfo) {
        let alert = NSAlert()
        alert.messageText = "System Settings Opened"
        alert.informativeText = """
        System Settings has been opened to the Privacy & Security section.
        
        Please:
        1. Find the relevant permission sections (Accessibility, Screen Recording)
        2. Add "\(hostInfo.displayName)" to each section
        3. Restart MacMCP after granting permissions
        
        The permissions may be granted to the application that's running MacMCP.
        """
        
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Show detailed permission information dialog
    @MainActor
    private static func showDetailedPermissionInfo(
        hostInfo: HostProcessDetectionService.HostProcessInfo,
        missingPermissions: [ComprehensivePermissions.PermissionType]
    ) {
        let alert = NSAlert()
        alert.messageText = "Permission Details"
        
        var details = "MacMCP requires these permissions:\n\n"
        
        for permission in missingPermissions {
            details += "• \(permission.rawValue)\n"
            details += "  \(permission.description)\n"
            details += "  Location: System Settings > \(permission.systemSettingsPath)\n\n"
        }
        
        details += """
        Host Application: \(hostInfo.displayName)
        
        The permissions are granted to the application that launches MacMCP. This could be:
        • Terminal or other command-line applications
        • Claude.app or other AI assistants
        • Any other application using MacMCP
        """
        
        alert.informativeText = details
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettingsForMissingPermissions(missingPermissions)
            showPermissionFollowUpDialog(hostInfo: hostInfo)
        }
    }
    
    /// Open System Settings for all missing permissions
    private static func openSystemSettingsForMissingPermissions(_ permissions: [ComprehensivePermissions.PermissionType]) {
        // Open the first missing permission's settings pane
        // User can navigate to others from there
        if let firstPermission = permissions.first {
            HostProcessDetectionService.openSystemSettings(for: firstPermission)
        }
    }
    
    /// Generate a detailed permission status report
    public static func generateDetailedStatusReport() -> String {
        let hostInfo = HostProcessDetectionService.detectHostProcess()
        let allPermissions = ComprehensivePermissions.checkAllPermissions()
        let missingPermissions = ComprehensivePermissions.getMissingPermissions()
        
        var report = """
        MacMCP Permission Status Report
        ===============================
        
        Host Application: \(hostInfo.displayName)
        """
        
        if let bundleId = hostInfo.bundleId {
            report += "\nBundle ID: \(bundleId)"
        }
        
        report += "\nProcess ID: \(hostInfo.processId)\n\n"
        
        report += "Permission Status:\n"
        for (permission, granted) in allPermissions {
            let icon = granted ? "✅" : "❌"
            let status = granted ? "GRANTED" : "MISSING"
            report += "\(icon) \(permission.rawValue): \(status)\n"
        }
        
        if missingPermissions.isEmpty {
            report += "\n🎉 All required permissions are granted!"
        } else {
            report += "\n⚠️  \(missingPermissions.count) permission(s) missing."
            report += "\n\nTo resolve:"
            report += "\n1. Open System Settings > Privacy & Security"
            report += "\n2. Add '\(hostInfo.displayName)' to the following sections:"
            
            for permission in missingPermissions {
                report += "\n   • \(permission.systemSettingsPath)"
            }
        }
        
        return report
    }
}