# Test Fix Todo

This document outlines the remaining test issues to fix after updating the error handling mechanism and actor isolation in the tests.

## General Issues

- [ ] Continue migrating from `MacMCPError` to `MCPError` in any remaining files
- [ ] Ensure consistent error handling and error types across all tools and services
- [ ] Fix any more actor isolation issues with the asynchronous test code

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

## E2E Test Stability Issues

- [ ] Improve stability of E2E tests that interact with real applications
- [ ] Add more robust waiting mechanisms for application state changes
- [ ] Consider adding retry mechanisms for flaky tests
- [ ] Add proper cleanup for test applications even when tests fail

## Refactoring Opportunities

- [ ] Refactor mock services to use the same design pattern for actor isolation
- [ ] Consider abstracting common test setup and assertion code
- [ ] Add more detailed error messages to test assertions
- [ ] Implement nonisolated property wrappers to simplify actor property access in tests

## Tools and Services Integration

- [ ] Complete the integration of `ApplicationManagementTool` throughout the codebase
- [ ] Complete the integration of `ClipboardManagementTool` throughout the codebase
- [ ] Ensure `WindowManagementTool` enhancements work correctly with the updated error handling

## Documentation

- [ ] Update tool documentation to reflect the new tools and error handling
- [ ] Document common testing patterns for asynchronous actor code
- [ ] Add examples of how to test tools with mock services