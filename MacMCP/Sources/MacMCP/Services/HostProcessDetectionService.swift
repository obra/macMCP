// ABOUTME: HostProcessDetectionService.swift
// ABOUTME: Detects which application is hosting the MCP server and provides context-specific permission guidance

import AppKit
import Foundation

/// Service for detecting the host process running the MCP server
public class HostProcessDetectionService {
  /// Information about the detected host process
  public struct HostProcessInfo {
    public let bundleId: String?
    public let name: String
    public let processId: pid_t
    public let executablePath: String?
    /// The display name for user-facing messages
    public var displayName: String { return name }
  }
  /// Detect the current host process
  public static func detectHostProcess() -> HostProcessInfo {
    let processId = getppid()  // Parent process ID

    // Walk up the process tree to find the actual desktop app host
    if let hostApp = findDesktopHostApp(fromPid: processId) {
      return HostProcessInfo(
        bundleId: hostApp.bundleIdentifier,
        name: hostApp.localizedName ?? hostApp.bundleIdentifier ?? "Unknown Application",
        processId: hostApp.processIdentifier,
        executablePath: hostApp.bundleURL?.path
      )
    }
    // Fallback: use immediate parent if we can't find a desktop app
    if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
      $0.processIdentifier == processId
    }) {
      return HostProcessInfo(
        bundleId: runningApp.bundleIdentifier,
        name: runningApp.localizedName ?? runningApp.bundleIdentifier ?? "Unknown Application",
        processId: processId,
        executablePath: runningApp.bundleURL?.path
      )
    }
    // Final fallback: use process name
    let processName = getProcessName(processId: processId) ?? "Unknown Process"
    return HostProcessInfo(
      bundleId: nil, name: processName, processId: processId, executablePath: nil)
  }
  /// Walk up the process tree to find a desktop app host
  private static func findDesktopHostApp(fromPid: pid_t) -> NSRunningApplication? {
    var currentPid = fromPid
    var lastValidApp: NSRunningApplication?
    while currentPid > 1 {  // Stop before init (PID 1)
      if let app = NSWorkspace.shared.runningApplications.first(where: {
        $0.processIdentifier == currentPid
      }) {
        // If this is a regular app (not background/accessory), it's a candidate
        if app.activationPolicy == .regular {
          lastValidApp = app
          // If it has a bundle ID, it's likely the host we want
          if app.bundleIdentifier != nil { return app }
        }
      }
      // Get parent of current process
      let task = Process()
      task.launchPath = "/bin/ps"
      task.arguments = ["-p", "\(currentPid)", "-o", "ppid="]
      let pipe = Pipe()
      task.standardOutput = pipe
      do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines),
          let parentPid = pid_t(output), parentPid != currentPid
        {
          currentPid = parentPid
        } else {
          break
        }
      } catch { break }
    }
    // Return the last valid regular app we found
    return lastValidApp
  }
  /// Get process name by process ID using system calls
  private static func getProcessName(processId: pid_t) -> String? {
    let task = Process()
    task.launchPath = "/bin/ps"
    task.arguments = ["-p", "\(processId)", "-o", "comm="]
    let pipe = Pipe()
    task.standardOutput = pipe
    do {
      try task.run()
      task.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines),
        !output.isEmpty
      {
        return output
      }
    } catch {
      // Ignore errors, will return nil
    }
    return nil
  }
  /// Get comprehensive guidance for opening System Settings for the detected host
  public static func getSystemSettingsGuidance(for hostInfo: HostProcessInfo) -> String {
    let missingPermissions = ComprehensivePermissions.getMissingPermissions()
    if missingPermissions.isEmpty { return "✅ All permissions are already granted!" }
    var guidance = """
      🔐 Permission Setup Required

      MacMCP needs additional permissions to function properly.
      The permissions need to be granted to: \(hostInfo.displayName)

      📋 Steps to grant permissions:

      1. Open System Settings (or System Preferences on older macOS)
      2. Navigate to Privacy & Security
      3. Find and configure these sections:

      """
    for permission in missingPermissions {
      guidance += """
           • \(permission.systemSettingsPath)
             → Click the (+) button and add "\(hostInfo.displayName)"
             → \(permission.description)

        """
    }
    guidance += """

      🔍 If you don't see "\(hostInfo.displayName)" in the permission dialog:
      • Click the (+) button to browse for it
      • Look for the application that's running the MCP server

      ⚠️  Important: After granting permissions, you may need to restart the MCP server for changes to take effect.
      """
    return guidance
  }
  /// Open System Settings to the appropriate privacy pane
  public static func openSystemSettings(for permission: ComprehensivePermissions.PermissionType) {
    let settingsURL: String
    switch permission {
    case .accessibility:
      settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    case .screenRecording:
      settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    }
    if let url = URL(string: settingsURL) { NSWorkspace.shared.open(url) }
  }
}
