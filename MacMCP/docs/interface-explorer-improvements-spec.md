# InterfaceExplorer Tool Improvements Specification

## Current Problems

### 1. Token Verbosity
The InterfaceExplorer tool currently produces extremely verbose output that often exceeds token limits:
- Shows "normal case" states like "enabled", "visible", "unfocused", "unselected"
- Shows redundant name attributes when they match role or identifier
- Always shows coordinates and actions even when not needed
- Example: A simple button exploration can exceed 25,000 tokens

### 2. Limited Filtering
Current filtering is too restrictive:
- Only supports exact field matching (`titleContains`, `descriptionContains`, etc.)
- No way to search across all text fields simultaneously
- Requires knowing exactly which field contains the target text

### 3. Inclusion Controls
No way to control what types of elements are included:
- Always includes disabled elements
- Always includes non-interactable elements
- No way to focus on just actionable UI elements

## Proposed Improvements

### 1. Universal Text Search
Add `anyFieldContains` filter that searches across all string fields:
```json
{
  "scope": "application",
  "bundleId": "com.apple.iWork.Keynote",
  "filter": {
    "anyFieldContains": "New"
  }
}
```
This searches across: title, description, value, identifier, role description, and any other text fields.

### 2. Inclusion Control Parameters
Add top-level boolean parameters to control element inclusion:

```json
{
  "scope": "application", 
  "bundleId": "com.apple.iWork.Keynote",
  "includeDisabled": false,     // Default: false
  "includeNonInteractable": false  // Default: false
}
```

- `includeDisabled`: Include elements with disabled state
- `includeNonInteractable`: Include elements that cannot be acted upon

### 3. Output Filtering Parameters
Add parameters to control what information is returned:

```json
{
  "scope": "application",
  "bundleId": "com.apple.iWork.Keynote", 
  "showCoordinates": false,  // Default: false
  "showActions": false       // Default: false
}
```

- `showCoordinates`: Include position/size information
- `showActions`: Include available accessibility actions

### 4. Verbosity Reduction Rules

#### State Filtering
Do NOT show these "normal case" states:
- `enabled` (only show `disabled`)
- `visible` (only show `hidden`/`invisible`) 
- `unfocused` (only show `focused`)
- `unselected` (only show `selected`)

#### Name Deduplication
Do NOT show `name` attribute when:
- `name` == `role` (e.g., don't show name="button" when role="AXButton")
- `name` == `identifier` (e.g., don't show name="Save" when identifier="Save")

#### Before/After Examples

**Before (Current - 150+ tokens):**
```json
{
  "id": "button-123",
  "role": "AXButton", 
  "name": "Save",
  "identifier": "Save",
  "description": "Save document",
  "state": ["enabled", "visible", "unfocused", "unselected"],
  "coordinates": {"x": 100, "y": 200, "width": 80, "height": 30},
  "actions": ["AXPress", "AXFocus"]
}
```

**After (Proposed - 50+ tokens):**
```json
{
  "id": "button-123", 
  "role": "AXButton",
  "description": "Save document"
}
```

## Implementation Requirements

### 1. Apply to All Element Returns
These verbosity improvements must apply to:
- InterfaceExplorer tool responses
- Element updates after UI interactions (UIInteractionTool, etc.)
- Any other tool that returns element information

### 2. Backward Compatibility
The new parameters should be optional with sensible defaults:
- `includeDisabled`: default `false` 
- `includeNonInteractable`: default `false`
- `showCoordinates`: default `false`
- `showActions`: default `false`

### 3. Performance Considerations
- `anyFieldContains` should be efficient for large UI trees
- Filtering should happen during traversal, not after
- Consider indexing frequently searched fields

## Expected Benefits

### Token Reduction
- Estimated 60-80% reduction in response size
- More elements can fit within token limits
- Faster processing and lower costs

### Improved Usability  
- `anyFieldContains` makes exploration much easier
- Focus on actionable elements reduces noise
- Optional detail allows targeted information gathering

### Better Tool Integration
- Reduced verbosity improves tool chaining
- Consistent element representation across all tools
- More predictable token usage for complex workflows

## Migration Strategy

1. **Phase 1**: Implement verbosity reduction (immediate wins)
2. **Phase 2**: Add inclusion control parameters  
3. **Phase 3**: Add output filtering parameters
4. **Phase 4**: Implement `anyFieldContains` search
5. **Phase 5**: Apply improvements to other tools returning elements

Each phase can be implemented and tested independently.