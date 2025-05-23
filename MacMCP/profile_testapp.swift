#!/usr/bin/swift

import Foundation
import AppKit

// Get the bundle ID of the calculator
let bundleId = "com.apple.calculator"

// Get the time at the beginning
let startTime = Date()

// Check if app is already running
let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
print("Initial check for running apps: \(runningApps.count) instances found in \(Date().timeIntervalSince(startTime) * 1000) ms")

// Terminate existing instances
if !runningApps.isEmpty {
    print("Terminating \(runningApps.count) existing instances...")
    for app in runningApps {
        app.terminate()
    }
    // Wait for termination
    Thread.sleep(forTimeInterval: 1.0)
    print("Termination wait complete at \(Date().timeIntervalSince(startTime) * 1000) ms")
}

// Launch Calculator
print("Launching calculator...")
let launchTime = Date()
let workspace = NSWorkspace.shared
var appLaunched: NSRunningApplication? = nil

do {
    appLaunched = try workspace.launchApplication(
        at: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
        options: [],
        configuration: [:]
    )
    print("Application launched in \(Date().timeIntervalSince(launchTime) * 1000) ms")
    print("Total time elapsed: \(Date().timeIntervalSince(startTime) * 1000) ms")
} catch {
    print("Error launching application: \(error)")
}

// Wait for app to initialize
Thread.sleep(forTimeInterval: 2.0)
print("Wait complete at \(Date().timeIntervalSince(startTime) * 1000) ms")

// Try to activate the application
if let app = appLaunched {
    let activateTime = Date()
    let activated = app.activate(options: [])
    print("Activation \(activated ? "succeeded" : "failed") in \(Date().timeIntervalSince(activateTime) * 1000) ms")
} else {
    print("No app to activate")
}

print("Total time: \(Date().timeIntervalSince(startTime) * 1000) ms")

// Finally terminate the app
print("Terminating app...")
appLaunched?.terminate()
