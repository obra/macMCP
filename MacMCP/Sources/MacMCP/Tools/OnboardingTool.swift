// ABOUTME: OnboardingTool.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// A tool that provides guidance and best practices for AI assistants working with macOS MCP
public struct OnboardingTool: @unchecked Sendable {
  /// The name of the tool
  public let name = ToolNames.onboarding

  /// Description of the tool
  public let description =
    "Provides guidance and best practices for working with macOS applications"

  /// Input schema for the tool
  public private(set) var inputSchema: Value

  /// Tool annotations
  public private(set) var annotations: Tool.Annotations

  /// The logger
  private let logger: Logger

  /// Tool handler function
  public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
    { [self] params in
      return try await self.processRequest(params)
    }
  }

  /// Create a new onboarding tool
  /// - Parameter logger: Optional logger to use
  public init(logger: Logger? = nil) {
    self.logger = logger ?? Logger(label: "mcp.tool.onboarding")

    // Set tool annotations
    annotations = .init(
      title: "AI Assistant Guidance",
      readOnlyHint: true,
      openWorldHint: false,
    )

    // Initialize inputSchema with an empty object first
    inputSchema = .object([:])

    // Now create the full input schema
    inputSchema = createInputSchema()
  }

  /// Create the input schema for the tool
  private func createInputSchema() -> Value {
    .object([
      "type": .string("object"),
      "properties": .object([
        "topic": .object([
          "type": .string("string"),
          "description": .string(
            "The topic to get guidance for: general, exploration, interaction, keynote, pages, finder, safari, or complex_apps"
          ),
          "enum": .array([
            .string("general"),
            .string("exploration"),
            .string("interaction"),
            .string("keynote"),
            .string("pages"),
            .string("finder"),
            .string("safari"),
            .string("complex_apps"),
          ]),
        ]),
        "specific": .object([
          "type": .string("string"),
          "description": .string("Optional specific subtopic to get more detailed guidance"),
        ]),
      ]),
      "required": .array([.string("topic")]),
      "additionalProperties": .bool(false),
    ])
  }

  /// Process a request for the tool
  /// - Parameter params: The request parameters
  /// - Returns: The tool result content
  private func processRequest(_ params: [String: Value]?) async throws -> [Tool.Content] {
    guard let params else {
      throw MCPError.invalidParams("Parameters are required")
    }

    // Get the topic
    guard let topic = params["topic"]?.stringValue else {
      throw MCPError.invalidParams("Topic is required")
    }

    // Get optional specific subtopic
    let specific = params["specific"]?.stringValue

    // Get guidance based on topic
    let guidance = getGuidance(topic: topic, specific: specific)

    return [.text(guidance)]
  }

  /// Get guidance based on the requested topic
  /// - Parameters:
  ///   - topic: The topic to get guidance for
  ///   - specific: Optional specific subtopic
  /// - Returns: Guidance text
  private func getGuidance(topic: String, specific: String?) -> String {
    switch topic {
    case "general":
      generalGuidance(specific: specific)
    case "exploration":
      explorationGuidance(specific: specific)
    case "interaction":
      interactionGuidance(specific: specific)
    case "keynote":
      keynoteGuidance(specific: specific)
    case "pages":
      pagesGuidance(specific: specific)
    case "finder":
      finderGuidance(specific: specific)
    case "safari":
      safariGuidance(specific: specific)
    case "complex_apps":
      complexAppsGuidance(specific: specific)
    default:
      "Topic not recognized. Please use one of the following: general, exploration, interaction, keynote, pages, finder, safari, or complex_apps."
    }
  }

  /// General guidance for working with macOS MCP
  private func generalGuidance(specific _: String?) -> String {
    """
    # General Guidance for macOS MCP

    ## Core Principles for AI Assistants

    1. **Explore First**: Always begin by exploring the application interface thoroughly before attempting interactions.

    2. **Step-by-Step Approach**: Break complex tasks into smaller, manageable steps. Verify success after each step.

    3. **Contextual Awareness**: Re-explore the interface after significant interactions as the UI state may change.

    4. **Error Recovery**: If an interaction fails, try alternative approaches or simpler tasks first.

    5. **Use Appropriate Tools**: Different tasks require different tools:
       - `InterfaceExplorerTool`: For exploring UI elements and discovering what's available
       - `UIInteractionTool`: For clicking, typing, dragging, and scrolling
       - `KeyboardInteractionTool`: For keyboard shortcuts and extended text input
       - `MenuNavigationTool`: For accessing menu items in applications
       - `WindowManagementTool`: For managing application windows

    ## Recommended Workflow

    1. **Initial Exploration**: When working with a new application, use InterfaceExplorerTool with high depth:
       ```json
       {
         "scope": "focused",
         "maxDepth": 15,
         "includeHidden": false
       }
       ```

    2. **Plan Actions**: Identify the specific elements you need to interact with and their capabilities.

    3. **Execute Actions**: Perform interactions one step at a time, verifying each step succeeds.

    4. **Verify Changes**: Re-explore to confirm the UI has updated as expected.

    5. **Adapt and Retry**: If an action fails, adjust your approach based on the error information.

    For more specific guidance on particular topics, request guidance on 'exploration', 'interaction', or specific applications like 'keynote', 'pages', etc.
    """
  }

  /// Guidance for exploring application interfaces
  private func explorationGuidance(specific: String?) -> String {
    switch specific {
    case "first_time":
      """
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
    case "targeted":
      """
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
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXGroup",
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
    case "troubleshooting":
      """
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
    default:
      """
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
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXGroup",
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
  }

  /// Guidance for interacting with UI elements
  private func interactionGuidance(specific: String?) -> String {
    switch specific {
    case "clicking":
      """
      # Guidance for Clicking UI Elements

      Clicking is the most common interaction you'll perform with macOS applications. Here's how to do it effectively:

      ## Best Practices for Clicking

      ### 1. Element Path-Based Clicking (Preferred)

      ```json
      {
        "action": "click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXButton[@AXTitle=\"Save\"]",
        "appBundleId": "com.example.app"
      }
      ```

      This is the most reliable method, as it uses path-based identifiers that describe the element's position in the accessibility hierarchy and are stable even if the UI position changes.

      ### 2. Position-Based Clicking (Fallback)

      ```json
      {
        "action": "click",
        "x": 500,
        "y": 300
      }
      ```

      Use this only when element ID-based clicking isn't working or for special cases like clicking on canvas coordinates.

      ### 3. Double-Clicking and Right-Clicking

      ```json
      {
        "action": "double_click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXStaticText[@AXValue=\"filename\"]"
      }
      ```

      ```json
      {
        "action": "right_click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXButton[@AXTitle=\"Options\"]"
      }
      ```

      ## Troubleshooting Click Problems

      1. **Element Not Found**: 
         - Verify the element exists using InterfaceExplorerTool
         - Check if the element path is correctly formatted and valid
         - Ensure the path attributes match the actual element attributes
         - Ensure the application is focused

      2. **Click Not Registering**:
         - Check if the element is enabled (`"isEnabled": true`)
         - Verify it has clicking capability (`capabilities` contains "clickable")
         - Try clicking a parent container if the specific element doesn't respond
         - Check if you need a different action (double-click, right-click)

      3. **Wrong Element Clicked**:
         - Elements may overlap; verify z-order (which is on top)
         - Try clicking a more specific child element
         - Use position-based clicking with precise coordinates

      ## Special Cases

      - **Canvas Interactions**: For drawing applications, use position-based clicking with coordinates relative to the canvas
      - **Text Selection**: Click at the beginning position, then use drag to the end position
      - **Dynamic Elements**: Re-explore after each significant interaction as IDs may change

      Remember to verify that your click had the intended effect by re-exploring the UI after the interaction.
      """
    case "typing":
      """
      # Guidance for Typing and Text Input

      Text input is handled through the KeyboardInteractionTool rather than the UIInteractionTool. Here's how to effectively work with text input:

      ## Text Input Workflow

      1. **First, focus the text field** using UIInteractionTool:
         ```json
         {
           "action": "click",
           "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.TextEdit\"]/AXWindow/AXTextField[@AXIdentifier=\"document_title\"]"
         }
         ```

      2. **Then, type text** using KeyboardInteractionTool:
         ```json
         {
           "action": "type_text",
           "text": "Hello, world!"
         }
         ```

      ## Special Text Input Scenarios

      ### Replacing Existing Text

      1. Click to focus the field
      2. Select all text with keyboard shortcut:
         ```json
         {
           "action": "key_sequence",
           "sequence": [
             {"key": "Meta", "action": "down"},
             {"key": "a", "action": "down"},
             {"key": "a", "action": "up"},
             {"key": "Meta", "action": "up"}
           ]
         }
         ```
      3. Type new text

      ### Working with Multi-line Text

      For paragraphs or longer text, include newlines in your text:

      ```json
      {
        "action": "type_text",
        "text": "Line 1\\nLine 2\\nLine 3"
      }
      ```

      ### Using Special Characters

      Most special characters can be typed directly in the text string:

      ```json
      {
        "action": "type_text",
        "text": "Symbol examples: @#$%^&*(){}[]"
      }
      ```

      ## Troubleshooting Text Input

      1. **Text Field Not Accepting Input**:
         - Verify the text field is enabled and editable
         - Check that it has focus (should show `"isFocused": true` after clicking)
         - Try clicking a different part of the text field

      2. **Wrong Text Field Selected**:
         - Use InterfaceExplorerTool to confirm which element has focus
         - Try clicking explicitly on the text field again

      3. **Text Not Appearing**:
         - Some applications handle text input differently
         - Try pressing Enter/Return after typing
         - Check if the field requires a specific format (like dates)

      ## Best Practices

      1. Type at a reasonable pace by breaking long text into smaller chunks
      2. Verify text input was successful before proceeding to next steps
      3. For complex text formatting, consider using menu commands rather than direct typing
      4. Remember that different applications handle text input differently
      """
    case "dragging":
      """
      # Guidance for Drag Operations

      Dragging is essential for many operations in macOS applications. Here's how to effectively perform drag operations:

      ## Basic Drag Operation

      ```json
      {
        "action": "drag",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXElement[@AXIdentifier=\"source_item\"]",
        "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXElement[@AXIdentifier=\"target_container\"]",
        "appBundleId": "com.example.app"
      }
      ```

      This drags one element onto another, which is useful for:
      - Moving files in Finder
      - Reordering items in lists
      - Dragging content between applications
      - Placing objects in containers

      ## Key Requirements for Successful Drags

      1. **Valid Source Element**: Must be draggable (check capabilities)
      2. **Valid Target Element**: Must be a valid drop target
      3. **Correct App Context**: Both elements typically need to be in the same application

      ## Common Drag Operations by Application Type

      ### Document Editors (Pages, Word, TextEdit)

      - **Text Selection**: Click at start, then drag to end
      - **Image Positioning**: Drag image to desired location
      - **Object Manipulation**: Drag to move, resize handles to adjust size

      ### Presentation Software (Keynote, PowerPoint)

      - **Slide Objects**: Drag to position
      - **Slide Reordering**: Drag slides in the navigator
      - **Object Layering**: Drag objects forward/backward

      ### File Management (Finder)

      - **File Moving**: Drag files between folders
      - **File Copying**: Drag with Option key

      ## Troubleshooting Drag Issues

      1. **Drag Not Initiating**:
         - Verify source element is draggable
         - Check if element requires a specific part to be dragged (e.g., drag handle)
         - Try clicking and holding briefly before dragging

      2. **Drop Target Not Accepting**:
         - Verify the target element accepts drops
         - Check if the drag operation is valid in the application context
         - Try different targets or positions

      3. **Precision Issues**:
         - Some drag operations require precise positioning
         - Try identifying more specific target elements
         - Consider using keyboard shortcuts instead for precision operations

      ## Alternative Approaches

      If dragging doesn't work well for your scenario, consider:

      1. Using clipboard operations (cut/copy and paste)
      2. Using menu commands for positioning
      3. Using keyboard shortcuts for selection and movement
      4. Breaking complex drag operations into simpler steps

      Remember to verify the result after dragging by re-exploring the UI to confirm the change occurred as expected.
      """
    case "scrolling":
      """
      # Guidance for Scrolling Operations

      Scrolling is necessary for navigating through content that doesn't fit on screen. Here's how to effectively scroll in macOS applications:

      ## Basic Scroll Operation

      ```json
      {
        "action": "scroll",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXScrollArea[@AXIdentifier=\"content_view\"]",
        "direction": "down",
        "amount": 0.5,
        "appBundleId": "com.example.app"
      }
      ```

      ## Key Parameters

      1. **direction**: 
         - `"up"`: Scroll toward the top of the content
         - `"down"`: Scroll toward the bottom of the content
         - `"left"`: Scroll toward the left edge
         - `"right"`: Scroll toward the right edge

      2. **amount**: 
         - Range from 0.0 to 1.0
         - 0.1 = small scroll (10% of viewport)
         - 0.5 = medium scroll (50% of viewport)
         - 1.0 = large scroll (100% of viewport)

      ## Best Practices for Scrolling

      1. **Use Scrollable Elements**: Look for elements with "scrollable" capability or role "AXScrollArea"

      2. **Incremental Scrolling**: Use smaller amounts (0.2-0.3) with multiple scrolls rather than one large scroll

      3. **Wait Between Scrolls**: Allow content to load before additional scrolling, especially in web content

      4. **Re-explore After Scrolling**: The visible elements will change after scrolling

      ## Common Scrolling Scenarios

      ### Document Navigation

      - Scroll down incrementally to read through a document
      - Use small scroll amounts (0.2-0.3) to ensure you don't miss content

      ### Finding Content

      - Scroll to locate specific content
      - Re-explore after each scroll to check if target is visible

      ### Long Lists

      - Use larger scroll amounts (0.5-0.7) to move quickly through long lists
      - Then use smaller amounts to fine-tune position

      ## Troubleshooting Scroll Issues

      1. **Content Not Scrolling**:
         - Verify the element is scrollable
         - Check if you're scrolling the correct container element
         - Try identifying parent or child elements that may be the actual scroll area

      2. **Scrolling Too Far**:
         - Reduce the amount parameter
         - Use incremental scrolls with smaller amounts

      3. **Can't Reach Specific Content**:
         - Try alternating directions if content layout is complex
         - Consider using search functionality if available
         - Try scrolling to a known position first, then refining

      Remember to explore the interface after scrolling to see the newly visible elements, as they may not have been included in previous exploration results.
      """
    default:
      """
      # UI Interaction Guidance

      Interacting with macOS UI elements requires understanding the capabilities of each element and using the right tools for different interaction types.

      ## Main Interaction Tools

      1. **UIInteractionTool**: For mouse-based interactions (clicking, dragging, scrolling)
      2. **KeyboardInteractionTool**: For keyboard inputs and shortcuts
      3. **MenuNavigationTool**: For accessing application menus

      ## Common Interaction Types

      ### 1. Clicking Elements

      ```json
      {
        "action": "click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXButton[@AXTitle=\"Save\"]",
        "appBundleId": "com.example.app"
      }
      ```

      **Variants:**
      - `"action": "double_click"` for double-clicking
      - `"action": "right_click"` for context menus

      ### 2. Typing Text

      First click to focus a text field, then use KeyboardInteractionTool:

      ```json
      {
        "action": "type_text",
        "text": "Hello, world!"
      }
      ```

      ### 3. Dragging Elements

      ```json
      {
        "action": "drag",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXElement[@AXIdentifier=\"source_item\"]",
        "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXElement[@AXIdentifier=\"target_container\"]"
      }
      ```

      ### 4. Scrolling Content

      ```json
      {
        "action": "scroll",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXScrollArea[@AXIdentifier=\"content_view\"]",
        "direction": "down",
        "amount": 0.5
      }
      ```

      ## Best Practices for Interactions

      1. **Verify Element Capabilities**: Check that elements can perform the interaction:
         - "clickable" for clicking
         - "editable" for typing
         - "scrollable" for scrolling

      2. **Element State Awareness**: Make sure elements are:
         - Enabled (not disabled)
         - Visible (not hidden)
         - Not overlapped by other elements

      3. **Context Matters**: Some interactions only work when:
         - The application is focused
         - Specific modes are active
         - Previous actions have been completed

      4. **Progressive Actions**: Break complex interactions into steps:
         - First select an object
         - Then modify its properties
         - Finally confirm changes

      5. **Verify Results**: Always check that your interaction had the intended effect

      For more specific guidance, request "interaction" with subtopics "clicking", "typing", "dragging", or "scrolling".
      """
    }
  }

  /// Guidance specific to Keynote
  private func keynoteGuidance(specific: String?) -> String {
    switch specific {
    case "slides":
      """
      # Working with Slides in Keynote

      Keynote's slide management requires understanding its UI hierarchy and using the right interaction patterns.

      ## Exploring Keynote's Slide Structure

      Start with a broad exploration to understand Keynote's layout:

      ```json
      {
        "scope": "focused",
        "maxDepth": 20,
        "includeHidden": false
      }
      ```

      Look for these key elements:
      - Slide navigator (left panel)
      - Slide canvas (main editing area)
      - Formatting panel (right side)

      ## Common Slide Operations

      ### 1. Creating New Slides

      The most reliable way to create new slides is through the menu:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Slide > New Slide"
      }
      ```

      ### 2. Selecting Slides

      Click on slide thumbnails in the navigator:

      ```json
      {
        "action": "click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXImage[@AXDescription=\"Slide 2\"]"
      }
      ```

      Tip: After your initial exploration, look for elements with roles like "AXImage" or "AXCell" in the slide navigator area.

      ### 3. Reordering Slides

      Drag operations work for reordering:

      ```json
      {
        "action": "drag",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXImage[@AXDescription=\"Slide 2\"]",
        "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXImage[@AXDescription=\"Slide 5\"]"
      }
      ```

      ### 4. Deleting Slides

      Select the slide first, then use the Delete key:

      ```json
      {
        "action": "key_sequence",
        "sequence": [
          {"key": "Delete", "action": "down"},
          {"key": "Delete", "action": "up"}
        ]
      }
      ```

      Alternatively, use the Edit menu:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Edit > Delete"
      }
      ```

      ## Slide Layouts and Templates

      To change slide layouts, select the slide first, then:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Format > Slide Layout > [Layout Name]"
      }
      ```

      ## Troubleshooting Slide Operations

      1. **Can't Find Slide Navigator**: 
         - Ensure View > Navigator is checked
         - Try re-exploring with higher maxDepth (20+)

      2. **Can't Select Slides**: 
         - Try clicking different parts of the thumbnail
         - Use keyboard navigation (arrow keys) after clicking one slide

      3. **New Slide Created with Wrong Layout**:
         - Use Format > Slide Layout after creating the slide
         - Or try Edit > Copy and Edit > Paste for consistent layouts

      Remember to periodically save your work using Command+S or File > Save.
      """
    case "text":
      """
      # Working with Text in Keynote

      Text manipulation in Keynote requires understanding text boxes and formatting controls.

      ## Finding and Selecting Text Boxes

      Text boxes can be identified in several ways:

      ```json
      {
        "scope": "focused",
        "filter": {
          "role": "AXTextField"
        }
      }
      ```

      Or look for elements with "AXStaticText" role within the slide canvas.

      ## Creating New Text Boxes

      Use the Text button in the toolbar or Insert menu:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Insert > Text Box"
      }
      ```

      Then click on the canvas where you want the text box:

      ```json
      {
        "action": "click",
        "x": 400,
        "y": 300
      }
      ```

      ## Editing Text

      1. First click the text box to select it:
         ```json
         {
           "action": "click",
           "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXTextField[@AXIdentifier=\"text_box_1\"]"
         }
         ```

      2. Then click again to place cursor:
         ```json
         {
           "action": "click",
           "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXTextField[@AXIdentifier=\"text_box_1\"]"
         }
         ```

      3. Type using KeyboardInteractionTool:
         ```json
         {
           "action": "type_text",
           "text": "This is my slide title"
         }
         ```

      ## Text Formatting

      1. First select the text (click and drag, or use Command+A):
         ```json
         {
           "action": "key_sequence",
           "sequence": [
             {"key": "Meta", "action": "down"},
             {"key": "a", "action": "down"},
             {"key": "a", "action": "up"},
             {"key": "Meta", "action": "up"}
           ]
         }
         ```

      2. Use Format menu for formatting:
         ```json
         {
           "action": "activateMenuItem",
           "bundleId": "com.apple.iWork.Keynote",
           "menuPath": "Format > Font > Bold"
         }
         ```

      3. Or use keyboard shortcuts:
         ```json
         {
           "action": "key_sequence",
           "sequence": [
             {"key": "Meta", "action": "down"},
             {"key": "b", "action": "down"},
             {"key": "b", "action": "up"},
             {"key": "Meta", "action": "up"}
           ]
         }
         ```

      ## Common Text Actions

      ### Changing Font

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Format > Font > Font..."
      }
      ```

      ### Changing Text Color

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Format > Font > Text Color..."
      }
      ```

      ### Text Alignment

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Format > Text > Align > Center"
      }
      ```

      ## Troubleshooting Text Issues

      1. **Can't Select Text Box**: 
         - Try clicking the edge of the text box first, then the text itself
         - If a text box is inside a group, you may need to ungroup first

      2. **Formatting Not Applied**: 
         - Ensure text is selected before applying formatting
         - Some text might have style protection - try Format > Advanced > Clear Style

      3. **Text Disappearing**: 
         - Text might be changing color to match background
         - Check Format > Font > Text Color

      Remember to click outside the text box when finished editing to commit changes.
      """
    case "images":
      """
      # Working with Images in Keynote

      Adding and manipulating images in Keynote requires understanding the right tools and menus.

      ## Adding Images

      ### Method 1: Insert Menu

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Insert > Choose..."
      }
      ```

      This will open a file picker dialog. Unfortunately, manipulating file dialogs can be challenging with MCP. You might need to:

      1. Use KeyboardInteractionTool to navigate the dialog
      2. Try using keyboard shortcuts to access recent files

      ### Method 2: Media Browser

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "View > Show Media Browser"
      }
      ```

      Then explore the media browser panel:

      ```json
      {
        "scope": "focused",
        "filter": {
          "role": "AXTabGroup"
        },
        "maxDepth": 10
      }
      ```

      Find the Photos tab and navigate to desired images.

      ## Selecting and Moving Images

      After adding an image, you'll need to select it to manipulate it:

      ```json
      {
        "action": "click",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXImage[@AXIdentifier=\"image_1\"]"
      }
      ```

      To move the image, drag it:

      ```json
      {
        "action": "drag",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXImage[@AXIdentifier=\"image_1\"]",
        "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXCanvas"
      }
      ```

      ## Resizing Images

      1. First select the image
      2. Look for resize handles (small squares at the corners)
      3. Click and drag a corner handle to resize

      ```json
      {
        "action": "drag",
        "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXButton[@AXRole=\"resize_handle\"]",
        "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.keynote\"]/AXWindow/AXCanvas"
      }
      ```

      Tip: Hold Shift while resizing to maintain aspect ratio.

      ## Image Formatting

      After selecting an image, use the Format sidebar or menu:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Format > Image > Add Drop Shadow"
      }
      ```

      Common formatting options:
      - Arrange > Bring to Front/Send to Back
      - Image > Mask with Shape
      - Image > Replace Image
      - Style > Border options

      ## Removing Images

      1. Select the image
      2. Press Delete:

      ```json
      {
        "action": "key_sequence",
        "sequence": [
          {"key": "Delete", "action": "down"},
          {"key": "Delete", "action": "up"}
        ]
      }
      ```

      ## Troubleshooting Image Issues

      1. **Can't Select Image**: 
         - The image might be part of a group or behind another object
         - Try Arrange > Bring to Front

      2. **Image Too Large/Small**: 
         - Use Format > Image > Original Size to reset
         - Or use Format > Image > Scale to fit exact dimensions

      3. **Poor Image Quality**: 
         - Check Format > Image > Quality settings
         - Try replacing with higher resolution image

      4. **Image Missing**: 
         - If you see a placeholder, the image file might be missing
         - Try Format > Image > Replace Image

      Remember to save your work frequently with Command+S.
      """
    default:
      """
      # Working with Keynote

      Keynote is Apple's presentation software and has a complex UI that requires careful exploration and interaction. Here are key strategies for working with Keynote effectively:

      ## Initial Exploration

      When first working with Keynote, use a deep exploration:

      ```json
      {
        "scope": "focused",
        "maxDepth": 20,
        "includeHidden": false
      }
      ```

      The high maxDepth is important because Keynote has a deep UI hierarchy.

      ## Key Interface Areas

      1. **Slide Navigator** (left side): Contains slide thumbnails
      2. **Canvas** (center): Main editing area for current slide
      3. **Format Panel** (right side): Controls for styling selected elements
      4. **Toolbar** (top): Common actions and tools

      ## Common Tasks

      ### 1. Working with Slides

      - **Create new slide**: Use Insert menu or toolbar button
      - **Select slide**: Click on slide thumbnail in navigator
      - **Reorder slides**: Drag thumbnails in navigator
      - **Change layout**: Use Format menu or right-click on slide

      ### 2. Adding and Editing Content

      - **Add text box**: Use Insert menu or toolbar
      - **Add image**: Use Insert menu or Media Browser
      - **Add shape**: Use Shape menu in toolbar
      - **Format elements**: Use Format panel or Format menu

      ### 3. Presentation Settings

      - **Slide transitions**: Format > Transition
      - **Presenter notes**: View > Show Presenter Notes
      - **Slideshow settings**: Play menu

      ## Menu-Based Operations

      Many operations in Keynote are easier through menus:

      ```json
      {
        "action": "activateMenuItem",
        "bundleId": "com.apple.iWork.Keynote",
        "menuPath": "Insert > Text Box"
      }
      ```

      ## Best Practices for Keynote

      1. **Work with One Element at a Time**: Select, then modify properties
      2. **Use Menus for Complex Actions**: Menus are more reliable than direct manipulation for some tasks
      3. **Verify After Each Action**: Check that operations completed successfully
      4. **Save Frequently**: Use Command+S or File > Save regularly
      5. **Use Keyboard Shortcuts**: Many operations are faster with shortcuts

      ## Troubleshooting Keynote

      1. **Can't Find Elements**: 
         - Increase exploration depth to 20 or even 25
         - Explore specific panels individually

      2. **Element Not Responding**: 
         - Check if the correct layer/slide is active
         - Try selecting the element first, then performing actions

      3. **Formatting Not Applied**: 
         - Make sure the correct element is selected
         - Check if master slides or styles are overriding

      For more specific guidance, request "keynote" with subtopics "slides", "text", or "images".
      """
    }
  }

  /// Guidance specific to Pages
  private func pagesGuidance(specific _: String?) -> String {
    """
    # Working with Pages

    Pages is Apple's word processing application. Here are strategies for working with it effectively:

    ## Initial Exploration

    When first working with Pages, use a deep exploration:

    ```json
    {
      "scope": "focused",
      "maxDepth": 15,
      "includeHidden": false
    }
    ```

    ## Key Interface Areas

    1. **Document Canvas** (center): Main editing area 
    2. **Format Panel** (right side): Text and object formatting
    3. **Toolbar** (top): Common actions and formatting
    4. **Page Thumbnails** (left side, if enabled): Document navigation

    ## Common Tasks

    ### Text Editing

    1. **First click** to position cursor:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.TextEdit\"]/AXWindow/AXTextArea"
       }
       ```

    2. **Then type** using KeyboardInteractionTool:
       ```json
       {
         "action": "type_text",
         "text": "This is a paragraph in Pages."
       }
       ```

    3. **Format text** by selecting it first (click and drag or Command+A), then using Format panel or Format menu

    ### Working with Images

    1. **Insert image** via menu:
       ```json
       {
         "action": "activateMenuItem",
         "bundleId": "com.apple.iWork.Pages",
         "menuPath": "Insert > Choose..."
       }
       ```

    2. **Resize image** by selecting it and dragging handles

    3. **Position image** by dragging or using the Format panel for precise control

    ### Document Structure

    1. **Add page break**: Place cursor and press Enter+Return

    2. **Add section break**: Use Insert > Section Break

    3. **Add headers/footers**: View > Show Header & Footer

    ## Best Practices for Pages

    1. **Work Incrementally**: Make small changes and verify each step

    2. **Use Menus for Complex Formatting**: Text styles, columns, etc. are best done via menus

    3. **Save Frequently**: Use Command+S or File > Save regularly

    4. **Focus on One Element**: Pages has many elements - focus on one at a time

    5. **Prefer Text Commands**: For text-heavy work, keyboard shortcuts are more reliable

    ## Troubleshooting Pages

    1. **Can't Edit Text**: 
       - Ensure document is not in read-only mode
       - Click to place cursor before typing
       - Check if you're in a special element (table, text box)

    2. **Format Panel Not Showing Options**: 
       - Make sure the correct element type is selected
       - Some options are contextual to the selection

    3. **Content Jumping or Rearranging**: 
       - Pages uses automatic layout features
       - Check text wrapping settings for objects
       - Use Format > Section to control layout behavior

    4. **Image Placement Issues**: 
       - Use "Move with Text" vs "Stay on Page" options
       - Try different wrapping settings

    Remember that Pages has both word processing and page layout features. For complex documents, plan your approach based on whether text flow or visual layout is more important.
    """
  }

  /// Guidance specific to Finder
  private func finderGuidance(specific _: String?) -> String {
    """
    # Working with Finder

    Finder is macOS's file management application. Here are strategies for working with it effectively:

    ## Initial Exploration

    When first working with Finder, use this exploration:

    ```json
    {
      "scope": "focused",
      "maxDepth": 10,
      "includeHidden": false
    }
    ```

    ## Key Interface Areas

    1. **Sidebar** (left): Contains favorites, locations, tags
    2. **File View** (center): Icon, list, column, or gallery view
    3. **Toolbar** (top): Navigation buttons, view options, search
    4. **Path Bar** (bottom, if enabled): Current directory path

    ## Common Tasks

    ### Navigating Directories

    1. **Click on sidebar items**:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXOutline/AXCell[@AXTitle=\"Documents\"]"
       }
       ```

    2. **Double-click folders**:
       ```json
       {
         "action": "double_click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXOutline/AXCell[@AXTitle=\"Projects\"]"
       }
       ```

    3. **Go up one level** (back to parent folder):
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Meta", "action": "down"},
           {"key": "ArrowUp", "action": "down"},
           {"key": "ArrowUp", "action": "up"},
           {"key": "Meta", "action": "up"}
         ]
       }
       ```

    ### File Operations

    1. **Select file**:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXOutline/AXCell[@AXTitle=\"Document.pdf\"]"
       }
       ```

    2. **Move file** (drag and drop):
       ```json
       {
         "action": "drag",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXOutline/AXCell[@AXTitle=\"Document.pdf\"]",
         "targetElementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.finder\"]/AXWindow/AXOutline/AXCell[@AXTitle=\"Projects\"]"
       }
       ```

    3. **Copy file** (using menu):
       ```json
       {
         "action": "activateMenuItem",
         "bundleId": "com.apple.finder",
         "menuPath": "Edit > Copy"
       }
       ```
       Then navigate to destination and:
       ```json
       {
         "action": "activateMenuItem",
         "bundleId": "com.apple.finder",
         "menuPath": "Edit > Paste"
       }
       ```

    4. **Delete file**:
       Select file, then:
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Delete", "action": "down"},
           {"key": "Delete", "action": "up"}
         ]
       }
       ```

    ### Creating New Items

    1. **New folder**:
       ```json
       {
         "action": "activateMenuItem",
         "bundleId": "com.apple.finder",
         "menuPath": "File > New Folder"
       }
       ```
       Then type the folder name.

    2. **New file** (typically done in the specific application)

    ## Best Practices for Finder

    1. **Verify Locations**: Always check the current location before operations

    2. **Use List View**: List view (`View > as List`) provides more details

    3. **Prefer Menu Commands**: For file operations, menu commands are more reliable than drag operations

    4. **Sidebar Navigation**: Use sidebar items for efficient navigation

    5. **Path Bar**: Enable View > Show Path Bar to see current location

    ## Troubleshooting Finder

    1. **Can't Find File**:
       - Use View > Show All Files to see hidden files
       - Check if you're in the correct location
       - Use the search field in the toolbar

    2. **Permission Issues**:
       - Some operations may fail due to permission restrictions
       - Check file permissions: Get Info (Command+I)

    3. **Drag Operations Failing**:
       - Verify you have write permission at the destination
       - Try using Cut/Copy and Paste instead

    4. **Interface Elements Not Found**:
       - Finder view options can change available UI elements
       - Try View > Show Sidebar, View > Show Path Bar, etc.

    Remember that Finder operations can affect the file system, so be cautious with deletion or moving operations.
    """
  }

  /// Guidance specific to Safari
  private func safariGuidance(specific _: String?) -> String {
    """
    # Working with Safari

    Safari is Apple's web browser. Here are strategies for working with it effectively:

    ## Initial Exploration

    When first working with Safari, use this exploration:

    ```json
    {
      "scope": "focused",
      "maxDepth": 15,
      "includeHidden": false
    }
    ```

    ## Key Interface Areas

    1. **Toolbar** (top): Address bar, navigation buttons, tab bar
    2. **Web Content** (main area): The loaded webpage
    3. **Sidebar** (left, if enabled): Bookmarks, Reading List, History
    4. **Status Bar** (bottom, if enabled): Link and loading information

    ## Common Tasks

    ### Navigating Web Pages

    1. **Enter URL** in address bar:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXToolbar/AXTextField[@AXSubrole=\"AXURLField\"]"
       }
       ```
       Then type the URL:
       ```json
       {
         "action": "type_text",
         "text": "https://www.example.com/"
       }
       ```
       Press Enter:
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Return", "action": "down"},
           {"key": "Return", "action": "up"}
         ]
       }
       ```

    2. **Back/Forward** navigation:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXToolbar/AXButton[@AXDescription=\"back\"]"
       }
       ```

    3. **Refresh page**:
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Meta", "action": "down"},
           {"key": "r", "action": "down"},
           {"key": "r", "action": "up"},
           {"key": "Meta", "action": "up"}
         ]
       }
       ```

    ### Tab Management

    1. **New tab**:
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Meta", "action": "down"},
           {"key": "t", "action": "down"},
           {"key": "t", "action": "up"},
           {"key": "Meta", "action": "up"}
         ]
       }
       ```

    2. **Switch tabs**:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXTabGroup/AXRadioButton[2]"
       }
       ```

    3. **Close tab**:
       ```json
       {
         "action": "key_sequence",
         "sequence": [
           {"key": "Meta", "action": "down"},
           {"key": "w", "action": "down"},
           {"key": "w", "action": "up"},
           {"key": "Meta", "action": "up"}
         ]
       }
       ```

    ### Web Page Interaction

    1. **Click links**:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXWebArea/AXLink[@AXTitle=\"Example link\"]"
       }
       ```

    2. **Fill forms**:
       ```json
       {
         "action": "click",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXWebArea/AXTextField[@AXPlaceholderValue=\"Username\"]"
       }
       ```
       Then type:
       ```json
       {
         "action": "type_text",
         "text": "example_user"
       }
       ```

    3. **Scroll page**:
       ```json
       {
         "action": "scroll",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.apple.safari\"]/AXWindow/AXWebArea",
         "direction": "down",
         "amount": 0.5
       }
       ```

    ## Web Page Exploration

    The web content area is a special case for exploration:

    ```json
    {
      "scope": "focused",
      "filter": {
        "role": "AXWebArea"
      },
      "maxDepth": 15
    }
    ```

    This will help you find interactive elements within the loaded webpage.

    ## Best Practices for Safari

    1. **Re-explore After Navigation**: Web content changes completely when navigating

    2. **Wait for Page Load**: Check for loading indicators or element existence before interaction

    3. **Web Elements vs Browser Elements**: Distinguish between browser UI and web page content

    4. **Use Role Filtering**: Filter for specific element types like links, buttons, or form fields

    5. **Scrolling Before Clicking**: Ensure elements are in view before attempting to interact

    ## Troubleshooting Safari

    1. **Elements Not Found**:
       - Web content might be in iframes or dynamic
       - Try scrolling to make elements visible
       - Wait longer for page loading

    2. **Clicks Not Working**:
       - Element might be covered by overlays or popups
       - JavaScript might be intercepting clicks
       - Try using keyboard navigation

    3. **Forms Not Submitting**:
       - Look for the actual submit button
       - Try pressing Enter after filling form fields

    4. **Content Changes**:
       - Re-explore after any major page change
       - Dynamic websites may change structure frequently

    Remember that web pages are complex and can change dynamically, so frequent re-exploration is key.
    """
  }

  /// Guidance for working with complex applications
  private func complexAppsGuidance(specific _: String?) -> String {
    """
    # Working with Complex Applications

    Complex applications like professional creative software require special approaches. Here are strategies for working with them effectively:

    ## Initial Approach

    For complex applications, a methodical approach is essential:

    1. **Initial Broad Exploration**:
       ```json
       {
         "scope": "focused",
         "maxDepth": 20,
         "includeHidden": false
       }
       ```

    2. **Focused Panel Exploration**: Identify key panels, then explore each:
       ```json
       {
         "scope": "element",
         "elementPath": "macos://ui/AXApplication[@bundleId=\"com.example.app\"]/AXWindow/AXGroup[@AXIdentifier=\"tools_panel\"]",
         "maxDepth": 10
       }
       ```

    3. **Identify Interactive Patterns**: Look for repeating UI patterns

    ## Breaking Down Complex Tasks

    Complex applications require breaking tasks into smaller steps:

    1. **Analyze the Workflow**: Understand the normal steps a user would take

    2. **Identify Key Elements**: Find the UI elements for each step

    3. **Sequence Actions**: Plan a sequence of simple actions

    4. **Verify Each Step**: Check the result after each action

    ## Dealing with Complex UIs

    ### Canvas-Based Applications

    Applications with editing canvases (Photoshop, Sketch, etc.) have special considerations:

    1. **Find the Canvas Element**:
       ```json
       {
         "scope": "focused",
         "filter": {
           "role": "AXCanvas"
         }
       }
       ```

    2. **Coordinate-Based Interactions**: Often require clicking at specific coordinates:
       ```json
       {
         "action": "click",
         "x": 400,
         "y": 300
       }
       ```

    3. **Tool Selection**: Usually requires clicking toolbar buttons first

    ### Multi-Panel Applications

    Applications with many panels (Adobe suite, video editors) need panel-focused exploration:

    1. **Identify Key Panels**: Explore each functional area

    2. **Panel Navigation**: Use tabs, buttons, or menu items to switch panels

    3. **Panel State Awareness**: Check if panels are expanded/collapsed

    ## Tips for Specific Complex Applications

    ### Graphics Applications

    - Use menu commands for precision operations
    - Tool selection usually comes before canvas interaction
    - Look for inspector panels for property editing

    ### Video Editing Software

    - Timeline navigation is usually critical
    - Selection must precede editing operations
    - Many operations use drag and drop

    ### Development IDEs

    - Multiple editor tabs and panels
    - Context menus for many operations
    - Keyboard shortcuts often more reliable than mouse

    ## Best Practices for Complex Apps

    1. **Prioritize Exploration**: Spend more time exploring before acting

    2. **Menu Commands**: Prefer menu commands over direct manipulation for precision

    3. **Minimal Steps**: Make one small change at a time

    4. **Save Work**: Encourage frequent saving of work

    5. **Use Keyboard Shortcuts**: Many complex apps are designed for keyboard use

    6. **Find Documentation**: Look for patterns documented in app guides

    ## Troubleshooting Complex Applications

    1. **Modal Dialogs**: Check for open dialogs that might block interaction

    2. **Tool State**: Verify the correct tool or mode is active

    3. **Selection State**: Ensure the right objects are selected

    4. **Hidden UI**: Some UI only appears in certain contexts or modes

    5. **Zoom Level**: Canvas interaction might depend on zoom level

    Remember that complex applications might require multiple attempts and approaches. Patience and systematic testing are key.
    """
  }
}
