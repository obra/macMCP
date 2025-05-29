// ABOUTME: KeyCodeMapping.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation

/// Structure representing a key code and its associated modifier flags
public struct KeyCodeWithModifiers {
  /// The virtual key code
  public let keyCode: CGKeyCode

  /// Modifier flags (if any)
  public let modifiers: CGEventFlags

  /// Initialize with key code and optional modifiers
  public init(keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }
}

/// Utility for mapping between keys, characters, and key codes
public enum KeyCodeMapping {
  /// All letter keys (a-z) and their corresponding key codes (ANSI layout)
  private static let letterKeyCodes: [String: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
    "c": 0x08, "v": 0x09,
    "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "o": 0x1F,
    "u": 0x20, "i": 0x22,
    "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D, "m": 0x2E,
  ]

  /// Number keys and their corresponding key codes (ANSI layout)
  private static let numberKeyCodes: [String: CGKeyCode] = [
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C,
    "9": 0x19, "0": 0x1D,
  ]

  /// Special keys and their corresponding key codes
  private static let specialKeyCodes: [String: CGKeyCode] = [
    "space": 0x31, "return": 0x24, "tab": 0x30, "escape": 0x35, "delete": 0x33,
    "forwarddelete": 0x75, "left": 0x7B,
    "right": 0x7C, "down": 0x7D, "up": 0x7E, "f1": 0x7A, "f2": 0x78, "f3": 0x63, "f4": 0x76,
    "f5": 0x60, "f6": 0x61,
    "f7": 0x62, "f8": 0x64, "f9": 0x65, "f10": 0x6D, "f11": 0x67, "f12": 0x6F, "home": 0x73,
    "end": 0x77,
    "pageup": 0x74, "pagedown": 0x79,
    // Alternative names for special keys
    "enter": 0x24, "esc": 0x35, "backspace": 0x33,
    // Special ASCII characters
    "\n": 0x24, "\r": 0x24, // Newline and carriage return map to Return key
  ]

  /// Modifier keys and their corresponding key codes
  private static let modifierKeyCodes: [String: CGKeyCode] = [
    "command": 0x37, "shift": 0x38, "option": 0x3A, "control": 0x3B, "rightcommand": 0x36,
    "rightshift": 0x3C,
    "rightoption": 0x3D, "rightcontrol": 0x3E, "capslock": 0x39, "function": 0x3F,
    // Aliases for modifier keys
    "alt": 0x3A, "ctrl": 0x3B, "cmd": 0x37,
  ]

  /// Symbol keys and their corresponding key codes
  private static let symbolKeyCodes: [String: CGKeyCode] = [
    "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A, ";": 0x29, "'": 0x27, ",": 0x2B,
    ".": 0x2F, "/": 0x2C,
    "`": 0x32, // backtick/grave
    // Names for symbols
    "minus": 0x1B, "equal": 0x18, "leftbracket": 0x21, "rightbracket": 0x1E, "backslash": 0x2A,
    "semicolon": 0x29,
    "quote": 0x27, "comma": 0x2B, "period": 0x2F, "slash": 0x2C, "grave": 0x32,
  ]

  /// Map of key names to the corresponding modifier flags
  private static let modifierFlags: [String: CGEventFlags] = [
    "command": .maskCommand, "cmd": .maskCommand, "shift": .maskShift, "option": .maskAlternate,
    "alt": .maskAlternate, "control": .maskControl, "ctrl": .maskControl,
  ]

  /// Map of symbol characters that require shift modifier to the base character
  private static let shiftSymbols: [String: String] = [
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9",
    ")": "0", "_": "-",
    "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/",
    // Common math operators that may need special handling
    "×": "*", // Multiplication sign maps to * (Shift+8)
    "÷": "/", // Division sign maps to /
  ]

  /// Get key code and modifiers for a key name (e.g., "a", "space", "command")
  /// - Parameter keyName: The key name
  /// - Returns: KeyCodeWithModifiers containing the key code and any required modifiers
  public static func keyCodeForKey(_ keyName: String) -> KeyCodeWithModifiers? {
    let lowercaseKey = keyName.lowercased()

    // Special case for space character
    if keyName == " " {
      if let keyCode = specialKeyCodes["space"] { return KeyCodeWithModifiers(keyCode: keyCode) }
    }

    // Check each category of keys
    if let keyCode = letterKeyCodes[lowercaseKey] {
      // For letters, check if uppercase to add shift modifier
      let modifiers: CGEventFlags = keyName != lowercaseKey ? .maskShift : []
      return KeyCodeWithModifiers(keyCode: keyCode, modifiers: modifiers)
    }

    if let keyCode = numberKeyCodes[lowercaseKey] { return KeyCodeWithModifiers(keyCode: keyCode) }

    if let keyCode = specialKeyCodes[lowercaseKey] { return KeyCodeWithModifiers(keyCode: keyCode) }

    if let keyCode = modifierKeyCodes[lowercaseKey] {
      return KeyCodeWithModifiers(keyCode: keyCode)
    }

    if let keyCode = symbolKeyCodes[lowercaseKey] { return KeyCodeWithModifiers(keyCode: keyCode) }

    // Check if it's a shifted symbol (e.g., !, @, #)
    if let baseKey = shiftSymbols[keyName] {
      if let keyCodeInfo = keyCodeForKey(baseKey) {
        // Add shift modifier for these symbols
        var modifiers = keyCodeInfo.modifiers
        modifiers.insert(.maskShift)
        return KeyCodeWithModifiers(keyCode: keyCodeInfo.keyCode, modifiers: modifiers)
      }
    }

    // Not found in any map
    return nil
  }

  /// Get key code and modifiers for a single character
  /// - Parameter character: The character to get key code for
  /// - Returns: KeyCodeWithModifiers containing the key code and any required modifiers
  public static func keyCodeForCharacter(_ character: Character) -> KeyCodeWithModifiers? {
    let charString = String(character)

    // First, check for characters that need shift
    if let baseChar = shiftSymbols[charString] {
      // Get the key code for the base character
      if let baseKeyCode = keyCodeForKey(baseChar) {
        // Add shift modifier
        var modifiers = baseKeyCode.modifiers
        modifiers.insert(.maskShift)
        return KeyCodeWithModifiers(keyCode: baseKeyCode.keyCode, modifiers: modifiers)
      }
    }

    // Handle special characters
    if character == " " {
      if let keyCode = specialKeyCodes["space"] { return KeyCodeWithModifiers(keyCode: keyCode) }
    }

    // Handle newline characters
    if character == "\n" || character == "\r" {
      if let keyCode = specialKeyCodes["return"] { return KeyCodeWithModifiers(keyCode: keyCode) }
    }

    // For uppercase letters, add shift modifier
    if character.isUppercase {
      let lowercaseChar = String(character.lowercased())
      if let keyCode = letterKeyCodes[lowercaseChar] {
        return KeyCodeWithModifiers(keyCode: keyCode, modifiers: .maskShift)
      }
    }

    // Standard lookup for other characters
    return keyCodeForKey(charString)
  }

  /// Get the CGEventFlags corresponding to an array of modifier key names
  /// - Parameter modifierNames: Array of modifier key names (e.g., ["command", "shift"])
  /// - Returns: Combined CGEventFlags for all specified modifiers
  public static func modifierFlagsForNames(_ modifierNames: [String]) -> CGEventFlags {
    var flags: CGEventFlags = []

    for name in modifierNames {
      if let modifierFlag = modifierFlags[name.lowercased()] { flags.insert(modifierFlag) }
    }

    return flags
  }

  /// Check if a key is a modifier key
  /// - Parameter keyName: The key name to check
  /// - Returns: True if the key is a modifier key
  public static func isModifierKey(_ keyName: String) -> Bool {
    modifierKeyCodes.keys.contains(keyName.lowercased())
  }

  /// Convert NSEvent.ModifierFlags to CGEventFlags
  /// - Parameter nsModifiers: The NSEvent.ModifierFlags to convert
  /// - Returns: Equivalent CGEventFlags
  public static func cgEventFlagsFromNSModifierFlags(_ nsModifiers: NSEvent.ModifierFlags)
    -> CGEventFlags
  {
    var cgFlags: CGEventFlags = []

    if nsModifiers.contains(.command) { cgFlags.insert(.maskCommand) }

    if nsModifiers.contains(.shift) { cgFlags.insert(.maskShift) }

    if nsModifiers.contains(.option) { cgFlags.insert(.maskAlternate) }

    if nsModifiers.contains(.control) { cgFlags.insert(.maskControl) }

    if nsModifiers.contains(.function) { cgFlags.insert(.maskSecondaryFn) }

    return cgFlags
  }

  /// Convert CGEventFlags to NSEvent.ModifierFlags
  /// - Parameter cgModifiers: The CGEventFlags to convert
  /// - Returns: Equivalent NSEvent.ModifierFlags
  public static func nsModifierFlagsFromCGEventFlags(_ cgModifiers: CGEventFlags)
    -> NSEvent.ModifierFlags
  {
    var nsFlags: NSEvent.ModifierFlags = []

    if cgModifiers.contains(.maskCommand) { nsFlags.insert(.command) }

    if cgModifiers.contains(.maskShift) { nsFlags.insert(.shift) }

    if cgModifiers.contains(.maskAlternate) { nsFlags.insert(.option) }

    if cgModifiers.contains(.maskControl) { nsFlags.insert(.control) }

    if cgModifiers.contains(.maskSecondaryFn) { nsFlags.insert(.function) }

    return nsFlags
  }
}
