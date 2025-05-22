// ABOUTME: MenuNavigationCalculatorTest.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
// Test utilities are directly available in this module
import MCP
import Testing

@testable import MacMCP

/// A simple struct to hold application information
private struct CalculatorAppInfo {
  let bundleId: String
  let applicationName: String
}

/// A focused test for menu navigation in Calculator
@Suite(.serialized)
struct MenuNavigationCalculatorTest {
  private var helper: CalculatorTestHelper!

  // Shared setup method
  private mutating func setUp() async throws {
    // Get shared helper
    helper = await CalculatorTestHelper.sharedHelper()

    // Ensure app is running and reset state
    let appRunning = try await helper.ensureAppIsRunning()
    #expect(appRunning, "Calculator should be running")

    // Explicitly activate Calculator using MCP to ensure it's in the foreground
    try await activateCalculatorWithMCP()

    // Wait longer to ensure activation is complete
    try await Task.sleep(for: .milliseconds(3000))

    // Verify Calculator is frontmost
    let frontmost = try await getFrontmostApp()
    #expect(
      frontmost?.bundleId == "com.apple.calculator",
      "Calculator should be frontmost after activation"
    )
  }
  
  // Shared teardown method
  private mutating func tearDown() async throws {
    if helper != nil {
      // Reset calculator to clean state
      await helper.resetAppState()
      
      // Optionally terminate the app
      // We don't terminate here since the helper manages app lifecycle
    }
  }



  /// Test basic menu navigation: switch from Basic to Scientific calculator mode
  @Test("View Menu Navigation")
  mutating func testViewMenuNavigation() async throws {
    try await setUp()
    
    // First run the menu listing logic to understand the menu structure
    // Ensure Calculator is activated and in the foreground
    try await activateCalculatorWithMCP()
    try await Task.sleep(for: .milliseconds(2000))

    // List all menu items in the application menu bar
    let menuParams: [String: Value] = [
      "action": .string("getApplicationMenus"),
      "bundleId": .string("com.apple.calculator"),
    ]
    
    let _ = try await helper.toolChain.menuNavigationTool.handler(menuParams)


    // Use Menu Navigation Tool to switch to Scientific mode via View menu
    let scientificSuccess = try await switchToCalculatorMode("Scientific")

    // Test switching to Scientific mode
    #expect(scientificSuccess, "Should successfully navigate to View > Scientific menu item")

    // Wait for mode change to take effect
    try await Task.sleep(for: .milliseconds(2000))

    // Get updated calculator mode
    let _ = try await getCalculatorMode()

    // Now try switching to Basic mode
    let basicSuccess = try await switchToCalculatorMode("Basic")
    #expect(basicSuccess, "Should successfully navigate to View > Basic menu item")

    // Wait for mode change to take effect
    try await Task.sleep(for: .milliseconds(2000))

    
    try await tearDown()
  }

  /// Activate Calculator application using MCP to bring it to foreground
  private func activateCalculatorWithMCP() async throws {
    // Use the applicationManagementTool to activate Calculator
    let params: [String: Value] = [
      "action": .string("activateApplication"),
      "bundleId": .string("com.apple.calculator"),
    ]

    let result = try await helper.toolChain.applicationManagementTool.handler(params)

    // Check if activation was successful
    if let content = result.first, case .text(let text) = content {
      let success = text.contains("success") && text.contains("true")
      if !success {
        throw MCPError.internalError("Failed to activate Calculator application")
      }
    }
  }

  /// Get the frontmost application
  private func getFrontmostApp() async throws -> CalculatorAppInfo? {
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
        return CalculatorAppInfo(
          bundleId: bundleId,
          applicationName: appName
        )
      }
    }

    return nil
  }

  /// Get the current calculator mode (Basic, Scientific, Programmer)
  private func getCalculatorMode() async throws -> String {
    // Use interface explorer to check the window title which reflects the mode
    let explorerParams: [String: Value] = [
      "scope": .string("application"),
      "bundleId": .string("com.apple.calculator"),
    ]

    let result = try await helper.toolChain.interfaceExplorerTool.handler(explorerParams)

    if let content = result.first, case .text(let text) = content {
      if text.contains("Scientific Calculator") {
        return "Scientific"
      } else if text.contains("Programmer Calculator") {
        return "Programmer"
      } else {
        return "Basic"
      }
    }

    return "Unknown"
  }

  /// Switch calculator to a different mode via View menu
  private func switchToCalculatorMode(_ mode: String) async throws -> Bool {
    // Ensure Calculator is activated first
    try await activateCalculatorWithMCP()
    try await Task.sleep(for: .milliseconds(1000))

    // Use menu paths with MenuNavigationTool in ElementPath URI format
    let menuParams: [String: Value] = [
      "action": .string("activateMenuItem"),
      "bundleId": .string("com.apple.calculator"),
      "menuPath": .string("macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXMenuBar/AXMenuBarItem[@AXTitle=\"View\"]/AXMenu/AXMenuItem[@AXTitle=\"" + mode + "\"]"),
    ]

    // Use MenuNavigationTool's handler method
    let result = try await helper.toolChain.menuNavigationTool.handler(menuParams)

    // Check if navigation was successful
    if let content = result.first, case .text(let text) = content {

      // Add a longer delay to allow menu action to take effect
      try await Task.sleep(for: .milliseconds(1000))

      return text.contains("success") || text.contains("true")
    }

    return false
  }
}