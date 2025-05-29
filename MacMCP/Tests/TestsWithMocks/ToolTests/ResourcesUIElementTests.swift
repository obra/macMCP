// ABOUTME: ResourcesUIElementTests.swift
// ABOUTME: Tests for the UI element resource handler in MacMCP.

import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct ResourcesUIElementTests {
  // Mock UI element for testing
  struct MockUIElement {
    let role: String
    let title: String?
    let path: String
    let isEnabled: Bool
    let isVisible: Bool
    let actions: [String]
    let frame: CGRect
    let children: [MockUIElement]
    let attributes: [String: Any]
  }

  // Simple mock implementation of AccessibilityServiceProtocol
  final class MockAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
    let rootElement: UIElement
    init(
      rootElement: UIElement = UIElement(
        path: "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]",
        role: "AXApplication",
        title: "Mock Application",
        value: nil,
        elementDescription: nil,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        children: [],
        attributes: ["bundleId": "com.apple.mock"],
        actions: [],
      )
    ) { self.rootElement = rootElement }
    // Required by AccessibilityServiceProtocol
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
      try await operation()
    }

    func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
      rootElement
    }

    func getApplicationUIElement(
      bundleId _: String,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement
    {
      rootElement
    }

    func getApplicationUIElement(processIdentifier _: pid_t, recursive _: Bool, maxDepth _: Int)
      async throws -> UIElement
    { rootElement }
    func getFocusedApplicationUIElement(
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws -> UIElement {
      rootElement
    }

    func getUIElementAtPosition(
      position _: CGPoint,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement?
    {
      rootElement
    }

    func findUIElements(
      role: String?,
      title: String?,
      titleContains: String?,
      value: String?,
      valueContains: String?,
      description: String?,
      descriptionContains: String?,
      textContains: String?,
      anyFieldContains: String?,
      isInteractable: Bool?,
      isEnabled: Bool?,
      inMenus: Bool?,
      inMainContent: Bool?,
      elementTypes: [String]?,
      scope: UIElementScope,
      recursive: Bool,
      maxDepth: Int,
    ) async throws -> [UIElement] { [rootElement] }
    func findElementByPath(path _: String) async throws -> UIElement? { rootElement }
    func performAction(action _: String, onElementWithPath _: String) async throws {
      // No-op
    }

    func moveWindow(withPath _: String, to _: CGPoint) async throws {
      // No-op
    }

    func resizeWindow(withPath _: String, to _: CGSize) async throws {
      // No-op
    }

    func minimizeWindow(withPath _: String) async throws {
      // No-op
    }

    func maximizeWindow(withPath _: String) async throws {
      // No-op
    }

    func closeWindow(withPath _: String) async throws {
      // No-op
    }

    func activateWindow(withPath _: String) async throws {
      // No-op
    }

    func setWindowOrder(
      withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?,
    )
      async throws
    {
      // No-op
    }

    func focusWindow(withPath _: String) async throws {
      // No-op
    }

    func navigateMenu(elementPath _: String, in _: String) async throws {
      // No-op
    }
  }

  // Create a more complex element hierarchy for testing
  static func createTestUIElementHierarchy() -> UIElement {
    // Create a button that is interactable
    let button1 = UIElement(
      path:
      "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]/AXWindow/AXButton[@AXTitle=\"OK\"]",
      role: "AXButton",
      title: "OK",
      value: nil,
      elementDescription: "OK Button",
      frame: CGRect(x: 10, y: 10, width: 80, height: 30),
      children: [],
      attributes: ["enabled": true, "visible": true],
      actions: ["AXPress"],
    )
    // Create a text field that is interactable
    let textField = UIElement(
      path:
      "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]/AXWindow/AXTextField[@AXTitle=\"Search\"]",
      role: "AXTextField",
      title: "Search",
      value: "",
      elementDescription: "Search Field",
      frame: CGRect(x: 100, y: 10, width: 200, height: 30),
      children: [],
      attributes: ["enabled": true, "visible": true],
      actions: ["AXFocus"],
    )
    // Create a static text that is not interactable
    let staticText = UIElement(
      path:
      "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]/AXWindow/AXStaticText[@AXTitle=\"Label\"]",
      role: "AXStaticText",
      title: "Label",
      value: nil,
      elementDescription: "A label",
      frame: CGRect(x: 10, y: 50, width: 100, height: 20),
      children: [],
      attributes: ["enabled": true, "visible": true],
      actions: [],
    )
    // Create a button that is disabled
    let disabledButton = UIElement(
      path:
      "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]/AXWindow/AXButton[@AXTitle=\"Disabled\"]",
      role: "AXButton",
      title: "Disabled",
      value: nil,
      elementDescription: "Disabled Button",
      frame: CGRect(x: 10, y: 80, width: 80, height: 30),
      children: [],
      attributes: ["enabled": false, "visible": true],
      actions: ["AXPress"],
    )
    // Create a window containing all these elements
    let window = UIElement(
      path: "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]/AXWindow",
      role: "AXWindow",
      title: "Mock Window",
      value: nil,
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 400, height: 300),
      children: [button1, textField, staticText, disabledButton],
      attributes: ["main": true, "visible": true],
      actions: [],
    )
    // Create the application containing the window
    let application = UIElement(
      path: "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]",
      role: "AXApplication",
      title: "Mock Application",
      value: nil,
      elementDescription: nil,
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      children: [window],
      attributes: ["bundleId": "com.apple.mock"],
      actions: [],
    )
    return application
  }

  @Test("Test basic UI element resource") func basicUIElementResource() async throws {
    // Create the test hierarchy
    let rootElement = Self.createTestUIElementHierarchy()
    // Set up mock service with the element hierarchy
    let mockService = MockAccessibilityService(rootElement: rootElement)
    let logger = Logger(label: "test.ui.element")
    // Create the resource handler
    let handler = UIElementResourceHandler(accessibilityService: mockService, logger: logger)
    // Create resource URI components
    let resourceURI = "macos://ui/AXApplication[@bundleId=\"com.apple.mock\"]"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/ui/AXApplication[@bundleId=\"com.apple.mock\"]",
      queryParameters: [:],
    )
    // Call the handler
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Check the result content
    if case .text(let jsonString) = content {
      // Just verify we got a non-empty response with the correct application title
      #expect(!jsonString.isEmpty, "Should receive non-empty JSON")
      #expect(jsonString.contains("Mock Application"), "Response should include application title")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Check the metadata
    #expect(metadata != nil, "Metadata should be provided")
    if let metadata {
      #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
    }
  }

  @Test("Test error handling for invalid path") func errorHandlingForInvalidPath() async throws {
    // Set up mock service that will return nil for findElementByPath
    let mockedService = NilUIElementMockService()
    let logger = Logger(label: "test.ui.element")
    // Create the resource handler
    let handler = UIElementResourceHandler(accessibilityService: mockedService, logger: logger)
    // Create resource URI components with an invalid path
    let resourceURI = "macos://ui/NonExistentElement"
    let components = ResourceURIComponents(
      scheme: "macos", path: "/ui/NonExistentElement", queryParameters: [:],
    )
    // Call the handler and expect it to throw
    do {
      _ = try await handler.handleRead(uri: resourceURI, components: components)
      #expect(Bool(false), "Should throw an error for invalid path")
    } catch let error as MCPError {
      // Verify it's the right error type
      switch error {
        case .invalidParams: #expect(Bool(true), "Should throw invalidParams error")
        default: #expect(Bool(false), "Should throw invalidParams error, got \(error)")
      }
    }
  }

  // Mock service that returns nil for findElementByPath
  final class NilUIElementMockService: @unchecked Sendable, AccessibilityServiceProtocol {
    // Required by AccessibilityServiceProtocol
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
      try await operation()
    }

    func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
      throw NSError(
        domain: "com.macos.mcp.test",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Not implemented"],
      )
    }

    func getApplicationUIElement(
      bundleId _: String,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement
    {
      throw NSError(
        domain: "com.macos.mcp.test",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Not implemented"],
      )
    }

    func getApplicationUIElement(processIdentifier _: pid_t, recursive _: Bool, maxDepth _: Int)
      async throws -> UIElement
    {
      throw NSError(
        domain: "com.macos.mcp.test",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Not implemented"],
      )
    }

    func getFocusedApplicationUIElement(
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws -> UIElement {
      throw NSError(
        domain: "com.macos.mcp.test",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Not implemented"],
      )
    }

    func getUIElementAtPosition(
      position _: CGPoint,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement?
    {
      nil
    }

    func findUIElements(
      role: String?,
      title: String?,
      titleContains: String?,
      value: String?,
      valueContains: String?,
      description: String?,
      descriptionContains: String?,
      textContains: String?,
      anyFieldContains: String?,
      isInteractable: Bool?,
      isEnabled: Bool?,
      inMenus: Bool?,
      inMainContent: Bool?,
      elementTypes: [String]?,
      scope: UIElementScope,
      recursive: Bool,
      maxDepth: Int,
    ) async throws -> [UIElement] { [] }
    func findElementByPath(path _: String) async throws -> UIElement? {
      // Return nil to simulate a not found element
      nil
    }

    func performAction(action _: String, onElementWithPath _: String) async throws {
      // No-op
    }

    func moveWindow(withPath _: String, to _: CGPoint) async throws {
      // No-op
    }

    func resizeWindow(withPath _: String, to _: CGSize) async throws {
      // No-op
    }

    func minimizeWindow(withPath _: String) async throws {
      // No-op
    }

    func maximizeWindow(withPath _: String) async throws {
      // No-op
    }

    func closeWindow(withPath _: String) async throws {
      // No-op
    }

    func activateWindow(withPath _: String) async throws {
      // No-op
    }

    func setWindowOrder(
      withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?,
    )
      async throws
    {
      // No-op
    }

    func focusWindow(withPath _: String) async throws {
      // No-op
    }

    func navigateMenu(elementPath _: String, in _: String) async throws {
      // No-op
    }
  }
}
