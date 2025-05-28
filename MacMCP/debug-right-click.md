# Debug Report: Right-Click Test Failure

## Issue Summary

The UIInteractionToolE2ETests right-click test is failing because `textEditHelper.app.getTextArea()` returns `nil`, even though TextEdit is visibly open with a document containing text.

## Root Cause Analysis

### Expected vs Actual Behavior

**Expected**: `ToolChain.findElements()` should return many UI elements including `AXTextArea` elements when searching TextEdit with a document open.

**Actual**: `ToolChain.findElements()` only returns 1 element - the root `AXApplication TextEdit` element.

### Key Discovery

The MCP inspector tool successfully finds many elements including multiple `AXTextArea` elements when run with:
```bash
./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --show-window-contents
```

But the test framework's `ToolChain.findElements()` only returns the application root element.

## Technical Details

### Debug Output Analysis

From the failing test debug output:

```
DEBUG: ToolChain.findElements calling interfaceExplorerTool with params: 
["scope": application, "maxDepth": 15, "bundleId": com.apple.TextEdit, "showCoordinates": true, "inMainContent": true]
DEBUG: interfaceExplorerTool returned: 1 result items
DEBUG: Total elements found: 1
DEBUG: Element 0: role=AXApplication TextEdit, path=zG4xaWRqRAa1UUgUciWJdA
DEBUG: TextArea elements found: 0
```

vs. successful MCP inspector output showing elements like:
```json
{
  "id": "XPtnPU1PSdilBodXLY-lcw",
  "props": "editable, selectable, hasMenu",
  "value": "Right-click test text",
  "role": "AXTextArea First Text View"
}
```

### Parameter Comparison

**MCP Inspector (works)**: Uses `--show-window-contents` flag
**ToolChain (fails)**: Uses `"inMainContent": true` parameter

Both should be equivalent but they produce different results.

### Code Locations

1. **Failing method**: `TextEditModel.getTextArea()` in `/Tests/TestsWithoutMocks/TestFramework/ApplicationModels/TextEditModel.swift:129`

2. **Core issue**: `ToolChain.findElements()` in `/Tests/TestsWithoutMocks/TestFramework/ToolChain.swift:203`

3. **InterfaceExplorerTool call**: Line 268 in ToolChain.swift

## Investigation Timeline

1. **Initial symptoms**: Test failure with "Failed to find TextEdit text area"

2. **First hypothesis**: Role mismatch between `"AXTextArea"` and `"AXTextArea First Text View"`
   - **Status**: Disproven - the verbose role text is JSON display only

3. **Second hypothesis**: TextEdit not in correct state
   - **Status**: Disproven - user confirmed TextEdit is visibly open with text

4. **Third hypothesis**: Document not created properly
   - **Status**: Disproven - text is successfully typed and visible

5. **Current hypothesis**: ToolChain parameters differ from MCP inspector parameters
   - **Status**: Under investigation

## Attempted Fixes

### 1. Added Debug Logging
```swift
print("DEBUG: getTextArea() called, bundleId = \(bundleId)")
print("DEBUG: Total elements found: \(allElements.count)")
```

### 2. Added inMainContent Parameter
```swift
// Include main content (windows and their contents) - this is equivalent to --show-window-contents
params["inMainContent"] = .bool(true)
```
**Result**: No change - still only returns 1 element

### 3. Parameter Investigation
Added debug logging to see exact parameters sent to InterfaceExplorerTool:
```
["scope": application, "maxDepth": 15, "bundleId": com.apple.TextEdit, "showCoordinates": true, "inMainContent": true]
```

## Current Status

The issue is that `InterfaceExplorerTool.handler()` is not exploring the UI hierarchy despite:
- Correct `scope: "application"`
- Correct `bundleId: "com.apple.TextEdit"`
- Adequate `maxDepth: 15`
- Added `inMainContent: true`

There appears to be a discrepancy between how the MCP inspector calls the InterfaceExplorerTool vs how the test framework's ToolChain calls it.

## Next Steps

1. **Compare exact InterfaceExplorerTool calls**: Determine the precise parameter differences between MCP inspector and ToolChain

2. **Check InterfaceExplorerTool implementation**: Review how `inMainContent` vs `--show-window-contents` are processed

3. **Test parameter variations**: Try different parameter combinations to match MCP inspector behavior

4. **Verify element hierarchy**: Confirm TextEdit UI structure hasn't changed

## Files Modified During Investigation

1. `/Tests/TestsWithoutMocks/TestFramework/ApplicationModels/TextEditModel.swift` - Added debug logging
2. `/Tests/TestsWithoutMocks/TestFramework/ToolChain.swift` - Added debug logging and `inMainContent` parameter

## Test Commands Used

```bash
# Failing test
swift test --filter UIInteractionToolE2ETests/testRightClick --no-parallel

# Working MCP inspector
open -a TextEdit; sleep 1; ./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --show-window-contents --raw-json

# Debug element discovery
./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --show-window-contents
```

## Key Insight

The fundamental issue is that `ToolChain.findElements()` and the MCP inspector are calling the same `InterfaceExplorerTool` but getting radically different results:
- **MCP inspector**: Returns hundreds of elements including windows, text areas, buttons, etc.
- **ToolChain**: Returns only 1 element (the application root)

This suggests either:
1. A parameter mapping issue between ToolChain and InterfaceExplorerTool
2. A bug in InterfaceExplorerTool's parameter processing
3. A difference in how the tools are instantiated or configured