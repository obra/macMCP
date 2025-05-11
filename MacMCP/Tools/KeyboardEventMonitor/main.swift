// ABOUTME: This is a simple utility to monitor keyboard events for testing the KeyboardInteractionTool.
// ABOUTME: It displays all keyboard events in real-time, showing key codes, characters, and modifiers.

import Foundation
import AppKit
import Cocoa  // Make sure we have all required AppKit imports

/// Structure to represent a captured keyboard event for display
struct KeyEvent {
    let keyCode: Int
    let character: String
    let isKeyDown: Bool
    let modifierFlags: NSEvent.ModifierFlags
    let timestamp: Double
    
    var formattedModifiers: String {
        var mods: [String] = []
        
        if modifierFlags.contains(.command) {
            mods.append("Command")
        }
        if modifierFlags.contains(.shift) {
            mods.append("Shift")
        }
        if modifierFlags.contains(.option) {
            mods.append("Option")
        }
        if modifierFlags.contains(.control) {
            mods.append("Control")
        }
        
        return mods.isEmpty ? "None" : mods.joined(separator: "+")
    }
    
    var description: String {
        let type = isKeyDown ? "Down" : "Up"
        return String(format: "%8.3f | %5d | %-10s | %-8s | %-20s |",
                      timestamp,
                      keyCode,
                      character.isEmpty ? "-" : character,
                      type,
                      formattedModifiers)
    }
}

class KeyboardMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var events: [KeyEvent] = []
    private var startTime: TimeInterval = 0
    private var logFile: FileHandle?
    private var useGlobalMonitoring = false
    
    /// Check if we have permission to monitor events
    private func checkPermissions() -> Bool {
        // We'll avoid using kAXTrustedCheckOptionPrompt directly due to concurrency issues
        // Instead, just check the current status without prompting
        return AXIsProcessTrusted()
    }
    
    /// Start monitoring keyboard events
    func start() {
        print("Keyboard Event Monitor Started")
        print(String(format: "%8s | %5s | %-10s | %-8s | %-20s |", "Time", "Code", "Char", "Type", "Modifiers"))
        print(String(repeating: "-", count: 65))
        
        startTime = ProcessInfo.processInfo.systemUptime
        
        // Try to create log file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let logPath = FileManager.default.temporaryDirectory.appendingPathComponent("keyboard-monitor-\(dateString).log")
        
        FileManager.default.createFile(atPath: logPath.path, contents: nil, attributes: nil)
        logFile = try? FileHandle(forWritingTo: logPath)
        
        if let logFile = logFile {
            let header = "Keyboard Event Monitor Log - \(Date())\n"
            logFile.write(header.data(using: .utf8)!)
            logFile.write(String(format: "%8s | %5s | %-10s | %-8s | %-20s |\n", "Time", "Code", "Char", "Type", "Modifiers").data(using: .utf8)!)
            logFile.write(String(repeating: "-", count: 65).data(using: .utf8)!)
            logFile.write("\n".data(using: .utf8)!)
            
            print("Logging to: \(logPath.path)")
        }
        
        // Monitor keyboard events from this application (always available)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            self.logEvent(event)
            return event
        }
        
        // Check accessibility permissions for global monitoring
        useGlobalMonitoring = checkPermissions()
        
        if useGlobalMonitoring {
            print("Global monitoring enabled - monitoring all keyboard events")
            // Monitor keyboard events from any application
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
                self.logEvent(event)
            }
        } else {
            print("⚠️ Global monitoring disabled - only monitoring this application")
            print("To enable global monitoring, grant accessibility permissions in")
            print("System Settings > Privacy & Security > Accessibility")
        }
    }
    
    /// Stop monitoring keyboard events
    func stop() {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        
        logFile?.closeFile()
        print("\nKeyboard Event Monitor Stopped")
    }
    
    /// Log a keyboard event
    private func logEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let character = event.characters ?? ""
        let isKeyDown = event.type == .keyDown
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let timestamp = ProcessInfo.processInfo.systemUptime - startTime
        
        let keyEvent = KeyEvent(
            keyCode: Int(keyCode),
            character: character,
            isKeyDown: isKeyDown,
            modifierFlags: modifiers,
            timestamp: timestamp
        )
        
        events.append(keyEvent)
        print(keyEvent.description)
        
        // Write to log file
        if let logFile = logFile {
            logFile.write("\(keyEvent.description)\n".data(using: .utf8)!)
        }
    }
    
    /// Save the recorded events to a file
    func saveEvents(to path: URL) {
        var output = "Keyboard Events Log\n"
        output += String(format: "%8s | %5s | %-10s | %-8s | %-20s |\n", "Time", "Code", "Char", "Type", "Modifiers")
        output += String(repeating: "-", count: 65)
        output += "\n"
        
        for event in events {
            output += "\(event.description)\n"
        }
        
        do {
            try output.write(to: path, atomically: true, encoding: .utf8)
            print("Events saved to: \(path.path)")
        } catch {
            print("Error saving events: \(error.localizedDescription)")
        }
    }
}

// Create a proper NSApplication to keep the app running
class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = KeyboardMonitor()
    
    @MainActor func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()

        print("Press Command+Q to exit the keyboard monitor")

        // Create a menu with Quit item
        setupMenu()
    }

    @MainActor func setupMenu() {
        let mainMenu = NSMenu(title: "MainMenu")

        let appMenuItem = NSMenuItem(title: "Application", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "Application")
        appMenuItem.submenu = appMenu

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitMenuItem)

        mainMenu.addItem(appMenuItem)
        NSApplication.shared.mainMenu = mainMenu
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }
}

// Main program
@MainActor func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    // Explicitly handle the run loop
    NSApp.run()
}

// Run the main function on the main actor
Task { @MainActor in
    main()
}