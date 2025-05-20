# Path Filtering Fix Plan

## Issue Description

The `--path-filter` option in `mcp-ax-inspector` doesn't work correctly when the filter is a UI element selector pattern (e.g., "AXButton[@AXDescription=\"1\"]") rather than a fully qualified path. The current implementation only handles path filters that start with "macos://ui/" and doesn't properly process non-path UI element filters.

When running:
```
swift build && cd /Users/jesse/Documents/GitHub/projects/mac-mcp/MacMCP && open -a Calculator && sleep 1 && ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --max-depth 3 --raw-json --path-filter "AXButton[@AXDescription=\"1\"]"
```

The tool returns a full tree dump instead of filtering for the specific AXButton with description="1".

## Root Cause Analysis

1. In `main.swift`, the `pathFilter` command-line argument is processed correctly but not properly used in the query.

2. The `effectiveInspectPath` is set to:
   ```swift
   let effectiveInspectPath = inspectPath ?? (pathFilter?.hasPrefix("macos://ui/") == true ? pathFilter : nil)
   ```
   This only uses the `pathFilter` value if it starts with "macos://ui/", otherwise it's ignored.

3. For non-path filters (like "AXButton[@AXDescription=\"1\"]"), there's no handling to convert it to an appropriate filter query for InterfaceExplorerTool.

4. The InterfaceExplorerTool API supports filtering by role, title, description, etc., but the path filter isn't being converted to use these parameters.

## Proposed Fix

1. Update the `MCPInspector.inspectApplication` method to properly handle path filter patterns that don't have the "macos://ui/" prefix:

```swift
func inspectApplication(pathFilter: String? = nil) async throws -> MCPUIElementNode {
    // Existing code...
    
    // If we have a path filter, process it properly based on its format
    if let pathFilter = pathFilter {
        if pathFilter.hasPrefix("macos://ui/") {
            // This is a complete path - use server-side path resolution
            print("Using server-side path resolution for: \(pathFilter)")
            do {
                return try await inspectElementByPath(bundleIdentifier: bundleIdentifier, path: pathFilter, maxDepth: maxDepth)
            } catch {
                // If path-based inspection fails, fall back to normal app inspection
                print("Path-based inspection failed with error: \(error.localizedDescription)")
                print("Falling back to standard application inspection")
                // Continue with standard app inspection
            }
        } else {
            // This is a UI element filter pattern, not a path
            print("Using filter pattern: \(pathFilter)")
            
            // Parse the filter pattern to extract role and attributes
            if let (role, attributes) = parseFilterPattern(pathFilter) {
                // Use parsed information to create appropriate filter parameters
                return try await fetchFilteredUIStateData(
                    bundleIdentifier: bundleIdentifier,
                    role: role,
                    attributes: attributes,
                    maxDepth: maxDepth
                )
            }
        }
    }
    
    // Continue with standard inspection if no filter or filter parsing failed
    // ...existing code...
}
```

2. Add helper methods to parse filter patterns and fetch filtered data:

```swift
/// Parse a filter pattern like "AXButton[@AXDescription=\"1\"]" into role and attributes
private func parseFilterPattern(_ pattern: String) -> (role: String, attributes: [String: String])? {
    // Simple regex-based parsing logic
    // Extract role (everything before any [ character)
    var role: String?
    var attributes: [String: String] = [:]
    
    // Extract role
    if let roleEndIndex = pattern.firstIndex(of: "[") {
        role = String(pattern[..<roleEndIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
        // If no attributes are specified, the whole string is the role
        role = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Extract attributes using regex
    let attributePattern = "\\[@([^=]+)=\"([^\"]+)\"\\]"
    let regex = try? NSRegularExpression(pattern: attributePattern)
    let nsRange = NSRange(pattern.startIndex..<pattern.endIndex, in: pattern)
    
    if let regex = regex {
        let matches = regex.matches(in: pattern, options: [], range: nsRange)
        for match in matches {
            // Extract attribute name and value
            if match.numberOfRanges == 3,
               let nameRange = Range(match.range(at: 1), in: pattern),
               let valueRange = Range(match.range(at: 2), in: pattern) {
                let name = String(pattern[nameRange])
                let value = String(pattern[valueRange])
                attributes[name] = value
            }
        }
    }
    
    guard let extractedRole = role else {
        return nil
    }
    
    return (extractedRole, attributes)
}

/// Fetch UI state with specific filter criteria
private func fetchFilteredUIStateData(
    bundleIdentifier: String,
    role: String,
    attributes: [String: String],
    maxDepth: Int
) async throws -> MCPUIElementNode {
    guard let mcpClient = self.mcpClient else {
        throw InspectionError.unexpectedError("MCP client not initialized")
    }
    
    // Start MCP server if needed
    try await startMCPIfNeeded()
    
    // Create filter for InterfaceExplorerTool
    var filter: [String: Value] = [:]
    
    // Add role filter
    filter["role"] = .string(role)
    
    // Add attribute filters
    for (key, value) in attributes {
        if key.lowercased().contains("title") {
            filter["titleContains"] = .string(value)
        } else if key.lowercased().contains("description") {
            filter["descriptionContains"] = .string(value)
        } else if key.lowercased().contains("value") {
            filter["valueContains"] = .string(value)
        }
    }
    
    // Create the request parameters
    let arguments: [String: Value] = [
        "scope": .string("application"),
        "bundleId": .string(bundleIdentifier),
        "maxDepth": .int(maxDepth),
        "includeHidden": .bool(true),
        "filter": .object(filter)
    ]
    
    // Send request to MCP
    print("Sending filtered request to MCP for: \(bundleIdentifier) with filter: \(filter)")
    let (content, isError) = try await mcpClient.callTool(
        name: "macos_interface_explorer",
        arguments: arguments
    )
    
    if let isError = isError, isError {
        throw InspectionError.unexpectedError("Error from MCP tool: \(content)")
    }
    
    // Process the response
    guard let firstContent = content.first, 
          case let .text(jsonString) = firstContent else {
        throw InspectionError.unexpectedError("Invalid response format from MCP: missing text content")
    }
    
    // Convert the JSON string to data and create a node
    guard let jsonData = jsonString.data(using: .utf8) else {
        throw InspectionError.unexpectedError("Failed to convert JSON string to data")
    }
    
    // Parse the JSON into an array of dictionaries
    let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
    guard let rootJson = jsonArray?.first else {
        throw InspectionError.unexpectedError("Invalid JSON response from MCP or no matching elements found")
    }
    
    // Reset element counter
    elementIndex = 0
    
    // Create the root node
    let rootNode = MCPUIElementNode(jsonElement: rootJson, index: elementIndex)
    elementIndex += 1
    
    // Recursively populate children
    _ = rootNode.populateChildren(from: rootJson, startingIndex: elementIndex)
    
    return rootNode
}
```

3. Update `main.swift` to properly handle non-path filters:

```swift
// Instead of:
let effectiveInspectPath = inspectPath ?? (pathFilter?.hasPrefix("macos://ui/") == true ? pathFilter : nil)

// Do this:
let effectiveInspectPath = inspectPath
let pathFilterValue = pathFilter  // Keep the original path filter for filtering
```

4. Then update the AsyncInspectionTask to accept the pathFilter:

```swift
let asyncTask = AsyncInspectionTask(
    inspector: inspector,
    showMenuDetail: showMenuDetail,
    menuPath: menuPath,
    showWindowDetail: showWindowDetail,
    windowId: windowId,
    inspectPath: effectiveInspectPath,
    pathFilter: pathFilterValue,  // Pass the path filter
    onComplete: { root, additionalInfo in
        resultRootElement = root
        additionalOutput = additionalInfo
        semaphore.signal()
    },
    onError: { error in
        resultError = error
        semaphore.signal()
    }
)
```

## Implementation Plan

1. Update the `MCPInspector` class to properly handle non-path filter patterns
2. Add helper methods to parse filter patterns and construct appropriate filter queries
3. Modify `main.swift` to properly pass path filters to the inspector
4. Update `AsyncInspectionTask` to support both path-based inspection and filter-based inspection

## Testing

Once implemented, test with:

```bash
swift build && cd /Users/jesse/Documents/GitHub/projects/mac-mcp/MacMCP && open -a Calculator && sleep 1 && ./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --max-depth 3 --raw-json --path-filter "AXButton[@AXDescription=\"1\"]"
```

The output should show only the matching AXButton elements with description="1" rather than the entire tree.