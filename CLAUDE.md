# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacMCP is a Model Context Protocol (MCP) server that exposes macOS accessibility APIs to Large Language Models (LLMs) over the stdio protocol. It allows LLMs like Claude to interact with macOS applications using the same accessibility APIs available to users, enabling them to perform user-level tasks such as browsing the web, creating presentations, working with spreadsheets, or using messaging applications.

## Build and Development Commands

### Building the Project
```bash
# Navigate to the MacMCP directory
cd MacMCP

# Build the project (debug build)
swift build

# Build the project (release build)
swift build -c release
```

### Running the Project
```bash
# Direct execution (for debugging)
./.build/debug/MacMCP

# Run with arguments
./.build/debug/MacMCP --debug

# Use the wrapper script for Claude desktop integration
../mcp-macos-wrapper.sh
```

### Testing
```bash
# Run all tests
cd MacMCP
swift test

# Run specific test
swift test --filter MacMCPTests.BasicArithmeticE2ETests/testAddition

# Run tests with verbose output
swift test --verbose
```

### Checking Accessibility Permissions
```bash
# Check if the app has the required accessibility permissions
swift run --package-path MacMCP check_permissions.swift
```

## Code Architecture

### Core Components

1. **MCPServer** (`MCPServer.swift`): The central server class that initializes the MCP server, registers tools, and handles accessibility permissions.

2. **Accessibility Services**:
   - `AccessibilityService`: Core service for interacting with macOS accessibility APIs
   - `ScreenshotService`: Takes screenshots of the screen or specific UI elements
   - `UIInteractionService`: Performs UI interactions like clicking and typing
   - `ApplicationService`: Launches and manages macOS applications

3. **MCP Tools**:
   - `UIStateTool`: Gets the current UI state of applications
   - `ScreenshotTool`: Takes screenshots
   - `UIInteractionTool`: Interacts with UI elements
   - `OpenApplicationTool`: Opens macOS applications
   - `WindowManagementTool`: Manages application windows
   - `MenuNavigationTool`: Navigates application menus
   - `InteractiveElementsDiscoveryTool`: Discovers interactive UI elements
   - `ElementCapabilitiesTool`: Determines what actions can be performed on elements

4. **Models**:
   - `UIElement`: Represents a UI element with accessibility properties
   - `ElementDescriptor`: Describes a UI element for serialization

### Entry Points

- `main.swift`: The primary entry point that starts the server with stdio transport
- `mcp-macos-wrapper.sh`: A wrapper script that runs the server with logging for debugging

### Testing

The project includes end-to-end tests that use the macOS Calculator app to validate that the accessibility interactions work correctly. The test architecture includes:

- `CalculatorApp.swift`: A wrapper for the Calculator app used in tests
- `CalculatorElementMap.swift`: Maps of Calculator UI elements for testing
- `BasicArithmeticE2ETests.swift`: Tests basic arithmetic operations
- `KeyboardInputE2ETests.swift`: Tests keyboard input
- `ScreenshotE2ETests.swift`: Tests screenshot functionality
- `UIStateInspectionE2ETests.swift`: Tests UI state inspection

## Important Development Notes

1. **NEVER Implement Mocks**: NEVER implement mocks for system behavior inside the MCP server. It is better to have a hard failure than to serve up mocked data. The server must always interact with the real macOS accessibility APIs and never simulate or fake functionality.

2. **Accessibility Permissions**: The app requires accessibility permissions to function correctly. During testing, ensure these permissions are granted in System Settings > Privacy & Security > Accessibility.

3. **Error Handling**: Use the provided error handling utilities in `ErrorHandling.swift` for consistent error reporting.

4. **Logging**: Use the Swift Logging framework for consistent logging throughout the codebase.

5. **Action Logging**: The `ActionLogger.swift` utility provides structured logging of accessibility actions.

6. **Testing Approach**: When writing tests, prefer end-to-end tests with real applications over mock-based tests to ensure the accessibility features work correctly.

7. **Synchronization**: When working with UI elements, ensure proper synchronization and waiting for UI updates, especially in tests.

8. **Proper tool implementation**: When implementing new tools, follow the pattern in existing tools like `UIStateTool.swift` and register them in `MCPServer.swift`.