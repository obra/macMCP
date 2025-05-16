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
            // print("DEBUG: Match check - role not available, status: \(roleStatus.rawValue)")
            return false
        }
        
        guard let role = roleRef as? String else {
            // print("DEBUG: Match check - role not a string: \(String(describing: roleRef))")
            return false
        }
        
        // Log role
        // print("DEBUG: Match check - element role: \(role), expected: \(segment.role)")
        
        // Check role match
        guard role == segment.role else {
            // print("DEBUG: Match check - role mismatch")
            return false
        }
        
        // If there are no attributes to match, we're done
        if segment.attributes.isEmpty {
            // print("DEBUG: Match check - no attributes required, match found")
            return true
        }
        
        // Check each attribute with resilient attribute access and fallbacks
        for (name, expectedValue) in segment.attributes {
            // print("DEBUG: Match check - checking attribute: \(name), expected value: \(expectedValue)")
            
            // Get fallback attribute names for this attribute
            // Try all variants of the attribute name
            var attributeMatched = false
            for attributeName in self.getAttributeVariants(name) {
                if matchAttribute(element, name: attributeName, expectedValue: expectedValue) {
                    attributeMatched = true
                    // print("DEBUG: Match check - attribute matched via variant: \(attributeName)")
                    break
                }
            }
            
            // If none of the attribute variants matched, this element doesn't match
            if !attributeMatched {
                // print("DEBUG: Match check - attribute \(name) match failed on all variants: \(attributeVariants)")
                return false
            }
        }
        
        // All checks passed
        // print("DEBUG: Match check - full match found")
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
            // print("DEBUG: Match check - attribute \(name) not available, status: \(attributeStatus.rawValue)")
            return false
        }
        
        // Convert attribute value to string for comparison
        let actualValue: String
        
        if let stringValue = attributeRef as? String {
            actualValue = stringValue
            // print("DEBUG: Match check - attribute \(name) value (string): \(actualValue)")
        } else if let numberValue = attributeRef as? NSNumber {
            actualValue = numberValue.stringValue
            // print("DEBUG: Match check - attribute \(name) value (number): \(actualValue)")
        } else if let boolValue = attributeRef as? Bool {
            actualValue = boolValue ? "true" : "false"
            // print("DEBUG: Match check - attribute \(name) value (bool): \(actualValue)")
        } else {
            // For other types, use description
            actualValue = String(describing: attributeRef!)
            // print("DEBUG: Match check - attribute \(name) value (other): \(actualValue)")
        }
        
        // Check for partial matches in some cases
        let matchType: ElementPath.MatchType = self.determineMatchType(forAttribute: name)
        
        switch matchType {
        case .exact:
            // Exact match required
            let matches = (actualValue == expectedValue)
            if !matches {
                // print("DEBUG: Match check - attribute \(name) value mismatch (exact): expected \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .contains:
            // Check if the actual value contains the expected value
            let matches = actualValue.localizedCaseInsensitiveContains(expectedValue)
            if !matches {
                // print("DEBUG: Match check - attribute \(name) value mismatch (contains): expected to contain \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .substring:
            // Check both directions - exact match, contains, or is contained by
            let exactMatch = (actualValue == expectedValue)
            let containsExpected = actualValue.localizedCaseInsensitiveContains(expectedValue)
            let expectedContainsActual = expectedValue.localizedCaseInsensitiveContains(actualValue)
            
            let matches = exactMatch || containsExpected || expectedContainsActual
            if !matches {
                // print("DEBUG: Match check - attribute \(name) value mismatch (substring): expected relationship with \(expectedValue), got \(actualValue)")
            }
            return matches
            
        case .startsWith:
            // Check if the actual value starts with the expected value
            let matches = actualValue.localizedCaseInsensitiveCompare(expectedValue) == .orderedSame ||
                          actualValue.localizedStandardRange(of: expectedValue)?.lowerBound == actualValue.startIndex
            if !matches {
                // print("DEBUG: Match check - attribute \(name) value mismatch (startsWith): expected to start with \(expectedValue), got \(actualValue)")
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

// MARK: - Element Scoring for Progressive Resolution

extension ElementPath {
    /// Diagnoses issues with a path resolution and provides detailed troubleshooting information
    /// - Parameters:
    ///   - pathString: The path string to diagnose
    ///   - accessibilityService: The accessibility service to use for resolution attempts
    /// - Returns: A diagnostic report with details about the issue and suggested solutions
    /// - Throws: ElementPathError if there's a critical error during diagnosis
    public static func diagnosePathResolutionIssue(_ pathString: String, using accessibilityService: AccessibilityServiceProtocol) async throws -> String {
        var diagnosis = "Path Resolution Diagnosis for: \(pathString)\n"
        diagnosis += "=".repeating(80) + "\n\n"
        
        // Step 1: Validate the path syntax
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
        
        // Step 2: Try progressive path resolution
        do {
            let path = try parse(pathString)
            
            // Use progressive resolution to get detailed segment-by-segment diagnostics
            // Resolve progressively
            let resolutionResult = await path.resolvePathProgressively(using: accessibilityService)
            
            if resolutionResult.success {
                diagnosis += "PATH RESOLUTION: ✅ Success\n"
                diagnosis += "The path resolves successfully to a UI element.\n\n"
            } else {
                diagnosis += "PATH RESOLUTION: ❌ Failed\n"
                if let error = resolutionResult.error {
                    diagnosis += "Error: \(error)\n"
                }
                diagnosis += "\n"
                
                // Detailed segment-by-segment analysis
                diagnosis += "SEGMENT ANALYSIS:\n"
                for (i, segment) in resolutionResult.segments.enumerated() {
                    diagnosis += "  Segment \(i): \(segment.segment)\n"
                    
                    if segment.success {
                        diagnosis += "    Resolution: ✅ Success\n"
                    } else {
                        diagnosis += "    Resolution: ❌ Failed\n"
                        if let reason = segment.failureReason {
                            diagnosis += "    Reason: \(reason)\n"
                        }
                        
                        // List alternative candidates
                        if !segment.candidates.isEmpty {
                            diagnosis += "    Available alternatives:\n"
                            for (j, candidate) in segment.candidates.prefix(5).enumerated() {
                                diagnosis += "      \(j+1). \(candidate.description) (match score: \(String(format: "%.2f", candidate.match)))\n"
                            }
                            if segment.candidates.count > 5 {
                                diagnosis += "      ... and \(segment.candidates.count - 5) more alternatives\n"
                            }
                        } else {
                            diagnosis += "    No matching elements found\n"
                        }
                    }
                    diagnosis += "\n"
                }
                
                // If we know which segment failed, provide specific guidance
                if let failureIndex = resolutionResult.failureIndex {
                    diagnosis += "SUGGESTIONS FOR SEGMENT \(failureIndex):\n"
                    
                    let failedSegment = resolutionResult.segments[failureIndex]
                    
                    if !failedSegment.candidates.isEmpty {
                        // Case 1: We have alternatives - suggest ways to match them
                        if failedSegment.candidates.count > 1 {
                            diagnosis += "  • Too many matching elements - add more specific attributes or use an index:\n"
                            
                            // Suggest using an index
                            diagnosis += "    - Add index to select a specific element, e.g.: [...][0]\n"
                            
                            // Suggest attributes based on candidate information
                            let topCandidate = failedSegment.candidates.first!
                            var suggestedAttributes = ""
                            
                            for (key, value) in topCandidate.attributes {
                                if !value.isEmpty && key != "role" {
                                    suggestedAttributes += "    - Add attribute: [@\(key)=\"\(value)\"]\n"
                                }
                            }
                            
                            if !suggestedAttributes.isEmpty {
                                diagnosis += suggestedAttributes
                            }
                        } else if failedSegment.failureReason?.contains("high-quality") == true {
                            // Case 2: We have matches but they're low quality
                            diagnosis += "  • Found possible matches, but none with high confidence:\n"
                            diagnosis += "    - Try using more specific attribute values\n"
                            diagnosis += "    - Consider using exact matches for critical attributes\n"
                        }
                    } else {
                        // Case 3: No matches found at all
                        diagnosis += "  • No matching elements found in the UI hierarchy:\n"
                        diagnosis += "    - Verify the element exists in the application's UI\n"
                        diagnosis += "    - Check if the role '\(failedSegment.segment.split(separator: "[")[0])' is correct\n"
                        diagnosis += "    - Consider using a more general role (e.g., 'AXGroup' instead of a specific control type)\n"
                    }
                    
                    diagnosis += "\n"
                }
                
                // General improvement suggestions
                diagnosis += "GENERAL IMPROVEMENTS:\n"
                diagnosis += "  • Use the application's bundleIdentifier in the first segment for precise targeting\n"
                diagnosis += "  • Add more specific attributes to ambiguous segments\n"
                diagnosis += "  • Use indexes when multiple identical elements exist\n"
                diagnosis += "  • Consider shorter paths when possible to reduce resolution complexity\n"
                diagnosis += "  • Test with more generic attribute matching (e.g., substring instead of exact)\n"
            }
        } catch let error as ElementPathError {
            diagnosis += "PATH PARSING ERROR: \(error.description)\n"
            diagnosis += "Fix the path structure before attempting resolution.\n"
        } catch {
            diagnosis += "UNEXPECTED ERROR: \(error.localizedDescription)\n"
        }
        
        return diagnosis
    }
    
    /// Score how well an element matches a path segment
    /// - Parameters:
    ///   - element: The element to score
    ///   - segment: The path segment to match against
    /// - Returns: A score between 0.0 (no match) and 1.0 (perfect match)
    private func scoreElementMatch(_ element: AXUIElement, segment: PathSegment) async -> Double {
        // Get the role and compare it
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        
        // Role must match exactly or we immediately return 0
        if roleStatus != .success || roleRef == nil {
            return 0.0
        }
        
        guard let role = roleRef as? String else {
            return 0.0
        }
        
        if role != segment.role {
            return 0.0
        }
        
        // Start with a base score for matching role
        var score = 0.5
        
        // If there are no attributes to match, return the base score
        if segment.attributes.isEmpty {
            return score
        }
        
        // For each matching attribute, increase the score
        let maxAttributeScore = 0.5 // Maximum score contribution from attributes
        var attributeScoreSum = 0.0
        
        for (name, expectedValue) in segment.attributes {
            let attributeScore = scoreAttributeMatch(element, attributeName: name, expectedValue: expectedValue)
            attributeScoreSum += attributeScore
        }
        
        // Normalize the attribute score based on number of attributes
        let attributeCount = Double(segment.attributes.count)
        let normalizedAttributeScore = attributeScoreSum / attributeCount
        
        // Combine the scores: 50% for role match, 50% for attribute matches
        score += normalizedAttributeScore * maxAttributeScore
        
        return score
    }
}
    
    extension ElementPath {
    /// Score how well an attribute matches its expected value
    /// - Parameters:
    ///   - element: The element containing the attribute
    ///   - attributeName: The name of the attribute
    ///   - expectedValue: The expected value of the attribute
    /// - Returns: A score between 0.0 (no match) and 1.0 (perfect match)
    private func scoreAttributeMatch(_ element: AXUIElement, attributeName: String, expectedValue: String) -> Double {
        // Try different variants of the attribute name
        let attributeVariants = self.getAttributeVariants(attributeName)
        var bestScore = 0.0
        
        for attributeKey in attributeVariants {
            var attributeRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, attributeKey as CFString, &attributeRef)
            
            if status != .success || attributeRef == nil {
                continue
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
            
            // Determine match type for this attribute
            let matchType = self.determineMatchType(forAttribute: attributeKey)
            let currentScore = self.calculateAttributeScore(expected: expectedValue, actual: actualValue, matchType: matchType)
            
            // Keep the best score among attribute variants
            if currentScore > bestScore {
                bestScore = currentScore
            }
        }
        
        return bestScore
    }
    
    /// Calculate a score for how well an attribute value matches its expected value
    /// - Parameters:
    ///   - expected: The expected value
    ///   - actual: The actual value
    ///   - matchType: The type of matching to perform
    /// - Returns: A score between 0.0 (no match) and 1.0 (perfect match)
    private func calculateAttributeScore(expected: String, actual: String, matchType: MatchType) -> Double {
        switch matchType {
        case .exact:
            // Exact match: 1.0 for match, 0.0 for no match
            return actual == expected ? 1.0 : 0.0
            
        case .contains:
            // Contains: 1.0 for exact match, 0.7 for contains, 0.0 for no match
            if actual == expected {
                return 1.0
            } else if actual.localizedCaseInsensitiveContains(expected) {
                // Calculate how significant the match is based on length ratio
                let matchRatio = Double(expected.count) / Double(actual.count)
                return 0.7 + (0.3 * matchRatio) // 0.7-1.0 depending on match quality
            }
            return 0.0
            
        case .substring:
            // Substring: 1.0 for exact match, 0.7-0.9 for contains/contained by
            if actual == expected {
                return 1.0
            } else if actual.localizedCaseInsensitiveContains(expected) {
                // Calculate how significant the match is based on length ratio
                let matchRatio = Double(expected.count) / Double(actual.count)
                return 0.7 + (0.2 * matchRatio) // 0.7-0.9 depending on match quality
            } else if expected.localizedCaseInsensitiveContains(actual) {
                // The expected value contains the actual value
                let matchRatio = Double(actual.count) / Double(expected.count)
                return 0.6 + (0.3 * matchRatio) // 0.6-0.9 depending on match quality
            }
            return 0.0
            
        case .startsWith:
            // StartsWith: 1.0 for exact match, 0.8 for startsWith, 0.0 for no match
            if actual == expected {
                return 1.0
            } else if actual.localizedStandardRange(of: expected)?.lowerBound == actual.startIndex {
                // Calculate how significant the match is based on length ratio
                let matchRatio = Double(expected.count) / Double(actual.count)
                return 0.8 + (0.2 * matchRatio) // 0.8-1.0 depending on match quality
            }
            return 0.0
        }
    }
    
    /// Get summary information about an element for diagnostic purposes
    /// - Parameter element: The AXUIElement to describe
    /// - Returns: A descriptive string and a dictionary of key attributes
    private func getElementDescription(_ element: AXUIElement) -> (description: String, attributes: [String: String]) {
        var description = ""
        var attributes: [String: String] = [:]
        
        // Try to get the role
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)
        if roleStatus == .success, let role = roleRef as? String {
            description += role
            attributes["AXRole"] = role
        } else {
            description += "Unknown"
        }
        
        // Try to get other identifying attributes
        for attrName in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
            var attrRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, attrName as CFString, &attrRef)
            if status == .success {
                if let stringValue = attrRef as? String, !stringValue.isEmpty {
                    description += ", \(attrName): \"\(stringValue)\""
                    attributes[attrName] = stringValue
                } else if let numberValue = attrRef as? NSNumber {
                    description += ", \(attrName): \(numberValue)"
                    attributes[attrName] = numberValue.stringValue
                } else if let boolValue = attrRef as? Bool {
                    description += ", \(attrName): \(boolValue)"
                    attributes[attrName] = boolValue ? "true" : "false"
                }
            }
        }
        
        return (description, attributes)
    }
    
    /// Resolve this path progressively, providing detailed information about each step
    /// - Parameter accessibilityService: The AccessibilityService to use for accessing the accessibility API
    /// - Returns: A PathResolutionResult containing detailed information about the resolution process
    public func resolvePathProgressively(
        using accessibilityService: AccessibilityServiceProtocol
    ) async -> PathResolutionResult {
        var segmentResults: [SegmentResolutionResult] = []
        var currentElement: AXUIElement?
        var failureIndex: Int?
        var errorMessage: String?
        
        // Get the application element as starting point
        let startElement: AXUIElement
        
        // Try to resolve the first segment (application or system-wide element)
        do {
            let firstSegment = segments[0]
            
            // First segment should be the application or window element
            if firstSegment.role == "AXApplication" {
                // Try different approaches to find the application element
                if let bundleId = firstSegment.attributes["bundleIdentifier"] {
                    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                    
                    if let app = apps.first {
                        startElement = AXUIElementCreateApplication(app.processIdentifier)
                        // Skip to next segment since we resolved this one directly
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: true,
                            candidates: [
                                CandidateElement(
                                    element: startElement, 
                                    match: 1.0,
                                    description: "Application: \(app.localizedName ?? bundleId)",
                                    attributes: ["bundleIdentifier": bundleId]
                                )
                            ],
                            failureReason: nil
                        )
                        segmentResults.append(segmentInfo)
                        currentElement = startElement
                    } else {
                        // Application not found - gather running apps for diagnostics
                        let runningApps = NSWorkspace.shared.runningApplications
                        let appCandidates: [CandidateElement] = runningApps.prefix(5).compactMap { app in
                            guard let appElement = app.processIdentifier != 0 ? 
                                  AXUIElementCreateApplication(app.processIdentifier) : nil else {
                                return nil
                            }
                            
                            let appBundleId = app.bundleIdentifier ?? "unknown"
                            let match = bundleId == appBundleId ? 1.0 : 0.0
                            return CandidateElement(
                                element: appElement,
                                match: match,
                                description: "Application: \(app.localizedName ?? "Unknown") (\(appBundleId))",
                                attributes: ["bundleIdentifier": appBundleId]
                            )
                        }
                        
                        let reason = "Application with bundleIdentifier '\(bundleId)' is not running"
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: false,
                            candidates: appCandidates,
                            failureReason: reason
                        )
                        segmentResults.append(segmentInfo)
                        failureIndex = 0
                        errorMessage = reason
                        
                        // Return early with failure
                        return PathResolutionResult(
                            success: false,
                            resolvedElement: nil,
                            segments: segmentResults,
                            failureIndex: failureIndex,
                            error: errorMessage
                        )
                    }
                }
                // Try by title/name if provided
                else if let title = firstSegment.attributes["title"] {
                    // Get all running applications
                    let runningApps = NSWorkspace.shared.runningApplications
                    
                    // Find application with matching title
                    if let app = runningApps.first(where: { 
                        $0.localizedName == title || $0.localizedName?.contains(title) == true 
                    }) {
                        startElement = AXUIElementCreateApplication(app.processIdentifier)
                        
                        // Skip to next segment since we resolved this one directly
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: true,
                            candidates: [
                                CandidateElement(
                                    element: startElement, 
                                    match: 1.0,
                                    description: "Application: \(app.localizedName ?? title)",
                                    attributes: ["title": title]
                                )
                            ],
                            failureReason: nil
                        )
                        segmentResults.append(segmentInfo)
                        currentElement = startElement
                    } else {
                        // No match found - gather apps for diagnostics
                        let runningApps = NSWorkspace.shared.runningApplications
                        let appCandidates: [CandidateElement] = runningApps.prefix(5).compactMap { app in
                            guard let appElement = app.processIdentifier != 0 ? 
                                  AXUIElementCreateApplication(app.processIdentifier) : nil,
                                  let appName = app.localizedName else {
                                return nil
                            }
                            
                            // Calculate match score based on title similarity
                            let matchScore: Double
                            if appName == title {
                                matchScore = 1.0
                            } else if appName.localizedCaseInsensitiveContains(title) {
                                matchScore = 0.7
                            } else if title.localizedCaseInsensitiveContains(appName) {
                                matchScore = 0.5
                            } else {
                                matchScore = 0.0
                            }
                            
                            return CandidateElement(
                                element: appElement,
                                match: matchScore,
                                description: "Application: \(appName) (\(app.bundleIdentifier ?? "unknown"))",
                                attributes: ["title": appName]
                            )
                        }
                        
                        // Sort candidates by match score
                        let sortedCandidates = appCandidates.sorted { $0.match > $1.match }
                        
                        let reason = "Application with title '\(title)' not found"
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: false,
                            candidates: sortedCandidates,
                            failureReason: reason
                        )
                        segmentResults.append(segmentInfo)
                        failureIndex = 0
                        errorMessage = reason
                        
                        // Return early with failure
                        return PathResolutionResult(
                            success: false,
                            resolvedElement: nil,
                            segments: segmentResults,
                            failureIndex: failureIndex,
                            error: errorMessage
                        )
                    }
                }
                // Use focused application as fallback
                else {
                    do {
                        // Get the focused application from the accessibility service
                        let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(recursive: false, maxDepth: 1)
                        
                        // Check if we got a valid element
                        guard let axElement = focusedElement.axElement else {
                            throw ElementPathError.segmentResolutionFailed("Could not get focused application element", atSegment: 0)
                        }
                        
                        startElement = axElement
                        
                        // Add segment info for the focused app
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: true,
                            candidates: [
                                CandidateElement(
                                    element: startElement, 
                                    match: 1.0,
                                    description: "Focused application",
                                    attributes: ["focused": "true"]
                                )
                            ],
                            failureReason: nil
                        )
                        segmentResults.append(segmentInfo)
                        currentElement = startElement
                    } catch {
                        // If that fails, try to get the frontmost application using NSWorkspace
                        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                            let reason = "Could not determine frontmost application"
                            let segmentInfo = SegmentResolutionResult(
                                segment: firstSegment.toString(),
                                success: false,
                                candidates: [],
                                failureReason: reason
                            )
                            segmentResults.append(segmentInfo)
                            failureIndex = 0
                            errorMessage = reason
                            
                            // Return early with failure
                            return PathResolutionResult(
                                success: false,
                                resolvedElement: nil,
                                segments: segmentResults,
                                failureIndex: failureIndex,
                                error: errorMessage
                            )
                        }
                        
                        startElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                        
                        // Add segment info for the frontmost app
                        let segmentInfo = SegmentResolutionResult(
                            segment: firstSegment.toString(),
                            success: true,
                            candidates: [
                                CandidateElement(
                                    element: startElement, 
                                    match: 1.0,
                                    description: "Frontmost application: \(frontApp.localizedName ?? "Unknown")",
                                    attributes: ["frontmost": "true"]
                                )
                            ],
                            failureReason: nil
                        )
                        segmentResults.append(segmentInfo)
                        currentElement = startElement
                    }
                }
            } 
            // For system-wide operations or other special starting points
            else if firstSegment.role == "AXSystemWide" {
                startElement = AXUIElementCreateSystemWide()
                
                // Add segment info for the system-wide element
                let segmentInfo = SegmentResolutionResult(
                    segment: firstSegment.toString(),
                    success: true,
                    candidates: [
                        CandidateElement(
                            element: startElement, 
                            match: 1.0,
                            description: "System-wide element",
                            attributes: [:]
                        )
                    ],
                    failureReason: nil
                )
                segmentResults.append(segmentInfo)
                currentElement = startElement
            }
            // For any other element type as the first segment
            else {
                // Get the system-wide element as starting point for a broader search
                startElement = AXUIElementCreateSystemWide()
                
                // Try to resolve the first segment using the system-wide element
                let segmentResult = await resolveSegmentProgressively(
                    element: startElement,
                    segment: firstSegment,
                    segmentIndex: 0
                )
                
                segmentResults.append(segmentResult)
                
                if segmentResult.success, let bestCandidate = segmentResult.candidates.first {
                    currentElement = bestCandidate.element
                } else {
                    // First segment resolution failed
                    failureIndex = 0
                    errorMessage = segmentResult.failureReason ?? "Could not resolve first segment"
                    
                    // Return early with failure
                    return PathResolutionResult(
                        success: false,
                        resolvedElement: nil,
                        segments: segmentResults,
                        failureIndex: failureIndex,
                        error: errorMessage
                    )
                }
            }
            
            // Now we have our starting point, traverse the remaining segments
            for (index, segment) in segments.enumerated() {
                // Skip the first segment if we already resolved it
                if index == 0 && currentElement != nil {
                    continue
                }
                
                // Make sure we have a current element to work with
                guard let element = currentElement else {
                    let reason = "No element available to resolve segment"
                    let segmentInfo = SegmentResolutionResult(
                        segment: segment.toString(),
                        success: false,
                        candidates: [],
                        failureReason: reason
                    )
                    segmentResults.append(segmentInfo)
                    failureIndex = index
                    errorMessage = reason
                    break
                }
                
                // Resolve this segment
                let segmentResult = await resolveSegmentProgressively(
                    element: element,
                    segment: segment,
                    segmentIndex: index
                )
                
                segmentResults.append(segmentResult)
                
                if segmentResult.success, let bestCandidate = segmentResult.candidates.first {
                    currentElement = bestCandidate.element
                } else {
                    // Segment resolution failed
                    failureIndex = index
                    errorMessage = segmentResult.failureReason ?? "Could not resolve segment"
                    currentElement = nil
                    break
                }
            }
            
            // Build the final result
            return PathResolutionResult(
                success: currentElement != nil,
                resolvedElement: currentElement,
                segments: segmentResults,
                failureIndex: failureIndex,
                error: errorMessage
            )
        }
    }
    
    /// Resolve a single segment with detailed information about the matching process
    /// - Parameters:
    ///   - element: The starting element
    ///   - segment: The segment to resolve
    ///   - segmentIndex: The index of the segment in the path
    /// - Returns: Detailed information about the resolution attempt
    private func resolveSegmentProgressively(
        element: AXUIElement,
        segment: PathSegment,
        segmentIndex: Int
    ) async -> SegmentResolutionResult {
        // Get children of the element
        var childrenRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
        
        // Check if we could get children
        if status != .success || childrenRef == nil {
            // If this is the first segment, check if the element itself matches
            if segmentIndex == 0 {
                let score = await scoreElementMatch(element, segment: segment)
                if score > 0 {
                    let (description, attributes) = getElementDescription(element)
                    let candidate = CandidateElement(
                        element: element,
                        match: score,
                        description: description,
                        attributes: attributes
                    )
                    return SegmentResolutionResult(
                        segment: segment.toString(),
                        success: true,
                        candidates: [candidate],
                        failureReason: nil
                    )
                }
            }
            
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: false,
                candidates: [],
                failureReason: "Could not get children for element"
            )
        }
        
        // Cast to array of elements
        guard let children = childrenRef as? [AXUIElement] else {
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: false,
                candidates: [],
                failureReason: "Children not in expected format"
            )
        }
        
        // Evaluate all children and calculate match scores
        var candidates: [CandidateElement] = []
        
        for child in children {
            let score = await scoreElementMatch(child, segment: segment)
            if score > 0 {
                let (description, attributes) = getElementDescription(child)
                candidates.append(CandidateElement(
                    element: child,
                    match: score,
                    description: description,
                    attributes: attributes
                ))
            }
        }
        
        // Special case for when the parent element itself matches
        if segmentIndex == 0 {
            let score = await scoreElementMatch(element, segment: segment)
            if score > 0 {
                let (description, attributes) = getElementDescription(element)
                candidates.append(CandidateElement(
                    element: element,
                    match: score,
                    description: description,
                    attributes: attributes
                ))
            }
        }
        
        // Sort candidates by match score (highest first)
        candidates.sort { $0.match > $1.match }
        
        // Handle based on number of high-quality matches
        let highQualityThreshold = 0.8
        let highQualityMatches = candidates.filter { $0.match >= highQualityThreshold }
        
        if candidates.isEmpty {
            // No matches at all
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: false,
                candidates: [],
                failureReason: "No elements match this segment"
            )
        } else if highQualityMatches.isEmpty && !candidates.isEmpty {
            // We have matches, but none with high confidence
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: false,
                candidates: candidates,
                failureReason: "No high-quality matches found"
            )
        } else if highQualityMatches.count == 1 || segment.index != nil {
            // We have a single high-quality match or an index was specified
            
            // If index was specified, use it to select
            if let index = segment.index {
                if index < 0 || index >= highQualityMatches.count {
                    return SegmentResolutionResult(
                        segment: segment.toString(),
                        success: false,
                        candidates: highQualityMatches,
                        failureReason: "Index out of range: \(index)"
                    )
                }
                
                // The matching candidates are already sorted by score
                return SegmentResolutionResult(
                    segment: segment.toString(),
                    success: true,
                    candidates: highQualityMatches,
                    failureReason: nil
                )
            }
            
            // No index specified, but we have a single high-quality match
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: true,
                candidates: highQualityMatches,
                failureReason: nil
            )
        } else {
            // Multiple high-quality matches and no index - ambiguous
            return SegmentResolutionResult(
                segment: segment.toString(),
                success: false,
                candidates: highQualityMatches,
                failureReason: "Multiple elements (\(highQualityMatches.count)) match this segment. Add more specific attributes or use an index."
            )
        }
	}
}
/// Result of a progressive path resolution operation
public struct PathResolutionResult: Sendable {
    /// Whether the full path resolution was successful
    public let success: Bool
    
    /// The final resolved element if successful
    public let resolvedElement: AXUIElement?
    
    /// Per-segment resolution results
    public let segments: [SegmentResolutionResult]
    
    /// Index where resolution failed, if any
    public let failureIndex: Int?
    
    /// Error message if resolution failed
    public let error: String?
}

/// Result of a single segment resolution attempt
public struct SegmentResolutionResult: Sendable {
    /// The segment string that was resolved
    public let segment: String
    
    /// Whether this segment was successfully resolved
    public let success: Bool
    
    /// Potential matching elements (ranked by match quality)
    public let candidates: [CandidateElement]
    
    /// Reason why resolution failed, if applicable
    public let failureReason: String?
}

/// A candidate element that might match a path segment
public struct CandidateElement: Sendable {
    /// The UI element
    public let element: AXUIElement
    
    /// Match score (0.0 to 1.0 with 1.0 being a perfect match)
    public let match: Double
    
    /// Description of the element for debugging
    public let description: String
    
    /// Key attributes that identify this element
    public let attributes: [String: String]
}
