// ABOUTME: This file defines the ElementPath model used for path-based UI element identification.
// ABOUTME: It includes path parsing, generation, and validation logic for UIElement paths.

import Foundation
import AppKit
import MacMCPUtilities

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
    
    /// Enhanced error with detailed information about why resolution failed
    case resolutionFailed(segment: String, index: Int, candidates: [String], reason: String)
    
    /// Application specified in path was not found
    case applicationNotFound(String, details: String)
    
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
        case (.resolutionFailed(let lhsSegment, let lhsIndex, let lhsCandidates, let lhsReason),
              .resolutionFailed(let rhsSegment, let rhsIndex, let rhsCandidates, let rhsReason)):
            return lhsSegment == rhsSegment && lhsIndex == rhsIndex && lhsCandidates == rhsCandidates && lhsReason == rhsReason
        case (.applicationNotFound(let lhsApp, let lhsDetails), .applicationNotFound(let rhsApp, let rhsDetails)):
            return lhsApp == rhsApp && lhsDetails == rhsDetails
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
        let startElement: AXUIElement
        
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
                
                startElement = AXUIElementCreateApplication(app.processIdentifier)
            }
            // 2. Try by title/name if provided
            else if let title = firstSegment.attributes["title"] {
                // Get all running applications
                let runningApps = NSWorkspace.shared.runningApplications
                
                // Find application with matching title
                if let app = runningApps.first(where: { 
                    $0.localizedName == title || $0.localizedName?.contains(title) == true 
                }) {
                    startElement = AXUIElementCreateApplication(app.processIdentifier)
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
                    
                    startElement = axElement
                } catch {
                    // If that fails, try to get the frontmost application using NSWorkspace
                    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                        throw ElementPathError.segmentResolutionFailed("Could not determine frontmost application", atSegment: 0)
                    }
                    
                    startElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                }
            }
        } 
        // For system-wide operations or other special starting points
        else if firstSegment.role == "AXSystemWide" {
            startElement = AXUIElementCreateSystemWide()
        }
        // For any other element type as the first segment
        else {
            // Get the system-wide element as starting point for a broader search
            startElement = AXUIElementCreateSystemWide()
        }
        
        // Now we have our starting point, traverse the path
        var currentElement = startElement
        
        // Iterate through each segment starting from the first
        for (index, segment) in segments.enumerated() {
            // If we're at the first segment and we already got an application directly, skip to next
            if index == 0 && firstSegment.role == "AXApplication" {
                continue
            }
            
            // Resolve this segment
            guard let nextElement = try await resolveSegment(element: currentElement, segment: segment, segmentIndex: index) else {
                let segmentString = segment.toString()
                throw ElementPathError.noMatchingElements(segmentString, atSegment: index)
            }
            
            // Update current element for next iteration
            currentElement = nextElement
        }
        
        return currentElement
    }
    
    /// Resolve a single segment of a path starting from a given element
    /// - Parameters:
    ///   - element: The starting element
    ///   - segment: The path segment to resolve
    ///   - segmentIndex: The index of the segment in the overall path (for error reporting)
    /// - Returns: The resolved element matching the segment, or nil if no match is found
    /// - Throws: ElementPathError if there's an error resolving the segment
    public func resolveSegment(element: AXUIElement, segment: PathSegment, segmentIndex: Int) async throws -> AXUIElement? {
        print("DEBUG: Resolving segment \(segmentIndex): \(segment.toString())")
        
        // Get information about the current element
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        if roleStatus == .success, let role = roleRef as? String {
            print("DEBUG: Current element role: \(role)")
            
            // Get title if available
            var titleRef: CFTypeRef?
            let titleStatus = AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &titleRef)
            if titleStatus == .success, let title = titleRef as? String {
                print("DEBUG: Current element title: \(title)")
            }
        }
        
        // Get the children of the current element
        var childrenRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        
        print("DEBUG: AXUIElementCopyAttributeValue status for AXChildren: \(status.rawValue)")
        
        // Check if we could get children
        if status != .success || childrenRef == nil {
            print("DEBUG: Failed to get children - status: \(status.rawValue), childrenRef: \(String(describing: childrenRef))")
            
            // If this is the first segment (application), allow the element itself to match
            if segmentIndex == 0 {
                // Check if this element itself matches the segment
                if try await elementMatchesSegment(element, segment: segment) {
                    print("DEBUG: First segment matches element itself")
                    return element
                }
            }
            
            let segmentString = segment.toString()
            throw ElementPathError.segmentResolutionFailed("Could not get children for segment: \(segmentString)", atSegment: segmentIndex)
        }
        
        // Cast to array of elements
        guard let children = childrenRef as? [AXUIElement] else {
            print("DEBUG: Failed to cast children to [AXUIElement] - type: \(type(of: childrenRef))")
            let segmentString = segment.toString()
            throw ElementPathError.segmentResolutionFailed("Children not in expected format for segment: \(segmentString)", atSegment: segmentIndex)
        }
        
        print("DEBUG: Found \(children.count) children of current element")
        
        // Log child roles to help with debugging
        print("DEBUG: Child roles:")
        for (i, child) in children.enumerated() {
            var childRoleRef: CFTypeRef?
            let childRoleStatus = AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &childRoleRef)
            if childRoleStatus == .success, let childRole = childRoleRef as? String {
                print("DEBUG:   [\(i)] \(childRole)")
                
                // If the child matches our target segment role, check title too
                if childRole == segment.role {
                    var childTitleRef: CFTypeRef?
                    let childTitleStatus = AXUIElementCopyAttributeValue(child, "AXTitle" as CFString, &childTitleRef)
                    if childTitleStatus == .success, let childTitle = childTitleRef as? String {
                        print("DEBUG:     Title: \(childTitle)")
                    }
                }
            } else {
                print("DEBUG:   [\(i)] Unknown role, status: \(childRoleStatus.rawValue)")
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
        
        print("DEBUG: Found \(matches.count) matches for segment \(segment.toString())")
        
        // Special case for when the parent element itself matches
        if segmentIndex == 0 && matches.isEmpty {
            // Check if the root element matches
            if try await elementMatchesSegment(element, segment: segment) {
                print("DEBUG: Root element matches first segment")
                return element
            }
        }
        
        // Handle based on number of matches and whether an index was specified
        if matches.isEmpty {
            print("DEBUG: No matches found for segment")
            
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
                    print("DEBUG: Index out of range: \(index) for matches.count: \(matches.count)")
                    throw ElementPathError.segmentResolutionFailed("Index out of range: \(index) for segment: \(segmentString)", atSegment: segmentIndex)
                }
                
                print("DEBUG: Returning match at specified index \(index)")
                return matches[index]
            }
            
            // Otherwise return the single match
            print("DEBUG: Returning single match")
            return matches[0]
        } else {
            // Multiple matches and no index specified - this is ambiguous
            let segmentString = segment.toString()
            print("DEBUG: Ambiguous match - \(matches.count) elements match segment")
            
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
            print("DEBUG: Match check - role not available, status: \(roleStatus.rawValue)")
            return false
        }
        
        guard let role = roleRef as? String else {
            print("DEBUG: Match check - role not a string: \(String(describing: roleRef))")
            return false
        }
        
        // Log role
        print("DEBUG: Match check - element role: \(role), expected: \(segment.role)")
        
        // Check role match
        guard role == segment.role else {
            print("DEBUG: Match check - role mismatch")
            return false
        }
        
        // If there are no attributes to match, we're done
        if segment.attributes.isEmpty {
            print("DEBUG: Match check - no attributes required, match found")
            return true
        }
        
        // Check each attribute with resilient attribute access and fallbacks
        for (name, expectedValue) in segment.attributes {
            print("DEBUG: Match check - checking attribute: \(name), expected value: \(expectedValue)")
            
            // Get fallback attribute names for this attribute
            let attributeVariants = getAttributeVariants(name)
            
            // Try all variants of the attribute name
            var attributeMatched = false
            for attributeName in attributeVariants {
                if matchAttribute(element, name: attributeName, expectedValue: expectedValue) {
                    attributeMatched = true
                    print("DEBUG: Match check - attribute matched via variant: \(attributeName)")
                    break
                }
            }
            
            // If none of the attribute variants matched, this element doesn't match
            if !attributeMatched {
                print("DEBUG: Match check - attribute \(name) match failed on all variants: \(attributeVariants)")
                return false
            }
        }
        
        // All checks passed
        print("DEBUG: Match check - full match found")
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
    
    /// Match an attribute value against an expected value with robust error handling
    /// - Parameters:
    ///   - element: The AXUIElement to check
    ///   - name: The attribute name
    ///   - expectedValue: The expected attribute value
    /// - Returns: True if the attribute matches the expected value
    private func matchAttribute(_ element: AXUIElement, name: String, expectedValue: String) -> Bool {
        // Get the attribute value
        var attributeRef: CFTypeRef?
        let attributeStatus = AXUIElementCopyAttributeValue(element, name as CFString, &attributeRef)
        
        // If we couldn't get the attribute, it doesn't match
        if attributeStatus != .success || attributeRef == nil {
            print("DEBUG: Match check - attribute \(name) not available, status: \(attributeStatus.rawValue)")
            return false
        }
        
        // Convert attribute value to string for comparison
        let actualValue: String
        
        if let stringValue = attributeRef as? String {
            actualValue = stringValue
            print("DEBUG: Match check - attribute \(name) value (string): \(actualValue)")
        } else if let numberValue = attributeRef as? NSNumber {
            actualValue = numberValue.stringValue
            print("DEBUG: Match check - attribute \(name) value (number): \(actualValue)")
        } else if let boolValue = attributeRef as? Bool {
            actualValue = boolValue ? "true" : "false"
            print("DEBUG: Match check - attribute \(name) value (bool): \(actualValue)")
        } else {
            // For other types, use description
            actualValue = String(describing: attributeRef!)
            print("DEBUG: Match check - attribute \(name) value (other): \(actualValue)")
        }
        
        // Check for partial matches in some cases
        let matchType: MatchType = determineMatchType(forAttribute: name)
        
        switch matchType {
        case .exact:
            // Exact match required
            let matches = (actualValue == expectedValue)
            if !matches {
                print("DEBUG: Match check - attribute \(name) value mismatch (exact): expected \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .contains:
            // Check if the actual value contains the expected value
            let matches = actualValue.localizedCaseInsensitiveContains(expectedValue)
            if !matches {
                print("DEBUG: Match check - attribute \(name) value mismatch (contains): expected to contain \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .substring:
            // Check both directions - exact match, contains, or is contained by
            let exactMatch = (actualValue == expectedValue)
            let containsExpected = actualValue.localizedCaseInsensitiveContains(expectedValue)
            let expectedContainsActual = expectedValue.localizedCaseInsensitiveContains(actualValue)
            
            let matches = exactMatch || containsExpected || expectedContainsActual
            if !matches {
                print("DEBUG: Match check - attribute \(name) value mismatch (substring): expected relationship with \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .startsWith:
            // Check if the actual value starts with the expected value
            let matches = actualValue.localizedCaseInsensitiveCompare(expectedValue) == .orderedSame ||
                          actualValue.localizedStandardRange(of: expectedValue)?.lowerBound == actualValue.startIndex
            if !matches {
                print("DEBUG: Match check - attribute \(name) value mismatch (startsWith): expected to start with \(expectedValue), got \(actualValue)")
            }
            return matches
        }
    }
    
    /// Determines how to match an attribute based on its type
    /// - Parameter attribute: The attribute name
    /// - Returns: The match type to use
    public func determineMatchType(forAttribute attribute: String) -> MatchType {
        // Normalize the attribute name for consistent matching
        let normalizedName = PathNormalizer.normalizeAttributeName(attribute)
        
        switch normalizedName {
        case "AXTitle":
            // Title can sometimes be a substring or contain the attribute we're looking for
            return .substring
            
        case "AXDescription", "AXHelp":
            // Descriptions are often longer and might just contain the expected text
            return .contains
            
        case "AXValue":
            // Values can sometimes be partial matches
            return .substring
            
        case "AXLabel", "AXPlaceholderValue":
            // Labels often contain the text we're looking for
            return .contains
            
        case "AXRoleDescription":
            // Role descriptions may contain what we're looking for
            return .contains
            
        case "AXIdentifier":
            // Identifiers should match exactly
            return .exact
            
        case "bundleIdentifier", "AXBundleIdentifier":
            // Bundle IDs should match exactly
            return .exact
            
        case "AXRole":
            // Roles should match exactly
            return .exact
            
        case "AXSubrole":
            // Subroles should match exactly
            return .exact
            
        case "AXPath":
            // Paths should match exactly
            return .exact
            
        case "AXFrameInScreenCoordinates", "AXFrame", "AXPosition", "AXSize":
            // Geometry attributes should match exactly
            return .exact
            
        case "AXFilename", "AXName":
            // Filenames often need startsWith matching for partial paths
            return .startsWith
            
        default:
            // For most attributes, require exact match
            return .exact
        }
    }
    
    /// Types of attribute matching strategies
    public enum MatchType {
        /// Require exact match between expected and actual values
        case exact
        
        /// Check if actual value contains expected value
        case contains
        
        /// Check if either value contains the other or they're equal
        case substring
        
        /// Check if actual value starts with expected value
        case startsWith
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