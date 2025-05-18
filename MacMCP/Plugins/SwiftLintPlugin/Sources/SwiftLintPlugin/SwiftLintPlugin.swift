// ABOUTME: SwiftLintPlugin.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import PackagePlugin

@main
struct SwiftLintPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    // Check if swiftlint is installed
    let swiftlintURL: URL
    do {
      swiftlintURL = try context.tool(named: "swiftlint").url
    } catch {
      // Print a warning but don't fail the build
      print("Warning: SwiftLint not found, skipping linting for target: \(target.name)")
      return []
    }

    // Determine the directory containing the target sources
    let targetDirectoryURL = target.directoryURL

    // Create the lint command for the target
    return [
      .buildCommand(
        displayName: "Linting \(target.name) with SwiftLint",
        executable: swiftlintURL,
        arguments: [
          "lint",
          "--path", targetDirectoryURL.path,
        ],
        environment: [:],
      )
    ]
  }
}

#if canImport(XcodeProjectPlugin)
  import XcodeProjectPlugin

  extension SwiftLintPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
      // Check if swiftlint is installed
      let swiftlintURL: URL
      do {
        swiftlintURL = try context.tool(named: "swiftlint").url
      } catch {
        // Print a warning but don't fail the build
        print("Warning: SwiftLint not found, skipping linting for target: \(target.displayName)")
        return []
      }

      // Create the lint command for the target
      return [
        .buildCommand(
          displayName: "Linting \(target.displayName) with SwiftLint",
          executable: swiftlintURL,
          arguments: [
            "lint",
            "--path", context.xcodeProject.directory.path,
          ],
          environment: [:],
        )
      ]
    }
  }
#endif
