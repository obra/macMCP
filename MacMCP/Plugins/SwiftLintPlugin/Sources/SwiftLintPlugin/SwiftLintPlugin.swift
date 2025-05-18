// ABOUTME: SwiftLintPlugin.swift
// ABOUTME: Provides build-time linting for Swift packages using SwiftLint.

import PackagePlugin
import Foundation

@main
struct SwiftLintPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Check if swiftlint is installed
        let swiftlintPath: Path
        do {
            swiftlintPath = try context.tool(named: "swiftlint").path
        } catch {
            // Print a warning but don't fail the build
            print("Warning: SwiftLint not found, skipping linting for target: \(target.name)")
            return []
        }
        
        // Determine the directory containing the target sources
        let targetDirectory = target.directory
        
        // Create the lint command for the target
        return [
            .buildCommand(
                displayName: "Linting \(target.name) with SwiftLint",
                executable: swiftlintPath,
                arguments: [
                    "lint",
                    "--path", "\(targetDirectory)"
                ],
                environment: [:]
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Check if swiftlint is installed
        let swiftlintPath: Path
        do {
            swiftlintPath = try context.tool(named: "swiftlint").path
        } catch {
            // Print a warning but don't fail the build
            print("Warning: SwiftLint not found, skipping linting for target: \(target.displayName)")
            return []
        }
        
        // Create the lint command for the target
        return [
            .buildCommand(
                displayName: "Linting \(target.displayName) with SwiftLint",
                executable: swiftlintPath,
                arguments: [
                    "lint",
                    "--path", "\(context.xcodeProject.directory)"
                ],
                environment: [:]
            )
        ]
    }
}
#endif