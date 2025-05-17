// ABOUTME: This file defines the ElementPath model used for path-based UI element identification.
// ABOUTME: It includes path parsing, generation, and validation logic for UIElement paths.

import Foundation
@preconcurrency import AppKit
import MacMCPUtilities

/// Errors that can occur when working with element paths
public enum ElementPathError: Error, CustomStringConvertible, Equatable {
    /// The path syntax is invalid
    case invalidPathSyntax(String, details: String)
    
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
    
    /// Enhanced error with detailed information about why resolution failed
    case resolutionFailed(segment: String, index: Int, candidates: [String], reason: String)
    
    /// Application specified in path was not found
    case applicationNotFound(String, details: String)
    
    /// Attribute format is invalid
    case invalidAttributeFormat(String, expectedFormat: String, atSegment: Int)
    
    /// Path is too complex (too many segments, attributes, or depth)
    case pathTooComplex(String, details: String)
    
    /// Path contains potential ambiguity issues
    case potentialAmbiguity(String, details: String, atSegment: Int)
    
    /// Missing essential attribute for reliable resolution
    case missingAttribute(String, suggestedAttribute: String, atSegment: Int)
    
    /// The segment resolution timed out
    case resolutionTimeout(String, atSegment: Int)
    
    /// Accessibility permissions are insufficient for path resolution
    case insufficientPermissions(String, details: String)
    
    /// A suggested validation warning rather than a hard error
    case validationWarning(String, suggestion: String)
    
    public var description: String {
        switch self {
        case .invalidPathSyntax(let path, let details):
            return "Invalid path syntax: \(path)\nDetails: \(details)"
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
        case .resolutionFailed(let segment, let index, let candidates, let reason):
            var details = "Failed to resolve segment: \(segment) at index \(index)\nReason: \(reason)"
            if !candidates.isEmpty {
                details += "\nPossible alternatives:"
                for (i, candidate) in candidates.enumerated() {
                    details += "\n  \(i+1). \(candidate)"
                }
                details += "\nConsider using one of these alternatives or add more specific attributes to your path."
            }
            return details
        case .applicationNotFound(let appIdentifier, let details):
            return "Application not found: \(appIdentifier). \(details)"
        case .invalidAttributeFormat(let attribute, let expectedFormat, let segmentIndex):
            return "Invalid attribute format: \(attribute) at segment \(segmentIndex). Expected format: \(expectedFormat)"
        case .pathTooComplex(let path, let details):
            return "Path is too complex: \(path).\nDetails: \(details)"
        case .potentialAmbiguity(let segment, let details, let segmentIndex):
            return "Potential ambiguity in segment \(segmentIndex): \(segment).\nDetails: \(details)\nConsider adding more specific attributes or an index."
        case .missingAttribute(let segment, let suggestedAttribute, let segmentIndex):
            return "Missing essential attribute in segment \(segmentIndex): \(segment).\nConsider adding \(suggestedAttribute) for more reliable resolution."
        case .resolutionTimeout(let segment, let segmentIndex):
            return "Resolution timeout for segment \(segmentIndex): \(segment).\nThe UI hierarchy might be too deep or complex."
        case .insufficientPermissions(let feature, let details):
            return "Insufficient accessibility permissions for: \(feature).\n\(details)"
        case .validationWarning(let message, let suggestion):
            return "Warning: \(message).\nSuggestion: \(suggestion)"
        }
    }
    
    public static func == (lhs: ElementPathError, rhs: ElementPathError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyPath, .emptyPath):
            return true
        case (.invalidPathSyntax(let lhsPath, let lhsDetails), .invalidPathSyntax(let rhsPath, let rhsDetails)):
            return lhsPath == rhsPath && lhsDetails == rhsDetails
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
        case (.resolutionFailed(let lhsSegment, let lhsIndex, let lhsCandidates, let lhsReason),
              .resolutionFailed(let rhsSegment, let rhsIndex, let rhsCandidates, let rhsReason)):
            return lhsSegment == rhsSegment && lhsIndex == rhsIndex && lhsCandidates == rhsCandidates && lhsReason == rhsReason
        case (.applicationNotFound(let lhsApp, let lhsDetails), .applicationNotFound(let rhsApp, let rhsDetails)):
            return lhsApp == rhsApp && lhsDetails == rhsDetails
        case (.invalidAttributeFormat(let lhsAttr, let lhsFormat, let lhsIndex),
              .invalidAttributeFormat(let rhsAttr, let rhsFormat, let rhsIndex)):
            return lhsAttr == rhsAttr && lhsFormat == rhsFormat && lhsIndex == rhsIndex
        case (.pathTooComplex(let lhsPath, let lhsDetails), .pathTooComplex(let rhsPath, let rhsDetails)):
            return lhsPath == rhsPath && lhsDetails == rhsDetails
        case (.potentialAmbiguity(let lhsSegment, let lhsDetails, let lhsIndex),
              .potentialAmbiguity(let rhsSegment, let rhsDetails, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsDetails == rhsDetails && lhsIndex == rhsIndex
        case (.missingAttribute(let lhsSegment, let lhsAttr, let lhsIndex),
              .missingAttribute(let rhsSegment, let rhsAttr, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsAttr == rhsAttr && lhsIndex == rhsIndex
        case (.resolutionTimeout(let lhsSegment, let lhsIndex), .resolutionTimeout(let rhsSegment, let rhsIndex)):
            return lhsSegment == rhsSegment && lhsIndex == rhsIndex
        case (.insufficientPermissions(let lhsFeature, let lhsDetails),
              .insufficientPermissions(let rhsFeature, let rhsDetails)):
            return lhsFeature == rhsFeature && lhsDetails == rhsDetails
        case (.validationWarning(let lhsMessage, let lhsSuggestion),
              .validationWarning(let rhsMessage, let rhsSuggestion)):
            return lhsMessage == rhsMessage && lhsSuggestion == rhsSuggestion
        default:
            return false
        }
    }
}

/// A segment in an element path, representing a single level in the hierarchy
public struct PathSegment: Sendable {
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
public struct ElementPath: Sendable {
    /// Path node to track traversal progress during breadth-first search
    private struct PathNode: Sendable {
        /// The UI element being traversed
        let element: AXUIElement
        
        /// Current segment index in the path segments array
        let segmentIndex: Int
        
        /// Path from root to this node for debugging
        let pathSoFar: String
    }
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
        let indexPattern = "\\[(\\d+)\\]" // Captures the index (could be anywhere in the segment)
        
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
    
    /// Resolve this path to a UI element in the accessibility hierarchy
    /// - Parameter accessibilityService: The AccessibilityService to use for accessing the accessibility API
    /// - Returns: The AXUIElement that matches this path, or nil if no match is found
    /// - Throws: ElementPathError if there's an error resolving the path
    public func resolve(using accessibilityService: AccessibilityServiceProtocol) async throws -> AXUIElement {
        // Get the application element as starting point
        let startElement = try await getApplicationElement(accessibilityService)
        
        // Skip the first segment if it's an application (we've already matched it)
        let skipFirstSegment = segments[0].role == "AXApplication"
        let startSegmentIndex = skipFirstSegment ? 1 : 0
        
        // For simple cases (only the application), return immediately
        if segments.count == 1 || (skipFirstSegment && segments.count == 2) {
            return startElement
        }
        
        // Use BFS for path resolution
        return try await resolveBFS(startElement: startElement, startIndex: startSegmentIndex)
    }
    
    /// Get the application element that serves as the starting point for path resolution
    /// - Parameter accessibilityService: The accessibility service to use
    /// - Returns: The application element to start path traversal from
    /// - Throws: ElementPathError if the application cannot be found or accessed
    private func getApplicationElement(_ accessibilityService: AccessibilityServiceProtocol) async throws -> AXUIElement {
        // First segment should be the application or window element
        let firstSegment = segments[0]
        
        // For first segment, we need to get it differently depending on the role
        if firstSegment.role == "AXApplication" {
            // Try different approaches to find the application element
            
            // 1. Try by bundleIdentifier if provided
            if let bundleId = firstSegment.attributes["bundleIdentifier"] {
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                
                guard let app = apps.first else {
                    // Get a list of running applications for better error messages
                    let runningApps = NSWorkspace.shared.runningApplications
                    var runningAppDetails: [String] = []
                    
                    for (i, app) in runningApps.prefix(10).enumerated() {
                        var appInfo = "\(i+1). "
                        if let name = app.localizedName {
                            appInfo += "\(name)"
                        } else {
                            appInfo += "Unknown"
                        }
                        if let bundleId = app.bundleIdentifier {
                            appInfo += " (bundleIdentifier: \(bundleId))"
                        }
                        runningAppDetails.append(appInfo)
                    }
                    
                    if runningApps.count > 10 {
                        runningAppDetails.append("...and \(runningApps.count - 10) more applications")
                    }
                    
                    throw ElementPathError.applicationNotFound(
                        bundleId,
                        details: "Application with bundleIdentifier '\(bundleId)' is not running. Running applications are:\n" +
                                runningAppDetails.joined(separator: "\n")
                    )
                }
                
                return AXUIElementCreateApplication(app.processIdentifier)
            }
            // 2. Try by title/name if provided
            else if let title = firstSegment.attributes["title"] {
                // Get all running applications
                let runningApps = NSWorkspace.shared.runningApplications
                
                // Find application with matching title
                if let app = runningApps.first(where: { 
                    $0.localizedName == title || $0.localizedName?.contains(title) == true 
                }) {
                    return AXUIElementCreateApplication(app.processIdentifier)
                } else {
                    // No exact match, gather information about running apps
                    var runningAppDetails: [String] = []
                    
                    for (i, app) in runningApps.prefix(10).enumerated() {
                        var appInfo = "\(i+1). "
                        if let name = app.localizedName {
                            appInfo += "\(name)"
                        } else {
                            appInfo += "Unknown"
                        }
                        if let bundleId = app.bundleIdentifier {
                            appInfo += " (bundleIdentifier: \(bundleId))"
                        }
                        runningAppDetails.append(appInfo)
                    }
                    
                    if runningApps.count > 10 {
                        runningAppDetails.append("...and \(runningApps.count - 10) more applications")
                    }
                    
                    throw ElementPathError.applicationNotFound(
                        title,
                        details: "Application with title '\(title)' not found. Running applications are:\n" +
                                runningAppDetails.joined(separator: "\n")
                    )
                }
            }
            // 3. Use focused application as fallback
            else {
                do {
                    // Get the focused application from the accessibility service
                    let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(recursive: false, maxDepth: 1)
                    
                    // Check if we got a valid element
                    guard let axElement = focusedElement.axElement else {
                        throw ElementPathError.segmentResolutionFailed("Could not get focused application element", atSegment: 0)
                    }
                    
                    return axElement
                } catch {
                    // If that fails, try to get the frontmost application using NSWorkspace
                    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                        throw ElementPathError.segmentResolutionFailed("Could not determine frontmost application", atSegment: 0)
                    }
                    
                    return AXUIElementCreateApplication(frontApp.processIdentifier)
                }
            }
        } 
        // For system-wide operations or other special starting points
        else if firstSegment.role == "AXSystemWide" {
            return AXUIElementCreateSystemWide()
        }
        // For any other element type as the first segment
        else {
            // Get the system-wide element as starting point for a broader search
            return AXUIElementCreateSystemWide()
        }
    }
    
    /// Helper method to get child elements of a given element
    /// - Parameter element: The element to get children for
    /// - Returns: Array of child elements, or nil if children couldn't be accessed
    private func getChildElements(of element: AXUIElement) -> [AXUIElement]? {
        var childrenRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        
        // Skip if we couldn't get children
        if status != .success || childrenRef == nil {
            return nil
        }
        
        // Convert to array of elements
        guard let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        
        return children
    }
    
    /// Resolves a path using breadth-first search to handle ambiguities
    /// - Parameters:
    ///   - startElement: The element to start the search from
    ///   - startIndex: The segment index to start from
    /// - Returns: The matched element at the end of the path
    /// - Throws: ElementPathError if no matching element is found
    private func resolveBFS(startElement: AXUIElement, startIndex: Int, maxDepth: Int = 50) async throws -> AXUIElement {
        // Create a queue for BFS
        var queue = [PathNode(element: startElement, 
                             segmentIndex: startIndex, 
                             pathSoFar: segments[0].toString())]
        
        // Set to track visited elements and avoid cycles
        var visited = Set<UInt>()
        
        // Track which segment is failing for better error reporting
        var failedSegmentIndex = startIndex
        
        // Add depth tracking
        var depth = 0
        
        // Breadth-first search loop
        while !queue.isEmpty && depth < maxDepth {
            // Track depth for timeout detection
            depth += 1
            // Dequeue the next node to process
            let node = queue.removeFirst()
            
            // Track visited nodes by memory address to avoid cycles
            let elementID = UInt(bitPattern: Unmanaged.passUnretained(node.element).toOpaque())
            if visited.contains(elementID) {
                continue
            }
            visited.insert(elementID)
            
            // Check if we've reached the end of the path
            if node.segmentIndex >= segments.count {
                return node.element
            }
            
            // Get the current segment we're trying to match
            let currentSegment = segments[node.segmentIndex]
            
            // Update the failed segment index to the deepest segment we've tried
            failedSegmentIndex = max(failedSegmentIndex, node.segmentIndex)
            
            // Get children of the current element to explore
            guard let children = getChildElements(of: node.element) else {
                continue
            }
            
            // Filter children by those matching the current segment
            for child in children {
                if try await elementMatchesSegment(child, segment: currentSegment) {
                    // Create path to this point for debugging
                    let newPath = node.pathSoFar + "/" + currentSegment.toString()
                    
                    // If this is the last segment, we've found our match
                    if node.segmentIndex == segments.count - 1 {
                        return child
                    }
                    
                    // Otherwise, add child to queue with next segment index
                    queue.append(PathNode(
                        element: child,
                        segmentIndex: node.segmentIndex + 1,
                        pathSoFar: newPath
                    ))
                }
            }
        }
        
        // Check if we hit max depth
        if depth >= maxDepth {
            throw ElementPathError.resolutionTimeout(
                "Path resolution exceeded maximum depth (\(maxDepth))",
                atSegment: failedSegmentIndex
            )
        }
        
        // If we've explored all possibilities and found no match, throw an error with the correct segment index
        throw ElementPathError.segmentResolutionFailed(
            "Could not find elements matching segment: \(segments[failedSegmentIndex].toString())",
            atSegment: failedSegmentIndex
        )
    }
    
    /// Resolve a single segment of a path starting from a given element
    /// - Parameters:
    ///   - element: The starting element
    ///   - segment: The path segment to resolve
    ///   - segmentIndex: The index of the segment in the overall path (for error reporting)
    /// - Returns: The resolved element matching the segment, or nil if no match is found
    /// - Throws: ElementPathError if there's an error resolving the segment
    public func resolveSegment(element: AXUIElement, segment: PathSegment, segmentIndex: Int) async throws -> AXUIElement? {
        // print("DEBUG: Resolving segment \(segmentIndex): \(segment.toString())")
        
        // Get information about the current element
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        if roleStatus == .success, let role = roleRef as? String {
            // print("DEBUG: Current element role: \(role)")
            
            // Get title if available
            var titleRef: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &titleRef)
            if titleStatus == .success, let title = titleRef as? String {
              //  print("DEBUG: Current element title: \(title)")
            }
        }
        
        // Get the children of the current element
        var childrenRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        
        // print("DEBUG: AXUIElementCopyAttributeValue status for AXChildren: \(status.rawValue)")
        
        // Check if we could get children
        if status != .success || childrenRef == nil {
            // print("DEBUG: Failed to get children - status: \(status.rawValue), childrenRef: \(String(describing: childrenRef))")
            
            // If this is the first segment (application), allow the element itself to match
            if segmentIndex == 0 {
                // Check if this element itself matches the segment
                if try await elementMatchesSegment(element, segment: segment) {
                    // print("DEBUG: First segment matches element itself")
                    return element
                }
            }
            
            let segmentString = segment.toString()
            throw ElementPathError.segmentResolutionFailed("Could not get children for segment: \(segmentString)", atSegment: segmentIndex)
        }
        
        // Cast to array of elements
        guard let children = childrenRef as? [AXUIElement] else {
            // print("DEBUG: Failed to cast children to [AXUIElement] - type: \(type(of: childrenRef))")
            let segmentString = segment.toString()
            throw ElementPathError.segmentResolutionFailed("Children not in expected format for segment: \(segmentString)", atSegment: segmentIndex)
        }
        
        // print("DEBUG: Found \(children.count) children of current element")
        
        // Log child roles to help with debugging
        // print("DEBUG: Child roles:")
        for (i, child) in children.enumerated() {
            var childRoleRef: CFTypeRef?
            let childRoleStatus = AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &childRoleRef)
            if childRoleStatus == .success, let childRole = childRoleRef as? String {
                // print("DEBUG:   [\(i)] \(childRole)")
                
                // If the child matches our target segment role, check title too
                if childRole == segment.role {
                    var childTitleRef: CFTypeRef?
                    let childTitleStatus = AXUIElementCopyAttributeValue(child, "AXTitle" as CFString, &childTitleRef)
                    if childTitleStatus == .success, let _ = childTitleRef as? String {
                        // print("DEBUG:     Title: \(childTitle)")
                    }
                }
            } else {
                 // print("DEBUG:   [\(i)] Unknown role, status: \(childRoleStatus.rawValue)")
            }
        }
        
        // Filter children by role to find potential matches
        var matches: [AXUIElement] = []
        
        for child in children {
            // Check if this child matches the segment
            if try await elementMatchesSegment(child, segment: segment) {
                matches.append(child)
            }
        }
        
        // print("DEBUG: Found \(matches.count) matches for segment \(segment.toString())")
        
        // Special case for when the parent element itself matches
        if segmentIndex == 0 && matches.isEmpty {
            // Check if the root element matches
            if try await elementMatchesSegment(element, segment: segment) {
                // print("DEBUG: Root element matches first segment")
                return element
            }
        }
        
        // Handle based on number of matches and whether an index was specified
        if matches.isEmpty {
            // print("DEBUG: No matches found for segment")
            
            // Gather information about available children for better diagnostics
            var availableChildren: [String] = []
            for (i, child) in children.prefix(5).enumerated() {
                var childInfo = "Child \(i) (role: "
                
                // Get the role
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &roleRef)
                if let role = roleRef as? String {
                    childInfo += role
                } else {
                    childInfo += "unknown"
                }
                
                // Try to get identifiable attributes
                for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                    var attrRef: CFTypeRef?
                    let status = AXUIElementCopyAttributeValue(child, attr as CFString, &attrRef)
                    if status == .success, let value = attrRef as? String, !value.isEmpty {
                        childInfo += ", \(attr): \"\(value)\""
                    }
                }
                
                childInfo += ")"
                availableChildren.append(childInfo)
            }
            
            // If there are more children than we showed, indicate that
            if children.count > 5 {
                availableChildren.append("...and \(children.count - 5) more children")
            }
            
            // If no children are found, indicate that
            if availableChildren.isEmpty {
                availableChildren.append("No children found in this element.")
            }
            
            let segmentString = segment.toString()
            throw ElementPathError.resolutionFailed(
                segment: segmentString,
                index: segmentIndex,
                candidates: availableChildren,
                reason: "No elements match this segment. Available children are shown below."
            )
        } else if matches.count == 1 || segment.index != nil {
            // Single match or specific index requested
            
            // If an index was specified, use it to select from matches
            if let index = segment.index {
                // Make sure the index is valid
                if index < 0 || index >= matches.count {
                    let segmentString = segment.toString()
                    // print("DEBUG: Index out of range: \(index) for matches.count: \(matches.count)")
                    throw ElementPathError.segmentResolutionFailed("Index out of range: \(index) for segment: \(segmentString)", atSegment: segmentIndex)
                }
                
                // print("DEBUG: Returning match at specified index \(index)")
                return matches[index]
            }
            
            // Otherwise return the single match
            // print("DEBUG: Returning single match")
            return matches[0]
        } else {
            // Multiple matches and no index specified - this is ambiguous
            let segmentString = segment.toString()
            // print("DEBUG: Ambiguous match - \(matches.count) elements match segment")
            
            // Gather information about the ambiguous matches to help with diagnostics
            var matchCandidates: [String] = []
            for (i, match) in matches.prefix(5).enumerated() {
                var description = "Element \(i) (role: "
                
                // Get the role
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(match, "AXRole" as CFString, &roleRef)
                if let role = roleRef as? String {
                    description += role
                } else {
                    description += "unknown"
                }
                
                // Try to get identifiable attributes
                for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                    var attrRef: CFTypeRef?
                    let status = AXUIElementCopyAttributeValue(match, attr as CFString, &attrRef)
                    if status == .success, let value = attrRef as? String, !value.isEmpty {
                        description += ", \(attr): \"\(value)\""
                    }
                }
                
                description += ")"
                matchCandidates.append(description)
            }
            
            // If there are more matches than we showed, indicate that
            if matches.count > 5 {
                matchCandidates.append("...and \(matches.count - 5) more matches")
            }
            
            // Throw enhanced error with candidate information
            throw ElementPathError.resolutionFailed(
                segment: segmentString,
                index: segmentIndex,
                candidates: matchCandidates,
                reason: "Multiple elements (\(matches.count)) match this segment. Add more specific attributes or use an index."
            )
        }
    }
    
    /// Check if an element matches a path segment
    /// - Parameters:
    ///   - element: The element to check
    ///   - segment: The path segment to match against
    /// - Returns: True if the element matches the segment
    private func elementMatchesSegment(_ element: AXUIElement, segment: PathSegment) async throws -> Bool {
        // Check role first - this is the primary type matcher
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        
        if roleStatus != .success || roleRef == nil {
            return false
        }
        
        guard let role = roleRef as? String else {
            return false
        }
        
        // Check role match - be more tolerant with role matching (optionally strip 'AX' prefix)
        let normalizedSegmentRole = segment.role.hasPrefix("AX") ? segment.role : "AX\(segment.role)"
        let normalizedElementRole = role.hasPrefix("AX") ? role : "AX\(role)"
        
        if role != segment.role && normalizedElementRole != normalizedSegmentRole {
            return false
        }
        
        // If there are no attributes to match, we're done
        if segment.attributes.isEmpty {
            return true
        }
        
        // Check each attribute - ALL must match for a successful match
        for (name, expectedValue) in segment.attributes {
            // Try attribute name variants
            var attributeMatched = false
            
            // Try all variants of the attribute name
            for attributeName in getAttributeVariants(name) {
                if attributeMatchesValue(element, name: attributeName, expectedValue: expectedValue) {
                    attributeMatched = true
                    break
                }
            }
            
            // If attribute didn't match, this element doesn't match
            if !attributeMatched {
                return false
            }
        }
        
        // All checks passed
        return true
    }
    
    /// Get the variants of an attribute name to try when matching
    /// - Parameter attributeName: The original attribute name
    /// - Returns: An array of attribute name variants to try
    private func getAttributeVariants(_ attributeName: String) -> [String] {
        // Standard cases handled by the normalizer
        let normalizedName = PathNormalizer.normalizeAttributeName(attributeName)
        var variants = [normalizedName]
        
        // Add original name if different from normalized
        if normalizedName != attributeName {
            variants.append(attributeName)
        }
        
        // Add common fallbacks based on attribute type
        switch normalizedName {
        case "AXTitle":
            variants.append(contentsOf: ["AXValue", "AXHelp", "AXDescription", "AXLabel"])
            
        case "AXDescription":
            variants.append(contentsOf: ["AXHelp", "AXValue", "AXLabel"])
            
        case "AXValue":
            variants.append(contentsOf: ["AXTitle", "AXDescription", "AXLabel"])
            
        case "AXIdentifier":
            variants.append(contentsOf: ["AXIdentifier", "id", "identifier", "AXDOMIdentifier"]) 
            
        case "AXLabel":
            variants.append(contentsOf: ["AXDescription", "AXHelp", "AXTitle"])
            
        default:
            // For attributes without special handling, try both with and without AX prefix
            if normalizedName.hasPrefix("AX") {
                // Add non-prefixed variant
                let nonPrefixed = String(normalizedName.dropFirst(2))
                variants.append(nonPrefixed.prefix(1).lowercased() + nonPrefixed.dropFirst())
            } else {
                // Add prefixed variant
                variants.append("AX" + normalizedName.prefix(1).uppercased() + normalizedName.dropFirst())
            }
        }
        
        return variants
    }
    
    /// Match an attribute value against an expected value with boolean matching
    /// - Parameters:
    ///   - element: The AXUIElement to check
    ///   - name: The attribute name
    ///   - expectedValue: The expected attribute value
    /// - Returns: True if the attribute matches the expected value
    private func attributeMatchesValue(_ element: AXUIElement, name: String, expectedValue: String) -> Bool {
        // Get the attribute value
        var attributeRef: CFTypeRef?
        let attributeStatus = AXUIElementCopyAttributeValue(element, name as CFString, &attributeRef)
        
        // If we couldn't get the attribute, it doesn't match
        if attributeStatus != .success || attributeRef == nil {
            return false
        }
        
        // Convert attribute value to string for comparison
        let actualValue: String
        
        if let stringValue = attributeRef as? String {
            actualValue = stringValue
        } else if let numberValue = attributeRef as? NSNumber {
            actualValue = numberValue.stringValue
        } else if let boolValue = attributeRef as? Bool {
            actualValue = boolValue ? "true" : "false"
        } else {
            actualValue = String(describing: attributeRef!)
        }
        
        // Empty check - if either value is empty, handle specially
        if actualValue.isEmpty || expectedValue.isEmpty {
            return actualValue.isEmpty && expectedValue.isEmpty
        }
        
        // Check for exact match first
        if actualValue == expectedValue {
            return true
        }
        
        // Then case-insensitive match
        if actualValue.localizedCaseInsensitiveCompare(expectedValue) == .orderedSame {
            return true
        }
        
        // Then check contains relationships
        if actualValue.localizedCaseInsensitiveContains(expectedValue) || 
           expectedValue.localizedCaseInsensitiveContains(actualValue) {
            return true
        }
        
        // No match
        return false
    }
    
}

extension ElementPath {
    /// Validates an element path string to check for common issues and syntax errors
    /// - Parameters:
    ///   - pathString: The path string to validate
    ///   - strict: Whether to use strict validation (more checks)
    /// - Returns: A tuple containing a boolean indicating success and an array of validation warnings
    /// - Throws: ElementPathError if validation fails
    public static func validatePath(_ pathString: String, strict: Bool = false) throws -> (isValid: Bool, warnings: [ElementPathError]) {
        var warnings: [ElementPathError] = []
        
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
        
        // Check for path complexity
        if segmentStrings.count > 15 && strict {
            warnings.append(ElementPathError.validationWarning(
                "Path has \(segmentStrings.count) segments, which might be excessive",
                suggestion: "Consider using a shorter path if possible"
            ))
        }
        
        // Validate each segment
        for (i, segmentString) in segmentStrings.enumerated() {
            // First, try to parse the segment to validate syntax
            do {
                let segment = try parseSegment(String(segmentString), segmentIndex: i)
                
                // Check for segment-specific warnings
                warnings.append(contentsOf: validateSegment(segment, index: i, strict: strict))
            } catch let error as ElementPathError {
                throw error  // Re-throw any parsing errors
            } catch {
                throw ElementPathError.invalidPathSyntax(String(segmentString), details: "Unknown error parsing segment at index \(i)")
            }
        }
        
        // Validate first segment (should typically be AXApplication)
        let firstSegmentString = segmentStrings[0]
        do {
            let firstSegment = try parseSegment(String(firstSegmentString), segmentIndex: 0)
            
            if strict {
                if firstSegment.role != "AXApplication" && firstSegment.role != "AXSystemWide" {
                    warnings.append(ElementPathError.validationWarning(
                        "First segment role is '\(firstSegment.role)' rather than 'AXApplication' or 'AXSystemWide'",
                        suggestion: "Paths typically start with AXApplication for targeting specific applications"
                    ))
                }
                
                if firstSegment.role == "AXApplication" {
                    // Check if bundleIdentifier or title is provided for the application
                    let hasBundleId = firstSegment.attributes["bundleIdentifier"] != nil
                    let hasTitle = firstSegment.attributes["title"] != nil || firstSegment.attributes["AXTitle"] != nil
                    
                    if !hasBundleId && !hasTitle {
                        warnings.append(ElementPathError.missingAttribute(
                            String(firstSegmentString),
                            suggestedAttribute: "bundleIdentifier or title",
                            atSegment: 0
                        ))
                    }
                }
            }
        } catch {
            // Error already thrown in the general segment validation
        }
        
        // Check for ambiguity issues across the path
        checkForAmbiguityIssues(segmentStrings, warnings: &warnings, strict: strict)
        
        return (true, warnings)
    }
    
    /// Validates a single path segment and returns any warnings
    /// - Parameters:
    ///   - segment: The segment to validate
    ///   - index: The index of the segment in the path
    ///   - strict: Whether to use strict validation
    /// - Returns: Array of validation warnings
    private static func validateSegment(_ segment: PathSegment, index: Int, strict: Bool) -> [ElementPathError] {
        var warnings: [ElementPathError] = []
        
        // Check for common role validation issues
        if segment.role.isEmpty {
            warnings.append(ElementPathError.validationWarning(
                "Empty role in segment at index \(index)",
                suggestion: "Specify a valid accessibility role like 'AXButton', 'AXTextField', etc."
            ))
        }
        
        // Role should typically start with AX for standard elements
        if !segment.role.hasPrefix("AX") && strict {
            warnings.append(ElementPathError.validationWarning(
                "Role '\(segment.role)' doesn't have the standard 'AX' prefix",
                suggestion: "Consider using standard accessibility roles like 'AXButton', 'AXTextField', etc."
            ))
        }
        
        // Check for empty attributes or invalid formats
        for (key, value) in segment.attributes {
            if value.isEmpty && strict {
                warnings.append(ElementPathError.validationWarning(
                    "Empty value for attribute '\(key)' in segment at index \(index)",
                    suggestion: "Consider removing the empty attribute or providing a meaningful value"
                ))
            }
            
            // Validate attribute name
            if key.isEmpty {
                warnings.append(ElementPathError.validationWarning(
                    "Empty attribute name in segment at index \(index)",
                    suggestion: "Specify a valid attribute name"
                ))
            }
        }
        
        // If it's a common UI element, check if it has the right attributes for reliable identification
        if index > 0 && segment.attributes.isEmpty && segment.index == nil && strict {
            switch segment.role {
            case "AXButton", "AXMenuItem", "AXRadioButton", "AXCheckBox":
                warnings.append(ElementPathError.missingAttribute(
                    segment.toString(),
                    suggestedAttribute: "AXTitle or AXDescription",
                    atSegment: index
                ))
                
            case "AXTextField", "AXTextArea":
                warnings.append(ElementPathError.missingAttribute(
                    segment.toString(),
                    suggestedAttribute: "AXPlaceholderValue or AXIdentifier",
                    atSegment: index
                ))
                
            case "AXTable", "AXGrid", "AXList", "AXOutline":
                warnings.append(ElementPathError.missingAttribute(
                    segment.toString(),
                    suggestedAttribute: "AXIdentifier",
                    atSegment: index
                ))
                
            default:
                break
            }
        }
        
        return warnings
    }
    
    /// Checks for potential ambiguity issues in the path
    /// - Parameters:
    ///   - segmentStrings: The string segments of the path
    ///   - warnings: The array of warnings to append to
    ///   - strict: Whether to use strict validation
    private static func checkForAmbiguityIssues(_ segmentStrings: [Substring], warnings: inout [ElementPathError], strict: Bool) {
        // Count segments with the same role in sequence
        var consecutiveSegments: [String: Int] = [:]
        var previousRole = ""
        
        for (i, segmentString) in segmentStrings.enumerated() {
            do {
                let segment = try parseSegment(String(segmentString), segmentIndex: i)
                
                if segment.role == previousRole {
                    consecutiveSegments[segment.role, default: 1] += 1
                    
                    // If we have multiple segments with the same role in a row and no index is specified, warn about ambiguity
                    if consecutiveSegments[segment.role, default: 1] > 1 && segment.index == nil && strict {
                        warnings.append(ElementPathError.potentialAmbiguity(
                            segment.toString(),
                            details: "Multiple consecutive '\(segment.role)' segments without index specification",
                            atSegment: i
                        ))
                    }
                } else {
                    consecutiveSegments[segment.role] = 1
                    previousRole = segment.role
                }
                
                // Warn about common generic roles without sufficient disambiguation
                if ["AXGroup", "AXBox", "AXGeneric"].contains(segment.role) && segment.attributes.isEmpty && segment.index == nil && strict {
                    warnings.append(ElementPathError.potentialAmbiguity(
                        segment.toString(),
                        details: "Generic role '\(segment.role)' without attributes or index may match multiple elements",
                        atSegment: i
                    ))
                }
            } catch {
                // Skip segments that couldn't be parsed - they'll have errors thrown elsewhere
            }
        }
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
    
    /// Creates a new string by repeating this string a specified number of times
    /// - Parameter count: The number of times to repeat the string
    /// - Returns: A new string containing the original string repeated count times
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

extension ElementPath {
    /// Diagnoses issues with a path resolution and provides detailed troubleshooting information
    /// - Parameters:
    ///   - pathString: The path string to diagnose
    ///   - accessibilityService: The accessibility service to use for resolution attempts
    /// - Returns: A diagnostic report with details about the issue and suggested solutions
    /// - Throws: ElementPathError if there's a critical error during diagnosis
    public static func diagnosePathResolutionIssue(_ pathString: String, using accessibilityService: AccessibilityServiceProtocol) async throws -> String {
        // Start with path validation
        var diagnosis = "Path Resolution Diagnosis for: \(pathString)\n"
        diagnosis += "=".repeating(80) + "\n\n"
        
        // Validate path syntax
        do {
            let (_, warnings) = try validatePath(pathString, strict: true)
            
            if !warnings.isEmpty {
                diagnosis += "VALIDATION WARNINGS:\n"
                for (i, warning) in warnings.enumerated() {
                    diagnosis += "  \(i+1). \(warning.description)\n"
                }
                diagnosis += "\n"
            } else {
                diagnosis += "Path syntax validation: ✅ No syntax warnings\n\n"
            }
        } catch let error as ElementPathError {
            diagnosis += "SYNTAX ERROR: \(error.description)\n"
            diagnosis += "Fix the syntax error before continuing with resolution.\n\n"
            return diagnosis
        } catch {
            diagnosis += "UNKNOWN ERROR: \(error.localizedDescription)\n\n"
            return diagnosis
        }
        
        // Parse the path
        let path = try parse(pathString)
        
        // Try to resolve each segment in sequence and report where it fails
        var currentElement: AXUIElement?
        
        // Start with the application element
        do {
            currentElement = try await path.getApplicationElement(accessibilityService)
            diagnosis += "✅ Successfully resolved application element\n\n"
        } catch let error as ElementPathError {
            diagnosis += "❌ Failed to resolve application element: \(error.description)\n"
            return diagnosis
        } catch {
            diagnosis += "❌ Unexpected error resolving application element: \(error.localizedDescription)\n"
            return diagnosis
        }
        
        // Now try each segment in sequence
        for (i, segment) in path.segments.enumerated().dropFirst() { // Skip first segment (app)
            diagnosis += "Segment \(i): \(segment.toString())\n"
            
            guard let element = currentElement else {
                diagnosis += "❌ No element to continue from\n\n"
                break
            }
            
            // Get children
            guard let children = path.getChildElements(of: element) else {
                diagnosis += "❌ Couldn't get children of current element\n\n"
                break
            }
            
            // Find matching children
            var matchingChildren: [AXUIElement] = []
            for child in children {
                if try await path.elementMatchesSegment(child, segment: segment) {
                    matchingChildren.append(child)
                }
            }
            
            if matchingChildren.isEmpty {
                diagnosis += "❌ No children match this segment\n"
                
                // List available children to help debugging
                diagnosis += "Available children (sample):\n"
                for (j, child) in children.prefix(5).enumerated() {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &roleRef)
                    let role = roleRef as? String ?? "unknown"
                    
                    // Show more information about each child to help with troubleshooting
                    diagnosis += "  Child \(j): role=\(role)"
                    
                    // Add key attributes to help with diagnosis
                    for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                        var attrRef: CFTypeRef?
                        let status = AXUIElementCopyAttributeValue(child, attr as CFString, &attrRef)
                        if status == .success, let value = attrRef as? String, !value.isEmpty {
                            diagnosis += ", \(attr)=\"\(value)\""
                        }
                    }
                    diagnosis += "\n"
                    
                    // Check what attributes would have been needed for a match
                    if role == segment.role {
                        diagnosis += "    ⚠️ This child has the right role but didn't match other criteria\n"
                        // For each attribute in the segment, check if the child has a matching value
                        for (attrName, expectedValue) in segment.attributes {
                            var hasMatch = false
                            // Check all attribute variants
                            for variantName in path.getAttributeVariants(attrName) {
                                var attrRef: CFTypeRef?
                                let status = AXUIElementCopyAttributeValue(child, variantName as CFString, &attrRef)
                                if status == .success, let actualValue = convertAttributeToString(attrRef) {
                                    diagnosis += "    - Attribute \(variantName): actual=\"\(actualValue)\", expected=\"\(expectedValue)\" "
                                    if path.attributeMatchesValue(child, name: variantName, expectedValue: expectedValue) {
                                        diagnosis += "✅ MATCH\n"
                                        hasMatch = true
                                        break
                                    } else {
                                        diagnosis += "❌ NO MATCH\n"
                                    }
                                }
                            }
                            if !hasMatch {
                                diagnosis += "    - Attribute \(attrName): ❌ NOT FOUND on this element\n"
                            }
                        }
                    }
                }
                
                if children.count > 5 {
                    diagnosis += "  ...and \(children.count - 5) more children\n"
                }
                
                diagnosis += "\n"
                diagnosis += "Possible solutions:\n"
                diagnosis += "  1. Check if the role is correct (case-sensitive: \(segment.role))\n"
                diagnosis += "  2. Verify attribute names and values match exactly\n"
                diagnosis += "  3. Consider using the mcp-ax-inspector tool to see the exact element structure\n"
                diagnosis += "  4. Try simplifying the path or using an index if there are many similar elements\n\n"
                break
            } else if matchingChildren.count > 1 {
                diagnosis += "⚠️ Multiple children (\(matchingChildren.count)) match this segment\n"
                diagnosis += "Matching children details:\n"
                
                // Show detailed information about the first few matching children
                for (j, child) in matchingChildren.prefix(3).enumerated() {
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &roleRef)
                    let role = roleRef as? String ?? "unknown"
                    
                    diagnosis += "  Match \(j): role=\(role)"
                    
                    // Add key attributes to help with disambiguation
                    for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                        var attrRef: CFTypeRef?
                        let status = AXUIElementCopyAttributeValue(child, attr as CFString, &attrRef)
                        if status == .success, let value = attrRef as? String, !value.isEmpty {
                            diagnosis += ", \(attr)=\"\(value)\""
                        }
                    }
                    diagnosis += "\n"
                }
                
                if matchingChildren.count > 3 {
                    diagnosis += "  ...and \(matchingChildren.count - 3) more matches\n"
                }
                
                diagnosis += "\nRecommendation:\n"
                diagnosis += "  Add more specific attributes or use an index to disambiguate\n"
                diagnosis += "  Example: \(segment.toString())[@AXTitle=\"SomeTitle\"] or \(segment.toString())[0]\n\n"
                
                // Continue with first match for now
                currentElement = matchingChildren[0]
                diagnosis += "✅ Continuing with first matching child\n\n"
            } else {
                diagnosis += "✅ One child matches this segment\n"
                // Show what matched for informational purposes
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(matchingChildren[0], "AXRole" as CFString, &roleRef)
                let role = roleRef as? String ?? "unknown"
                diagnosis += "  Match details: role=\(role)"
                
                // Add key attributes for information
                for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                    var attrRef: CFTypeRef?
                    let status = AXUIElementCopyAttributeValue(matchingChildren[0], attr as CFString, &attrRef)
                    if status == .success, let value = attrRef as? String, !value.isEmpty {
                        diagnosis += ", \(attr)=\"\(value)\""
                    }
                }
                diagnosis += "\n\n"
                
                currentElement = matchingChildren[0]
            }
        }
        
        // Final summary
        if let finalElement = currentElement {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(finalElement, "AXRole" as CFString, &roleRef)
            let role = roleRef as? String ?? "unknown"
            
            // Get more information about the final element for better feedback
            var finalDetails = "  Details: role=\(role)"
            for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
                var attrRef: CFTypeRef?
                let status = AXUIElementCopyAttributeValue(finalElement, attr as CFString, &attrRef)
                if status == .success, let value = attrRef as? String, !value.isEmpty {
                    finalDetails += ", \(attr)=\"\(value)\""
                }
            }
            
            diagnosis += "Final result: ✅ Resolved to \(role) element\n"
            diagnosis += finalDetails + "\n"
        } else {
            diagnosis += "Final result: ❌ Failed to resolve complete path\n"
            diagnosis += "Try using the mcp-ax-inspector tool to examine the actual UI hierarchy\n"
        }
        
        return diagnosis
    }
    
    /// Helper function to convert an attribute reference to a string for diagnostics
    private static func convertAttributeToString(_ attributeRef: CFTypeRef?) -> String? {
        guard let attributeRef = attributeRef else { return nil }
        
        if let stringValue = attributeRef as? String {
            return stringValue
        } else if let numberValue = attributeRef as? NSNumber {
            return numberValue.stringValue
        } else if let boolValue = attributeRef as? Bool {
            return boolValue ? "true" : "false"
        } else {
            return String(describing: attributeRef)
        }
    }
}
    
    extension ElementPath {
    
    
    
    
}
