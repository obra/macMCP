# MacMCP Resources Implementation Plan

This document outlines a step-by-step test-driven implementation plan for adding MCP resource support to MacMCP. Each step includes specific prompts for the LLM to efficiently implement the required functionality.

## Phase 0: Test Infrastructure

### Step 1: Create Resource Tests
```prompt
Create comprehensive tests for the resource implementation (before implementing the functionality).

- [x] Create ResourcesTests.swift with mock services
- [x] Create ResourcesTests.swift stub (initial placeholder version)
- [ ] Test resources list method
- [ ] Test resource templates list method
- [ ] Test applications resource
- [ ] Test application menus resource
- [ ] Test application windows resource
- [ ] Test UI element resource
- [ ] Test interactable elements resource
- [ ] Test error handling for invalid resources
- [ ] Test resource parameter validation
```

## Phase 1: Resource Infrastructure

### Step 2: Add Resource Method Handlers
```prompt
Create the infrastructure for handling resource methods in MacMCP. 

- [x] Implement the ResourcesRead method handler following MCP specification
- [x] Implement the ResourcesTemplatesList method handler following MCP specification
- [x] Add resource URI parsing utilities
- [x] Add resource parameters structure for query parameters
- [x] Create resource handler protocol
- [x] Create resource registry class

For ResourcesRead:
- [x] Parameter parsing
- [x] Content structure (text, binary)
- [x] Metadata structure
- [x] Resource resolution logic
- [x] Error handling for invalid resources

For ResourcesTemplatesList:
- [x] Template data structures
- [x] Parameter definition structures
- [x] Template registration system
- [ ] Template discovery
```

### Step 3: Integrate with MCPServer
```prompt
Integrate the resource handling infrastructure into the MCPServer class. 

- [x] Create resource method handlers (ResourcesReadMethodHandler, etc.)
- [x] Update the server capabilities to properly advertise resource support
- [x] Add methods to register resource handlers and templates
- [x] Wire up the resource method handlers to the MCP framework
- [x] Add resource-related logging
- [x] Register resource handler registry with the server
- [x] Update server initialization to include resource support
- [x] Add appropriate debug logging
```

## Phase 2: Core Resource Types

### Step 4: Implement Applications Resource
```prompt
Implement the applications resource that provides information about running applications.

- [x] Create ApplicationsResourceHandler class
- [ ] Register handler for URI pattern `macos://applications`
- [x] Use ApplicationService to get running applications
- [x] Format application info as JSON response
- [ ] Add appropriate caching to avoid repeated system calls
- [x] Handle error cases properly

The response should include:
- [x] Bundle identifiers as keys
- [x] Application names as values
- [ ] Basic application info (running state, active)
```

### Step 5: Implement Application Menu Resource
```prompt
Implement the application menu resource that provides menu structures for applications.

- [x] Create ApplicationMenusResourceHandler class
- [x] Register handler for URI pattern `macos://applications/{bundleId}/menus`
- [x] Extract the bundle ID from the URI
- [x] Use MenuNavigationService to retrieve menu structure
- [x] Format menu structure as JSON response
- [x] Implement proper error handling for invalid bundle IDs

The response should include:
- [x] Menu titles and hierarchy
- [x] Menu item paths
- [x] Enabled/disabled state
- [x] Keyboard shortcuts if available
```

### Step 6: Implement Application Windows Resource
```prompt
Implement the application windows resource that lists windows for applications.

- [x] Create ApplicationWindowsResourceHandler class
- [x] Register handler for URI pattern `macos://applications/{bundleId}/windows`
- [x] Extract the bundle ID from the URI
- [x] Use AccessibilityService to retrieve window information
- [x] Format window information as JSON response
- [x] Implement proper error handling for invalid bundle IDs

The response should include:
- [x] Window titles
- [x] Window IDs/paths
- [x] Position and size information
- [x] Minimized/maximized state
- [x] Main window flag
```

## Phase 3: UI Element Resources

### Step 7: Implement UI Element Resource
```prompt
Implement the UI element resource that provides access to UI elements by path.

- [x] Create UIElementResourceHandler class
- [x] Register handler for URI pattern `macos://ui/{uiPath}`
- [x] Extract the UI path from the URI
- [x] Parse query parameters for maxDepth etc.
- [x] Use AccessibilityService to resolve and retrieve the element
- [x] Format the element info as JSON response
- [x] Handle errors for invalid paths

The response should include:
- [x] Element role, title, description
- [x] Element state (enabled, visible)
- [x] Element hierarchy (children) up to maxDepth
- [x] Element capabilities (clickable, editable)
- [x] Path information
```

### Step 8: Implement Interactable Elements Filter
```prompt
Implement the interactable elements filter for the UI element resource.

- [x] Add interactable query parameter to UIElementResourceHandler
- [x] Update handler to return array of elements when interactable=true
- [x] Add `limit` parameter to control number of results
- [x] Implement filtering logic to find elements with interactive capabilities
- [x] Apply filter to element tree traversal
- [x] Return only elements that can be interacted with
- [x] Update documentation to reflect the query parameter approach

The response should include:
- [x] Element paths
- [x] Element roles and titles
- [x] Element capabilities (clickable, editable, etc.)
- [x] Enabled/disabled state
```

## Phase 4: Resource Templates

### Step 9: Implement Resource Templates
```prompt
Implement resource templates for dynamic resource discovery.

- [x] Create template structures for:
  - UI element paths: `macos://ui/{path}`
  - Application menus: `macos://applications/{bundleId}/menus`
  - Application windows: `macos://applications/{bundleId}/windows`
  - Interactable elements: `macos://ui/{uiPath}/interactables`
- [x] Create ResourceTemplateFactory for centralized template creation
- [x] Implement template parameter validation
- [x] Add template documentation
- [x] Add template examples

Ensure templates properly represent the available resource types and their parameters.
```

## Phase 5: Integration and Documentation

### Step 10: Update Documentation
```prompt
Update documentation to reflect the new resource capabilities.

- [x] Add resource documentation to the resources-spec.md
- [x] Add code documentation for resource handlers
- [x] Document resource URI formats and parameters
- [x] Provide examples of resource usage
- [ ] Create a user-facing guide for resource capabilities
```

## Implementation Notes

1. **Path Format**: All UI element paths use the `macos://ui/` scheme.

2. **Resource URIs**:
   - `macos://applications` - Running applications
   - `macos://applications/{bundleId}/menus` - Application menus
   - `macos://applications/{bundleId}/windows` - Application windows
   - `macos://ui/{uiPath}` - UI element tree

3. **Query Parameters**:
   - `maxDepth` - Tree traversal depth
   - `limit` - Result limit
   - `filter` - Element filtering
   - `interactable` - Show only interactive elements

4. **Content Types**:
   - All resources return JSON content
   - Use ResourceContent.text for JSON strings
   - Use proper MIME types in metadata