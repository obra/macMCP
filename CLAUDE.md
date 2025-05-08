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

### Using the Accessibility Inspector Tool
```bash
# Navigate to the MacMCP directory
cd MacMCP

# Build the tool
swift build

# Run the tool to inspect an application by bundle ID
./.build/debug/ax-inspector --app-id com.apple.calculator

# Run the tool to inspect an application by process ID
./.build/debug/ax-inspector --pid 12345

# Filter output to show only specific UI component types
./.build/debug/ax-inspector --app-id com.apple.calculator --show-menus
./.build/debug/ax-inspector --app-id com.apple.calculator --show-window-controls
./.build/debug/ax-inspector --app-id com.apple.calculator --show-window-contents

# Hide invisible or disabled elements
./.build/debug/ax-inspector --app-id com.apple.calculator --hide-invisible --hide-disabled

# Save the output to a file
./.build/debug/ax-inspector --app-id com.apple.calculator --save output.txt

# Apply custom property filters
./.build/debug/ax-inspector --app-id com.apple.calculator --filter "role=button"
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

## Accessibility Inspection

### Accessibility Inspector Tool Overview

The Accessibility Inspector Tool (`ax-inspector`) is a utility for exploring and understanding the accessibility tree of macOS applications. It's invaluable for:

1. **Discovering Element Identifiers**: Find the exact identifiers, roles, and attributes of UI elements for use in tests and MCP tools.
2. **Understanding UI Hierarchy**: Visualize how elements are organized in the accessibility tree.
3. **Debugging UI Interactions**: Identify why certain elements might not be interactive or visible.
4. **Test Development**: Create more precise element selectors for automated tests.

### Understanding the Output

The inspector provides detailed information about each UI element, organized into sections:

- **Identification**: Basic information like role, identifier, and description
- **State**: A comma-separated list of element states (Enabled/Disabled, Visible/Invisible, etc.)
- **Geometry**: Position and size information
- **Relationships**: Parent-child relationships and hierarchy information
- **Interactions**: Available actions like AXPress, AXFocus, etc.
- **Attributes**: All accessibility attributes exposed by the element

Example output for a button:
```
[24] AXButton: Untitled
   Identifier: Three
   Frame: (x:360, y:561, w:40, h:40)
   State: Enabled, Visible, Clickable, Unfocused, Unselected
   Role: AXButton (button)
   Description: 3
   Relationships: Children: 0, Has Parent, Has Window
   Actions: AXPress

   Additional Attributes:
      AXActivationPoint: (380, 581)
      AXAutoInteractable: 0
      AXPath: [Element reference]
```

### Finding Elements for Tests and MCP Tools

To find the correct element selectors for interacting with UI elements:

1. Run the inspector on your target application:
   ```bash
   ./.build/debug/ax-inspector --app-id com.apple.calculator
   ```

2. Look for elements with the identifier, role, or description you need:
   ```bash
   # Find all buttons
   ./.build/debug/ax-inspector --app-id com.apple.calculator --filter "role=button"
   
   # Find elements with specific identifiers
   ./.build/debug/ax-inspector --app-id com.apple.calculator --filter "identifier=equals"
   ```

3. Use the identified properties in your MCP tools:
   - For UIStateTool: Use the role, identifier, or description
   - For UIInteractionTool: Use the identifier for precise targeting
   - For MenuNavigationTool: Note the menu item identifiers and structure

### Tips for Effective Use

- Use `--show-window-contents` to focus on the main UI elements and exclude menus and controls
- Use `--show-menus` to explore available menu items and their identifiers
- Use `--hide-invisible` to reduce clutter in output
- Save complex hierarchies to a file for further analysis: `--save output.txt`
- When debugging interaction issues, check if the element is Enabled and Visible
- Look at the available Actions to determine what operations are supported

## Important Development Notes

1. **NEVER Implement Mocks**: NEVER implement mocks for system behavior inside the MCP server. It is better to have a hard failure than to serve up mocked data. The server must always interact with the real macOS accessibility APIs and never simulate or fake functionality.

2. **Accessibility Permissions**: The app requires accessibility permissions to function correctly. During testing, ensure these permissions are granted in System Settings > Privacy & Security > Accessibility.

3. **Error Handling**: Use the provided error handling utilities in `ErrorHandling.swift` for consistent error reporting.

4. **Logging**: Use the Swift Logging framework for consistent logging throughout the codebase.

5. **Action Logging**: The `ActionLogger.swift` utility provides structured logging of accessibility actions.

6. **Testing Approach**: When writing tests, prefer end-to-end tests with real applications over mock-based tests to ensure the accessibility features work correctly.

7. **Synchronization**: When working with UI elements, ensure proper synchronization and waiting for UI updates, especially in tests.

8. **Proper tool implementation**: When implementing new tools, follow the pattern in existing tools like `UIStateTool.swift` and register them in `MCPServer.swift`.