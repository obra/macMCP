# Calculator Button Frame Detection Fix

## Summary of the Issue

We identified and fixed an issue with Calculator button frame detection in the MacMCP framework. The problem was that Calculator buttons were showing up with zero coordinates (0,0,0,0) in UI state responses, making them impossible to interact with.

## Root Cause

The root cause was identified in the `AccessibilityElement.swift` file where the frame information extraction from AXUIElements was not properly handling `AXValue` types. The code was primarily expecting `NSValue` types for position and size information, but Calculator's accessibility implementation returns `AXValue` types instead.

## Implementation Fix

We modified the frame detection code in `AccessibilityElement.swift` to properly handle both `NSValue` and `AXValue` types:

```swift
// Get frame with robust error handling
let frame: CGRect
do {
    // First try using AXPosition and AXSize directly which is more reliable
    var origin = CGPoint.zero
    var size = CGSize.zero
    var hasValidPosition = false
    var hasValidSize = false
    
    // Get position
    if let positionValue = try getAttribute(axElement, attribute: AXAttribute.position) {
        // Check for both NSValue and AXValue types since different macOS versions return different types
        if let nsValue = positionValue as? NSValue {
            origin = nsValue.pointValue
            hasValidPosition = true
        } else if CFGetTypeID(positionValue as CFTypeRef) == AXValueGetTypeID() {
            // It's an AXValue, extract the CGPoint
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
            hasValidPosition = true
        }
    }
    
    // Get size
    if let sizeValue = try getAttribute(axElement, attribute: AXAttribute.size) {
        // Check for both NSValue and AXValue types
        if let nsValue = sizeValue as? NSValue {
            size = nsValue.sizeValue
            hasValidSize = true
        } else if CFGetTypeID(sizeValue as CFTypeRef) == AXValueGetTypeID() {
            // It's an AXValue, extract the CGSize
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            hasValidSize = true
        }
    }
    
    if hasValidPosition && hasValidSize {
        frame = CGRect(origin: origin, size: size)
    } 
    // Fallback to AXFrame if position and size aren't available separately
    else if let axFrame = try getAttribute(axElement, attribute: AXAttribute.frame) as? NSValue {
        frame = axFrame.rectValue
    } else {
        // No valid frame information found
        frame = .zero
    }
} catch {
    NSLog("WARNING: Failed to get frame: \(error.localizedDescription)")
    frame = .zero
}
```

We also improved filtering in `UIStateTool.swift` to properly handle elements with invalid frames:

```swift
private func hasValidCoordinates(_ element: UIElement) -> Bool {
    // For root elements like Application or Window, always include them regardless of frame
    if element.role == "AXApplication" || element.role == "AXWindow" || element.role == "AXMenuBar" {
        return true
    }
    
    // For containers that might have valid children, be lenient
    if element.role == "AXGroup" || element.role == "AXSplitGroup" || element.children.count > 0 {
        return true
    }
    
    // For interactive elements, check if the frame is valid
    if element.frame.origin.x == 0 && element.frame.origin.y == 0 && 
       element.frame.size.width == 0 && element.frame.size.height == 0 {
        return false
    }
    
    return true
}
```

## Testing

We created several test scripts to verify the fix:

1. **Direct accessibility test**: Confirmed that Calculator buttons do have valid frames when accessed directly through the macOS Accessibility API.
2. **MCP UIState test**: Verified that MCP's `macos_ui_state` tool now returns Calculator buttons with valid frames.

Direct testing confirmed that Calculator buttons have valid frames when using the macOS Accessibility API directly. The frames are returned as `AXValue` types rather than `NSValue`:

```
Button 7 frame: (663.0, 575.0, 40.0, 40.0)
  - x: 663.0, y: 575.0
  - width: 40.0, height: 40.0
✅ Button 7 has a valid frame!
```

## Results

After implementing the fixes, Calculator buttons now have valid coordinates in UI state responses, making them properly interactive in the MCP framework. This enables Claude to successfully interact with the Calculator app, performing operations like clicking buttons and reading the display.