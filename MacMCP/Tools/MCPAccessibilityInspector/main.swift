// ABOUTME: main.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import ArgumentParser
import Dispatch
import Foundation
import Logging
import MCP  // Import MCP for Value type

// Configure a logger for the inspector
let logger = Logger(label: "com.anthropic.mac-mcp.mcp-ax-inspector")

/// A class to handle JSON fetching tasks in a way that can be used with a semaphore
/// This solves the issue of capturing state in Task closures
@available(macOS 12.0, *)
final class JsonFetcher: @unchecked Sendable {
  private let inspector: MCPInspector
  private let appId: String?
  private let inspectPath: String?
  private let maxDepth: Int
  private let onComplete: (String) -> Void
  private let onError: (Swift.Error) -> Void

  init(
    inspector: MCPInspector,
    appId: String?,
    inspectPath: String?,
    maxDepth: Int,
    onComplete: @escaping (String) -> Void,
    onError: @escaping (Swift.Error) -> Void
  ) {
    self.inspector = inspector
    self.appId = appId
    self.inspectPath = inspectPath
    self.maxDepth = maxDepth
    self.onComplete = onComplete
    self.onError = onError
  }

  func fetch() async {
    do {
      let result = try await getOriginalJsonOutput()
      onComplete(result)
    } catch {
      onError(error)
    }
  }

  /// Get the original JSON output directly from the MCP server
  private func getOriginalJsonOutput() async throws -> String {
    guard let client = inspector.mcpClient else {
      throw InspectionError.unexpectedError("MCP client not initialized")
    }

    guard let bundleId = appId else {
      throw InspectionError.unexpectedError("Bundle ID required for raw JSON output")
    }

    // Create the request parameters based on whether we're doing a path-based lookup
    let arguments: [String: Value]

    if let path = inspectPath, path.hasPrefix("ui://") {
      // Path-based inspection
      arguments = [
        "scope": .string("path"),
        "bundleId": .string(bundleId),
        "elementPath": .string(path),
        "maxDepth": .int(maxDepth),
        "includeHidden": .bool(true),
        // Add original path to ensure we keep it intact in the output
        "originalPath": .string(path),
      ]
      print("Fetching raw JSON for path: \(path)")
    } else {
      // Standard application inspection
      arguments = [
        "scope": .string("application"),
        "bundleId": .string(bundleId),
        "maxDepth": .int(maxDepth),
        "includeHidden": .bool(true),
      ]
      print("Fetching raw JSON for application: \(bundleId)")
    }

    // Call the MCP server
    let (content, isError) = try await client.callTool(
      name: "macos_interface_explorer",
      arguments: arguments,
    )

    if let isError, isError {
      throw InspectionError.unexpectedError("Error from MCP tool: \(content)")
    }

    // Extract the JSON content
    guard let firstContent = content.first, case .text(let jsonString) = firstContent else {
      throw InspectionError.unexpectedError(
        "Invalid response format from MCP: missing text content")
    }

    // Try to pretty-print the JSON for better readability
    do {
      // Parse the JSON into an object
      guard let jsonData = jsonString.data(using: .utf8) else {
        return jsonString  // Return the original if conversion fails
      }

      let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])

      // Convert back to a pretty-printed JSON string
      let prettyData = try JSONSerialization.data(
        withJSONObject: jsonObject, options: [.prettyPrinted])

      if let prettyString = String(data: prettyData, encoding: .utf8) {
        return prettyString
      } else {
        return jsonString  // Return the original if conversion fails
      }
    } catch {
      // If pretty-printing fails, return the original JSON string
      return jsonString
    }
  }
}

/// A class to handle asynchronous inspection tasks in a way that can be used with a semaphore
/// This solves the issue of capturing state in Task closures
@available(macOS 12.0, *)
final class AsyncInspectionTask: @unchecked Sendable {
  private let inspector: MCPInspector
  private let onComplete: (MCPUIElementNode, String) -> Void  // Added additional output parameter
  private let onError: (Swift.Error) -> Void
  private let showMenuDetail: Bool
  private let menuPath: String?
  private let showWindowDetail: Bool
  private let windowId: String?
  private let inspectPath: String?
  private let pathFilter: String?

  init(
    inspector: MCPInspector,
    showMenuDetail: Bool = false,
    menuPath: String? = nil,
    showWindowDetail: Bool = false,
    windowId: String? = nil,
    inspectPath: String? = nil,
    pathFilter: String? = nil,
    onComplete: @escaping (MCPUIElementNode, String) -> Void,
    onError: @escaping (Swift.Error) -> Void
  ) {
    self.inspector = inspector
    self.showMenuDetail = showMenuDetail
    self.menuPath = menuPath
    self.showWindowDetail = showWindowDetail
    self.windowId = windowId
    self.inspectPath = inspectPath
    self.pathFilter = pathFilter
    self.onComplete = onComplete
    self.onError = onError
  }

  func run() async {
    do {
      print("Launching MCP and retrieving UI state...")

      // Check if we're doing path-based inspection or filter-based inspection
      let rootElement: MCPUIElementNode

      if let path = inspectPath, let appId = inspector.appId {
        print("Performing server-side path-based inspection for: \(path)")
        // Use the inspectElementByPath method for direct server-side path resolution
        rootElement = try await inspector.inspectElementByPath(
          bundleIdentifier: appId,
          path: path,
          maxDepth: 15,  // Use smaller depth for path inspection
        )
        print("Successfully retrieved element at path: \(path)")
      } else if let filter = pathFilter, inspector.appId != nil {
        print("Performing filter-based inspection for: \(filter)")
        // Use the inspector method that accepts a path filter
        rootElement = try await inspector.inspectApplication(pathFilter: filter)
        print("Successfully retrieved UI state with filter: \(filter)")
      } else {
        // Normal application inspection
        rootElement = try await inspector.inspectApplication()
        print("Successfully retrieved UI state!")
      }

      // Fetch additional details
      var additionalOutput = ""

      // Get menu details if requested (only if not doing path-based inspection)
      if showMenuDetail || menuPath != nil, inspectPath == nil {
        additionalOutput += "\n--- Menu Structure ---\n"
        // Get menu information using the client from the inspector
        if let mcpClient = inspector.mcpClient, let appId = inspector.appId {
          do {
            // Get application menus
            let arguments: [String: Value] = [
              "action": .string("getApplicationMenus"),
              "bundleId": .string(appId),
            ]

            print("Fetching menu structure for \(appId)...")
            let (content, isError) = try await mcpClient.callTool(
              name: "macos_menu_navigation",
              arguments: arguments,
            )

            if let isError, isError {
              additionalOutput += "Error fetching menu structure: \(content)\n"
            } else if let firstContent = content.first, case .text(let menuText) = firstContent {
              additionalOutput += "Application Menus:\n\(menuText)\n"
            } else {
              additionalOutput += "No menu structure available\n"
            }

            // If a specific menu was requested, get its items
            if let menuName = menuPath {
              additionalOutput += "\nFetching items for menu '\(menuName)'...\n"

              let menuItemsArgs: [String: Value] = [
                "action": .string("getMenuItems"),
                "bundleId": .string(appId),
                "menuTitle": .string(menuName),
                "includeSubmenus": .bool(true),
              ]

              let (menuItemsContent, menuItemsError) = try await mcpClient.callTool(
                name: "macos_menu_navigation",
                arguments: menuItemsArgs,
              )

              if let isError = menuItemsError, isError {
                additionalOutput += "Error fetching menu items: \(menuItemsContent)\n"
              } else if let firstContent = menuItemsContent.first,
                case .text(let menuItemsText) = firstContent
              {
                additionalOutput += "Menu Items:\n\(menuItemsText)\n"
              } else {
                additionalOutput += "No menu items available\n"
              }
            }
          } catch {
            additionalOutput += "Error with menu navigation: \(error.localizedDescription)\n"
          }
        } else {
          additionalOutput += "Cannot access menu navigation tools\n"
        }
      }

      // Get window details if requested (only if not doing path-based inspection)
      if showWindowDetail || windowId != nil, inspectPath == nil {
        additionalOutput += "\n--- Window Information ---\n"
        // Get window information using the client from the inspector
        if let mcpClient = inspector.mcpClient, let appId = inspector.appId {
          do {
            // Get application windows
            let arguments: [String: Value] = [
              "action": .string("getApplicationWindows"),
              "bundleId": .string(appId),
              "includeMinimized": .bool(true),
            ]

            print("Fetching window information for \(appId)...")
            let (content, isError) = try await mcpClient.callTool(
              name: "macos_window_management",
              arguments: arguments,
            )

            if let isError, isError {
              additionalOutput += "Error fetching window information: \(content)\n"
            } else if let firstContent = content.first, case .text(let windowText) = firstContent {
              additionalOutput += "Application Windows:\n\(windowText)\n"
            } else {
              additionalOutput += "No window information available\n"
            }

            // If a specific window was requested, get its details
            if let windowIdValue = windowId {
              additionalOutput += "\nFetching details for window ID '\(windowIdValue)'...\n"

              let windowDetailsArgs: [String: Value] = [
                "action": .string("getActiveWindow"),
                "bundleId": .string(appId),
                "windowId": .string(windowIdValue),
              ]

              let (windowDetailsContent, windowDetailsError) = try await mcpClient.callTool(
                name: "macos_window_management",
                arguments: windowDetailsArgs,
              )

              if let isError = windowDetailsError, isError {
                additionalOutput += "Error fetching window details: \(windowDetailsContent)\n"
              } else if let firstContent = windowDetailsContent.first,
                case .text(let windowDetailsText) = firstContent
              {
                additionalOutput += "Window Details:\n\(windowDetailsText)\n"
              } else {
                additionalOutput += "No details available for this window\n"
              }
            }
          } catch {
            additionalOutput += "Error with window management: \(error.localizedDescription)\n"
          }
        } else {
          additionalOutput += "Cannot access window management tools\n"
        }
      }

      // Call onComplete with both the root element and the additional output
      onComplete(rootElement, additionalOutput)
    } catch {
      print("Error during inspection: \(error)")
      onError(error)
    }
  }
}

// Define the command-line tool using ArgumentParser
struct MCPAccessibilityInspector: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "mcp-ax-inspector",
    abstract:
      "A utility for inspecting the accessibility tree of macOS applications using MCP tools",
    discussion: """
      The MCP Accessibility Tree Inspector provides detailed visualization and inspection
      of UI element hierarchies in macOS applications. This implementation uses the MacMCP's
      InterfaceExplorerTool for enhanced element information including state and capabilities,
      along with MenuNavigationTool and WindowManagementTool for menu and window inspection.

      Examples:
        # Inspect Calculator with default settings
        mcp-ax-inspector --app-id com.apple.calculator

        # Filter to show only button elements
        mcp-ax-inspector --app-id com.apple.calculator --filter "role=AXButton"

        # Find elements with specific description
        mcp-ax-inspector --app-id com.apple.calculator --filter "description=1"

        # Show only window content elements (exclude menus and controls)
        mcp-ax-inspector --app-id com.apple.calculator --show-window-contents

        # Save the output to a file
        mcp-ax-inspector --app-id com.apple.calculator --save output.txt

        # Limit tree depth for large applications (improves performance)
        mcp-ax-inspector --app-id com.apple.TextEdit --max-depth 10

        # Show detailed menu structure and window information
        mcp-ax-inspector --app-id com.apple.TextEdit --menu-detail --window-detail

        # Get details for a specific menu
        mcp-ax-inspector --app-id com.apple.TextEdit --menu-path "File"

      Path-related features:
        # Show element paths for all UI elements
        mcp-ax-inspector --app-id com.apple.calculator --show-paths

        # Highlight paths to make them more visible
        mcp-ax-inspector --app-id com.apple.calculator --highlight-paths

        # Show paths only for interactive elements
        mcp-ax-inspector --app-id com.apple.calculator --interactive-paths

        # Filter elements by path pattern
        mcp-ax-inspector --app-id com.apple.calculator --path-filter "AXButton[@description=\\"1\\"]"

        # Show full hierarchical paths (default behavior)
        mcp-ax-inspector --app-id com.apple.calculator

        # Disable full path display (show only path segments)
        mcp-ax-inspector --app-id com.apple.calculator --hide-full-paths

        # Inspect a specific element directly by its path
        mcp-ax-inspector --app-id com.apple.calculator --inspect-path "ui://AXApplication[@title=\"Calculator\"]/AXWindow/AXButton[@description=\"1\"]"

      Output options:
        # Output raw JSON response instead of tree visualization
        mcp-ax-inspector --app-id com.apple.calculator --raw-json

        # Output raw JSON for a specific element path
        mcp-ax-inspector --app-id com.apple.calculator --inspect-path "ui://AXApplication[@AXTitle=\"Calculator\"]/AXWindow" --raw-json
      """,
  )

  // Application targeting options
  @Option(name: [.customLong("app-id")], help: "Application bundle identifier")
  var appId: String?

  // We don't require PID anymore since app-id is required
  @Option(name: [.customLong("pid")], help: "Application process ID (optional)")
  var pid: Int?

  // Tree traversal options
  @Option(name: [.customLong("max-depth")], help: "Maximum depth to traverse (default: 150)")
  var maxDepth: Int = 150

  // MCP server options
  @Option(name: [.customLong("mcp-path")], help: "Path to MCP server executable")
  var mcpPath: String?

  // Output options
  @Option(name: [.customLong("save")], help: "Save output to file")
  var saveToFile: String?

  @Option(
    name: [.customLong("filter")], help: "Filter elements by property (format: property=value)")
  var filter: [String] = []

  @Flag(name: [.customLong("hide-invisible")], help: "Hide invisible elements")
  var hideInvisible: Bool = false

  @Flag(name: [.customLong("hide-disabled")], help: "Hide disabled elements")
  var hideDisabled: Bool = false

  @Flag(
    name: [.customLong("show-menus")],
    help: "Only show menu-related elements (menu bar, menus, menu items)")
  var showMenus: Bool = false

  @Flag(
    name: [.customLong("show-window-controls")],
    help: "Only show window control elements (close, minimize, zoom buttons, toolbars, etc.)",
  )
  var showWindowControls: Bool = false

  @Flag(
    name: [.customLong("show-window-contents")],
    help: "Only show window content elements (excluding menus and controls)",
  )
  var showWindowContents: Bool = false

  @Flag(
    name: [.customLong("verbose")],
    help: "Show even more detailed diagnostics (currently all data is shown by default)",
  )
  var verbose: Bool = false

  // Menu interaction options
  @Flag(
    name: [.customLong("menu-detail")], help: "Show detailed menu structure for the application")
  var showMenuDetail: Bool = false

  @Option(name: [.customLong("menu-path")], help: "Get items for a specific menu (e.g., 'File')")
  var menuPath: String?

  // Window interaction options
  @Flag(
    name: [.customLong("window-detail")],
    help: "Show detailed window information for the application")
  var showWindowDetail: Bool = false

  @Option(name: [.customLong("window-id")], help: "Get details for a specific window ID")
  var windowId: String?

  // Path-related options
  @Flag(name: [.customLong("show-paths")], help: "Show UI element paths for all elements")
  var showPaths: Bool = false

  @Flag(name: [.customLong("highlight-paths")], help: "Highlight UI element paths in the output")
  var highlightPaths: Bool = false

  @Option(
    name: [.customLong("path-filter")],
    help: "Filter elements by path pattern (e.g., \"AXButton[@description=1]\")",
  )
  var pathFilter: String?

  @Flag(
    name: [.customLong("interactive-paths")],
    help: "Highlight paths for interactive elements (buttons, links, etc.)",
  )
  var showInteractivePaths: Bool = false

  @Flag(
    name: [.customLong("hide-full-paths")],
    help: "Hide full hierarchical paths and show only path segments")
  var hideFullPaths: Bool = false

  @Option(
    name: [.customLong("inspect-path")],
    help:
      "Directly inspect an element by its full path (e.g., \"ui://AXApplication[@title=\\\"Calculator\\\"]/AXWindow/AXButton\")",
  )
  var inspectPath: String?

  // Raw output option
  @Flag(
    name: [.customLong("raw-json")],
    help: "Output the raw JSON response instead of rendering the tree")
  var rawJson: Bool = false

  // Need to implement a synchronous wrapper to execute async code
  func run() throws {
    print("Starting MCP Accessibility Inspector...")

    print("Command-line arguments received in run():")
    print("App ID: \(appId ?? "Not specified")")
    print("PID: \(pid ?? -1)")
    print("MCP path: \(mcpPath ?? "Not specified")")
    print("Max depth: \(maxDepth)")
    print("Save to file: \(saveToFile ?? "Not specified")")
    print("Filters: \(filter)")
    print("Hide invisible: \(hideInvisible)")
    print("Hide disabled: \(hideDisabled)")
    print("Show menus: \(showMenus)")
    print("Show window controls: \(showWindowControls)")
    print("Show window contents: \(showWindowContents)")
    print("Verbose: \(verbose)")
    print("Show paths: \(showPaths)")
    print("Highlight paths: \(highlightPaths)")
    print("Path filter: \(pathFilter ?? "Not specified")")
    print("Show interactive paths: \(showInteractivePaths)")
    print("Hide full paths: \(hideFullPaths)")
    print("Inspect path: \(inspectPath ?? "Not specified")")

    // Verify we have either appId or pid
    guard appId != nil || pid != nil else {
      logger.error("Either --app-id or --pid must be specified")
      print("Error: Either --app-id or --pid must be specified")
      throw ValidationError("Either --app-id or --pid must be specified")
    }

    // Create the inspector with the specified MCP path
    let resolvedMcpPath = resolveMcpPath(mcpPath)
    print("Creating inspector with MCP path: \(resolvedMcpPath)")

    // Check if MCP executable exists
    let executablePath = checkMcpExecutable(resolvedMcpPath)

    // Create inspector and run
    let inspector = MCPInspector(
      appId: appId, pid: pid, maxDepth: maxDepth, mcpPath: executablePath)

    // Parse filters
    var filterDict = [String: String]()
    for filterString in filter {
      let parts = filterString.split(separator: "=")
      if parts.count == 2 {
        filterDict[String(parts[0])] = String(parts[1])
      } else {
        logger.warning(
          "Ignoring invalid filter format: \(filterString). Expected format: property=value")
        print(
          "Warning: Ignoring invalid filter format: \(filterString). Expected format: property=value"
        )
      }
    }

    // Run the inspection
    do {
      print("Beginning inspection of \(appId ?? String(describing: pid))")
      logger.info(
        "Beginning inspection",
        metadata: [
          "appId": .string(appId ?? ""),
          "pid": .stringConvertible(pid ?? 0),
          "mcpPath": .string(mcpPath ?? "default"),
        ])

      // Check if app ID is required but not provided
      if inspectPath != nil, appId == nil {
        logger.error("--app-id must be specified with --inspect-path")
        print("Error: --app-id must be specified with --inspect-path")
        throw ValidationError("--app-id must be specified with --inspect-path")
      }

      // We can't directly use async/await in a synchronous run method,
      // so we'll use a dispatch semaphore to wait for the async operation to complete
      let semaphore = DispatchSemaphore(value: 0)
      var resultRootElement: MCPUIElementNode?
      var resultError: Swift.Error?
      var additionalOutput = ""

      // We need to delegate to a separate async method to avoid issues
      // with capturing state in the Task
      // Only use pathFilter as inspectPath if it's a full UI path
      let effectiveInspectPath = inspectPath
      let pathFilterValue = pathFilter  // Keep the original path filter for filtering

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
        },
      )

      // Run the async task with @Sendable to prevent data race issues
      Task { @Sendable in
        await asyncTask.run()
      }

      // Wait for the task to complete
      print("Waiting for MCP inspection to complete...")
      semaphore.wait()

      // Check for error
      if let error = resultError {
        throw error
      }

      // Process results
      guard let rootElement = resultRootElement else {
        print("No UI elements returned")
        return
      }

      // If raw JSON output is requested, set up a way to get the raw JSON
      if rawJson {
        // Create a semaphore and result holders
        let jsonSemaphore = DispatchSemaphore(value: 0)
        var jsonResult: String?
        var jsonError: Swift.Error?

        // Create the fetcher object with the top-level JsonFetcher class
        let fetcher = JsonFetcher(
          inspector: inspector,
          appId: appId,
          inspectPath: effectiveInspectPath,
          maxDepth: maxDepth,
          onComplete: { result in
            jsonResult = result
            jsonSemaphore.signal()
          },
          onError: { error in
            jsonError = error
            jsonSemaphore.signal()
          },
        )

        // Start the fetch task
        Task {
          await fetcher.fetch()
        }

        // Wait for the task to complete
        jsonSemaphore.wait()

        // Check for errors
        if let error = jsonError {
          throw error
        }

        // Print the JSON result
        if let jsonOutput = jsonResult {
          print(jsonOutput)
        } else {
          print("No JSON output available")
        }

        // Cleanup resources
        inspector.cleanupSync()
        return
      }

      // Create visualizer options
      var visualizerOptions = MCPTreeVisualizer.Options()
      visualizerOptions.showDetails = true  // Always show details
      visualizerOptions.showAllAttributes = true  // Always show all attributes

      // Apply path-related options
      visualizerOptions.highlightPaths = highlightPaths || showPaths
      visualizerOptions.showFullPaths = !hideFullPaths

      // Initialize visualizer
      let visualizer = MCPTreeVisualizer(options: visualizerOptions)

      // Add interactive elements filter if requested
      if showInteractivePaths {
        filterDict["component-type"] = "interactive"
      }

      // Generate the visualization
      print("Generating visualization...")
      let output = visualizer.visualize(
        rootElement, withFilters: filterDict, pathPattern: pathFilter)

      // Note: additionalOutput is already populated by the AsyncInspectionTask

      // Output handling
      if let saveToFile {
        // Save to file
        print("Saving output to file: \(saveToFile)")
        do {
          let combinedOutput = output + additionalOutput
          try combinedOutput.write(toFile: saveToFile, atomically: true, encoding: .utf8)
          print("Output saved to: \(saveToFile)")
        } catch {
          logger.error("Failed to save output to file: \(error.localizedDescription)")
          print("Error: Failed to save output to file: \(error.localizedDescription)")
        }
      } else {
        // Print to console
        print("\n--- UI Tree ---\n")
        print(output)

        // Print additional info if available
        if !additionalOutput.isEmpty {
          print(additionalOutput)
        }
      }

      logger.info("Inspection completed successfully")
      print("Inspection completed successfully")

      // Explicitly clean up MCP resources
      print("Cleaning up MCP resources...")
      inspector.cleanupSync()
      print("MCP resources cleaned up")
    } catch let error as InspectionError {
      logger.error("Inspection failed: \(error.description)")
      print("Inspection error: \(error.description)")

      // Clean up even on error
      inspector.cleanupSync()
      throw ExitCode.failure
    } catch {
      logger.error("Unexpected error: \(error.localizedDescription)")
      print("Unexpected error: \(error.localizedDescription)")

      // Clean up even on error
      inspector.cleanupSync()
      throw ExitCode.failure
    }
  }

  private func resolveMcpPath(_ path: String?) -> String {
    guard let path else {
      // Default to MacMCP in the same directory
      return "./MacMCP"
    }

    // If the path is absolute, use it directly
    if path.hasPrefix("/") {
      return path
    }

    // If the path is relative, resolve it against the current directory
    let fileManager = FileManager.default
    let currentDirectory = fileManager.currentDirectoryPath
    return URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
  }

  private func checkMcpExecutable(_ path: String) -> String {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
      print("Warning: MCP executable not found at: \(path)")

      // Try to find MacMCP in various locations
      let possibleLocations = [
        "./MacMCP",
        "./.build/debug/MacMCP",
        "../.build/debug/MacMCP",
        "/usr/local/bin/MacMCP",
      ]

      for location in possibleLocations {
        let resolvedPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
          .appendingPathComponent(location).path
        if fileManager.fileExists(atPath: resolvedPath) {
          print("Found MCP executable at: \(resolvedPath)")
          return resolvedPath
        }
      }

      // If we get here, we couldn't find the executable
      print("WARNING: Could not find MCP executable in any standard location.")
      print("Using the original path but the application may fail to start: \(path)")
      return path
    } else {
      print("MCP executable found at: \(path)")
      return path
    }
  }

  // We've moved the getOriginalJsonOutput function to the JsonFetcher class

  /// Get detailed menu information using MenuNavigationTool
  private func getMenuDetails(inspector: MCPInspector, bundleId: String) async throws -> String {
    guard let mcpClient = inspector.mcpClient else {
      return "Menu client not available\n"
    }

    var result = "Fetching menu structure for \(bundleId)...\n"

    // Create the request parameters for the MenuNavigationTool
    var arguments: [String: Value] = [
      "action": .string("getApplicationMenus"),
      "bundleId": .string(bundleId),
    ]

    do {
      // First get all application menus
      let (content, isError) = try await mcpClient.callTool(
        name: "macos_menu_navigation",
        arguments: arguments,
      )

      if let isError, isError {
        return "Error fetching menu structure: \(content)\n"
      }

      // Convert menu content to string
      if let firstContent = content.first, case .text(let menuText) = firstContent {
        result += "Application Menus:\n\(menuText)\n"
      } else {
        result += "No menu structure available\n"
      }

      // If a specific menu path was requested, get the menu items
      if let menuTitle = menuPath {
        result += "\nFetching menu items for \(menuTitle)...\n"

        // Create parameters for getting menu items
        arguments = [
          "action": .string("getMenuItems"),
          "bundleId": .string(bundleId),
          "menuTitle": .string(menuTitle),
          "includeSubmenus": .bool(true),
        ]

        let (menuItemsContent, menuItemsError) = try await mcpClient.callTool(
          name: "macos_menu_navigation",
          arguments: arguments,
        )

        if let isError = menuItemsError, isError {
          result += "Error fetching menu items: \(menuItemsContent)\n"
        } else if let firstContent = menuItemsContent.first,
          case .text(let menuItemsText) = firstContent
        {
          result += "Menu Items for \(menuTitle):\n\(menuItemsText)\n"
        } else {
          result += "No menu items available for \(menuTitle)\n"
        }
      }

      return result
    } catch {
      return "Error fetching menu details: \(error.localizedDescription)\n"
    }
  }

  /// Get detailed window information using WindowManagementTool
  private func getWindowDetails(inspector: MCPInspector, bundleId: String, windowId: String?)
    async throws -> String
  {
    guard let mcpClient = inspector.mcpClient else {
      return "Window client not available\n"
    }

    var result = "Fetching window information for \(bundleId)...\n"

    // Create the request parameters for the WindowManagementTool
    var arguments: [String: Value] = [
      "action": .string("getApplicationWindows"),
      "bundleId": .string(bundleId),
      "includeMinimized": .bool(true),
    ]

    do {
      // First get all application windows
      let (content, isError) = try await mcpClient.callTool(
        name: "macos_window_management",
        arguments: arguments,
      )

      if let isError, isError {
        return "Error fetching window information: \(content)\n"
      }

      // Convert window content to string
      if let firstContent = content.first, case .text(let windowText) = firstContent {
        result += "Application Windows:\n\(windowText)\n"
      } else {
        result += "No window information available\n"
      }

      // If a specific window ID was requested, get details for that window
      if let windowId {
        result += "\nFetching details for window ID \(windowId)...\n"

        // Create parameters for getting window details
        arguments = [
          "action": .string("getActiveWindow"),
          "bundleId": .string(bundleId),
          "windowId": .string(windowId),
        ]

        let (windowDetailsContent, windowDetailsError) = try await mcpClient.callTool(
          name: "macos_window_management",
          arguments: arguments,
        )

        if let isError = windowDetailsError, isError {
          result += "Error fetching window details: \(windowDetailsContent)\n"
        } else if let firstContent = windowDetailsContent.first,
          case .text(let windowDetailsText) = firstContent
        {
          result += "Window Details for \(windowId):\n\(windowDetailsText)\n"
        } else {
          result += "No details available for window ID \(windowId)\n"
        }
      }

      return result
    } catch {
      return "Error fetching window details: \(error.localizedDescription)\n"
    }
  }
}

// Run the command
MCPAccessibilityInspector.main()
