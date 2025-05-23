# Tool Documentation Improvement Plan

This document outlines a systematic plan to improve the documentation and usability of all MacMCP tools, following the pattern established for the KeyboardInteractionTool.

## Overview

Based on feedback that Claude has trouble with our tools due to lacking documentation, we need to enhance each tool with:
1. Comprehensive descriptions with usage patterns and examples
2. Detailed input schemas with embedded examples
3. Proper tool annotations with behavioral hints

## Tools to Improve

### 1. UIInteractionTool (`Sources/MacMCP/Tools/UIInteractionTool.swift`)

**Current Issues:**
- Basic description: "Interact with UI elements on macOS - click, type, scroll and more"
- Schema lacks detailed examples and validation guidance
- Missing common usage patterns

**Improvement Prompt:**
```
Improve the UIInteractionTool documentation following the pattern used for KeyboardInteractionTool. The tool supports actions: click, double_click, right_click, drag, scroll.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of each action type
   - Common usage patterns (clicking buttons, scrolling lists, dragging files)
   - Important notes about elementPath format (macos://ui/ paths)
   - When to use position-based vs element-based interactions

2. Improve the input schema with:
   - Detailed descriptions for each parameter
   - Examples showing different action types
   - Validation guidance for required vs optional parameters
   - Common elementPath examples

3. Update annotations:
   - Better title (e.g., "macOS UI Interaction")
   - Ensure proper behavioral hints are set

Reference the existing KeyboardInteractionTool implementation for the style and depth of documentation needed.
```

### 2. ScreenshotTool (`Sources/MacMCP/Tools/ScreenshotTool.swift`)

**Current Issues:**
- Basic description about capturing screenshots
- Unclear about different region types and their requirements
- Missing examples for coordinate-based captures

**Improvement Prompt:**
```
Improve the ScreenshotTool documentation following the pattern used for KeyboardInteractionTool. The tool supports regions: full, area, window, element.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of each region type (full screen, specific area, window, UI element)
   - When to use each region type
   - Parameter requirements for each region
   - Common use cases (debugging UI, capturing specific windows, element inspection)

2. Improve the input schema with:
   - Detailed descriptions for each parameter
   - Examples for each region type
   - Clear indication of which parameters are required for which regions
   - Coordinate system explanation for area captures

3. Update annotations:
   - Better title (e.g., "macOS Screenshot Capture")
   - Ensure proper behavioral hints (readOnlyHint: true since it doesn't modify state)

Include examples like:
- Full screen: {"region": "full"}
- Specific area: {"region": "area", "x": 100, "y": 200, "width": 400, "height": 300}
- Application window: {"region": "window", "bundleId": "com.apple.calculator"}
```

### 3. InterfaceExplorerTool (`Sources/MacMCP/Tools/InterfaceExplorerTool.swift`)

**Current Issues:**
- Complex tool with many scope options but unclear documentation
- Filtering options not well explained
- Missing guidance on when to use different scopes

**Improvement Prompt:**
```
Improve the InterfaceExplorerTool documentation following the pattern used for KeyboardInteractionTool. This is a complex tool for exploring UI hierarchies with scopes: system, application, focused, position, element, path.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of each scope type and when to use them
   - Filtering capabilities and syntax
   - Common exploration patterns
   - Relationship to other tools (use this to find elements for UIInteractionTool)
   - Performance considerations (prefer 'focused' over 'system')

2. Improve the input schema with:
   - Detailed descriptions for each scope
   - Examples for common exploration scenarios
   - Filter syntax examples
   - Guidance on bundleId usage vs scope selection

3. Update annotations:
   - Better title (e.g., "macOS UI Explorer")
   - Proper behavioral hints (readOnlyHint: true)

Include examples like:
- Explore focused app: {"scope": "focused"}
- Find buttons in Calculator: {"scope": "application", "bundleId": "com.apple.calculator", "filter": {"role": "AXButton"}}
- Element at coordinates: {"scope": "position", "x": 400, "y": 300}
```

### 4. ApplicationManagementTool (`Sources/MacMCP/Tools/ApplicationManagementTool.swift`)

**Current Issues:**
- Covers multiple actions (launch, terminate, hide, show) but lacks clear action documentation
- Missing examples for different launch methods
- Unclear about app identification methods

**Improvement Prompt:**
```
Improve the ApplicationManagementTool documentation following the pattern used for KeyboardInteractionTool. The tool supports actions: launch, terminate, hide, show.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of each action type
   - Different ways to identify applications (name vs bundleId)
   - Common use cases and workflows
   - Security and permission considerations

2. Improve the input schema with:
   - Detailed descriptions for each action
   - Examples using both app names and bundle IDs
   - Guidance on when to use applicationName vs bundleId
   - Error handling expectations

3. Update annotations:
   - Better title (e.g., "macOS Application Management")
   - Proper behavioral hints (destructiveHint: true for terminate)

Include examples like:
- Launch by name: {"action": "launch", "applicationName": "Calculator"}
- Launch by bundle: {"action": "launch", "bundleId": "com.apple.calculator"}
- Terminate safely: {"action": "terminate", "bundleId": "com.apple.calculator"}
```

### 5. WindowManagementTool (`Sources/MacMCP/Tools/WindowManagementTool.swift`)

**Current Issues:**
- Many actions but unclear documentation about capabilities
- Missing coordinate system explanation
- Unclear about window identification

**Improvement Prompt:**
```
Improve the WindowManagementTool documentation following the pattern used for KeyboardInteractionTool. The tool supports multiple window management actions.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of all supported actions
   - Window identification methods (bundleId, windowId)
   - Coordinate system explanation
   - Common window management workflows

2. Improve the input schema with:
   - Detailed descriptions for each action
   - Examples for positioning, resizing, and state changes
   - Required vs optional parameters for each action
   - Window selection strategies

3. Update annotations:
   - Better title (e.g., "macOS Window Management")
   - Proper behavioral hints

Reference the docs/WindowManagementTool.md if it exists for technical details.
```

### 6. MenuNavigationTool (`Sources/MacMCP/Tools/MenuNavigationTool.swift`)

**Current Issues:**
- Complex menu path requirements not well documented
- Action types unclear
- Missing examples for menu item identification

**Improvement Prompt:**
```
Improve the MenuNavigationTool documentation following the pattern used for KeyboardInteractionTool. The tool supports menu exploration and activation.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of menu navigation concepts
   - Menu path format and identification
   - Different action types supported
   - Relationship to InterfaceExplorerTool for menu discovery

2. Improve the input schema with:
   - Detailed descriptions for each action
   - Menu path format examples
   - Application-specific considerations
   - Common menu navigation patterns

3. Update annotations:
   - Better title (e.g., "macOS Menu Navigation")
   - Proper behavioral hints

Reference docs/menu-navigation-implementation-plan.md and related docs for technical details.
```

### 7. ClipboardManagementTool (`Sources/MacMCP/Tools/ClipboardManagementTool.swift`)

**Current Issues:**
- Multiple content types (text, images, files) not clearly explained
- Action types unclear
- Missing examples for different data types

**Improvement Prompt:**
```
Improve the ClipboardManagementTool documentation following the pattern used for KeyboardInteractionTool. The tool supports different clipboard content types and operations.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of supported content types (text, images, files)
   - Different action types (get, set, clear operations)
   - Data format requirements
   - Common clipboard workflows

2. Improve the input schema with:
   - Detailed descriptions for each action and content type
   - Examples for text, image, and file operations
   - Data encoding requirements (base64 for images)
   - Format specifications

3. Update annotations:
   - Better title (e.g., "macOS Clipboard Management")
   - Proper behavioral hints

Include examples for all content types and operations.
```

### 8. OnboardingTool (`Sources/MacMCP/Tools/OnboardingTool.swift`)

**Current Issues:**
- Purpose and usage not clear from description
- Topic structure unclear
- Missing guidance on when to use

**Improvement Prompt:**
```
Improve the OnboardingTool documentation following the pattern used for KeyboardInteractionTool. This tool provides guidance for AI assistants using MacMCP.

Key improvements needed:
1. Enhance the description to include:
   - Clear explanation of the tool's purpose (AI assistant guidance)
   - Available topics and what each covers
   - When AI assistants should use this tool
   - How it relates to other tools and workflows

2. Improve the input schema with:
   - Detailed descriptions of available topics
   - Examples of when to request specific guidance
   - Clear topic taxonomy

3. Update annotations:
   - Better title (e.g., "MacMCP Assistant Guidance")
   - Proper behavioral hints (readOnlyHint: true)

Reference the existing guidance files in Sources/MacMCP/Tools/OnboardingTool/ for content details.
```

## Implementation Notes

### Common Patterns to Follow

1. **Description Structure:**
   ```
   Brief one-line summary.
   
   IMPORTANT: Key usage notes and requirements.
   
   Common patterns:
   - Pattern 1: Example description
   - Pattern 2: Example description
   
   Valid options: List key options/values
   ```

2. **Schema Examples:**
   - Include examples in both the schema items and top-level schema
   - Show common use cases, not just basic syntax
   - Include both minimal and complex examples

3. **Annotations:**
   - Use descriptive titles that include "macOS" prefix
   - Set behavioral hints accurately:
     - `readOnlyHint: true` for tools that don't modify state
     - `destructiveHint: true` for tools that can make destructive changes
     - `idempotentHint: true` for tools where repeated calls are safe
     - `openWorldHint: true` for tools that interact with external entities

### Testing Strategy

After each tool improvement:
1. Build the project to ensure no syntax errors
2. Run relevant tests to ensure functionality is preserved
3. Test with a simple MCP client if available to verify the enhanced documentation is visible

### Verification

Each improved tool should result in:
- ✅ Comprehensive description with examples and patterns
- ✅ Detailed input schema with embedded examples
- ✅ Proper tool annotations with accurate behavioral hints
- ✅ No breaking changes to existing functionality
- ✅ Build passes without errors
- ✅ Tests continue to pass

## Order of Implementation

Implement in this order based on tool complexity and usage frequency:
1. ScreenshotTool (simplest, good for establishing pattern)
2. ApplicationManagementTool (moderate complexity)
3. WindowManagementTool (moderate complexity)
4. ClipboardManagementTool (multiple content types)
5. OnboardingTool (simple but unique purpose)
6. UIInteractionTool (complex with multiple actions)
7. InterfaceExplorerTool (most complex)
8. MenuNavigationTool (complex menu handling)

This plan will systematically improve the usability of all MacMCP tools for AI agents like Claude.