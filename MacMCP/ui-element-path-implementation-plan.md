# UI Element Path-based Identifier Implementation Plan

This document presents an ordered series of prompts for implementing a path-based UI element identification system in MacMCP. Each step follows test-driven development (TDD) practices and includes clear commit instructions.

## Current Status

## Implementation Progress

### Step 1: Create ElementPath Model and Parser 

The core ElementPath model and parser must besuccessfully implemented with the following features:

- **Path Syntax**: Supports paths like `ui://AXWindow/AXScrollArea/AXTextArea[@name="Content"]`
- **Path Components**:
  - Path ID prefix: `ui://`
  - Path segments with roles: `AXWindow/AXGroup/AXButton`
  - Attribute selectors: `[@title="Save"][@description="Save button"]` 
  - Index selectors: `[2]` (for selecting nth matching element)
- **Error Handling**: Comprehensive error types for validation failures
- **Parsing & Generation**: Full support for both parsing paths from strings and generating path strings

**Design Notes**:
- When generating paths, we should always try to have a unique attribute at each level. it might be the identifier or description or name or value
- The `ElementPath` struct contains:
  - `segments`: Array of `PathSegment` objects representing the path hierarchy
- The nested `PathSegment` struct contains:
  - `role`: Accessibility role (e.g., "AXButton")
  - `attributes`: Dictionary of attribute name/value pairs
  - `index`: Optional index for selecting among multiple matches

## Phase 1: Core Element Path Infrastructure

### 🔲 Step 2: Element Path Resolution Logic

**Prompt for LLM agent:**
```
Implement the resolution logic for ElementPath that converts a path string into an actual AXUIElement. Follow TDD principles:

1. Extend ElementPathTests.swift with tests for path resolution
2. Create test fixtures or mocks to validate resolution logic
3. Implement these methods in ElementPath:
   - `resolve(using: AccessibilityService) async throws -> AXUIElement?`
   - `resolveSegment(element: AXUIElement, segment: PathSegment) async throws -> AXUIElement?`
4. Add integration tests with real applications if possible

The path resolution should:
- Start with the application element
- Traverse through each path segment
- Match elements based on role, attributes, and index
- Handle error cases when elements can't be found

Commit the changes with message: "Add ElementPath resolution logic with tests"
```

### 🔲 Step 3: UIElement Path Extension

**Prompt for LLM agent:**
```
Extend UIElement with methods to generate and parse paths. Follow TDD approach:

1. Write tests in UIElementTests.swift for path generation from existing UIElements
2. Add tests for comparing UIElements via their paths
3. Implement these extensions:
   - `UIElement.generatePath() -> String?`
   - `UIElement.init(fromPath: String, accessibilityService: AccessibilityService) async throws`
4. Ensure path generation captures the element's hierarchy accurately
5. Add static comparison methods to determine if two paths reference the same element

Paths should include relevant attributes (title, description, identifier) that would help uniquely identify an element.

Commit the changes with message: "Add UIElement extensions for path generation and parsing"
```

## Phase 2: Service Layer Integration

### 🔲 Step 4: Update AccessibilityService for Path Support

**Prompt for LLM agent:**
```
Update AccessibilityService to support finding elements by path. Follow TDD:

1. Write tests in AccessibilityServiceTests.swift for the new methods
2. Create tests that verify path-based element lookup
3. Add these methods to AccessibilityService:
   - `findElementByPath(_ path: String) async throws -> UIElement?`
   - `findApplicationElementByBundleId(_ bundleId: String) async throws -> AXUIElement?`
4. Update existing find methods to optionally accept paths
5. Add performance optimizations like caching for repeated path lookups

Make sure the implementation handles error cases gracefully and provides useful diagnostic information when paths can't be resolved.

Commit the changes with message: "Update AccessibilityService with path-based element lookup"
```

### 🔲 Step 5: Enhance UIInteractionService with Path Support

**Prompt for LLM agent:**
```
Update UIInteractionService to prioritize path-based element lookups. Follow TDD:

1. Write tests in UIInteractionServiceTests.swift for path-based interactions
2. Update these methods to handle paths:
   - `getAXUIElement(for identifier: String) async throws -> AXUIElement`
   - `clickElement(identifier: String) async throws`
   - Other interaction methods
3. Add a mechanism to detect if an identifier is a path
4. Implement optimized caching for path resolution
5. Add detailed error reporting for path resolution failures

The implementation should:
- Check if an identifier is a path (starts with 'ui:')
- Use path-based resolution for paths
- Fall back to existing methods for legacy identifiers
- Prioritize paths for reliability

Commit the changes with message: "Enhance UIInteractionService with path-based element lookup"
```

## Phase 3: Tools and API Surface

### 🔲 Step 6: Update InterfaceExplorerTool for Path Output

**Prompt for LLM agent:**
```
Update InterfaceExplorerTool to include path information in element descriptions. Follow TDD:

1. Write tests in InterfaceExplorerToolTests.swift
2. Update ElementDescriptor to include a path field
3. Modify InterfaceExplorerTool to generate paths for all returned elements
4. Add a helper method to generate paths for the explored elements
5. Include parent hierarchy information to help users understand element context

The tool should:
- Generate complete application-rooted paths for elements
- Include the path in ElementDescriptor responses
- Provide helper methods to navigate up/down the element hierarchy

Commit the changes with message: "Update InterfaceExplorerTool to include element paths"
```

### 🔲 Step 7: Update UIInteractionTool to Document Path Support

**Prompt for LLM agent:**
```
Update UIInteractionTool to document and support path-based element identifiers. Follow TDD:

1. Write tests in UIInteractionToolTests.swift for path-based interactions
2. Update the tool documentation to explain path syntax and usage
3. Add examples of path-based interactions to the documentation
4. Update error messages to be more helpful with paths
5. Add a parameter to allow users to specify whether to use paths or legacy IDs

Make sure the API documentation clearly explains:
- The path syntax and format
- How to create paths for elements
- Best practices for creating reliable paths
- How to debug path resolution issues

Commit the changes with message: "Update UIInteractionTool with path support documentation"
```

## Phase 4: Testing Infrastructure

### 🔲 Step 8: Create Path Testing Utilities

**Prompt for LLM agent:**
```
Create testing utilities to make path-based testing easier. Follow TDD:

1. Add a new file Tests/MacMCPTests/TestFramework/PathTestHelper.swift
2. Implement utilities for common path-based operations:
   - `findElementByPath(_ path: String) async throws -> UIElement?`
   - `clickElementByPath(_ path: String) async throws`
   - `typeTextInElementByPath(_ path: String, text: String) async throws`
   - `verifyElementExistsByPath(_ path: String) async throws -> Bool`
3. Add methods to generate paths for common UI elements
4. Create methods to find common elements with partial paths

The test helpers should make it easy to:
- Find elements using paths in tests
- Generate paths for discovered elements
- Interact with elements using paths
- Validate element properties using paths

Commit the changes with message: "Add path-based testing utilities"
```

### 🔲 Step 9: Update Application Models

**Prompt for LLM agent:**
```
Update application test models to use paths instead of direct element identifiers. Follow TDD:

1. Update Tests/MacMCPTests/TestFramework/ApplicationModels/CalculatorModel.swift with path constants
2. Update Tests/MacMCPTests/TestFramework/ApplicationModels/TextEditModel.swift with path constants
3. Replace direct element ID references with path-based references
4. Create tests that verify these paths resolve correctly
5. Add helper methods to generate common paths

For example, change:
```swift
static let button1ID = "ui:AXButton:123456"
```

To:
```swift
static let button1Path = "ui://AXWindow/AXGroup/AXButton[@description=\"1\"]"
```

Commit the changes with message: "Update application models to use path-based identifiers"
```

### 🔲 Step 10: Create Integration Tests

**Prompt for LLM agent:**
```
Create comprehensive integration tests for path-based element interactions. Follow TDD:

1. Create a new file Tests/MacMCPTests/ElementPathIntegrationTests.swift
2. Write tests that verify paths work with real applications:
   - Test Calculator button paths
   - Test TextEdit text area paths
   - Test Safari web element paths
3. Add tests that verify complex path selectors (attributes, indices)
4. Create tests for handling dynamic UIs where paths might change
5. Develop tests for error conditions and recovery

These tests should verify that:
- Paths can uniquely identify elements across application launches
- Path resolution is reliable even with UI changes
- Performance is acceptable for path resolution
- Error handling provides useful diagnostic information

Commit the changes with message: "Add integration tests for path-based element interaction"
```

## Phase 5: Documentation and Examples

### 🔲 Step 11: Create Developer Documentation

**Prompt for LLM agent:**
```
Create comprehensive documentation for the path-based identification system. Include:

1. Create a new file docs/ElementPaths.md
2. Document the path syntax with examples
3. Provide best practices for creating reliable paths
4. Include examples for common applications:
   - TextEdit
   - Calculator
   - System Preferences
   - Safari
5. Add troubleshooting advice for common issues

The documentation should cover:
- Complete path syntax reference
- Element attributes that can be used in selectors
- Examples of complex paths
- How to use the InterfaceExplorerTool to discover paths
- Debug techniques for path resolution issues

Commit the changes with message: "Add comprehensive documentation for element paths"
```

### 🔲 Step 12: Update Existing Tests

**Prompt for LLM agent:**
```
Update existing tests to use the new path-based identifiers. Work through tests systematically:

1. Identify tests that use direct element identifiers
2. Convert element identifiers to paths where appropriate
3. Update test utilities to support paths
4. Add assertions to verify that paths resolve correctly
5. Update test documentation to explain path usage

Focus on:
- Test reliability improvements
- Removing position-based lookups
- Making tests more maintainable
- Documenting the path strategy

Commit the changes in logical groups with messages like:
"Update Calculator tests to use path-based identifiers"
"Update TextEdit tests to use path-based identifiers"
```

## Implementation Notes

1. **Test-First Development**: Always write tests before implementing functionality. Ensure tests fail before implementation and pass after.

2. **Commit Frequently**: Each logical chunk of work should be committed separately with clear messages.

3. **Error Handling**: Provide detailed error messages that help diagnose path resolution failures.

4. **Documentation**: Document the code thoroughly as you go, not just at the end.

5. **Performance**: Monitor and optimize performance, especially for deep path traversal.

6. **Compatibility**: While we're going all-in on paths, make sure error messages are helpful for users transitioning from the old system.

7. **Realistic Testing**: Test with real applications to ensure the solution works in practice, not just in theory.

## Design Decisions and Implementation Details

### Path Syntax

The path syntax follows a hierarchical approach similar to XPath or CSS selectors but specialized for accessibility elements:

- **Prefix**: `ui://` - Identifies that this is a path to an element
- **Segments**: `/AXRole` - Defines the accessibility role of the element
- **Attributes**: `[@attribute="value"]` - Optional attribute constraints to filter elements
- **Index**: `[n]` - Optional index to select a specific element when multiple match

### Path Resolution Strategy

The planned resolution strategy (to be implemented in Step 2):
1. Get the application element using the bundleID
2. For each path segment, resolve by:
   - Finding all children with the matching role
   - Filtering by attribute constraints
   - Selecting by index if needed

### Error Handling

A robust error handling system that provides clear diagnostic information:
- Path syntax validation errors
- Application not found errors
- Element resolution failures with context about where in the path the failure occurred

### Future Considerations

- **Caching**: Implement caching at various levels to improve performance for repeated path resolutions
- **Partial Path Resolution**: Allow resolving partial paths from a starting element, not just full paths
- **Relative Paths**: Consider supporting relative paths that don't start from the application root
