# Unified macOS MCP Tools Specification

## Overview
This specification outlines the consolidation of related functionalities across different MCP tools to create more cohesive, focused tools. Specifically, it addresses:

1. Moving window-related operations from UIInteractionTool to an enhanced WindowManagementTool
2. Transforming OpenApplicationTool into a comprehensive ApplicationManagementTool
3. Creating a new ClipboardManagementTool for handling clipboard operations

## 1. Enhanced WindowManagementTool

### Purpose
Create a unified tool for all window-related operations, centralizing functionality currently spread between WindowManagementTool and UIInteractionTool.

### Current Implementation Analysis
Currently, window management is split between:
- WindowManagementTool: Focuses on listing windows and getting information
- UIInteractionTool: Handles window interaction actions like dragging, resizing

### Proposed Implementation

#### API Structure
```swift
public struct WindowManagementTool: @unchecked Sendable {
    public let name = ToolNames.windowManagement
    public let description = "Comprehensive window management for macOS applications"
    
    // Core functionality actions
    enum Action: String, Codable {
        // Existing actions
        case getApplicationWindows
        case getActiveWindow
        case getFocusedElement
        
        // New actions from UIInteractionTool
        case moveWindow
        case resizeWindow
        case minimizeWindow
        case maximizeWindow
        case closeWindow
        case activateWindow
        case setWindowOrder
        case focusWindow
    }
    
    // Implementation details...
}
```

#### New Input Schema
```swift
private func createInputSchema() -> Value {
    return .object([
        "type": .string("object"),
        "properties": .object([
            "action": .object([
                "type": .string("string"),
                "description": .string("The window management action to perform"),
                "enum": .array([
                    .string("getApplicationWindows"),
                    .string("getActiveWindow"),
                    .string("getFocusedElement"),
                    .string("moveWindow"),
                    .string("resizeWindow"),
                    .string("minimizeWindow"),
                    .string("maximizeWindow"),
                    .string("closeWindow"),
                    .string("activateWindow"),
                    .string("setWindowOrder"),
                    .string("focusWindow")
                ])
            ]),
            "bundleId": .object([
                "type": .string("string"),
                "description": .string("The bundle identifier of the application")
            ]),
            "windowId": .object([
                "type": .string("string"),
                "description": .string("Identifier of a specific window to target")
            ]),
            "includeMinimized": .object([
                "type": .string("boolean"),
                "description": .string("Whether to include minimized windows in the results"),
                "default": .bool(true)
            ]),
            "x": .object([
                "type": .string("number"),
                "description": .string("X coordinate for window positioning")
            ]),
            "y": .object([
                "type": .string("number"),
                "description": .string("Y coordinate for window positioning")
            ]),
            "width": .object([
                "type": .string("number"),
                "description": .string("Width for window resizing")
            ]),
            "height": .object([
                "type": .string("number"),
                "description": .string("Height for window resizing")
            ]),
            "orderMode": .object([
                "type": .string("string"),
                "description": .string("Window ordering mode: front, back, above, below"),
                "enum": .array([
                    .string("front"),
                    .string("back"),
                    .string("above"),
                    .string("below")
                ])
            ]),
            "referenceWindowId": .object([
                "type": .string("string"),
                "description": .string("Reference window ID for relative ordering operations")
            ])
        ]),
        "required": .array([.string("action")]),
        "additionalProperties": .bool(false)
    ])
}
```

#### New Handler Methods

```swift
private func moveWindow(params: [String: Value]) async throws -> [Tool.Content] {
    guard let windowId = params["windowId"]?.stringValue else {
        throw MCPError.invalidParams("windowId is required for moveWindow action")
    }
    
    let x: CGFloat
    let y: CGFloat
    
    if let xDouble = params["x"]?.doubleValue {
        x = CGFloat(xDouble)
    } else {
        throw MCPError.invalidParams("x coordinate is required for moveWindow action")
    }
    
    if let yDouble = params["y"]?.doubleValue {
        y = CGFloat(yDouble)
    } else {
        throw MCPError.invalidParams("y coordinate is required for moveWindow action")
    }
    
    do {
        try await accessibilityService.moveWindow(
            withIdentifier: windowId,
            to: CGPoint(x: x, y: y)
        )
        return [.text("Window moved successfully")]
    } catch {
        throw MCPError.operationFailed("Failed to move window: \(error.localizedDescription)")
    }
}

private func resizeWindow(params: [String: Value]) async throws -> [Tool.Content] {
    guard let windowId = params["windowId"]?.stringValue else {
        throw MCPError.invalidParams("windowId is required for resizeWindow action")
    }
    
    let width: CGFloat
    let height: CGFloat
    
    if let widthDouble = params["width"]?.doubleValue {
        width = CGFloat(widthDouble)
    } else {
        throw MCPError.invalidParams("width is required for resizeWindow action")
    }
    
    if let heightDouble = params["height"]?.doubleValue {
        height = CGFloat(heightDouble)
    } else {
        throw MCPError.invalidParams("height is required for resizeWindow action")
    }
    
    do {
        try await accessibilityService.resizeWindow(
            withIdentifier: windowId,
            to: CGSize(width: width, height: height)
        )
        return [.text("Window resized successfully")]
    } catch {
        throw MCPError.operationFailed("Failed to resize window: \(error.localizedDescription)")
    }
}

// Additional handler methods for other window operations...
```

#### AccessibilityService Extensions
```swift
extension AccessibilityService {
    /// Move a window to a new position
    /// - Parameters:
    ///   - identifier: Window identifier
    ///   - point: Target position
    public func moveWindow(withIdentifier identifier: String, to point: CGPoint) async throws {
        // Implementation
    }
    
    /// Resize a window
    /// - Parameters:
    ///   - identifier: Window identifier
    ///   - size: Target size
    public func resizeWindow(withIdentifier identifier: String, to size: CGSize) async throws {
        // Implementation
    }
    
    // Additional methods...
}
```

### Code Migration Steps
1. Create new handler methods in WindowManagementTool
2. Add necessary methods to AccessibilityService
3. Update UIInteractionTool to remove window-specific operations
4. Update documentation and examples

## 2. ApplicationManagementTool

### Purpose
Transform the existing OpenApplicationTool into a comprehensive ApplicationManagementTool that handles all application lifecycle operations.

### Current Implementation Analysis
Currently, OpenApplicationTool only handles launching applications, while termination and monitoring are implemented elsewhere or lacking.

### Proposed Implementation

#### API Structure
```swift
public struct ApplicationManagementTool: @unchecked Sendable {
    public let name = ToolNames.applicationManagement
    public let description = "Manage macOS applications - launch, terminate, and monitor"
    
    // Core functionality actions
    enum Action: String, Codable {
        case launch
        case terminate
        case forceTerminate
        case isRunning
        case getRunningApplications
        case activateApplication
        case hideApplication
        case unhideApplication
        case hideOtherApplications
        case getFrontmostApplication
    }
    
    // Implementation details...
}
```

#### Input Schema
```swift
private func createInputSchema() -> Value {
    return .object([
        "type": .string("object"),
        "properties": .object([
            "action": .object([
                "type": .string("string"),
                "description": .string("The application management action to perform"),
                "enum": .array([
                    .string("launch"),
                    .string("terminate"),
                    .string("forceTerminate"),
                    .string("isRunning"),
                    .string("getRunningApplications"),
                    .string("activateApplication"),
                    .string("hideApplication"),
                    .string("unhideApplication"),
                    .string("hideOtherApplications"),
                    .string("getFrontmostApplication")
                ])
            ]),
            "applicationName": .object([
                "type": .string("string"),
                "description": .string("The name of the application (e.g., 'Safari')")
            ]),
            "bundleIdentifier": .object([
                "type": .string("string"),
                "description": .string("The bundle identifier of the application (e.g., 'com.apple.Safari')")
            ]),
            "arguments": .object([
                "type": .string("array"),
                "description": .string("Optional array of command-line arguments to pass to the application"),
                "items": .object([
                    "type": .string("string")
                ])
            ]),
            "hideOthers": .object([
                "type": .string("boolean"),
                "description": .string("Whether to hide other applications when opening this one"),
                "default": .bool(false)
            ]),
            "waitForLaunch": .object([
                "type": .string("boolean"),
                "description": .string("Whether to wait for the application to fully launch"),
                "default": .bool(true)
            ]),
            "launchTimeout": .object([
                "type": .string("number"),
                "description": .string("Timeout in seconds for waiting for application launch"),
                "default": .double(30.0)
            ]),
            "terminateTimeout": .object([
                "type": .string("number"),
                "description": .string("Timeout in seconds for waiting for application termination"),
                "default": .double(10.0)
            ])
        ]),
        "required": .array([.string("action")]),
        "additionalProperties": .bool(false)
    ])
}
```

#### Handler Methods

```swift
private func launch(params: [String: Value]) async throws -> [Tool.Content] {
    // Existing launch implementation with enhancements
    
    // Extract application identifier (name or bundle ID)
    let applicationName = params["applicationName"]?.stringValue
    let bundleIdentifier = params["bundleIdentifier"]?.stringValue
    
    if applicationName == nil && bundleIdentifier == nil {
        throw MCPError.invalidParams("Either applicationName or bundleIdentifier is required")
    }
    
    // Extract optional parameters
    let arguments = params["arguments"]?.arrayValue?.compactMap { $0.stringValue } ?? []
    let hideOthers = params["hideOthers"]?.boolValue ?? false
    let waitForLaunch = params["waitForLaunch"]?.boolValue ?? true
    let launchTimeout = params["launchTimeout"]?.doubleValue ?? 30.0
    
    do {
        let result = try await applicationService.launchApplication(
            name: applicationName,
            bundleIdentifier: bundleIdentifier,
            arguments: arguments,
            hideOthers: hideOthers,
            waitForLaunch: waitForLaunch,
            timeout: launchTimeout
        )
        
        return [.text(
            """
            {
                "success": true,
                "processIdentifier": \(result.processIdentifier),
                "bundleIdentifier": "\(result.bundleIdentifier)"
            }
            """
        )]
    } catch {
        throw MCPError.operationFailed("Failed to launch application: \(error.localizedDescription)")
    }
}

private func terminate(params: [String: Value]) async throws -> [Tool.Content] {
    // Implementation for terminate handler
    
    // Extract application identifier (required: bundle ID)
    guard let bundleIdentifier = params["bundleIdentifier"]?.stringValue else {
        throw MCPError.invalidParams("bundleIdentifier is required for terminate action")
    }
    
    // Extract optional parameters
    let terminateTimeout = params["terminateTimeout"]?.doubleValue ?? 10.0
    
    do {
        let terminated = try await applicationService.terminateApplication(
            bundleIdentifier: bundleIdentifier,
            timeout: terminateTimeout
        )
        
        return [.text(
            """
            {
                "success": \(terminated)
            }
            """
        )]
    } catch {
        throw MCPError.operationFailed("Failed to terminate application: \(error.localizedDescription)")
    }
}

// Additional handler methods for other application operations...
```

#### ApplicationService Enhancements
```swift
extension ApplicationService {
    /// Result of an application launch operation
    public struct LaunchResult {
        public let success: Bool
        public let processIdentifier: Int
        public let bundleIdentifier: String
    }
    
    /// Launch an application by name or bundle identifier
    /// - Parameters:
    ///   - name: Optional application name
    ///   - bundleIdentifier: Optional bundle identifier
    ///   - arguments: Optional command-line arguments
    ///   - hideOthers: Whether to hide other applications
    ///   - waitForLaunch: Whether to wait for the application to fully launch
    ///   - timeout: Timeout for waiting for launch completion
    /// - Returns: Launch result with process information
    public func launchApplication(
        name: String?,
        bundleIdentifier: String?,
        arguments: [String] = [],
        hideOthers: Bool = false,
        waitForLaunch: Bool = true,
        timeout: TimeInterval = 30.0
    ) async throws -> LaunchResult {
        // Implementation
    }
    
    /// Terminate an application by bundle identifier
    /// - Parameters:
    ///   - bundleIdentifier: Bundle identifier of the application to terminate
    ///   - timeout: Timeout for waiting for termination completion
    /// - Returns: Whether the application was successfully terminated
    public func terminateApplication(
        bundleIdentifier: String,
        timeout: TimeInterval = 10.0
    ) async throws -> Bool {
        // Implementation
    }
    
    // Additional methods...
}
```

### ToolNames Update
```swift
public struct ToolNames {
    // Existing tools...
    
    // Renamed tool (was openApplication)
    public static let applicationManagement = "\(prefix)_application_management"
    
    // Other tools...
}
```

## 3. ClipboardManagementTool

### Purpose
Create a new tool for comprehensive clipboard management, enabling the reading and writing of various data types to the macOS clipboard.

### Proposed Implementation

#### API Structure
```swift
public struct ClipboardManagementTool: @unchecked Sendable {
    public let name = ToolNames.clipboardManagement
    public let description = "Manage macOS clipboard operations - copy, paste, and monitor clipboard content"
    
    // Core functionality actions
    enum Action: String, Codable {
        case getText
        case setText
        case getHtml
        case setHtml
        case getImage
        case setImage
        case getFilesList
        case setFiles
        case getAvailableTypes
        case clear
        case monitor
        case stopMonitoring
    }
    
    // Data types the clipboard can handle
    enum ClipboardDataType: String, Codable {
        case text
        case html
        case rtf
        case image
        case files
        case url
        case color
        case audio
        case video
    }
    
    // Implementation details...
}
```

#### Input Schema
```swift
private func createInputSchema() -> Value {
    return .object([
        "type": .string("object"),
        "properties": .object([
            "action": .object([
                "type": .string("string"),
                "description": .string("The clipboard management action to perform"),
                "enum": .array([
                    .string("getText"),
                    .string("setText"),
                    .string("getHtml"),
                    .string("setHtml"),
                    .string("getImage"),
                    .string("setImage"),
                    .string("getFilesList"),
                    .string("setFiles"),
                    .string("getAvailableTypes"),
                    .string("clear"),
                    .string("monitor"),
                    .string("stopMonitoring")
                ])
            ]),
            "text": .object([
                "type": .string("string"),
                "description": .string("Text content to set on the clipboard")
            ]),
            "html": .object([
                "type": .string("string"),
                "description": .string("HTML content to set on the clipboard")
            ]),
            "imagePath": .object([
                "type": .string("string"),
                "description": .string("Path to an image file to set on the clipboard")
            ]),
            "imageData": .object([
                "type": .string("string"),
                "description": .string("Base64-encoded image data to set on the clipboard")
            ]),
            "filePaths": .object([
                "type": .string("array"),
                "description": .string("Array of file paths to set on the clipboard"),
                "items": .object([
                    "type": .string("string")
                ])
            ]),
            "monitorDuration": .object([
                "type": .string("number"),
                "description": .string("Duration in seconds to monitor clipboard changes"),
                "default": .double(300.0)
            ]),
            "outputFormat": .object([
                "type": .string("string"),
                "description": .string("Format for data in response: text, base64, json"),
                "enum": .array([
                    .string("text"),
                    .string("base64"),
                    .string("json")
                ]),
                "default": .string("json")
            ])
        ]),
        "required": .array([.string("action")]),
        "additionalProperties": .bool(false)
    ])
}
```

#### Handler Methods

```swift
private func getText(params: [String: Value]) async throws -> [Tool.Content] {
    do {
        let clipboardService = ClipboardService(logger: logger)
        
        if let text = try clipboardService.getClipboardText() {
            return [.text(
                """
                {
                    "success": true,
                    "hasText": true,
                    "text": "\(escapeJsonString(text))"
                }
                """
            )]
        } else {
            return [.text(
                """
                {
                    "success": true,
                    "hasText": false
                }
                """
            )]
        }
    } catch {
        throw MCPError.operationFailed("Failed to get clipboard text: \(error.localizedDescription)")
    }
}

private func setText(params: [String: Value]) async throws -> [Tool.Content] {
    guard let text = params["text"]?.stringValue else {
        throw MCPError.invalidParams("text is required for setText action")
    }
    
    do {
        let clipboardService = ClipboardService(logger: logger)
        try clipboardService.setClipboardText(text)
        
        return [.text(
            """
            {
                "success": true
            }
            """
        )]
    } catch {
        throw MCPError.operationFailed("Failed to set clipboard text: \(error.localizedDescription)")
    }
}

private func getImage(params: [String: Value]) async throws -> [Tool.Content] {
    let outputFormat = params["outputFormat"]?.stringValue ?? "json"
    
    do {
        let clipboardService = ClipboardService(logger: logger)
        
        if let image = try clipboardService.getClipboardImage() {
            switch outputFormat {
            case "base64":
                if let base64String = try clipboardService.convertImageToBase64(image) {
                    return [.text(base64String)]
                } else {
                    throw MCPError.operationFailed("Failed to convert clipboard image to base64")
                }
                
            case "json":
                if let base64String = try clipboardService.convertImageToBase64(image) {
                    return [.text(
                        """
                        {
                            "success": true,
                            "hasImage": true,
                            "imageFormat": "base64",
                            "imageData": "\(base64String)"
                        }
                        """
                    )]
                } else {
                    throw MCPError.operationFailed("Failed to convert clipboard image to base64")
                }
                
            default:
                throw MCPError.invalidParams("Unsupported output format for images: \(outputFormat)")
            }
        } else {
            return [.text(
                """
                {
                    "success": true,
                    "hasImage": false
                }
                """
            )]
        }
    } catch {
        throw MCPError.operationFailed("Failed to get clipboard image: \(error.localizedDescription)")
    }
}

// Additional handler methods for other clipboard operations...
```

#### ClipboardService Implementation
```swift
/// Service for interacting with the macOS clipboard
public class ClipboardService {
    /// Logger for the clipboard service
    private let logger: Logger
    
    /// Create a new clipboard service
    /// - Parameter logger: Logger to use
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "mcp.clipboard")
    }
    
    /// Get text from the clipboard
    /// - Returns: Text content if available, nil otherwise
    public func getClipboardText() throws -> String? {
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }
    
    /// Set text on the clipboard
    /// - Parameter text: The text to place on the clipboard
    public func setClipboardText(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        if !success {
            throw NSError(
                domain: "ClipboardService",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Failed to set text on clipboard"]
            )
        }
    }
    
    /// Get an image from the clipboard
    /// - Returns: NSImage if available, nil otherwise
    public func getClipboardImage() throws -> NSImage? {
        let pasteboard = NSPasteboard.general
        
        if let data = pasteboard.data(forType: .tiff) {
            return NSImage(data: data)
        } else if let data = pasteboard.data(forType: .png) {
            return NSImage(data: data)
        }
        
        return nil
    }
    
    /// Set an image on the clipboard
    /// - Parameter image: The image to place on the clipboard
    public func setClipboardImage(_ image: NSImage) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        guard let tiffData = image.tiffRepresentation else {
            throw NSError(
                domain: "ClipboardService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get TIFF representation of image"]
            )
        }
        
        let success = pasteboard.setData(tiffData, forType: .tiff)
        
        if !success {
            throw NSError(
                domain: "ClipboardService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Failed to set image on clipboard"]
            )
        }
    }
    
    /// Get a list of file URLs from the clipboard
    /// - Returns: Array of file URLs if available, empty array otherwise
    public func getClipboardFiles() throws -> [URL] {
        let pasteboard = NSPasteboard.general
        return pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
    }
    
    /// Set file URLs on the clipboard
    /// - Parameter urls: Array of file URLs to place on the clipboard
    public func setClipboardFiles(_ urls: [URL]) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let success = pasteboard.writeObjects(urls as [NSURL])
        
        if !success {
            throw NSError(
                domain: "ClipboardService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Failed to set files on clipboard"]
            )
        }
    }
    
    /// Convert an image to base64-encoded string
    /// - Parameter image: The image to convert
    /// - Returns: Base64-encoded string or nil on failure
    public func convertImageToBase64(_ image: NSImage) throws -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData.base64EncodedString()
    }
    
    // Additional methods...
}
```

### ToolNames Update
```swift
public struct ToolNames {
    // Existing tools...
    
    // New tool
    public static let clipboardManagement = "\(prefix)_clipboard_management"
    
    // Other tools...
}
```

## Test Specifications

### 1. WindowManagementTool Tests

#### Unit Tests with Mocked Backend

```swift
final class WindowManagementToolTests: XCTestCase {
    var mockAccessibilityService: MockAccessibilityService!
    var windowManagementTool: WindowManagementTool!
    
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
    
    func testGetApplicationWindows() async throws {
        // Setup mock response
        let mockWindow1 = UIElement(
            identifier: "window1",
            role: "AXWindow",
            title: "Test Window 1",
            value: nil,
            elementDescription: "Test Window 1",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            normalizedFrame: nil,
            viewportFrame: nil,
            frameSource: .direct,
            parent: nil,
            children: [],
            attributes: [:],
            actions: []
        )
        
        let mockWindow2 = UIElement(
            identifier: "window2",
            role: "AXWindow",
            title: "Test Window 2",
            value: nil,
            elementDescription: "Test Window 2",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            normalizedFrame: nil,
            viewportFrame: nil,
            frameSource: .direct,
            parent: nil,
            children: [],
            attributes: [:],
            actions: []
        )
        
        mockAccessibilityService.applicationWindowsToReturn = [mockWindow1, mockWindow2]
        
        // Execute the test
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.test.app")
        ]
        
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            XCTAssertEqual(json.count, 2, "Should return two windows")
            
            let firstWindow = json[0]
            XCTAssertEqual(firstWindow["id"] as? String, "window1")
            XCTAssertEqual(firstWindow["title"] as? String, "Test Window 1")
            
            let secondWindow = json[1]
            XCTAssertEqual(secondWindow["id"] as? String, "window2")
            XCTAssertEqual(secondWindow["title"] as? String, "Test Window 2")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the mock was called correctly
        XCTAssertEqual(mockAccessibilityService.getApplicationWindowsCallCount, 1)
        XCTAssertEqual(mockAccessibilityService.lastBundleIdentifier, "com.test.app")
    }
    
    func testMoveWindow() async throws {
        // Setup mock response
        mockAccessibilityService.moveWindowSuccess = true
        
        // Execute the test
        let params: [String: Value] = [
            "action": .string("moveWindow"),
            "windowId": .string("window1"),
            "x": .double(200),
            "y": .double(300)
        ]
        
        let result = try await windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let text) = result[0] {
            XCTAssertTrue(text.contains("success"), "Result should indicate success")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the mock was called correctly
        XCTAssertEqual(mockAccessibilityService.moveWindowCallCount, 1)
        XCTAssertEqual(mockAccessibilityService.lastWindowIdentifier, "window1")
        XCTAssertEqual(mockAccessibilityService.lastPoint?.x, 200)
        XCTAssertEqual(mockAccessibilityService.lastPoint?.y, 300)
    }
    
    // Additional tests...
}
```

#### End-to-End Tests with Real Applications

```swift
final class WindowManagementE2ETests: XCTestCase {
    var toolChain: ToolChain!
    
    override func setUp() async throws {
        super.setUp()
        toolChain = ToolChain()
        
        // Close all instances of the test applications
        try await terminateApplication(bundleId: "com.apple.calculator")
        try await terminateApplication(bundleId: "com.apple.TextEdit")
        
        // Allow time for applications to fully close
        try await Task.sleep(for: .milliseconds(1000))
    }
    
    override func tearDown() async throws {
        // Close all test applications
        try await terminateApplication(bundleId: "com.apple.calculator")
        try await terminateApplication(bundleId: "com.apple.TextEdit")
        
        toolChain = nil
        super.tearDown()
    }
    
    private func terminateApplication(bundleId: String) async throws {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        for app in runningApps {
            _ = app.forceTerminate()
        }
    }
    
    func testGetApplicationWindows() async throws {
        // Launch Calculator
        let launchSuccess = try await toolChain.openApp(bundleId: "com.apple.calculator")
        XCTAssertTrue(launchSuccess, "Calculator should launch successfully")
        
        // Give the app time to fully launch
        try await Task.sleep(for: .milliseconds(2000))
        
        // Get application windows
        let params: [String: Value] = [
            "action": .string("getApplicationWindows"),
            "bundleId": .string("com.apple.calculator")
        ]
        
        let result = try await toolChain.windowManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            XCTAssertTrue(json.count >= 1, "Should return at least one window")
            
            let firstWindow = json[0]
            XCTAssertNotNil(firstWindow["id"], "Window should have an ID")
            XCTAssertEqual(firstWindow["role"] as? String, "AXWindow", "Window should have AXWindow role")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    // Additional tests...
}
```

### 2. ApplicationManagementTool Tests

#### Unit Tests with Mocked Backend

```swift
final class ApplicationManagementToolTests: XCTestCase {
    var mockApplicationService: MockApplicationService!
    var applicationManagementTool: ApplicationManagementTool!
    
    override func setUp() {
        super.setUp()
        mockApplicationService = MockApplicationService()
        applicationManagementTool = ApplicationManagementTool(
            applicationService: mockApplicationService,
            logger: Logger(label: "test.application_management")
        )
    }
    
    override func tearDown() {
        applicationManagementTool = nil
        mockApplicationService = nil
        super.tearDown()
    }
    
    func testLaunchByBundleIdentifier() async throws {
        // Setup mock response
        let mockLaunchResult = ApplicationService.LaunchResult(
            success: true,
            processIdentifier: 12345,
            bundleIdentifier: "com.test.app"
        )
        mockApplicationService.launchResultToReturn = mockLaunchResult
        
        // Execute the test
        let params: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string("com.test.app"),
            "arguments": .array([.string("--arg1"), .string("--arg2")]),
            "hideOthers": .bool(true)
        ]
        
        let result = try await applicationManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            XCTAssertEqual(json["success"] as? Bool, true, "Should indicate success")
            XCTAssertEqual(json["processIdentifier"] as? Int, 12345, "Should return correct process ID")
            XCTAssertEqual(json["bundleIdentifier"] as? String, "com.test.app", "Should return correct bundle ID")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the mock was called correctly
        XCTAssertEqual(mockApplicationService.launchApplicationCallCount, 1)
        XCTAssertNil(mockApplicationService.lastApplicationName)
        XCTAssertEqual(mockApplicationService.lastBundleIdentifier, "com.test.app")
        XCTAssertEqual(mockApplicationService.lastArguments, ["--arg1", "--arg2"])
        XCTAssertEqual(mockApplicationService.lastHideOthers, true)
    }
    
    // Additional tests...
}
```

#### End-to-End Tests with Real Applications

```swift
final class ApplicationManagementE2ETests: XCTestCase {
    var toolChain: ToolChain!
    
    override func setUp() {
        super.setUp()
        toolChain = ToolChain()
    }
    
    override func tearDown() async throws {
        // Clean up any test applications
        for bundleId in ["com.apple.calculator", "com.apple.TextEdit"] {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            for app in runningApps {
                _ = app.forceTerminate()
            }
        }
        
        toolChain = nil
        super.tearDown()
    }
    
    func testLaunchAndTerminate() async throws {
        // Ensure Calculator is not running at start
        let initialRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        for app in initialRunning {
            _ = app.forceTerminate()
        }
        
        try await Task.sleep(for: .milliseconds(1000))
        
        // Test launching Calculator
        let launchParams: [String: Value] = [
            "action": .string("launch"),
            "bundleIdentifier": .string("com.apple.calculator")
        ]
        
        let launchResult = try await toolChain.applicationManagementTool.handler(launchParams)
        
        // Verify launch result
        XCTAssertEqual(launchResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = launchResult[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            XCTAssertEqual(json["success"] as? Bool, true, "Should indicate success")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the app is running
        try await Task.sleep(for: .milliseconds(1000))
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        XCTAssertFalse(runningApps.isEmpty, "Calculator should be running after launch")
        
        // Test terminating Calculator
        let terminateParams: [String: Value] = [
            "action": .string("terminate"),
            "bundleIdentifier": .string("com.apple.calculator")
        ]
        
        let terminateResult = try await toolChain.applicationManagementTool.handler(terminateParams)
        
        // Verify terminate result
        XCTAssertEqual(terminateResult.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = terminateResult[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            XCTAssertEqual(json["success"] as? Bool, true, "Should indicate success")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the app is no longer running
        try await Task.sleep(for: .milliseconds(1000))
        let afterTerminateApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.calculator")
        XCTAssertTrue(afterTerminateApps.isEmpty, "Calculator should not be running after termination")
    }
    
    // Additional tests...
}
```

### 3. ClipboardManagementTool Tests

#### Unit Tests with Mocked Backend

```swift
final class ClipboardManagementToolTests: XCTestCase {
    var mockClipboardService: MockClipboardService!
    var clipboardManagementTool: ClipboardManagementTool!
    
    override func setUp() {
        super.setUp()
        mockClipboardService = MockClipboardService()
        clipboardManagementTool = ClipboardManagementTool(
            clipboardService: mockClipboardService,
            logger: Logger(label: "test.clipboard_management")
        )
    }
    
    override func tearDown() {
        clipboardManagementTool = nil
        mockClipboardService = nil
        super.tearDown()
    }
    
    func testGetText() async throws {
        // Setup mock response
        mockClipboardService.textToReturn = "Test clipboard text"
        
        // Execute the test
        let params: [String: Value] = [
            "action": .string("getText")
        ]
        
        let result = try await clipboardManagementTool.handler(params)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            XCTAssertEqual(json["success"] as? Bool, true, "Should indicate success")
            XCTAssertEqual(json["hasText"] as? Bool, true, "Should indicate text is available")
            XCTAssertEqual(json["text"] as? String, "Test clipboard text", "Should return correct text")
        } else {
            XCTFail("Result should be text content")
        }
        
        // Verify the mock was called correctly
        XCTAssertEqual(mockClipboardService.getClipboardTextCallCount, 1)
    }
    
    // Additional tests...
}
```

#### Mock Service Implementations

```swift
// Mock Accessibility Service for Window Management Tests
class MockAccessibilityService: AccessibilityServiceProtocol {
    // Mock variables to track calls
    var getApplicationWindowsCallCount = 0
    var moveWindowCallCount = 0
    var resizeWindowCallCount = 0
    
    // Last parameters received
    var lastBundleIdentifier: String?
    var lastWindowIdentifier: String?
    var lastPoint: CGPoint?
    var lastSize: CGSize?
    
    // Mock return values
    var applicationWindowsToReturn: [UIElement] = []
    var moveWindowSuccess = false
    var resizeWindowSuccess = false
    
    // Implement AccessibilityServiceProtocol methods...
}

// Mock Application Service for Application Management Tests
class MockApplicationService: ApplicationServiceProtocol {
    // Mock variables to track calls
    var launchApplicationCallCount = 0
    var terminateApplicationCallCount = 0
    
    // Last parameters received
    var lastApplicationName: String?
    var lastBundleIdentifier: String?
    var lastArguments: [String]?
    var lastHideOthers: Bool?
    var lastTimeout: TimeInterval?
    
    // Mock return values
    var launchResultToReturn: ApplicationService.LaunchResult?
    var terminateResultToReturn: Bool = false
    
    // Implement ApplicationServiceProtocol methods...
}

// Mock Clipboard Service for Clipboard Management Tests
class MockClipboardService {
    // Mock variables to track calls
    var getClipboardTextCallCount = 0
    var setClipboardTextCallCount = 0
    var getClipboardImageCallCount = 0
    var setClipboardImageCallCount = 0
    var getClipboardFilesCallCount = 0
    var setClipboardFilesCallCount = 0
    var convertImageToBase64CallCount = 0
    
    // Last parameters received
    var lastText: String?
    var lastImage: NSImage?
    var lastFileURLs: [URL]?
    
    // Mock return values
    var textToReturn: String?
    var imageToReturn: NSImage?
    var fileURLsToReturn: [URL] = []
    var base64ToReturn: String?
    var setTextSuccess = false
    var setImageSuccess = false
    var setFilesSuccess = false
    
    // Implement clipboard methods...
}
```

#### End-to-End Tests with Real Applications

```swift
final class ClipboardManagementE2ETests: XCTestCase {
    var toolChain: ToolChain!
    var clipboardManagementTool: ClipboardManagementTool!
    var previousClipboardText: String?
    
    override func setUp() async throws {
        super.setUp()
        toolChain = ToolChain()
        
        // Create a new ClipboardService and ClipboardManagementTool
        let clipboardService = ClipboardService()
        clipboardManagementTool = ClipboardManagementTool(
            clipboardService: clipboardService, 
            logger: Logger(label: "test.clipboard_management")
        )
        
        // Save current clipboard text to restore later
        previousClipboardText = try? clipboardService.getClipboardText()
    }
    
    override func tearDown() async throws {
        // Restore previous clipboard content if available
        if let text = previousClipboardText {
            let clipboardService = ClipboardService()
            try? clipboardService.setClipboardText(text)
        }
        
        clipboardManagementTool = nil
        toolChain = nil
        super.tearDown()
    }
    
    func testSetAndGetText() async throws {
        // Set text on the clipboard
        let testText = "ClipboardManagementTool E2E Test \(Date())"
        
        let setParams: [String: Value] = [
            "action": .string("setText"),
            "text": .string(testText)
        ]
        
        _ = try await clipboardManagementTool.handler(setParams)
        
        // Verify text was set by getting it back
        let getParams: [String: Value] = [
            "action": .string("getText")
        ]
        
        let result = try await clipboardManagementTool.handler(getParams)
        
        // Verify the result
        XCTAssertEqual(result.count, 1, "Should return one content item")
        
        if case .text(let jsonString) = result[0] {
            // Parse and validate the JSON
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
            
            XCTAssertEqual(json["success"] as? Bool, true, "Should indicate success")
            XCTAssertEqual(json["hasText"] as? Bool, true, "Should indicate text is available")
            XCTAssertEqual(json["text"] as? String, testText, "Should return the text we set")
        } else {
            XCTFail("Result should be text content")
        }
    }
    
    // Additional tests...
}
```

## Implementation Timeline

### Phase 1: WindowManagementTool Enhancements (2-3 weeks)
1. Week 1: Implement enhanced WindowManagementTool with new actions
2. Week 2: Write unit tests and end-to-end tests
3. Week 3: Update existing code to use the enhanced WindowManagementTool and remove window-related functionality from UIInteractionTool

### Phase 2: ApplicationManagementTool Implementation (2-3 weeks)
1. Week 1: Implement ApplicationManagementTool and enhance ApplicationService
2. Week 2: Write unit tests and end-to-end tests
3. Week 3: Update existing code to use ApplicationManagementTool and remove OpenApplicationTool

### Phase 3: ClipboardManagementTool Implementation (2-3 weeks)
1. Week 1: Implement ClipboardService and ClipboardManagementTool
2. Week 2: Write unit tests and end-to-end tests
3. Week 3: Integration and documentation

## Conclusion

This specification outlines a comprehensive approach to consolidating and enhancing the MacOS MCP tools, focusing on:

1. Moving window-related functionality from UIInteractionTool to an enhanced WindowManagementTool
2. Transforming OpenApplicationTool into a full-featured ApplicationManagementTool
3. Creating a new ClipboardManagementTool for clipboard operations

The resulting tools will provide cleaner, more focused APIs while maintaining or expanding the capabilities of the existing implementation. The extensive test suites, including both mocked unit tests and end-to-end tests with real applications, will ensure the reliability and correctness of the new tools.