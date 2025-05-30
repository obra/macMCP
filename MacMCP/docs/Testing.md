# Testing Guide for MacMCP

This document provides guidance on writing and running tests for the MacMCP project, with a special emphasis on handling UI tests that must be executed serially.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Test Serialization](#test-serialization)
- [Writing UI Tests](#writing-ui-tests)
- [Testing Best Practices](#testing-best-practices)
- [Running Tests](#running-tests)
- [Troubleshooting](#troubleshooting)

## Overview

MacMCP tests are unique because they interact with real macOS UI elements rather than using mocks. This creates specific requirements for how tests must be structured and executed:

1. **Real Applications**: Tests interact with real macOS applications like Calculator and TextEdit
2. **UI Interaction**: Tests perform real UI interactions using the Accessibility APIs
3. **Serial Execution**: Tests must run serially to avoid interference between UI operations
4. **Resource Management**: Tests must properly launch and terminate applications

## Test Structure

The MacMCP project organizes tests into two main categories:

### 1. TestsWithMocks

These tests use mock services and focus on testing components in isolation:

- Located in `MacMCP/Tests/TestsWithMocks/`
- Test tools, utilities, and specific components
- Use mocks for services like `MockClipboardService`
- Can often be run in parallel

### 2. TestsWithoutMocks

These tests interact with real macOS applications and accessibility APIs:

- Located in `MacMCP/Tests/TestsWithoutMocks/`
- Include:
  - `ApplicationTests/`: Tests against specific applications (Calculator, TextEdit)
  - `AccessibilityTests/`: Tests for accessibility-specific functionality
  - `ToolE2ETests/`: End-to-end tests for specific tools
- Must be run serially

## Test Serialization

Since our tests interact with real UI elements, they must run serially to avoid conflicts where UI actions from one test interfere with another. We enforce serialization at multiple levels:

### 1. Suite-Level Serialization

Test suites that need to be serialized are marked with the `@Suite(.serialized)` annotation:

```swift
@Suite(.serialized)
struct CalculatorTests {
    @Test("Test addition")
    func testAddition() async throws {
        // Test code here
    }
    
    @Test("Test subtraction")
    func testSubtraction() async throws {
        // Test code here
    }
}
```

This ensures that tests within the suite run one after another, not concurrently.

### 2. Project-Level Serialization

To ensure that entire suites run serially rather than in parallel, we use two mechanisms:

#### XCTSerialSuites.txt

This file at the project root lists test suites that should always run serially:

```
TestsWithoutMocks.ApplicationTests.CalculatorTests
TestsWithoutMocks.ApplicationTests.TextEditTests
TestsWithoutMocks.ApplicationTests
TestsWithoutMocks.ToolE2ETests
TestsWithoutMocks.AccessibilityTests
```

#### Swift Test Command

Always use the `--no-parallel` flag when running tests:

```bash
swift test --no-parallel
```

This flag ensures that the test runner executes test suites serially.

## Writing UI Tests

When writing tests that interact with UI elements, follow these guidelines:

### Test Structure

1. **Test Setup**:
   - Launch the application
   - Wait for the UI to stabilize
   - Clear any previous state

2. **Test Actions**:
   - Perform UI actions
   - Add delays between actions for UI stability
   - Use accessibility paths to locate elements

3. **Test Assertions**:
   - Verify expected UI states
   - Check element attributes

4. **Test Cleanup**:
   - Close application windows
   - Terminate the application
   - Ensure resources are released

### Example Test

```swift
@Suite(.serialized)
struct SimpleCalculatorTest {
  private var app: CalculatorModel!
  private var toolChain: ToolChain!

  @Test("Test basic addition")
  func testBasicAddition() async throws {
    // Setup
    toolChain = ToolChain()
    app = CalculatorModel(toolChain: toolChain)
    
    // Launch application
    let launchSuccess = try await app.launch(hideOthers: false)
    #expect(launchSuccess, "Calculator should launch successfully")
    
    // Wait for app to be ready
    try await Task.sleep(for: .milliseconds(2000))
    
    // Clear the calculator
    _ = try await app.clear()
    
    // Perform calculation
    _ = try await app.pressButtonViaAccessibility("3")
    _ = try await app.pressButtonViaAccessibility("+")
    _ = try await app.pressButtonViaAccessibility("4")
    _ = try await app.pressButtonViaAccessibility("=")
    
    // Wait for UI update
    try await Task.sleep(for: .milliseconds(500))
    
    // Verify result
    let displayValue = try await app.getDisplayValue()
    #expect(displayValue != nil, "Should be able to read the display value")
    
    if let displayValue {
      let isExpectedValue = displayValue == "7" || displayValue == "7." || displayValue.hasPrefix("7")
      #expect(isExpectedValue, "Display should show '7', got '\(displayValue)'")
    }
    
    // Cleanup
    let runningAppsAfter = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleId)
    for runningApp in runningAppsAfter {
      _ = runningApp.terminate()
    }
    
    // Wait for termination to complete
    try await Task.sleep(for: .milliseconds(1000))
  }
}
```

### Helper Classes

The project provides helper classes to simplify UI testing:

- `CalculatorTestHelper`: Helper for Calculator app tests
- `TextEditTestHelper`: Helper for TextEdit app tests
- `ToolChain`: Provides unified access to all MCP tools
- `UIElementCriteria`: Helps find UI elements with specific attributes

Use these helpers to make your tests more concise and maintainable.

## Testing Best Practices

### 1. Resilience to UI Changes

- Use element descriptions, roles, and identifiers that are unlikely to change
- Implement retry mechanisms for UI operations that might be timing-dependent
- Add sufficient delays to allow UI to stabilize

### 2. Test Isolation

- Each test should be completely self-contained
- Always launch and terminate the application in each test
- Don't rely on state from previous tests

### 3. Error Handling and Diagnostics

- Add detailed error messages to assertions
- Log relevant information during test execution
- Use TestLogger for consistent logging

### 4. Setup and Cleanup

- Always clean up resources even if tests fail
- Use try/finally patterns to ensure cleanup happens
- Terminate applications to prevent resource leaks

### 5. Performance Considerations

- Add sufficient delays for UI stability
- Avoid unnecessary UI operations
- Use the MCP-based accessibility inspector to find the most direct path to UI elements

### 6. Using #expect Assertions

When using the Swift Testing framework's `#expect` macro, follow these guidelines:

1. **Basic Assertions**:
   ```swift
   // Correct usage
   #expect(value == expected, "Optional message")
   #expect(condition == true, "Optional message")
   #expect(value == nil, "Optional message")
   
   // For explicit failure cases, use Bool(false)
   #expect(Bool(false), "This test should fail")
   ```

2. **Common Patterns**:
   ```swift
   // Equality checks
   #expect(actual == expected, "Values should be equal")
   
   // Boolean conditions
   #expect(condition, "Condition should be true")
   
   // Nil checks
   #expect(optional == nil, "Value should be nil")
   
   // String contains
   #expect(string.contains("expected"), "String should contain expected text")
   
   // Error handling
   do {
     try someOperation()
     #expect(Bool(false), "Operation should throw")
   } catch {
     #expect(error is ExpectedErrorType, "Wrong error type")
   }
   ```

3. **Avoid Common Mistakes**:
   - Don't use `#expect(false, "message")` - use `#expect(Bool(false), "message")` instead
   - Don't use `#expect(true, "message")` - use `#expect(condition, "message")` instead
   - Always provide descriptive messages for failures
   - Use appropriate comparison operators (==, !=, >, <, etc.)

4. **Best Practices**:
   - Keep assertions focused and specific
   - Use descriptive failure messages
   - Group related assertions together
   - Use appropriate comparison methods for different types
   - Consider using custom assertion helpers for complex checks

### 7. Testing JSON Responses

When testing JSON responses from resources or other API calls, **always** use the `JSONTestUtilities` framework rather than string-based assertions. This approach is more robust and less prone to failures due to whitespace, field ordering, or formatting differences.

#### Using JSONTestUtilities

The MacMCP test suite provides a comprehensive `JSONTestUtilities` framework located in `Tests/TestsWithoutMocks/TestFramework/JSONTestUtilities.swift`. This utility provides structured, type-safe JSON testing.

##### Basic JSON Object Testing

```swift
import JSONTestUtilities

// Test a JSON response from a resource
if case .text(let jsonString) = content {
    try JSONTestUtilities.testJSONObject(jsonString) { json in
        // Test basic properties
        try JSONTestUtilities.assertProperty(json, property: "id", equals: "expected-id")
        try JSONTestUtilities.assertProperty(json, property: "role", equals: "AXButton")
        
        // Test for property existence without checking value
        try JSONTestUtilities.assertPropertyExists(json, property: "frame")
        
        // Test that certain properties are omitted
        try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "redundantField")
        
        // Test string contains
        try JSONTestUtilities.assertPropertyContains(json, property: "el", substring: "Button")
    }
} else {
    #expect(Bool(false), "Content should be text")
}
```

##### JSON Array Testing

```swift
// Test a JSON array response
if case .text(let jsonString) = content {
    try JSONTestUtilities.testJSONArray(jsonString) { jsonArray in
        // Test array structure
        #expect(jsonArray.count > 0, "Array should not be empty")
        
        // Test that array contains an object with specific property
        try JSONTestUtilities.assertArrayContainsObjectWithProperty(
            jsonArray, 
            property: "role", 
            equals: "AXButton"
        )
        
        // Test all items in array have required property
        for item in jsonArray {
            try JSONTestUtilities.assertPropertyExists(item, property: "id")
        }
    }
} else {
    #expect(Bool(false), "Content should be text")
}
```

##### Testing EnhancedElementDescriptor Output

For testing `EnhancedElementDescriptor` JSON output specifically, use the specialized utility:

```swift
// Test an EnhancedElementDescriptor
let element = UIElement(...)
let descriptor = EnhancedElementDescriptor.from(element: element)

try JSONTestUtilities.testElementDescriptor(descriptor) { json in
    // Test required fields
    try JSONTestUtilities.assertPropertyExists(json, property: "id")
    try JSONTestUtilities.assertProperty(json, property: "role", equals: "AXButton")
    
    // Test verbosity reduction - omitted fields
    try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "name")
    
    // Test combined element field
    try JSONTestUtilities.assertPropertyContains(json, property: "el", substring: "Save")
    
    // Test conditional fields (only present when showCoordinates=true)
    if showCoordinates {
        try JSONTestUtilities.assertPropertyExists(json, property: "frame")
    } else {
        try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "frame")
    }
}
```

#### Available Utility Methods

The `JSONTestUtilities` provides these methods:

1. **Core Parsing**:
   - `parseJSON(_:)` - Parse JSON string to Any
   - `parseJSONObject(_:)` - Parse JSON string to [String: Any]
   - `parseJSONArray(_:)` - Parse JSON string to [[String: Any]]

2. **Property Assertions**:
   - `assertPropertyExists(_:property:)` - Check property exists
   - `assertPropertyDoesNotExist(_:property:)` - Check property is absent
   - `assertProperty(_:property:equals:)` - Check property has specific value
   - `assertPropertyContains(_:property:substring:)` - Check string property contains substring

3. **Array Assertions**:
   - `assertArrayContainsObjectWithProperty(_:property:equals:)` - Check array contains object with property

4. **Structured Testing**:
   - `testJSONObject(_:assertions:)` - Parse and test JSON object
   - `testJSONArray(_:assertions:)` - Parse and test JSON array
   - `testElementDescriptor(_:assertions:)` - Test EnhancedElementDescriptor output

#### Benefits of This Approach

1. **Robust to Formatting Changes**: Independent of JSON string formatting, whitespace, or property ordering
2. **Type Safety**: Checks both property existence and correct types
3. **Better Error Messages**: Provides specific error messages about what's wrong
4. **Complex Conditions**: Supports complex testing scenarios like array searches
5. **Maintainable**: Changes to JSON structure require minimal test updates
6. **Consistent**: All JSON tests use the same patterns and utilities

#### Migration from String-Based Tests

**❌ Avoid this pattern:**
```swift
// Brittle string-based testing
let jsonString = String(data: jsonData, encoding: .utf8)!
#expect(jsonString.contains("\"role\":\"AXButton\""), "Should contain role")
#expect(jsonString.contains("\"id\":"), "Should contain id field")
#expect(!jsonString.contains("\"name\""), "Should not contain name field")
```

**✅ Use this pattern instead:**
```swift
// Robust structured testing
try JSONTestUtilities.testElementDescriptor(descriptor) { json in
    try JSONTestUtilities.assertProperty(json, property: "role", equals: "AXButton")
    try JSONTestUtilities.assertPropertyExists(json, property: "id")
    try JSONTestUtilities.assertPropertyDoesNotExist(json, property: "name")
}
```

## Running Tests

### Basic Test Execution

```bash
# Run all tests serially
cd MacMCP
swift test --no-parallel

# Run specific test
swift test --filter TestsWithoutMocks.ApplicationTests.CalculatorTests/SimpleCalculatorTest/testBasicAddition --no-parallel

# Run tests with verbose output
swift test --verbose --no-parallel
```

### Code Coverage

```bash
# Run tests with code coverage
swift test --no-parallel --enable-code-coverage
```

### Selective Testing

```bash
# Run only the Calculator tests
swift test --filter TestsWithoutMocks.ApplicationTests.CalculatorTests --no-parallel

# Skip specific tests
swift test --skip PerformanceTests --no-parallel
```

## Troubleshooting

### Common Issues

1. **Tests Timing Out**
   - Increase delay durations for UI operations
   - Check application state (might be in unexpected state)
   - Verify accessibility permissions

2. **Element Not Found**
   - Use the MCP accessibility inspector to verify element paths
   - Check if element ID or structure has changed
   - Verify the application is in the expected state

3. **Test Interference**
   - Ensure tests are running serially (check for `--no-parallel` flag)
   - Verify tests properly clean up resources
   - Check for leftover application instances

4. **Accessibility Permission Issues**
   - Grant full disk access to Terminal and development tools
   - Enable accessibility access for the Terminal and dev environment
   - Run the permissions check script

### Debugging Techniques

1. **Use the MCP-Based Inspector**
   ```bash
   ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP
   ```

2. **Enable Verbose Logging**
   ```bash
   swift test --verbose --no-parallel
   ```

3. **Run a Single Test**
   ```bash
   swift test --filter TestsWithoutMocks.ApplicationTests.CalculatorTests/SimpleCalculatorTest/testBasicAddition --no-parallel
   ```

4. **Check Test Logs**
   - Examine the test logs in the terminal output
   - Check the saved log files for detailed diagnostics



⏺ Performance Optimization Insights for MacMCP Tests

  Here's what I learned about optimizing test performance in your codebase:

  Key Bottlenecks Identified

  1. App Launch/Termination Overhead: Each test was individually launching and terminating Calculator, taking 3-4 seconds per test.
  2. Excessive Sleep Durations: Long Task.sleep durations (2s after launch, 1s after termination) significantly extended test time.
  3. ElementPath Resolution: The BFS-based search algorithm in resolveBFS is expensive, with many AX API calls.
  4. Verbose Diagnostic Logging: Extensive "DIAGNOSTIC" logging in ElementPath's resolve methods adds overhead.
  5. Redundant Initialization: Each test was recreating the same accessibility service and application connections.

  Effective Optimization Strategies

  1. Share State Across Tests:
    - Use static properties to maintain shared app instances
    - Initialize once, reuse throughout test suite
    - Add proper Actor isolation with @MainActor
  2. Reduce Sleep Durations:
    - Launch wait: 2000ms → 500ms
    - Termination wait: 1000ms → 100ms
    - Foreground activation: 1000ms → 100ms
  3. Lazy Initialization Pattern:
    - Only launch the app when needed
    - Use a state flag to track initialization status
    - Clean up resources only after all tests complete
  4. Concurrency-Safe Resource Sharing:
    - Proper @MainActor isolation for shared state
    - Safe access via MainActor.run { ... }
    - Avoid unnecessary async/await overhead
  5. Optimize Test Structure:
    - Single app instance for all test cases
    - Reset state between tests instead of terminating
    - Clean up resources only at the end of all tests

  Results

  - Before: 120 seconds total)
  - After: ~12 seconds for first test, ~0.1-0.7 seconds for subsequent tests
  - Total suite time: ~14.6 seconds (8x improvement)

  Additional Optimization Opportunities

  1. ElementPath Resolution Optimization:
    - Cache common path resolutions
    - Reduce trace logging in path resolution code
    - Implement more efficient search algorithms than BFS for common cases
  2. Application-Specific Shortcuts:
    - Use direct pid-based access instead of element path resolution
    - Maintain a cache of commonly accessed UI elements
    - Implement custom element finders for specific applications
  3. Parallel Test Execution:
    - Run non-UI tests in parallel
    - Group UI tests by application to minimize app launches
  4. Targeted Testing:
    - Use snapshot testing for UI verification
    - Minimize AX API calls during tests
