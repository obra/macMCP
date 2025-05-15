// ABOUTME: This file defines the ElementPath model used for path-based UI element identification.
// ABOUTME: It includes path parsing, generation, and validation logic for UIElement paths.

import Foundation

/// Errors that can occur when working with element paths
public enum ElementPathError: Error, CustomStringConvertible, Equatable {
    /// The path syntax is invalid
    case invalidPathSyntax(String)
    
    /// The path prefix is missing or incorrect (should start with ui://)
    case invalidPathPrefix(String)
    
    /// A segment has an invalid role
    case invalidSegmentRole(String)
    
    /// A segment has an invalid attribute syntax
    case invalidAttributeSyntax(String, atSegment: Int)
    
    /// A segment has an invalid index syntax
    case invalidIndexSyntax(String, atSegment: Int)
    
    /// The path is empty (has no segments)
    case emptyPath
    
    /// An attribute value is invalid
    case invalidAttributeValue(String, forAttribute: String)
    
    /// Error resolving a path segment
    case segmentResolutionFailed(String, atSegment: Int)
    
    /// No elements found matching a segment
    case noMatchingElements(String, atSegment: Int)
    
    /// Multiple elements match without distinguishing information
    case ambiguousMatch(String, matchCount: Int, atSegment: Int)
    
    public var description: String {
        switch self {
        case .invalidPathSyntax(let path):
            return "Invalid path syntax: \(path)"
        case .invalidPathPrefix(let prefix):
            return "Invalid path prefix: \(prefix), should start with ui://"
        case .invalidSegmentRole(let role):
            return "Invalid segment role: \(role)"
        case .invalidAttributeSyntax(let attr, let segmentIndex):
            return "Invalid attribute syntax: \(attr) at segment \(segmentIndex)"
        case .invalidIndexSyntax(let index, let segmentIndex):
            return "Invalid index syntax: \(index) at segment \(segmentIndex)"
        case .emptyPath:
            return "Path is empty - must contain at least one segment"
        case .invalidAttributeValue(let value, let attribute):
            return "Invalid attribute value: \(value) for attribute \(attribute)"
        case .segmentResolutionFailed(let segment, let segmentIndex):
            return "Failed to resolve segment: \(segment) at index \(segmentIndex)"
        case .noMatchingElements(let segment, let segmentIndex):
            return "No elements match segment: \(segment) at index \(segmentIndex)"
        case .ambiguousMatch(let segment, let count, let segmentIndex):
            return "Ambiguous match: \(count) elements match segment \(segment) at index \(segmentIndex)"
        }
    }
    
    public static func == (lhs: ElementPathError, rhs: ElementPathError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyPath, .emptyPath):
            return true
        case (.invalidPathSyntax(let lhsPath), .invalidPathSyntax(let rhsPath)):
            return lhsPath == rhsPath
        case (.invalidPathPrefix(let lhsPrefix), .invalidPathPrefix(let rhsPrefix)):
            return lhsPrefix == rhsPrefix
        case (.invalidSegmentRole(let lhsRole), .invalidSegmentRole(let rhsRole)):
            return lhsRole == rhsRole
        case (.invalidAttributeSyntax(let lhsAttr, let lhsSegment), .invalidAttributeSyntax(let rhsAttr, let rhsSegment)):
            return lhsAttr == rhsAttr && lhsSegment == rhsSegment
        case (.invalidIndexSyntax(let lhsIndex, let lhsSegment), .invalidIndexSyntax(let rhsIndex, let rhsSegment)):
            return lhsIndex == rhsIndex && lhsSegment == rhsSegment
        case (.invalidAttributeValue(let lhsValue, let lhsAttr), .invalidAttributeValue(let rhsValue, let rhsAttr)):
            return lhsValue == rhsValue && lhsAttr == rhsAttr
        case (.segmentResolutionFailed(let lhsSegment, let lhsIndex), .segmentResolutionFailed(let rhsSegment, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsIndex == rhsIndex
        case (.noMatchingElements(let lhsSegment, let lhsIndex), .noMatchingElements(let rhsSegment, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsIndex == rhsIndex
        case (.ambiguousMatch(let lhsSegment, let lhsCount, let lhsIndex), .ambiguousMatch(let rhsSegment, let rhsCount, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsCount == rhsCount && lhsIndex == rhsIndex
        default:
            return false
        }
    }
}

/// A segment in an element path, representing a single level in the hierarchy
public struct PathSegment {
    /// The accessibility role of the element (e.g., "AXButton")
    public let role: String
    
    /// Attribute constraints to filter matching elements
    public let attributes: [String: String]
    
    /// Optional index to select a specific element when multiple match
    public let index: Int?
    
    /// Create a new path segment
    /// - Parameters:
    ///   - role: Accessibility role
    ///   - attributes: Attribute constraints (default is empty)
    ///   - index: Optional index for selecting among multiple matches
    public init(role: String, attributes: [String: String] = [:], index: Int? = nil) {
        self.role = role
        self.attributes = attributes
        self.index = index
    }
    
    /// Generate a string representation of this segment
    /// - Returns: String representation of the path segment
    public func toString() -> String {
        var result = role
        
        // Add attributes if present
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            // Escape quotes in the value
            let escapedValue = value.replacingOccurrences(of: "\"", with: "\\\"")
            result += "[@\(key)=\"\(escapedValue)\"]"
        }
        
        // Add index if present
        if let index = index {
            result += "[\(index)]"
        }
        
        return result
    }
}

/// A path to a UI element in the accessibility hierarchy
public struct ElementPath {
    /// The path ID prefix (ui://)
    public static let pathPrefix = "ui://"
    
    /// Path segments that make up the full path
    public let segments: [PathSegment]
    
    /// Create a new element path with segments
    /// - Parameter segments: Array of path segments
    public init(segments: [PathSegment]) throws {
        guard !segments.isEmpty else {
            throw ElementPathError.emptyPath
        }
        self.segments = segments
    }
    
    /// Parse a path string into an ElementPath
    /// - Parameter pathString: The path string to parse
    /// - Returns: An ElementPath instance
    /// - Throws: ElementPathError if the path syntax is invalid
    public static func parse(_ pathString: String) throws -> ElementPath {
        // Check if the path starts with the expected prefix
        guard pathString.hasPrefix(pathPrefix) else {
            throw ElementPathError.invalidPathPrefix(pathString)
        }
        
        // Remove the prefix
        let pathWithoutPrefix = String(pathString.dropFirst(pathPrefix.count))
        
        // Split the path into segments
        let segmentStrings = pathWithoutPrefix.split(separator: "/")
        
        // Make sure we have at least one segment
        guard !segmentStrings.isEmpty else {
            throw ElementPathError.emptyPath
        }
        
        // Parse each segment
        var segments: [PathSegment] = []
        
        for (i, segmentString) in segmentStrings.enumerated() {
            let segment = try parseSegment(String(segmentString), segmentIndex: i)
            segments.append(segment)
        }
        
        return try ElementPath(segments: segments)
    }
    
    /// Parse a segment string into a PathSegment
    /// - Parameters:
    ///   - segmentString: The segment string to parse
    ///   - segmentIndex: The index of the segment in the path
    /// - Returns: A PathSegment instance
    /// - Throws: ElementPathError if the segment syntax is invalid
    private static func parseSegment(_ segmentString: String, segmentIndex: Int) throws -> PathSegment {
        // Regular expressions for parsing
        let rolePattern = "^([A-Za-z0-9]+)" // Captures the role name
        let attributePattern = "\\[@([^=]+)=\"((?:[^\"]|\\\\\")*)\"\\]" // Captures attribute name and value
        let indexPattern = "\\[(\\d+)\\]$" // Captures the index at the end
        
        // Extract the role
        guard let roleRange = segmentString.range(of: rolePattern, options: .regularExpression) else {
            throw ElementPathError.invalidSegmentRole(segmentString)
        }
        
        let role = String(segmentString[roleRange])
        
        // Extract attributes
        var attributes: [String: String] = [:]
        let attributeRanges = segmentString.ranges(of: attributePattern)
        
        for range in attributeRanges {
            let attributeString = segmentString[range]
            let nameEndIndex = attributeString.firstIndex(of: "=")!
            let nameStartIndex = attributeString.index(attributeString.startIndex, offsetBy: 2) // Skip [@
            let name = String(attributeString[nameStartIndex..<nameEndIndex])
            
            let valueStartIndex = attributeString.index(nameEndIndex, offsetBy: 2) // Skip ="
            let valueEndIndex = attributeString.index(attributeString.endIndex, offsetBy: -2) // Skip "]
            var value = String(attributeString[valueStartIndex..<valueEndIndex])
            
            // Unescape quotes in the value
            value = value.replacingOccurrences(of: "\\\"", with: "\"")
            
            attributes[name] = value
        }
        
        // Extract index if present
        var index: Int? = nil
        if let indexRange = segmentString.range(of: indexPattern, options: .regularExpression) {
            let indexString = segmentString[indexRange]
            let startIndex = indexString.index(after: indexString.startIndex)
            let endIndex = indexString.index(before: indexString.endIndex)
            if let parsedIndex = Int(indexString[startIndex..<endIndex]) {
                index = parsedIndex
            } else {
                throw ElementPathError.invalidIndexSyntax(String(indexString), atSegment: segmentIndex)
            }
        }
        
        return PathSegment(role: role, attributes: attributes, index: index)
    }
    
    /// Generate a path string from this ElementPath
    /// - Returns: String representation of the element path
    public func toString() -> String {
        var result = ElementPath.pathPrefix
        result += segments.map { $0.toString() }.joined(separator: "/")
        return result
    }
    
    /// Create a new ElementPath with a segment appended
    /// - Parameter segment: The segment to append
    /// - Returns: A new ElementPath with the segment appended
    public func appendingSegment(_ segment: PathSegment) throws -> ElementPath {
        var newSegments = segments
        newSegments.append(segment)
        return try ElementPath(segments: newSegments)
    }
    
    /// Create a new ElementPath with segments appended
    /// - Parameter newSegments: The segments to append
    /// - Returns: A new ElementPath with the segments appended
    public func appendingSegments(_ newSegments: [PathSegment]) throws -> ElementPath {
        var segments = self.segments
        segments.append(contentsOf: newSegments)
        return try ElementPath(segments: segments)
    }
    
    /// Check if a string appears to be an element path
    /// - Parameter string: The string to check
    /// - Returns: True if the string looks like an element path
    public static func isElementPath(_ string: String) -> Bool {
        return string.hasPrefix(pathPrefix)
    }
}

extension String {
    /// Find all ranges matching a regular expression
    /// - Parameter pattern: The regular expression pattern
    /// - Returns: Array of ranges matching the pattern
    func ranges(of pattern: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let nsString = self as NSString
        let range = NSRange(location: 0, length: nsString.length)
        let matches = regex.matches(in: self, options: [], range: range)
        
        return matches.map { match in
            let range = match.range
            let startIndex = self.index(self.startIndex, offsetBy: range.location)
            let endIndex = self.index(startIndex, offsetBy: range.length)
            return startIndex..<endIndex
        }
    }
}