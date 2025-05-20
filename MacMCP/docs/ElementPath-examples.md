# ElementPath Examples and Common Patterns

This document provides practical examples of using ElementPath in common UI automation scenarios. The examples demonstrate best practices for path construction and usage.

## Basic Path Patterns

### Application Paths

```
# By bundle identifier (recommended for stability)
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]

# By title 
macos://ui/AXApplication[@AXTitle="Calculator"]

# System-wide element
macos://ui/AXSystemWide
```

### Window Selection

```
# Main window
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[@AXMain="1"]

# Window by title
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[@AXTitle="Apple"]

# First window (when multiple exist)
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow[0]
```

### Button Interaction

```
# Button by description
macos://ui/AXApplication[@bundleIdentifier="com.apple.calculator"]/AXWindow/AXButton[@AXDescription="7"]

# Button by title
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXButton[@AXTitle="Save"]

# Toolbar button
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXToolbar/AXButton[@AXDescription="Back"]

# Window control buttons
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXButton[@AXSubrole="AXCloseButton"]
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXButton[@AXSubrole="AXMinimizeButton"]
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXButton[@AXSubrole="AXZoomButton"]
```

### Text Interaction

```
# Single-line text field
macos://ui/AXApplication[@bundleIdentifier="com.apple.safari"]/AXWindow/AXTextField[@AXSubrole="AXURLField"]

# Multi-line text area
macos://ui/AXApplication[@bundleIdentifier="com.apple.TextEdit"]/AXWindow/AXScrollArea/AXTextArea

# Password field
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXSecureTextField[@AXPlaceholderValue="Password"]

# Text field by placeholder
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTextField[@AXPlaceholderValue="Search..."]
```

### Tables and Lists

```
# Table selection
macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXTable

# Table row by index (zero-based)
macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXTable/AXRow[3]

# Table row by title
macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXTable/AXRow[@AXTitle="file.txt"]

# Table cell by coordinates
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[2]/AXCell[1]

# List with items
macos://ui/AXApplication[@bundleIdentifier="com.apple.finder"]/AXWindow/AXList/AXStaticText[@AXValue="Documents"]
```

### Checkboxes and Radio Buttons

```
# Checkbox
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXTitle="Remember me"]

# Selected checkbox
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXCheckBox[@AXValue="1"]

# Radio button
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXRadioButton[@AXTitle="Option 1"]

# Radio button in a group
macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXRadioGroup/AXRadioButton[2]
```

## Real-World Scenarios

### Calculator Operations

```javascript
// Click the "7" button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"7\"]"
});

// Click the addition button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"Add\"]"
});

// Click the "9" button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"9\"]"
});

// Click the equals button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXDescription=\"Equals\"]"
});

// Get the result from the display
let result = await macos_ui_state({
  scope: "application",
  bundleId: "com.apple.calculator",
  filter: {
    role: "AXStaticText",
    subrole: "AXMenuItemText"
  }
});
```

### Web Browsing with Safari

```javascript
// Open Safari
await macos_open_application({
  bundleIdentifier: "com.apple.safari"
});

// Click the URL field
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXTextField[@AXSubrole=\"AXURLField\"]"
});

// Type a URL
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

// Click on a link (after allowing time for the page to load)
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.safari\"]/AXWindow/AXWebArea/AXLink[@AXTitle=\"Mac\"]"
});
```

### Text Editing in TextEdit

```javascript
// Open TextEdit
await macos_open_application({
  bundleIdentifier: "com.apple.TextEdit"
});

// Click in the text area
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXWindow/AXScrollArea/AXTextArea"
});

// Type some text
await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXWindow/AXScrollArea/AXTextArea",
  text: "Hello, ElementPath!"
});

// Using menu navigation to save the file
await macos_menu_navigation({
  action: "activateMenuItem",
  bundleId: "com.apple.TextEdit",
  menuPath: "File > Save"
});

// Type a filename in the save dialog
await macos_ui_interact({
  action: "type",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXSheet/AXTextField[@AXPlaceholderValue=\"Save As:\"]",
  text: "MyDocument.txt"
});

// Click the Save button
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.TextEdit\"]/AXSheet/AXButton[@AXTitle=\"Save\"]"
});
```

### Working with Finder

```javascript
// Open Finder
await macos_open_application({
  bundleIdentifier: "com.apple.finder"
});

// Click on Documents in the sidebar
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.finder\"]/AXWindow/AXSplitGroup/AXGroup[@AXSubrole=\"AXSidebar\"]/AXList/AXStaticText[@AXValue=\"Documents\"]"
});

// Create a new folder using menu navigation
await macos_menu_navigation({
  action: "activateMenuItem",
  bundleId: "com.apple.finder",
  menuPath: "File > New Folder"
});

// Type the folder name (after the new folder dialog appears)
await macos_ui_interact({
  action: "type",
  text: "My New Folder"
});

// Press Enter to confirm
await macos_ui_interact({
  action: "press_key",
  key: "Return"
});

// Select the new folder
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.finder\"]/AXWindow/AXTable/AXRow[@AXTitle=\"My New Folder\"]"
});
```

### System Preferences/Settings

```javascript
// Open System Settings (macOS 13+)
await macos_open_application({
  bundleIdentifier: "com.apple.systempreferences"
});

// Navigate to a specific preference pane
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.systempreferences\"]/AXWindow/AXList/AXButton[@AXTitle=\"Wi-Fi\"]"
});

// Toggle a switch (example for Wi-Fi)
await macos_ui_interact({
  action: "click",
  elementPath: "macos://ui/AXApplication[@bundleIdentifier=\"com.apple.systempreferences\"]/AXWindow/AXGroup/AXSwitch[@AXTitle=\"Wi-Fi\"]"
});
```

## Advanced Path Techniques

### Handling Dynamic UIs

For applications with dynamic UI elements that change position or properties:

```javascript
// Approach 1: Use more general attributes
// Instead of position-specific paths like:
"macos://ui/AXApplication[@bundleIdentifier=\"app\"]/AXWindow/AXGroup[2]/AXButton[3]"

// Use attribute-based paths:
"macos://ui/AXApplication[@bundleIdentifier=\"app\"]/AXWindow/AXButton[@AXTitle=\"Save\"]"

// Approach 2: Use partial attribute matching
// For elements whose text might change slightly:
"macos://ui/AXApplication[@bundleIdentifier=\"app\"]/AXWindow/AXStaticText[contains(@AXValue, \"Welcome\")]"
```

### Finding Elements with Complex Paths

Sometimes UI elements are deeply nested or have no unique attributes. In these cases:

```javascript
// Method 1: First find a unique parent element
const parentPath = "macos://ui/AXApplication[@bundleIdentifier=\"app\"]/AXWindow/AXGroup[@AXIdentifier=\"unique-id\"]";

// Then use the UI State Tool to explore its children
const result = await macos_ui_state({
  scope: "element",
  elementPath: parentPath,
  maxDepth: 3
});

// Method 2: Use the MCP Accessibility Inspector
// ./.build/debug/mcp-ax-inspector --app-id com.example.app --filter "title=MyElement" --show-paths
```

## Best Practices for Path Creation

1. **Start with the application**
   ```
   macos://ui/AXApplication[@bundleIdentifier="com.example.app"]
   ```

2. **Use unique attributes when possible**
   ```
   // Good (unique identifiers)
   macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXIdentifier="submit-button"]
   
   // Also good (descriptive attributes)
   macos://ui/AXApplication[@bundleIdentifier="com.example.app"]/AXWindow/AXButton[@AXTitle="Submit"]
   ```

3. **Avoid excessive depth**
   ```
   // Too deep and brittle
   macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXButton
   
   // Better
   macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXButton[@AXTitle="Submit"]
   ```

4. **Use index selectors when needed**
   ```
   // For multiple similar elements
   macos://ui/AXApplication[@bundleIdentifier="app"]/AXWindow/AXTable/AXRow[5]
   ```

5. **Prefer stable attributes**
   - `AXIdentifier` and `bundleIdentifier` are most stable
   - `AXTitle`, `AXDescription`, and `AXRole` are generally stable
   - Avoid relying on position alone when possible

## Troubleshooting ElementPath Issues

### Common Problems and Solutions

1. **Path doesn't find any elements**
   - Verify the application is running
   - Check attribute values (case-sensitive)
   - Try using the MCP Accessibility Inspector to see the actual UI hierarchy

2. **Multiple elements match the path**
   - Add more specific attributes
   - Use an index selector: `macos://ui/AXApplication/AXWindow/AXButton[0]`

3. **Element properties change between launches**
   - Use more stable attributes like identifiers
   - Consider using multiple attribute conditions

4. **Path is too brittle due to UI changes**
   - Shorten the path to include only necessary segments
   - Focus on stable parts of the UI that don't change often

### Element Not Found Checklist

If your path doesn't resolve:

1. Is the application running?
2. Are the attribute values correct (check capitalization)?
3. Does the element actually exist in the current state?
4. Have you verified the path with the MCP Accessibility Inspector?
5. Do you need to wait for UI elements to appear?