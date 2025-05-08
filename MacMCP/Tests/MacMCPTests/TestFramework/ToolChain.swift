// ABOUTME: This file defines the ToolChain class that provides a unified interface to MCP tools.
// ABOUTME: It represents the primary way for tests to interact with MCP functionality.

import Foundation
import Logging
import MCP
@testable import MacMCP

/// Class that provides access to all MCP tools with a unified interface
public class ToolChain {
    // MARK: - Properties
    
    /// Logger for the tool chain
    public let logger: Logger
    
    // MARK: - Services
    
    /// Accessibility service for interacting with macOS accessibility APIs
    public let accessibilityService: AccessibilityService
    
    /// Application service for launching and managing applications
    public let applicationService: ApplicationService
    
    /// Screenshot service for taking screenshots
    public let screenshotService: ScreenshotService
    
    /// UI interaction service for interacting with UI elements
    public let interactionService: UIInteractionService
    
    // MARK: - Tools
    
    /// Tool for inspecting UI state
    public let uiStateTool: UIStateTool
    
    /// Tool for taking screenshots
    public let screenshotTool: ScreenshotTool
    
    /// Tool for interacting with UI elements
    public let uiInteractionTool: UIInteractionTool
    
    /// Tool for opening applications
    public let openApplicationTool: OpenApplicationTool
    
    /// Tool for managing windows
    public let windowManagementTool: WindowManagementTool
    
    /// Tool for navigating menus
    public let menuNavigationTool: MenuNavigationTool
    
    /// Tool for discovering interactive elements
    public let interactiveElementsDiscoveryTool: InteractiveElementsDiscoveryTool
    
    /// Tool for checking element capabilities
    public let elementCapabilitiesTool: ElementCapabilitiesTool
    
    // MARK: - Initialization
    
    /// Create a new tool chain with default services
    /// - Parameter logLabel: Label for the logger (defaults to "mcp.toolchain")
    public init(logLabel: String = "mcp.toolchain") {
        // Create logger
        self.logger = Logger(label: logLabel)
        
        // Create services
        self.accessibilityService = AccessibilityService(logger: logger)
        self.applicationService = ApplicationService(logger: logger)
        self.screenshotService = ScreenshotService(
            accessibilityService: accessibilityService,
            logger: logger
        )
        self.interactionService = UIInteractionService(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        // Create tools
        self.uiStateTool = UIStateTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        self.screenshotTool = ScreenshotTool(
            screenshotService: screenshotService,
            logger: logger
        )
        
        self.uiInteractionTool = UIInteractionTool(
            interactionService: interactionService,
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        self.openApplicationTool = OpenApplicationTool(
            applicationService: applicationService,
            logger: logger
        )
        
        self.windowManagementTool = WindowManagementTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        self.menuNavigationTool = MenuNavigationTool(
            accessibilityService: accessibilityService,
            interactionService: interactionService,
            logger: logger
        )
        
        self.interactiveElementsDiscoveryTool = InteractiveElementsDiscoveryTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
        
        self.elementCapabilitiesTool = ElementCapabilitiesTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    // MARK: - Application Operations
    
    /// Open an application by bundle identifier
    /// - Parameters:
    ///   - bundleId: Bundle identifier of the application to open
    ///   - arguments: Optional command line arguments
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: True if the application was successfully opened
    public func openApp(
        bundleId: String,
        arguments: [String]? = nil,
        hideOthers: Bool = false
    ) async throws -> Bool {
        // Create parameters for the tool
        var params: [String: Value] = [
            "bundleIdentifier": .string(bundleId)
        ]
        
        if let arguments = arguments {
            params["arguments"] = .array(arguments.map { .string($0) })
        }
        
        params["hideOthers"] = .bool(hideOthers)
        
        // Call the tool
        let result = try await openApplicationTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("opened") || text.contains("true")
        }
        
        return false
    }
    
    /// Terminate an application by bundle identifier
    /// - Parameter bundleId: Bundle identifier of the application to terminate
    /// - Returns: True if the application was successfully terminated
    public func terminateApp(bundleId: String) async throws -> Bool {
        // Use the application service directly for termination
        return try await applicationService.terminateApplication(bundleIdentifier: bundleId)
    }
    
    // MARK: - UI State Operations
    
    /// Get UI elements matching criteria
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - position: Position for position scope
    ///   - maxDepth: Maximum depth of the element hierarchy
    /// - Returns: Array of matching UI elements
    public func findElements(
        matching criteria: UIElementCriteria,
        scope: String = "system",
        bundleId: String? = nil,
        position: CGPoint? = nil,
        maxDepth: Int = 10
    ) async throws -> [UIElement] {
        // Create parameters for the tool
        var params: [String: Value] = [
            "scope": .string(scope),
            "maxDepth": .int(maxDepth)
        ]
        
        if let bundleId = bundleId {
            params["bundleId"] = .string(bundleId)
        }
        
        if let position = position {
            params["x"] = .double(Double(position.x))
            params["y"] = .double(Double(position.y))
        }
        
        // Call the UI state tool
        let result = try await uiStateTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let jsonString) = content {
            // Parse the JSON into UI elements
            let jsonData = jsonString.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as! [[String: Any]]
            
            // Create UI elements from JSON
            var elements: [UIElement] = []
            for elementJson in json {
                // This is a simplified version - in practice, we'd need more complete parsing
                let element = try parseUIElement(from: elementJson)
                elements.append(element)
            }
            
            // Filter elements by criteria
            return elements.filter { criteria.matches($0) }
        }
        
        return []
    }
    
    /// Find a single UI element matching criteria
    /// - Parameters:
    ///   - criteria: Criteria to match against UI elements
    ///   - scope: Scope of the search ("system", "application", "focused", "position")
    ///   - bundleId: Bundle identifier for application scope
    ///   - position: Position for position scope
    ///   - maxDepth: Maximum depth of the element hierarchy
    /// - Returns: Matching UI element or nil if none found
    public func findElement(
        matching criteria: UIElementCriteria,
        scope: String = "system",
        bundleId: String? = nil,
        position: CGPoint? = nil,
        maxDepth: Int = 10
    ) async throws -> UIElement? {
        let elements = try await findElements(
            matching: criteria,
            scope: scope,
            bundleId: bundleId,
            position: position,
            maxDepth: maxDepth
        )
        
        return elements.first
    }
    
    // MARK: - UI Interaction Operations
    
    /// Click on a UI element
    /// - Parameters:
    ///   - elementId: Identifier of the element to click
    ///   - bundleId: Optional bundle identifier of the application
    /// - Returns: True if the click was successful
    public func clickElement(
        elementId: String,
        bundleId: String? = nil
    ) async throws -> Bool {
        // Create parameters for the tool
        var params: [String: Value] = [
            "action": .string("click"),
            "elementId": .string(elementId)
        ]
        
        if let bundleId = bundleId {
            params["bundleId"] = .string(bundleId)
        }
        
        // Call the UI interaction tool
        let result = try await uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("clicked") || text.contains("true")
        }
        
        return false
    }
    
    /// Click at a position on the screen
    /// - Parameter position: Position to click
    /// - Returns: True if the click was successful
    public func clickAtPosition(position: CGPoint) async throws -> Bool {
        // Create parameters for the tool
        let params: [String: Value] = [
            "action": .string("click"),
            "x": .double(Double(position.x)),
            "y": .double(Double(position.y))
        ]
        
        // Call the UI interaction tool
        let result = try await uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("clicked") || text.contains("true")
        }
        
        return false
    }
    
    /// Type text into a UI element
    /// - Parameters:
    ///   - elementId: Identifier of the element to type into
    ///   - text: Text to type
    /// - Returns: True if the text was successfully typed
    public func typeText(
        elementId: String,
        text: String
    ) async throws -> Bool {
        // Create parameters for the tool
        let params: [String: Value] = [
            "action": .string("type"),
            "elementId": .string(elementId),
            "text": .string(text)
        ]
        
        // Call the UI interaction tool
        let result = try await uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("typed") || text.contains("true")
        }
        
        return false
    }
    
    /// Press a key
    /// - Parameter keyCode: Key code to press
    /// - Returns: True if the key was successfully pressed
    public func pressKey(keyCode: Int) async throws -> Bool {
        // Create parameters for the tool
        let params: [String: Value] = [
            "action": .string("press_key"),
            "keyCode": .int(keyCode)
        ]
        
        // Call the UI interaction tool
        let result = try await uiInteractionTool.handler(params)
        
        // Parse the result
        if let content = result.first, case .text(let text) = content {
            // Check for success message in the result
            return text.contains("success") || text.contains("pressed") || text.contains("true")
        }
        
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Parse a UI element from JSON
    /// - Parameter json: JSON dictionary representing a UI element
    /// - Returns: UI element
    private func parseUIElement(from json: [String: Any]) throws -> UIElement {
        // Extract required fields
        guard let identifier = json["identifier"] as? String else {
            throw NSError(
                domain: "ToolChain",
                code: 1000,
                userInfo: [NSLocalizedDescriptionKey: "Missing identifier in UI element JSON"]
            )
        }
        
        guard let role = json["role"] as? String else {
            throw NSError(
                domain: "ToolChain",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Missing role in UI element JSON"]
            )
        }
        
        // Extract optional fields
        let title = json["title"] as? String
        let value = json["value"] as? String
        let description = json["description"] as? String
        
        // Extract frame
        var frame = CGRect.zero
        if let frameDict = json["frame"] as? [String: Any],
           let x = frameDict["x"] as? CGFloat,
           let y = frameDict["y"] as? CGFloat,
           let width = frameDict["width"] as? CGFloat,
           let height = frameDict["height"] as? CGFloat {
            frame = CGRect(x: x, y: y, width: width, height: height)
        }
        
        // Extract normalized frame
        var normalizedFrame: CGRect? = nil
        if let normFrameDict = json["normalizedFrame"] as? [String: Any],
           let x = normFrameDict["x"] as? CGFloat,
           let y = normFrameDict["y"] as? CGFloat,
           let width = normFrameDict["width"] as? CGFloat,
           let height = normFrameDict["height"] as? CGFloat {
            normalizedFrame = CGRect(x: x, y: y, width: width, height: height)
        }
        
        // Extract children
        var children: [UIElement] = []
        if let childrenJson = json["children"] as? [[String: Any]] {
            for childJson in childrenJson {
                let child = try parseUIElement(from: childJson)
                children.append(child)
            }
        }
        
        // Extract attributes
        var attributes: [String: Any] = [:]
        if let attributesDict = json["attributes"] as? [String: Any] {
            attributes = attributesDict
        }
        
        // Extract actions
        var actions: [String] = []
        if let actionsArray = json["actions"] as? [String] {
            actions = actionsArray
        }
        
        // Create and return the UI element
        return UIElement(
            identifier: identifier,
            role: role,
            title: title,
            value: value,
            elementDescription: description,
            frame: frame,
            normalizedFrame: normalizedFrame,
            viewportFrame: nil, // Not included in JSON
            frameSource: .direct, // Default
            parent: nil, // Parent relationship not preserved in JSON
            children: children,
            attributes: attributes,
            actions: actions
        )
    }
}