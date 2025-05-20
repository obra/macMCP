# ElementPath Tutorial

This tutorial introduces ElementPath, the standardized path-based approach to identifying UI elements in macOS applications using MacMCP. 

## Introduction

ElementPath is a XPath-inspired syntax for reliably and consistently referencing UI elements in the macOS accessibility hierarchy. This tutorial will walk you through how to effectively use ElementPath for your UI automation tasks.

## Why Use ElementPath?

ElementPath offers several advantages:

1. **Human-readable**: Paths clearly indicate the UI hierarchy
2. **Stable**: More resistant to UI changes than position-based references
3. **Precise**: Can specifically target elements using multiple attributes
4. **Hierarchical**: Represents the actual structure of UI elements
5. **Standardized**: Consistent format across all MacMCP tools

## ElementPath Syntax

### Basic Format

```
macos://ui/RoleType[@attribute="value"]/ChildRole[@attribute="value"]
```

Each path consists of:

- `macos://ui/` prefix: Indicates this is an ElementPath
- Role segments: Element types (e.g., `AXApplication`, `AXWindow`, `AXButton`)
- Attribute selectors: Filter elements by properties (`[@AXTitle="Calculator"]`)
- Path separator: Forward slash (`/`) to navigate through hierarchy

### Simple Examples

```
# Application reference
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]

# Button in Calculator
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow/AXButton[@AXDescription="7"]

# Text field in Safari
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXTextField[@AXSubrole="AXURLField"]
```

## Step-by-Step Tutorial

### Step 1: Identifying an Application

The first segment of any ElementPath typically references the application:

```
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]
```

For stability, use the bundle identifier when possible. You can also use the application title:

```
macos://ui/AXApplication[@AXTitle="Calculator"]
```

### Step 2: Navigating to Windows

After specifying the application, navigate to a window:

```
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow
```

To be more specific, you can add attributes to identify a particular window:

```
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow[@AXTitle="Untitled"]
```

If an application has multiple windows, you can use an index selector:

```
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[0]  # First window
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[1]  # Second window
```

### Step 3: Finding Elements Within Windows

Once you've referenced a window, you can navigate to specific UI elements:

```
# Button in Calculator
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow/AXButton[@AXDescription="7"]

# Text area in TextEdit
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXScrollArea/AXTextArea
```

### Step 4: Using Attribute Selectors

Attribute selectors help you target specific elements when multiple similar elements exist:

```
# Button with specific title
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXTitle="Save"]

# Element with a specific identifier
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXIdentifier="submit-button"]

# Element with specific description
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow/AXButton[@AXDescription="7"]
```

You can combine multiple attributes to be even more specific:

```
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXTitle="OK"][@AXEnabled="1"]
```

### Step 5: Navigating Through Complex Hierarchies

For deeply nested elements, follow the UI hierarchy:

```
# Element in a group
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXGroup/AXButton

# Element in nested groups
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXGroup/AXGroup/AXButton

# Element in a specific group
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXGroup[@AXIdentifier="controls"]/AXButton
```

### Step 6: Using Index Selectors

When multiple elements match the same criteria, use index selectors to distinguish them:

```
# First button in a group
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXGroup/AXButton[0]

# Third cell in a row
macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXTable/AXRow[1]/AXCell[2]
```

Indexes are zero-based (the first element is at index 0).

## Practical Examples

### Example 1: Calculator Interaction

To perform a calculation in Calculator:

```javascript
// Click "7"
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]"
});

// Click "+"
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"Add\"]"
});

// Click "5"
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"5\"]"
});

// Click "="
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"Equals\"]"
});
```

### Example 2: Web Navigation in Safari

```javascript
// Type URL in address bar
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]"
});

await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]",
  text: "https://www.apple.com"
});

// Press Enter to navigate
await macos_ui_interact({
  action: "press_key",
  key: "Return"
});
```

### Example 3: Text Editing

```javascript
// Focus on text area
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXWindow/AXScrollArea/AXTextArea"
});

// Type text
await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXWindow/AXScrollArea/AXTextArea",
  text: "Hello, world!"
});
```

### Example 4: Working with Dialog Boxes

```javascript
// Click "Save" in a save dialog
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXSheet/AXButton[@AXTitle=\"Save\"]"
});

// Enter filename in save dialog
await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXSheet/AXTextField[@AXPlaceholderValue=\"Save As:\"]",
  text: "MyDocument.txt"
});
```

## Finding Element Paths

The easiest way to find paths for UI elements is to use the MCP Accessibility Inspector:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --show-paths
```

This will display the ElementPath for each UI element in the application.

For interactive elements only:

```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --interactive-paths
```

## Debugging Path Issues

If your path doesn't resolve to the expected element:

1. **Verify the element exists**: Check if the element is actually in the UI hierarchy.
2. **Check attribute values**: Ensure attribute values match exactly (case-sensitive).
3. **Simplify the path**: Start with a simpler path and gradually add specificity.
4. **Use the MCP Accessibility Inspector**: Verify the actual hierarchy and element attributes.

## Best Practices

1. **Start with the application**:
   ```
   macos://ui/AXApplication[@bundleIdentifier="com.example.app"]
   ```

2. **Use specific attributes**:
   ```
   macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXTitle="Submit"]
   ```

3. **Use stable identifiers when available**:
   - `bundleIdentifier` for applications
   - `AXIdentifier` for UI elements
   - `AXTitle` and `AXDescription` are generally stable

4. **Avoid overly deep paths**:
   ```
   # Too deep and brittle
   macos://ui/AXApplication/AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXButton
   
   # Better
   macos://ui/AXApplication/AXWindow/AXButton[@AXTitle="Submit"]
   ```

5. **Use index selectors when needed**:
   ```
   macos://ui/AXApplication/AXWindow/AXTable/AXRow[5]
   ```

## Common Element Paths

### Essential Controls

| Element Type | Example Path |
|--------------|--------------|
| Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXTitle="OK"]` |
| Text Field | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextField[@AXPlaceholderValue="Username"]` |
| Text Area | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXScrollArea/AXTextArea` |
| Checkbox | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXTitle="Remember me"]` |
| Radio Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXRadioButton[@AXTitle="Option 1"]` |
| Link | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXLink[@AXTitle="Learn more"]` |

### Specialized Elements

| Element Type | Example Path |
|--------------|--------------|
| Menu Bar | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar` |
| Menu Item | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXMenuBar/AXMenuBarItem[@AXTitle="File"]/AXMenu/AXMenuItem[@AXTitle="Open"]` |
| Table Row | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[3]` |
| Table Cell | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[3]/AXCell[2]` |
| Dialog Button | `macos://ui/AXApplication[@bundleIdentifier="app"]/AXSheet/AXButton[@AXTitle="OK"]` |

## Conclusion

ElementPath provides a powerful, flexible, and standardized way to identify UI elements across macOS applications. By following the patterns and practices in this tutorial, you can create reliable UI automation that works consistently across different applications and UI states.