# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacMCP is a Model Context Protocol (MCP) server that exposes macOS accessibility APIs to Large Language Models (LLMs) over the stdio protocol. It allows LLMs like Claude to interact with macOS applications using the same accessibility APIs available to users, enabling them to perform user-level tasks such as browsing the web, creating presentations, working with spreadsheets, or using messaging applications.


This  is the REAL APP. We never use mocks. not in the code, not in the tests
our tests have access to a live macos UI. we can interact with the ui in tests


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
# Run all tests (serialized execution)
cd MacMCP
swift test --no-parallel

# Run specific test
swift test --filter MacMCPTests.BasicArithmeticE2ETests/testAddition --no-parallel

# Run tests with verbose output
swift test --verbose --no-parallel

# Run tests with a specific number of workers (when parallel execution is needed for non-UI tests)
swift test --num-workers 1

# Run tests with code coverage
swift test --no-parallel --enable-code-coverage
```

### Accessibility Permissions
The MCP server automatically checks all required permissions at startup and displays a native macOS dialog to guide users through granting any missing permissions. No manual checking is required.

### Using the Accessibility Inspector Tools

#### Native Accessibility Inspector (Direct API Access)
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

#### MCP-Based Accessibility Inspector (Uses MCP Tools) - PREFERRED METHOD
```bash
# Navigate to the MacMCP directory
cd MacMCP

# Build the tool
swift build

# Run the tool to inspect an application by bundle ID (shows what the MCP server "sees")
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP

# Filter output to show only buttons
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "role=AXButton"

# Find elements by description (useful for finding numeric buttons in Calculator)
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "description=1"

# Other filtering options work the same as the native inspector
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --show-window-contents
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --hide-invisible

# Save output to a file
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --save output.txt

# Limit the tree depth for large applications
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --max-depth 5

# NEW: Display detailed menu structure - shows all application menus
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --menu-detail

# NEW: Get items for a specific menu
./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --menu-path "File"

# NEW: Get detailed window information
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --window-detail

# NEW: Combine multiple options for comprehensive inspection
./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --menu-detail --window-detail --max-depth 3
```

#### Choosing Between the Inspectors

While both accessibility inspectors provide valuable insights, the **MCP-based inspector** is now the **preferred tool**:

1. **Native Inspector (`ax-inspector`)**
   - Provides a complete view of the accessibility tree directly from macOS APIs
   - Shows all native attributes without any processing
   - Only useful when you need to see the raw API perspective, which is rarely needed

2. **MCP-Based Inspector (`mcp-ax-inspector`) - RECOMMENDED**
   - Shows exactly what the MCP server sees and provides to LLMs
   - Essential for writing tests that use MCP
   - Helps debug issues where MCP interactions may not match direct API behaviors
   - More accurately reflects the state that Claude or other LLMs will work with
   - **Enhanced with menu and window inspection capabilities**
   - Provides better information about element capabilities and states
   - Uses the same InterfaceExplorerTool that the MCP server uses

When to use which:
- **Always start with the MCP-based inspector** - it shows you what the MCP actually sees
- Only use the native inspector if you're specifically debugging discrepancies between the raw accessibility APIs and the MCP's interpretation
- The MCP-based inspector is the required choice when creating test fixtures, as it shows the exact element IDs and structure that the MCP tools will work with
- The menu and window inspection features of the MCP-based inspector are essential for debugging menu navigation and window management issues

## Code Architecture

### Core Components

1. **MCPServer** (`MCPServer.swift`): The central server class that initializes the MCP server, registers tools, and handles accessibility permissions.

2. **Accessibility Services**:
   - `AccessibilityService`: Core service for interacting with macOS accessibility APIs
   - `ScreenshotService`: Takes screenshots of the screen or specific UI elements
   - `UIInteractionService`: Performs UI interactions like clicking and typing
   - `ApplicationService`: Launches and manages macOS applications

3. **MCP Tools**:
   - `InterfaceExplorerTool`: Enhanced UI exploration with state and capabilities information (replaces UIStateTool)
   - `ScreenshotTool`: Takes screenshots of the screen or UI elements
   - `UIInteractionTool`: Interacts with UI elements (clicking, typing, scrolling)
   - `ApplicationManagementTool`: Manages application lifecycle (launch, terminate, query status)
   - `WindowManagementTool`: Manages application windows (move, resize, minimize, maximize)
   - `MenuNavigationTool`: Navigates application menus and activates menu items
   - `KeyboardInteractionTool`: Executes keyboard shortcuts and types text
   - `ClipboardManagementTool`: Manages clipboard content including text and images

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

#### Test Serialization

Since our tests interact with the UI, they must be run serially to avoid conflicts:

1. **Test Classes**: Use `@Suite(.serialized)` annotation to ensure tests within a class run serially
2. **Test Execution**: Use `--no-parallel` flag when running `swift test` to ensure all tests run serially
3. **XCTSerialSuites.txt**: This file at the package root lists test suites that should always run serially

See `docs/Testing.md` for full details on our testing approach and practices.

## Accessibility Inspection

### Accessibility Inspector Tools Overview

MacMCP provides two different accessibility inspector tools:

1. **Native Inspector (`ax-inspector`)**: Directly uses macOS accessibility APIs to provide comprehensive information about UI elements.

2. **MCP-Based Inspector (`mcp-ax-inspector`)**: Uses the MCP server to inspect applications, showing exactly what the MCP tools can see and work with.

These inspector tools are invaluable for:

1. **Discovering Element Identifiers**: Find the exact identifiers, roles, and attributes of UI elements for use in tests and MCP tools.
2. **Understanding UI Hierarchy**: Visualize how elements are organized in the accessibility tree.
3. **Debugging UI Interactions**: Identify why certain elements might not be interactive or visible.
4. **Test Development**: Create more precise element selectors for automated tests. When writing tests using the MCP tools, the MCP-based inspector (`mcp-ax-inspector`) is particularly useful as it shows exactly the same view of the UI that the MCP server will provide to the tools.

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

1. Run the MCP-based inspector on your target application:
   ```bash
   # Always use the MCP-based inspector for MCP tools and tests:
   ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP
   ```

2. Look for elements with the identifier, role, or description you need:
   ```bash
   # Find all buttons
   ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "role=AXButton"

   # Find elements with specific descriptions
   ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "description=1"

   # Find elements with specific identifiers
   ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "id=Equals"
   ```

3. For menu-related testing, use the new menu inspection features:
   ```bash
   # Get full menu structure of the application
   ./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --menu-detail

   # Get items for a specific menu
   ./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --menu-path "File"
   ```

4. For window-related testing, use the window inspection features:
   ```bash
   # Get all windows and their properties
   ./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --window-detail
   ```

5. Use the identified properties in your MCP tools:
   - For InterfaceExplorerTool (formerly UIStateTool): Use the role, identifier, or description
   - For UIInteractionTool: Use the identifier for precise targeting
   - For MenuNavigationTool: Use the menu item identifiers from the menu structure output
   - For WindowManagementTool: Use the window IDs from the window information output

   **Important**: The MCP-based inspector with its menu and window inspection features shows you the exact element identifiers that the MCP tools use, making it essential when developing tests for MCP-based workflows.

### Tips for Effective Use

The MCP-based inspector provides a rich set of options for exploring UI hierarchies:

#### Basic Filtering and Display Options:
- Use `--show-window-contents` to focus on the main UI elements and exclude menus and controls
- Use `--hide-invisible` to reduce clutter in output
- Use `--filter "role=X"` to find elements with specific roles
- Use `--filter "description=X"` to find elements with specific descriptions
- Save output to a file for analysis: `--save output.txt`
- Use `--max-depth` (e.g., 3-5) for large applications to prevent overwhelming output

#### Advanced Features:
- Use `--menu-detail` to see all application menus (essential for MenuNavigationTool)
- Use `--menu-path "MenuName"` to explore specific menu contents
- Use `--window-detail` to see all windows and their properties (essential for WindowManagementTool)
- Combine multiple options for comprehensive inspection (e.g., `--menu-detail --window-detail --max-depth 3`)

#### Best Practices:
- Always include the `--mcp-path` parameter pointing to your MacMCP executable
- Check if elements are Enabled, Visible, and have the right Capabilities
- Look at the State section to determine element interactability
- The Capabilities field shows high-level interaction capabilities like "clickable" and "editable"
- The Actions field shows low-level accessibility actions that can be performed
- When debugging menu navigation issues, always use `--menu-detail` to verify menu structure
- When debugging window management issues, always use `--window-detail` to verify window IDs

## Important Development Notes

1. **NEVER Implement Mocks**: NEVER implement mocks for system behavior inside the MCP server. It is better to have a hard failure than to serve up mocked data. The server must always interact with the real macOS accessibility APIs and never simulate or fake functionality.

2. **Accessibility Permissions**: The app requires accessibility permissions to function correctly. The MCP server automatically detects missing permissions at startup and displays a native macOS dialog to guide users through granting them. The permissions are granted to the host process (e.g., Terminal, Claude.app, or other LLM host applications).

3. **Error Handling**: Use the provided error handling utilities in `ErrorHandling.swift` for consistent error reporting.

4. **Logging**: Use the Swift Logging framework for consistent logging throughout the codebase.

5. **Action Logging**: The `ActionLogger.swift` utility provides structured logging of accessibility actions.

6. **Testing Approach**: When writing tests, prefer end-to-end tests with real applications over mock-based tests to ensure the accessibility features work correctly.

7. **Synchronization**: When working with UI elements, ensure proper synchronization and waiting for UI updates, especially in tests.

8. **Proper tool implementation**: When implementing new tools, follow the pattern in existing tools like `UIStateTool.swift` and register them in `MCPServer.swift`.