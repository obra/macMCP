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
        .executable(name: "ax-inspector", targets: ["AccessibilityInspector"])
    ],
    dependencies: [
        .package(path: "../swift-sdk"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "MacMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ]),
        .executableTarget(
            name: "AccessibilityInspector",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Tools/AccessibilityInspector"),
        .testTarget(
            name: "MacMCPTests",
            dependencies: ["MacMCP"])
    ]
)
