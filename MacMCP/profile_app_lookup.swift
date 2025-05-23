#\!/usr/bin/env swift

import Foundation
import ApplicationServices
import AppKit

// This script simulates the behavior in AccessibilityLookupTests but without importing MacMCP

let calcBundleId = "com.apple.calculator"
let calcTitle = "Calculator"

// First, launch Calculator if not running
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: calcBundleId)
var app: NSRunningApplication? = nil

if runningApps.isEmpty {
    print("Launching calculator...")
    do {
        app = try NSWorkspace.shared.launchApplication(
            at: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            options: [],
            configuration: [:]
        )
        print("Calculator launched")
        Thread.sleep(forTimeInterval: 0.5)
    } catch {
        print("Error launching calculator: \(error)")
        exit(1)
    }
} else {
    print("Calculator is already running")
    app = runningApps.first
}

// Now try to find it using accessibility APIs
print("Trying to get AXUIElement for Calculator")
let startTime = Date()

// Try to get the application by bundle ID
let systemWideElement = AXUIElementCreateSystemWide()
print("Created system-wide element in \(Date().timeIntervalSince(startTime) * 1000) ms")

// Get all applications
var applicationArray: CFArray?
let appArrayStatus = AXUIElementCopyAttributeValue(
    systemWideElement,
    kAXApplicationsAttribute as CFString,
    &applicationArray
)

print("Got application array with status \(appArrayStatus) in \(Date().timeIntervalSince(startTime) * 1000) ms")

if appArrayStatus == .success, let applications = applicationArray as? [AXUIElement] {
    print("Found \(applications.count) applications")
    
    // Find the Calculator application
    var found = false
    var foundTime: TimeInterval = 0
    
    for appElement in applications {
        // Get the PID for this application
        var pid: pid_t = 0
        let pidStatus = AXUIElementGetPid(appElement, &pid)
        
        if pidStatus == .success {
            // Get the running application for this PID
            if let runningApp = NSRunningApplication(processIdentifier: pid) {
                // Check if this is the Calculator
                if runningApp.bundleIdentifier == calcBundleId {
                    let time = Date().timeIntervalSince(startTime)
                    print("Found Calculator with PID \(pid) in \(time * 1000) ms")
                    found = true
                    foundTime = time
                    
                    // Get role to verify it's an application
                    var roleRef: CFTypeRef?
                    let roleStatus = AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &roleRef)
                    if roleStatus == .success, let role = roleRef as? String {
                        print("Role: \(role) (status: \(roleStatus))")
                    } else {
                        print("Failed to get role: \(roleStatus)")
                    }
                    
                    break
                }
            }
        }
    }
    
    if \!found {
        print("Did not find Calculator in the application list")
    }
} else {
    print("Failed to get applications list")
}

let totalTime = Date().timeIntervalSince(startTime)
print("Total search time: \(totalTime * 1000) ms")

// Terminate calculator
print("Terminating calculator...")
app?.terminate()
