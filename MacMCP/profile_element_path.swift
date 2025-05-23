#!/usr/bin/swift

import Foundation
@testable import MacMCP

// Check how long it takes to parse an element path
let startTime = Date()
let paths = [
    "macos://ui/AXApplication[@AXTitle=\"Calculator\"]",
    "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]",
    "macos://ui/AXApplication[@AXTitle=\"Calculator\"][@bundleId=\"com.apple.calculator\"]",
    "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"][@AXTitle=\"Calculator\"]"
]

do {
    // First parse to get ElementPath class loaded
    _ = try ElementPath.parse(paths[0])
    
    print("Testing element path parsing performance:")
    for (i, path) in paths.enumerated() {
        let parseStart = Date()
        let elementPath = try ElementPath.parse(path)
        let elapsed = Date().timeIntervalSince(parseStart) * 1000
        print("[\(i+1)] Path: \(path)")
        print("    - Parsed in \(elapsed) ms")
        
        // Try resolving the first segment
        if let firstSegment = elementPath.segments.first {
            let truncatedPath = try ElementPath(segments: [firstSegment])
            print("    - Created truncated path with 1 segment")
        }
    }
} catch {
    print("Error: \(error)")
}

print("Total time: \(Date().timeIntervalSince(startTime) * 1000) ms")
