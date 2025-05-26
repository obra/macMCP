# Path Resolution Enhancement Specification

To complete the positional indexing feature, we need to enhance the path resolution system to understand and handle the `#index` syntax.

## Current State Analysis

### Existing Path Resolution Components
1. **ElementPath.swift** - Main path parsing and structure
2. **ElementPathParser.swift** - Converts path strings to ElementPath objects  
3. **PathSegment.swift** - Individual path segments with role/attributes
4. **AccessibilityService.findElementByPath()** - Resolves paths to actual UI elements

### Current Path Resolution Flow
```
"macos://ui/AXWindow/AXButton[@AXDescription=\"Add\"]"
    ↓ ElementPathParser.parse()
    ↓ Creates PathSegment objects
    ↓ AccessibilityService.findElementByPath()
    ↓ Traverses UI tree matching segments
    ↓ Returns UIElement or throws error
```

## Required Enhancements

### 1. PathSegment Enhancement
**File:** `Sources/MacMCP/Models/PathSegment.swift`

**Current Structure:**
```swift
public struct PathSegment {
    public let role: String
    public let attributes: [String: String]
    public let index: Int?  // Already exists but unused
}
```

**Enhancement Needed:**
- Ensure `index` property is properly populated during parsing
- Update `toString()` method to generate `AXRole#index[@attributes]` format
- Add validation that index is 1-based positive integer

### 2. ElementPathParser Enhancement  
**File:** `Sources/MacMCP/Models/ElementPathParser.swift`

**Current Parsing Logic:**
```swift
// Current regex probably looks like: AXRole[@attr="value"][@attr2="value2"]
// Needs to support: AXRole#index[@attr="value"][@attr2="value2"]
```

**Enhancement Needed:**
```swift
private static func parsePathSegment(_ segment: String) throws -> PathSegment {
    // New regex pattern to capture: role, optional #index, optional attributes
    // Pattern: ^(AX\w+)(?:#(\d+))?(?:\[@(.+)\])?$
    
    // Examples to parse:
    // "AXButton" -> role="AXButton", index=nil, attributes=[]
    // "AXButton#3" -> role="AXButton", index=3, attributes=[]  
    // "AXButton[@AXDescription=\"Add\"]" -> role="AXButton", index=nil, attributes=[...]
    // "AXButton#2[@AXDescription=\"Add\"]" -> role="AXButton", index=2, attributes=[...]
}
```

**Parsing Algorithm:**
1. **Extract role** - everything before `#` or `[`
2. **Extract index** - number after `#` (if present)
3. **Extract attributes** - everything in `[@...]` sections
4. **Validate index** - must be positive integer if present
5. **Create PathSegment** with all components

### 3. Path Resolution Logic Enhancement
**File:** `Sources/MacMCP/Accessibility/AccessibilityService.swift`

**Current Resolution:**
```swift
public func findElementByPath(path: String) async throws -> UIElement? {
    // Parse path into segments
    // For each segment, find matching children
    // Return first match or throw error if not found
}
```

**Enhanced Resolution Algorithm:**
```swift
private func resolveSegment(_ segment: PathSegment, in parent: AXUIElement) throws -> AXUIElement {
    // Get all children of parent
    let children = try getChildren(of: parent)
    
    // Find all children matching the base criteria (role + attributes)
    let matchingChildren = children.filter { child in
        return matchesSegment(child, segment: segment, ignoreIndex: true)
    }
    
    if let index = segment.index {
        // Positional resolution: return the child at the specified position
        guard index >= 1 && index <= matchingChildren.count else {
            throw PathResolutionError.indexOutOfRange(index, availableCount: matchingChildren.count)
        }
        return matchingChildren[index - 1]  // Convert to 0-based
    } else {
        // No index specified
        if matchingChildren.count == 1 {
            return matchingChildren[0]  // Unique match
        } else if matchingChildren.count > 1 {
            // Multiple matches but no index - this is ambiguous
            throw PathResolutionError.ambiguousMatch(count: matchingChildren.count, segment: segment)
        } else {
            throw PathResolutionError.noMatch(segment: segment)
        }
    }
}
```

### 4. Error Handling Enhancement
**File:** `Sources/MacMCP/Models/ElementPathError.swift`

**New Error Cases:**
```swift
public enum ElementPathError: Error, Equatable {
    // ... existing cases ...
    
    /// The positional index is out of range for available siblings
    case indexOutOfRange(Int, availableCount: Int)
    
    /// Multiple elements match the base path but no index was specified
    case ambiguousMatch(count: Int, segment: PathSegment)
    
    /// Invalid index syntax (not a positive integer)
    case invalidIndexSyntax(String)
    
    /// Index specified but no siblings match the base path
    case indexWithoutMatches(Int, segment: PathSegment)
}
```

### 5. Backward Compatibility
**Requirement:** Existing paths without indices must continue to work

**Strategy:**
- Paths without `#index` resolve as before
- If multiple matches exist and no index specified:
  - **Option A:** Return first match (current behavior)
  - **Option B:** Throw ambiguous match error (stricter)
  - **Recommendation:** Option A for backward compatibility

### 6. Round-trip Compatibility  
**Requirement:** Paths generated with indices should parse and resolve correctly

**Test Cases:**
```swift
// Path generation creates: "AXButton#2[@AXDescription=\"Add\"]"
// Path parsing should extract: role="AXButton", index=2, attributes=["AXDescription": "Add"]
// Path resolution should find: 2nd child matching AXButton[@AXDescription="Add"]
// Generated path should be: identical to original
```

## Implementation Plan

### Phase 1: Parser Enhancement
1. Update regex patterns in `ElementPathParser`
2. Enhance `parsePathSegment()` to extract index
3. Update `PathSegment.toString()` to include index
4. Add unit tests for all parsing scenarios

### Phase 2: Resolution Enhancement  
1. Update `resolveSegment()` in `AccessibilityService`
2. Add positional matching logic
3. Implement comprehensive error handling
4. Add integration tests with real UI elements

### Phase 3: Error Handling
1. Add new error cases to `ElementPathError`
2. Update error messages to be helpful for debugging
3. Add error handling tests

### Phase 4: Compatibility Testing
1. Test all existing paths still resolve correctly
2. Test round-trip: generate → parse → resolve → generate
3. Test edge cases (empty indices, out of range, etc.)

## Key Design Decisions

### Index Numbering
- **1-based indexing** in paths (user-friendly)
- **0-based indexing** internally (Swift arrays)
- **Conversion** handled in resolution layer

### Ambiguous Resolution Strategy
- **Without index + single match** → Return the match
- **Without index + multiple matches** → Return first match (backward compatibility)
- **With index + no matches** → Error (invalid path)
- **With index + out of range** → Error (invalid index)

### Regex Pattern Design
```regex
^(AX\w+)(?:#(\d+))?(?:\[@(.+)\])*$

Groups:
1. Role (required): AX followed by word characters  
2. Index (optional): # followed by digits
3. Attributes (optional): [@key="value"] patterns
```

This specification provides a complete roadmap for implementing path resolution with positional indexing support. Would you like me to proceed with implementing any specific phase?