#!/usr/bin/env swift

// ABOUTME: check_permissions.swift  
// ABOUTME: Script to check all macOS permissions required for window management

import Foundation
import AppKit
import AVFoundation

// Copy the permission checking logic
func hasAccessibilityPermissions() -> Bool {
    return AXIsProcessTrusted()
}

func hasAutomationPermissions() -> Bool {
    let script = """
    tell application "System Events"
        get name of first process
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let result = scriptObject.executeAndReturnError(&error)
        return error == nil && result.stringValue != nil
    }
    
    return false
}

func hasScreenRecordingPermissions() -> Bool {
    if #available(macOS 10.15, *) {
        let hasPermission = CGPreflightScreenCaptureAccess()
        return hasPermission
    }
    return true
}

print("🔍 MacMCP Permission Checker")
print("===========================\n")

// Check each permission
let accessibility = hasAccessibilityPermissions()
let automation = hasAutomationPermissions()
let screenRecording = hasScreenRecordingPermissions()

print("Permission Status:")
print("✅ Accessibility: \(accessibility ? "GRANTED" : "❌ MISSING")")
print("🤖 Automation: \(automation ? "GRANTED" : "❌ MISSING")")
print("📹 Screen Recording: \(screenRecording ? "GRANTED" : "❌ MISSING")")

print("\nDetailed Analysis:")
print("- Accessibility: Required for basic UI element access")
print("- Automation: Required for controlling other applications' windows")
print("- Screen Recording: May be required for advanced accessibility operations")

let missingCount = [accessibility, automation, screenRecording].filter { !$0 }.count

if missingCount == 0 {
    print("\n🎉 All permissions granted! Window management should work.")
} else {
    print("\n⚠️  Missing \(missingCount) permission(s). This likely explains the window management failures.")
    print("\nTo fix:")
    if !accessibility {
        print("1. Go to System Settings > Privacy & Security > Accessibility")
        print("   Add this terminal or the MacMCP executable")
    }
    if !automation {
        print("2. Go to System Settings > Privacy & Security > Automation") 
        print("   Allow this app to control 'System Events' and other applications")
    }
    if !screenRecording {
        print("3. Go to System Settings > Privacy & Security > Screen Recording")
        print("   Add this terminal or the MacMCP executable")
    }
}

print("\n💡 The AXError -25201 (kAXErrorCannotComplete) we're seeing")
print("   is typically caused by missing Automation permissions.")