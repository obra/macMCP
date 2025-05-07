// ABOUTME: A test file to validate the tool name standardization changes
// ABOUTME: This ensures all tool names are properly following the snake_case convention

import Foundation

/// A simple internal class to test tool name standardization
struct ToolNamesTest {
    /// Run a verification test on all tool names
    static func runTest() {
        print("=== Tool Names Test ===")
        
        // Print each tool name
        print("Tool names:")
        print("- Ping: \(ToolNames.ping)")
        print("- UI State: \(ToolNames.uiState)")
        print("- Screenshot: \(ToolNames.screenshot)")
        print("- UI Interaction: \(ToolNames.uiInteraction)")
        print("- Open Application: \(ToolNames.openApplication)")
        print("- Window Management: \(ToolNames.windowManagement)")
        print("- Menu Navigation: \(ToolNames.menuNavigation)")
        print("- Interactive Elements: \(ToolNames.interactiveElements)")
        print("- Element Capabilities: \(ToolNames.elementCapabilities)")
        
        // Check for consistency
        print("\nChecking consistency:")
        let allNames = [
            ToolNames.ping,
            ToolNames.uiState,
            ToolNames.screenshot,
            ToolNames.uiInteraction,
            ToolNames.openApplication,
            ToolNames.windowManagement,
            ToolNames.menuNavigation,
            ToolNames.interactiveElements,
            ToolNames.elementCapabilities
        ]
        
        // Check that all names use the same prefix
        let prefixes = Set(allNames.map { name in
            String(name.split(separator: "_").first ?? "")
        })
        print("All use same prefix: \(prefixes.count == 1 ? "✓" : "✗") (\(prefixes.joined(separator: ", ")))")
        
        // Check that all names use snake_case
        let allSnakeCase = allNames.allSatisfy { name in
            name.split(separator: "_").count > 1 && !name.contains { $0.isUppercase }
        }
        print("All use snake_case: \(allSnakeCase ? "✓" : "✗")")
        
        // Check for camelCase or other inconsistencies
        let nonSnakeCaseNames = allNames.filter { name in
            name.contains { $0.isUppercase }
        }
        if !nonSnakeCaseNames.isEmpty {
            print("Non snake_case names found:")
            for name in nonSnakeCaseNames {
                print("- \(name)")
            }
        }
    }
}