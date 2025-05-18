// ABOUTME: ToolChain.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

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
    try await operation()
  }

  public func findElementByPath(path: String) async throws -> UIElement? {
    // Mock implementation - create a fake element based on the path
    let parts = path.split(separator: "/")
    if let lastPart = parts.last {
      let role = String(lastPart.split(separator: "[").first ?? "AXUnknown")
      return createMockUIElement(role: role, title: "Path Element")
    }
    return nil
  }

  public func performAction(action _: String, onElementWithPath _: String) async throws {
    // Mock implementation - do nothing
  }

  public func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
    createMockUIElement(role: "AXApplication", title: "System")
  }

  public func getApplicationUIElement(
    bundleIdentifier: String,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> UIElement {
    createMockUIElement(role: "AXApplication", title: bundleIdentifier)
  }

  public func getFocusedApplicationUIElement(recursive _: Bool, maxDepth _: Int) async throws
    -> UIElement
  {
    createMockUIElement(role: "AXApplication", title: "Focused App")
  }

  public func getUIElementAtPosition(
    position _: CGPoint,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> UIElement? {
    createMockUIElement(role: "AXButton", title: "Element at Position")
  }

  public func findUIElements(
    role _: String?,
    title _: String?,
    titleContains _: String?,
    value _: String?,
    valueContains _: String?,
    description _: String?,
    descriptionContains _: String?,
    scope _: UIElementScope,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> [UIElement] {
    // Return empty array for simplified mock
    []
  }

  // Legacy element identifier methods have been removed

  // Legacy element identifier methods have been removed

  public func moveWindow(withPath _: String, to _: CGPoint) async throws {
    // Do nothing in mock
  }

  public func resizeWindow(withPath _: String, to _: CGSize) async throws {
    // Do nothing in mock
  }

  public func minimizeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func maximizeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func closeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func activateWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func setWindowOrder(
    withPath _: String,
    orderMode _: WindowOrderMode,
    referenceWindowPath _: String?,
  ) async throws {
    // Do nothing in mock
  }

  public func focusWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func navigateMenu(path _: String, in _: String) async throws {
    // Do nothing in mock
  }

  // MARK: - Additional Methods

  public func getApplicationUIElement(
    bundleIdentifier _: String,
    launch _: Bool,
    recursive _: Bool,
  ) async throws -> UIElement? {
    // Return nil for simplified mock
    nil
  }

  // Legacy element identifier methods have been removed

  public func getUIElementFrame(_: AccessibilityElement) -> CGRect {
    .zero
  }

  public func performAction(_: AccessibilityElement, action _: String) async throws -> Bool {
    true
  }

  public func setAttribute(_: AccessibilityElement, name _: String, value _: Any) async throws
    -> Bool
  {
    true
  }

  public func getValue(_: AccessibilityElement, attribute _: String) -> Any? {
    nil
  }

  public func getWindowList(bundleId _: String) async throws -> [UIElement] {
    []
  }

  public func getMenuItemsForMenu(menuElement _: String, bundleId _: String) async throws
    -> [UIElement]
  {
    []
  }

  public func getApplicationMenus(bundleId _: String) async throws -> [UIElement] {
    []
  }

  public func activateMenuItem(menuPath _: String, bundleId _: String) async throws -> Bool {
    true
  }

  public func getAccessibilityPermissionStatus() async -> AccessibilityPermissionStatus {
    .authorized
  }

  // MARK: - Helper Methods

  private func createMockUIElement(role: String, title: String? = nil) -> UIElement {
    var path = "ui://AXApplication[@AXRole=\"AXApplication\"]/"

    // Construct path based on available properties
    path += role

    // Add title if available
    if let title, !title.isEmpty {
      path += "[@AXTitle=\"\(title)\"]"
    }

    return UIElement(
      path: path,
      role: role,
      title: title,
      value: nil,
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      frameSource: .direct,
      attributes: ["enabled": true, "visible": true],
      actions: ["AXPress"],
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
    logger = Logger(label: logLabel)
    accessibilityService = MockAccessibilityService()
  }
}
