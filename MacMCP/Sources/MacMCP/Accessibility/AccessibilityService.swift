// ABOUTME: This file provides the AccessibilityService for getting UI element information.
// ABOUTME: It coordinates interactions with the macOS accessibility API.

import Foundation
import AppKit
import Logging

/// Service for working with the macOS accessibility API
public actor AccessibilityService: AccessibilityServiceProtocol {
    /// The logger for accessibility operations
    internal let logger: Logger
    
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

extension AccessibilityService {
    /// Find a UI element by identifier
    /// - Parameters:
    ///   - identifier: The element identifier to search for
    ///   - bundleId: Optional bundle ID of the app to search in
    /// - Returns: The matching UIElement if found, nil otherwise
    public func findElement(identifier: String, in bundleId: String? = nil) async throws -> UIElement? {
        print("🔍 DEBUG: AccessibilityService.findElement - Searching for element with ID: \(identifier)")
        
        // This is similar to UIInteractionService.findUIElement but with more logging
        var foundElement: UIElement? = nil
        
        // Strategy 1: Try to find in specified app if provided
        if let bundleId = bundleId {
            print("   - Searching in application with bundle ID: \(bundleId)")
            do {
                let appElement = try await getApplicationUIElement(
                    bundleIdentifier: bundleId,
                    recursive: true,
                    maxDepth: 25
                )
                
                // Look for the element with the exact ID first
                foundElement = searchForElementWithId(appElement, identifier: identifier, exact: true)
                
                if foundElement != nil {
                    print("   - Found element with exact ID match in specified app")
                } else {
                    // Try partial ID matching
                    print("   - No exact match found, trying partial ID matching in app")
                    foundElement = searchForElementWithId(appElement, identifier: identifier, exact: false)
                    
                    if foundElement != nil {
                        print("   - Found element with partial ID match in specified app")
                    }
                }
            } catch {
                print("   - Error accessing app: \(error.localizedDescription)")
            }
        }
        
        // Strategy 2: If not found in specified app or no app ID provided, check focused app
        if foundElement == nil {
            print("   - Searching in focused application")
            do {
                let focusedApp = try await getFocusedApplicationUIElement(
                    recursive: true,
                    maxDepth: 25
                )
                
                // Look for exact match first
                foundElement = searchForElementWithId(focusedApp, identifier: identifier, exact: true)
                
                if foundElement != nil {
                    print("   - Found element with exact ID match in focused app")
                } else {
                    // Try partial matching
                    print("   - No exact match found, trying partial ID matching in focused app")
                    foundElement = searchForElementWithId(focusedApp, identifier: identifier, exact: false)
                    
                    if foundElement != nil {
                        print("   - Found element with partial ID match in focused app")
                    }
                }
            } catch {
                print("   - Error accessing focused app: \(error.localizedDescription)")
            }
        }
        
        // Strategy 3: As last resort, try system-wide search
        if foundElement == nil {
            print("   - Searching system-wide (this may be slow)")
            do {
                let systemElement = try await getSystemUIElement(
                    recursive: true,
                    maxDepth: 25
                )
                
                // Look for exact match first
                foundElement = searchForElementWithId(systemElement, identifier: identifier, exact: true)
                
                if foundElement != nil {
                    print("   - Found element with exact ID match in system-wide search")
                } else {
                    // Try partial matching but limit depth to prevent too much searching
                    print("   - No exact match found, trying partial ID matching system-wide")
                    foundElement = searchForElementWithId(systemElement, identifier: identifier, exact: false, maxDepth: 10)
                    
                    if foundElement != nil {
                        print("   - Found element with partial ID match in system-wide search")
                    }
                }
            } catch {
                print("   - Error in system-wide search: \(error.localizedDescription)")
            }
        }
        
        if let element = foundElement {
            print("✅ DEBUG: AccessibilityService.findElement - Element found:")
            print("   - Role: \(element.role)")
            print("   - Identifier: \(element.identifier)")
            print("   - Frame: (\(element.frame.origin.x), \(element.frame.origin.y), \(element.frame.size.width), \(element.frame.size.height))")
        } else {
            print("❌ DEBUG: AccessibilityService.findElement - Element not found with ID: \(identifier)")
        }
        
        return foundElement
    }
    
    /// Search for an element with a specific ID in a hierarchy
    private func searchForElementWithId(_ element: UIElement, identifier: String, exact: Bool, maxDepth: Int = 25, currentDepth: Int = 0) -> UIElement? {
        // Check depth limit
        if currentDepth > maxDepth {
            return nil
        }
        
        // Check if this element matches
        if exact {
            // Exact match
            if element.identifier == identifier {
                return element
            }
        } else {
            // Partial match - check for structured IDs first
            if identifier.hasPrefix("ui:") && element.identifier.hasPrefix("ui:") {
                let idParts = identifier.split(separator: ":")
                let elementIdParts = element.identifier.split(separator: ":")
                
                if idParts.count >= 2 && elementIdParts.count >= 2 {
                    // Match by descriptive part
                    if idParts[1] == elementIdParts[1] {
                        return element
                    }
                    
                    // Match by hash part if available
                    if idParts.count > 2 && elementIdParts.count > 2 && idParts[2] == elementIdParts[2] {
                        return element
                    }
                }
            }
            
            // For button-like elements, check title and description
            if element.role == "AXButton" || element.role == "AXMenuItem" || 
               element.role == "AXCheckBox" || element.role == "AXRadioButton" {
                
                if let title = element.title, title == identifier {
                    return element
                }
                
                if let desc = element.elementDescription, desc == identifier {
                    return element
                }
            }
            
            // Check for ID contains match if the ID is substantial enough
            if element.identifier.contains(identifier) && identifier.count > 3 {
                return element
            }
        }
        
        // Search through children
        for child in element.children {
            if let found = searchForElementWithId(child, identifier: identifier, exact: exact, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }
        
        return nil
    }
}
