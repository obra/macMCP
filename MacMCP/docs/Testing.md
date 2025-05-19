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