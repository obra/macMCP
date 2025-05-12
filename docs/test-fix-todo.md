# Test Fix Todo

This document outlines the remaining test issues to fix after updating the error handling mechanism and actor isolation in the tests.


## Menu Navigation tests

- [ ] Write a basic test for menu navigation
	- open text edit
	- count the open windows
	- open the file menu
	- click on 'New' in the file menu
	- count the number of windows to make sure it has increased by one

## General Issues

- [ ] Continue migrating from `MacMCPError` to `MCPError` in any remaining files
- [ ] Ensure consistent error handling and error types across all tools and services
- [x] Fix actor isolation issues with the asynchronous test code in Calculator tests

## ClipboardManagementToolTests Issues

- [ ] Fix `testGetInfo` assertions (current assertion failures: countCheck: 0 vs 1, typeArray: 3 vs 2)
- [ ] Fix `testGetInfoError` to properly throw an error when configured to do so
- [ ] Fix `testExecuteWithInvalidAction` and `testExecuteWithMissingAction` assertions
- [ ] Fix `testSetImageMissingImageData` assertion failure
- [ ] Fix `testSetFilesMissingFilePaths` assertion failure
- [ ] Fix `testSetFilesEmptyArray` assertion failure

## ApplicationManagementE2ETests Issues

- [ ] Fix `testForceTerminate` force termination assertions
- [ ] Fix `testHideOtherApplications` assertions for hiding other applications
- [ ] Fix `testHideUnhideActivate` assertions for hiding applications

## E2E Test Framework Improvements

- [x] Create efficient pattern for sharing application instances in tests
- [x] Implement Calculator-specific test helpers with state reset logic
- [x] Implement improved Calculator tests with shared app instances
- [x] Implement TextEdit-specific test helpers with state reset logic
- [x] Implement improved TextEdit tests with shared app instances
- [ ] Create similar test helpers for other applications
- [ ] Update E2E test suite to use the shared app pattern consistently

## E2E Test Stability Issues

- [x] Reduce application launches and terminations between tests
- [x] Improve state reset between tests (clear calculator, create new document, etc.)
- [x] Add more robust waiting mechanisms for application state changes
- [x] Implement retry mechanisms for flaky UI interactions
- [x] Add proper cleanup for test applications even when tests fail
- [x] Implement better assertion helpers like the `assertDisplayValue` method
- [ ] Consider screenshot-based verification for UI state

## Mock Service Improvements

- [ ] Refactor mock services to use the same design pattern for actor isolation
- [ ] Create base mock service class with common functionality
- [ ] Implement improved actor-safe property access pattern based on MockClipboardService
- [ ] Add proper type checking and validation to mock services
- [ ] Add detailed logging to mock services for better test diagnostics

## Refactoring Opportunities

- [x] Abstract common test setup and lifecycle management code
- [x] Use proper async/await patterns in test code
- [x] Add more detailed error messages to test assertions
- [x] Implement better patterns for actor access in tests (added proper MainActor annotations)
- [x] Create helper methods for common test operations
- [x] Extract duplicate code into shared utilities

## Tools and Services Integration

- [ ] Complete the integration of `ApplicationManagementTool` throughout the codebase
- [ ] Complete the integration of `ClipboardManagementTool` throughout the codebase
- [ ] Ensure `WindowManagementTool` enhancements work correctly with the updated error handling
- [ ] Update `ToolChain` to provide access to all tools in a consistent way
- [ ] Add proper disposal and cleanup methods to all services and tools

## Documentation

- [ ] Update tool documentation to reflect the new tools and error handling
- [x] Document common testing patterns for asynchronous actor code
- [x] Add examples of how to test tools with mock services
- [x] Document the new application test helpers approach (via CalculatorTestHelper and TextEditTestHelper)
- [ ] Create a testing guide with best practices for MCP tests
- [ ] Add XML documentation to all public test APIs

## Swift Concurrency Improvements

- [x] Address actor isolation and concurrency warnings in Calculator test code
- [x] Ensure proper MainActor usage for UI-related code in Calculator tests
- [x] Fix data race issues in shared test state for Calculator tests
- [x] Implement better patterns for async setUp and tearDown in Calculator tests
- [x] Create helper utilities for handling async XCTest flows

## Recent Progress

- Created CalculatorTestHelper.swift to provide a shared interface for Calculator tests
- Fixed actor isolation issues in BasicArithmeticTest and CalculatorSmokeTest
- Implemented proper MainActor annotations for test classes
- Fixed setUp and tearDown methods to respect actor isolation
- Tests now run without data race warnings in Calculator tests
- Created TextEditTestHelper.swift for shared TextEdit test functionality
- Updated SimpleTextEditTest and TextEditFormattingTest to use the helper
- Added improved document management and state reset to TextEdit tests
- Implemented retry mechanisms and better error handling in test helpers

## Known Issues and Next Steps

- Menu navigation is still problematic in some tests; we need to investigate why the MenuNavigationTool fails to find menu items in TextEdit
- TextEdit's testSaveAndReopen test fails with element not found errors, likely due to UI focus issues with save dialogs
- We should implement a reliable mechanism for handling file dialogs consistently (save, open, etc.)
- Consider implementing a fallback mechanism where keyboard shortcuts can be used when menu navigation fails
- Need to further improve async error handling for accessibility interaction failures
- Need to standardize the test helper pattern across all application tests
- Consider creating a base ApplicationTestHelper class that can be extended for specific application tests
