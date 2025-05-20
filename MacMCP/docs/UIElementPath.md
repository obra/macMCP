# UI Element Path Documentation

## Overview

UI Element Paths provide a standardized way to identify and locate UI elements within macOS applications using the accessibility hierarchy. They offer a more stable and reliable approach to element identification compared to direct element IDs, particularly across application launches or when UI elements change position. This document covers the path syntax, usage, and best practices for working with UI Element Paths in MacMCP.

## Path Format

### Basic Syntax

UI Element Paths follow this format:

```
macos://ui/RoleType[@attribute="value"][@attribute2="value2"]/ChildRole[@attribute="value"]
```

Each component has a specific purpose:

- **`macos://ui/` prefix**: Indicates that this is a UI element path
- **Role segments**: Represent element types in the hierarchy (e.g., `AXApplication`, `AXWindow`, `AXButton`)
- **Attribute selectors**: Filter elements by their properties (`[@AXTitle="Calculator"]`)
- **Path separator**: Forward slash (`/`) separates segments in the hierarchy

### Example Paths

Here are some examples of valid UI Element Paths:

```
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow/AXButton[@AXDescription="7"]
```

```
macos://ui/AXApplication[@AXTitle="Safari"]/AXWindow/AXTextField[@AXSubrole="AXURLField"]
```

```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXWindow/AXTextArea
```

## Path Components

### Role Types

Role types represent the accessibility role of elements and typically start with the `AX` prefix:

- `AXApplication`: Top-level application
- `AXWindow`: Application window
- `AXButton`: Button control
- `AXTextField`: Text entry field
- `AXTextArea`: Multi-line text area
- `AXGroup`: Element grouping
- `AXMenu`: Menu element
- `AXMenuItem`: Menu item
- `AXCheckBox`: Checkbox control
- `AXRadioButton`: Radio button control

### Attribute Selectors

Attribute selectors filter elements by their properties and follow this format: `[@attribute="value"]`

Common attributes include:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `AXTitle` | Element's title or label | `[@AXTitle="Save"]` |
| `AXDescription` | Element's description | `[@AXDescription="Enter your name"]` |
| `AXValue` | Element's current value | `[@AXValue="Hello World"]` |
| `AXIdentifier` | Element's unique identifier | `[@AXIdentifier="submitButton"]` |
| `bundleIdentifier` | App's bundle identifier (for application elements) | `[@bundleIdentifier="com.apple.safari"]` |
| `AXSubrole` | Element's specialized role | `[@AXSubrole="AXURLField"]` |

### Index Selectors

When multiple elements match the same path, you can select a specific one using an index selector:

```
macos://ui/AXApplication[@AXTitle="Safari"]/AXWindow/AXButton[0]
```

This selects the first button in the window. Indexes are zero-based.

## Path Resolution

### How Paths Are Resolved

When resolving a path:

1. **Starting element**: Resolution begins with the application or system-wide element
2. **Traversal**: Each segment is resolved in sequence, starting from the root
3. **Matching**: Elements are matched by role first, then by attributes
4. **Selection**: If multiple elements match, the index selector (if provided) is used

### Resolution Rules

- **Role matching**: The element's role must match exactly
- **Attribute matching**: Different attributes use different matching strategies:
  - **Exact match**: For identifiers, roles, and most properties
  - **Substring match**: For titles and values (more flexible matching)
  - **Contains match**: For descriptions and help text (even more permissive)
- **Fallbacks**: If a specific attribute isn't found, related attributes may be checked

## Attribute Matching

### Match Types

The path resolution system uses different matching strategies depending on the attribute:

| Match Type | Description | Used For |
|------------|-------------|----------|
| `.exact` | Values must match exactly | `AXIdentifier`, `bundleIdentifier`, `AXRole` |
| `.contains` | Actual value can contain the expected value | `AXDescription`, `AXHelp` |
| `.substring` | Either value can contain the other | `AXTitle`, `AXValue` |
| `.startsWith` | Actual value starts with expected value | `AXFilename`, `AXName` |

### Attribute Variants

Multiple attribute name variants are supported for flexibility:

- `title` → `AXTitle`
- `description` → `AXDescription`
- `value` → `AXValue`
- `id`/`identifier` → `AXIdentifier`
- `bundleId`/`bundleID` → `bundleIdentifier`

## Best Practices

### Creating Reliable Paths

1. **Start with the application**:
   - Always begin with `AXApplication` and specify either `bundleIdentifier` or `title`
   - Example: `macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]`

2. **Use specific attributes**:
   - Include distinguishing attributes for elements
   - Prefer unique identifiers when available
   - Example: `macos://ui/AXApplication[@AXTitle="Calculator"]/AXWindow/AXButton[@AXDescription="7"]`

3. **Limit path depth**:
   - Keep paths as short as possible while maintaining uniqueness
   - Deep paths are more fragile to UI changes

4. **Handle ambiguity**:
   - Use index selectors when multiple elements match the same criteria
   - Example: `macos://ui/AXApplication[@AXTitle="Safari"]/AXWindow/AXGroup/AXButton[2]`

5. **Escaping special characters**:
   - When attributes contain quotes, backslashes, or control characters, they must be escaped
   - Example: `macos://ui/AXApplication[@AXTitle="App with \"quotes\""]`

### Path Generation vs. Writing Paths

There are two ways to get paths:

1. **Generate from elements**: Use UI inspection tools to get paths for existing elements
2. **Write manually**: Create paths based on knowledge of the application structure

Generation is preferred for accuracy, but manual writing is sometimes necessary.

## Common Scenarios

### Finding Application Windows

#### Get All Windows of an Application
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow
```

#### Get Main Window
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[@AXMain="true"]
```

#### Get Window By Title
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[@AXTitle="Apple"]
```

Example usage:
```javascript
// MCP automation code
let windowInfo = await macos_window_management({
  action: "getApplicationWindows",
  bundleId: "com.apple.safari"
});

// Use with UI interaction
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXButton[@AXTitle=\"Back\"]"
});
```

### Interacting with Buttons

#### Calculator Buttons
```
macos://ui/AXApplication[@AXTitle="Calculator"]/AXWindow/AXButton[@AXDescription="7"]
macos://ui/AXApplication[@AXTitle="Calculator"]/AXWindow/AXButton[@AXDescription="+"]
macos://ui/AXApplication[@AXTitle="Calculator"]/AXWindow/AXButton[@AXDescription="="]
```

#### Safari Toolbar Buttons
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXToolbar/AXButton[@AXDescription="Back"]
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXToolbar/AXButton[@AXDescription="Forward"]
```

Example usage:
```javascript
// Click the Calculator's "7" button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]"
});

// Double-click a button
await macos_ui_interact({
  action: "double_click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"TextEdit\"]/AXWindow/AXButton[@AXTitle=\"Button\"]"
});
```

### Working with Text Fields

#### Safari URL Field
```
macos://ui/AXApplication[@AXTitle="Safari"]/AXWindow/AXTextField[@AXSubrole="AXURLField"]
```

#### Login Form Fields
```
macos://ui/AXApplication[@AXTitle="Some App"]/AXWindow/AXTextField[@AXPlaceholderValue="Username"]
macos://ui/AXApplication[@AXTitle="Some App"]/AXWindow/AXSecureTextField[@AXPlaceholderValue="Password"]
```

#### TextEdit Document
```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXWindow/AXTextArea
```

Example usage:
```javascript
// Type in Safari's URL field
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"Safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]"
});

await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"Safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]",
  text: "https://www.apple.com"
});

// Type in TextEdit
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"TextEdit\"]/AXWindow/AXTextArea"
});

await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"TextEdit\"]/AXWindow/AXTextArea",
  text: "Hello world!"
});
```

### Working with Checkboxes and Radio Buttons

#### Checkboxes
```
macos://ui/AXApplication[@AXTitle="System Settings"]/AXWindow/AXCheckBox[@AXTitle="Remember my credentials"]
```

#### Radio Buttons
```
macos://ui/AXApplication[@AXTitle="App"]/AXWindow/AXRadioButton[@AXTitle="Option 1"]
macos://ui/AXApplication[@AXTitle="App"]/AXWindow/AXRadioGroup/AXRadioButton[0]
```

Example usage:
```javascript
// Toggle a checkbox
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"System Settings\"]/AXWindow/AXCheckBox[@AXTitle=\"Remember my credentials\"]"
});

// Select a radio button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"System Settings\"]/AXWindow/AXRadioGroup/AXRadioButton[@AXTitle=\"Light\"]"
});
```

### Navigating Menus

#### Opening a Menu
```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]
```

#### Selecting a Menu Item
```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]/AXMenu/AXMenuItem[@AXTitle="New"]
```

#### Working with Submenus
```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXMenuBar/AXMenuBarItem[@AXTitle="Format"]/AXMenu/AXMenuItem[@AXTitle="Font"]/AXMenu/AXMenuItem[@AXTitle="Bold"]
```

Example usage with the Menu Navigation Tool:
```javascript
// Using menu navigation tool is often more reliable for menus
await macos_menu_navigation({
  action: "activateMenuItem",
  bundleId: "com.apple.TextEdit",
  menuPath: "File > New"
});

// Getting all menus
let menus = await macos_menu_navigation({
  action: "getApplicationMenus",
  bundleId: "com.apple.TextEdit"
});
```

### Handling Dialog Elements

#### Alert Dialog
```
macos://ui/AXApplication[@AXTitle="Safari"]/AXSheet[@AXSubrole="AXStandardWindow"]
macos://ui/AXApplication[@AXTitle="Safari"]/AXSheet/AXButton[@AXTitle="Cancel"]
```

#### File Open/Save Dialogs
```
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXSheet[@AXSubrole="AXStandardWindow"]/AXButton[@AXTitle="Save"]
macos://ui/AXApplication[@AXTitle="TextEdit"]/AXSheet/AXTextField[@AXPlaceholderValue="Save As:"]
```

#### System Dialogs
```
macos://ui/AXApplication[@AXTitle="System Dialog"]/AXWindow/AXButton[@AXTitle="Allow"]
```

Example usage:
```javascript
// Click Cancel in a dialog
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"Safari\"]/AXSheet/AXButton[@AXTitle=\"Cancel\"]"
});

// Type a filename in a save dialog
await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"TextEdit\"]/AXSheet/AXTextField[@AXPlaceholderValue=\"Save As:\"]",
  text: "My Document.txt"
});
```

### Working with Tabs

#### Browser Tabs
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXTabGroup/AXTab[@AXTitle="Apple"]
```

#### Selecting Tabs
```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXTabGroup/AXTab[0]
```

Example usage:
```javascript
// Click a tab by title
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTabGroup/AXTab[@AXTitle=\"Apple\"]"
});

// Click the first tab
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTabGroup/AXTab[0]"
});
```

### Interacting with Tables and Lists

#### Table Row Selection
```
macos://ui/AXApplication[@AXTitle="Finder"]/AXWindow/AXTable/AXRow[@AXTitle="file.txt"]
```

#### Table Cell Access
```
macos://ui/AXApplication[@AXTitle="App"]/AXWindow/AXTable/AXRow[2]/AXCell[3]
```

#### List Items
```
macos://ui/AXApplication[@AXTitle="Finder"]/AXWindow/AXList/AXStaticText[@AXValue="Downloads"]
```

Example usage:
```javascript
// Click a specific table row
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"Finder\"]/AXWindow/AXTable/AXRow[@AXTitle=\"file.txt\"]"
});

// Click a cell in a specific row and column
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@AXTitle=\"App\"]/AXWindow/AXTable/AXRow[2]/AXCell[3]"
});
```

## Troubleshooting

### Common Issues

1. **Path doesn't resolve**:
   - Verify the application is running
   - Check for typos in role names or attribute values
   - Try using more general attribute matching (substring instead of exact)
   - Use the MCP Accessibility Inspector to verify the actual hierarchy

2. **Ambiguous matches**:
   - Add more specific attributes
   - Use an index selector to choose a specific match
   - Make the path more specific by including parent elements

3. **Path too fragile**:
   - Use more stable attributes (identifiers rather than position)
   - Keep paths shorter when possible
   - Focus on unique, persistent attributes

### Diagnostic Tools

MacMCP provides tools to help debug path issues:

1. **MCP Accessibility Inspector**: Explore UI hierarchies and generate correct paths
2. **Progressive Path Resolution**: Debug resolution failures segment by segment
3. **Path Validation**: Check for common issues in path syntax

#### Using the MCP Accessibility Inspector

The MCP Accessibility Inspector (`mcp-ax-inspector`) helps you explore application UI hierarchies and generate accurate paths:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --show-paths
```

To highlight only interactive elements:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --interactive-paths
```

To filter elements by path pattern:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --path-filter "AXButton"
```

#### Progressive Path Resolution

The `resolvePathProgressively` method provides detailed information about each step of path resolution, helping diagnose where and why paths fail:

```swift
let path = try ElementPath.parse("macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]")
let result = await path.resolvePathProgressively(using: accessibilityService)

if result.success {
    print("Path resolved successfully to: \(result.resolvedElement)")
} else {
    print("Path resolution failed at segment \(result.failureIndex ?? -1)")
    
    // Print segment-by-segment results for debugging
    for (i, segment) in result.segments.enumerated() {
        print("Segment \(i): \(segment.segment) - \(segment.success ? "Success" : "Failed")")
        if !segment.success {
            print("  Failure reason: \(segment.failureReason ?? "Unknown")")
            print("  Candidate elements: \(segment.candidates.count)")
        }
    }
}
```

This provides insights on:
- Which segment in the path failed
- Why the resolution failed at that point
- Alternative candidate elements that might be a better match
- Detailed attribute information about found elements

#### Path Diagnostics

The `diagnosePathResolutionIssue` function provides comprehensive troubleshooting information:

```swift
let diagnosis = try await ElementPath.diagnosePathResolutionIssue(
    "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow/AXButton[@AXDescription=\"9\"]", 
    using: accessibilityService
)
print(diagnosis)
```

This outputs a detailed report that includes:
- Syntax validation
- Progressive resolution results
- Specific suggestions for fixing path issues
- Information about alternatives if resolution failed

#### Validating Paths

The path validation function checks for common issues in path syntax:

```swift
let pathString = "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]"
let (isValid, warnings) = try ElementPath.validatePath(pathString, strict: true)

if isValid {
    print("Path is valid")
    if !warnings.isEmpty {
        print("Warnings:")
        warnings.forEach { print(" - \($0)") }
    }
} else {
    print("Path is invalid")
}
```

The validation checks for:
- Correct path prefix (`macos://ui/`)
- Valid segment syntax
- Attribute format correctness
- Potential ambiguity issues
- Missing important attributes
- Excessively complex paths

## Reference

### Common Element Paths

#### Standard Controls

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXTitle="OK"]` | Use `AXTitle` for labeled buttons |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXDescription="Action"]` | Use `AXDescription` for buttons with descriptions |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXToolbar/AXButton[@AXIdentifier="refresh-button"]` | Use `AXIdentifier` when available |
| Toolbar Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXToolbar/AXButton[@AXDescription="Back"]` | Toolbar buttons are typically in an `AXToolbar` container |
| Image Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXSubrole="AXImageButton"]` | Buttons that primarily display images |
| Disclosure Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXDisclosureTriangle` | Used for expandable/collapsible sections |
| Checkbox | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXTitle="Remember Me"]` | Use `AXValue=1` to find checked boxes |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXValue="1"]` | Value 1=checked, 0=unchecked |
| Radio Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXRadioButton[@AXTitle="Option 1"]` | Individual radio buttons |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXRadioGroup/AXRadioButton[@AXValue="1"]` | Selected radio button in a group |
| Dropdown/Popup | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXPopUpButton[@AXTitle="Select:"]` | Closed popup menu |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXPopUpButton/AXMenu/AXMenuItem[@AXTitle="Option"]` | Item in an open popup menu |
| Combobox | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXComboBox[@AXTitle="Choose an option"]` | Combination of popup and text field |
| Slider | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSlider[@AXDescription="Volume"]` | Use `AXValue` for the current position |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSlider[@AXValue="0.5"]` | Value typically ranges from 0.0 to 1.0 |
| Stepper | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXStepper` | Increment/decrement control |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXStepper/AXButton[@AXDescription="Increment"]` | Increment button of a stepper |
| Toggle | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXSubrole="AXToggle"]` | Modern toggle switch |
| Progress Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXProgressIndicator` | Shows progress of operations |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXProgressIndicator[@AXValue="0.5"]` | Progress at 50% |

#### Text Editing Controls

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Text Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextField[@AXPlaceholderValue="Username"]` | Single-line text input |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextField[@AXValue="Current text"]` | Field with existing text |
| Text Area | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextArea` | Multi-line text input |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea/AXTextArea` | Text area in a scroll container |
| Password Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSecureTextField` | Password entry field |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSecureTextField[@AXPlaceholderValue="Password"]` | Password field with placeholder |
| Search Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextField[@AXSubrole="AXSearchField"]` | Search input field |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSearchField` | Alternative representation |
| Token Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXTokenField"]` | Text field with token objects (like tags) |
| Rich Text Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextArea[@AXSubrole="AXRichText"]` | Text with formatting capabilities |
| Form Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXForm"]/AXTextField` | Text field within a form group |

#### Navigation and Container Controls

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Tab Group | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTabGroup` | Container for tabs |
| Tab | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTabGroup/AXTab[@AXTitle="Settings"]` | Individual tab within a tab group |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTabGroup/AXTab[@AXValue="1"]` | Selected tab (value=1) |
| Table | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable` | Data table/grid |
| Table Header | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[@AXSubrole="AXTableHeaderRow"]` | Header row of a table |
| Table Row | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[2]` | Third row in a table (zero-indexed) |
| Table Cell | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[1]/AXCell[0]` | First cell in second row |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow/AXCell[@AXTitle="Data"]` | Cell with specific content |
| List | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXList` | Vertical list of items |
| List Item | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXList/AXStaticText[@AXValue="Item 1"]` | Item in a list |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXList/AXGroup[3]` | Fourth group in a list |
| Outline/Tree | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXOutline` | Hierarchical tree view |
| Outline Item | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXOutline/AXOutlineRow[@AXTitle="Item"]` | Item in an outline/tree |
| Scroll Area | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea` | Scrollable container |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea/AXGroup` | Content within scroll area |
| Split View | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSplitGroup` | Split pane container |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSplitGroup/AXGroup[0]` | Left/top pane |
| Sidebar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXSidebar"]` | Sidebar navigation panel |
| Toolbar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXToolbar` | Application toolbar |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXToolbar/AXGroup` | Group in toolbar |

#### Window Management Controls

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Window | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow` | Application window |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow[@AXMain="1"]` | Main application window |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow[@AXTitle="Document"]` | Window with specific title |
| Close Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXSubrole="AXCloseButton"]` | Window close button (red) |
| Minimize Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXSubrole="AXMinimizeButton"]` | Window minimize button (yellow) |
| Zoom Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXSubrole="AXZoomButton"]` | Window zoom/maximize button (green) |
| Title Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXTitleBar"]` | Window title bar |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXTitleBar"]/AXStaticText` | Window title text |
| Resize Handle | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGrowArea` | Window resize handle (bottom right) |
| Toolbar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXToolbar` | Window toolbar |
| Status Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXStatusBar"]` | Status bar (usually at bottom) |

#### Dialog and Popover Elements

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Alert | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet[@AXSubrole="AXStandardWindow"]` | Alert dialog |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXStaticText[@AXRole="AXHeading"]` | Alert heading text |
| Sheet | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet` | Sheet dialog attached to a window |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXGroup` | Content group in a sheet |
| Dialog | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXDialog` | Modal dialog |
| File Open Dialog | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXPopUpButton[@AXTitle="Enable:"]` | Typical file dialog control |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXButton[@AXTitle="Open"]` | Open button in file dialog |
| Save Dialog | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXTextField[@AXPlaceholderValue="Save As:"]` | Filename field in save dialog |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXButton[@AXTitle="Save"]` | Save button in save dialog |
| Popover | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXPopover"]` | Popup information panel |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup[@AXSubrole="AXPopover"]/AXButton` | Button in popover |
| Toast/Notification | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXGroup[@AXSubrole="AXNotification"]` | Temporary notification |

#### Menu Elements

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Menu Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar` | Application menu bar (top of screen) |
| Menu Bar Item | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]` | Top-level menu item |
| Menu | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]/AXMenu` | Dropdown menu |
| Menu Item | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]/AXMenu/AXMenuItem[@AXTitle="Open"]` | Item in a menu |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem/AXMenu/AXMenuItem[@AXTitle="Save"]/AXMenu/AXMenuItem` | Item in a submenu |
| Menu Item Checkbox | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem/AXMenu/AXMenuItem[@AXSubrole="AXMenuItemCheckbox"]` | Checkbox menu item |
| Menu Item Radio | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem/AXMenu/AXMenuItem[@AXSubrole="AXMenuItemRadio"]` | Radio menu item |
| Context Menu | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXMenu[@AXSubrole="AXContextMenu"]` | Right-click context menu |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXMenu[@AXSubrole="AXContextMenu"]/AXMenuItem` | Item in context menu |
| Dock Menu | `macos://ui/AXApplication[@bundleIdentifier="com.apple.dock"]/AXMenu` | macOS Dock app menu |

#### Special Application Elements

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Safari URL Field | `macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXTextField[@AXSubrole="AXURLField"]` | Safari address bar |
| Safari Bookmark | `macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXToolbar/AXGroup/AXButton[@AXSubrole="AXBookmark"]` | Safari bookmark button |
| Finder Sidebar | `macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXGroup[@AXSubrole="AXSidebar"]` | Finder sidebar navigation |
| Finder Item | `macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXTable/AXRow[@AXTitle="file.txt"]` | Item in Finder list view |
| System Dialog | `macos://ui/AXApplication[@bundleIdentifier="com.apple.systempreferences"]/AXWindow/AXSheet` | System preference confirmation dialog |
| Calendar Event | `macos://ui/AXApplication[@bundleIdentifier="com.apple.iCal"]/AXWindow/AXGroup[@AXSubrole="AXCalendarView"]/AXGroup[@AXSubrole="AXCalendarEvent"]` | Event in Calendar app |
| Photos Item | `macos://ui/AXApplication[@bundleIdentifier="com.apple.Photos"]/AXWindow/AXGrid/AXCell` | Photo in Photos app grid |

#### Other Specialized Controls

| Control Type | Example Path | Notes |
|--------------|--------------|-------|
| Color Well | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXColorWell` | Color picker control |
| Date Picker | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXDateField` | Date selection control |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXDateField/AXCalendar` | Calendar in date picker |
| Segmented Control | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSegmentedControl` | Button bar with segments |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSegmentedControl/AXRadioButton[@AXValue="1"]` | Selected segment |
| Image | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXImage` | Image element |
| Link | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXLink[@AXTitle="Learn more"]` | Hyperlink or clickable text |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXWebArea/AXLink` | Web link in web content |
| Static Text | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXStaticText[@AXValue="Welcome"]` | Non-editable text |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXStaticText[@AXSubrole="AXHeading"]` | Heading text |
| Scroll Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea/AXScrollBar` | Scroll bar control |
| | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea/AXScrollBar/AXValueIndicator` | Scroll bar thumb/indicator |
| Splitter | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSplitGroup/AXSplitter` | Draggable divider between split views |
| Web Area | `macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXWebArea` | Web content container |

## Migration from Element IDs

If you're updating code that used element IDs, here's how to convert to path-based identification:

1. **Replace element IDs with paths**:

   Before:
   ```swift
   toolChain.clickElement(elementId: "button123", bundleId: "com.apple.calculator")
   ```

   After:
   ```swift
   toolChain.clickElement(elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]")
   ```

2. **Update parameter names**:

   Before:
   ```swift
   let params: [String: Value] = [
       "action": .string("click"),
       "elementId": .string(id),
       "appBundleId": .string(bundleId)
   ]
   ```

   After:
   ```swift
   let params: [String: Value] = [
       "action": .string("click"),
       "elementPath": .string(path),
       "appBundleId": .string(bundleId)
   ]
   ```

3. **Extract element paths**:

   If you need to get a path from an existing element:
   ```swift
   guard let elementPath = element.path else {
       XCTFail("No path available for element")
       return
   }
   ```