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
      ExplorationGuidance.guidance(specific: specific)
    case "interaction":
      InteractionGuidance.guidance(specific: specific)
    case "keynote":
      KeynoteGuidance.guidance(specific: specific)
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

  // EXTRACTED: ExplorationGuidance, InteractionGuidance, KeynoteGuidance moved to separate files

  /// Guidance specific to Pages
  // EXTRACTED: ExplorationGuidance, InteractionGuidance, KeynoteGuidance moved to separate files

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
