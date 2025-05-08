// ABOUTME: Entry point for the Accessibility Tree Inspector command-line tool
// ABOUTME: Processes command-line arguments and coordinates the inspection of macOS UI elements

import Foundation
import ArgumentParser
import Logging

// Configure a logger for the inspector
let logger = Logger(label: "com.anthropic.mac-mcp.ax-inspector")

// Define the command-line tool using ArgumentParser
struct AccessibilityInspector: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ax-inspector",
        abstract: "A utility for inspecting the accessibility tree of macOS applications",
        discussion: """
        The Accessibility Tree Inspector provides detailed visualization and inspection 
        of UI element hierarchies in macOS applications. This is essential for test 
        development and troubleshooting accessibility interactions.
        """
    )
    
    // Application targeting options
    @Option(name: [.customLong("app-id")], help: "Application bundle identifier")
    var appId: String?
    
    @Option(name: [.customLong("pid")], help: "Application process ID")
    var pid: Int?
    
    // Tree traversal options
    @Option(name: [.customLong("max-depth")], help: "Maximum depth to traverse (default: 150)")
    var maxDepth: Int = 150
    
    // Output options
    @Option(name: [.customLong("save")], help: "Save output to file")
    var saveToFile: String?
    
    @Option(name: [.customLong("filter")], help: "Filter elements by property (format: property=value)")
    var filter: [String] = []
    
    @Flag(name: [.customLong("hide-invisible")], help: "Hide invisible elements")
    var hideInvisible: Bool = false
    
    @Flag(name: [.customLong("hide-disabled")], help: "Hide disabled elements")
    var hideDisabled: Bool = false
    
    @Flag(name: [.customLong("verbose")], help: "Show all available element data")
    var verbose: Bool = false
    
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
                logger.warning("Ignoring invalid filter format: \(filterString). Expected format: property=value")
            }
        }
        
        // Run the inspection
        do {
            logger.info("Beginning inspection", metadata: ["appId": .string(appId ?? ""), "pid": .stringConvertible(pid ?? 0)])
            
            // Perform the inspection
            let rootElement = try inspector.inspectApplication()
            
            // Create visualizer options
            var visualizerOptions = TreeVisualizer.Options()
            visualizerOptions.showDetails = verbose
            visualizerOptions.showAllAttributes = verbose
            
            // Initialize visualizer
            let visualizer = TreeVisualizer(options: visualizerOptions)
            
            // Add filters for invisible and disabled elements if requested
            var combinedFilters = filterDict
            if hideInvisible {
                combinedFilters["visible"] = "yes"
            }
            if hideDisabled {
                combinedFilters["enabled"] = "yes"
            }
            
            // Generate the visualization
            let output = visualizer.visualize(rootElement, withFilters: combinedFilters)
            
            // Output handling
            if let saveToFile = saveToFile {
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
            return "Accessibility permission denied. Please enable accessibility permissions in System Settings > Privacy & Security > Accessibility."
        case .applicationNotFound:
            return "Application not found. Please verify the bundle ID or process ID."
        case .timeout:
            return "Operation timed out. The application may be busy or not responding."
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
}

// Run the command
AccessibilityInspector.main()