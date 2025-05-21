# MacMCP Resources Specification

This document describes the resource types exposed by the MacMCP server.

## Overview

MacMCP resources provide LLMs with direct access to macOS UI elements, application information, menu structures, windows, and more. Resources are identified by URIs and follow the Model Context Protocol (MCP) resources specification.

## Resource Types

### Application Resources

#### Running Applications
- **URI**: `macos://applications`
- **Description**: List of all running applications
- **Return Type**: JSON object mapping bundle IDs to application names
- **Example**:
  ```json
  {
    "com.apple.finder": "Finder",
    "com.apple.calculator": "Calculator",
    "com.apple.safari": "Safari"
  }
  ```

#### Application Menu Structure
- **URI**: `macos://applications/{bundleId}/menus`
- **Description**: Complete menu structure for a specific application
- **Parameters**:
  - `bundleId`: The bundle identifier of the application
- **Return Type**: Array of menu descriptors
- **Example**:
  ```json
  [
    {
      "title": "File",
      "enabled": true,
      "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXMenuBar/AXMenuBarItem[@AXTitle=\"File\"]",
      "children": [
        {
          "title": "New Window",
          "enabled": true,
          "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXMenuBar/AXMenuBarItem[@AXTitle=\"File\"]/AXMenu/AXMenuItem[@AXTitle=\"New Window\"]"
        }
      ]
    },
    {
      "title": "Edit",
      "enabled": true,
      "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXMenuBar/AXMenuBarItem[@AXTitle=\"Edit\"]",
      "children": []
    }
  ]
  ```

#### Application Windows
- **URI**: `macos://applications/{bundleId}/windows`
- **Description**: List of windows for a specific application
- **Parameters**:
  - `bundleId`: The bundle identifier of the application
- **Return Type**: Array of window descriptors
- **Example**:
  ```json
  [
    {
      "title": "Untitled",
      "id": "12345",
      "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.textedit\"]/AXWindow[@AXTitle=\"Untitled\"]",
      "position": {"x": 100, "y": 100},
      "size": {"width": 800, "height": 600},
      "minimized": false,
      "main": true
    }
  ]
  ```

### UI Element Resources

#### UI Element Tree
- **URI**: `macos://ui/{uiPath}`
- **Description**: Accessibility tree for a UI element
- **Parameters**:
  - `uiPath`: The path to the UI element
  - Query Parameters:
    - `maxDepth`: Maximum depth of the tree to return (default: 10)
    - `interactable`: Set to `true` to return an array of interactable elements (default: false)
    - `limit`: Maximum number of interactable elements to return when interactable=true (default: 100)
- **Return Type**: 
  - When interactable=false: Element descriptor with children
  - When interactable=true: Array of interactable element descriptors
- **Example (normal mode)**:
  ```json
  {
    "role": "AXButton",
    "title": "OK",
    "description": "OK Button",
    "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"OK\"]",
    "enabled": true,
    "children": []
  }
  ```
- **Example (interactable=true)**:
  ```json
  [
    {
      "role": "AXButton",
      "title": "OK",
      "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"OK\"]",
      "enabled": true,
      "capabilities": ["clickable"]
    },
    {
      "role": "AXTextField",
      "title": "Search",
      "path": "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXTextField[@AXTitle=\"Search\"]",
      "enabled": true,
      "capabilities": ["editable", "focusable"]
    }
  ]
  ```

## Resource Templates

The MacMCP server supports the following resource templates:

1. **UI Element Path**:
   - Template: `macos://ui/{path}`
   - Example: `macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]`
   - Query Parameters:
     - `interactable=true` to get interactable elements
     - `maxDepth=5` to control tree depth
     - `limit=50` to limit interactable element results

2. **Application Menu**:
   - Template: `macos://applications/{bundleId}/menus`
   - Example: `macos://applications/com.apple.safari/menus`
   - Query Parameters:
     - `menuTitle=File` to get items for a specific menu
     - `includeSubmenus=true` to include submenu items

3. **Application Windows**:
   - Template: `macos://applications/{bundleId}/windows`
   - Example: `macos://applications/com.apple.textedit/windows`
   - Query Parameters:
     - `includeMinimized=false` to exclude minimized windows

## Implementation Notes

1. **Path Format**: All UI element paths use the `macos://ui/` scheme.

2. **Query Parameters**: Resources support query parameters for filtering and pagination.

3. **Performance**: Resources may implement caching to improve performance.

4. **Error Handling**: Resources return standard MCP errors for invalid paths or parameters.

5. **Resource Updates**: The current implementation does not support resource subscriptions.