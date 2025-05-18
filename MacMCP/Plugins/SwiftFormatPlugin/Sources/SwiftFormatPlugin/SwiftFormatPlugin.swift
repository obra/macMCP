// ABOUTME: SwiftFormatPlugin.swift
// ABOUTME: Provides build-time formatting for Swift packages using SwiftFormat.

import PackagePlugin
import Foundation

@main
struct SwiftFormatPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Check if swiftformat is installed
        let swiftformatPath: Path
        do {
            swiftformatPath = try context.tool(named: "swiftformat").path
        } catch {
            // Print a warning but don't fail the build
            print("Warning: SwiftFormat not found, skipping formatting for target: \(target.name)")
            return []
        }
        
        // Determine the directory containing the target sources
        let targetDirectory = target.directory
        
        // Create the format command for the target
        return [
            .buildCommand(
                displayName: "Formatting \(target.name) with SwiftFormat",
                executable: swiftformatPath,
                arguments: [
                    "\(targetDirectory)",
                    "--quiet",
                    "--lint"
                ],
                environment: [:]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftFormatPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Check if swiftformat is installed
        let swiftformatPath: Path
        do {
            swiftformatPath = try context.tool(named: "swiftformat").path
        } catch {
            // Print a warning but don't fail the build
            print("Warning: SwiftFormat not found, skipping formatting for target: \(target.displayName)")
            return []
        }
        
        // Create the format command for the target
        return [
            .buildCommand(
                displayName: "Formatting \(target.displayName) with SwiftFormat",
                executable: swiftformatPath,
                arguments: [
                    "\(context.xcodeProject.directory)",
                    "--quiet",
                    "--lint"
                ],
                environment: [:]
            )
        ]
    }
}
#endif