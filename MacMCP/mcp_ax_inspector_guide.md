# MCP-Based Accessibility Inspector Guide

The MCP-Based Accessibility Inspector (`mcp-ax-inspector`) is a command-line tool that provides detailed information about the UI elements in macOS applications. Unlike the standard Accessibility Inspector (`ax-inspector`), this tool uses the MacMCP tools to access the accessibility hierarchy, making it ideal for use with LLMs and ensuring consistency with other MCP-based operations.

## Building the Tool

To build the MCP-based Accessibility Inspector:

```bash
# Navigate to the MacMCP directory
cd /path/to/MacMCP

# Build the project
swift build
```

This will create the `mcp-ax-inspector` executable in the `.build/debug/` directory.

## Basic Usage

The basic command structure is:

```bash
./.build/debug/mcp-ax-inspector --app-id <bundle_identifier>
```

or

```bash
./.build/debug/mcp-ax-inspector --pid <process_id>
```

For example, to inspect the Calculator app:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator
```

## Command-Line Options

The tool supports the following options:

| Option | Description |
|--------|-------------|
| `--app-id <bundle_id>` | Specify the application by its bundle identifier |
| `--pid <process_id>` | Specify the application by its process ID |
| `--max-depth <number>` | Maximum depth to traverse in the element hierarchy (default: 150) |
| `--mcp-path <path>` | Path to the MCP server executable (default: ./.build/debug/MacMCP) |
| `--save <file_path>` | Save the output to a file |
| `--filter <property=value>` | Filter elements by property (can be used multiple times) |
| `--hide-invisible` | Hide invisible elements |
| `--hide-disabled` | Hide disabled elements |
| `--show-menus` | Only show menu-related elements |
| `--show-window-controls` | Only show window control elements |
| `--show-window-contents` | Only show window content elements |
| `--verbose` | Show more detailed information |

## Filtering Elements

You can filter the UI elements by various properties:

```bash
# Show only buttons
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --filter "role=AXButton"

# Show only visible elements
./.build/debug/mcp-ax-inspector --app-id com.apple.safari --hide-invisible

# Show only elements with a specific title
./.build/debug/mcp-ax-inspector --app-id com.apple.safari --filter "title=Safari"
```

## Focusing on UI Components

The tool includes options to focus on specific types of UI components:

```bash
# Show only menus and menu items
./.build/debug/mcp-ax-inspector --app-id com.apple.safari --show-menus

# Show only window controls (close, minimize, etc.)
./.build/debug/mcp-ax-inspector --app-id com.apple.safari --show-window-controls

# Show only window contents (the main UI elements)
./.build/debug/mcp-ax-inspector --app-id com.apple.safari --show-window-contents
```

## Saving Output

You can save the inspection results to a file:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --save calculator_ui.txt
```

## Understanding the Output

The output shows a hierarchical tree of UI elements with their properties:

```
[0] AXApplication: Calculator
   Identifier: AXApplication:12345
   Frame: (x:100, y:100, w:320, h:460)
   State: Enabled, Visible, Not clickable, Unfocused, Unselected
   Role: AXApplication (application)
   Relationships: Children: 1, Has Parent
   Additional Attributes:
      AXMainWindow: [Element reference]
      
   │
   └─+[1] AXWindow: Calculator
      Identifier: AXWindow:67890
      Frame: (x:100, y:100, w:320, h:460)
      State: Enabled, Visible, Not clickable, Unfocused, Unselected
      Role: AXWindow (window)
      Relationships: Children: 15, Has Parent
      
      │
      ├─+[2] AXButton: 7
      │  Identifier: AXButton:11111
      │  Frame: (x:120, y:200, w:60, h:60)
      │  State: Enabled, Visible, Clickable, Unfocused, Unselected
      │  Role: AXButton (button)
      │  Description: 7
      │  Relationships: Children: 0, Has Parent, Has Window
      │  Actions: AXPress
      │
      └─+[3] AXButton: +
         Identifier: AXButton:22222
         Frame: (x:260, y:200, w:60, h:60)
         State: Enabled, Visible, Clickable, Unfocused, Unselected
         Role: AXButton (button)
         Description: Add
         Relationships: Children: 0, Has Parent, Has Window
         Actions: AXPress
```

Each element entry includes:

1. **Identification**: Index, role, and title
2. **Basic info**: Identifier, frame (position/size)
3. **State**: Enabled/disabled, visible/invisible, etc.
4. **Role details**: Role and role description
5. **Relationships**: Parent-child structure
6. **Actions**: Available interactions
7. **Additional attributes**: Other accessibility properties

## How It Works

The MCP-based inspector:

1. Launches the MacMCP server process
2. Uses the `macos_ui_state` tool to retrieve UI information
3. Processes the JSON data into a hierarchical structure
4. Applies any filters or display options
5. Formats and displays the UI tree

This approach ensures consistency with other MCP-based tools and avoids direct access to the accessibility APIs.

## Differences from Standard Inspector

While the MCP-based inspector aims to provide the same information as the standard accessibility inspector, there are some differences:

1. It uses MCP tools for data collection rather than direct API access
2. The output format may vary slightly
3. Some advanced features may behave differently due to differences in API access

However, the core functionality remains the same, and both tools can be used interchangeably for most purposes.