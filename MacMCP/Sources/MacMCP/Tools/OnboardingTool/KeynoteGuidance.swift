// ABOUTME: KeynoteGuidance provides detailed guidance for working with Apple Keynote application
// ABOUTME: Contains static content for slide management, text editing, and image handling workflows

import Foundation

/// Provides Keynote-specific guidance content for the OnboardingTool
public enum KeynoteGuidance {
  /// Provides Keynote guidance based on the specific topic requested
  /// - Parameter specific: Optional specific topic ("slides", "text", "images")
  /// - Returns: Markdown-formatted guidance string
  public static func guidance(specific: String?) -> String {
    switch specific {
      case "slides": slidesGuidance
      case "text": textGuidance
      case "images": imagesGuidance
      default: generalKeynoteGuidance
    }
  }

  // MARK: - Specific Guidance Content

  private static let slidesGuidance = """
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
    "id": "slide-2-uuid"
  }
  ```

  Tip: After your initial exploration, look for elements with roles like "AXImage" or "AXCell" in the slide navigator area.

  ### 3. Reordering Slides

  Drag operations work for reordering:

  ```json
  {
    "action": "drag",
    "id": "slide-2-uuid",
    "targetId": "slide-5-uuid"
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
  private static let textGuidance = """
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
       "id": "text-box-1-uuid"
     }
     ```

  2. Then click again to place cursor:
     ```json
     {
       "action": "click",
       "id": "text-box-1-uuid"
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
  private static let imagesGuidance = """
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
    "id": "image-1-uuid"
  }
  ```

  To move the image, drag it:

  ```json
  {
    "action": "drag",
    "id": "image-1-uuid",
    "targetId": "canvas-uuid"
  }
  ```

  ## Resizing Images

  1. First select the image
  2. Look for resize handles (small squares at the corners)
  3. Click and drag a corner handle to resize

  ```json
  {
    "action": "drag",
    "id": "resize-handle-uuid",
    "targetId": "canvas-uuid"
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
  private static let generalKeynoteGuidance = """
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
