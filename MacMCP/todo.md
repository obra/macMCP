# MacMCP Project Todo List

## Completed Tasks
- ✅ Extend frame detection to handle all frame information types
- ✅ Add fallback mechanisms for zero-size frames
- ✅ Implement MacMCP tools testing framework with direct tool invocation
- ✅ Create application drivers for Calculator, TextEdit, and Safari
- ✅ Implement TestLogHandler for capturing log messages during tests
- ✅ Develop UI state verification for test results
- ✅ Create element criteria matching for test verification
- ✅ Implement ScreenshotVerifier for verifying screenshot properties
- ✅ Add tests for screenshot verification functionality (basic and advanced tests)
- ✅ Extend ToolInvoker with support for all MacMCP tools
- ✅ Create standalone element testing framework (with example button test)
- ✅ Discover bug in element identification with zero frame coordinates

## High Priority Tasks
- ⬜ Implement multiple app detection strategies (bundle ID, name, partial matching)
- ⬜ Improve focus tracking with multiple detection methods
- ⬜ Implement multiple interaction methods (AX actions, mouse, keyboard)
- ⬜ Add pre-launch validation (verify app exists, check if running)
- ⬜ Implement post-launch verification (wait for initialization, verify window creation)
- ⬜ Develop application state observer to track running applications
- ⬜ Implement hierarchical frame inference (derive child positions from parents)
- ⬜ Support identifying elements by visible text
- ⬜ Enhance menu navigation with retry logic and robust discovery
- ⬜ Improve window management with caching and multiple lookup methods
- ⬜ Fix bug with elements reporting zero frame coordinates (affects clickability)
- ⬜ Implement InteractionVerifier for testing framework

## Medium Priority Tasks
- ⬜ Implement an intelligent element cache with fingerprinting
- ⬜ Create tool metadata system for validation and documentation
- ⬜ Implement comprehensive schema-based parameter validation
- ⬜ Develop error classification system with consistent codes
- ⬜ Enhance error logging with detailed context
- ⬜ Develop interaction verification to validate results
- ⬜ Add automatic retries with exponential backoff for failed interactions
- ⬜ Enhance timing management with UI stabilization waits
- ⬜ Expand unit test coverage for all tools
- ✅ Implement integration tests with real applications
- ⬜ Test with diverse applications (system apps, third-party apps)
- ⬜ Create comprehensive API documentation
- ⬜ Enhance logging with structured logs and context
- ⬜ Add support for xpath-like element paths
- ⬜ Enhance UI tree traversal with fuzzy matching
- ⬜ Add element relationship tracking (parent-child, siblings, spatial)
- ⬜ Develop parameter preprocessor to normalize inputs
- ⬜ Add context-aware recovery suggestions for common errors
- ⬜ Implement self-healing mechanisms (auto-retry, fallbacks)
- ⬜ Implement a focus manager with history and restoration
- ⬜ Develop context-aware operations that work without focus
- ⬜ Enhance window identification with fuzzy matching
- ⬜ Implement adaptive timing based on application responsiveness
- ⬜ Develop element state prediction for validation
- ⬜ Create regression test suite for previously fixed issues
- ⬜ Implement continuous integration with test coverage tracking
- ⬜ Create more comprehensive application-specific test examples
- ⬜ Implement self-documenting tools with discovery
- ⬜ Develop debugging utilities (UI hierarchy explorer, element inspector)

## Testing Framework Next Steps
- ✅ Implement ScreenshotVerifier for validating screenshots
- ⬜ Implement InteractionVerifier for validating UI interactions
- ✅ Add support for all tools in ToolInvoker
- ⬜ Create comprehensive test suite using the new framework
- ⬜ Fix warning messages in driver implementations
- ⬜ Improve calculator button detection for more reliable tests (fix zero-frame bug)
- ⬜ Add detailed documentation for testing framework components
- ⬜ Migrate existing E2E tests to use the new framework
- ⬜ Fix element-level screenshot testing to properly handle element identification
- ⬜ Add more robust methods to verify button coordinates and presence