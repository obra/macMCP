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
2. **ApplicationDrivers**: Lightweight drivers for specific applications to be used in tests
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
    - ApplicationDrivers/
      - TestApplicationDriver.swift
      - CalculatorDriver.swift
      - TextEditDriver.swift
      - SafariDriver.swift
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
    let logger: Logger
    let testHandler: TestLogHandler
    
    init() {
        // Create test logger that captures log messages
        let (logger, handler) = Logger.testLogger(label: "test.harness")
        self.logger = logger
        self.testHandler = handler
        
        // Initialize services
        accessibilityService = AccessibilityService(logger: logger)
        applicationService = ApplicationService(logger: logger)
        screenshotService = ScreenshotService(
            accessibilityService: accessibilityService,
            logger: logger
        )
        interactionService = UIInteractionService(
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    /// Creates UI state tool
    func createUIStateTool() -> UIStateTool {
        return UIStateTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    /// Creates application driver
    func createApplicationDriver(_ appType: TestApplicationType) -> TestApplicationDriver {
        switch appType {
        case .calculator:
            return CalculatorDriver(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .textEdit:
            return TextEditDriver(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .safari:
            return SafariDriver(
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
    /// Invokes a UI state tool with the given parameters
    static func invoke(
        tool: UIStateTool,
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
        return try UIStateResult(rawContent: result.content)
    }
    
    // Additional helper methods for other tools...
}
```

### TestApplicationDriver

```swift
/// Base protocol for application drivers used in tests
protocol TestApplicationDriver {
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

// Base implementation of TestApplicationDriver
class BaseApplicationDriver: TestApplicationDriver {
    let bundleIdentifier: String
    let applicationService: ApplicationService
    let accessibilityService: AccessibilityService
    let interactionService: UIInteractionService
    let appName: String
    
    init(
        bundleIdentifier: String,
        appName: String,
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.applicationService = applicationService
        self.accessibilityService = accessibilityService
        self.interactionService = interactionService
    }
    
    // Default implementations of required methods
    // ...
}
```

### Application-Specific Driver Example

```swift
/// Driver for the Calculator app used in tests
class CalculatorDriver: BaseApplicationDriver {
    /// Calculator button identifiers
    enum Button {
        static let zero = "0"
        static let one = "1"
        // ... more buttons
        static let equals = "="
        static let allClear = "AC"
    }
    
    init(
        applicationService: ApplicationService,
        accessibilityService: AccessibilityService,
        interactionService: UIInteractionService
    ) {
        super.init(
            bundleIdentifier: "com.apple.calculator",
            appName: "Calculator",
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
            if child.role == "AXStaticText" {
                return child.value
            }
        }
        
        return nil
    }
    
    /// Press a calculator button
    func pressButton(_ button: String) async throws -> Bool {
        guard let window = try await getMainWindow() else {
            return false
        }
        
        // Find and click the button
        // ...
        
        return true
    }
    
    /// Perform a calculation
    func calculate(num1: String, operation: String, num2: String) async throws -> String? {
        // Clear first
        try await pressButton(Button.allClear)
        
        // Enter first number
        for digit in num1 {
            try await pressButton(String(digit))
        }
        
        // Press operation
        try await pressButton(operation)
        
        // Enter second number
        for digit in num2 {
            try await pressButton(String(digit))
        }
        
        // Press equals
        try await pressButton(Button.equals)
        
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
    
    // Create calculator driver
    let calculator = testHarness.createApplicationDriver(.calculator)
    try await calculator.launch()
    
    // Wait for app to load
    try await Task.sleep(for: .milliseconds(1000))
    
    // Create UI state tool
    let uiStateTool = testHarness.createUIStateTool()
    
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
    
    // Perform calculation using calculator driver
    if let calculatorDriver = calculator as? CalculatorDriver {
        let calcResult = try await calculatorDriver.calculate(num1: "5", operation: "+", num2: "3")
        XCTAssertEqual(calcResult, "8", "5 + 3 should equal 8")
    }
    
    // Clean up
    try await calculator.terminate()
}
```

## Key Benefits

1. **Direct Tool Testing**: Tests interact directly with tool implementations, without MCP protocol overhead
2. **Real Application Testing**: All tests use real macOS applications
3. **Reusable Components**: Application drivers and verifiers can be shared across tests
4. **Fast Iteration**: Direct tool testing allows faster iteration during development
5. **Structured Approach**: Clear separation of concerns makes tests easier to write and maintain
6. **Comprehensive Testing**: Can test both individual tools and their integration with services
7. **Reliable Tests**: By testing against real applications with structured drivers, tests are more robust
8. **Debugging Visibility**: TestLogHandler allows inspection of logs during test execution

## Implementation Plan

1. Create the base test harness framework
2. Implement drivers for common test applications
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

A: We'll log them for later review.

- What's the best approach for simulating user input during tests?

A: You have tools to provide input. clicks and text entry and mouse movement.

- How should this framework integrate with the existing test suite?

A: it should replace all existing E2E tests

- How much test coverage should we aim for with the new framework?

A: We need to start working toward full coverage for the API. Then we can work toward full code coverage across a range of apps.

- Should we implement this incrementally or as a complete replacement?

A: We should build it out to the point where it can completely replace the existing tests.

## Implementation Lessons and Guidance

The following section contains insights from the initial implementation of this framework to help future engineers working on it:

### Key Technical Considerations

1. **Swift Concurrency and Thread Safety**: 
   - All driver classes must conform to `@unchecked Sendable` to work with XCTest async teardown
   - Use `addTeardownBlock` instead of `defer { Task { ... } }` for cleanup operations
   - Be cautious with capturing `self` in async contexts

2. **UIInteractionService Extensions**:
   - The `UIInteractionService` requires extensions for key modifiers (Command, Option, etc.)
   - Implement type-safe wrappers like `enum KeyModifier` for clarity
   - Add convenience methods like `typeText(text:)` without requiring element identifiers

3. **ElementCriteria Implementation**:
   - Pattern matching for elements requires careful consideration of nil values
   - Consider implementing fuzzy matching for more reliable element identification
   - Use namespaces to avoid conflicts with similar types (e.g., `ApplicationDrivers.ElementCriteria`)

4. **Tool Invocation Patterns**:
   - Use specialized methods for each tool type rather than generic invocation
   - Parse tool results immediately to provide type-safe access to data
   - Handle errors with detailed context for easier debugging

5. **Testing Environment Requirements**:
   - Tests require accessibility permissions to be granted
   - Some UI elements may not be found consistently across macOS versions
   - Consider environment variables to control which tests run (e.g., `RUN_INTERACTIVE_TESTS`)

### Troubleshooting Common Issues

1. **Element Not Found Issues**:
   - When UI elements can't be found, implement deeper searching with recursion
   - Add detailed logging of element properties to help diagnose identification issues
   - Consider multiple identification strategies (role, title, identifier, or position)

2. **Reliability Improvements**:
   - Add retry logic for unreliable operations
   - Implement adaptive waiting based on application responsiveness
   - Use fuzzy matching for element identification where exact matches fail

3. **Button Interaction Problems**:
   - Some buttons may require alternative interaction methods (e.g., keyboard shortcuts)
   - Verify if an element supports the AXPress action before attempting it
   - Consider position-based clicking as a fallback for problematic elements

### Expansion Recommendations

1. **Additional Verifiers**:
   - Implement ScreenshotVerifier with image comparison capabilities
   - Create InteractionVerifier to validate UI state changes after interactions
   - Consider adding result-specific verifiers for specialized tools

2. **Cross-Application Testing**:
   - Implement data transfer tests between applications
   - Create workflows that involve multiple applications
   - Test application launching and focusing thoroughly

3. **Performance Considerations**:
   - Add benchmarking capabilities to measure tool performance
   - Implement caching strategies for expensive operations
   - Consider parallel execution for independent tests

This guidance should help future engineers understand the nuances of the framework and make more informed implementation decisions.

## Test Suite Audit (May 8, 2025)

An audit of the existing test suite was conducted to identify low-value and redundant tests. The goal is to focus development efforts on high-value tests that provide meaningful validation of the MacMCP functionality.

### Low-Value Tests

#### 1. UIStateToolTests.swift
**Issue:** Uses mock objects (`MockAccessibilityService`) rather than real accessibility components. Only verifies parameter handling and basic functionality.
**Recommendation:** Replace with integration tests using real `AccessibilityService` to test against actual applications, similar to `StandaloneDirectToolTest.swift`.

#### 2. ActionLoggingTests.swift
**Issue:** Tests mock implementations (`LogService` and `ActionLogTool`) rather than the actual logging system.
**Recommendation:** Replace with integration tests that use the real `ActionLogger` and verify logs are correctly generated during actual UI interactions.

#### 3. AccessibilityTests.swift
**Issue:** Most tests are skipped or perform trivial validations due to permission requirements.
**Recommendation:** Replace with properly configured end-to-end tests with accessibility permissions granted before running, using the framework in `StandaloneDirectToolTest.swift`.

#### 4. ScreenshotToolTests.swift
**Issue:** Uses `MockScreenshotService` that returns synthetic images rather than capturing real screenshots.
**Recommendation:** Replace with integration tests using the real `ScreenshotService` to verify actual screenshot functionality, similar to `ScreenshotE2ETests.swift`.

#### 5. MenuInteractionTests.swift
**Issue:** Mostly skeleton tests with `XCTAssertTrue(true)` placeholders. Uses mocks without substantive validation.
**Recommendation:** Replace with real end-to-end tests that verify menu navigation in actual applications, similar to `BasicArithmeticE2ETests.swift`.

#### 6. UIInteractionToolTests.swift
**Issue:** Most substantive tests are skipped and redirected to E2E tests. Only tests initialization and basic error cases.
**Recommendation:** Either consolidate with existing E2E tests or convert to true unit tests with more comprehensive mock verification.

### Redundant Tests

#### 1. UIInteractionToolTests.swift
**Issue:** Redundant with end-to-end tests (`BasicArithmeticE2ETests.swift` and `KeyboardInputE2ETests.swift`).
**Recommendation:** Remove or repurpose to test edge cases not covered by E2E tests.

#### 2. UIStateToolTests.swift
**Issue:** Redundant with `UIStateInspectionE2ETests.swift` which provides more thorough testing with real applications.
**Recommendation:** Remove or convert to unit tests focused on parameter validation not covered in E2E tests.

### High-Value Tests

#### 1. StandaloneDirectToolTest.swift
This provides an excellent framework for direct tool testing without protocol layer overhead. It uses real applications and real system components.

#### 2. End-to-End Tests
All of the E2E tests are highly valuable:
- `BasicArithmeticE2ETests.swift`
- `KeyboardInputE2ETests.swift`
- `ScreenshotE2ETests.swift`
- `UIStateInspectionE2ETests.swift`

These tests interact with real applications and validate actual functionality.

#### 3. Core Model Tests
`UIElementTests.swift` provides valuable validation of the core data model.

#### 4. Error Handling Tests
`ErrorHandlingTests.swift` provides comprehensive error handling validation.

### Recommendations

1. **Eliminate Mock-Heavy Tests**: Remove or replace tests that primarily use mocks when testing core functionality that should be tested with real components.

2. **Standardize on E2E Testing**: The E2E testing approach (with Calculator app) is the most valuable. Standardize more tests to follow this pattern.

3. **Use `StandaloneDirectToolTest.swift` as a Template**: This file demonstrates a good approach for direct tool testing and could be expanded for more comprehensive testing.

4. **Improve Documentation**: In the surviving tests, improve documentation to clearly explain what each test is validating and why.

5. **Prioritize Test Reliability**: Ensure tests that interact with real system components have proper safeguards and permission checking to avoid test failures due to environmental issues.

6. **Focus on Untested Areas**: After removing redundant tests, focus on adding tests for untested or undertested areas of the codebase.

Based on this audit, we've already removed the worthless `ServerTests.swift` and its dependency `MockTransport.swift` which provided no real value as they only tested mocked functionality rather than real server behavior.