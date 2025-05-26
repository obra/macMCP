// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MacMCP",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "MacMCP", targets: ["MacMCP"]),
    .executable(name: "ax-inspector", targets: ["AccessibilityInspector"]),
    .executable(name: "mcp-ax-inspector", targets: ["MCPAccessibilityInspector"]),
  ],
  dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk", branch: "main"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(path: "Plugins/SwiftLintPlugin"),
  ],
  targets: [
    // Library target for shared utilities that can be used by all executables
    .target(
      name: "MacMCPUtilities",
      dependencies: [],
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),

    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "MacMCP",
      dependencies: [
        .target(name: "MacMCPUtilities"),
        .product(name: "MCP", package: "swift-sdk"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
      ],
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),
    .executableTarget(
      name: "AccessibilityInspector",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
      ],
      path: "Tools/AccessibilityInspector",
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),
    .executableTarget(
      name: "MCPAccessibilityInspector",
      dependencies: [
        .target(name: "MacMCPUtilities"),
        .target(name: "MacMCP"),
        .product(name: "MCP", package: "swift-sdk"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Logging", package: "swift-log"),
      ],
      path: "Tools/MCPAccessibilityInspector",
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),
    .testTarget(
      name: "TestsWithMocks",
      dependencies: ["MacMCP", "MacMCPUtilities"],
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),
    .testTarget(
      name: "TestsWithoutMocks",
      dependencies: ["MacMCP", "MacMCPUtilities"],
      resources: [
        .copy("TestAssets/ScrollTestContent.txt"),
      ],
      plugins: [
        .plugin(name: "SwiftLintPlugin", package: "SwiftLintPlugin"),
      ],
    ),
    // Original test target removed after migration to TestsWithMocks and TestsWithoutMocks
    // .testTarget(
    //     name: "MacMCPTests",
    //     dependencies: ["MacMCP"],
    //     exclude: ["http-logs"]
    // )
  ],
)
