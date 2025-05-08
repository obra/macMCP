# MacMCP Testing Architecture Redesign

**Date:** May 8, 2025  
**Status:** Implementation in Progress  

## Background

The current testing approach for MacMCP has several limitations:

- Tests are focused on accessibility framework rather than the MCP tools
- There's a mix of abstraction layers across the test suite
- Some tests use mocks while others go through the actual MCP protocol layer
- Many tests duplicate functionality and setup code
- Test setup is complex and brittle with static state sharing

## Goals

1. **Test tools end-to-end**: Focus on verifying that MCP tools work correctly when used together
2. **Use real applications**: Test against actual macOS applications to validate real-world behavior
3. **Minimize boilerplate**: Make test writing simple and consistent
4. **Clear separation of concerns**: Each component should have a single responsibility
5. **Flexible test verification**: Support various verification methods (UI state, screenshots, etc.)

## Core Architecture

The new testing architecture focuses on three main concepts:

1. **Test Scenarios**: End-to-end test cases that model real-world usage patterns
2. **Tool Chain**: A composition of MCP tools that work together as a unit
3. **Application Models**: Typed representations of applications under test
4. **Test Verifiers**: Components to verify test outcomes

### Test Scenario

The `TestScenario` protocol provides the structure for end-to-end tests:

```swift
protocol TestScenario {
    // Core test methods
    func setup() async throws
    func run() async throws
    func teardown() async throws
    
    // Helper methods for assertions
    func expectUIElementMatching(_ criteria: ElementCriteria) async throws -> UIElement
    func expectScreenshotMatches(_ reference: String) async throws
    func expectCalculationResult(_ expected: String) async throws
    // Additional expect methods as needed
}
```

### Tool Chain

The `ToolChain` class provides a unified API for using all MCP tools:

```swift
class ToolChain {
    // Underlying services
    let accessibilityService: AccessibilityService
    let applicationService: ApplicationService
    let screenshotService: ScreenshotService
    let interactionService: UIInteractionService
    
    // Tools
    let uiStateTool: UIStateTool
    let screenshotTool: ScreenshotTool
    let uiInteractionTool: UIInteractionTool
    let openApplicationTool: OpenApplicationTool
    let windowManagementTool: WindowManagementTool
    let menuNavigationTool: MenuNavigationTool
    let interactiveElementsDiscoveryTool: InteractiveElementsDiscoveryTool
    let elementCapabilitiesTool: ElementCapabilitiesTool
    
    // Application models (factory methods)
    func createCalculatorModel() -> CalculatorModel
    func createTextEditModel() -> TextEditModel
    func createSafariModel() -> SafariModel
    
    // Convenience methods for common flows
    func openApp(bundleId: String) async throws
    func findElement(matching: ElementCriteria) async throws -> UIElement?
    func findAndClickElement(matching: ElementCriteria) async throws
    func typeText(text: String) async throws
    func takeScreenshot() async throws -> Screenshot
    // Additional helper methods
}
```

### Application Models

Application models provide strongly-typed interfaces for interacting with specific applications:

```swift
protocol ApplicationModel {
    var bundleId: String { get }
    var toolChain: ToolChain { get }
    
    func launch() async throws
    func terminate() async throws
    func isRunning() async throws -> Bool
}

class CalculatorModel: ApplicationModel {
    let bundleId = "com.apple.calculator"
    let toolChain: ToolChain
    
    // UI elements
    let display: ElementCriteria
    let buttons: [String: ElementCriteria]
    
    // Actions
    func pressButton(_ button: String) async throws
    func getDisplayValue() async throws -> String
    func calculate(num1: String, op: String, num2: String) async throws -> String
}
```

### Test Verifiers

Verifiers provide specialized assertion methods for different types of verification:

```swift
class UIVerifier {
    let toolChain: ToolChain
    
    func verifyElementExists(matching: ElementCriteria) async throws
    func verifyElementText(matching: ElementCriteria, equals: String) async throws
    func verifyElementProperty(matching: ElementCriteria, property: String, equals: Any) async throws
    // Additional verification methods
}

class ScreenshotVerifier {
    let toolChain: ToolChain
    
    func verifyScreenshotMatches(reference: String) async throws
    func verifyElementAppearance(elementId: String, matchesReference: String) async throws
    // Additional verification methods
}
```

## Example Test

Here's an example of a complete test using the new architecture:

```swift
class CalculatorBasicArithmeticTest: TestScenario {
    private let toolChain: ToolChain
    private let calculator: CalculatorModel
    private let uiVerifier: UIVerifier
    
    init() {
        self.toolChain = ToolChain()
        self.calculator = toolChain.createCalculatorModel()
        self.uiVerifier = UIVerifier(toolChain: toolChain)
    }
    
    func setup() async throws {
        // Launch calculator app
        try await calculator.launch()
        
        // Verify calculator is running
        try await uiVerifier.verifyElementExists(matching: calculator.display)
    }
    
    func run() async throws {
        // Test addition
        let additionResult = try await calculator.calculate(num1: "2", op: "+", num2: "2")
        XCTAssertEqual(additionResult, "4", "2 + 2 should equal 4")
        
        // Test subtraction
        let subtractionResult = try await calculator.calculate(num1: "5", op: "-", num2: "3")
        XCTAssertEqual(subtractionResult, "2", "5 - 3 should equal 2")
        
        // Test multiplication
        let multiplicationResult = try await calculator.calculate(num1: "4", op: "×", num2: "5")
        XCTAssertEqual(multiplicationResult, "20", "4 × 5 should equal 20")
        
        // Test division
        let divisionResult = try await calculator.calculate(num1: "10", op: "÷", num2: "2")
        XCTAssertEqual(divisionResult, "5", "10 ÷ 2 should equal 5")
    }
    
    func teardown() async throws {
        // Terminate calculator
        try await calculator.terminate()
    }
}
```

## Project Structure

The new test architecture will be organized as follows:

```
MacMCP/Tests/
  - TestFramework/
    - TestScenario.swift
    - ToolChain.swift
    - Verifiers/
      - UIVerifier.swift
      - ScreenshotVerifier.swift
      - InteractionVerifier.swift
    - ApplicationModels/
      - ApplicationModel.swift
      - CalculatorModel.swift
      - TextEditModel.swift
      - SafariModel.swift
  - ToolTests/
    - BasicArithmeticTests.swift
    - KeyboardInputTests.swift
    - UIStateTests.swift
    - ScreenshotTests.swift
    - MenuNavigationTests.swift
    - ElementDiscoveryTests.swift
  - ApplicationTests/
    - CalculatorTests/
      - ArithmeticTests.swift
      - ScientificFunctionsTests.swift
    - TextEditTests/
      - TextEntryTests.swift
      - FormattingTests.swift
    - SafariTests/
      - BrowsingTests.swift
      - TabManagementTests.swift
  - CrossApplicationTests/
    - CopyPasteTests.swift
    - DragDropTests.swift
```

## Implementation Plan

1. Create the new test framework foundation:
   - Define `TestScenario` protocol
   - Implement `ToolChain` class
   - Create basic verifiers

2. Implement application models:
   - Define `ApplicationModel` protocol
   - Implement `CalculatorModel` for initial testing

3. Create tool-focused tests:
   - Implement basic arithmetic tests
   - Create UI state inspection tests
   - Add screenshot tests

4. Add application-specific tests:
   - Calculator
   - TextEdit
   - Safari

5. Add cross-application tests:
   - Copy/paste between applications
   - Drag and drop between applications

## Benefits

This new architecture provides several benefits:

1. **Focus on MCP Tools**: Tests are directly validating what Claude will use (the MCP tools)
2. **Reusable Components**: Application models and verifiers can be reused across tests
3. **Maintainable Tests**: Clean separation of concerns makes tests easier to maintain
4. **Real-World Testing**: Tests interact with actual applications, validating real behaviors
5. **Extensible Design**: New verifiers, application models, and test scenarios can be added easily

## Timeline

- Initial framework implementation: 1 week
- Basic tool tests: 1 week
- Application models and tests: 2 weeks
- Cross-application tests: 1 week

Total implementation time: 5 weeks