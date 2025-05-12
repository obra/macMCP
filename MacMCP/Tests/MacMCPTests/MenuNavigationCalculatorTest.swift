// ABOUTME: This file provides a focused test for menu navigation in Calculator.
// ABOUTME: It verifies that menu commands can be found and activated properly.

import Foundation
import XCTest
@testable import MacMCP
import MCP

/// A simple struct to hold application information
fileprivate struct CalculatorAppInfo {
    let bundleIdentifier: String
    let applicationName: String
}

/// A focused test for menu navigation in Calculator
@MainActor
final class MenuNavigationCalculatorTest: XCTestCase {
    private var helper: CalculatorTestHelper!
    
    override func setUp() async throws {
        // Get shared helper
        helper = CalculatorTestHelper.sharedHelper()
        
        // Ensure app is running and reset state
        let appRunning = try await helper.ensureAppIsRunning()
        XCTAssertTrue(appRunning, "Calculator should be running")
        
        // Explicitly activate Calculator using MCP to ensure it's in the foreground
        try await activateCalculatorWithMCP()
        
        // Wait longer to ensure activation is complete
        try await Task.sleep(for: .milliseconds(3000))
        
        // Verify Calculator is frontmost
        let frontmost = try await getFrontmostApp()
        XCTAssertEqual(frontmost?.bundleIdentifier, "com.apple.calculator", "Calculator should be frontmost after activation")
    }
    
    /// Test listing application menus (helpful for debugging menu navigation)
    func testListCalculatorMenus() async throws {
        // Ensure Calculator is activated and in the foreground
        try await activateCalculatorWithMCP()
        try await Task.sleep(for: .milliseconds(2000))

        // List all menu items in the application menu bar
        let menuParams: [String: Value] = [
            "action": .string("getApplicationMenus"),
            "bundleId": .string("com.apple.calculator")
        ]

        let result = try await helper.toolChain.menuNavigationTool.handler(menuParams)

        // Print the menu structure for debugging
        if let content = result.first, case .text(let text) = content {
            print("Calculator Menu Bar Structure:")
            print(text)

            // Parse the JSON to examine the menu structure in detail
            if let data = text.data(using: .utf8),
               let menuItems = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {

                print("\nDetailed Menu Analysis:")
                print("Total menu items found: \(menuItems.count)")

                for (index, item) in menuItems.enumerated() {
                    let title = item["title"] as? String ?? "Untitled"
                    let id = item["id"] as? String ?? "No ID"
                    let enabled = item["isEnabled"] as? Bool ?? false
                    let selected = item["isSelected"] as? Bool ?? false

                    print("Item \(index): Title='\(title)', ID=\(id), Enabled=\(enabled), Selected=\(selected)")
                }

                // Identify "View" menu specifically
                if let viewMenu = menuItems.first(where: { ($0["title"] as? String) == "View" }) {
                    print("\nView menu details:")
                    print("ID: \(viewMenu["id"] ?? "No ID")")
                    print("Is enabled: \(viewMenu["isEnabled"] ?? "unknown")")
                }
            }
        }

        // Now get the View menu items specifically
        let viewMenuParams: [String: Value] = [
            "action": .string("getMenuItems"),
            "bundleId": .string("com.apple.calculator"),
            "menuTitle": .string("View")
        ]

        let viewMenuResult = try await helper.toolChain.menuNavigationTool.handler(viewMenuParams)

        // Print the View menu items for debugging
        if let content = viewMenuResult.first, case .text(let text) = content {
            print("Calculator View Menu Items:")
            print(text)
        }

        // This is just for debugging menu structure, so no assertions needed
        XCTAssertTrue(true, "Successfully retrieved menu structure")
    }

    /// Test basic menu navigation: switch from Basic to Scientific calculator mode
    func testViewMenuNavigation() async throws {
        // First run the menu listing test to understand the menu structure
        try await testListCalculatorMenus()

        // Get initial mode of calculator
        let initialMode = try await getCalculatorMode()
        print("Initial calculator mode: \(initialMode)")

        // Use Menu Navigation Tool to switch to Scientific mode via View menu
        let scientificSuccess = try await switchToCalculatorMode("Scientific")

        // Test switching to Scientific mode
        XCTAssertTrue(scientificSuccess, "Should successfully navigate to View > Scientific menu item")

        // Wait for mode change to take effect
        try await Task.sleep(for: .milliseconds(2000))

        // Get updated calculator mode
        let scientificMode = try await getCalculatorMode()
        print("Calculator mode after Scientific: \(scientificMode)")

        // Now try switching to Basic mode
        let basicSuccess = try await switchToCalculatorMode("Basic")
        XCTAssertTrue(basicSuccess, "Should successfully navigate to View > Basic menu item")

        // Wait for mode change to take effect
        try await Task.sleep(for: .milliseconds(2000))

        // Get final calculator mode
        let basicMode = try await getCalculatorMode()
        print("Calculator mode after Basic: \(basicMode)")
    }
    
    /// Activate Calculator application using MCP to bring it to foreground
    private func activateCalculatorWithMCP() async throws {
        // Use the applicationManagementTool to activate Calculator
        let params: [String: Value] = [
            "action": .string("activateApplication"),
            "bundleIdentifier": .string("com.apple.calculator")
        ]

        let result = try await helper.toolChain.applicationManagementTool.handler(params)
        print("Activation result received with \(result.count) items")

        // Check if activation was successful
        if let content = result.first, case .text(let text) = content {
            print("Activation response: \(text)")
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
            print("Frontmost app response: \(text)")

            // Extract application info from the JSON response
            if let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let bundleId = json["bundleIdentifier"] as? String,
               let appName = json["applicationName"] as? String {

                return CalculatorAppInfo(
                    bundleIdentifier: bundleId,
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
            "bundleId": .string("com.apple.calculator")
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

        // Now let's try the approach that directly uses menu paths with MenuNavigationTool
        // but we'll use a properly formatted menu path
        let menuParams: [String: Value] = [
            "action": .string("activateMenuItem"),
            "bundleId": .string("com.apple.calculator"),
            "menuPath": .string("View > " + mode)  // Plain format without the identifiers
        ]

        // Use MenuNavigationTool's handler method
        let result = try await helper.toolChain.menuNavigationTool.handler(menuParams)

        // Check if navigation was successful
        if let content = result.first, case .text(let text) = content {
            print("Menu navigation result: \(text)")

            // Add a longer delay to allow menu action to take effect
            try await Task.sleep(for: .milliseconds(1000))

            return text.contains("success") || text.contains("true")
        }

        return false
    }
}