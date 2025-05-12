# InterfaceExplorerTool Technical Specification

## 1. Overview

The InterfaceExplorerTool is a consolidated Model Context Protocol (MCP) tool that provides a unified interface for exploring, discovering, and examining UI elements and their capabilities within macOS applications. It replaces and consolidates the functionality previously divided among three separate tools: UIStateTool, InteractiveElementsDiscoveryTool, and ElementCapabilitiesTool.

## 2. Purpose and Scope

This tool serves as the primary mechanism for LLMs to perceive and understand the macOS user interface. It allows models to:

- Explore the complete UI hierarchy of applications
- Discover specific types of interactive controls
- Examine the detailed capabilities and properties of UI elements
- Make informed decisions about how to interact with the interface

## 3. Tool Identification

```swift
/// The name of the tool
public let name = ToolNames.interfaceExplorer

/// Description of the tool
public let description = "Explore and examine UI elements and their capabilities in macOS applications"
```

## 4. Input Schema

```swift
{
    "type": "object",
    "properties": {
        "scope": {
            "type": "string",
            "description": "The scope of UI elements to retrieve: system, application, focused, position, element",
            "enum": ["system", "application", "focused", "position", "element"]
        },
        "bundleId": {
            "type": "string",
            "description": "The bundle identifier of the application to retrieve (required for 'application' scope)"
        },
        "elementId": {
            "type": "string",
            "description": "The ID of a specific element to retrieve (required for 'element' scope)"
        },
        "x": {
            "type": ["number", "integer"],
            "description": "X coordinate for position scope"
        },
        "y": {
            "type": ["number", "integer"],
            "description": "Y coordinate for position scope"
        },
        "maxDepth": {
            "type": "number",
            "description": "Maximum depth of the element hierarchy to retrieve",
            "default": 10
        },
        "filter": {
            "type": "object",
            "description": "Filter criteria for elements",
            "properties": {
                "role": {
                    "type": "string",
                    "description": "Filter by accessibility role"
                },
                "titleContains": {
                    "type": "string",
                    "description": "Filter by title containing this text"
                },
                "valueContains": {
                    "type": "string",
                    "description": "Filter by value containing this text"
                },
                "descriptionContains": {
                    "type": "string",
                    "description": "Filter by description containing this text"
                }
            }
        },
        "elementTypes": {
            "type": "array",
            "description": "Types of interactive elements to find (when discovering interactive elements)",
            "items": {
                "type": "string",
                "enum": ["button", "checkbox", "radio", "textfield", "dropdown", "slider", "link", "tab", "any"]
            },
            "default": ["any"]
        },
        "includeHidden": {
            "type": "boolean",
            "description": "Whether to include hidden elements",
            "default": false
        },
        "limit": {
            "type": "integer",
            "description": "Maximum number of elements to return",
            "default": 100
        }
    },
    "required": ["scope"],
    "additionalProperties": false
}
```

## 5. Parameter Details

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `scope` | Defines the search scope for UI elements | Yes | N/A |
| `bundleId` | Application bundle identifier | For 'application' scope | N/A |
| `elementId` | Specific element identifier | For 'element' scope | N/A |
| `x`, `y` | Coordinates for position-based search | For 'position' scope | N/A |
| `maxDepth` | Maximum hierarchy depth to traverse | No | 10 |
| `filter` | Element filtering criteria | No | N/A |
| `elementTypes` | Types of interactive elements to find | No | ["any"] |
| `includeHidden` | Whether to include hidden elements | No | false |
| `limit` | Maximum number of elements to return | No | 100 |

### 5.1 Scope Values

- `system`: All UI elements across the system
- `application`: Elements within a specific application (requires `bundleId`)
- `focused`: Elements within the currently focused application
- `position`: Elements at a specific screen position (requires `x` and `y`)
- `element`: A specific element and its descendants (requires `elementId`)

### 5.2 Element Types

- `button`: Button elements
- `checkbox`: Checkbox elements
- `radio`: Radio button elements
- `textfield`: Text field and text area elements
- `dropdown`: Dropdown/combo box elements
- `slider`: Slider and scroll bar elements
- `link`: Link elements
- `tab`: Tab elements
- `any`: Any interactive element

## 6. Output Format

The tool returns a JSON array of UI element descriptors. Each element is represented by the following structure:

```json
{
  "id": "unique_identifier",
  "role": "AXButton",
  "name": "Human-readable name",
  "title": "Element title (if any)",
  "value": "Current value (if applicable)",
  "description": "Human-readable description",
  "frame": {
    "x": 100,
    "y": 200,
    "width": 50,
    "height": 30
  },
  "state": ["enabled", "visible", "unfocused", "unselected"],
  "capabilities": [
    "clickable",
    "hasHelp",
    "hasTooltip"
  ],
  "actions": ["AXPress"],
  "attributes": {
    "keyboardShortcut": "⌘S",
    "helpText": "Save the document"
  },
  "children": [
    // Child elements using same format (if within maxDepth)
  ]
}
```

## 7. Element Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | String | Unique identifier for the element |
| `role` | String | Accessibility role (e.g., "AXButton", "AXTextField") |
| `name` | String | Human-readable name (derived from title, description, or role) |
| `title` | String? | The title or label of the element (if any) |
| `value` | String? | The current value of the element (if applicable) |
| `description` | String? | Human-readable description of the element |
| `frame` | Object | Position and size of the element |
| `state` | String[] | Current states as string array |
| `capabilities` | String[] | Higher-level interaction capabilities |
| `actions` | String[] | Available accessibility actions |
| `attributes` | Object | Additional element attributes |
| `children` | Array | Child elements (if within maxDepth) |

### 7.1 State Values

State is represented as an array of string values:

- `enabled` / `disabled`
- `visible` / `hidden`
- `focused` / `unfocused`
- `selected` / `unselected`
- `expanded` / `collapsed`
- `readonly` / `editable`
- `required` / `optional`

### 7.2 Capabilities

Capabilities represent higher-level interaction possibilities:

- `clickable`: Element can be clicked
- `editable`: Element's text can be edited
- `toggleable`: Element can be toggled (like checkboxes)
- `selectable`: Element can be selected from options
- `adjustable`: Element can be incremented/decremented
- `scrollable`: Element can be scrolled
- `hasChildren`: Element contains child elements
- `hasMenu`: Element has an associated menu
- `hasHelp`: Element has help text
- `hasTooltip`: Element has a tooltip
- `navigable`: Element supports navigation (like links)
- `focusable`: Element can receive keyboard focus

## 8. Implementation Details

### 8.1 Tool Structure

```swift
public struct InterfaceExplorerTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.interfaceExplorer
    
    /// Description of the tool
    public let description = "Explore and examine UI elements and their capabilities in macOS applications"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// Tool handler function
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content]
    
    /// The logger
    private let logger: Logger
    
    /// Initialization method with dependencies
    public init(accessibilityService: any AccessibilityServiceProtocol, logger: Logger? = nil)
    
    /// Process request method
    private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content]
    
    /// Handle different scope types
    private func handleSystemScope(params) async throws -> [Tool.Content]
    private func handleApplicationScope(params) async throws -> [Tool.Content]
    private func handleFocusedScope(params) async throws -> [Tool.Content]
    private func handlePositionScope(params) async throws -> [Tool.Content]
    private func handleElementScope(params) async throws -> [Tool.Content]
    
    /// Helper methods
    private func findElements(criteria) async throws -> [UIElement]
    private func convertToOutputFormat(elements: [UIElement]) throws -> [ElementDescriptor]
    private func formatResponse<T: Encodable>(_ data: T) throws -> [Tool.Content]
}
```

### 8.2 Element Descriptor

```swift
public struct EnhancedElementDescriptor: Codable, Sendable, Identifiable {
    public let id: String
    public let role: String
    public let name: String
    public let title: String?
    public let value: String?
    public let description: String?
    public let frame: ElementFrame
    public let state: [String]
    public let capabilities: [String]
    public let actions: [String]
    public let attributes: [String: String]
    public let children: [EnhancedElementDescriptor]?
    
    public static func from(element: UIElement, maxDepth: Int = 10, currentDepth: Int = 0) -> EnhancedElementDescriptor
}
```

### 8.3 State Mapping

```swift
private func determineElementState(_ element: UIElement) -> [String] {
    var states: [String] = []
    
    // Map boolean attributes to string state values
    if element.isEnabled {
        states.append("enabled")
    } else {
        states.append("disabled")
    }
    
    if element.isVisible {
        states.append("visible")
    } else {
        states.append("hidden")
    }
    
    if element.isFocused {
        states.append("focused")
    } else {
        states.append("unfocused")
    }
    
    if element.isSelected {
        states.append("selected")
    } else {
        states.append("unselected")
    }
    
    // Add other state mappings based on attributes
    if let expanded = element.attributes["expanded"] as? Bool {
        states.append(expanded ? "expanded" : "collapsed")
    }
    
    if let readonly = element.attributes["readonly"] as? Bool {
        states.append(readonly ? "readonly" : "editable")
    }
    
    if let required = element.attributes["required"] as? Bool {
        states.append(required ? "required" : "optional")
    }
    
    return states
}
```

### 8.4 Capability Mapping

```swift
private func determineElementCapabilities(_ element: UIElement) -> [String] {
    var capabilities: [String] = []
    
    // Map element roles and actions to higher-level capabilities
    if element.isClickable {
        capabilities.append("clickable")
    }
    
    if element.isEditable {
        capabilities.append("editable")
    }
    
    if element.isToggleable {
        capabilities.append("toggleable")
    }
    
    if element.isSelectable {
        capabilities.append("selectable")
    }
    
    if element.isAdjustable {
        capabilities.append("adjustable")
    }
    
    if element.role == "AXScrollArea" || element.actions.contains(AXAttribute.Action.scrollToVisible) {
        capabilities.append("scrollable")
    }
    
    if !element.children.isEmpty {
        capabilities.append("hasChildren")
    }
    
    if element.actions.contains(AXAttribute.Action.showMenu) {
        capabilities.append("hasMenu")
    }
    
    if element.attributes["help"] != nil || element.attributes["helpText"] != nil {
        capabilities.append("hasHelp")
    }
    
    if element.attributes["tooltip"] != nil || element.attributes["toolTip"] != nil {
        capabilities.append("hasTooltip")
    }
    
    if element.role == AXAttribute.Role.link {
        capabilities.append("navigable")
    }
    
    if element.attributes["focusable"] as? Bool == true {
        capabilities.append("focusable")
    }
    
    return capabilities
}
```

### 8.5 Attribute Filtering

```swift
private func filterAttributes(_ element: UIElement) -> [String: String] {
    var result: [String: String] = [:]
    
    // Only include attributes that aren't already covered by other properties
    for (key, value) in element.attributes {
        // Skip attributes already covered by capabilities, state, or primary properties
        if ["role", "title", "value", "description", "identifier", 
             "enabled", "visible", "focused", "selected"].contains(key) {
            continue
        }
        
        // Include other attributes with string conversion
        result[key] = String(describing: value)
    }
    
    return result
}
```

## 9. Usage Examples

### 9.1 Get System-Wide UI State

Request:
```json
{
  "scope": "system",
  "maxDepth": 5
}
```

### 9.2 Get Application UI Hierarchy

Request:
```json
{
  "scope": "application",
  "bundleId": "com.apple.calculator",
  "maxDepth": 10
}
```

### 9.3 Get Specific Element

Request:
```json
{
  "scope": "element",
  "elementId": "calculator-button-7"
}
```

### 9.4 Find Interactive Elements with Filtering

Request:
```json
{
  "scope": "application",
  "bundleId": "com.apple.TextEdit",
  "elementTypes": ["button", "textfield"],
  "filter": {
    "titleContains": "Save"
  },
  "maxDepth": 5
}
```

### 9.5 Get UI Element at Screen Position

Request:
```json
{
  "scope": "position",
  "x": 500,
  "y": 300,
  "maxDepth": 3
}
```

## 10. Error Handling

The tool returns appropriate error responses in the following situations:

1. **Invalid Parameters**: When required parameters are missing or have invalid values
2. **Element Not Found**: When a specified element ID cannot be found
3. **Application Not Found**: When a specified bundle ID cannot be found
4. **Permission Denied**: When accessibility permissions are not granted
5. **Internal Errors**: When unexpected errors occur during processing

Error responses follow the MCP error format with appropriate error codes and descriptive messages.

## 11. Performance Considerations

1. **Depth Control**: The `maxDepth` parameter prevents excessive hierarchy traversal
2. **Element Limit**: The `limit` parameter caps the number of returned elements
3. **Filterable Results**: Filter parameters allow narrowing results efficiently
4. **Hidden Element Optimization**: `includeHidden` parameter allows skipping invisible elements

## 12. Testing Approach

Tests should include:

1. **Unit Tests**: Test each handler method with mock UIElements
2. **Integration Tests**: Test with real applications like Calculator
3. **Edge Cases**: Test with very deep hierarchies, many elements, and unusual input
4. **Error Cases**: Test with invalid inputs and error conditions

## 13. Implementation Plan

1. Create the InterfaceExplorerTool class structure
2. Implement core parameter handling and scope routing
3. Implement element conversion with state and capability mapping
4. Implement specialized handlers for each scope type
5. Add filtering and element type matching
6. Implement comprehensive error handling
7. Add unit and integration tests
8. Document public API and usage examples

## 14. Tools to Remove

The following tools will be deprecated and removed as they are consolidated into the InterfaceExplorerTool:

1. **UIStateTool**
   - File: `/Sources/MacMCP/Tools/UIStateTool.swift`
   - Related enums in `ToolNames.swift`: `uiState`

2. **InteractiveElementsDiscoveryTool**
   - File: `/Sources/MacMCP/Tools/InteractiveElementsDiscoveryTool.swift`
   - Related enums in `ToolNames.swift`: `interactiveElements`

3. **ElementCapabilitiesTool**
   - File: `/Sources/MacMCP/Tools/ElementCapabilitiesTool.swift`
   - Related enums in `ToolNames.swift`: `elementCapabilities`

Update the `ToolNames.swift` file to add the new tool:

```swift
/// Interface explorer tool
public static let interfaceExplorer = "\(prefix)_interface_explorer"
```

## 15. Tests to Update

The following tests will need to be updated or consolidated:

1. **UIStateTool Tests**
   - Update or replace any tests that verify the functionality of UIStateTool
   - Ensure test coverage for all UIStateTool functionality in the new InterfaceExplorerTool

2. **InteractiveElementsDiscoveryTool Tests**
   - Update or replace any tests that verify the functionality of InteractiveElementsDiscoveryTool
   - Ensure test coverage for all interactive element discovery functionality in the new InterfaceExplorerTool

3. **ElementCapabilitiesTool Tests**
   - Update or replace any tests that verify the functionality of ElementCapabilitiesTool
   - Ensure test coverage for all element capability inspection functionality in the new InterfaceExplorerTool

4. **Integration Tests**
   - Update any integration tests that use the removed tools
   - Create new integration tests for InterfaceExplorerTool with real applications

5. **Test Dependencies**
   - Update any test helpers or mock objects that depend on the removed tools
   - Create new test helpers for InterfaceExplorerTool as needed

6. **Specific Test Files to Update**:
   - `/Tests/MacMCPTests/UIElementTests.swift` - Update any tests that use the removed tools
   - `/Tests/MacMCPTests/AccessibilityTests.swift` - Update any tests that use the removed tools
   - `/Tests/MacMCPTests/ToolTests/` - Update or create test files for the new tool
   - `/Tests/MacMCPTests/ApplicationTests/CalculatorTests/` - Update calculator-specific tests
   - `/Tests/MacMCPTests/ApplicationTests/TextEditTests/` - Update TextEdit-specific tests

## 16. MCPServer Registration Updates

Update the `MCPServer.swift` file's `registerTools` method to register the new InterfaceExplorerTool instead of the three removed tools. This involves:

1. Removing the registration of UIStateTool (around line 272)
2. Removing the registration of InteractiveElementsDiscoveryTool (around line 346)
3. Removing the registration of ElementCapabilitiesTool (around line 358)
4. Adding the registration of InterfaceExplorerTool:

```swift
// Register the interface explorer tool
let interfaceExplorerTool = InterfaceExplorerTool(
    accessibilityService: accessibilityService,
    logger: logger
)
await registerTool(
    name: interfaceExplorerTool.name,
    description: interfaceExplorerTool.description,
    inputSchema: interfaceExplorerTool.inputSchema,
    annotations: interfaceExplorerTool.annotations,
    handler: interfaceExplorerTool.handler
)
```