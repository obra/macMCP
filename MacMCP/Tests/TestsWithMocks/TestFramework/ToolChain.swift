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
    
    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        return try await operation()
    }
    
    public func findElementByPath(path: String) async throws -> UIElement? {
        // Mock implementation - create a fake element based on the path
        let parts = path.split(separator: "/")
        if let lastPart = parts.last {
            let role = String(lastPart.split(separator: "[").first ?? "AXUnknown")
            return createMockUIElement(identifier: "path_element", role: role, title: "Path Element")
        }
        return nil
    }
    
    public func performAction(action: String, onElementWithPath elementPath: String) async throws {
        // Mock implementation - do nothing
    }
    
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
    
    // Legacy element identifier methods have been removed
    
    // Legacy element identifier methods have been removed
    
    public func moveWindow(withPath path: String, to point: CGPoint) async throws {
        // Do nothing in mock
    }
    
    public func resizeWindow(withPath path: String, to size: CGSize) async throws {
        // Do nothing in mock
    }
    
    public func minimizeWindow(withPath path: String) async throws {
        // Do nothing in mock
    }
    
    public func maximizeWindow(withPath path: String) async throws {
        // Do nothing in mock
    }
    
    public func closeWindow(withPath path: String) async throws {
        // Do nothing in mock
    }
    
    public func activateWindow(withPath path: String) async throws {
        // Do nothing in mock
    }
    
    public func setWindowOrder(withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?) async throws {
        // Do nothing in mock
    }
    
    public func focusWindow(withPath path: String) async throws {
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
    
    // Legacy element identifier methods have been removed
    
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
        let path = "ui://AXApplication[@AXRole=\"AXApplication\"]/\(role)[@identifier=\"\(identifier)\"]"
        return UIElement(
            path: path,
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