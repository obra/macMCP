// ABOUTME: This file contains tests for the enhanced WindowManagementTool functionality.
// ABOUTME: It verifies the tool's ability to get window information and perform window operations.

import XCTest
import Foundation
import MCP
import Logging
@testable import MacMCP

/// Mock of the AccessibilityService for testing WindowManagementTool
private class MockAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
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
    
    func getSystemUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        getSystemUIElementCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockSystemUIElement ?? createMockUIElement(identifier: "system", role: "AXApplication", title: "System")
    }
    
    func getApplicationUIElement(bundleIdentifier: String, recursive: Bool, maxDepth: Int) async throws -> UIElement {
        getApplicationUIElementCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockApplicationUIElement ?? createMockUIElement(identifier: bundleIdentifier, role: "AXApplication", title: bundleIdentifier)
    }
    
    func getFocusedApplicationUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
        getFocusedApplicationUIElementCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockFocusedApplicationUIElement ?? createMockUIElement(identifier: "focused", role: "AXApplication", title: "Focused Application")
    }
    
    func getUIElementAtPosition(position: CGPoint, recursive: Bool, maxDepth: Int) async throws -> UIElement? {
        getUIElementAtPositionCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockUIElementAtPosition
    }
    
    func findUIElements(role: String?, titleContains: String?, scope: UIElementScope, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
        findUIElementsCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockFoundElements
    }
    
    func findElement(identifier: String, in bundleId: String?) async throws -> UIElement? {
        findElementCalled = true
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
        
        return mockFoundElement
    }
    
    // MARK: - Window Management Methods
    
    func moveWindow(withIdentifier identifier: String, to point: CGPoint) async throws {
        moveWindowCalled = true
        moveWindowIdentifier = identifier
        moveWindowPoint = point
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func resizeWindow(withIdentifier identifier: String, to size: CGSize) async throws {
        resizeWindowCalled = true
        resizeWindowIdentifier = identifier
        resizeWindowSize = size
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func minimizeWindow(withIdentifier identifier: String) async throws {
        minimizeWindowCalled = true
        minimizeWindowIdentifier = identifier
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func maximizeWindow(withIdentifier identifier: String) async throws {
        maximizeWindowCalled = true
        maximizeWindowIdentifier = identifier
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func closeWindow(withIdentifier identifier: String) async throws {
        closeWindowCalled = true
        closeWindowIdentifier = identifier
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func activateWindow(withIdentifier identifier: String) async throws {
        activateWindowCalled = true
        activateWindowIdentifier = identifier
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func setWindowOrder(withIdentifier identifier: String, orderMode: WindowOrderMode, referenceWindowId: String?) async throws {
        setWindowOrderCalled = true
        setWindowOrderIdentifier = identifier
        setWindowOrderMode = orderMode
        setWindowOrderReferenceWindowId = referenceWindowId
        
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    func focusWindow(withIdentifier identifier: String) async throws {
        focusWindowCalled = true
        focusWindowIdentifier = identifier

        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }

    func performAction(action: String, onElement identifier: String, in bundleId: String?) async throws {
        // Add tracking properties if needed in the future

        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }

    func navigateMenu(path: String, in bundleId: String) async throws {
        // Mock implementation for menu navigation
        if shouldFailOperations {
            throw errorToThrow ?? MCPError.internalError("Mock error")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a mock UI element for testing
    private func createMockUIElement(
        identifier: String,
        role: String,
        title: String?,
        value: String? = nil,
        elementDescription: String? = nil,
        frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
        attributes: [String: Any] = [:],
        children: [UIElement] = []
    ) -> UIElement {
        return UIElement(
            identifier: identifier,
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
            actions: []
        )
    }
}

/// Tests for the enhanced WindowManagementTool
final class WindowManagementToolTests: XCTestCase {
    // Test components
    private var mockAccessibilityService: MockAccessibilityService!
    private var windowManagementTool: WindowManagementTool!
    
    override func setUp() {
        super.setUp()
        mockAccessibilityService = MockAccessibilityService()
        windowManagementTool = WindowManagementTool(
            accessibilityService: mockAccessibilityService,
            logger: Logger(label: "test.window_management")
        )
    }
    
    override func tearDown() {
        windowManagementTool = nil
        mockAccessibilityService = nil
        super.tearDown()
    }
    
    // MARK: - Test Methods for Existing Functionality
    
    /// Test getting application windows
    func testGetApplicationWindows() async throws {
        // Setup mock window
        let window1 = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        let window2 = UIElement(
            identifier: "window2",
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
            actions: []
        )
        
        // Create mock application with windows
        let app = UIElement(
            identifier: "com.test.app",
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
            attributes: [:],
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockApplicationUIElement = app
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.test.app"),
            "includeMinimized": .bool(true)
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.getApplicationUIElementCalled, "Should call getApplicationUIElement")
        
        // Parse the result JSON to verify content
        if case .text(let jsonString) = result[0] {
            // Parse the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify window count
            XCTAssertEqual(json.count, 2, "Should have 2 windows")
            
            // Verify first window
            let firstWindow = json[0]
            XCTAssertEqual(firstWindow["id"] as? String, "window1")
            XCTAssertEqual(firstWindow["title"] as? String, "Test Window 1")
            
            // Verify second window
            let secondWindow = json[1]
            XCTAssertEqual(secondWindow["id"] as? String, "window2")
            XCTAssertEqual(secondWindow["title"] as? String, "Test Window 2")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test getting active window
    func testGetActiveWindow() async throws {
        // Setup mock window
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Create mock focused application with window
        let app = UIElement(
            identifier: "com.test.app",
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
            attributes: [:],
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFocusedApplicationUIElement = app
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("getActiveWindow")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.getFocusedApplicationUIElementCalled, "Should call getFocusedApplicationUIElement")
        
        // Parse the result JSON to verify content
        if case .text(let jsonString) = result[0] {
            // Parse the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Verify window
            XCTAssertEqual(json.count, 1, "Should have 1 window")
            
            let activeWindow = json[0]
            XCTAssertEqual(activeWindow["id"] as? String, "window1")
            XCTAssertEqual(activeWindow["title"] as? String, "Active Window")
            XCTAssertEqual(activeWindow["isMain"] as? Bool, true)
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    // MARK: - Tests for New Functionality
    
    /// Test moving a window
    func testMoveWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("moveWindow"),
            "windowId": .string("window1"),
            "x": .double(200),
            "y": .double(300)
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.moveWindowCalled, "Should call moveWindow")
        XCTAssertEqual(mockAccessibilityService.moveWindowIdentifier, "window1")
        XCTAssertEqual(mockAccessibilityService.moveWindowPoint?.x, 200)
        XCTAssertEqual(mockAccessibilityService.moveWindowPoint?.y, 300)
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"moveWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test resizing a window
    func testResizeWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("resizeWindow"),
            "windowId": .string("window1"),
            "width": .double(1000),
            "height": .double(800)
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.resizeWindowCalled, "Should call resizeWindow")
        XCTAssertEqual(mockAccessibilityService.resizeWindowIdentifier, "window1")
        XCTAssertEqual(mockAccessibilityService.resizeWindowSize?.width, 1000)
        XCTAssertEqual(mockAccessibilityService.resizeWindowSize?.height, 800)
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"resizeWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test minimizing a window
    func testMinimizeWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("minimizeWindow"),
            "windowId": .string("window1")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.minimizeWindowCalled, "Should call minimizeWindow")
        XCTAssertEqual(mockAccessibilityService.minimizeWindowIdentifier, "window1")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"minimizeWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test maximizing a window
    func testMaximizeWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("maximizeWindow"),
            "windowId": .string("window1")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.maximizeWindowCalled, "Should call maximizeWindow")
        XCTAssertEqual(mockAccessibilityService.maximizeWindowIdentifier, "window1")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"maximizeWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test closing a window
    func testCloseWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("closeWindow"),
            "windowId": .string("window1")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.closeWindowCalled, "Should call closeWindow")
        XCTAssertEqual(mockAccessibilityService.closeWindowIdentifier, "window1")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"closeWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test activating a window
    func testActivateWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("activateWindow"),
            "windowId": .string("window1")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.activateWindowCalled, "Should call activateWindow")
        XCTAssertEqual(mockAccessibilityService.activateWindowIdentifier, "window1")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"activateWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test setting window order
    func testSetWindowOrder() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("setWindowOrder"),
            "windowId": .string("window1"),
            "orderMode": .string("front")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.setWindowOrderCalled, "Should call setWindowOrder")
        XCTAssertEqual(mockAccessibilityService.setWindowOrderIdentifier, "window1")
        XCTAssertEqual(mockAccessibilityService.setWindowOrderMode?.rawValue, "front")
        XCTAssertNil(mockAccessibilityService.setWindowOrderReferenceWindowId)
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"setWindowOrder\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
            XCTAssertTrue(jsonString.contains("\"orderMode\":\"front\""), "Response should include order mode")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test setting window order with reference window
    func testSetWindowOrderWithReference() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters for relative ordering
        let params: [String: Value] = [
            "action": .string("setWindowOrder"),
            "windowId": .string("window1"),
            "orderMode": .string("above"),
            "referenceWindowId": .string("window2")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.setWindowOrderCalled, "Should call setWindowOrder")
        XCTAssertEqual(mockAccessibilityService.setWindowOrderIdentifier, "window1")
        XCTAssertEqual(mockAccessibilityService.setWindowOrderMode?.rawValue, "above")
        XCTAssertEqual(mockAccessibilityService.setWindowOrderReferenceWindowId, "window2")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"setWindowOrder\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
            XCTAssertTrue(jsonString.contains("\"orderMode\":\"above\""), "Response should include order mode")
            XCTAssertTrue(jsonString.contains("\"referenceWindowId\":\"window2\""), "Response should include reference window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    /// Test focusing a window
    func testFocusWindow() async throws {
        // Setup mock element for findElement
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("focusWindow"),
            "windowId": .string("window1")
        ]
        
        // Execute the test
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        // Verify the service was called correctly
        XCTAssertTrue(mockAccessibilityService.focusWindowCalled, "Should call focusWindow")
        XCTAssertEqual(mockAccessibilityService.focusWindowIdentifier, "window1")
        
        // Verify response format
        if case .text(let jsonString) = result[0] {
            // Basic validation of JSON format
            XCTAssertTrue(jsonString.contains("\"success\":true"), "Response should indicate success")
            XCTAssertTrue(jsonString.contains("\"action\":\"focusWindow\""), "Response should include action name")
            XCTAssertTrue(jsonString.contains("\"windowId\":\"window1\""), "Response should include window ID")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    // MARK: - Error Tests
    
    /// Test error handling for failures
    func testErrorHandling() async throws {
        // Setup mock element for findElement but set failure flag
        let window = UIElement(
            identifier: "window1",
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
            actions: []
        )
        
        // Set mock data
        mockAccessibilityService.mockFoundElement = window
        mockAccessibilityService.shouldFailOperations = true
        mockAccessibilityService.errorToThrow = MCPError.internalError("Test error message")
        
        // Create parameters
        let params: [String: Value] = [
            "action": .string("moveWindow"),
            "windowId": .string("window1"),
            "x": .double(200),
            "y": .double(300)
        ]
        
        // Test that the error is propagated
        do {
            _ = try await windowManagementTool.handler(params)
            XCTFail("Should throw an error")
        } catch let error as MCPError {
            // Verify it's the correct error type
            switch error {
            case .internalError(let message):
                XCTAssertTrue(message?.contains("Test error message") ?? false, "Error message should include the original error details")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test validation errors for missing parameters
    func testValidationErrors() async throws {
        // Test missing windowId
        let params: [String: Value] = [
            "action": .string("moveWindow"),
            "x": .double(200),
            "y": .double(300)
        ]
        
        // Test that parameter validation works
        do {
            _ = try await windowManagementTool.handler(params)
            XCTFail("Should throw an error for missing windowId")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("windowId is required") ?? false, "Error should indicate missing windowId")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test invalid action
        let invalidActionParams: [String: Value] = [
            "action": .string("invalidAction"),
            "windowId": .string("window1")
        ]
        
        do {
            _ = try await windowManagementTool.handler(invalidActionParams)
            XCTFail("Should throw an error for invalid action")
        } catch let error as MCPError {
            switch error {
            case .invalidParams(let message):
                XCTAssertTrue(message?.contains("Valid action is required") ?? false, "Error should indicate invalid action")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}