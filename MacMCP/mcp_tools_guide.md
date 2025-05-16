# MacMCP Tools Guide

This document provides an overview of the available tools in MacMCP, explaining what each tool does, when to use it, and how to interact with it effectively.

## Table of Contents

1. [UI State Tool](#ui-state-tool)
2. [Screenshot Tool](#screenshot-tool)
3. [UI Interaction Tool](#ui-interaction-tool)
4. [Open Application Tool](#open-application-tool)
5. [Window Management Tool](#window-management-tool)
6. [Menu Navigation Tool](#menu-navigation-tool)
7. [Interactive Elements Discovery Tool](#interactive-elements-discovery-tool)
8. [Element Capabilities Tool](#element-capabilities-tool)

## UI State Tool

**Tool Name:** `macos_ui_state`

### Purpose
The UI State Tool provides access to the UI hierarchy of macOS applications. It's the primary tool for inspecting the current state of UI elements on screen, helping you understand the structure of applications and discover elements for interaction.

### When to Use
- When you need to explore the UI structure of an application
- To find specific UI elements by their properties
- Before performing interactions to verify elements exist
- To check the state of elements after interactions

### Parameters
- `scope`: The scope of UI elements to retrieve (`system`, `application`, `focused`, `position`)
- `bundleId`: The bundle identifier of the application (required for `application` scope)
- `x` and `y`: Coordinates for position-based queries (required for `position` scope)
- `maxDepth`: Maximum depth of the element hierarchy to retrieve (default: 10)
- `filter`: Optional filter criteria for elements (by role or title)

### Example Usage
```json
{
  "scope": "application",
  "bundleId": "com.apple.calculator",
  "maxDepth": 5,
  "filter": {
    "role": "AXButton",
    "titleContains": "="
  }
}
```

### Tips
- Start with a focused scope when possible to reduce the amount of data returned
- Use filters to narrow down results and improve performance
- The tool returns a JSON representation of UI elements with their properties, frames, and relationships

## Screenshot Tool

**Tool Name:** `macos_screenshot`

### Purpose
The Screenshot Tool allows you to capture images of the screen, windows, or specific UI elements. It's essential for visual verification and helps LLMs see and understand the current state of the UI.

### When to Use
- When you need to visually verify the state of the UI
- To help LLMs identify UI elements by seeing them
- For capturing the result of interactions
- When text-based UI state isn't sufficient to understand the interface

### Parameters
- `region`: The region to capture (`full`, `area`, `window`, `element`)
- `x`, `y`, `width`, `height`: Coordinates and dimensions for area screenshots (required for `area` region)
- `bundleId`: The bundle identifier of the application window to capture (required for `window` region)
- `elementPath`: The path of the UI element to capture (required for `element` region)

### Example Usage
```json
{
  "region": "window",
  "bundleId": "com.apple.safari"
}
```

### Tips
- Element-based screenshots are often more precise than full-screen captures
- Screenshots are returned as base64-encoded PNG images with metadata about dimensions
- Use with UI State Tool to first identify elements you want to capture

## UI Interaction Tool

**Tool Name:** `macos_ui_interact`

### Purpose
The UI Interaction Tool allows direct interaction with UI elements. It's the primary tool for performing user actions like clicking, typing, and dragging.

### When to Use
- To click buttons, checkboxes, and other controls
- To enter text into fields
- To navigate through interfaces
- To simulate user interactions like keyboard input or dragging

### Parameters
- `action`: The interaction action to perform (`click`, `double_click`, `right_click`, `type`, `press_key`, `drag`, `scroll`)
- `elementPath`: The path of the UI element to interact with (required for most actions)
- `appBundleId`: Optional bundle ID of the application containing the element
- `x` and `y`: Coordinates for position-based clicking
- `text`: Text to type (required for `type` action)
- `keyCode`: Key code to press (required for `press_key` action)
- `targetElementPath`: Target element path for drag action (required for `drag` action)
- `direction`: Scroll direction (required for `scroll` action)
- `amount`: Scroll amount from 0.0 to 1.0 (required for `scroll` action)

### Example Usage
```json
{
  "action": "click",
  "elementPath": "ui://AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXButton[@AXTitle=\"Back\"]",
  "appBundleId": "com.apple.safari"
}
```

```json
{
  "action": "type",
  "elementPath": "ui://AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]",
  "text": "Hello, world!"
}
```

### Tips
- Get element paths first using the UI State Tool or Interactive Elements Discovery Tool
- For complex interactions, break them down into a sequence of simpler actions
- Specifying `appBundleId` can help resolve ambiguities when multiple applications are open
- Position-based clicking should be used as a last resort if element-based clicking doesn't work

## Open Application Tool

**Tool Name:** `macos_open_application`

### Purpose
The Open Application Tool allows you to launch macOS applications by bundle identifier or name. It's the starting point for interacting with applications.

### When to Use
- To start a specific application
- Before attempting to interact with an application
- When switching between different applications

### Parameters
- `bundleIdentifier`: The bundle identifier of the application to open (e.g., 'com.apple.Safari')
- `applicationName`: The name of the application to open (e.g., 'Safari')
- `arguments`: Optional array of command-line arguments to pass to the application
- `hideOthers`: Whether to hide other applications when opening this one

### Example Usage
```json
{
  "bundleIdentifier": "com.apple.safari"
}
```

```json
{
  "applicationName": "Calculator",
  "hideOthers": true
}
```

### Tips
- Prefer using bundle identifiers over application names for reliability
- The tool will return information about whether the application was successfully opened
- You can provide either bundle identifier or application name, but not both
- After opening an application, allow a short delay before interacting with it

## Window Management Tool

**Tool Name:** `macos_window_management`

### Purpose
The Window Management Tool helps you work with application windows, find the active window, or discover focused elements within windows.

### When to Use
- To get a list of all windows in an application
- To find the currently active window
- To find the focused element within a window
- When you need to work with multiple windows

### Parameters
- `action`: The action to perform (`getApplicationWindows`, `getActiveWindow`, `getFocusedElement`)
- `bundleId`: The bundle identifier of the application (required for `getApplicationWindows`)
- `includeMinimized`: Whether to include minimized windows in the results (default: true)
- `windowId`: Identifier of a specific window to target

### Example Usage
```json
{
  "action": "getApplicationWindows",
  "bundleId": "com.apple.safari"
}
```

```json
{
  "action": "getActiveWindow"
}
```

### Tips
- After getting window information, you can use the window IDs with other tools
- The active window is usually where the user is currently working
- Window management is particularly useful for applications that use multiple windows
- Use `getFocusedElement` to find the currently focused control (like a text field)

## Menu Navigation Tool

**Tool Name:** `macos_menu_navigation`

### Purpose
The Menu Navigation Tool allows exploration and interaction with application menus. It helps you find and activate menu items, which is often necessary for accessing application features.

### When to Use
- To explore available menu options in an application
- To activate commands that are only accessible through menus
- When working with applications that rely heavily on menu-based interfaces
- To perform actions that have keyboard shortcuts listed in menus

### Parameters
- `action`: The action to perform (`getApplicationMenus`, `getMenuItems`, `activateMenuItem`)
- `bundleId`: The bundle identifier of the application (required for all actions)
- `menuTitle`: Title of the menu to get items from or navigate (required for `getMenuItems` and `activateMenuItem`)
- `menuPath`: Path to the menu item to activate, using '>' as a separator (e.g., 'File > Open') (required for `activateMenuItem`)
- `includeSubmenus`: Whether to include submenus in the results when getting menu items (default: false)

### Example Usage
```json
{
  "action": "getApplicationMenus",
  "bundleId": "com.apple.safari"
}
```

```json
{
  "action": "activateMenuItem",
  "bundleId": "com.apple.safari",
  "menuPath": "File > New Window"
}
```

### Tips
- Menu navigation is often the best way to access application-specific features
- Use `getApplicationMenus` first to discover available top-level menus
- Then use `getMenuItems` to explore specific menus
- Menu paths are case-sensitive and must match exactly what's shown in the UI
- Menu items may change based on application state or context

## Interactive Elements Discovery Tool

**Tool Name:** `macos_interactive_elements`

### Purpose
The Interactive Elements Discovery Tool helps find interactive UI elements like buttons, text fields, and checkboxes within applications. It's particularly useful for discovering controls without knowing the exact UI structure.

### When to Use
- To find all interactive controls in an application or window
- When exploring an unfamiliar interface
- To discover elements that can be interacted with
- When you need to filter elements by type (buttons, text fields, etc.)

### Parameters
- `scope`: The scope of elements to search (`application`, `window`, `element`)
- `bundleId`: The bundle identifier of the application (required for `application` and `window` scopes)
- `windowId`: The ID of the window to search (required for `window` scope)
- `elementPath`: The path of the element to search within (required for `element` scope)
- `types`: Types of interactive elements to find (e.g., `button`, `checkbox`, `textfield`, etc., or `any` for all types)
- `maxDepth`: Maximum depth to search (default: 10)
- `includeHidden`: Whether to include hidden elements (default: false)
- `limit`: Maximum number of elements to return (default: 100)
- `filter`: Filter criteria for elements (like title or value content)

### Example Usage
```json
{
  "scope": "application",
  "bundleId": "com.apple.calculator",
  "types": ["button"],
  "filter": {
    "titleContains": "="
  }
}
```

### Tips
- Use this tool when you're not sure what elements are available
- Combine with UI State Tool for a more comprehensive view of the UI
- Narrow your search with types and filters to get more relevant results
- Searching within a specific window or element is faster than searching the entire application

## Element Capabilities Tool

**Tool Name:** `macos_element_capabilities`

### Purpose
The Element Capabilities Tool provides detailed information about what actions can be performed on a specific UI element. It helps you understand how to interact with elements and what properties they have.

### When to Use
- To understand what actions are possible on a specific element
- Before attempting to interact with a complex UI control
- To debug why an interaction isn't working as expected
- To get detailed properties of an element

### Parameters
- `elementPath`: The path of the element to get capabilities for
- `bundleId`: The bundle identifier of the application containing the element
- `includeChildren`: Whether to include children in the result (default: false)
- `childrenDepth`: Depth of children to include if includeChildren is true (default: 1)

### Example Usage
```json
{
  "elementPath": "ui://AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXButton[@AXTitle=\"Back\"]",
  "bundleId": "com.apple.safari",
  "includeChildren": true
}
```

### Tips
- Use this tool after finding an element with UI State Tool or Interactive Elements Discovery Tool
- The capabilities list tells you what actions are supported (clickable, editable, toggleable, etc.)
- Check the actions list for specific accessibility actions that can be triggered
- Including children helps understand complex controls that have nested elements
- The attributes dictionary contains raw accessibility attributes that can provide additional insights

## Best Practices for Using MCP Tools

1. **Start with UI State or Interactive Elements** to discover elements before interacting with them.
2. **Use element paths rather than coordinates** whenever possible for more reliable interactions.
3. **Chain tools together** in a logical sequence: open application → get UI state → interact with elements.
4. **Verify after interactions** using screenshots or UI state checks.
5. **Use the most specific scope possible** to improve performance and reduce data volume.
6. **Prefer bundle identifiers over application names** for more reliable application targeting.
7. **Break complex interactions into smaller steps** and verify success at each step.
8. **Use menu navigation for application-specific functions** that aren't directly accessible in the UI.

## Common Tool Sequences

### Basic Interaction Flow
1. Open application with **Open Application Tool**
2. Find element with **UI State Tool** or **Interactive Elements Discovery Tool**
3. Interact with element using **UI Interaction Tool**
4. Verify result with **Screenshot Tool** or **UI State Tool**

### Working with Menus
1. Open application with **Open Application Tool**
2. Get available menus with **Menu Navigation Tool** (getApplicationMenus)
3. Get menu items with **Menu Navigation Tool** (getMenuItems)
4. Activate menu item with **Menu Navigation Tool** (activateMenuItem)

### Complex UI Exploration
1. Open application with **Open Application Tool**
2. Get window information with **Window Management Tool**
3. Find interactive elements with **Interactive Elements Discovery Tool**
4. Check element capabilities with **Element Capabilities Tool**
5. Interact with elements using **UI Interaction Tool**

## Troubleshooting

If you encounter issues using MCP tools, try these approaches:

1. **Check if the element exists** using UI State Tool before attempting interaction
2. **Verify element capabilities** to ensure the action you're trying is supported
3. **Take a screenshot** to visually verify the UI state
4. **Try different scopes or search methods** if you can't find an element
5. **Break complex actions into simpler steps** if interactions aren't working
6. **Check for application-specific behaviors** that might affect interactions
7. **Ensure accessibility permissions** are properly configured for MacMCP