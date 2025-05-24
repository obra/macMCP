// ABOUTME: InteractionGuidance provides detailed guidance for UI interaction operations
// ABOUTME: Contains static content for clicking, typing, dragging, and scrolling operations

import Foundation

/// Provides interaction guidance content for the OnboardingTool
public struct InteractionGuidance {
  
  /// Provides interaction guidance based on the specific topic requested
  /// - Parameter specific: Optional specific topic ("clicking", "typing", "dragging", "scrolling")
  /// - Returns: Markdown-formatted guidance string
  public static func guidance(specific: String?) -> String {
    switch specific {
    case "clicking":
      return clickingGuidance
    case "typing":
      return typingGuidance
    case "dragging":
      return draggingGuidance
    case "scrolling":
      return scrollingGuidance
    default:
      return generalInteractionGuidance
    }
  }
  
  // MARK: - Specific Guidance Content
  
  private static let clickingGuidance = """
    # Guidance for Clicking UI Elements

    Clicking is the most common interaction you'll perform with macOS applications. Here's how to do it effectively:

    ## Best Practices for Clicking

    ### 1. Element Path-Based Clicking (Preferred)

    ```json
    {
      "action": "click",
      "id": "save-button-uuid",
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
      "id": "filename-text-uuid"
    }
    ```

    ```json
    {
      "action": "right_click",
      "id": "options-button-uuid"
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
  
  private static let typingGuidance = """
    # Guidance for Typing and Text Input

    Text input is handled through the KeyboardInteractionTool rather than the UIInteractionTool. Here's how to effectively work with text input:

    ## Text Input Workflow

    1. **First, focus the text field** using UIInteractionTool:
       ```json
       {
         "action": "click",
         "id": "document-title-field-uuid"
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
  
  private static let draggingGuidance = """
    # Guidance for Drag Operations

    Dragging is essential for many operations in macOS applications. Here's how to effectively perform drag operations:

    ## Basic Drag Operation

    ```json
    {
      "action": "drag",
      "id": "source-item-uuid",
      "targetId": "target-container-uuid",
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
  
  private static let scrollingGuidance = """
    # Guidance for Scrolling Operations

    Scrolling is necessary for navigating through content that doesn't fit on screen. Here's how to effectively scroll in macOS applications:

    ## Basic Scroll Operation

    ```json
    {
      "action": "scroll",
      "id": "content-view-uuid",
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
  
  private static let generalInteractionGuidance = """
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
      "id": "save-button-uuid",
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
      "id": "source-item-uuid",
      "targetId": "target-container-uuid"
    }
    ```

    ### 4. Scrolling Content

    ```json
    {
      "action": "scroll",
      "id": "content-view-uuid",
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