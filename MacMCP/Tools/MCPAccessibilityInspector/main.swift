// ABOUTME: Entry point for the MCP-based Accessibility Tree Inspector command-line tool
// ABOUTME: Processes command-line arguments and coordinates the inspection of macOS UI elements using MCP

import Foundation
import ArgumentParser
import Logging
import Dispatch

// Configure a logger for the inspector
let logger = Logger(label: "com.anthropic.mac-mcp.mcp-ax-inspector")

/// A class to handle asynchronous inspection tasks in a way that can be used with a semaphore
/// This solves the issue of capturing state in Task closures
@available(macOS 12.0, *)
final class AsyncInspectionTask: @unchecked Sendable {
    private let inspector: MCPInspector
    private let onComplete: (MCPUIElementNode) -> Void
    private let onError: (Error) -> Void
    
    init(inspector: MCPInspector, 
         onComplete: @escaping (MCPUIElementNode) -> Void,
         onError: @escaping (Error) -> Void) {
        self.inspector = inspector
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func run() async {
        do {
            print("Launching MCP and retrieving UI state...")
            let rootElement = try await inspector.inspectApplication()
            print("Successfully retrieved UI state!")
            onComplete(rootElement)
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
        abstract: "A utility for inspecting the accessibility tree of macOS applications using MCP tools",
        discussion: """
        The MCP Accessibility Tree Inspector provides detailed visualization and inspection 
        of UI element hierarchies in macOS applications. This implementation uses the MacMCP's
        tools rather than direct API access, making it suitable for LLM-driven exploration.
        
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
        """
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
    
    @Option(name: [.customLong("filter")], help: "Filter elements by property (format: property=value)")
    var filter: [String] = []
    
    @Flag(name: [.customLong("hide-invisible")], help: "Hide invisible elements")
    var hideInvisible: Bool = false
    
    @Flag(name: [.customLong("hide-disabled")], help: "Hide disabled elements")
    var hideDisabled: Bool = false
    
    @Flag(name: [.customLong("show-menus")], help: "Only show menu-related elements (menu bar, menus, menu items)")
    var showMenus: Bool = false
    
    @Flag(name: [.customLong("show-window-controls")], help: "Only show window control elements (close, minimize, zoom buttons, toolbars, etc.)")
    var showWindowControls: Bool = false
    
    @Flag(name: [.customLong("show-window-contents")], help: "Only show window content elements (excluding menus and controls)")
    var showWindowContents: Bool = false
    
    @Flag(name: [.customLong("verbose")], help: "Show even more detailed diagnostics (currently all data is shown by default)")
    var verbose: Bool = false
    
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
        let inspector = MCPInspector(appId: appId, pid: pid, maxDepth: maxDepth, mcpPath: executablePath)
        
        // Parse filters
        var filterDict = [String: String]()
        for filterString in filter {
            let parts = filterString.split(separator: "=")
            if parts.count == 2 {
                filterDict[String(parts[0])] = String(parts[1])
            } else {
                logger.warning("Ignoring invalid filter format: \(filterString). Expected format: property=value")
                print("Warning: Ignoring invalid filter format: \(filterString). Expected format: property=value")
            }
        }
        
        // Run the inspection
        do {
            print("Beginning inspection of \(appId ?? String(describing: pid))")
            logger.info("Beginning inspection", metadata: [
                "appId": .string(appId ?? ""),
                "pid": .stringConvertible(pid ?? 0),
                "mcpPath": .string(mcpPath ?? "default")
            ])
            
            // Perform the inspection
            // We can't directly use async/await in a synchronous run method,
            // so we need to use a workaround to bridge the gap
            
            // Instead of using await directly, we'll use a dispatch semaphore 
            // to wait for the async operation to complete
            let semaphore = DispatchSemaphore(value: 0)
            var resultRootElement: MCPUIElementNode?
            var resultError: Error?
            
            // We need to delegate to a separate async method to avoid issues
            // with capturing state in the Task
            let asyncTask = AsyncInspectionTask(
                inspector: inspector,
                onComplete: { root in
                    resultRootElement = root
                    semaphore.signal()
                },
                onError: { error in
                    resultError = error
                    semaphore.signal()
                }
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
            
            // Create visualizer options
            var visualizerOptions = MCPTreeVisualizer.Options()
            visualizerOptions.showDetails = true // Always show details
            visualizerOptions.showAllAttributes = true // Always show all attributes
            
            // Initialize visualizer
            let visualizer = MCPTreeVisualizer(options: visualizerOptions)
            
            // Generate the visualization
            print("Generating visualization...")
            let output = visualizer.visualize(rootElement, withFilters: filterDict)
            
            // Output handling
            if let saveToFile = saveToFile {
                // Save to file
                print("Saving output to file: \(saveToFile)")
                do {
                    try output.write(toFile: saveToFile, atomically: true, encoding: .utf8)
                    print("Output saved to: \(saveToFile)")
                } catch {
                    logger.error("Failed to save output to file: \(error.localizedDescription)")
                    print("Error: Failed to save output to file: \(error.localizedDescription)")
                }
            } else {
                // Print to console
                print("\n--- UI Tree ---\n")
                print(output)
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
        guard let path = path else {
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
                "/usr/local/bin/MacMCP"
            ]
            
            for location in possibleLocations {
                let resolvedPath = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent(location).path
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
}

// Run the command
MCPAccessibilityInspector.main()