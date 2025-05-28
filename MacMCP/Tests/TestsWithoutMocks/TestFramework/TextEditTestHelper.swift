// ABOUTME: TextEditTestHelper.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
@preconcurrency import ApplicationServices
import Foundation
@preconcurrency import MCP
import Testing

@testable @preconcurrency import MacMCP

// Extend UIElementCriteria to be Sendable since it's a simple value type
extension UIElementCriteria: @unchecked Sendable {}

/// Helper class for TextEdit testing, providing shared resources and convenience methods
@MainActor final class TextEditTestHelper {
  // MARK: - Properties

  /// The TextEdit app model
  let app: TextEditModel

  /// The ToolChain for interacting with MCP tools
  let toolChain: ToolChain

  /// Temporary directory for test files
  private let tempDirectory: URL

  // Singleton instance
  private static var sharedInstance: TextEditTestHelper?
  private static let lock = NSLock()

  // MARK: - Initialization

  init() {
    // Create a tool chain
    toolChain = ToolChain(logLabel: "mcp.test.textedit")

    // Create a TextEdit model
    app = TextEditModel(toolChain: toolChain)

    // Create a temporary directory for test files
    tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(
      "textedit_tests_\(UUID().uuidString)"
    )

    // Create the directory if it doesn't exist
    do {
      try FileManager.default.createDirectory(
        at: tempDirectory, withIntermediateDirectories: true, )
    } catch {
      print("Warning: Failed to create temp directory: \(error)")
    }
  }

  /// Get or create a shared helper instance
  @MainActor static func shared() -> TextEditTestHelper {
    lock.lock()
    defer { lock.unlock() }

    if let instance = sharedInstance { return instance }

    let newInstance = TextEditTestHelper()
    sharedInstance = newInstance
    return newInstance
  }

  deinit {
    // Clean up temp directory
    try? FileManager.default.removeItem(at: tempDirectory)
  }

  // MARK: - TextEdit Operations

  /// Ensure the TextEdit app is running and is the frontmost application
  func ensureAppIsRunning() async throws -> Bool {
    let wasRunning = try await app.isRunning()
    if !wasRunning {
      // Launch the app
      let launched = try await app.launch()
      if !launched { return false }
      // Wait for app to launch fully
      try await Task.sleep(for: .milliseconds(2000))
    }

    // Ensure TextEdit is frontmost application regardless of whether we just launched it
    if let textEditApp = NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.apple.TextEdit"
    ).first {
      let activateSuccess = textEditApp.activate(options: [])
      if !activateSuccess { print("Warning: Failed to activate TextEdit as frontmost app") }

      // Wait for activation
      try await Task.sleep(for: .milliseconds(500))
    } else {
      return false
    }

    return true
  }

  /// Reset the TextEdit app state (create a new document)
  func resetAppState() async throws {
    do {
      // Create a new document to start with a clean slate
      _ = try await app.createNewDocument()
      try await Task.sleep(for: .milliseconds(1000))
    } catch {
      // If creating a new document fails, try to terminate and relaunch
      do {
        _ = try await app.terminate()
        try await Task.sleep(for: .milliseconds(1000))
        _ = try await app.launch()
        try await Task.sleep(for: .milliseconds(1000))
        _ = try await app.createNewDocument()
        try await Task.sleep(for: .milliseconds(1000))
      } catch {
        // Log error but continue - we'll do our best with the current state
        print("Warning: Could not reset TextEdit state: \(error)")
      }
    }
  }

  /// Assert that the TextEdit document contains specific text
  func assertDocumentContainsText(_ expectedText: String, message: String = "") async throws {
    // Get the actual document text
    let actualText = try await app.getText()

    // Use the custom message if provided, otherwise create a default message
    let _ =
      message.isEmpty
      ? "TextEdit document should contain '\(expectedText)' but found '\(actualText ?? "nil")'"
      : message

    // Assert the text is contained in the document using Swift Testing framework
    #expect(actualText?.contains(expectedText) ?? false)
  }

  /// Generate a unique temp file path for tests
  func generateTempFilePath(fileExtension: String = "rtf") -> String {
    let filename = "test_\(UUID().uuidString).\(fileExtension)"
    return tempDirectory.appendingPathComponent(filename).path
  }

  // MARK: - Text Operations

  /// Type text into the TextEdit document
  func typeText(_ text: String) async throws -> Bool { try await app.typeText(text) }

  /// Select text in the document
  func selectText(startPos: Int, length: Int) async throws -> Bool {
    try await app.selectText(startPos: startPos, length: length)
  }

  /// Toggle bold formatting for selected text
  func toggleBold() async throws -> Bool { try await app.toggleBold() }

  /// Toggle italic formatting for selected text
  func toggleItalic() async throws -> Bool { try await app.toggleItalic() }

  /// Make text larger by using the Format menu
  func makeTextLarger() async throws -> Bool { try await app.makeTextLarger() }

  /// Make text smaller by using the Format menu
  func makeTextSmaller() async throws -> Bool { try await app.makeTextSmaller() }

  // MARK: - Document Operations

  /// Save the document to a file
  func saveDocument(to path: String? = nil) async throws -> (path: String, success: Bool) {
    let savePath = path ?? generateTempFilePath()

    // Try to save the document
    let saveSuccess = try await app.saveDocument(to: savePath)
    if !saveSuccess {
      throw NSError(
        domain: "TextEditTestHelper",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Failed to save document to \(savePath)"],
      )
    }

    return (savePath, saveSuccess)
  }

  /// Open a document from a file
  func openDocument(from path: String) async throws -> Bool {
    try await app.openDocument(from: path)
  }

  /// Close window and click "Delete" button on save dialog
  /// This is specifically for ElementPath testing where we need to handle
  /// the window close differently than the regular TextEditModel approach
  @MainActor func closeWindowAndDiscardChanges() async throws -> Bool {
    // Use the internal accessibilityService from the app
    return try await closeWindowAndDiscardChanges(using: app.toolChain.accessibilityService)
  }
  /// Close window and click "Delete" button on save dialog with a specific accessibilityService
  /// This is specifically for ElementPath testing where we need to handle
  /// the window close differently than the regular TextEditModel approach
  @MainActor func closeWindowAndDiscardChanges(using accessibilityService: AccessibilityService, )
    async throws
    -> Bool
  {
    // First try pressing Escape to dismiss any open menus or dialogs
    let systemEsc = AXUIElementCreateSystemWide()
    try? AccessibilityElement.performAction(systemEsc, action: "AXCancel")

    // Find the close button on the window using ElementPath
    let closeButtonPath = try ElementPath.parse(
      "macos://ui/AXApplication[@bundleId=\"com.apple.TextEdit\"]/AXWindow[0]/AXButton[@AXSubrole=\"AXCloseButton\"]",
    )

    // Try to resolve and press the close button
    if let closeButton = try? await closeButtonPath.resolve(using: accessibilityService) {
      // Press the close button
      try? AccessibilityElement.performAction(closeButton, action: "AXPress")

      // Wait for save dialog to appear
      try await Task.sleep(nanoseconds: 800_000_000)

      // Look for the "Delete" button in the save dialog
      let appElement = AccessibilityElement.applicationElement(
        pid: NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit")
          .first!
          .processIdentifier,
      )

      // Helper to find buttons in the dialog
      @MainActor func findButtonWithTitle(_ title: String, inElement element: AXUIElement)
        -> AXUIElement?
      {
        if let children = try? AccessibilityElement.getAttribute(element, attribute: "AXChildren")
          as? [AXUIElement]
        {
          for child in children {
            if let role = try? AccessibilityElement.getAttribute(child, attribute: "AXRole")
              as? String,
              role == "AXButton",
              let childTitle = try? AccessibilityElement.getAttribute(child, attribute: "AXTitle", )
                as? String, childTitle == title
            {
              return child
            }

            // Recursive search
            if let button = findButtonWithTitle(title, inElement: child) { return button }
          }
        }
        return nil
      }

      // Find and press "Delete" button
      if let deleteButton = findButtonWithTitle("Delete", inElement: appElement) {
        try? AccessibilityElement.performAction(deleteButton, action: "AXPress")
        try await Task.sleep(nanoseconds: 500_000_000)
        return true
      }
    }

    return false
  }

  /// Perform common text operation and verify result
  func performTextOperation(operation: () async throws -> Bool, verificationText: String, )
    async throws -> Bool
  {
    // Reset document state
    try await resetAppState()

    // Perform the operation
    _ = try await operation()

    // Brief pause to allow UI to update
    try await Task.sleep(for: .milliseconds(500))

    // Get the document text
    let documentText = try await app.getText()

    // Verify the text
    return documentText?.contains(verificationText) ?? false
  }
}
