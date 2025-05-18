// ABOUTME: main.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import ArgumentParser
import Foundation

@main
struct CLIKeyboardMonitor: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cli-keymon",
    abstract: "A simple CLI keyboard event monitor",
    discussion: """
      This utility displays key codes for keyboard input, useful for testing 
      and debugging keyboard-related functionality.
      """,
  )

  @Flag(name: .shortAndLong, help: "Write key events to a log file")
  var log = false

  func run() throws {
    // Set up key code to name mapping
    let keyNames: [UInt8: String] = [
      0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x",
      8: "c", 9: "v", 11: "b", 12: "q", 13: "w", 14: "e", 15: "r",
      16: "y", 17: "t", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
      23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
      30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p", 36: "return",
      37: "l", 38: "j", 39: "'", 40: "k", 41: ";", 42: "\\", 43: ",",
      44: "/", 45: "n", 46: "m", 47: ".", 48: "tab", 49: "space", 50: "`",
      51: "delete", 53: "escape", 55: "command", 56: "shift", 58: "option",
      59: "control", 123: "left", 124: "right", 125: "down", 126: "up",
    ]

    // Create a log file if requested
    var logFile: FileHandle?
    var logPath: URL?

    if log {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
      let dateString = dateFormatter.string(from: Date())
      logPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("cli-keyboard-monitor-\(dateString).log")

      FileManager.default.createFile(atPath: logPath!.path, contents: nil, attributes: nil)
      logFile = try? FileHandle(forWritingTo: logPath!)

      if let logFile, let logPath {
        let header = "CLI Keyboard Monitor Log - \(Date())\n"
        logFile.write(header.data(using: .utf8)!)
        logFile.write("KeyCode | KeyName\n".data(using: .utf8)!)
        logFile.write("----------------\n".data(using: .utf8)!)

        print("Logging to: \(logPath.path)")
      }
    }

    // Display start message
    print("CLI Keyboard Monitor Started")
    print("Press keys to see their key codes (Ctrl+C to exit)")
    print("KeyCode | KeyName")
    print("----------------")

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
      print("\nCLI Keyboard Monitor Stopped")
    }

    // Main input loop
    while true {
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
      defer { buffer.deallocate() }

      let amountRead = read(fd, buffer, 1)

      if amountRead > 0 {
        let keyCode = buffer[0]
        let keyName = keyNames[keyCode] ?? "unknown"

        // Log the key event
        let logEntry = String(format: "  %-3d   | %s", keyCode, keyName)
        print(logEntry)

        // Write to log file
        if let logFile {
          logFile.write("\(logEntry)\n".data(using: .utf8)!)
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
