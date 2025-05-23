# Application Lookup Optimization Specification

## Problem Statement

The `ApplicationLookupTests` in MacMCP are experiencing a significant delay of approximately 12 seconds during the first test run. Analysis has identified that the primary bottleneck is in resolving application elements via accessibility APIs, specifically when using `AXUIElementCopyAttributeValue` with `kAXApplicationsAttribute` to retrieve all running applications.

## Current Implementation

The current implementation in `ElementPath.resolve()`:

1. Creates a system-wide accessibility element
2. Retrieves all running applications using `AXUIElementCopyAttributeValue(systemWideElement, kAXApplicationsAttribute)`
3. Iterates through every application to find one matching the specified criteria (title and/or bundleId)
4. This approach is particularly slow on first execution due to:
   - macOS building the entire accessibility hierarchy across all applications
   - The need to search through every application
   - Cold cache performance penalties

## Proposed Optimization

### 1. Fast Path for BundleId Lookups

When a bundleId is available in the ElementPath:

```swift
// Fast path when bundleId is available
if let bundleId = attributes["bundleId"] as? String {
    // Use NSRunningApplication to find matching applications (fast)
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    
    if let app = runningApps.first {
        // Create AXUIElement directly from PID (fast)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // If title is also specified, verify the title matches
        if let requiredTitle = attributes["AXTitle"] as? String {
            var titleRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, "AXTitle" as CFString, &titleRef)
            
            // If title check passes, return the element
            if status == .success, let title = titleRef as? String, title == requiredTitle {
                return appElement
            }
        } else {
            // No title specified, bundleId match is sufficient
            return appElement
        }
    }
}
```

### 2. Fallback Path for Title-Only Lookups

Only when bundleId is not available:

```swift
// Fallback for title-only lookups
if let requiredTitle = attributes["AXTitle"] as? String {
    // Cache the application list between calls
    if cachedApplicationElements == nil {
        let systemWideElement = AXUIElementCreateSystemWide()
        var applicationArray: CFArray?
        let status = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXApplicationsAttribute as CFString,
            &applicationArray
        )
        
        if status == .success, let applications = applicationArray as? [AXUIElement] {
            cachedApplicationElements = applications
        }
    }
    
    // Search through cached application elements
    if let applications = cachedApplicationElements {
        for appElement in applications {
            var titleRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(appElement, "AXTitle" as CFString, &titleRef)
            
            if status == .success, let title = titleRef as? String, title == requiredTitle {
                return appElement
            }
        }
    }
}
```

### 3. Cache Implementation

Add a cache mechanism for application elements:

```swift
// Static cache for application elements - reused across resolutions
private static var cachedApplicationElements: [AXUIElement]?
private static var cacheTimestamp: Date?
private static let cacheLifetime: TimeInterval = 30.0 // 30 seconds cache validity
```

Cache invalidation logic:

```swift
// Invalidate cache if older than cacheLifetime
private func validateCache() {
    if let timestamp = Self.cacheTimestamp, 
       Date().timeIntervalSince(timestamp) > Self.cacheLifetime {
        Self.cachedApplicationElements = nil
        Self.cacheTimestamp = nil
    }
}
```

### 4. Performance Logging

Add instrumentation for performance monitoring:

```swift
// Timing for performance metrics
let startTime = Date()
// ... perform lookup operation
let elapsed = Date().timeIntervalSince(startTime)
logger.debug("Application lookup completed in \(elapsed) seconds")
```

## Expected Benefits

1. **Significant Performance Improvement**: BundleId-based lookups should complete in <100ms instead of 10+ seconds
2. **Reduced System Impact**: Avoiding full accessibility hierarchy traversal when unnecessary
3. **Better Cold Start**: First-time lookups will be much faster when bundleId is available
4. **Compatibility**: No API or interface changes, existing code will continue to work
5. **Test Performance**: Tests will run significantly faster, especially ApplicationLookupTests

## Implementation Plan

1. Modify `ElementPath.resolve()` to add the fast path implementation
2. Add caching mechanism for application elements
3. Add performance logging
4. Update tests to ensure compatibility and verify performance gains

## Testing Strategy

1. Run existing ApplicationLookupTests to verify functionality
2. Add performance tests comparing before and after implementations
3. Verify that application lookups by title-only still work correctly
4. Test with multiple applications to ensure robust behavior

## Risks and Mitigations

1. **Risk**: Cache invalidation issues could lead to stale references
   - **Mitigation**: Short cache lifetime and explicit cache invalidation on errors

2. **Risk**: Title verification could add overhead for bundleId+title lookups
   - **Mitigation**: Only verify title when explicitly requested in the path

3. **Risk**: Memory usage for cached application elements
   - **Mitigation**: Limited cache lifetime and holding only necessary references