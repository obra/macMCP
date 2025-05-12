# MenuNavigationTool Replacement Plan

## Overview

This document outlines a comprehensive plan to completely replace the current `MenuNavigationTool` implementation, which is fundamentally flawed due to its reliance on position-based navigation. The new implementation will use a pure path-based navigation approach that works consistently across all macOS applications, with special attention to handling zero-sized menu items and complex menu hierarchies.

## Replacement Strategy

Given that the existing implementation doesn't work reliably, we will:

1. **Complete Removal**: Remove the entire current implementation rather than trying to salvage parts of it
2. **Fresh Start**: Create new files for the core navigation service to maintain clean separation
3. **Safe Transition**: Build and test the new implementation thoroughly before integrating it

### Current Working Copy Handling

Before starting this major refactoring:

1. Commit any working changes that aren't related to menu navigation
2. Create a new branch specifically for the menu navigation refactoring (`menu-navigation-refactor`)
3. This ensures current work isn't lost and provides a clean separation for review

## Current Issues to Address

1. **Position-based Navigation Failures**:
   - Current implementation relies on `AXUIElementCopyElementAtPosition` which fails for zero-sized menu items
   - Error code -25200 occurs frequently during menu navigation

2. **Unreliable Menu Traversal**:
   - Problems with traversing menu hierarchies with multiple levels
   - Issues with menu item identification across different applications
   - Inconsistent handling of menu state (open/closed)

3. **Code Complexity and Special Cases**:
   - Current implementation has many special cases and workarounds
   - Lack of a consistent, unified approach to menu navigation
   - Poor separation of concerns between menu discovery and interaction

## Implementation Plan

## Path-Based Identifier Specification

Before implementing the new solution, we need to clearly define how menu paths will be identified and resolved.

### Menu Path Formats

1. **User-Facing Format**:
   - Simple human-readable paths: `"File > Open"`
   - Used in all public APIs and tool interfaces
   - Case-sensitive by default, but with flexible matching options

2. **Internal Identifier Format**:
   - Structured identifiers: `"ui:menu:MenuBar > File > MenuItem > Open"`
   - Used for internal element tracking and stable identification
   - Can include component type indicators for disambiguation

3. **Mapping Between Formats**:
   - Clear conversion between user paths and internal identifiers
   - Consistent handling of special characters and whitespace
   - Predictable generation of identifiers from menu hierarchy

### Path Resolution Strategy

1. **Component Matching Levels**:
   - **Level 1**: Exact matching (case-sensitive, exact whitespace)
   - **Level 2**: Normalized matching (case-insensitive, trimmed whitespace)
   - **Level 3**: Partial matching (substring, most significant parts)
   - **Level 4**: Role-based fallback (for items without clear titles)

2. **Path Traversal Logic**:
   - Start with menu bar (always accessible via AXMenuBar role)
   - For each path component, find the corresponding menu item
   - Activate each menu item in sequence to reveal next level
   - Support any depth of nested menus

3. **Identifier Stability Considerations**:
   - Some menu identifiers may change between application launches
   - Generate identifiers that remain stable across sessions
   - Handle dynamic menu items that may appear/disappear

### Phase 1: Core Architecture Redesign

#### 1.1. Create a Dedicated Menu Navigation Service

```swift
/// Service dedicated to menu navigation operations
public actor MenuNavigationService: MenuNavigationServiceProtocol {
    private let accessibilityService: any AccessibilityServiceProtocol
    private let logger: Logger
    
    // Initialize with dependencies
    public init(accessibilityService: any AccessibilityServiceProtocol, logger: Logger? = nil) {
        self.accessibilityService = accessibilityService
        self.logger = logger ?? Logger(label: "mcp.menu_navigation")
    }
    
    // Primary API methods will be implemented here
}
```

#### 1.2. Define Clear Protocol Contract

```swift
/// Protocol defining menu navigation operations
public protocol MenuNavigationServiceProtocol: Actor {
    /// Get all top-level menus for an application
    func getApplicationMenus(bundleIdentifier: String) async throws -> [MenuDescriptor]
    
    /// Get menu items for a specific menu
    func getMenuItems(
        bundleIdentifier: String, 
        menuTitle: String,
        includeSubmenus: Bool
    ) async throws -> [MenuItemDescriptor]
    
    /// Activate a menu item by path
    func activateMenuItem(
        bundleIdentifier: String,
        menuPath: String
    ) async throws -> Bool
}
```

#### 1.3. Create Dedicated Menu Data Models

```swift
/// Descriptor for a menu
public struct MenuDescriptor: Codable, Sendable {
    public let id: String
    public let title: String
    public let isEnabled: Bool
    public let isSelected: Bool
    public let hasSubmenu: Bool
}

/// Descriptor for a menu item
public struct MenuItemDescriptor: Codable, Sendable {
    public let id: String
    public let title: String
    public let name: String
    public let isEnabled: Bool
    public let isSelected: Bool
    public let hasSubmenu: Bool
    public let children: [MenuItemDescriptor]?
}
```

### Phase 2: Hierarchical Menu Traversal Implementation

#### 2.1. Menu Bar and Menu Discovery

```swift
/// Get the menu bar for an application
private func getMenuBar(appElement: AXUIElement) async throws -> AXUIElement {
    var menuBarRef: CFTypeRef?
    let menuBarStatus = AXUIElementCopyAttributeValue(appElement, "AXMenuBar" as CFString, &menuBarRef)
    
    if menuBarStatus != .success || menuBarRef == nil {
        // Log detailed error
        throw MenuNavigationError.menuBarNotFound
    }
    
    return menuBarRef as! AXUIElement
}

/// Get all menu bar items
private func getMenuBarItems(menuBar: AXUIElement) async throws -> [AXUIElement] {
    var menuBarItemsRef: CFTypeRef?
    let menuBarItemsStatus = AXUIElementCopyAttributeValue(menuBar, "AXChildren" as CFString, &menuBarItemsRef)
    
    if menuBarItemsStatus != .success || menuBarItemsRef == nil {
        // Log detailed error
        throw MenuNavigationError.menuItemsNotFound
    }
    
    guard let menuBarItems = menuBarItemsRef as? [AXUIElement] else {
        throw MenuNavigationError.invalidMenuItemFormat
    }
    
    return menuBarItems
}
```

#### 2.2. Implement Pure Path-based Menu Navigation

```swift
/// Activate a menu item by path
public func activateMenuItem(
    bundleIdentifier: String,
    menuPath: String
) async throws -> Bool {
    // 1. Get the application element
    let appElement = try await accessibilityService.getApplicationUIElement(
        bundleIdentifier: bundleIdentifier,
        recursive: false
    )
    
    // 2. Parse the menu path
    let pathComponents = menuPath.components(separatedBy: " > ")
    guard !pathComponents.isEmpty else {
        throw MenuNavigationError.invalidMenuPath(menuPath)
    }
    
    // 3. Navigate through the menu hierarchy
    return try await navigateMenuPath(
        appElement: appElement,
        pathComponents: pathComponents
    )
}

/// Navigate through a menu path
private func navigateMenuPath(
    appElement: AXUIElement,
    pathComponents: [String]
) async throws -> Bool {
    // 1. Get the menu bar
    let menuBar = try await getMenuBar(appElement: appElement)
    
    // 2. Get all menu bar items
    let menuBarItems = try await getMenuBarItems(menuBar: menuBar)
    
    // 3. Find the top-level menu
    guard let topLevelMenu = findMenuItem(
        items: menuBarItems,
        title: pathComponents[0],
        useFlexibleMatching: true
    ) else {
        throw MenuNavigationError.menuItemNotFound(pathComponents[0])
    }
    
    // 4. Start navigation from the top-level menu
    return try await navigateFromMenuItem(
        menuItem: topLevelMenu,
        remainingPath: Array(pathComponents.dropFirst())
    )
}
```

#### 2.3. Implement Robust Menu Item Matching

```swift
/// Find a menu item by title with flexible matching options
private func findMenuItem(
    items: [AXUIElement],
    title: String,
    useFlexibleMatching: Bool = false
) -> AXUIElement? {
    // First try exact matching
    if let exactMatch = items.first(where: { getMenuItemTitle($0) == title }) {
        return exactMatch
    }
    
    // If flexible matching is enabled, try additional matching strategies
    if useFlexibleMatching {
        // Case-insensitive matching
        if let caseInsensitiveMatch = items.first(where: { 
            getMenuItemTitle($0)?.lowercased() == title.lowercased() 
        }) {
            return caseInsensitiveMatch
        }
        
        // Trimmed matching (for whitespace differences)
        if let trimmedMatch = items.first(where: { 
            getMenuItemTitle($0)?.trimmingCharacters(in: .whitespacesAndNewlines) == 
                title.trimmingCharacters(in: .whitespacesAndNewlines)
        }) {
            return trimmedMatch
        }
        
        // Partial matching
        if let partialMatch = items.first(where: { 
            guard let itemTitle = getMenuItemTitle($0) else { return false }
            return itemTitle.contains(title) || title.contains(itemTitle)
        }) {
            return partialMatch
        }
    }
    
    return nil
}

/// Get the title of a menu item safely
private func getMenuItemTitle(_ menuItem: AXUIElement) -> String? {
    var titleRef: CFTypeRef?
    let titleStatus = AXUIElementCopyAttributeValue(menuItem, "AXTitle" as CFString, &titleRef)
    
    if titleStatus == .success, let title = titleRef as? String {
        return title
    }
    
    return nil
}
```

#### 2.4. Implement Menu Navigation Logic

```swift
/// Navigate from a menu item through remaining path components
private func navigateFromMenuItem(
    menuItem: AXUIElement,
    remainingPath: [String]
) async throws -> Bool {
    // If no more path components, we've reached the target item
    if remainingPath.isEmpty {
        // Activate the final menu item
        try AccessibilityElement.performAction(menuItem, action: "AXPress")
        return true
    }
    
    // Otherwise, we need to activate this menu to reveal submenus
    try AccessibilityElement.performAction(menuItem, action: "AXPress")
    
    // Add delay to ensure menu has time to open
    try await Task.sleep(nanoseconds: 250_000_000) // 250ms
    
    // Get the children of the activated menu
    let menuChildren = try await getMenuChildren(menuItem)
    
    // Find the next menu item in the path
    guard let nextMenuItem = findMenuItem(
        items: menuChildren,
        title: remainingPath[0],
        useFlexibleMatching: true
    ) else {
        // If not found, log details about available items for debugging
        logAvailableMenuItems(menuChildren)
        throw MenuNavigationError.menuItemNotFound(remainingPath[0])
    }
    
    // Continue navigation with the next menu item
    return try await navigateFromMenuItem(
        menuItem: nextMenuItem,
        remainingPath: Array(remainingPath.dropFirst())
    )
}

/// Get the children of a menu item
private func getMenuChildren(_ menuItem: AXUIElement) async throws -> [AXUIElement] {
    // Try to get children directly
    var childrenRef: CFTypeRef?
    let childrenStatus = AXUIElementCopyAttributeValue(menuItem, "AXChildren" as CFString, &childrenRef)
    
    if childrenStatus == .success, let children = childrenRef as? [AXUIElement] {
        return children
    }
    
    // If direct access fails, try to find AXMenu child first
    var menuRef: CFTypeRef?
    let menuStatus = AXUIElementCopyAttributeValue(menuItem, "AXMenu" as CFString, &menuRef)
    
    if menuStatus == .success, let menu = menuRef as? AXUIElement {
        // Try to get children of the menu
        var menuChildrenRef: CFTypeRef?
        let menuChildrenStatus = AXUIElementCopyAttributeValue(menu, "AXChildren" as CFString, &menuChildrenRef)
        
        if menuChildrenStatus == .success, let menuChildren = menuChildrenRef as? [AXUIElement] {
            return menuChildren
        }
    }
    
    // If all attempts fail, return empty array
    return []
}
```

### Phase 3: Error Handling and Diagnostics

#### 3.1. Define Specific Menu Navigation Errors

```swift
/// Errors specific to menu navigation
public enum MenuNavigationError: Error, CustomStringConvertible {
    case menuBarNotFound
    case menuItemsNotFound
    case menuItemNotFound(String)
    case invalidMenuPath(String)
    case invalidMenuItemFormat
    case timeoutWaitingForMenu
    
    public var description: String {
        switch self {
        case .menuBarNotFound:
            return "Could not find menu bar in application"
        case .menuItemsNotFound:
            return "Could not find menu items in menu bar"
        case .menuItemNotFound(let item):
            return "Could not find menu item: \(item)"
        case .invalidMenuPath(let path):
            return "Invalid menu path: \(path)"
        case .invalidMenuItemFormat:
            return "Menu items not in expected format"
        case .timeoutWaitingForMenu:
            return "Timeout waiting for menu to open"
        }
    }
}
```

#### 3.2. Implement Comprehensive Logging

```swift
/// Log available menu items for debugging
private func logAvailableMenuItems(_ items: [AXUIElement]) {
    var availableItems: [String] = []
    
    for item in items {
        if let title = getMenuItemTitle(item) {
            availableItems.append(title)
        }
    }
    
    logger.error("Available menu items", metadata: [
        "count": .string("\(availableItems.count)"),
        "items": .string(availableItems.joined(separator: ", "))
    ])
}

/// Log menu navigation step
private func logNavigationStep(
    step: String,
    component: String,
    metadata: [String: Logger.MetadataValue] = [:]
) {
    var combinedMetadata = metadata
    combinedMetadata["step"] = .string(step)
    combinedMetadata["component"] = .string(component)
    
    logger.info("Menu navigation step", metadata: combinedMetadata)
}
```

#### 3.3. Implement Recovery Strategies

```swift
/// Try alternative approaches if standard navigation fails
private func tryAlternativeNavigation(
    appElement: AXUIElement,
    menuPath: String
) async throws -> Bool {
    // Log that we're trying alternative approaches
    logger.info("Trying alternative navigation approaches", metadata: [
        "menuPath": .string(menuPath)
    ])
    
    // 1. Try refreshing the application element
    let refreshedAppElement = try await accessibilityService.getApplicationUIElement(
        bundleIdentifier: bundleId,
        recursive: true,
        maxDepth: 2
    )
    
    // 2. Try with a fully refreshed state
    return try await navigateMenuPath(
        appElement: refreshedAppElement,
        pathComponents: menuPath.components(separatedBy: " > ")
    )
}
```

### Phase 4: MenuNavigationTool Implementation

#### 4.1. Refactor MenuNavigationTool to Use the New Service

```swift
/// A tool for navigating and interacting with application menus
public struct MenuNavigationTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.menuNavigation
    
    /// Description of the tool
    public let description = "Get and interact with menus of macOS applications"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The menu navigation service to use
    private let menuNavigationService: any MenuNavigationServiceProtocol
    
    /// The logger
    private let logger: Logger
    
    /// Tool handler function that uses this instance's services
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
        return { [self] params in
            return try await self.processRequest(params)
        }
    }
    
    /// Create a new menu navigation tool
    public init(
        menuNavigationService: any MenuNavigationServiceProtocol,
        logger: Logger? = nil
    ) {
        self.menuNavigationService = menuNavigationService
        self.logger = logger ?? Logger(label: "mcp.tool.menu_navigation")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Menu Navigation",
            readOnlyHint: false,
            openWorldHint: true
        )
        
        // Initialize inputSchema with the full schema
        self.inputSchema = createInputSchema()
    }
    
    /// Process a menu navigation request
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
        guard let params = params else {
            throw MCPError.invalidParams("Parameters are required")
        }
        
        // Validate and extract parameters
        // ... (parameter validation code) ...
        
        // Delegate to the appropriate method based on action
        switch actionValue {
        case "getApplicationMenus":
            let menus = try await menuNavigationService.getApplicationMenus(bundleIdentifier: bundleId)
            return try formatResponse(menus)
            
        case "getMenuItems":
            let menuItems = try await menuNavigationService.getMenuItems(
                bundleIdentifier: bundleId,
                menuTitle: menuTitle,
                includeSubmenus: includeSubmenus
            )
            return try formatResponse(menuItems)
            
        case "activateMenuItem":
            let success = try await menuNavigationService.activateMenuItem(
                bundleIdentifier: bundleId,
                menuPath: menuPath
            )
            
            let result = ["success": success, "message": "Menu item activated: \(menuPath)"]
            return try formatResponse(result)
            
        default:
            throw MCPError.invalidParams("Invalid action: \(actionValue)")
        }
    }
}
```

### Phase 5: Testing and Validation

#### 5.1. Comprehensive Test Suite

```swift
/// Tests for the MenuNavigationService
final class MenuNavigationServiceTests: XCTestCase {
    private var accessibilityService: MockAccessibilityService!
    private var menuNavigationService: MenuNavigationService!
    
    override func setUp() {
        accessibilityService = MockAccessibilityService()
        menuNavigationService = MenuNavigationService(accessibilityService: accessibilityService)
    }
    
    /// Test getting application menus
    func testGetApplicationMenus() async throws {
        // Setup mock responses
        accessibilityService.mockApplicationElement = createMockAppElement()
        
        // Execute test
        let menus = try await menuNavigationService.getApplicationMenus(bundleIdentifier: "com.example.app")
        
        // Verify results
        XCTAssertEqual(menus.count, 3)
        XCTAssertEqual(menus[0].title, "File")
        XCTAssertEqual(menus[1].title, "Edit")
        XCTAssertEqual(menus[2].title, "View")
    }
    
    /// Test menu item activation with various path formats
    func testActivateMenuItemWithDifferentPaths() async throws {
        // Test cases for different path formats
        let testCases = [
            "File > Open",
            "Edit > Copy",
            "View > Show Toolbar"
        ]
        
        for path in testCases {
            // Setup mock responses
            accessibilityService.mockApplicationElement = createMockAppElement()
            
            // Execute test
            let result = try await menuNavigationService.activateMenuItem(
                bundleIdentifier: "com.example.app",
                menuPath: path
            )
            
            // Verify results
            XCTAssertTrue(result, "Menu activation failed for path: \(path)")
        }
    }
    
    /// Test handling of zero-sized menu items
    func testZeroSizedMenuItems() async throws {
        // Setup mock with zero-sized menu items
        accessibilityService.mockApplicationElement = createMockAppWithZeroSizedMenuItems()
        
        // Execute test
        let result = try await menuNavigationService.activateMenuItem(
            bundleIdentifier: "com.example.app",
            menuPath: "View > Zero-sized Item"
        )
        
        // Verify results
        XCTAssertTrue(result, "Should successfully activate zero-sized menu item")
    }
    
    /// Test flexible menu item matching
    func testFlexibleMenuItemMatching() async throws {
        // Test cases for flexible matching
        let testCases = [
            ("File > Open", "FILE > open"),  // Case difference
            ("Edit > Copy", "Edit > Copy "), // Whitespace difference
            ("View > Show Toolbar", "View > Show") // Partial match
        ]
        
        for (actualPath, searchPath) in testCases {
            // Setup mock responses
            accessibilityService.mockApplicationElement = createMockAppElement()
            
            // Execute test
            let result = try await menuNavigationService.activateMenuItem(
                bundleIdentifier: "com.example.app",
                menuPath: searchPath
            )
            
            // Verify results
            XCTAssertTrue(result, "Flexible matching failed for path: \(searchPath)")
        }
    }
    
    // Helper methods to create mock data
    private func createMockAppElement() -> UIElement {
        // Create a mock application element with menu structure
    }
    
    private func createMockAppWithZeroSizedMenuItems() -> UIElement {
        // Create a mock with zero-sized menu items
    }
}
```

#### 5.2. End-to-End Tests with Real Applications

```swift
/// End-to-end tests for menu navigation with real applications
@MainActor
final class MenuNavigationE2ETests: XCTestCase {
    private var helper: TestHelper!
    
    override func setUp() async throws {
        helper = TestHelper.sharedHelper()
    }
    
    /// Test menu navigation in TextEdit
    func testTextEditMenuNavigation() async throws {
        // Ensure TextEdit is running
        let appRunning = try await helper.ensureAppIsRunning(bundleId: "com.apple.TextEdit")
        XCTAssertTrue(appRunning, "TextEdit should be running")
        
        // Test File > New menu activation
        let newFileSuccess = try await helper.activateMenuItem(
            bundleId: "com.apple.TextEdit",
            menuPath: "File > New"
        )
        XCTAssertTrue(newFileSuccess, "Should successfully navigate to File > New")
        
        // Verify a new document was created
        let documentCount = try await helper.getDocumentCount(bundleId: "com.apple.TextEdit")
        XCTAssertGreaterThan(documentCount, 0, "A new document should be created")
    }
    
    /// Test menu navigation with nested submenus
    func testNestedSubmenuNavigation() async throws {
        // Test with an application that has nested submenus
        let success = try await helper.activateMenuItem(
            bundleId: "com.apple.Safari",
            menuPath: "View > Developer > Show JavaScript Console"
        )
        XCTAssertTrue(success, "Should successfully navigate nested submenus")
    }
}
```

### Phase 6: Error Recovery Strategies

#### 6.1. Define Comprehensive Recovery Approaches

```swift
/// Try multiple recovery approaches if initial menu navigation fails
private func attemptRecoveryStrategies(
    bundleIdentifier: String,
    menuPath: String,
    failureReason: Error
) async throws -> Bool {
    // Log initial failure
    logger.warning("Menu navigation failed, attempting recovery strategies", metadata: [
        "menuPath": .string(menuPath),
        "error": .string("\(failureReason)")
    ])

    // Strategy 1: Refresh the application state and retry
    if let result = try? await refreshAndRetry(bundleIdentifier: bundleIdentifier, menuPath: menuPath) {
        return result
    }

    // Strategy 2: Try alternative matching approaches
    if let result = try? await useAlternativeMatching(bundleIdentifier: bundleIdentifier, menuPath: menuPath) {
        return result
    }

    // Strategy 3: Try traversing menu structure differently
    if let result = try? await useAlternativeTraversal(bundleIdentifier: bundleIdentifier, menuPath: menuPath) {
        return result
    }

    // If all strategies fail, rethrow the original error with enhanced context
    throw MenuNavigationError.navigationFailed(menuPath, failureReason)
}
```

#### 6.2. Implement Detailed Error Reporting

```swift
/// Create a detailed error report for menu navigation failures
private func createErrorReport(
    bundleIdentifier: String,
    menuPath: String,
    failureDetails: [String: Any]
) -> String {
    var report = "Menu Navigation Error Report\n"
    report += "===========================\n"
    report += "Application: \(bundleIdentifier)\n"
    report += "Menu Path: \(menuPath)\n"
    report += "Failure Point: \(failureDetails["failurePoint"] as? String ?? "Unknown")\n"
    report += "Available Menu Items: \(failureDetails["availableItems"] as? [String] ?? [])\n"
    report += "Menu Structure:\n\(failureDetails["menuStructure"] as? String ?? "Not available")\n"
    report += "Suggested Fixes:\n"

    // Generate fix suggestions based on failure type
    let fixSuggestions = generateFixSuggestions(
        menuPath: menuPath,
        failureDetails: failureDetails
    )

    for (index, suggestion) in fixSuggestions.enumerated() {
        report += "  \(index + 1). \(suggestion)\n"
    }

    return report
}

/// Generate fix suggestions based on failure type
private func generateFixSuggestions(
    menuPath: String,
    failureDetails: [String: Any]
) -> [String] {
    var suggestions: [String] = []

    let failurePoint = failureDetails["failurePoint"] as? String ?? ""
    let availableItems = failureDetails["availableItems"] as? [String] ?? []

    // Suggest similar menu items if available
    if let mostSimilarItem = findMostSimilarItem(target: failurePoint, candidates: availableItems) {
        suggestions.append("Try using '\(mostSimilarItem)' instead of '\(failurePoint)'")
    }

    // Suggest checking for dynamic menus
    suggestions.append("Verify if this menu is dynamic or context-sensitive")

    // Suggest proper path format
    suggestions.append("Ensure the path format follows 'Menu > Submenu > Item' pattern")

    return suggestions
}
```

## Implementation Timeline and Resources

### Week 1: Remove Old Code and Create Foundations

- Day 1: Remove the current menu navigation implementation
- Day 2-3: Create the `MenuNavigationService` protocol and base implementation
- Day 4-5: Implement menu path resolution strategy and identifier formats

### Week 2: Core Navigation Logic

- Day 1-2: Implement pure path-based menu hierarchy traversal
- Day 3-4: Implement robust menu item matching with all matching levels
- Day 5: Implement proper menu state management and cleanup

### Week 3: Error Handling and Recovery

- Day 1-2: Implement comprehensive error types and recovery strategies
- Day 3: Create detailed error reporting system for debugging
- Day 4-5: Implement advanced recovery strategies for edge cases

### Week 4: Tool Integration and Testing

- Day 1-2: Create new `MenuNavigationTool` implementation using the service
- Day 3-4: Write comprehensive unit tests for all components
- Day 5: Create end-to-end tests with multiple applications

### Resources Required

1. **Development Resources**:
   - At least one dedicated developer for the full 4 weeks
   - Access to macOS devices with multiple applications for testing
   - TestFlight or equivalent for validation with real users

2. **Testing Resources**:
   - Test environment with various macOS applications
   - Ability to test with applications that have complex menu structures
   - Automated test runner for regression testing

3. **Documentation Resources**:
   - Technical writer to update documentation for the new APIs
   - User guide updates for any changed behavior

## Conclusion

This implementation plan provides a comprehensive approach to completely replacing the `MenuNavigationTool` with a new solution built from the ground up. By implementing a pure path-based navigation system with robust menu item matching, we can create a solution that works reliably across all macOS applications, including those with zero-sized menu items and complex menu hierarchies.

The key aspects of this solution are:

1. **Complete Removal** of the existing position-based implementation
2. A dedicated `MenuNavigationService` that encapsulates all menu navigation logic
3. Pure path-based traversal of menu hierarchies with clearly defined identifier formats
4. Robust menu item matching with multiple matching strategies
5. Comprehensive error handling, recovery strategies, and diagnostic reporting
6. Thorough testing with multiple applications and menu structures

This approach eliminates reliance on position-based navigation and creates a more maintainable, reliable menu navigation system for the MacMCP project that will properly handle the complex menu hierarchies found in macOS applications.

## Next Steps

1. Create a new git branch for this work (`menu-navigation-refactor`)
2. Remove the existing implementation of menu navigation
3. Implement the `MenuNavigationService` as outlined in this plan
4. Create comprehensive tests for the new implementation
5. Update the `MenuNavigationTool` to use the new service
6. Document the new approach for users and developers

By following this plan, we will replace a fundamentally flawed approach with a robust solution that properly handles menu navigation in macOS applications.