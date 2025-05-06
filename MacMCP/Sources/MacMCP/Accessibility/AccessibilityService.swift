// ABOUTME: This file provides the AccessibilityService for getting UI element information.
// ABOUTME: It coordinates interactions with the macOS accessibility API.

import Foundation
import AppKit
import Logging

/// Service for working with the macOS accessibility API
public actor AccessibilityService: AccessibilityServiceProtocol {
    /// The logger for accessibility operations
    private let logger: Logger
    
    /// The default maximum recursion depth for element hierarchy
    public static let defaultMaxDepth = 25
    
    /// Initialize the accessibility service
    /// - Parameter logger: Optional logger to use (creates one if not provided)
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "mcp.accessibility")
    }
    
    /// Get the system-wide UI element structure
    /// - Parameters:
    ///   - recursive: Whether to recursively get children
    ///   - maxDepth: Maximum depth for recursion
    /// - Returns: A UIElement representing the system-wide accessibility hierarchy
    public func getSystemUIElement(
        recursive: Bool = true,
        maxDepth: Int = AccessibilityService.defaultMaxDepth
    ) async throws -> UIElement {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }
        
        let systemElement = AccessibilityElement.systemWideElement()
        return try AccessibilityElement.convertToUIElement(
            systemElement,
            recursive: recursive,
            maxDepth: maxDepth
        )
    }
    
    /// Get the UI element for a specific application
    /// - Parameters:
    ///   - bundleIdentifier: The application's bundle identifier
    ///   - recursive: Whether to recursively get children
    ///   - maxDepth: Maximum depth for recursion
    /// - Returns: A UIElement representing the application's accessibility hierarchy
    public func getApplicationUIElement(
        bundleIdentifier: String,
        recursive: Bool = true,
        maxDepth: Int = AccessibilityService.defaultMaxDepth
    ) async throws -> UIElement {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }
        
        // Find the application by bundle ID
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard let app = runningApps.first else {
            logger.error("Application not running", metadata: ["bundleId": "\(bundleIdentifier)"])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Application not running: \(bundleIdentifier)"]
            )
        }
        
        // Log some useful information for debugging
        logger.info("Found application", metadata: [
            "bundleId": "\(bundleIdentifier)", 
            "pid": "\(app.processIdentifier)",
            "isFinishedLaunching": "\(app.isFinishedLaunching)",
            "isActive": "\(app.isActive)"
        ])
        
        // Small delay to ensure app is ready for accessibility
        if !app.isFinishedLaunching {
            logger.info("Waiting for application to finish launching")
            try await Task.sleep(for: .milliseconds(500))
        }
        
        // Get the application element
        let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
        
        // Try to create a UIElement representing the app
        do {
            return try AccessibilityElement.convertToUIElement(
                appElement,
                recursive: recursive,
                maxDepth: maxDepth
            )
        } catch {
            // Log detailed error but try to recover
            logger.error("Error converting application element", metadata: [
                "bundleId": "\(bundleIdentifier)",
                "error": "\(error.localizedDescription)"
            ])
            
            // Try again with a simpler approach (less recursion, fewer attributes)
            do {
                logger.info("Retrying with simplified conversion")
                return try AccessibilityElement.convertToUIElement(
                    appElement,
                    recursive: false,  // Don't try recursive conversion
                    maxDepth: 1        // Minimal depth
                )
            } catch {
                // If even the simplified approach fails, rethrow the error
                logger.error("Failed simplified conversion attempt", metadata: [
                    "error": "\(error.localizedDescription)"
                ])
                throw error
            }
        }
    }
    
    /// Get the UI element for the currently focused application
    /// - Parameters:
    ///   - recursive: Whether to recursively get children
    ///   - maxDepth: Maximum depth for recursion
    /// - Returns: A UIElement representing the focused application's accessibility hierarchy
    public func getFocusedApplicationUIElement(
        recursive: Bool = true,
        maxDepth: Int = AccessibilityService.defaultMaxDepth
    ) async throws -> UIElement {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }
        
        let systemElement = AccessibilityElement.systemWideElement()
        let attributeResult = try AccessibilityElement.getAttribute(
            systemElement,
            attribute: "AXFocusedApplication"
        )
        
        // Check if we got an AXUIElement result
        guard let focusedApp = attributeResult as? NSObject, CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
            logger.error("No focused application found")
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "No focused application found"]
            )
        }
        
        // We need to cast it to AXUIElement for the conversion
        let axElement = unsafeBitCast(focusedApp, to: AXUIElement.self)
        
        return try AccessibilityElement.convertToUIElement(
            axElement,
            recursive: recursive,
            maxDepth: maxDepth
        )
    }
    
    /// Get UI element at a specific screen position
    /// - Parameter position: The screen position to query
    /// - Returns: A UIElement at the specified position, if any
    public func getUIElementAtPosition(
        position: CGPoint,
        recursive: Bool = true,
        maxDepth: Int = AccessibilityService.defaultMaxDepth
    ) async throws -> UIElement? {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }
        
        let systemElement = AccessibilityElement.systemWideElement()
        var element: AXUIElement?
        
        // Use AXUIElementCopyElementAtPosition to get the element at the position
        let error = AXUIElementCopyElementAtPosition(systemElement, Float(position.x), Float(position.y), &element)
        
        guard error == .success, let element = element else {
            logger.warning("No element found at position", metadata: [
                "x": "\(position.x)",
                "y": "\(position.y)",
                "error": "\(error.rawValue)"
            ])
            return nil
        }
        
        return try AccessibilityElement.convertToUIElement(
            element,
            recursive: recursive,
            maxDepth: maxDepth
        )
    }
    
    /// Find UI elements matching criteria
    /// - Parameters:
    ///   - role: The accessibility role to match
    ///   - titleContains: Optional substring to match against element titles
    ///   - scope: The scope to search within (default is the system-wide element)
    /// - Returns: An array of matching UIElements
    public func findUIElements(
        role: String? = nil,
        titleContains: String? = nil,
        scope: UIElementScope = .systemWide,
        recursive: Bool = true,
        maxDepth: Int = AccessibilityService.defaultMaxDepth
    ) async throws -> [UIElement] {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }
        
        // Get the root element based on the scope
        let rootElement: AXUIElement
        switch scope {
        case .systemWide:
            rootElement = AccessibilityElement.systemWideElement()
        case .focusedApplication:
            let systemElement = AccessibilityElement.systemWideElement()
            let attributeResult = try AccessibilityElement.getAttribute(
                systemElement,
                attribute: "AXFocusedApplication"
            )
            
            // Check if we got an AXUIElement result
            guard let focusedApp = attributeResult as? NSObject, CFGetTypeID(focusedApp) == AXUIElementGetTypeID() else {
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "No focused application found"]
                )
            }
            // Use unsafeBitCast to properly convert NSObject to AXUIElement
            rootElement = unsafeBitCast(focusedApp, to: AXUIElement.self)
        case .application(let bundleIdentifier):
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Application not running: \(bundleIdentifier)"]
                )
            }
            rootElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)
        }
        
        // Convert to our UIElement model
        let uiElement = try AccessibilityElement.convertToUIElement(
            rootElement,
            recursive: recursive,
            maxDepth: maxDepth
        )
        
        // Find elements matching criteria
        return findMatchingElements(in: uiElement, role: role, titleContains: titleContains)
    }
    
    /// Recursively find elements matching criteria in a UIElement hierarchy
    private func findMatchingElements(
        in element: UIElement,
        role: String?,
        titleContains: String?
    ) -> [UIElement] {
        var results: [UIElement] = []
        
        // Check if this element matches
        var matches = true
        
        // Check role if specified
        if let role = role, element.role != role {
            matches = false
        }
        
        // Check title if specified
        if let titleContains = titleContains, 
           element.title?.localizedCaseInsensitiveContains(titleContains) != true {
            matches = false
        }
        
        // Add to results if all criteria matched
        if matches {
            results.append(element)
        }
        
        // Recursively check children
        for child in element.children {
            results.append(contentsOf: findMatchingElements(
                in: child,
                role: role,
                titleContains: titleContains
            ))
        }
        
        return results
    }
}

/// Scope for UI element search operations
public enum UIElementScope: Sendable {
    /// The entire system (all applications)
    case systemWide
    /// The currently focused application
    case focusedApplication
    /// A specific application by bundle identifier
    case application(bundleIdentifier: String)
}