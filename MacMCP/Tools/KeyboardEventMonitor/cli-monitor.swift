// ABOUTME: Simple CLI keyboard event monitor for testing keyboard tools.
// ABOUTME: This version runs in the terminal and doesn't require a GUI or accessibility permissions.

import Foundation
import Dispatch

struct KeyInfo {
    let keyCode: Int
    let keyName: String
    let isPrintable: Bool
}

let keyMap: [Int: KeyInfo] = [
    0: KeyInfo(keyCode: 0, keyName: "a", isPrintable: true),
    1: KeyInfo(keyCode: 1, keyName: "s", isPrintable: true),
    2: KeyInfo(keyCode: 2, keyName: "d", isPrintable: true),
    3: KeyInfo(keyCode: 3, keyName: "f", isPrintable: true),
    4: KeyInfo(keyCode: 4, keyName: "h", isPrintable: true),
    5: KeyInfo(keyCode: 5, keyName: "g", isPrintable: true),
    6: KeyInfo(keyCode: 6, keyName: "z", isPrintable: true),
    7: KeyInfo(keyCode: 7, keyName: "x", isPrintable: true),
    8: KeyInfo(keyCode: 8, keyName: "c", isPrintable: true),
    9: KeyInfo(keyCode: 9, keyName: "v", isPrintable: true),
    11: KeyInfo(keyCode: 11, keyName: "b", isPrintable: true),
    12: KeyInfo(keyCode: 12, keyName: "q", isPrintable: true),
    13: KeyInfo(keyCode: 13, keyName: "w", isPrintable: true),
    14: KeyInfo(keyCode: 14, keyName: "e", isPrintable: true),
    15: KeyInfo(keyCode: 15, keyName: "r", isPrintable: true),
    16: KeyInfo(keyCode: 16, keyName: "y", isPrintable: true),
    17: KeyInfo(keyCode: 17, keyName: "t", isPrintable: true),
    18: KeyInfo(keyCode: 18, keyName: "1", isPrintable: true),
    19: KeyInfo(keyCode: 19, keyName: "2", isPrintable: true),
    20: KeyInfo(keyCode: 20, keyName: "3", isPrintable: true),
    21: KeyInfo(keyCode: 21, keyName: "4", isPrintable: true),
    22: KeyInfo(keyCode: 22, keyName: "6", isPrintable: true),
    23: KeyInfo(keyCode: 23, keyName: "5", isPrintable: true),
    24: KeyInfo(keyCode: 24, keyName: "=", isPrintable: true),
    25: KeyInfo(keyCode: 25, keyName: "9", isPrintable: true),
    26: KeyInfo(keyCode: 26, keyName: "7", isPrintable: true),
    27: KeyInfo(keyCode: 27, keyName: "-", isPrintable: true),
    28: KeyInfo(keyCode: 28, keyName: "8", isPrintable: true),
    29: KeyInfo(keyCode: 29, keyName: "0", isPrintable: true),
    30: KeyInfo(keyCode: 30, keyName: "]", isPrintable: true),
    31: KeyInfo(keyCode: 31, keyName: "o", isPrintable: true),
    32: KeyInfo(keyCode: 32, keyName: "u", isPrintable: true),
    33: KeyInfo(keyCode: 33, keyName: "[", isPrintable: true),
    34: KeyInfo(keyCode: 34, keyName: "i", isPrintable: true),
    35: KeyInfo(keyCode: 35, keyName: "p", isPrintable: true),
    36: KeyInfo(keyCode: 36, keyName: "return", isPrintable: false),
    37: KeyInfo(keyCode: 37, keyName: "l", isPrintable: true),
    38: KeyInfo(keyCode: 38, keyName: "j", isPrintable: true),
    39: KeyInfo(keyCode: 39, keyName: "'", isPrintable: true),
    40: KeyInfo(keyCode: 40, keyName: "k", isPrintable: true),
    41: KeyInfo(keyCode: 41, keyName: ";", isPrintable: true),
    42: KeyInfo(keyCode: 42, keyName: "\\", isPrintable: true),
    43: KeyInfo(keyCode: 43, keyName: ",", isPrintable: true),
    44: KeyInfo(keyCode: 44, keyName: "/", isPrintable: true),
    45: KeyInfo(keyCode: 45, keyName: "n", isPrintable: true),
    46: KeyInfo(keyCode: 46, keyName: "m", isPrintable: true),
    47: KeyInfo(keyCode: 47, keyName: ".", isPrintable: true),
    48: KeyInfo(keyCode: 48, keyName: "tab", isPrintable: false),
    49: KeyInfo(keyCode: 49, keyName: "space", isPrintable: false),
    50: KeyInfo(keyCode: 50, keyName: "`", isPrintable: true),
    51: KeyInfo(keyCode: 51, keyName: "delete", isPrintable: false),
    53: KeyInfo(keyCode: 53, keyName: "escape", isPrintable: false),
    55: KeyInfo(keyCode: 55, keyName: "command", isPrintable: false),
    56: KeyInfo(keyCode: 56, keyName: "shift", isPrintable: false),
    57: KeyInfo(keyCode: 57, keyName: "capslock", isPrintable: false),
    58: KeyInfo(keyCode: 58, keyName: "option", isPrintable: false),
    59: KeyInfo(keyCode: 59, keyName: "control", isPrintable: false),
    60: KeyInfo(keyCode: 60, keyName: "rightshift", isPrintable: false),
    61: KeyInfo(keyCode: 61, keyName: "rightoption", isPrintable: false),
    62: KeyInfo(keyCode: 62, keyName: "rightcontrol", isPrintable: false),
    63: KeyInfo(keyCode: 63, keyName: "function", isPrintable: false),
    96: KeyInfo(keyCode: 96, keyName: "f5", isPrintable: false),
    97: KeyInfo(keyCode: 97, keyName: "f6", isPrintable: false),
    98: KeyInfo(keyCode: 98, keyName: "f7", isPrintable: false),
    99: KeyInfo(keyCode: 99, keyName: "f3", isPrintable: false),
    100: KeyInfo(keyCode: 100, keyName: "f8", isPrintable: false),
    101: KeyInfo(keyCode: 101, keyName: "f9", isPrintable: false),
    103: KeyInfo(keyCode: 103, keyName: "f11", isPrintable: false),
    109: KeyInfo(keyCode: 109, keyName: "f10", isPrintable: false),
    111: KeyInfo(keyCode: 111, keyName: "f12", isPrintable: false),
    114: KeyInfo(keyCode: 114, keyName: "insert", isPrintable: false),
    115: KeyInfo(keyCode: 115, keyName: "home", isPrintable: false),
    116: KeyInfo(keyCode: 116, keyName: "pageup", isPrintable: false),
    117: KeyInfo(keyCode: 117, keyName: "forwarddelete", isPrintable: false),
    118: KeyInfo(keyCode: 118, keyName: "f4", isPrintable: false),
    119: KeyInfo(keyCode: 119, keyName: "end", isPrintable: false),
    120: KeyInfo(keyCode: 120, keyName: "f2", isPrintable: false),
    121: KeyInfo(keyCode: 121, keyName: "pagedown", isPrintable: false),
    122: KeyInfo(keyCode: 122, keyName: "f1", isPrintable: false),
    123: KeyInfo(keyCode: 123, keyName: "leftarrow", isPrintable: false),
    124: KeyInfo(keyCode: 124, keyName: "rightarrow", isPrintable: false),
    125: KeyInfo(keyCode: 125, keyName: "downarrow", isPrintable: false),
    126: KeyInfo(keyCode: 126, keyName: "uparrow", isPrintable: false)
]

func getKeyName(for keyCode: UInt8) -> String {
    return keyMap[Int(keyCode)]?.keyName ?? "unknown(\(keyCode))"
}

// Set up signal handlers
signal(SIGINT) { _ in
    print("\nExiting CLI Keyboard Monitor")
    exit(0)
}

// Create a log file
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
let dateString = dateFormatter.string(from: Date())
let logPath = FileManager.default.temporaryDirectory.appendingPathComponent("cli-keyboard-monitor-\(dateString).log")
FileManager.default.createFile(atPath: logPath.path, contents: nil, attributes: nil)
let logFile = try? FileHandle(forWritingTo: logPath)

if let logFile = logFile {
    let header = "CLI Keyboard Monitor Log - \(Date())\n"
    logFile.write(header.data(using: .utf8)!)
    logFile.write("KeyCode | KeyName | Type\n".data(using: .utf8)!)
    logFile.write("-----------------------\n".data(using: .utf8)!)
}

print("CLI Keyboard Monitor Started")
print("Log file: \(logPath.path)")
print("Press Ctrl+C to exit")
print("KeyCode | KeyName | Type")
print("-----------------------")

// Set up terminal for reading single characters
let fd = FileHandle.standardInput.fileDescriptor
var termios = termios()
tcgetattr(fd, &termios)
let originalTermios = termios

// Disable canonical mode (line-by-line input) and local echo
termios.c_lflag &= ~UInt(ICANON | ECHO)
tcsetattr(fd, TCSANOW, &termios)

// Start a background task to read keyboard input
DispatchQueue.global(qos: .userInteractive).async {
    while true {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        let amountRead = read(fd, buffer, 1)
        
        if amountRead > 0 {
            let keyCode = buffer[0]
            let keyName = getKeyName(for: keyCode)
            
            // Log the key event
            let logEntry = String(format: "%-7d | %-7s | Down", keyCode, keyName)
            print(logEntry)
            
            // Write to log file
            if let logFile = logFile {
                logFile.write("\(logEntry)\n".data(using: .utf8)!)
            }
        }
        
        buffer.deallocate()
        // Small delay to prevent CPU spinning
        usleep(1000)
    }
}

// Keep the program running
dispatchMain()