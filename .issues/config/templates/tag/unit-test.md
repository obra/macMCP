# unit-test

> Test-Driven Development workflow that ensures proper unit testing before, during, and after implementation. Uses the Red-Green-Refactor cycle to build reliable code.

## Steps
- Write failing unit tests for the functionality (RED phase)
  - Focus on behavior, not implementation details
  - Test both happy paths and edge cases
  - Use descriptive test names that explain expected behavior
- Run the unit tests and verify they fail for the expected reason
  - Confirm tests fail for the right reason (not due to syntax errors)
  - Document specific test failures for verification
- [ACTUAL TASK GOES HERE]
  - Implement minimal code to pass tests (GREEN phase)
  - Focus on making tests pass, not optimization
- Run unit tests and verify they now pass
  - All tests should pass with your implementation
  - No functionality should be included beyond what's tested
- Refactor the implementation while keeping tests passing (REFACTOR phase)
  - Improve code structure and readability
  - Remove duplication and optimize where needed
  - Ensure tests still pass after each refactoring step
- Make sure test coverage meets project requirements
  - Check coverage metrics for key code paths
  - Add tests for any uncovered edge cases
