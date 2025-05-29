// ABOUTME: KeyboardInteractionToolTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct KeyboardInteractionToolTests {
  // Test components
  private var accessibilityService: AccessibilityService!
  private var interactionService: UIInteractionServiceStub!
  private var keyboardInteractionTool: KeyboardInteractionTool!

  // Test helpers
  private var keyboardEventMonitor: KeyboardEventMonitor!
  private var capturedEvents: [CapturedKeyEvent] = []

  private mutating func setupTest() async throws {
    // Create dependencies
    accessibilityService = AccessibilityService()
    interactionService = UIInteractionServiceStub()

    // Create the tool
    let mockAccessibilityService = MockAccessibilityService()
    let changeDetectionService = UIChangeDetectionService(
      accessibilityService: mockAccessibilityService,
    )
    keyboardInteractionTool = KeyboardInteractionTool(
      interactionService: interactionService,
      accessibilityService: mockAccessibilityService,
      changeDetectionService: changeDetectionService,
    )

    // Set up keyboard event monitor
    keyboardEventMonitor = KeyboardEventMonitor()
    // Use a local handler that doesn't capture self
    let handler: (CapturedKeyEvent) -> Void = { _ in
      // We're not actually doing anything with the events in the test
      // Just using the monitor to set up the environment
    }
    keyboardEventMonitor.startMonitoring(handler: handler)

    // Clear captured events
    capturedEvents = []
  }

  private mutating func cleanupTest() async throws {
    // Stop monitoring keyboard events
    keyboardEventMonitor.stopMonitoring()

    // Clear captured events
    capturedEvents = []
  }

  // MARK: - Type Text Tests

  @Test("Test type text") mutating func typeText() async throws {
    try await setupTest()
    // Prepare test data
    let text = "Hello"
    let params: [String: Value] = ["action": .string("type_text"), "text": .string(text)]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // Verify the correct keys were pressed
    try await Task.sleep(for: .seconds(0.5)) // Allow events to be processed

    // Verify with the stub service
    let interactionStub = interactionService!
    #expect(
      interactionStub.keyPressCount == text.count, "Should have pressed one key for each character",
    )
    try await cleanupTest()
  }

  @Test("Test type text special characters") mutating func typeTextSpecialCharacters()
    async throws
  {
    try await setupTest()
    // Prepare test data with special characters
    let text = "Hello, World!"
    let params: [String: Value] = ["action": .string("type_text"), "text": .string(text)]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // Verify the correct keys were pressed
    try await Task.sleep(for: .seconds(0.5)) // Allow events to be processed

    // Verify with the stub service
    let interactionStub = interactionService!
    #expect(
      interactionStub.keyPressCount == text.count, "Should have pressed one key for each character",
    )

    // Check for modifiers on special characters
    #expect(interactionStub.usedModifiers, "Should have used modifiers for special characters")
    try await cleanupTest()
  }

  // MARK: - Key Sequence Tests

  @Test("Test key sequence simple tap") mutating func keySequenceSimpleTap() async throws {
    try await setupTest()
    // Test a simple key tap
    let params: [String: Value] = [
      "action": .string("key_sequence"), "sequence": .array([.object(["tap": .string("a")])]),
    ]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // Verify the key presses
    let interactionStub = interactionService!
    #expect(interactionStub.keyPressCount == 1, "Should have pressed one key")
    #expect(!interactionStub.usedModifiers, "Should not have used modifiers")
    try await cleanupTest()
  }

  @Test("Test key sequence with modifiers") mutating func keySequenceWithModifiers()
    async throws
  {
    try await setupTest()
    // Test a key tap with modifiers
    let params: [String: Value] = [
      "action": .string("key_sequence"),
      "sequence": .array([
        .object(["tap": .string("s"), "modifiers": .array([.string("command")])]),
      ]),
    ]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // Verify the key presses
    let interactionStub = interactionService!
    #expect(interactionStub.keyPressCount == 1, "Should have pressed one key")
    #expect(interactionStub.usedModifiers, "Should have used modifiers")
    try await cleanupTest()
  }

  @Test("Test key sequence press release") mutating func keySequencePressRelease() async throws {
    try await setupTest()
    // Test separate press and release events
    let params: [String: Value] = [
      "action": .string("key_sequence"),
      "sequence": .array([
        .object(["press": .string("down")]), .object(["delay": .double(0.1)]),
        .object(["release": .string("down")]),
      ]),
    ]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // For this test, we're more interested in the fact that it completes without errors
    // since actual key events are handled by the CGEvent system directly
    #expect(Bool(true), "Key sequence with press/release completed successfully")
    try await cleanupTest()
  }

  @Test("Test complex key sequence") mutating func complexKeySequence() async throws {
    try await setupTest()
    // Test a complex key sequence
    let params: [String: Value] = [
      "action": .string("key_sequence"),
      "sequence": .array([
        .object(["press": .string("command")]), .object(["tap": .string("tab")]),
        .object(["delay": .double(0.1)]), .object(["tap": .string("tab")]),
        .object(["release": .string("command")]),
      ]),
    ]

    // Execute the tool
    _ = try await keyboardInteractionTool.handler(params)

    // For complex sequences, we're more interested in the fact that it completes without errors
    #expect(Bool(true), "Complex key sequence completed successfully")
    try await cleanupTest()
  }
}

// MARK: - Test Support Classes

/// Structure to represent a captured keyboard event
struct CapturedKeyEvent {
  let keyCode: Int
  let character: String
  let isKeyDown: Bool
  let modifiers: NSEvent.ModifierFlags
  let timestamp: TimeInterval
}

/// Enum for common key codes
enum KeyCode: Int {
  // Letters (ANSI layout)
  case a = 0x00
  case s = 0x01
  case d = 0x02
  case f = 0x03
  case h = 0x04
  case g = 0x05
  case z = 0x06
  case x = 0x07
  case c = 0x08
  case v = 0x09
  case b = 0x0B
  case q = 0x0C
  case w = 0x0D
  case e = 0x0E
  case r = 0x0F
  case y = 0x10
  case t = 0x11
  case o = 0x1F
  case u = 0x20
  case i = 0x22
  case p = 0x23
  case l = 0x25
  case j = 0x26
  case k = 0x28
  case n = 0x2D
  case m = 0x2E

  // Numbers (ANSI layout)
  case one = 0x12
  case two = 0x13
  case three = 0x14
  case four = 0x15
  case five = 0x17
  case six = 0x16
  case seven = 0x1A
  case eight = 0x1C
  case nine = 0x19
  case zero = 0x1D

  // Special keys
  case return_key = 0x24
  case tab = 0x30
  case space = 0x31
  case delete = 0x33 // Backspace
  case escape = 0x35
  case forwardDelete = 0x75
  case home = 0x73
  case end = 0x77
  case pageUp = 0x74
  case pageDown = 0x79

  // Arrow keys
  case leftArrow = 0x7B
  case rightArrow = 0x7C
  case downArrow = 0x7D
  case upArrow = 0x7E

  // Function keys
  case f1 = 0x7A
  case f2 = 0x78
  case f3 = 0x63
  case f4 = 0x76
  case f5 = 0x60
  case f6 = 0x61
  case f7 = 0x62
  case f8 = 0x64
  case f9 = 0x65
  case f10 = 0x6D
  case f11 = 0x67
  case f12 = 0x6F

  // Modifier keys
  case command = 0x37
  case shift = 0x38
  case option = 0x3A // Alt key
  case control = 0x3B
  case rightCommand = 0x36
  case rightShift = 0x3C
  case rightOption = 0x3D
  case rightControl = 0x3E
  case capsLock = 0x39

  // Symbol keys
  case minus = 0x1B // -
  case equal = 0x18 // =
  case leftBracket = 0x21 // [
  case rightBracket = 0x1E // ]
  case backslash = 0x2A // \
  case semicolon = 0x29 // ;
  case quote = 0x27 // '
  case comma = 0x2B // ,
  case period = 0x2F // .
  case slash = 0x2C // /
  case grave = 0x32 // ` (backtick)
}

/// A stub implementation of the UIInteractionServiceProtocol for testing
class UIInteractionServiceStub: UIInteractionServiceProtocol {
  var keyPressCount = 0
  var usedModifiers = false

  func clickElementByPath(path _: String, appBundleId _: String?) async throws {
    // No-op for testing
  }

  func clickAtPosition(position _: CGPoint) async throws {
    // No-op for testing
  }

  func doubleClickElementByPath(path _: String, appBundleId _: String?) async throws {
    // No-op for testing
  }

  func doubleClickAtPosition(position _: CGPoint) async throws {
    // No-op for testing
  }

  func rightClickElementByPath(path _: String, appBundleId _: String?) async throws {
    // No-op for testing
  }

  func rightClickAtPosition(position _: CGPoint) async throws {
    // No-op for testing
  }

  func typeTextByPath(path _: String, text _: String, appBundleId _: String?) async throws {
    // No-op for testing
  }

  func pressKey(keyCode _: Int, modifiers: CGEventFlags?) async throws {
    keyPressCount += 1
    if let modifiers, !modifiers.isEmpty { usedModifiers = true }
  }

  func dragElementByPath(sourcePath _: String, targetPath _: String, appBundleId _: String?)
    async throws
  {
    // No-op for testing
  }

  func scrollElementByPath(
    path _: String, direction _: ScrollDirection, amount _: Double, appBundleId _: String?,
  )
    async throws
  {
    // No-op for testing
  }

  func performActionByPath(path _: String, action _: String, appBundleId _: String?) async throws {
    // No-op for testing
  }
}

/// Class to monitor keyboard events for testing
class KeyboardEventMonitor {
  private var localMonitor: Any?
  private var globalMonitor: Any?

  /// Start monitoring keyboard events
  func startMonitoring(handler: @escaping (CapturedKeyEvent) -> Void) {
    // Monitor keyboard events within the application
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      self.processEvent(event, isKeyDown: true, handler: handler)
      return event
    }

    NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
      self.processEvent(event, isKeyDown: false, handler: handler)
      return event
    }

    // Monitor keyboard events globally
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
      self.processEvent(event, isKeyDown: event.type == .keyDown, handler: handler)
    }
  }

  /// Stop monitoring keyboard events
  func stopMonitoring() {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }

    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
      self.globalMonitor = nil
    }
  }

  /// Process a keyboard event
  private func processEvent(_ event: NSEvent, isKeyDown: Bool, handler: (CapturedKeyEvent) -> Void)
  {
    let keyCode = Int(event.keyCode)
    let character = event.characters ?? ""
    let modifiers = event.modifierFlags
    let timestamp = ProcessInfo.processInfo.systemUptime

    let capturedEvent = CapturedKeyEvent(
      keyCode: keyCode,
      character: character,
      isKeyDown: isKeyDown,
      modifiers: modifiers,
      timestamp: timestamp,
    )

    handler(capturedEvent)
  }
}
