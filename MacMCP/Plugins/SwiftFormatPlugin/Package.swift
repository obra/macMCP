// swift-tools-version: 6.1
// ABOUTME: Package.swift for SwiftFormatPlugin
// ABOUTME: Defines a Swift Package Manager plugin for formatting Swift code.

import PackageDescription

let package = Package(
    name: "SwiftFormatPlugin",
    products: [
        .plugin(
            name: "SwiftFormatPlugin",
            targets: ["SwiftFormatPlugin"]
        ),
    ],
    targets: [
        .plugin(
            name: "SwiftFormatPlugin",
            capability: .buildTool(),
            dependencies: [],
            path: "Sources/SwiftFormatPlugin"
        ),
    ]
)