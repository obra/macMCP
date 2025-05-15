// ABOUTME: This file provides a simplified ToolChain used for mocked tests.
// ABOUTME: It includes just enough functionality to test tools in isolation.

import Foundation
import Logging
import MCP
@testable import MacMCP

/// Accessibility permission status enum for mocks
public enum AccessibilityPermissionStatus: String, Codable {
    case authorized
    case denied
    case unknown
}

/// Mock of AccessibilityServiceProtocol for testing
public class MockAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
    // MARK: - Protocol Required Methods
    
    public func getSystemUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return createMockUIElement(identifier: "system", role: "AXApplication", title: "System")
    }
    
    public func getApplicationUIElement(bundleIdentifier: String, recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return createMockUIElement(identifier: "app", role: "AXApplication", title: bundleIdentifier)
    }
    
    public func getFocusedApplicationUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        return createMockUIElement(identifier: "focused", role: "AXApplication", title: "Focused App")
    }
    
    public func getUIElementAtPosition(position: CGPoint, recursive: Bool, maxDepth: Int) async throws -> UIElement? {
        return createMockUIElement(identifier: "element_at_position", role: "AXButton", title: "Element at Position")
    }
    
    public func findUIElements(role: String?, titleContains: String?, scope: UIElementScope, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
        // Return empty array for simplified mock
        return []
    }
    
    public func findElement(identifier: String, in bundleId: String?) async throws -> UIElement? {
        return createMockUIElement(identifier: identifier, role: "AXButton", title: "Mock Element")
    }
    
    public func performAction(action: String, onElement identifier: String, in bundleId: String?) async throws {
        // Do nothing in mock
    }
    
    public func moveWindow(withIdentifier identifier: String, to point: CGPoint) async throws {
        // Do nothing in mock
    }
    
    public func resizeWindow(withIdentifier identifier: String, to size: CGSize) async throws {
        // Do nothing in mock
    }
    
    public func minimizeWindow(withIdentifier identifier: String) async throws {
        // Do nothing in mock
    }
    
    public func maximizeWindow(withIdentifier identifier: String) async throws {
        // Do nothing in mock
    }
    
    public func closeWindow(withIdentifier identifier: String) async throws {
        // Do nothing in mock
    }
    
    public func activateWindow(withIdentifier identifier: String) async throws {
        // Do nothing in mock
    }
    
    public func setWindowOrder(withIdentifier identifier: String, orderMode: WindowOrderMode, referenceWindowId: String?) async throws {
        // Do nothing in mock
    }
    
    public func focusWindow(withIdentifier identifier: String) async throws {
        // Do nothing in mock
    }
    
    public func navigateMenu(path: String, in bundleId: String) async throws {
        // Do nothing in mock
    }
    
    // MARK: - Additional Methods
    
    public func getApplicationUIElement(bundleIdentifier: String, launch: Bool, recursive: Bool) async throws -> UIElement? {
        // Return nil for simplified mock
        return nil
    }
    
    public func getUIElement(elementId: String, refresh: Bool) async throws -> UIElement? {
        // Return nil for simplified mock
        return nil
    }
    
    public func getUIElementFrame(_ element: AccessibilityElement) -> CGRect {
        return .zero
    }
    
    public func performAction(_ element: AccessibilityElement, action: String) async throws -> Bool {
        return true
    }
    
    public func setAttribute(_ element: AccessibilityElement, name: String, value: Any) async throws -> Bool {
        return true
    }
    
    public func getValue(_ element: AccessibilityElement, attribute: String) -> Any? {
        return nil
    }
    
    public func getWindowList(bundleId: String) async throws -> [UIElement] {
        return []
    }
    
    public func getMenuItemsForMenu(menuElement: String, bundleId: String) async throws -> [UIElement] {
        return []
    }
    
    public func getApplicationMenus(bundleId: String) async throws -> [UIElement] {
        return []
    }
    
    public func activateMenuItem(menuPath: String, bundleId: String) async throws -> Bool {
        return true
    }
    
    public func getAccessibilityPermissionStatus() async -> AccessibilityPermissionStatus {
        return .authorized
    }
    
    // MARK: - Helper Methods
    
    private func createMockUIElement(identifier: String, role: String, title: String? = nil) -> UIElement {
        return UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: nil,
            elementDescription: nil,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            frameSource: .direct,
            attributes: ["enabled": true, "visible": true],
            actions: ["AXPress"]
        )
    }
}

/// Simplified ToolChain for unit tests with mocks
public final class ToolChain: @unchecked Sendable {
    /// Logger for the tool chain
    public let logger: Logger
    
    /// Mock AccessibilityService
    public let accessibilityService: MockAccessibilityService
    
    /// Initialize with a logger
    public init(logLabel: String = "mcp.toolchain.mock") {
        self.logger = Logger(label: logLabel)
        self.accessibilityService = MockAccessibilityService()
    }
}