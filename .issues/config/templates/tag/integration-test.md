# integration-test

> Test-Driven Development workflow for integration testing that verifies how components work together. Focuses on interfaces, data flow, and component interactions.

## Steps
- Write failing integration tests that verify component interactions (RED phase)
  - Focus on interfaces between components
  - Test data flow across component boundaries
  - Verify dependencies are satisfied correctly
  - Test error handling between components
- Run the integration tests and verify they fail as expected
  - Confirm the failures are due to missing implementation
  - Document specific interface requirements based on test failures
  - Verify test environment includes all required dependencies
- [ACTUAL TASK GOES HERE]
  - Implement component interfaces to satisfy tests (GREEN phase)
  - Focus on cross-component communication and data flow
  - Use real components rather than mocks when possible
- Run integration tests and verify they now pass
  - All component interactions should work correctly
  - Data should flow properly between components
  - Error conditions should be handled appropriately
- Refactor the implementation while keeping tests passing (REFACTOR phase)
  - Improve interface design and component coupling
  - Optimize data transfer between components
  - Ensure component boundaries are well-defined
- Verify component integration in the broader system context
  - Ensure changes don't break existing functionality
  - Verify performance characteristics of interactions
  - Document any integration requirements for other systems