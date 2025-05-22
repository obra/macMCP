// ABOUTME: WindowManagementToolTests.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP
import Testing

@testable import MacMCP

/// Mock of the AccessibilityService specifically for testing WindowManagementTool
private class WindowManagementMockAccessibilityService: @unchecked Sendable,
  AccessibilityServiceProtocol
{
  // MARK: - Test Control Properties

  // Mock data to return
  var mockSystemUIElement: UIElement?
  var mockApplicationUIElement: UIElement?
  var mockFocusedApplicationUIElement: UIElement?
  var mockUIElementAtPosition: UIElement?
  var mockFoundElements: [UIElement] = []
  var mockFoundElement: UIElement?

  // Tracking properties
  var getSystemUIElementCalled = false
  var getApplicationUIElementCalled = false
  var getFocusedApplicationUIElementCalled = false
  var getUIElementAtPositionCalled = false
  var findUIElementsCalled = false
  var findElementCalled = false

  // Tracking properties for window operations
  var moveWindowCalled = false
  var moveWindowIdentifier: String?
  var moveWindowPoint: CGPoint?

  var resizeWindowCalled = false
  var resizeWindowIdentifier: String?
  var resizeWindowSize: CGSize?

  var minimizeWindowCalled = false
  var minimizeWindowIdentifier: String?

  var maximizeWindowCalled = false
  var maximizeWindowIdentifier: String?

  var closeWindowCalled = false
  var closeWindowIdentifier: String?

  var activateWindowCalled = false
  var activateWindowIdentifier: String?

  var setWindowOrderCalled = false
  var setWindowOrderIdentifier: String?
  var setWindowOrderMode: WindowOrderMode?
  var setWindowOrderReferenceWindowId: String?

  var focusWindowCalled = false
  var focusWindowIdentifier: String?

  // Error control
  var shouldFailOperations = false
  var errorToThrow: MCPError?

  // MARK: - AccessibilityServiceProtocol Implementation

  func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
    try await operation()
  }

  func findElementByPath(path _: String) async throws -> UIElement? {
    findElementCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockFoundElement
  }

  func performAction(action _: String, onElementWithPath _: String) async throws {
    // Add tracking properties if needed

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
    getSystemUIElementCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockSystemUIElement ?? createMockUIElement(role: "AXApplication", title: "System")
  }

  func getApplicationUIElement(
    bundleId: String,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> UIElement {
    getApplicationUIElementCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockApplicationUIElement
      ?? createMockUIElement(role: "AXApplication", title: bundleId)
  }

  func getFocusedApplicationUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement
  {
    getFocusedApplicationUIElementCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockFocusedApplicationUIElement
      ?? createMockUIElement(
        role: "AXApplication",
        title: "Focused Application",
      )
  }

  func getUIElementAtPosition(position _: CGPoint, recursive _: Bool, maxDepth _: Int) async throws
    -> UIElement?
  {
    getUIElementAtPositionCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockUIElementAtPosition
  }

  func findUIElements(
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
    findUIElementsCalled = true

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }

    return mockFoundElements
  }

  // Legacy element identifier methods have been removed

  // MARK: - Window Management Methods

  func moveWindow(withPath path: String, to point: CGPoint) async throws {
    moveWindowCalled = true
    moveWindowIdentifier = path
    moveWindowPoint = point

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func resizeWindow(withPath path: String, to size: CGSize) async throws {
    resizeWindowCalled = true
    resizeWindowIdentifier = path
    resizeWindowSize = size

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func minimizeWindow(withPath path: String) async throws {
    minimizeWindowCalled = true
    minimizeWindowIdentifier = path

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func maximizeWindow(withPath path: String) async throws {
    maximizeWindowCalled = true
    maximizeWindowIdentifier = path

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func closeWindow(withPath path: String) async throws {
    closeWindowCalled = true
    closeWindowIdentifier = path

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func activateWindow(withPath path: String) async throws {
    activateWindowCalled = true
    activateWindowIdentifier = path

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func setWindowOrder(
    withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?
  ) async throws {
    setWindowOrderCalled = true
    setWindowOrderIdentifier = path
    setWindowOrderMode = orderMode
    setWindowOrderReferenceWindowId = referenceWindowPath

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func focusWindow(withPath path: String) async throws {
    focusWindowCalled = true
    focusWindowIdentifier = path

    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  func navigateMenu(elementPath _: String, in _: String) async throws {
    // Mock implementation for menu navigation
    if shouldFailOperations {
      throw errorToThrow ?? MCPError.internalError("Mock error")
    }
  }

  // MARK: - Helper Methods

  /// Create a mock UI element for testing
  private func createMockUIElement(
    role: String,
    title: String?,
    value: String? = nil,
    elementDescription: String? = nil,
    frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
    attributes: [String: Any] = [:],
    children: [UIElement] = [],
  ) -> UIElement {
    // Generate a path based on the element's role and title
    var path = "macos://ui/"
    path += role

    // Add title if available
    if let title, !title.isEmpty {
      path += "[@AXTitle=\"\(title)\"]"
    }

    // Add description if available
    if let description = elementDescription, !description.isEmpty {
      path += "[@AXDescription=\"\(description)\"]"
    }

    return UIElement(
      path: path,
      role: role,
      title: title,
      value: value,
      elementDescription: elementDescription,
      frame: frame,
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: children,
      attributes: attributes,
      actions: [],
    )
  }
}

/// Tests for the enhanced WindowManagementTool
@Suite(.serialized)
struct WindowManagementToolTests {
  // Test components
  private var mockAccessibilityService: WindowManagementMockAccessibilityService!
  private var windowManagementTool: WindowManagementTool!

  // Common test constants
  private let testWindowPath =
    "macos://ui/AXWindow[@AXTitle=\"Test Window\"][@AXDescription=\"Test Window\"]"
  private let secondWindowPath =
    "macos://ui/AXWindow[@AXTitle=\"Second Window\"][@AXDescription=\"Second Window\"]"

  @Test("Test getting application windows")
  mutating func testGetApplicationWindows() async throws {
    // Setup mock window
    let window1 = UIElement(
      path: "macos://ui/AXWindow[@AXTitle=\"Test Window 1\"][@AXDescription=\"Test Window 1\"]",
      role: AXAttribute.Role.window,
      title: "Test Window 1",
      value: nil,
      elementDescription: "Test Window 1",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: ["main": true, "minimized": false, "visible": true],
      actions: [],
    )

    let window2 = UIElement(
      path: "macos://ui/AXWindow[@AXTitle=\"Test Window 2\"][@AXDescription=\"Test Window 2\"]",
      role: AXAttribute.Role.window,
      title: "Test Window 2",
      value: nil,
      elementDescription: "Test Window 2",
      frame: CGRect(x: 100, y: 100, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: ["main": false, "minimized": false, "visible": true],
      actions: [],
    )

    // Create mock application with windows
    let app = UIElement(
      path: "macos://ui/AXApplication[@AXTitle=\"Test App\"][@bundleId=\"com.test.app\"]",
      role: "AXApplication",
      title: "Test App",
      value: nil,
      elementDescription: nil,
      frame: CGRect.zero,
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [window1, window2],
      attributes: ["bundleId": "com.test.app"],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockApplicationUIElement = app

    // Create parameters
    let params: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string("com.test.app"),
      "includeMinimized": .bool(true),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.getApplicationUIElementCalled, "Should call getApplicationUIElement")

    // Parse the result JSON to verify content
    if case .text(let jsonString) = result[0] {
      // Parse the JSON
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify window count
      #expect(json.count == 2, "Should have 2 windows")

      // Verify first window
      let firstWindow = json[0]
      #expect(
        firstWindow["id"] as? String == "macos://ui/AXWindow[@AXTitle=\"Test Window 1\"][@AXDescription=\"Test Window 1\"]",
        "First window should have the correct ID"
      )
      #expect(firstWindow["title"] as? String == "Test Window 1", "First window should have the correct title")

      // Verify second window
      let secondWindow = json[1]
      #expect(
        secondWindow["id"] as? String == "macos://ui/AXWindow[@AXTitle=\"Test Window 2\"][@AXDescription=\"Test Window 2\"]",
        "Second window should have the correct ID"
      )
      #expect(secondWindow["title"] as? String == "Test Window 2", "Second window should have the correct title")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test getting active window")
  mutating func testGetActiveWindow() async throws {
    // Setup mock window
    let window = UIElement(
      path: "macos://ui/AXWindow[@AXTitle=\"Active Window\"][@AXDescription=\"Active Test Window\"]",
      role: AXAttribute.Role.window,
      title: "Active Window",
      value: nil,
      elementDescription: "Active Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: ["main": true, "minimized": false, "visible": true],
      actions: [],
    )

    // Create mock focused application with window
    let app = UIElement(
      path: "macos://ui/AXApplication[@AXTitle=\"Test App\"][@bundleId=\"com.test.app\"]",
      role: "AXApplication",
      title: "Test App",
      value: nil,
      elementDescription: nil,
      frame: CGRect.zero,
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [window],
      attributes: ["bundleId": "com.test.app"],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFocusedApplicationUIElement = app

    // Create parameters
    let params: [String: Value] = [
      "action": .string("getActiveWindow")
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.getFocusedApplicationUIElementCalled, "Should call getFocusedApplicationUIElement")

    // Parse the result JSON to verify content
    if case .text(let jsonString) = result[0] {
      // Parse the JSON
      let jsonData = jsonString.data(using: .utf8)!
      let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]

      // Verify window
      #expect(json.count == 1, "Should have 1 window")

      let activeWindow = json[0]
      #expect(
        activeWindow["id"] as? String == "macos://ui/AXWindow[@AXTitle=\"Active Window\"][@AXDescription=\"Active Test Window\"]",
        "Active window should have the correct ID"
      )
      #expect(activeWindow["title"] as? String == "Active Window", "Active window should have the correct title")
      #expect(activeWindow["isMain"] as? Bool == true, "Active window should be the main window")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test moving a window")
  mutating func testMoveWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("moveWindow"),
      "windowId": .string(testWindowPath),
      "x": .double(200),
      "y": .double(300),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.moveWindowCalled, "Should call moveWindow")
    #expect(mockAccessibilityService.moveWindowIdentifier == testWindowPath, "Should use the correct window ID")
    #expect(mockAccessibilityService.moveWindowPoint?.x == 200, "Should move to the correct x coordinate")
    #expect(mockAccessibilityService.moveWindowPoint?.y == 300, "Should move to the correct y coordinate")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
      #expect(jsonString.contains("\"position\""), "Response should include position information")
      #expect(jsonString.contains("\"x\""), "Response should include x coordinate")
      #expect(jsonString.contains("\"y\""), "Response should include y coordinate")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test resizing a window")
  mutating func testResizeWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("resizeWindow"),
      "windowId": .string(testWindowPath),
      "width": .double(1000),
      "height": .double(800),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.resizeWindowCalled, "Should call resizeWindow")
    #expect(mockAccessibilityService.resizeWindowIdentifier == testWindowPath, "Should use the correct window ID")
    #expect(mockAccessibilityService.resizeWindowSize?.width == 1000, "Should resize to the correct width")
    #expect(mockAccessibilityService.resizeWindowSize?.height == 800, "Should resize to the correct height")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
      #expect(jsonString.contains("\"size\""), "Response should include size information")
      #expect(jsonString.contains("\"width\""), "Response should include width")
      #expect(jsonString.contains("\"height\""), "Response should include height")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test minimizing a window")
  mutating func testMinimizeWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("minimizeWindow"),
      "windowId": .string(testWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.minimizeWindowCalled, "Should call minimizeWindow")
    #expect(mockAccessibilityService.minimizeWindowIdentifier == testWindowPath, "Should use the correct window ID")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test maximizing a window")
  mutating func testMaximizeWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("maximizeWindow"),
      "windowId": .string(testWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.maximizeWindowCalled, "Should call maximizeWindow")
    #expect(mockAccessibilityService.maximizeWindowIdentifier == testWindowPath, "Should use the correct window ID")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test closing a window")
  mutating func testCloseWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("closeWindow"),
      "windowId": .string(testWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.closeWindowCalled, "Should call closeWindow")
    #expect(mockAccessibilityService.closeWindowIdentifier == testWindowPath, "Should use the correct window ID")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test activating a window")
  mutating func testActivateWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("activateWindow"),
      "windowId": .string(testWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.activateWindowCalled, "Should call activateWindow")
    #expect(mockAccessibilityService.activateWindowIdentifier == testWindowPath, "Should use the correct window ID")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test setting window order")
  mutating func testSetWindowOrder() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("setWindowOrder"),
      "windowId": .string(testWindowPath),
      "orderMode": .string("front"),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.setWindowOrderCalled, "Should call setWindowOrder")
    #expect(mockAccessibilityService.setWindowOrderIdentifier == testWindowPath, "Should use the correct window ID")
    #expect(mockAccessibilityService.setWindowOrderMode?.rawValue == "front", "Should use the correct order mode")
    #expect(mockAccessibilityService.setWindowOrderReferenceWindowId == nil, "Should not have a reference window")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
      #expect(jsonString.contains("\"orderMode\""), "Response should include order mode")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test setting window order with reference")
  mutating func testSetWindowOrderWithReference() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters for relative ordering
    let params: [String: Value] = [
      "action": .string("setWindowOrder"),
      "windowId": .string(testWindowPath),
      "orderMode": .string("above"),
      "referenceWindowId": .string(secondWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.setWindowOrderCalled, "Should call setWindowOrder")
    #expect(mockAccessibilityService.setWindowOrderIdentifier == testWindowPath, "Should use the correct window ID")
    #expect(mockAccessibilityService.setWindowOrderMode?.rawValue == "above", "Should use the correct order mode")
    #expect(mockAccessibilityService.setWindowOrderReferenceWindowId == secondWindowPath, "Should have the correct reference window")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
      #expect(jsonString.contains("\"orderMode\""), "Response should include order mode")
      #expect(jsonString.contains("\"referenceWindowId\""), "Response should include reference window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test focusing a window")
  mutating func testFocusWindow() async throws {
    // Setup mock element for findElement
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window

    // Create parameters
    let params: [String: Value] = [
      "action": .string("focusWindow"),
      "windowId": .string(testWindowPath),
    ]

    // Execute the test
    let result = try await windowManagementTool.handler(params)

    // Verify the result
    #expect(result.count == 1, "Should return one content item")

    // Verify the service was called correctly
    #expect(mockAccessibilityService.focusWindowCalled, "Should call focusWindow")
    #expect(mockAccessibilityService.focusWindowIdentifier == testWindowPath, "Should use the correct window ID")

    // Use simple string contains validation instead of JSON parsing
    if case .text(let jsonString) = result[0] {
      #expect(jsonString.contains("\"success\""), "Response should indicate success")
      #expect(jsonString.contains("\"action\""), "Response should include action name")
      #expect(jsonString.contains("\"windowId\""), "Response should include window ID")
    } else {
      #expect(Bool(false), "Result should be text content")
    }
  }

  @Test("Test error handling")
  mutating func testErrorHandling() async throws {
    // Setup mock element for findElement but set failure flag
    let window = UIElement(
      path: testWindowPath,
      role: AXAttribute.Role.window,
      title: "Test Window",
      value: nil,
      elementDescription: "Test Window",
      frame: CGRect(x: 0, y: 0, width: 800, height: 600),
      normalizedFrame: nil,
      viewportFrame: nil,
      frameSource: .direct,
      parent: nil,
      children: [],
      attributes: [:],
      actions: [],
    )

    setupTest()
    
    // Set mock data
    mockAccessibilityService.mockFoundElement = window
    mockAccessibilityService.shouldFailOperations = true
    mockAccessibilityService.errorToThrow = MCPError.internalError("Test error message")

    // Create parameters
    let params: [String: Value] = [
      "action": .string("moveWindow"),
      "windowId": .string(testWindowPath),
      "x": .double(200),
      "y": .double(300),
    ]

    // Test that the error is propagated
    do {
      _ = try await windowManagementTool.handler(params)
      #expect(Bool(false), "Should throw an error")
    } catch let error as MCPError {
      // Verify it's the correct error type
      switch error {
      case .internalError(let message):
        #expect(
          message?.contains("Test error message") ?? false,
          "Error message should include the original error details"
        )
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }
  }

  @Test("Test validation errors")
  mutating func testValidationErrors() async throws {
    setupTest()
    
    // Test missing windowId
    let params: [String: Value] = [
      "action": .string("moveWindow"),
      "x": .double(200),
      "y": .double(300),
    ]

    // Test that parameter validation works
    do {
      _ = try await windowManagementTool.handler(params)
      #expect(Bool(false), "Should throw an error for missing windowId")
    } catch let error as MCPError {
      switch error {
      case .invalidParams(let message):
        #expect(
          message?.contains("windowId is required") ?? false,
          "Error should indicate missing windowId"
        )
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }

    // Test invalid action
    let invalidActionParams: [String: Value] = [
      "action": .string("invalidAction"),
      "windowId": .string(testWindowPath),
    ]

    do {
      _ = try await windowManagementTool.handler(invalidActionParams)
      #expect(Bool(false), "Should throw an error for invalid action")
    } catch let error as MCPError {
      switch error {
      case .invalidParams(let message):
        #expect(
          message?.contains("Valid action is required") ?? false,
          "Error should indicate invalid action"
        )
      default:
        #expect(Bool(false), "Wrong error type: \(error)")
      }
    } catch {
      #expect(Bool(false), "Unexpected error type: \(error)")
    }
  }
  
  // MARK: - Helper Methods
  
  private mutating func setupTest() {
    mockAccessibilityService = WindowManagementMockAccessibilityService()
    windowManagementTool = WindowManagementTool(
      accessibilityService: mockAccessibilityService,
      logger: Logger(label: "test.window_management"),
    )
  }
}