// ABOUTME: ApplicationWindowsResourceTests.swift
// ABOUTME: Tests for the application windows resource handler in MacMCP.

import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

@Suite(.serialized) struct ApplicationWindowsResourceTests {
  // Mock UI element for testing
  struct MockUIElement {
    let role: String
    let title: String?
    let path: String
    let isMinimized: Bool
    let isMain: Bool
    let isVisible: Bool
    let frame: CGRect
    let children: [MockUIElement]
    let attributes: [String: Any]
  }

  // Custom extension to mock the parameter extraction
  class TestableApplicationWindowsResourceHandler: ApplicationWindowsResourceHandler, @unchecked
  Sendable {
    // Using a custom implementation instead of override since we're using the default
    // implementation from ResourceHandler
    public func extractParameters(from uri: String, pattern _: String) throws -> [String: String] {
      if uri.contains("com.apple.calculator") {
        return ["bundleId": "com.apple.calculator"]
      } else if uri.contains("com.test.app") {
        return ["bundleId": "com.test.app"]
      } else {
        throw ResourceURIError.invalidURIFormat(uri)
      }
    }
  }

  // Simple mock implementation of AccessibilityServiceProtocol
  final class MockAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
    let windowElements: [MockUIElement]
    init(windowElements: [MockUIElement] = []) { self.windowElements = windowElements }
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

    func getApplicationUIElement(bundleId: String, recursive _: Bool, maxDepth _: Int) async throws
      -> UIElement
    {
      // Create a UIElement representing the application with window children
      let children = windowElements.map { mockElement in
        // We need to create UIElement with proper attributes to match what WindowDescriptor.from
        // expects
        var attributes = mockElement.attributes
        // Ensure attributes match what the WindowDescriptor.from method expects
        attributes["main"] = mockElement.isMain
        attributes["minimized"] = mockElement.isMinimized
        attributes["visible"] = mockElement.isVisible
        return UIElement(
          path: mockElement.path,
          role: mockElement.role,
          title: mockElement.title,
          value: nil,
          elementDescription: nil,
          frame: mockElement.frame,
          children: [],
          attributes: attributes,
          actions: [],
        )
      }
      return UIElement(
        path: "//AXApplication[@AXTitle='Mock Application']",
        role: "AXApplication",
        title: "Mock Application",
        value: nil,
        elementDescription: nil,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        children: children,
        attributes: ["bundleId": bundleId],
        actions: [],
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
    func findElementByPath(path _: String) async throws -> UIElement? { nil }
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

  // Error-throwing mock service for testing error cases
  final class ErrorThrowingAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
      try await operation()
    }

    func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func getApplicationUIElement(
      bundleId _: String,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement
    {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func getApplicationUIElement(processIdentifier _: pid_t, recursive _: Bool, maxDepth _: Int)
      async throws -> UIElement
    { throw AccessibilityPermissions.Error.permissionDenied }
    func getFocusedApplicationUIElement(
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws -> UIElement {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func getUIElementAtPosition(
      position _: CGPoint,
      recursive _: Bool,
      maxDepth _: Int,
    ) async throws
      -> UIElement?
    {
      throw AccessibilityPermissions.Error.permissionDenied
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
    ) async throws -> [UIElement] { throw AccessibilityPermissions.Error.permissionDenied }
    func findElementByPath(path _: String) async throws -> UIElement? {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func performAction(action _: String, onElementWithPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func moveWindow(withPath _: String, to _: CGPoint) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func resizeWindow(withPath _: String, to _: CGSize) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func minimizeWindow(withPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func maximizeWindow(withPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func closeWindow(withPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func activateWindow(withPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func setWindowOrder(
      withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?,
    )
      async throws
    { throw AccessibilityPermissions.Error.permissionDenied }
    func focusWindow(withPath _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }

    func navigateMenu(elementPath _: String, in _: String) async throws {
      throw AccessibilityPermissions.Error.permissionDenied
    }
  }

  @Test("Test handling application windows resource with no windows") func noWindows()
    async throws
  {
    // Set up mock service with no windows
    let mockService = MockAccessibilityService()
    let logger = Logger(label: "test.application.windows")
    // Create the resource handler
    let handler = TestableApplicationWindowsResourceHandler(
      accessibilityService: mockService, logger: logger,
    )
    // Create resource URI components
    let resourceURI = "macos://applications/com.apple.calculator/windows"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/com.apple.calculator/windows",
      queryParameters: [:],
    )
    // Call the handler
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Check the result content
    if case .text(let jsonString) = content {
      // Parse the JSON to verify it's an empty array
      let jsonData = jsonString.data(using: .utf8)!
      let windowsArray = try JSONDecoder().decode([WindowDescriptor].self, from: jsonData)
      #expect(windowsArray.isEmpty, "Windows array should be empty")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Check the metadata
    #expect(metadata != nil, "Metadata should be provided")
    if let metadata {
      #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
      #expect(
        metadata.additionalMetadata?["bundleId"]?.stringValue == "com.apple.calculator",
        "Bundle ID should be correct",
      )
      #expect(
        metadata.additionalMetadata?["windowCount"]?.doubleValue == 0, "Window count should be 0",
      )
    }
  }

  @Test("Test handling application windows resource with multiple windows")
  func multipleWindows() async throws {
    // Create mock window elements
    let mockWindows = [
      MockUIElement(
        role: "AXWindow",
        title: "Main Window",
        path: "//AXApplication[@AXTitle='Mock Application']/AXWindow[@AXTitle='Main Window']",
        isMinimized: false,
        isMain: true,
        isVisible: true,
        frame: CGRect(x: 100, y: 100, width: 800, height: 600),
        children: [],
        attributes: [:], // Empty attributes so they'll be set by our updated mock
      ),
      MockUIElement(
        role: "AXWindow",
        title: "Secondary Window",
        path: "//AXApplication[@AXTitle='Mock Application']/AXWindow[@AXTitle='Secondary Window']",
        isMinimized: false,
        isMain: false,
        isVisible: true,
        frame: CGRect(x: 200, y: 200, width: 400, height: 300),
        children: [],
        attributes: [:], // Empty attributes so they'll be set by our updated mock
      ),
      MockUIElement(
        role: "AXWindow",
        title: "Minimized Window",
        path: "//AXApplication[@AXTitle='Mock Application']/AXWindow[@AXTitle='Minimized Window']",
        isMinimized: true,
        isMain: false,
        isVisible: true,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        children: [],
        attributes: [:], // Empty attributes so they'll be set by our updated mock
      ),
    ]
    // Set up mock service with windows
    let mockService = MockAccessibilityService(windowElements: mockWindows)
    let logger = Logger(label: "test.application.windows")
    // Create the resource handler
    let handler = TestableApplicationWindowsResourceHandler(
      accessibilityService: mockService, logger: logger,
    )
    // Create resource URI components - explicitly include minimized windows
    let resourceURI = "macos://applications/com.test.app/windows?includeMinimized=true"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/com.test.app/windows",
      queryParameters: ["includeMinimized": "true"],
    )
    // Call the handler
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Parse the JSON to verify the windows
    if case .text(let jsonString) = content {
      let jsonData = jsonString.data(using: .utf8)!
      let windowsArray = try JSONDecoder().decode([WindowDescriptor].self, from: jsonData)
      #expect(windowsArray.count == 3, "Should return 3 windows")
      // Check the first window
      let mainWindow = windowsArray.first { $0.isMain }
      #expect(mainWindow != nil, "Should have a main window")
      if let mainWindow {
        #expect(mainWindow.title == "Main Window", "Main window title should match")
        #expect(mainWindow.isMinimized == false, "Main window should not be minimized")
      }
      // Check the minimized window
      let minimizedWindow = windowsArray.first { $0.isMinimized }
      #expect(minimizedWindow != nil, "Should have a minimized window")
      if let minimizedWindow {
        #expect(minimizedWindow.title == "Minimized Window", "Minimized window title should match")
      }
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Check the metadata
    #expect(metadata != nil, "Metadata should be provided")
    if let metadata {
      #expect(metadata.mimeType == "application/json", "MIME type should be application/json")
      #expect(
        metadata.additionalMetadata?["bundleId"]?.stringValue == "com.test.app",
        "Bundle ID should be correct",
      )
      #expect(
        metadata.additionalMetadata?["windowCount"]?.doubleValue == 3, "Window count should be 3",
      )
    }
  }

  @Test("Test handling application windows resource with filtering minimized windows")
  func filteringMinimizedWindows() async throws {
    // Create mock window elements
    let mockWindows = [
      MockUIElement(
        role: "AXWindow",
        title: "Main Window",
        path: "//AXApplication[@AXTitle='Mock Application']/AXWindow[@AXTitle='Main Window']",
        isMinimized: false,
        isMain: true,
        isVisible: true,
        frame: CGRect(x: 100, y: 100, width: 800, height: 600),
        children: [],
        attributes: ["main": true, "minimized": false, "visible": true],
      ),
      MockUIElement(
        role: "AXWindow",
        title: "Minimized Window",
        path: "//AXApplication[@AXTitle='Mock Application']/AXWindow[@AXTitle='Minimized Window']",
        isMinimized: true,
        isMain: false,
        isVisible: true,
        frame: CGRect(x: 0, y: 0, width: 800, height: 600),
        children: [],
        attributes: ["main": false, "minimized": true, "visible": true],
      ),
    ]
    // Set up mock service with windows
    let mockService = MockAccessibilityService(windowElements: mockWindows)
    let logger = Logger(label: "test.application.windows")
    // Create the resource handler
    let handler = TestableApplicationWindowsResourceHandler(
      accessibilityService: mockService, logger: logger,
    )
    // Create resource URI components with includeMinimized=false
    let resourceURI = "macos://applications/com.test.app/windows?includeMinimized=false"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/com.test.app/windows",
      queryParameters: ["includeMinimized": "false"],
    )
    // Call the handler
    let (content, metadata) = try await handler.handleRead(uri: resourceURI, components: components)
    // Check the result content
    if case .text(let jsonString) = content {
      // Parse the JSON to verify the windows
      let jsonData = jsonString.data(using: .utf8)!
      let windowsArray = try JSONDecoder().decode([WindowDescriptor].self, from: jsonData)
      #expect(windowsArray.count == 1, "Should return only 1 window (non-minimized)")
      // Check that the window is the main window
      #expect(windowsArray[0].isMain == true, "Should be the main window")
      #expect(windowsArray[0].title == "Main Window", "Should have the correct title")
    } else {
      #expect(Bool(false), "Content should be text")
    }
    // Check the metadata
    #expect(metadata != nil, "Metadata should be provided")
    if let metadata {
      #expect(
        metadata.additionalMetadata?["windowCount"]?.doubleValue == 1, "Window count should be 1",
      )
    }
  }

  @Test("Test handling application windows resource with error") func errorHandling()
    async throws
  {
    // Create an error-throwing mock service
    let errorService = ErrorThrowingAccessibilityService()
    let logger = Logger(label: "test.application.windows")
    // Create the resource handler
    let handler = TestableApplicationWindowsResourceHandler(
      accessibilityService: errorService, logger: logger,
    )
    // Create resource URI components
    let resourceURI = "macos://applications/com.test.app/windows"
    let components = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/com.test.app/windows",
      queryParameters: [:],
    )
    // Call the handler and expect it to throw
    do {
      _ = try await handler.handleRead(uri: resourceURI, components: components)
      #expect(Bool(false), "Should throw an error")
    } catch let error as MCPError {
      // Check that the error message contains "permission denied"
      #expect(
        error.localizedDescription.contains("permission denied"),
        "Should throw a permission denied error",
      )
    }
  }

  @Test("Test invalid URI params") func invalidURIParams() async throws {
    let mockService = MockAccessibilityService()
    let logger = Logger(label: "test.application.windows")
    // Create the resource handler
    let handler = TestableApplicationWindowsResourceHandler(
      accessibilityService: mockService, logger: logger,
    )
    // The URI is invalid because we don't override the extractParameters for non-test URIs
    let invalidResourceURI = "macos://applications/windows"
    let invalidComponents = ResourceURIComponents(
      scheme: "macos",
      path: "/applications/windows",
      queryParameters: [:],
    )
    // Call the handler and expect it to throw
    do {
      _ = try await handler.handleRead(uri: invalidResourceURI, components: invalidComponents)
      #expect(Bool(false), "Should throw an error for invalid URI")
    } catch _ as ResourceURIError { #expect(Bool(true), "Should throw a ResourceURIError") } catch {
      #expect(Bool(false), "Should throw a ResourceURIError specifically")
    }
  }
}
