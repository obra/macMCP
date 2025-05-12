// ABOUTME: This file provides the AccessibilityService for getting UI element information.
// ABOUTME: It coordinates interactions with the macOS accessibility API.

import Foundation
import AppKit
import Logging
import MCP

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

    /// Perform a specific accessibility action on an element
    /// - Parameters:
    ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
    ///   - identifier: The element identifier
    ///   - bundleId: Optional bundle ID of the application containing the element
    public func performAction(
        action: String,
        onElement identifier: String,
        in bundleId: String?
    ) async throws {
        logger.info("Performing accessibility action", metadata: [
            "action": .string(action),
            "identifier": .string(identifier),
            "bundleId": bundleId.map { .string($0) } ?? "nil"
        ])

        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            logger.error("Accessibility permissions not granted")
            throw AccessibilityPermissions.Error.permissionDenied
        }

        // Special handling for menu items with path-based identifiers
        if identifier.hasPrefix("ui:menu:") && action == "AXPress" && bundleId != nil {
            logger.info("Detected menu item by path-based identifier, using hierarchical navigation", metadata: [
                "identifier": .string(identifier),
                "menuPath": .string(identifier.replacingOccurrences(of: "ui:menu:", with: ""))
            ])

            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId!).first {
                let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)

                try await directMenuItemActivation(
                    menuIdentifier: identifier,
                    menuTitle: nil, // We'll extract from path components
                    appElement: appElement
                )

                return
            }
        }

        // Find the target element
        guard let element = try await findElement(identifier: identifier, in: bundleId) else {
            logger.error("Element not found", metadata: [
                "identifier": .string(identifier),
                "bundleId": bundleId.map { .string($0) } ?? "nil"
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.elementNotFound,
                userInfo: [NSLocalizedDescriptionKey: "Element not found: \(identifier)"]
            )
        }

        // Validate that the element has the required action
        if !element.actions.contains(action) {
            logger.error("Element does not support the requested action", metadata: [
                "identifier": .string(identifier),
                "action": .string(action),
                "availableActions": .string(element.actions.joined(separator: ", "))
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.actionNotSupported,
                userInfo: [
                    NSLocalizedDescriptionKey: "Element does not support action: \(action)",
                    "availableActions": element.actions
                ]
            )
        }

        // Get the element's position to use with AXUIElementCopyElementAtPosition if needed
        // For menu items with zero size, we need a special approach
        let elementPosition: CGPoint
        let hasZeroSize = element.frame.size.width == 0 && element.frame.size.height == 0

        // Special handling for menu items with zero-sized frames - common in macOS
        if hasZeroSize && element.role == "AXMenuItem" {
            // For zero-sized menu items, we'll use a direct approach without relying on position
            if action == "AXPress" && element.title != nil {
                logger.info("Using title-based direct activation for zero-sized menu item", metadata: [
                    "id": .string(identifier),
                    "title": .string(element.title ?? "unknown"),
                    "role": .string(element.role)
                ])

                // For AXMenuItem with zero-sized frames, we'll use direct action via raw AXUIElement
                // Instead of trying to find the element by position, which is unreliable

                // Get the app element
                if let bundleId = bundleId,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                    let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)

                    // Use direct AXPress without position-based lookup
                    // This approach is more reliable for menu items
                    try await directMenuItemActivation(
                        menuIdentifier: identifier,
                        menuTitle: element.title,
                        appElement: appElement
                    )

                    // Action performed successfully - return early
                    return
                }
            }

            // If we can't use the direct approach, fall back to the position-based approach
            elementPosition = element.frame.origin

            logger.info("Using position-based handling for zero-sized menu item", metadata: [
                "id": .string(identifier),
                "position": .string("\(elementPosition.x), \(elementPosition.y)")
            ])
        } else {
            // For normal elements, use the center point
            elementPosition = CGPoint(
                x: element.frame.origin.x + (element.frame.size.width / 2),
                y: element.frame.origin.y + (element.frame.size.height / 2)
            )
        }

        // Find the raw AXUIElement using the system element and position
        let systemElement = AccessibilityElement.systemWideElement()
        var rawElement: AXUIElement?
        let positionError = AXUIElementCopyElementAtPosition(
            systemElement,
            Float(elementPosition.x),
            Float(elementPosition.y),
            &rawElement
        )

        // Check if we successfully got the element at position
        if positionError != .success || rawElement == nil {
            // For menu items with zero size, try a few different Y positions as a last resort
            if hasZeroSize && element.role == "AXMenuItem" {
                logger.info("Trying alternative positions for zero-sized menu item", metadata: [
                    "originalPosition": .string("\(elementPosition.x), \(elementPosition.y)")
                ])

                // Try positions with slight offsets from the original Y
                let alternativeOffsets = [5.0, 10.0, 15.0, 20.0, -5.0, -10.0, -15.0, -20.0]
                for offset in alternativeOffsets {
                    let alternativePosition = CGPoint(x: elementPosition.x, y: elementPosition.y + offset)

                    let altPositionError = AXUIElementCopyElementAtPosition(
                        systemElement,
                        Float(alternativePosition.x),
                        Float(alternativePosition.y),
                        &rawElement
                    )

                    if altPositionError == .success && rawElement != nil {
                        logger.info("Found element at alternative position", metadata: [
                            "x": .string("\(alternativePosition.x)"),
                            "y": .string("\(alternativePosition.y)"),
                            "offset": .string("\(offset)")
                        ])
                        break
                    }
                }
            }

            // If still not found, log the error and continue to fallback methods
            if positionError != .success || rawElement == nil {
                logger.error("Failed to get element at position", metadata: [
                    "x": .string("\(elementPosition.x)"),
                    "y": .string("\(elementPosition.y)"),
                    "error": .string("\(positionError.rawValue)"),
                    "elementId": .string(identifier),
                    "elementRole": .string(element.role),
                    "elementTitle": .string(element.title ?? "nil"),
                    "elementFrame": .string("(\(element.frame.origin.x), \(element.frame.origin.y), \(element.frame.size.width), \(element.frame.size.height))"),
                    "frameSource": .string("\(element.frameSource)")
                ])
            }

            // Fall back to application element if we have a bundle ID
            if let bundleId = bundleId,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {

                logger.info("Falling back to application search", metadata: [
                    "bundleId": .string(bundleId)
                ])

                // Get application element
                let appElement = AccessibilityElement.applicationElement(pid: app.processIdentifier)

                // Need to recursively search the app element for a matching element ID
                // Do this by getting the app UI tree and searching for our target element
                do {
                    let appUIElement = try await getApplicationUIElement(
                        bundleIdentifier: bundleId,
                        recursive: true,
                        maxDepth: 25
                    )

                    // Search for element by ID
                    if let foundElement = searchForElementWithId(appUIElement, identifier: identifier, exact: true) {
                        // Found the element, but we need the raw AXUIElement for the accessibility action
                        // For menu items, we can try a special approach: finding and activating by title

                        if foundElement.role == "AXMenuItem" && action == "AXPress" && foundElement.title != nil {
                            logger.info("Using title-based activation for menu item", metadata: [
                                "identifier": .string(identifier),
                                "title": .string(foundElement.title ?? "unknown"),
                                "menuPath": .string(identifier.replacingOccurrences(of: "ui:menu:", with: ""))
                            ])

                            // Try to find parent menu elements to construct a path
                            var menuPathComponents: [String] = []
                            if let title = foundElement.title {
                                menuPathComponents.append(title)
                            }

                            var currentParent = foundElement.parent
                            while currentParent != nil && (currentParent!.role == "AXMenu" || currentParent!.role == "AXMenuBarItem") {
                                if let title = currentParent!.title, !title.isEmpty {
                                    menuPathComponents.insert(title, at: 0)
                                }
                                currentParent = currentParent!.parent
                            }

                            // If we constructed a path with at least two components (parent menu and item)
                            if menuPathComponents.count >= 2 {
                                let menuPath = menuPathComponents.joined(separator: " > ")
                                logger.info("Attempting menu path activation", metadata: [
                                    "menuPath": .string(menuPath)
                                ])

                                // Use our direct menu item activation method
                                try await directMenuItemActivation(
                                    menuIdentifier: identifier,
                                    menuTitle: foundElement.title,
                                    appElement: appElement,
                                    menuPath: menuPath
                                )
                            }
                        }

                        logger.error("Found element by ID but cannot get raw AXUIElement reference", metadata: [
                            "identifier": .string(identifier),
                            "role": .string(foundElement.role),
                            "title": .string(foundElement.title ?? "nil"),
                            "frame": .string("(\(foundElement.frame.origin.x), \(foundElement.frame.origin.y), \(foundElement.frame.size.width), \(foundElement.frame.size.height))"),
                            "parent": .string(foundElement.parent?.role ?? "nil"),
                            "position": .string("\(foundElement.frame.origin.x + (foundElement.frame.size.width / 2)), \(foundElement.frame.origin.y + (foundElement.frame.size.height / 2))"),
                            "frameSource": .string("\(foundElement.frameSource)")
                        ])

                        throw NSError(
                            domain: "com.macos.mcp.accessibility",
                            code: MacMCPErrorCode.actionFailed,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to get raw AXUIElement for action: \(identifier) (role: \(foundElement.role))"]
                        )
                    } else {
                        logger.error("Element not found in application", metadata: [
                            "identifier": .string(identifier),
                            "bundleId": .string(bundleId)
                        ])

                        throw NSError(
                            domain: "com.macos.mcp.accessibility",
                            code: MacMCPErrorCode.elementNotFound,
                            userInfo: [NSLocalizedDescriptionKey: "Element not found in application: \(identifier)"]
                        )
                    }
                } catch {
                    logger.error("Error searching for element in application", metadata: [
                        "error": .string(error.localizedDescription)
                    ])

                    throw NSError(
                        domain: "com.macos.mcp.accessibility",
                        code: MacMCPErrorCode.actionFailed,
                        userInfo: [NSLocalizedDescriptionKey: "Error finding element: \(error.localizedDescription)"]
                    )
                }
            } else {
                // No fallback available
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.actionFailed,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get element at position and no fallback available"]
                )
            }
        }

        // We have the raw element, now perform the action
        guard let rawElement = rawElement else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.actionFailed,
                userInfo: [NSLocalizedDescriptionKey: "Raw element unavailable for action"]
            )
        }

        do {
            // Attempt the action
            try AccessibilityElement.performAction(rawElement, action: action)
            logger.info("Successfully performed action", metadata: [
                "action": .string(action),
                "identifier": .string(identifier)
            ])
        } catch {
            logger.error("Failed to perform action", metadata: [
                "action": .string(action),
                "identifier": .string(identifier),
                "error": .string(error.localizedDescription)
            ])

            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.actionFailed,
                userInfo: [NSLocalizedDescriptionKey: "Failed to perform \(action): \(error.localizedDescription)"]
            )
        }
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
    /// Activate a menu item directly via its path
    /// - Parameters:
    ///   - menuIdentifier: The menu item identifier
    ///   - menuTitle: The menu item title
    ///   - appElement: The application's AXUIElement
    ///   - menuPath: Optional explicit path to use (default: parse from identifier)
    private func directMenuItemActivation(
        menuIdentifier: String,
        menuTitle: String?,
        appElement: AXUIElement,
        menuPath: String? = nil
    ) async throws {
        // Extract or use the path from either the provided path or the identifier
        let pathToUse: String
        if let explicitPath = menuPath {
            pathToUse = explicitPath
        } else if menuIdentifier.hasPrefix("ui:menu:") {
            pathToUse = menuIdentifier.replacingOccurrences(of: "ui:menu:", with: "")
        } else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.invalidActionParams,
                userInfo: [NSLocalizedDescriptionKey: "Cannot determine menu path for activation"]
            )
        }

        logger.info("Activating menu item using path-based navigation", metadata: [
            "path": .string(pathToUse),
            "title": .string(menuTitle ?? "unknown")
        ])

        // Split the path into components
        let pathComponents = pathToUse.components(separatedBy: " > ")

        // We need at least one component (the menu bar item) to continue
        guard pathComponents.count >= 1 else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.invalidActionParams,
                userInfo: [NSLocalizedDescriptionKey: "Invalid menu path: \(pathToUse)"]
            )
        }

        // Get the menu bar
        var menuBarRef: CFTypeRef?
        let menuBarStatus = AXUIElementCopyAttributeValue(appElement, "AXMenuBar" as CFString, &menuBarRef)

        if menuBarStatus != .success || menuBarRef == nil {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.elementNotFound,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get menu bar from application"]
            )
        }

        let menuBar = menuBarRef as! AXUIElement

        // Get the menu bar items
        var menuBarItemsRef: CFTypeRef?
        let menuBarItemsStatus = AXUIElementCopyAttributeValue(menuBar, "AXChildren" as CFString, &menuBarItemsRef)

        if menuBarItemsStatus != .success || menuBarItemsRef == nil {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.elementNotFound,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get menu bar items"]
            )
        }

        guard let menuBarItems = menuBarItemsRef as? [AXUIElement] else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.elementNotFound,
                userInfo: [NSLocalizedDescriptionKey: "Menu bar items not in expected format"]
            )
        }

        // Find the first component (menu bar item)
        var currentElement: AXUIElement?
        let firstComponent = pathComponents[0]

        // Find the top-level menu
        for menuBarItem in menuBarItems {
            var titleRef: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(menuBarItem, "AXTitle" as CFString, &titleRef)

            if titleStatus == .success, let title = titleRef as? String {
                // Match by exact title, or just "MenuBar" prefix for generic menu bar items
                if title == firstComponent || (firstComponent.hasPrefix("MenuBar") && title.count > 0) {
                    currentElement = menuBarItem
                    break
                }
            }
        }

        guard let menuBarItem = currentElement else {
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.elementNotFound,
                userInfo: [NSLocalizedDescriptionKey: "Could not find menu bar item: \(firstComponent)"]
            )
        }

        // Open the top-level menu by performing AXPress
        logger.info("Opening top-level menu", metadata: [
            "menuItem": .string(firstComponent)
        ])

        try AccessibilityElement.performAction(menuBarItem, action: "AXPress")
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay

        // Now we need to navigate through the rest of the path
        currentElement = menuBarItem

        // Process each path component after the menu bar item
        for i in 1..<pathComponents.count {
            let component = pathComponents[i]

            // Get the children of the current element
            var childrenRef: CFTypeRef?
            var childrenStatus = AXUIElementCopyAttributeValue(currentElement!, "AXChildren" as CFString, &childrenRef)

            if childrenStatus != .success || childrenRef == nil {
                // If we can't get children, check if there's an AXMenu child first
                var menuRef: CFTypeRef?
                let menuStatus = AXUIElementCopyAttributeValue(currentElement!, "AXMenu" as CFString, &menuRef)

                if menuStatus == .success && menuRef != nil {
                    // Use the menu as the current element
                    currentElement = menuRef as! AXUIElement

                    // Try to get children again
                    childrenStatus = AXUIElementCopyAttributeValue(currentElement!, "AXChildren" as CFString, &childrenRef)
                }

                if childrenStatus != .success || childrenRef == nil {
                    throw NSError(
                        domain: "com.macos.mcp.accessibility",
                        code: MacMCPErrorCode.elementNotFound,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to get children for component: \(component)"]
                    )
                }
            }

            guard let childrenArray = childrenRef as? [AXUIElement] else {
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.elementNotFound,
                    userInfo: [NSLocalizedDescriptionKey: "Children not in expected format for component: \(component)"]
                )
            }

            // Try to find the matching child element
            var found = false

            // First pass: Try exact title match
            for child in childrenArray {
                var titleRef: CFTypeRef?
                let titleStatus = AXUIElementCopyAttributeValue(child, "AXTitle" as CFString, &titleRef)

                if titleStatus == .success, let title = titleRef as? String {
                    // Match by exact title, or just "Menu" prefix for generic menu items
                    if title == component || (component.hasPrefix("Menu") && title.count > 0) {
                        currentElement = child
                        found = true

                        // If this is the last component, perform AXPress to activate it
                        if i == pathComponents.count - 1 {
                            logger.info("Activating final menu item", metadata: [
                                "component": .string(component),
                                "title": .string(title)
                            ])

                            try AccessibilityElement.performAction(child, action: "AXPress")
                            try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                        } else {
                            // If it's an intermediate component, open the submenu
                            logger.info("Opening submenu", metadata: [
                                "component": .string(component),
                                "title": .string(title)
                            ])

                            try AccessibilityElement.performAction(child, action: "AXPress")
                            try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                        }

                        break
                    }
                }
            }

            // Second pass: Try a more flexible match if exact match failed
            if !found {
                for child in childrenArray {
                    var titleRef: CFTypeRef?
                    let titleStatus = AXUIElementCopyAttributeValue(child, "AXTitle" as CFString, &titleRef)

                    if titleStatus == .success, let title = titleRef as? String {
                        // Try more flexible matching options
                        if title.lowercased() == component.lowercased() ||
                           title.contains(component) ||
                           component.contains(title) {
                            currentElement = child
                            found = true

                            // If this is the last component, perform AXPress to activate it
                            if i == pathComponents.count - 1 {
                                logger.info("Activating final menu item (flexible match)", metadata: [
                                    "component": .string(component),
                                    "matchedTitle": .string(title)
                                ])

                                try AccessibilityElement.performAction(child, action: "AXPress")
                                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                            } else {
                                // If it's an intermediate component, open the submenu
                                logger.info("Opening submenu (flexible match)", metadata: [
                                    "component": .string(component),
                                    "matchedTitle": .string(title)
                                ])

                                try AccessibilityElement.performAction(child, action: "AXPress")
                                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                            }

                            break
                        }
                    }
                }
            }

            if !found {
                // If we still couldn't find a match, log details about available items for debugging
                var availableItems: [String] = []
                for child in childrenArray {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(child, "AXTitle" as CFString, &titleRef) == .success,
                       let title = titleRef as? String {
                        availableItems.append(title)
                    }
                }

                logger.error("Could not find menu component", metadata: [
                    "component": .string(component),
                    "availableItems": .string(availableItems.joined(separator: ", "))
                ])

                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.elementNotFound,
                    userInfo: [NSLocalizedDescriptionKey: "Could not find menu component: \(component)"]
                )
            }
        }

        // If we reached this point, we successfully activated the menu item
        logger.info("Successfully activated menu item using path-based navigation", metadata: [
            "path": .string(pathToUse)
        ])
    }

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
