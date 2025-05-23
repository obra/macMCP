# MacMCP Style Guide and Architecture Conventions

## File Organization and Size Management

### File Size Guidelines
- **Maximum file size**: 500 lines of code (excluding comments and whitespace)
- **Preferred file size**: 200-300 lines of code
- **Critical threshold**: Files over 1000 lines require immediate refactoring

### File Organization Patterns

#### 1. Extensions in Separate Files
When a class grows large, extract related functionality into extensions:

```swift
// ApplicationService.swift (core implementation)
// ApplicationService+WindowManagement.swift
// ApplicationService+MenuNavigation.swift
// ApplicationService+ProcessManagement.swift
```

**Naming Convention**: `BaseType+CategoryName.swift`

#### 2. Protocol-Driven Architecture
Break large classes into focused protocols implemented by smaller classes:

```swift
// Instead of one 2000-line service:
protocol WindowManaging {
    func moveWindow(id: String, to point: CGPoint) async throws
    func resizeWindow(id: String, to size: CGSize) async throws
}

protocol MenuNavigating {
    func getMenuItems(for bundleId: String) async throws -> [MenuItem]
    func activateMenuItem(path: ElementPath) async throws
}

// Implement in focused classes:
class WindowManager: WindowManaging { /* 200 lines */ }
class MenuNavigator: MenuNavigating { /* 150 lines */ }
```

#### 3. Value Types and Data Models
Extract complex data structures into their own files:

```swift
// Models/WindowConfiguration.swift
// Models/MenuHierarchy.swift
// Models/ElementPathComponents.swift
```

#### 4. Static Content Separation
For tools with large static content (like OnboardingTool):

- **JSON/Plist files**: For structured data
- **String constant files**: For large text blocks
- **Template files**: For documentation templates
- **Separate Swift files**: For different content categories

Example:
```swift
// Tools/OnboardingTool/OnboardingContent.swift
// Tools/OnboardingTool/OnboardingTemplates.swift
// Tools/OnboardingTool/resources/workflow_templates.json
```

## Architecture Patterns

### Service Architecture
- **Core Services**: Handle fundamental system interactions
- **Tool Services**: Implement MCP tool functionality
- **Utility Services**: Provide cross-cutting concerns

### Dependency Injection
Use protocol-based dependency injection for testability:

```swift
class UIInteractionTool {
    private let accessibilityService: AccessibilityServiceProtocol
    private let applicationService: ApplicationServiceProtocol
    
    init(
        accessibilityService: AccessibilityServiceProtocol,
        applicationService: ApplicationServiceProtocol
    ) {
        self.accessibilityService = accessibilityService
        self.applicationService = applicationService
    }
}
```

### Error Handling
- Use Swift's Result type for operations that can fail
- Implement custom error types for domain-specific errors
- Leverage the centralized ErrorHandling utilities

### Async/Await Patterns
- Prefer async/await over completion handlers
- Use TaskGroup for concurrent operations
- Implement proper cancellation handling

## Code Organization Within Files

### File Structure Template
```swift
// ABOUTME: Brief description of what this file does
// ABOUTME: Additional context if needed

import Foundation
// Other imports

// MARK: - Types and Protocols

// MARK: - Main Implementation

// MARK: - Private Extensions

// MARK: - Helper Types (if small)
```

### Method Organization
Within classes, organize methods in this order:
1. Initializers
2. Public interface methods
3. Internal methods
4. Private methods
5. Protocol conformance (in extensions)

### Property Organization
1. Public properties
2. Internal properties
3. Private properties
4. Computed properties

## Naming Conventions

### Files
- **Classes/Structs**: `ClassName.swift`
- **Extensions**: `ClassName+CategoryName.swift`
- **Protocols**: `ProtocolNameProtocol.swift` or `ProtocolNaming.swift`
- **Utilities**: `UtilityName.swift`

### Types
- **Classes**: `PascalCase`
- **Protocols**: `PascalCase` with descriptive names
- **Enums**: `PascalCase`
- **Cases**: `camelCase`

### Methods and Properties
- **Methods**: `camelCase` with descriptive verbs
- **Properties**: `camelCase` with descriptive nouns
- **Boolean properties**: Use `is`, `has`, `can`, `should` prefixes

## Refactoring Strategies

### When to Refactor
- File exceeds 500 lines
- Class has more than 10 methods
- Method exceeds 50 lines
- Cyclomatic complexity is high
- Code duplication exists

### Refactoring Priorities
1. **High Priority**: Files > 1500 lines
2. **Medium Priority**: Files > 800 lines
3. **Low Priority**: Files > 500 lines

### Safe Refactoring Steps
1. Ensure all tests pass
2. Create feature branch
3. Refactor incrementally
4. Run tests after each change
5. Commit frequently with descriptive messages

## Testing Considerations

### Test File Organization
- Mirror source structure in test directory
- One test file per source file
- Use descriptive test class names
- Group related tests with `// MARK:` comments

### Mocking Strategy
- Never implement mocks within the main codebase
- Use protocol-based dependency injection for testability
- Prefer integration tests with real macOS APIs

## Documentation Standards

### Code Comments
- Use `// MARK:` for section organization
- Document complex algorithms
- Explain "why" not "what"
- Keep comments up-to-date with code changes

### File Headers
All files must start with:
```swift
// ABOUTME: Brief description of what this file does
// ABOUTME: Additional context about the file's purpose
```

This makes files easily searchable and provides immediate context.

## Legacy Code Migration

### Incremental Approach
1. Identify extraction candidates
2. Create protocols for new interfaces
3. Extract functionality gradually
4. Maintain backward compatibility during transition
5. Remove deprecated code once migration is complete

### Backward Compatibility
- Use `@available` annotations for deprecations
- Provide migration guides in comments
- Maintain existing public APIs during transition periods