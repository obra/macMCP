# e2e-test

> End-to-end testing workflow that verifies functionality in the full application context. Uses Test-Driven Development principles to ensure features work correctly from the user's perspective.

## Steps
- Write failing end-to-end test that verifies the expected behavior (RED phase)
  - Focus on user journeys and complete workflows
  - Test from the user's perspective (UI interactions, API flows)
  - Include assertions that verify the expected outcomes
  - Set up test data and environments needed for testing
- Run the test and verify it fails correctly
  - Confirm test fails because functionality doesn't exist yet
  - Document the specific failure points for verification later
  - Ensure test infrastructure is working correctly
- [ACTUAL TASK GOES HERE]
  - Implement the feature to satisfy the test requirements (GREEN phase)
  - Develop the minimal functionality needed to pass the test
  - Focus on the complete user journey, not just isolated components
- Run the end-to-end test and verify it passes
  - The complete workflow should execute successfully
  - All assertions should pass without flakiness
  - No test environment hacks or workarounds should be needed
- Refactor the implementation while maintaining test passing status (REFACTOR phase)
  - Improve performance, usability, and code structure
  - Ensure the feature integrates well with the rest of the application
  - Keep tests passing during refactoring
- Verify the feature works in the full application context
  - Test in a production-like environment if possible
  - Verify edge cases and error conditions
  - Check performance and responsiveness requirements
