// ABOUTME: ExplorationGuidance provides detailed guidance for UI exploration operations
// ABOUTME: Contains static content for first-time, targeted, and troubleshooting exploration workflows

import Foundation

/// Provides exploration guidance content for the OnboardingTool
public enum ExplorationGuidance {
  /// Provides exploration guidance based on the specific topic requested
  /// - Parameter specific: Optional specific topic ("first_time", "targeted", "troubleshooting")
  /// - Returns: Markdown-formatted guidance string
  public static func guidance(specific: String?) -> String {
    switch specific {
      case "first_time": firstTimeGuidance
      case "targeted": targetedGuidance
      case "troubleshooting": troubleshootingGuidance
      default: generalExplorationGuidance
    }
  }

  // MARK: - Specific Guidance Content

  private static let firstTimeGuidance = """
  # First-Time Application Exploration

  When exploring an application for the first time, follow these guidelines:

  ## Recommended Settings

  ```json
  {
    "scope": "focused",
    "maxDepth": 15,
    "includeHidden": false
  }
  ```

  ## Why These Settings?

  - **scope: "focused"**: Focuses on the currently active application window, which is usually what the user is working with
  - **maxDepth: 15**: Provides enough depth to capture most important UI elements in complex applications
  - **includeHidden: false**: Focuses only on visible elements to reduce noise

  ## Important Tips

  1. **NO FILTERS INITIALLY**: Do not use any filters on your first exploration - get the complete picture first
  2. **ACTIVE WINDOW**: Ensure the application window is active and in view before exploring
  3. **SAVE THE RESULTS**: Store important elements and their IDs for future interactions
  4. **ANALYZE HIERARCHY**: Pay attention to the parent-child relationships for context
  5. **NOTE CAPABILITIES**: For each interesting element, check its "capabilities" property to see what interactions are possible

  ## What to Look For

  1. **Main Interface Containers**: Look for large AXGroups or panels that contain important UI elements
  2. **Interactive Controls**: Find buttons, menus, text fields, and other interactive elements
  3. **Element IDs**: Note the format of element IDs to help with future explorations
  4. **States**: Check which elements are enabled, visible, and focused

  After your initial exploration, you can use more targeted explorations with filters.
  """
  private static let targetedGuidance = """
  # Targeted UI Exploration

  After your initial broad exploration, use these techniques for more focused investigations:

  ## Filter by Element Types

  ```json
  {
    "scope": "focused",
    "elementTypes": ["button", "textfield", "dropdown"],
    "maxDepth": 15
  }
  ```

  This helps find specific types of interactive controls.

  ## Search by Text Content

  ```json
  {
    "scope": "focused",
    "filter": {
      "titleContains": "Save"
    }
  }
  ```

  Use this to find elements with specific text like buttons labeled "Save" or "Cancel".

  ## Examine Specific UI Areas

  ```json
  {
    "scope": "element",
    "id": "example-group-uuid",
    "maxDepth": 10
  }
  ```

  This explores a specific element and its children, useful for drilling down into a particular part of the interface.

  ## Find Elements by Role

  ```json
  {
    "scope": "focused",
    "filter": {
      "role": "AXButton"
    }
  }
  ```

  This finds all elements with a specific accessibility role.

  ## Tips For Effective Exploration

  1. **Increase Depth for Complex Apps**: Use maxDepth of 15-20 for applications like Keynote or Pages
  2. **Combine Filters**: Use multiple filter criteria to narrow down results
  3. **Explore Different Scopes**: Try different scopes if you're not finding what you need
  4. **Progressive Refinement**: Start broad, then narrow down with more specific queries
  5. **Check Multiple Windows**: Some apps have important UI in separate windows or panels
  """
  private static let troubleshootingGuidance = """
  # Troubleshooting UI Exploration Issues

  When you're having trouble exploring or finding UI elements:

  ## Common Issues and Solutions

  ### 1. Few or No Elements Found

  **Solutions:**
  - Increase `maxDepth` (try 15-20)
  - Ensure the application window is focused (use ApplicationManagementTool to activate it)
  - Try `"scope": "application"` with the application's bundleId
  - Use `"includeHidden": true` to see if elements are hidden

  ### 2. Too Many Elements (Overwhelming Results)

  **Solutions:**
  - Use filters to narrow down results
  - Decrease maxDepth
  - Focus on a specific section using the element scope
  - Filter by element types that are relevant to your task

  ### 3. Can't Find a Specific Element

  **Solutions:**
  - Try different text filters (partial matches, different case)
  - Look for container elements and explore them specifically
  - Check if the element is in a different window or panel
  - Verify the element is visible and not in a collapsed section

  ### 4. Exploration is Very Slow

  **Solutions:**
  - Reduce maxDepth
  - Use more specific scope (element or position instead of focused or system)
  - Filter for specific element types
  - Break exploration into multiple targeted queries

  ## Verification Techniques

  1. Take screenshots to visually confirm what you're exploring
  2. Cross-reference element positions with visual layout
  3. Use position-based exploration to find elements at specific coordinates
  4. Try exploring parent elements if child elements are hard to find

  Remember that the UI state can change dynamically, so re-explore after significant interactions.
  """
  private static let generalExplorationGuidance = """
  # UI Exploration Guidance

  The InterfaceExplorerTool is essential for discovering and understanding application interfaces. It provides detailed information about UI elements, their properties, states, and capabilities.

  ## Key Exploration Strategies

  ### 1. Initial Broad Exploration

  When first working with an application, start with a broad exploration:

  ```json
  {
    "scope": "focused",
    "maxDepth": 15,
    "includeHidden": false
  }
  ```

  This gives you an overview of the application's interface structure.

  ### 2. Find Interactive Elements

  To focus on elements you can interact with:

  ```json
  {
    "scope": "focused",
    "elementTypes": ["button", "textfield", "dropdown", "checkbox"],
    "maxDepth": 15
  }
  ```

  ### 3. Search by Text

  To find elements with specific text:

  ```json
  {
    "scope": "focused",
    "filter": {
      "titleContains": "Save"
    }
  }
  ```

  ### 4. Explore Specific Areas

  To drill down into a specific part of the interface:

  ```json
  {
    "scope": "element",
    "id": "example-group-uuid",
    "maxDepth": 10
  }
  ```

  ## Understanding Element Information

  Pay attention to these key properties:

  - **id**: Unique identifier needed for interactions
  - **role**: The accessibility role (button, text field, etc.)
  - **state**: Current state (enabled/disabled, visible/hidden, etc.)
  - **capabilities**: What interactions are possible (clickable, editable, etc.)
  - **actions**: Specific accessibility actions supported
  - **frame**: Position and size on screen

  ## Exploration Tips

  1. **Re-explore after interactions**: The UI may change after you interact with it
  2. **Prioritize visible and enabled elements**: These are usually the ones you can interact with
  3. **Look for patterns in element IDs**: This helps understand the application's structure
  4. **Check parent-child relationships**: Context matters for understanding element purpose
  5. **Use different scopes**: Different scopes can reveal different aspects of the interface

  For more specific guidance, request "exploration" with subtopics "first_time", "targeted", or "troubleshooting".
  """
}
