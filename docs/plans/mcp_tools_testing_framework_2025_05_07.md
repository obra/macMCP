# MacMCP Tools Testing Framework Design [PLAN]

**Date:** May 7, 2025  
**Status:** Planning Phase - Not Yet Implemented  
**Author:** Claude  

> **IMPORTANT NOTE:** This document outlines a planned approach for improving the testing framework for MacMCP tools. This design has not yet been implemented and is subject to review and modification before implementation.

## Background

The current testing approach has several limitations:
- Reliance on the MCP protocol adds complexity to tests
- Testing through the MCP protocol makes it difficult to test specific tool functionality
- End-to-end tests with real applications are brittle and hard to maintain
- Current mocks don't accurately represent real-world behavior for MCP tools

We need a testing framework that allows:
- Direct testing of MCP tools at the Swift level
- Testing against real applications
- Quick iteration during development
- Reliable and maintainable tests

## Proposed Solution: Application-Driven Swift Testing Harness

This framework enables direct testing of MacMCP tools against real applications without going through the MCP protocol layer, while still providing the benefits of testing with real applications.

### Key Components

1. **ToolTestHarness**: A base class that provides common functionality for testing MCP tools
2. **ApplicationWrappers**: Lightweight wrappers for specific applications to be used in tests
3. **TestVerifiers**: Components that verify the outputs from tool operations
4. **ToolInvoker**: Direct invoker of tool implementations without going through protocol

### Framework Structure

```
MacMCP/Tests/
  - TestHarness/
    - ToolTestHarness.swift
    - ToolInvoker.swift
    - TestVerifiers/
      - UIStateVerifier.swift
      - ScreenshotVerifier.swift
      - InteractionVerifier.swift
    - ApplicationWrappers/
      - TestApplicationWrapper.swift
      - CalculatorWrapper.swift
      - TextEditWrapper.swift
      - SafariWrapper.swift
```

## Implementation Details

### ToolTestHarness

```swift
/// Base class for testing MCP tools directly
class ToolTestHarness {
    // Common services used by tools
    let accessibilityService: AccessibilityService
    let applicationService: ApplicationService
    let screenshotService: ScreenshotService
    let interactionService: UIInteractionService
    
    // Logger that can be inspected in tests
    let testLogger: TestLogger
    
    init() {
        testLogger = TestLogger()
        accessibilityService = AccessibilityService(logger: testLogger)
        applicationService = ApplicationService(logger: testLogger)
        screenshotService = ScreenshotService(
            accessibilityService: accessibilityService,
            logger: testLogger
        )
        interactionService = UIInteractionService(
            accessibilityService: accessibilityService,
            logger: testLogger
        )
    }
    
    /// Creates a freshly initialized test instance of any MCP tool
    func createToolInstance<T: MCPTool>(toolType: T.Type) -> T {
        return T.init(
            accessibilityService: accessibilityService,
            applicationService: applicationService,
            screenshotService: screenshotService,
            interactionService: interactionService,
            logger: testLogger
        )
    }
    
    /// Launches a test application and returns the appropriate wrapper
    func launchTestApplication(_ appType: TestApplicationType) -> TestApplicationWrapper {
        switch appType {
        case .calculator:
            return CalculatorWrapper(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .textEdit:
            return TextEditWrapper(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .safari:
            return SafariWrapper(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        }
    }
}
```

### ToolInvoker

```swift
/// Direct invoker for MCP tools without going through protocol
class ToolInvoker {
    /// Invokes a tool with the given parameters
    static func invoke<T: MCPTool>(
        tool: T,
        parameters: [String: Value]
    ) async throws -> ToolResult {
        // Direct invocation of the tool's handler
        let content = try await tool.handler(parameters)
        return ToolResult(content: content)
    }
    
    /// Helper method for UI state tool
    static func getUIState(
        tool: UIStateTool,
        scope: String,
        bundleId: String? = nil,
        position: CGPoint? = nil,
        maxDepth: Int = 5
    ) async throws -> UIStateResult {
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
        
        let result = try await invoke(tool: tool, parameters: params)
        return UIStateResult(rawContent: result.content)
    }
    
    // Additional helper methods for other tools...
}
```

### TestApplicationWrapper

```swift
/// Base protocol for application wrappers used in tests
protocol TestApplicationWrapper {
    var bundleIdentifier: String { get }
    var applicationService: ApplicationService { get }
    var accessibilityService: AccessibilityService { get }
    var interactionService: UIInteractionService { get }
    
    /// Launch the application
    func launch() async throws -> Bool
    
    /// Terminate the application
    func terminate() async throws -> Bool
    
    /// Get the main window of the application
    func getMainWindow() async throws -> UIElement?
    
    /// Get all windows of the application
    func getAllWindows() async throws -> [UIElement]
    
    /// Check if the application is running
    func isRunning() -> Bool
    
    /// Wait for a specific element to appear
    func waitForElement(matching criteria: ElementCriteria, timeout: TimeInterval) async throws -> UIElement?
}

// Base implementation of TestApplicationWrapper
class BaseApplicationWrapper: TestApplicationWrapper {
    let bundleIdentifier: String
    let applicationService: ApplicationService
    let accessibilityService: AccessibilityService
    let interactionService: UIInteractionService
    
    init(
        bundleIdentifier: String,
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationService = applicationService
        self.accessibilityService = accessibilityService
        self.interactionService = interactionService
    }
    
    // Default implementations of required methods
    // ...
}
```

### Application-Specific Wrapper Example

```swift
/// Wrapper for the Calculator app used in tests
class CalculatorWrapper: BaseApplicationWrapper {
    init(
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        super.init(
            bundleIdentifier: "com.apple.calculator",
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Get the display value shown on the calculator
    func getDisplayValue() async throws -> String? {
        guard let window = try await getMainWindow() else {
            return nil
        }
        
        // Find the display element
        for child in window.children {
            if child.role == "AXStaticText" && 
               (child.identifier.contains("Display") || 
                (child.frame.origin.y < 100 && child.frame.origin.x < 100)) {
                return child.value
            }
        }
        
        return nil
    }
    
    /// Press a calculator button by identifier
    func pressButton(identifier: String) async throws -> Bool {
        try await interactionService.clickElement(identifier: identifier)
        return true
    }
    
    /// Perform a calculation
    func calculate(num1: String, operation: String, num2: String) async throws -> String? {
        // Clear first
        _ = try await pressButton(identifier: "AC")
        
        // Enter first number
        for digit in num1 {
            _ = try await pressButton(identifier: String(digit))
        }
        
        // Press operation
        _ = try await pressButton(identifier: operation)
        
        // Enter second number
        for digit in num2 {
            _ = try await pressButton(identifier: String(digit))
        }
        
        // Press equals
        _ = try await pressButton(identifier: "=")
        
        // Get result
        return try await getDisplayValue()
    }
}
```

### Test Verifiers

```swift
/// Verifies UI state results from tool operations
struct UIStateVerifier {
    /// Verifies that an element matching the criteria exists in the UI state
    static func verifyElementExists(
        in uiState: UIStateResult,
        matching criteria: ElementCriteria
    ) -> Bool {
        return findElement(in: uiState.elements, matching: criteria) != nil
    }
    
    /// Finds an element matching the criteria in the UI state
    static func findElement(
        in elements: [UIElementRepresentation],
        matching criteria: ElementCriteria
    ) -> UIElementRepresentation? {
        // Recursive function to search through elements
        func search(in elements: [UIElementRepresentation]) -> UIElementRepresentation? {
            for element in elements {
                if criteria.matches(element) {
                    return element
                }
                
                if let found = search(in: element.children) {
                    return found
                }
            }
            return nil
        }
        
        return search(in: elements)
    }
}
```

## Example Test Case

```swift
func testUIStateTool() async throws {
    // Create test harness
    let testHarness = ToolTestHarness()
    
    // Launch calculator app
    let calculator = testHarness.launchTestApplication(.calculator)
    try await calculator.launch()
    
    // Wait for app to load
    try await Task.sleep(for: .milliseconds(1000))
    
    // Create UI state tool
    let uiStateTool = testHarness.createToolInstance(toolType: UIStateTool.self)
    
    // Get UI state directly
    let result = try await ToolInvoker.getUIState(
        tool: uiStateTool,
        scope: "application",
        bundleId: calculator.bundleIdentifier,
        maxDepth: 10
    )
    
    // Verify calculator buttons exist
    let hasEqualsButton = UIStateVerifier.verifyElementExists(
        in: result,
        matching: ElementCriteria(role: "AXButton", title: "=")
    )
    XCTAssertTrue(hasEqualsButton, "Calculator should have equals button")
    
    // Perform calculation using calculator wrapper
    let calcResult = try await calculator.calculate(num1: "5", operation: "+", num2: "3")
    XCTAssertEqual(calcResult, "8", "5 + 3 should equal 8")
    
    // Clean up
    try await calculator.terminate()
}
```

## Key Benefits

1. **Direct Tool Testing**: Tests interact directly with tool implementations, without MCP protocol overhead
2. **Real Application Testing**: All tests use real macOS applications
3. **Reusable Components**: Application wrappers and verifiers can be shared across tests
4. **Fast Iteration**: Direct tool testing allows faster iteration during development
5. **Structured Approach**: Clear separation of concerns makes tests easier to write and maintain
6. **Comprehensive Testing**: Can test both individual tools and their integration with services
7. **Reliable Tests**: By testing against real applications with structured wrappers, tests are more robust
8. **Debugging Visibility**: TestLogger allows inspection of logs during test execution

## Implementation Plan

1. Create the base test harness framework
2. Implement wrappers for common test applications
3. Create tool invokers for all MCP tools
4. Add verifiers for tool outputs
5. Refactor existing tests to use the new framework
6. Add comprehensive tests for all tools
7. Create integration tests for tool combinations

This approach balances direct tool testing with real-world application interactions, providing the best of both worlds for testing the MacMCP tools.

## Next Steps

This plan requires review and approval before implementation begins. The next steps would be:

1. Review this design with the team
2. Prioritize implementation tasks
3. Create a timeline for implementation
4. Assign resources to implement the framework
5. Begin implementation with a proof of concept

## Open Questions

- How should we handle application-specific failures during tests?
- What's the best approach for simulating user input during tests?
- How should this framework integrate with the existing test suite?
- How much test coverage should we aim for with the new framework?
- Should we implement this incrementally or as a complete replacement?