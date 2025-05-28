// ABOUTME: main.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import ArgumentParser
import Foundation
import Logging

// Configure a logger for the inspector
let logger = Logger(label: "com.fsck.mac-mcp.ax-inspector")

// Define the command-line tool using ArgumentParser
struct AccessibilityInspector: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ax-inspector",
    abstract: "A utility for inspecting the accessibility tree of macOS applications",
    discussion: """
      The Accessibility Tree Inspector provides detailed visualization and inspection 
      of UI element hierarchies in macOS applications. This is essential for test 
      development and troubleshooting accessibility interactions.
      """,
  )

  // Application targeting options
  @Option(name: [.customLong("app-id")], help: "Application bundle identifier") var appId: String?

  @Option(name: [.customLong("pid")], help: "Application process ID") var pid: Int?

  // Tree traversal options
  @Option(name: [.customLong("max-depth")], help: "Maximum depth to traverse (default: 150)")
  var maxDepth: Int = 150

  // Output options
  @Option(name: [.customLong("save")], help: "Save output to file") var saveToFile: String?

  @Option(
    name: [.customLong("filter")], help: "Filter elements by property (format: property=value)")
  var filter: [String] = []

  @Flag(name: [.customLong("hide-invisible")], help: "Hide invisible elements") var hideInvisible:
    Bool = false

  @Flag(name: [.customLong("hide-disabled")], help: "Hide disabled elements") var hideDisabled:
    Bool = false

  @Flag(
    name: [.customLong("show-menus")],
    help: "Only show menu-related elements (menu bar, menus, menu items)")
  var showMenus: Bool = false

  @Flag(
    name: [.customLong("show-window-controls")],
    help: "Only show window control elements (close, minimize, zoom buttons, toolbars, etc.)",
  ) var showWindowControls: Bool = false

  @Flag(
    name: [.customLong("show-window-contents")],
    help: "Only show window content elements (excluding menus and controls)",
  ) var showWindowContents: Bool = false

  @Flag(
    name: [.customLong("verbose")],
    help: "Show even more detailed diagnostics (currently all data is shown by default)",
  ) var verbose: Bool = false

  func run() throws {
    logger.info("Starting Accessibility Tree Inspector")

    // Verify we have either appId or pid
    guard appId != nil || pid != nil else {
      logger.error("Either --app-id or --pid must be specified")
      throw ValidationError("Either --app-id or --pid must be specified")
    }

    // Create the inspector
    let inspector = Inspector(appId: appId, pid: pid, maxDepth: maxDepth)

    // Parse filters
    var filterDict = [String: String]()
    for filterString in filter {
      let parts = filterString.split(separator: "=")
      if parts.count == 2 {
        filterDict[String(parts[0])] = String(parts[1])
      } else {
        logger.warning(
          "Ignoring invalid filter format: \(filterString). Expected format: property=value")
      }
    }

    // Run the inspection
    do {
      logger.info(
        "Beginning inspection",
        metadata: ["appId": .string(appId ?? ""), "pid": .stringConvertible(pid ?? 0)],
      )

      // Perform the inspection
      let rootElement = try inspector.inspectApplication()

      // Create visualizer options
      var visualizerOptions = TreeVisualizer.Options()
      visualizerOptions.showDetails = true  // Always show details
      visualizerOptions.showAllAttributes = true  // Always show all attributes

      // Initialize visualizer
      let visualizer = TreeVisualizer(options: visualizerOptions)

      // Add filters for invisible and disabled elements if requested
      var combinedFilters = filterDict
      if hideInvisible { combinedFilters["visible"] = "yes" }
      if hideDisabled { combinedFilters["enabled"] = "yes" }

      // Handle UI component focus flags
      let viewTypeFlags = [showMenus, showWindowControls, showWindowContents]
      if viewTypeFlags.contains(true) {
        // If only one type is specified, use a direct component-type filter
        let flagsOn = viewTypeFlags.count(where: { $0 })
        if flagsOn == 1 {
          if showMenus {
            // Include menu-related elements: menu bar, menus, menu items
            combinedFilters["component-type"] = "menu"
          } else if showWindowControls {
            // Include window control elements: close/minimize/zoom buttons, toolbars, etc.
            combinedFilters["component-type"] = "window-controls"
          } else if showWindowContents {
            // Include main window content elements
            combinedFilters["component-type"] = "window-contents"
          }
        } else {
          // If multiple component types are requested, create a custom description
          // to explain what's being shown
          var typesShown = [String]()
          if showMenus { typesShown.append("menus") }
          if showWindowControls { typesShown.append("window controls") }
          if showWindowContents { typesShown.append("window contents") }

          logger.info("Showing multiple component types: \(typesShown.joined(separator: ", "))")

          // Use multiple filter keys with OR logic between them
          combinedFilters["component-types"] = typesShown.joined(separator: ",")
        }
      }

      // Generate the visualization
      let output = visualizer.visualize(rootElement, withFilters: combinedFilters)

      // Output handling
      if let saveToFile {
        // Save to file
        do {
          try output.write(toFile: saveToFile, atomically: true, encoding: .utf8)
          print("Output saved to: \(saveToFile)")
        } catch {
          logger.error("Failed to save output to file: \(error.localizedDescription)")
          print("Error: Failed to save output to file: \(error.localizedDescription)")
        }
      } else {
        // Print to console
        print(output)
      }

      logger.info("Inspection completed successfully")
    } catch let error as InspectionError {
      logger.error("Inspection failed: \(error.description)")
      print("Error: \(error.description)")
      throw ExitCode.failure
    } catch {
      logger.error("Unexpected error: \(error.localizedDescription)")
      print("Error: \(error.localizedDescription)")
      throw ExitCode.failure
    }
  }
}

// Define custom error types
enum InspectionError: Error {
  case accessibilityPermissionDenied
  case applicationNotFound
  case timeout
  case unexpectedError(String)

  var description: String {
    switch self {
    case .accessibilityPermissionDenied:
      "Accessibility permission denied. Please enable accessibility permissions in System Settings > Privacy & Security > Accessibility."
    case .applicationNotFound: "Application not found. Please verify the bundle ID or process ID."
    case .timeout: "Operation timed out. The application may be busy or not responding."
    case .unexpectedError(let message): "Unexpected error: \(message)"
    }
  }
}

// Run the command
AccessibilityInspector.main()
