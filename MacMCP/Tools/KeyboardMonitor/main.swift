// ABOUTME: main.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import ArgumentParser
import Foundation

/// Maps key codes to their human-readable names
enum KeyCodeMap {
  /// Get the key name for a given key code
  static func name(for keyCode: UInt8) -> String {
    keyNames[Int(keyCode)] ?? "unknown(\(keyCode))"
  }

  /// Map of key codes to their human-readable names
  static let keyNames: [Int: String] = [
    0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
    8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
    16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
    23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
    30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "return",
    37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
    44: "/", 45: "n", 46: "m", 47: ".", 48: "tab", 49: "space", 50: "`",
    51: "delete", 53: "escape", 55: "command", 56: "shift", 58: "option",
    59: "control", 60: "rightshift", 61: "rightoption", 62: "rightcontrol",
    96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9",
    103: "f11", 109: "f10", 111: "f12", 114: "insert", 115: "home",
    116: "pageup", 117: "forwarddelete", 118: "f4", 119: "end",
    120: "f2", 121: "pagedown", 122: "f1", 123: "leftarrow",
    124: "rightarrow", 125: "downarrow", 126: "uparrow",
  ]
}

/// Definition for a keyboard event
struct KeyEvent: CustomStringConvertible {
  let keyCode: Int
  let keyName: String
  let type: EventType
  let timestamp: TimeInterval

  enum EventType: String {
    case down = "Down"
    case up = "Up"
  }

  var description: String {
    String(
      format: "%8.3f | %5d | %-10s | %s",
      timestamp,
      keyCode,
      keyName,
      type.rawValue,
    )
  }
}

@main
struct KeyboardMonitor: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "keymon",
    abstract: "A keyboard event monitor utility",
    discussion: """
      Monitors and displays keyboard events with their key codes, key names, and event types.
      This tool is useful for testing and debugging keyboard interaction tools.
      """,
    version: "1.0.0",
  )

  @Flag(name: .shortAndLong, help: "Write key events to a log file")
  var log = false

  @Option(name: .shortAndLong, help: "Path to save the log file (default: temporary directory)")
  var output: String?

  @Flag(name: .shortAndLong, help: "Show timestamp for each key event")
  var timestamp = false

  @Flag(name: .long, help: "Show only down (press) events, not up (release) events")
  var downOnly = false

  @Flag(name: .shortAndLong, help: "Show full header and details")
  var verbose = false

  mutating func run() throws {
    // Start monitoring timestamp
    let startTime = ProcessInfo.processInfo.systemUptime

    // Create a log file if requested
    var logFile: FileHandle?
    var logPath: URL?

    if log {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
      let dateString = dateFormatter.string(from: Date())

      if let outputPath = output {
        logPath = URL(fileURLWithPath: outputPath)
      } else {
        logPath = FileManager.default.temporaryDirectory.appendingPathComponent(
          "keymon-log-\(dateString).txt")
      }

      FileManager.default.createFile(atPath: logPath!.path, contents: nil, attributes: nil)
      logFile = try? FileHandle(forWritingTo: logPath!)

      if let logFile, let logPath {
        let header = "Keyboard Event Monitor Log - \(Date())\n"
        logFile.write(header.data(using: .utf8)!)
        if timestamp {
          logFile.write("Timestamp | KeyCode | KeyName     | Type\n".data(using: .utf8)!)
          logFile.write("------------------------------------------\n".data(using: .utf8)!)
        } else {
          logFile.write("KeyCode | KeyName     | Type\n".data(using: .utf8)!)
          logFile.write("---------------------------\n".data(using: .utf8)!)
        }

        if verbose {
          print("Logging to: \(logPath.path)")
        }
      }
    }

    // Display start message
    if verbose {
      print("Keyboard Monitor Started")
      print("Press Ctrl+C to exit")

      if timestamp {
        print("Timestamp | KeyCode | KeyName     | Type")
        print("------------------------------------------")
      } else {
        print("KeyCode | KeyName     | Type")
        print("---------------------------")
      }
    }

    // Set up terminal for reading single characters
    let fd = FileHandle.standardInput.fileDescriptor
    var term = termios()
    tcgetattr(fd, &term)
    var newTerm = term
    newTerm.c_lflag &= ~UInt(ICANON | ECHO)
    tcsetattr(fd, TCSANOW, &newTerm)

    // Register cleanup on exit
    defer {
      tcsetattr(fd, TCSANOW, &term)
      logFile?.closeFile()
      if verbose {
        print("\nKeyboard Monitor Stopped")
      }
    }

    // Main input loop
    while true {
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
      defer { buffer.deallocate() }

      let amountRead = read(fd, buffer, 1)

      if amountRead > 0 {
        let keyCode = buffer[0]
        let keyName = KeyCodeMap.name(for: keyCode)
        let currentTime = ProcessInfo.processInfo.systemUptime - startTime

        // Create the key event
        let event = KeyEvent(
          keyCode: Int(keyCode),
          keyName: keyName,
          type: .down,
          timestamp: currentTime,
        )

        // Format the log entry
        var logEntryText = ""
        if timestamp {
          logEntryText = event.description
        } else {
          logEntryText = String(
            format: "%5d | %-10s | %s",
            event.keyCode,
            event.keyName,
            event.type.rawValue,
          )
        }

        // Log the key down event
        print(logEntryText)

        // Write to log file
        if let logFile {
          logFile.write("\(logEntryText)\n".data(using: .utf8)!)
        }

        // Log the key up event (if not downOnly)
        if !downOnly {
          // Small delay for key up event
          usleep(50000)  // 50ms delay

          let upEvent = KeyEvent(
            keyCode: Int(keyCode),
            keyName: keyName,
            type: .up,
            timestamp: ProcessInfo.processInfo.systemUptime - startTime,
          )

          // Format the log entry for key up
          var upLogEntryText = ""
          if timestamp {
            upLogEntryText = upEvent.description
          } else {
            upLogEntryText = String(
              format: "%5d | %-10s | %s",
              upEvent.keyCode,
              upEvent.keyName,
              upEvent.type.rawValue,
            )
          }

          print(upLogEntryText)

          // Write to log file
          if let logFile {
            logFile.write("\(upLogEntryText)\n".data(using: .utf8)!)
          }
        }

        // Exit on Ctrl+C (keyCode 3)
        if keyCode == 3 {
          return
        }
      }

      // Short delay to prevent CPU spinning
      usleep(1000)
    }
  }
}
