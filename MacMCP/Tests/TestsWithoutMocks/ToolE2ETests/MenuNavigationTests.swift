// ABOUTME: MenuNavigationTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP
import Testing

@testable import MacMCP

/// A simple struct to hold application information
private struct TextEditAppInfo {
  let bundleId: String
  let applicationName: String
}

/// A focused test for menu navigation in TextEdit
@Suite(.serialized)
struct MenuNavigationTest {
  private var helper: TextEditTestHelper!

  // Shared setup method
  private mutating func setUp() async throws {
    // Get shared helper
    helper = await TextEditTestHelper.shared()

    // Ensure app is running and reset state
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning)
    try await helper.resetAppState()

    // Explicitly activate TextEdit using MCP to ensure it's in the foreground
    try await activateTextEditWithMCP()

    // Wait longer to ensure activation is complete
    try await Task.sleep(for: .milliseconds(3000))

    // Verify TextEdit is frontmost
    let frontmost = try await getFrontmostApp()
    #expect(frontmost?.bundleId == "com.apple.TextEdit")
  }
  
  // Shared teardown method
  private mutating func tearDown() async throws {
    if helper != nil {
      _ = try await helper.closeWindowAndDiscardChanges()
    }
  }

  /// Test basic menu navigation: open a new document and close it
  @Test("Menu Navigation Basic Operations")
  mutating func testMenuNavigationBasic() async throws {
    try await setUp()
    
    // Get initial count of windows
    let initialWindows = try await getTextEditWindowCount()

    // Use Menu Navigation Tool to open a new document via File > New menu
    let openSuccess = try await openNewDocumentViaMenu()

    // Test opening new document - this assertion must pass to continue
    #expect(openSuccess)

    // Only continue if open was successful
    if openSuccess {
      // Wait for window to appear
      try await Task.sleep(for: .milliseconds(2000))

      // Count windows after opening a new document
      let afterOpenWindows = try await getTextEditWindowCount()

      // Verify a new window was opened
      #expect(
        afterOpenWindows == initialWindows + 1,
        "Opening a new document should increase window count by 1"
      )

      // Only try to close if we verified window count increased
      if afterOpenWindows == initialWindows + 1 {
        // Now close the newly created window using File > Close menu
        let closeSuccess = try await closeDocumentViaMenu()
        #expect(closeSuccess, "Should successfully navigate to File > Close menu item")

        // Wait for window to close
        try await Task.sleep(for: .milliseconds(2000))

        // Count windows after closing
        let afterCloseWindows = try await getTextEditWindowCount()

        // Verify the window was closed
        #expect(
          afterCloseWindows == initialWindows,
          "Closing the document should return to initial window count"
        )
      }
    }
    
    try await tearDown()
  }

  /// Activate TextEdit application using MCP to bring it to foreground
  private func activateTextEditWithMCP() async throws {
    // Use the applicationManagementTool to activate TextEdit
    let params: [String: Value] = [
      "action": .string("activateApplication"),
      "bundleId": .string("com.apple.TextEdit"),
    ]

    let result = try await helper.toolChain.applicationManagementTool.handler(params)

    // Check if activation was successful
    if let content = result.first, case .text(let text) = content {
      let success = text.contains("success") && text.contains("true")
      if !success {
        throw MCPError.internalError("Failed to activate TextEdit application")
      }
    }
  }

  /// Get the frontmost application
  private func getFrontmostApp() async throws -> TextEditAppInfo? {
    let params: [String: Value] = [
      "action": .string("getFrontmostApplication")
    ]

    let result = try await helper.toolChain.applicationManagementTool.handler(params)

    // Parse the response to get application info
    if let content = result.first, case .text(let text) = content {

      // Extract application info from the JSON response
      if let data = text.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let bundleId = json["bundleId"] as? String,
        let appName = json["applicationName"] as? String
      {
        return TextEditAppInfo(
          bundleId: bundleId,
          applicationName: appName
        )
      }
    }

    return nil
  }

  /// Get count of TextEdit windows
  private func getTextEditWindowCount() async throws -> Int {
    // Use window management tool to get the application windows
    let windowParams: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string("com.apple.TextEdit"),
      "includeMinimized": .bool(true),
    ]

    let result = try await helper.toolChain.windowManagementTool.handler(windowParams)

    // Extract window count from result
    if let content = result.first, case .text(let text) = content {

      // Parse the JSON for window information
      if let data = text.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      {
        // The result directly contains an array of window descriptors
        return json.count
      }
    }

    throw MCPError.internalError("Failed to get window count: could not parse window data")
  }

  /// Open a new document via File > New menu
  private func openNewDocumentViaMenu() async throws -> Bool {
    // Ensure TextEdit is activated first
    try await activateTextEditWithMCP()
    try await Task.sleep(for: .milliseconds(1000))

    let menuParams: [String: Value] = [
      "action": .string("selectMenuItem"),
      "bundleId": .string("com.apple.TextEdit"),
      "menuPath": .string("File > New"),
    ]

    let result = try await helper.toolChain.menuNavigationTool.handler(menuParams)

    // Check if navigation was successful
    if let content = result.first, case .text(let text) = content {
      return text.contains("success") || text.contains("true")
    }

    return false
  }

  /// Close the document via File > Close menu
  private func closeDocumentViaMenu() async throws -> Bool {
    // Ensure TextEdit is activated first
    try await activateTextEditWithMCP()
    try await Task.sleep(for: .milliseconds(1000))

    let menuParams: [String: Value] = [
      "action": .string("selectMenuItem"),
      "bundleId": .string("com.apple.TextEdit"),
      "menuPath": .string("File > Close"),
    ]

    let result = try await helper.toolChain.menuNavigationTool.handler(menuParams)

    // Check if navigation was successful
    if let content = result.first, case .text(let text) = content {
      return text.contains("success") || text.contains("true")
    }

    return false
  }
}