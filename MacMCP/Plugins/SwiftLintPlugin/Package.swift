// swift-tools-version: 6.1
// ABOUTME: Package.swift for SwiftLintPlugin
// ABOUTME: Defines a Swift Package Manager plugin for linting Swift code.

import PackageDescription

let package = Package(
  name: "SwiftLintPlugin",
  products: [
    .plugin(
      name: "SwiftLintPlugin",
      targets: ["SwiftLintPlugin"],
    )
  ],
  targets: [
    .plugin(
      name: "SwiftLintPlugin",
      capability: .buildTool(),
      dependencies: [],
      path: "Sources/SwiftLintPlugin",
    )
  ],
)
