// ABOUTME: ElementPath.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

@preconcurrency import AppKit
import Foundation
import Logging
import MacMCPUtilities

// Logger for element path operations
private let logger = Logger(label: "mcp.models.element_path")

/// Errors that can occur when working with element paths
public enum ElementPathError: Error, CustomStringConvertible, Equatable {
  /// The path syntax is invalid
  case invalidPathSyntax(String, details: String)

  /// The path prefix is missing or incorrect (should start with macos://ui/)
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
      return "Invalid path prefix: \(prefix), should start with macos://ui/"
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
          details += "\n  \(i + 1). \(candidate)"
        }
        details +=
          "\nConsider using one of these alternatives or add more specific attributes to your path."
      }
      return details
    case .applicationNotFound(let appIdentifier, let details):
      return "Application not found: \(appIdentifier). \(details)"
    case .invalidAttributeFormat(let attribute, let expectedFormat, let segmentIndex):
      return
        "Invalid attribute format: \(attribute) at segment \(segmentIndex). Expected format: \(expectedFormat)"
    case .pathTooComplex(let path, let details):
      return "Path is too complex: \(path).\nDetails: \(details)"
    case .potentialAmbiguity(let segment, let details, let segmentIndex):
      return
        "Potential ambiguity in segment \(segmentIndex): \(segment).\nDetails: \(details)\nConsider adding more specific attributes or an index."
    case .missingAttribute(let segment, let suggestedAttribute, let segmentIndex):
      return
        "Missing essential attribute in segment \(segmentIndex): \(segment).\nConsider adding \(suggestedAttribute) for more reliable resolution."
    case .resolutionTimeout(let segment, let segmentIndex):
      return
        "Resolution timeout for segment \(segmentIndex): \(segment).\nThe UI hierarchy might be too deep or complex."
    case .insufficientPermissions(let feature, let details):
      return "Insufficient accessibility permissions for: \(feature).\n\(details)"
    case .validationWarning(let message, let suggestion):
      return "Warning: \(message).\nSuggestion: \(suggestion)"
    }
  }

  public static func == (lhs: ElementPathError, rhs: ElementPathError) -> Bool {
    switch (lhs, rhs) {
    case (.emptyPath, .emptyPath):
      true
    case (
      .invalidPathSyntax(let lhsPath, let lhsDetails),
      .invalidPathSyntax(let rhsPath, let rhsDetails)
    ):
      lhsPath == rhsPath && lhsDetails == rhsDetails
    case (.invalidPathPrefix(let lhsPrefix), .invalidPathPrefix(let rhsPrefix)):
      lhsPrefix == rhsPrefix
    case (.invalidSegmentRole(let lhsRole), .invalidSegmentRole(let rhsRole)):
      lhsRole == rhsRole
    case (
      .invalidAttributeSyntax(let lhsAttr, let lhsSegment),
      .invalidAttributeSyntax(let rhsAttr, let rhsSegment),
    ):
      lhsAttr == rhsAttr && lhsSegment == rhsSegment
    case (
      .invalidIndexSyntax(let lhsIndex, let lhsSegment),
      .invalidIndexSyntax(let rhsIndex, let rhsSegment)
    ):
      lhsIndex == rhsIndex && lhsSegment == rhsSegment
    case (
      .invalidAttributeValue(let lhsValue, let lhsAttr),
      .invalidAttributeValue(let rhsValue, let rhsAttr)
    ):
      lhsValue == rhsValue && lhsAttr == rhsAttr
    case (
      .segmentResolutionFailed(let lhsSegment, let lhsIndex),
      .segmentResolutionFailed(let rhsSegment, let rhsIndex),
    ):
      lhsSegment == rhsSegment && lhsIndex == rhsIndex
    case (
      .noMatchingElements(let lhsSegment, let lhsIndex),
      .noMatchingElements(let rhsSegment, let rhsIndex)
    ):
      lhsSegment == rhsSegment && lhsIndex == rhsIndex
    case (
      .ambiguousMatch(let lhsSegment, let lhsCount, let lhsIndex),
      .ambiguousMatch(let rhsSegment, let rhsCount, let rhsIndex),
    ):
      lhsSegment == rhsSegment && lhsCount == rhsCount && lhsIndex == rhsIndex
    case (
      .resolutionFailed(let lhsSegment, let lhsIndex, let lhsCandidates, let lhsReason),
      .resolutionFailed(let rhsSegment, let rhsIndex, let rhsCandidates, let rhsReason),
    ):
      lhsSegment == rhsSegment && lhsIndex == rhsIndex && lhsCandidates == rhsCandidates
        && lhsReason == rhsReason
    case (
      .applicationNotFound(let lhsApp, let lhsDetails),
      .applicationNotFound(let rhsApp, let rhsDetails)
    ):
      lhsApp == rhsApp && lhsDetails == rhsDetails
    case (
      .invalidAttributeFormat(let lhsAttr, let lhsFormat, let lhsIndex),
      .invalidAttributeFormat(let rhsAttr, let rhsFormat, let rhsIndex),
    ):
      lhsAttr == rhsAttr && lhsFormat == rhsFormat && lhsIndex == rhsIndex
    case (
      .pathTooComplex(let lhsPath, let lhsDetails), .pathTooComplex(let rhsPath, let rhsDetails)
    ):
      lhsPath == rhsPath && lhsDetails == rhsDetails
    case (
      .potentialAmbiguity(let lhsSegment, let lhsDetails, let lhsIndex),
      .potentialAmbiguity(let rhsSegment, let rhsDetails, let rhsIndex),
    ):
      lhsSegment == rhsSegment && lhsDetails == rhsDetails && lhsIndex == rhsIndex
    case (
      .missingAttribute(let lhsSegment, let lhsAttr, let lhsIndex),
      .missingAttribute(let rhsSegment, let rhsAttr, let rhsIndex),
    ):
      lhsSegment == rhsSegment && lhsAttr == rhsAttr && lhsIndex == rhsIndex
    case (
      .resolutionTimeout(let lhsSegment, let lhsIndex),
      .resolutionTimeout(let rhsSegment, let rhsIndex)
    ):
      lhsSegment == rhsSegment && lhsIndex == rhsIndex
    case (
      .insufficientPermissions(let lhsFeature, let lhsDetails),
      .insufficientPermissions(let rhsFeature, let rhsDetails),
    ):
      lhsFeature == rhsFeature && lhsDetails == rhsDetails
    case (
      .validationWarning(let lhsMessage, let lhsSuggestion),
      .validationWarning(let rhsMessage, let rhsSuggestion),
    ):
      lhsMessage == rhsMessage && lhsSuggestion == rhsSuggestion
    default:
      false
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
    if let index {
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

  /// The path ID prefix (macos://ui/)
  public static let pathPrefix = "macos://ui/"

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
  private static func parseSegment(_ segmentString: String, segmentIndex: Int) throws -> PathSegment
  {
    // Regular expressions for parsing
    let rolePattern = "^([A-Za-z0-9]+)"  // Captures the role name
    let attributePattern = "\\[@([^=]+)=\"((?:[^\"]|\\\\\")*)\"\\]"  // Captures attribute name and value
    let indexPattern = "\\[(\\d+)\\]"  // Captures the index (could be anywhere in the segment)

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
      let nameStartIndex = attributeString.index(attributeString.startIndex, offsetBy: 2)  // Skip [@
      let name = String(attributeString[nameStartIndex..<nameEndIndex])

      let valueStartIndex = attributeString.index(nameEndIndex, offsetBy: 2)  // Skip ="
      let valueEndIndex = attributeString.index(attributeString.endIndex, offsetBy: -2)  // Skip "]
      var value = String(attributeString[valueStartIndex..<valueEndIndex])

      // Unescape quotes in the value
      value = value.replacingOccurrences(of: "\\\"", with: "\"")

      // Normalize the attribute name during parsing
      let normalizedName = PathNormalizer.normalizeAttributeName(name)
      attributes[normalizedName] = value
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
    var segments = segments
    segments.append(contentsOf: newSegments)
    return try ElementPath(segments: segments)
  }

  /// Check if a string appears to be an element path
  /// - Parameter string: The string to check
  /// - Returns: True if the string looks like an element path
  public static func isElementPath(_ string: String) -> Bool {
    string.hasPrefix(pathPrefix)
  }

  /// Resolve this path to a UI element in the accessibility hierarchy
  /// - Parameter accessibilityService: The AccessibilityService to use for accessing the accessibility API
  /// - Returns: The AXUIElement that matches this path, or nil if no match is found
  /// - Throws: ElementPathError if there's an error resolving the path
  public func resolve(using accessibilityService: AccessibilityServiceProtocol) async throws
    -> AXUIElement
  {
    // Get the application element as starting point
    let startElement = try await getApplicationElement(accessibilityService)

    // Skip the first segment if it's an application (we've already matched it)
    let skipFirstSegment = segments[0].role == "AXApplication"
    let startSegmentIndex = skipFirstSegment ? 1 : 0
    
    // DIAGNOSTIC: Log application skipping logic
    logger.trace("DIAGNOSTIC: First segment role: \(segments[0].role), skipFirstSegment: \(skipFirstSegment), startSegmentIndex: \(startSegmentIndex)")

    // For simple cases (only the application), return immediately
    if segments.count == 1 || (skipFirstSegment && segments.count == 2) {
      logger.trace("DIAGNOSTIC: Simple case - returning start element directly (segments: \(segments.count), skipFirst: \(skipFirstSegment))")
      
      // Verify the start element
      var roleRef: CFTypeRef?
      let roleStatus = AXUIElementCopyAttributeValue(startElement, "AXRole" as CFString, &roleRef)
      if roleStatus == .success, let role = roleRef as? String {
        logger.trace("DIAGNOSTIC: Start element has role: \(role)")
      } else {
        logger.trace("DIAGNOSTIC: Warning - Start element role unavailable, status: \(roleStatus)")
      }
      
      return startElement
    }

    // Use BFS for path resolution
    logger.trace("DIAGNOSTIC: Starting BFS resolution with startIndex=\(startSegmentIndex), total segments=\(segments.count)")
    let result = try await resolveBFS(startElement: startElement, startIndex: startSegmentIndex)
    logger.trace("DIAGNOSTIC: BFS resolution succeeded")
    return result
  }

  /// Get the application element that serves as the starting point for path resolution
  /// - Parameter accessibilityService: The accessibility service to use
  /// - Returns: The application element to start path traversal from
  /// - Throws: ElementPathError if the application cannot be found or accessed
  private func getApplicationElement(_ accessibilityService: AccessibilityServiceProtocol)
    async throws
    -> AXUIElement
  {
    // DIAGNOSTIC: Add explicit application resolution logging
    logger.trace("DIAGNOSTIC: Starting application element resolution")
    // First segment should be the application or window element
    let firstSegment = segments[0]
    
    // DIAGNOSTIC: Log first segment details
    let attributesDebug = firstSegment.attributes.map { key, value in "\(key)=\"\(value)\"" }.joined(separator: ", ")
    logger.trace("DIAGNOSTIC: First segment role=\(firstSegment.role), attributes=[\(attributesDebug)], index=\(String(describing: firstSegment.index))")

    // For first segment, we need to get it differently depending on the role
    if firstSegment.role == "AXApplication" {
      logger.trace("DIAGNOSTIC: Processing AXApplication segment")
      // Try different approaches to find the application element

      // 1. Try by bundleIdentifier if provided
      if let bundleId = firstSegment.attributes["bundleIdentifier"] {
        logger.trace("DIAGNOSTIC: Trying to find application by bundleIdentifier: \(bundleId)")
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        logger.trace("DIAGNOSTIC: Found \(apps.count) running applications with bundleIdentifier: \(bundleId)")

        guard let app = apps.first else {
          logger.trace("DIAGNOSTIC: No running applications found with bundleIdentifier: \(bundleId)")
          // Get a list of running applications for better error messages
          let runningApps = NSWorkspace.shared.runningApplications
          var runningAppDetails: [String] = []

          for (i, app) in runningApps.prefix(10).enumerated() {
            var appInfo = "\(i + 1). "
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
            details:
              "Application with bundleIdentifier '\(bundleId)' is not running. Running applications are:\n"
              + runningAppDetails.joined(separator: "\n"),
          )
        }

        logger.trace("DIAGNOSTIC: Successfully found application with bundleIdentifier: \(bundleId), pid: \(app.processIdentifier)")
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // DIAGNOSTIC: Verify if the application element is valid by trying to get its role
        var roleRef: CFTypeRef?
        let roleStatus = AXUIElementCopyAttributeValue(appElement, "AXRole" as CFString, &roleRef)
        if roleStatus == .success, let role = roleRef as? String {
          logger.trace("DIAGNOSTIC: Created valid application element with role: \(role)")
        } else {
          logger.trace("DIAGNOSTIC: Warning - Created application element might not be valid, role fetch status: \(roleStatus)")
        }
        
        return appElement
      }
      // 2. Try by title/name if provided
      else if let title = firstSegment.attributes["title"] {
        logger.trace("DIAGNOSTIC: Trying to find application by title: \(title)")
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        logger.trace("DIAGNOSTIC: Searching among \(runningApps.count) running applications")

        // Find application with exactly matching title - only exact matches
        if let app = runningApps.first(where: { $0.localizedName == title }) {
          logger.debug("Found exact match for application title: \(title)")
          logger.trace("DIAGNOSTIC: Found exact match for application title: \(title), pid: \(app.processIdentifier)")
          let appElement = AXUIElementCreateApplication(app.processIdentifier)
          
          // DIAGNOSTIC: Verify if the application element is valid by trying to get its role
          var roleRef: CFTypeRef?
          let roleStatus = AXUIElementCopyAttributeValue(appElement, "AXRole" as CFString, &roleRef)
          if roleStatus == .success, let role = roleRef as? String {
            logger.trace("DIAGNOSTIC: Created valid application element with role: \(role)")
          } else {
            logger.trace("DIAGNOSTIC: Warning - Created application element might not be valid, role fetch status: \(roleStatus)")
          }
          
          return appElement
        } else {
          // No exact match, gather information about running apps
          var runningAppDetails: [String] = []

          for (i, app) in runningApps.prefix(10).enumerated() {
            var appInfo = "\(i + 1). "
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
            details: "Application with title '\(title)' not found. Running applications are:\n"
              + runningAppDetails.joined(separator: "\n"),
          )
        }
      }
      // 3. Use focused application as fallback
      else {
        logger.trace("DIAGNOSTIC: No bundleIdentifier or title provided, using focused application as fallback")
        do {
          logger.trace("DIAGNOSTIC: Attempting to get focused application from accessibility service")
          // Get the focused application from the accessibility service
          let focusedElement = try await accessibilityService.getFocusedApplicationUIElement(
            recursive: false,
            maxDepth: 1,
          )
          logger.trace("DIAGNOSTIC: Got focused element from accessibility service")

          // Check if we got a valid element
          guard let axElement = focusedElement.axElement else {
            logger.trace("DIAGNOSTIC: Failed to get AXElement from focused element")
            throw ElementPathError.segmentResolutionFailed(
              "Could not get focused application element",
              atSegment: 0,
            )
          }

          logger.trace("DIAGNOSTIC: Successfully got focused application element")
          
          // DIAGNOSTIC: Verify the focused application element
          var roleRef: CFTypeRef?
          let roleStatus = AXUIElementCopyAttributeValue(axElement, "AXRole" as CFString, &roleRef)
          if roleStatus == .success, let role = roleRef as? String {
            logger.trace("DIAGNOSTIC: Focused application element has role: \(role)")
          } else {
            logger.trace("DIAGNOSTIC: Warning - Focused application element might not be valid, role fetch status: \(roleStatus)")
          }
          
          // DIAGNOSTIC: Try to get application title for verification
          var titleRef: CFTypeRef?
          if AXUIElementCopyAttributeValue(axElement, "AXTitle" as CFString, &titleRef) == .success,
             let title = titleRef as? String {
            logger.trace("DIAGNOSTIC: Focused application has title: \(title)")
          }
          
          return axElement
        } catch {
          logger.trace("DIAGNOSTIC: Failed to get focused application from accessibility service: \(error)")
          logger.trace("DIAGNOSTIC: Trying to get frontmost application from NSWorkspace as fallback")
          
          // If that fails, try to get the frontmost application using NSWorkspace
          guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            logger.trace("DIAGNOSTIC: Failed to get frontmost application from NSWorkspace")
            throw ElementPathError.segmentResolutionFailed(
              "Could not determine frontmost application",
              atSegment: 0,
            )
          }

          logger.trace("DIAGNOSTIC: Using frontmost application: \(frontApp.localizedName ?? "Unknown"), pid: \(frontApp.processIdentifier)")
          let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
          
          // DIAGNOSTIC: Verify the frontmost application element
          var roleRef: CFTypeRef?
          let roleStatus = AXUIElementCopyAttributeValue(appElement, "AXRole" as CFString, &roleRef)
          if roleStatus == .success, let role = roleRef as? String {
            logger.trace("DIAGNOSTIC: Frontmost application element has role: \(role)")
          } else {
            logger.trace("DIAGNOSTIC: Warning - Frontmost application element might not be valid, role fetch status: \(roleStatus)")
          }
          
          return appElement
        }
      }
    }
    // For system-wide operations or other special starting points
    else if firstSegment.role == "AXSystemWide" {
      logger.trace("DIAGNOSTIC: Creating system-wide accessibility element")
      let sysElement = AXUIElementCreateSystemWide()
      logger.trace("DIAGNOSTIC: System-wide accessibility element created")
      return sysElement
    }
    // For any other element type as the first segment
    else {
      logger.trace("DIAGNOSTIC: First segment has unexpected role: \(firstSegment.role), using system-wide element as fallback")
      // Get the system-wide element as starting point for a broader search
      let sysElement = AXUIElementCreateSystemWide()
      logger.trace("DIAGNOSTIC: Created system-wide element as fallback starting point")
      return sysElement
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
  private func resolveBFS(
    startElement: AXUIElement,
    startIndex: Int,
    maxDepth: Int = 50,
  ) async throws -> AXUIElement {
    // Create a queue for BFS
    var queue = [
      PathNode(
        element: startElement,
        segmentIndex: startIndex,
        pathSoFar: segments[0].toString(),
      )
    ]

    // Set to track visited elements and avoid cycles
    var visited = Set<UInt>()

    // Track which segment is failing for better error reporting
    var failedSegmentIndex = startIndex

    // Add depth tracking
    var depth = 0

    // Add detailed logging
    logger.trace("==== BFS PATH RESOLUTION DEBUG ====")
    logger.trace(
      "BFS path resolution starting",
      metadata: [
        "path": "\(toString())",
        "startIndex": "\(startIndex)",
        "totalSegments": "\(segments.count)",
        "initialSegment": "\(segments[0].toString())",
      ])

    // Breadth-first search loop
    while !queue.isEmpty, depth < maxDepth {
      // Track depth for timeout detection
      depth += 1
      logger.trace(
        "BFS processing", metadata: ["depth": "\(depth)", "queueSize": "\(queue.count)"])
      
      if depth % 10 == 0 {
        logger.trace("DIAGNOSTIC: BFS processing depth \(depth) with queue size \(queue.count)")
      }

      // Dequeue the next node to process
      let node = queue.removeFirst()

      // Get element details for debugging
      var roleRef: CFTypeRef?
      let roleStatus = AXUIElementCopyAttributeValue(node.element, "AXRole" as CFString, &roleRef)
      let role = (roleStatus == .success) ? (roleRef as? String ?? "unknown") : "unknown"

      logger.trace(
        "Exploring node",
        metadata: [
          "segmentIndex": "\(node.segmentIndex)", "role": "\(role)", "path": "\(node.pathSoFar)",
        ],
      )
      
      // DIAGNOSTIC: Add more detailed element logging for key points
      if node.segmentIndex <= 2 || node.segmentIndex >= segments.count - 1 { // First or last segments
        logger.trace("DIAGNOSTIC: Exploring element with role=\(role), segmentIndex=\(node.segmentIndex), depth=\(depth)")
        
        // Try to get more identifying information
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(node.element, "AXTitle" as CFString, &titleRef) == .success,
           let title = titleRef as? String, !title.isEmpty {
          logger.trace("DIAGNOSTIC: Element title: \(title)")
        }
        
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(node.element, "AXDescription" as CFString, &descRef) == .success,
           let desc = descRef as? String, !desc.isEmpty {
          logger.trace("DIAGNOSTIC: Element description: \(desc)")
        }
      }

      // Track visited nodes by memory address to avoid cycles
      let elementID = UInt(bitPattern: Unmanaged.passUnretained(node.element).toOpaque())
      if visited.contains(elementID) {
        logger.trace("Skipping visited element", metadata: ["elementID": "\(elementID)"])
        continue
      }
      visited.insert(elementID)
      logger.trace(
        "Marked element as visited",
        metadata: ["elementID": "\(elementID)", "totalVisited": "\(visited.count)"],
      )
      
      // DIAGNOSTIC: Log cycle detection for key elements
      if node.segmentIndex <= 2 { // First few segments
        logger.trace("DIAGNOSTIC: Element ID=\(elementID) at segmentIndex=\(node.segmentIndex) marked as visited, cycle detection active")
      }

      // Check if we've reached the end of the path
      if node.segmentIndex >= segments.count {
        logger.trace("SUCCESS - Reached end of path! All segments matched.")
        logger.trace("==== END BFS DEBUG ====\n")
        logger.trace("DIAGNOSTIC: Path resolution succeeded! Found matching element at depth \(depth)")
        
        // DIAGNOSTIC: Get final element details
        var titleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(node.element, "AXTitle" as CFString, &titleRef) == .success,
           let title = titleRef as? String {
          logger.trace("DIAGNOSTIC: Final element title: \(title)")
        }
        
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(node.element, "AXDescription" as CFString, &descRef) == .success,
           let desc = descRef as? String {
          logger.trace("DIAGNOSTIC: Final element description: \(desc)")
        }
        
        var positionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(node.element, "AXPosition" as CFString, &positionRef) == .success,
           CFGetTypeID(positionRef!) == AXValueGetTypeID() {
           var position = CGPoint.zero
           AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
           logger.trace("DIAGNOSTIC: Final element position: (\(position.x), \(position.y))")
        }
        
        return node.element
      }

      // Get the current segment we're trying to match
      let currentSegment = segments[node.segmentIndex]
      logger.trace(
        "Current segment",
        metadata: ["index": "\(node.segmentIndex)", "segment": "\(currentSegment.toString())"],
      )

      // Update the failed segment index to the deepest segment we've tried
      failedSegmentIndex = max(failedSegmentIndex, node.segmentIndex)

      // Get children of the current element to explore
      guard let children = getChildElements(of: node.element) else {
        // print("DEBUG: No children found for this element")
        continue
      }
      // print("DEBUG: Found \(children.count) children to check")

      // If the segment specifies an index, we need to collect all matches first
      if currentSegment.index != nil {
        // print("DEBUG: Index-based segment detected with index \(String(describing: currentSegment.index))")
        // Collect all matches for indexed selection
        var matches: [(element: AXUIElement, path: String)] = []

        for (_, child) in children.enumerated() {
          // Get child role for debugging
          var childRoleRef: CFTypeRef?
          let childRoleStatus = AXUIElementCopyAttributeValue(
            child, "AXRole" as CFString, &childRoleRef)
          _ = (childRoleStatus == .success) ? (childRoleRef as? String ?? "unknown") : "unknown"

          // print("DEBUG: Checking child: role info")

          if try await elementMatchesSegment(child, segment: currentSegment, segmentIndex: node.segmentIndex) {
            let newPath = node.pathSoFar + "/" + currentSegment.toString()
            matches.append((child, newPath))
            // print("DEBUG: MATCH FOUND! Child matches segment \(currentSegment.toString())")
          }
        }

        // print("DEBUG: Found \(matches.count) matching children for indexed segment")

        // Now apply index selection if we found any matches
        if !matches.isEmpty {
          if let index = currentSegment.index {
            // Validate the index is in range
            if index < 0 || index >= matches.count {
              // print("DEBUG: ERROR - Index \(index) is out of range (0..\(matches.count-1))")
              throw ElementPathError.invalidIndexSyntax(
                "Index \(index) is out of range (0..\(matches.count - 1))",
                atSegment: node.segmentIndex,
              )
            }

            // Get the element at the specified index
            let (matchedElement, matchedPath) = matches[index]
            // print("DEBUG: Selected match at index \(index)")

            // Get matched element role for debugging
            var matchedRoleRef: CFTypeRef?
            let matchedRoleStatus = AXUIElementCopyAttributeValue(
              matchedElement,
              "AXRole" as CFString,
              &matchedRoleRef,
            )
            _ = (matchedRoleStatus == .success) ? (matchedRoleRef as? String ?? "unknown") : "unknown"

            // If this is the last segment, we've found our match
            if node.segmentIndex == segments.count - 1 {
              // print("DEBUG: SUCCESS - Found final element")
              // print("==== END BFS DEBUG ====\n")
              return matchedElement
            }

            // Otherwise add to queue for further processing
            // print("DEBUG: Adding matched element (role=\(matchedRole)) to queue with next segment index \(node.segmentIndex + 1)")
            queue.append(
              PathNode(
                element: matchedElement,
                segmentIndex: node.segmentIndex + 1,
                pathSoFar: matchedPath,
              ))
          }
        } else {
          // print("DEBUG: No matches found for indexed segment")
        }
      } else {
        // No index specified, process all matching children normally
        var matchCount = 0

        for (_, child) in children.enumerated() {
          // Get child role for debugging
          var childRoleRef: CFTypeRef?
          let childRoleStatus = AXUIElementCopyAttributeValue(
            child, "AXRole" as CFString, &childRoleRef)
          _ = (childRoleStatus == .success) ? (childRoleRef as? String ?? "unknown") : "unknown"

          // These attribute fetching operations commented out since they're only used for debugging
          // Uncomment if needed for debugging in the future
          /*
          // Get other key attributes for debugging
          var descRef: CFTypeRef?
          let descStatus = AXUIElementCopyAttributeValue(
            child, "AXDescription" as CFString, &descRef)
          
          var idRef: CFTypeRef?
          let idStatus = AXUIElementCopyAttributeValue(child, "AXIdentifier" as CFString, &idRef)
          */

          // print("DEBUG: Checking child: role info available when debugging enabled")

          if try await elementMatchesSegment(child, segment: currentSegment, segmentIndex: node.segmentIndex) {
            matchCount += 1
            // Create path to this point for debugging
            let newPath = node.pathSoFar + "/" + currentSegment.toString()
            // print("DEBUG: MATCH FOUND! Child matches segment \(currentSegment.toString())")

            // If this is the last segment, we've found our match
            if node.segmentIndex == segments.count - 1 {
              // print("DEBUG: SUCCESS - Found final element")
              // print("==== END BFS DEBUG ====\n")
              return child
            }

            // Otherwise, add child to queue with next segment index
            // print("DEBUG: Adding matched element to queue with next segment index \(node.segmentIndex + 1)")
            queue.append(
              PathNode(
                element: child,
                segmentIndex: node.segmentIndex + 1,
                pathSoFar: newPath,
              ))
          }
        }

        // print("DEBUG: Found \(matchCount) matching children for segment \(currentSegment.toString())")
      }
    }

    // Check if we hit max depth
    if depth >= maxDepth {
      // print("DEBUG: ERROR - Exceeded maximum depth of \(maxDepth)")
      // print("==== END BFS DEBUG ====\n")
      throw ElementPathError.resolutionTimeout(
        "Path resolution exceeded maximum depth (\(maxDepth))",
        atSegment: failedSegmentIndex,
      )
    }

    // If we've explored all possibilities and found no match, enhance error reporting
    logger.trace("==== END BFS DEBUG ====\n")

    // Special error handling for generic containers like AXGroup
    let segment = segments[failedSegmentIndex]
    let isGenericContainer =
      (segment.role == "AXGroup" || segment.role == "AXBox" || segment.role == "AXGeneric" || segment.role == "AXSplitGroup")
    
    // Enhanced info for AXIdentifier-specific failures in generic containers
    if isGenericContainer && segment.attributes.count == 1 && segment.attributes.keys.contains("AXIdentifier") {
      let expectedIdentifier = segment.attributes["AXIdentifier"]!
      logger.trace("DIAGNOSTIC: Failed to match AXIdentifier=\(expectedIdentifier) for \(segment.role) at index \(failedSegmentIndex)")
      logger.trace("DIAGNOSTIC: This may be due to inconsistent identifier attribute naming.")
      logger.trace("DIAGNOSTIC: You may want to try a simpler path without AXIdentifier or use an index instead.")
    }

    if isGenericContainer {
      // Enhanced debug information specifically for AXGroup segments
      // Gather all available attributes of the potential children to see what's available
      var debugInfo = "Generic container resolution failure debugging:"

      // Get all children at the current level for debugging
      let latestNode = queue.last
      if let element = latestNode?.element {
        // First log the failing segment details
        logger.trace("DETAILED DIAGNOSIS: Failing to match segment \(segment.toString())")
        let segmentAttributes = segment.attributes.map { key, value in "\(key)=\(value)" }.joined(separator: ", ")
        logger.trace("DETAILED DIAGNOSIS: Segment attributes: \(segmentAttributes)")
        
        // Try to get detailed information about the element we're searching from
        var parentRoleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &parentRoleRef) == .success,
           let parentRole = parentRoleRef as? String {
          logger.trace("DETAILED DIAGNOSIS: Parent element role: \(parentRole)")
          
          // Get other identifying attributes for the parent
          for attr in ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"] {
            var attrRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &attrRef) == .success,
               let value = attrRef as? String, !value.isEmpty {
              logger.trace("DETAILED DIAGNOSIS: Parent \(attr): \(value)")
            }
          }
        }
        
        // Get the complete set of available attributes on the parent
        var parentAttrNamesRef: CFArray?
        if AXUIElementCopyAttributeNames(element, &parentAttrNamesRef) == .success,
           let parentAttrNames = parentAttrNamesRef as? [String] {
          logger.trace("DETAILED DIAGNOSIS: Parent has \(parentAttrNames.count) attributes: \(parentAttrNames.joined(separator: ", "))")
        }
        
        // Now examine the children in detail
        var childrenRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)

        if status == .success, let children = childrenRef as? [AXUIElement] {
          debugInfo += "\nFound \(children.count) children at this level. "
          logger.trace("DETAILED DIAGNOSIS: Parent has \(children.count) children")

          // Get attributes for all AXGroup-like children (or any type if failingSegmentIndex is 0)
          var potentialMatches: [(Int, AXUIElement, String, [String: String])] = []

          for (i, child) in children.enumerated() {
            var roleRef: CFTypeRef?
            let roleStatus = AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &roleRef)

            if roleStatus == .success, let role = roleRef as? String {
              // When inspecting the first segment, or when looking for generic containers,
              // show all children to help with diagnosis
              let isRelevantForGroup = (role == "AXGroup" || role == "AXBox" || 
                                      role == "AXGeneric" || role == "AXSplitGroup")
              
              if isRelevantForGroup || failedSegmentIndex == 0 || 
                 (role == segment.role) {
                var attributes: [String: String] = [:]
                let attributesToCheck = ["AXRole", "AXDescription", "AXTitle", 
                                       "AXIdentifier", "AXValue", "AXPosition", "AXSize"]

                for attr in attributesToCheck {
                  var attrRef: CFTypeRef?
                  let attrStatus = AXUIElementCopyAttributeValue(child, attr as CFString, &attrRef)

                  if attrStatus == .success {
                    // Convert different attribute types to string
                    if let strValue = attrRef as? String {
                      attributes[attr] = strValue
                    } else if let numValue = attrRef as? NSNumber {
                      attributes[attr] = numValue.stringValue
                    } else if let boolValue = attrRef as? Bool {
                      attributes[attr] = boolValue ? "true" : "false"
                    } else if attr == "AXPosition" || attr == "AXSize" {
                      // Special handling for geometry values
                      if let valueRef = attrRef, CFGetTypeID(valueRef) == AXValueGetTypeID() {
                        let axValue = valueRef as! AXValue
                        if attr == "AXPosition" {
                          var point = CGPoint.zero
                          AXValueGetValue(axValue, .cgPoint, &point)
                          attributes[attr] = "(\(point.x), \(point.y))"
                        } else if attr == "AXSize" {
                          var size = CGSize.zero
                          AXValueGetValue(axValue, .cgSize, &size)
                          attributes[attr] = "(\(size.width), \(size.height))"
                        }
                      }
                    } else {
                      attributes[attr] = String(describing: attrRef!)
                    }
                  }
                }

                potentialMatches.append((i, child, role, attributes))
                
                // For AXGroup elements, try to also get their children
                if isRelevantForGroup {
                  var groupChildrenRef: CFTypeRef?
                  if AXUIElementCopyAttributeValue(child, "AXChildren" as CFString, &groupChildrenRef) == .success,
                     let groupChildren = groupChildrenRef as? [AXUIElement], !groupChildren.isEmpty {
                    
                    logger.trace("DETAILED DIAGNOSIS: AXGroup child \(i) has \(groupChildren.count) children")
                    
                    // Log the role of each child in the group
                    for (j, groupChild) in groupChildren.prefix(5).enumerated() {
                      var groupChildRoleRef: CFTypeRef?
                      if AXUIElementCopyAttributeValue(groupChild, "AXRole" as CFString, &groupChildRoleRef) == .success,
                         let groupChildRole = groupChildRoleRef as? String {
                        logger.trace("DETAILED DIAGNOSIS:   Group \(i) child \(j) role: \(groupChildRole)")
                        
                        // If the child is the right type, get detailed attributes
                        if groupChildRole == segment.role || 
                           (segment.role == "AXGroup" && isRelevantForGroup) {
                          for attr in ["AXDescription", "AXTitle", "AXIdentifier", "AXValue"] {
                            var attrRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(groupChild, attr as CFString, &attrRef) == .success,
                               let value = attrRef as? String, !value.isEmpty {
                              logger.trace("DETAILED DIAGNOSIS:     \(attr): \(value)")
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          debugInfo += "\nExamined \(potentialMatches.count) potential matches:"
          for (i, _, role, attrs) in potentialMatches {
            debugInfo += "\n  Child \(i) (\(role)): "
            for (key, value) in attrs.sorted(by: { $0.key < $1.key }) {
              debugInfo += "\(key)=\"\(value)\", "
            }
          }
          
          // Log the most relevant information - role matching children first
          let roleMatchingElements = potentialMatches.filter { $0.2 == segment.role }
          if !roleMatchingElements.isEmpty {
            logger.trace("DETAILED DIAGNOSIS: Found \(roleMatchingElements.count) elements with matching role '\(segment.role)'")
            
            for (i, _, _, attrs) in roleMatchingElements.prefix(3) {
              let attrStr = attrs.map { key, value in "\(key)=\"\(value)\"" }.joined(separator: ", ")
              logger.trace("DETAILED DIAGNOSIS: Matching role element \(i): \(attrStr)")
            }
          } else {
            logger.trace("DETAILED DIAGNOSIS: No elements found with matching role '\(segment.role)'")
            
            // Show what roles are available for reference
            let availableRoles = Set(potentialMatches.map { $0.2 })
            logger.trace("DETAILED DIAGNOSIS: Available roles: \(availableRoles.joined(separator: ", "))")
          }
        }
      }

      logger.trace("\(debugInfo)")

      throw ElementPathError.segmentResolutionFailed(
        "Could not find generic container element matching segment: \(segment.toString()). Generic containers like AXGroup may require position-based matching or more specific attributes.",
        atSegment: failedSegmentIndex,
      )
    } else {
      throw ElementPathError.segmentResolutionFailed(
        "Could not find elements matching segment: \(segment.toString())",
        atSegment: failedSegmentIndex,
      )
    }
  }

  /// Resolve a single segment of a path starting from a given element
  /// - Parameters:
  ///   - element: The starting element
  ///   - segment: The path segment to resolve
  ///   - segmentIndex: The index of the segment in the overall path (for error reporting)
  /// - Returns: The resolved element matching the segment, or nil if no match is found
  /// - Throws: ElementPathError if there's an error resolving the segment
  public func resolveSegment(
    element: AXUIElement,
    segment: PathSegment,
    segmentIndex: Int,
  ) async throws -> AXUIElement? {
    // Get the children of the current element
    var childrenRef: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)

    // Check if we could get children
    if status != .success || childrenRef == nil {
      let segmentString = segment.toString()
      throw ElementPathError.segmentResolutionFailed(
        "Could not get children for segment: \(segmentString)",
        atSegment: segmentIndex,
      )
    }

    // Cast to array of elements
    guard let children = childrenRef as? [AXUIElement] else {
      let segmentString = segment.toString()
      throw ElementPathError.segmentResolutionFailed(
        "Children not in expected format for segment: \(segmentString)",
        atSegment: segmentIndex,
      )
    }

    // Filter children by role to find potential matches
    var matches: [AXUIElement] = []

    for child in children {
      // Check if this child matches the segment
      if try await elementMatchesSegment(child, segment: segment, segmentIndex: segmentIndex) {
        matches.append(child)
      }
    }

    // Handle based on number of matches and whether an index was specified
    if matches.isEmpty {
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
      
      // Special handling for generic container errors
      let isGenericContainer = (segment.role == "AXGroup" || segment.role == "AXBox" || 
                              segment.role == "AXGeneric" || segment.role == "AXSplitGroup")
      
      let segmentString = segment.toString()
      var reason = "No elements match this segment. Available children are shown below."
      
      // Enhanced error for AXGroup elements
      if isGenericContainer {
        // Add specific suggestions for generic containers
        let containsAXIdentifier = segment.attributes.keys.contains("AXIdentifier")
        
        if containsAXIdentifier {
          reason = "No generic containers match this segment with the specified AXIdentifier. " +
                  "Consider simplifying the path by using the segment without AXIdentifier or using an index instead."
        } else if segment.attributes.isEmpty {
          reason = "No generic containers match this segment. " +
                  "Generic containers like AXGroup often require an index (e.g., AXGroup[0]) for reliable resolution."
        }
      }
      
      throw ElementPathError.resolutionFailed(
        segment: segmentString,
        index: segmentIndex,
        candidates: availableChildren,
        reason: reason,
      )
    } else if segment.index != nil {
      // Segment has an index specified, validate and use it
      guard let index = segment.index else {
        // This should never happen since we just checked for it
        return matches[0]
      }

      // Validate the index is in range
      if index < 0 || index >= matches.count {
        throw ElementPathError.invalidIndexSyntax(
          "Index \(index) is out of range (0..\(matches.count - 1))",
          atSegment: segmentIndex,
        )
      }

      // Return the element at the specified index
      return matches[index]
    } else if matches.count == 1 {
      // Single match without index - straightforward case
      return matches[0]
    } else {
      // Multiple matches and no index specified - this is ambiguous
      let segmentString = segment.toString()

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
        reason:
          "Multiple elements (\(matches.count)) match this segment. Add more specific attributes or use an index.",
      )
    }
  }

  /// Check if an element matches a path segment
  /// - Parameters:
  ///   - element: The element to check
  ///   - segment: The path segment to match against
  /// - Returns: True if the element matches the segment
  private func elementMatchesSegment(_ element: AXUIElement, segment: PathSegment, segmentIndex: Int? = nil) async throws
    -> Bool
  {
    // DIAGNOSTIC: Get debug environment flags
    let enableDetailedDebug = ProcessInfo.processInfo.environment["MCP_PATH_RESOLUTION_DEBUG"] == "true"
    let enableAttributeMatchingDebug = ProcessInfo.processInfo.environment["MCP_ATTRIBUTE_MATCHING_DEBUG"] == "true"
    
    // Element ID for debugging
    let elementID = UInt(bitPattern: Unmanaged.passUnretained(element).toOpaque())
    logger.trace("Matching element \(elementID) against segment \(segment.toString())")
    
    if enableDetailedDebug {
      logger.trace("DETAILED PATH RESOLUTION: Testing element \(elementID) against segment \(segment.toString())")
    }

    // Check role first - this is the primary type matcher
    var roleRef: CFTypeRef?
    let roleStatus = AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &roleRef)

    if roleStatus != .success || roleRef == nil {
      logger.trace("Element has no role or couldn't access role")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: Element has no role or couldn't access role, status: \(getAXErrorName(roleStatus))")
      }
      return false
    }

    guard let role = roleRef as? String else {
      logger.trace("Element role is not a string value")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: Element role is not a string value")
      }
      return false
    }

    logger.trace("Element role = \(role), segment role = \(segment.role)")
    if enableDetailedDebug {
      logger.trace("DETAILED PATH RESOLUTION: Element role = \(role), segment role = \(segment.role)")
      
      // Get other key attributes for additional context
      var elementDescription = ""
      var titleRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &titleRef) == .success,
         let title = titleRef as? String, !title.isEmpty {
        elementDescription += " title=\"\(title)\""
      }
      
      var descRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXDescription" as CFString, &descRef) == .success,
         let desc = descRef as? String, !desc.isEmpty {
        elementDescription += " desc=\"\(desc)\""
      }
      
      var idRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXIdentifier" as CFString, &idRef) == .success,
         let id = idRef as? String, !id.isEmpty {
        elementDescription += " id=\"\(id)\""
      }
      
      var positionRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
         CFGetTypeID(positionRef!) == AXValueGetTypeID() {
         var position = CGPoint.zero
         AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
         elementDescription += " pos=(\(position.x), \(position.y))"
      }
      
      if !elementDescription.isEmpty {
        logger.trace("DETAILED PATH RESOLUTION: Element details:\(elementDescription)")
      }
    }

    // Check role match - be more tolerant with role matching (optionally strip 'AX' prefix)
    let normalizedSegmentRole = segment.role.hasPrefix("AX") ? segment.role : "AX\(segment.role)"
    let normalizedElementRole = role.hasPrefix("AX") ? role : "AX\(role)"

    if role != segment.role, normalizedElementRole != normalizedSegmentRole {
      logger.trace("ROLE MISMATCH - Element role doesn't match segment role")
      logger.trace("Element: \(role), Segment: \(segment.role)")
      logger.trace(
        "Normalized Element: \(normalizedElementRole), Normalized Segment: \(normalizedSegmentRole)"
      )
      
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: ROLE MISMATCH")
        logger.trace("DETAILED PATH RESOLUTION: Element role: \(role), Segment role: \(segment.role)")
        logger.trace("DETAILED PATH RESOLUTION: Normalized Element: \(normalizedElementRole), Normalized Segment: \(normalizedSegmentRole)")
      }
      
      return false
    }

    logger.trace("ROLE MATCH OK ✓")
    if enableDetailedDebug {
      logger.trace("DETAILED PATH RESOLUTION: ROLE MATCH SUCCESSFUL ✓")
    }

    // If there are no attributes to match, we're done
    if segment.attributes.isEmpty {
      logger.trace("No attributes to check, match successful ✓")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: No attributes to check, match successful ✓")
      }
      return true
    }

    // Check each attribute - ALL must match for a successful match
    logger.trace("Checking attributes (\(segment.attributes.count) total):")
    if enableDetailedDebug {
      logger.trace("DETAILED PATH RESOLUTION: Checking \(segment.attributes.count) attributes")
    }
    
    let isSegmentParentOfButton = segmentIndex != nil && segmentIndex == segments.count - 2
    let isSegmentOfInterest = segmentIndex != nil && (segmentIndex == 0 || segmentIndex == 1 || isSegmentParentOfButton)
    let isButtonSegment = segment.role == "AXButton" || segment.role == "Button"
    
    // Log special segment checks to help with troubleshooting
    if enableDetailedDebug && (isSegmentOfInterest || isButtonSegment) {
      logger.trace("DETAILED PATH RESOLUTION: Special segment of interest at index \(segmentIndex ?? -1), isButtonSegment=\(isButtonSegment)")
    }
    
    for (name, expectedValue) in segment.attributes {
      logger.trace("Checking attribute \(name) with expected value \"\(expectedValue)\"")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: Checking attribute \(name) with expected value \"\(expectedValue)\"")
      }

      // Get normalized attribute name
      let normalizedName = getNormalizedAttributeName(name)
      logger.trace("Using normalized attribute name: \(normalizedName)")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: Using normalized attribute name: \(normalizedName)")
      }

      // For generic containers like AXGroup, we need additional debugging
      let role = segment.role
      let isGenericContainer = (role == "AXGroup" || role == "AXBox" || role == "AXGeneric" || role == "AXSplitGroup")

      if isGenericContainer || enableAttributeMatchingDebug {
        logger.trace("DIAGNOSTIC: Processing \(isGenericContainer ? "generic container" : "regular") element \(role) with attributes: \(segment.attributes)")
        
        // Dump all available attributes on this element for diagnostic purposes
        var attrNamesRef: CFArray?
        let attrNamesResult = AXUIElementCopyAttributeNames(element, &attrNamesRef)
        
        if attrNamesResult == .success, let attrNames = attrNamesRef as? [String] {
          logger.trace("DIAGNOSTIC: Available attributes on this \(role):")
          
          // Track the keys we need to be checking
          var matchingAttributes: [String: String] = [:]
          
          // Check for normalized versions of the attribute we're looking for
          for attrName in attrNames {
            // This helps diagnose when the attribute might be available under a different name
            let normalizedAttrName = getNormalizedAttributeName(attrName)
            if normalizedAttrName == normalizedName || attrName == normalizedName {
              matchingAttributes[attrName] = "MATCHING KEY"
            } else if normalizedAttrName == "AX\(normalizedName)" || attrName == "AX\(normalizedName)" {
              matchingAttributes[attrName] = "MATCHING KEY (with AX prefix)"
            } else if normalizedAttrName == normalizedName.dropFirst(2) || attrName == normalizedName.dropFirst(2) {
              matchingAttributes[attrName] = "MATCHING KEY (without AX prefix)"
            }
          }
          
          // Log matching attributes first, then others
          for attrName in attrNames {
            var attrValueRef: CFTypeRef?
            let attrValueResult = AXUIElementCopyAttributeValue(element, attrName as CFString, &attrValueRef)
            
            var valueDesc = "<failed to read value>"
            var isAttributeOfInterest = false
            
            if attrValueResult == .success, let attrValue = attrValueRef {
              if let stringValue = attrValue as? String {
                valueDesc = "String: \"\(stringValue)\""
                
                // Check if this is close to what we're looking for
                if stringValue == expectedValue {
                  isAttributeOfInterest = true
                  valueDesc += " [EXACT MATCH WITH EXPECTED VALUE]"
                } else if stringValue.contains(expectedValue) || expectedValue.contains(stringValue) {
                  isAttributeOfInterest = true
                  valueDesc += " [PARTIAL MATCH WITH EXPECTED VALUE]"
                }
              } else if let numValue = attrValue as? NSNumber {
                valueDesc = "Number: \(numValue)"
                // Check for numeric match
                if numValue.stringValue == expectedValue {
                  isAttributeOfInterest = true
                  valueDesc += " [MATCH WITH EXPECTED VALUE]"
                }
              } else if let boolValue = attrValue as? Bool {
                valueDesc = "Bool: \(boolValue)"
                // Check for boolean match
                if (boolValue && expectedValue == "true") || (!boolValue && expectedValue == "false") {
                  isAttributeOfInterest = true
                  valueDesc += " [MATCH WITH EXPECTED VALUE]"
                }
              } else if attrName == "AXPosition" || attrName == "AXSize", 
                        CFGetTypeID(attrValue) == AXValueGetTypeID() {
                if attrName == "AXPosition" {
                  var point = CGPoint.zero
                  AXValueGetValue(attrValue as! AXValue, .cgPoint, &point)
                  valueDesc = "Position: (\(point.x), \(point.y))"
                } else {
                  var size = CGSize.zero
                  AXValueGetValue(attrValue as! AXValue, .cgSize, &size)
                  valueDesc = "Size: (\(size.width), \(size.height))"
                }
              } else {
                let fullDesc = String(describing: attrValue)
                valueDesc = fullDesc.count > 100 ? "Object: \(fullDesc.prefix(100))..." : "Object: \(fullDesc)"
              }
            }
            
            // Log attributes with special formatting for ones we're interested in
            var attributeLabel = "  - \(attrName): "
            if matchingAttributes[attrName] != nil {
              attributeLabel = "  - \(attrName) [KEY MATCH]: "
              isAttributeOfInterest = true
            }
            
            if isAttributeOfInterest || isGenericContainer || enableAttributeMatchingDebug {
              logger.trace("DIAGNOSTIC:\(attributeLabel)\(valueDesc)")
            }
          }
        } else {
          logger.trace("DIAGNOSTIC: Failed to get attribute names, error: \(getAXErrorName(attrNamesResult))")
        }
        
        // For generic containers, also look at children to help diagnose issues
        if isGenericContainer {
          // Try to get children information for this container
          var childrenRef: CFTypeRef?
          let childrenResult = AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &childrenRef)
          
          if childrenResult == .success, let children = childrenRef as? [AXUIElement] {
            logger.trace("DIAGNOSTIC: Generic container has \(children.count) children")
            
            // Log details of the first few children
            for (i, child) in children.prefix(7).enumerated() {
              var childRoleRef: CFTypeRef?
              if AXUIElementCopyAttributeValue(child, "AXRole" as CFString, &childRoleRef) == .success,
                 let childRole = childRoleRef as? String {
                logger.trace("DIAGNOSTIC:   Child \(i) role: \(childRole)")
                
                // For important attributes, try to log them too
                for attr in ["AXDescription", "AXTitle", "AXIdentifier", "AXValue"] {
                  var attrRef: CFTypeRef?
                  if AXUIElementCopyAttributeValue(child, attr as CFString, &attrRef) == .success,
                     let value = attrRef as? String, !value.isEmpty {
                    logger.trace("DIAGNOSTIC:     - \(attr): \(value)")
                  }
                }
                
                // For buttons, look deeper for calculator buttons
                if childRole == "AXButton" && segmentIndex != nil && (segmentIndex == 3 || segmentIndex == 4) {
                  logger.trace("DIAGNOSTIC:     [Button in AXGroup - potential calculator button]")
                  
                  // This is a critical debug point for calculator buttons - check position
                  var positionRef: CFTypeRef?
                  if AXUIElementCopyAttributeValue(child, "AXPosition" as CFString, &positionRef) == .success,
                     CFGetTypeID(positionRef!) == AXValueGetTypeID() {
                     var position = CGPoint.zero
                     AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
                     logger.trace("DIAGNOSTIC:     - Position: (\(position.x), \(position.y))")
                  }
                }
              }
            }
          } else {
            logger.trace("DIAGNOSTIC: Failed to get children of generic container, error: \(getAXErrorName(childrenResult))")
          }
        }
      }

      // Get the actual value for detailed logging
      var attributeRef: CFTypeRef?
      let attributeStatus = AXUIElementCopyAttributeValue(
        element, normalizedName as CFString, &attributeRef)

      if attributeStatus != .success || attributeRef == nil {
        logger.trace("No value for attribute \(normalizedName)")
        if enableDetailedDebug {
          logger.trace("DETAILED PATH RESOLUTION: Failed to get attribute \(normalizedName), status: \(getAXErrorName(attributeStatus))")
          
          // Try different prefix variants as diagnostic info
          if normalizedName.hasPrefix("AX") {
            // Try without AX prefix
            let withoutAXPrefix = String(normalizedName.dropFirst(2))
            var altAttrRef: CFTypeRef?
            let altResult = AXUIElementCopyAttributeValue(element, withoutAXPrefix as CFString, &altAttrRef)
            if altResult == .success, altAttrRef != nil {
              logger.trace("DETAILED PATH RESOLUTION: Found value with alternate attribute name WITHOUT AX prefix: \(withoutAXPrefix)")
            }
          } else {
            // Try with AX prefix
            let withAXPrefix = "AX\(normalizedName)"
            var altAttrRef: CFTypeRef?
            let altResult = AXUIElementCopyAttributeValue(element, withAXPrefix as CFString, &altAttrRef)
            if altResult == .success, altAttrRef != nil {
              logger.trace("DETAILED PATH RESOLUTION: Found value with alternate attribute name WITH AX prefix: \(withAXPrefix)")
            }
          }
        }

        // Special handling for failing to find attributes on generic containers
        if isGenericContainer, segment.attributes.count == 1 {
          // For generic containers with only one attribute, if it fails to match, check if this might be
          // a structural container element that should match just based on role
          logger.trace("Generic container match consideration - may need position-based matching")
          if enableDetailedDebug {
            logger.trace("DETAILED PATH RESOLUTION: Generic container match consideration - may need position-based matching")
          }

          // If we have an index specified, we should still find a match
          if segment.index != nil {
            logger.trace("Has index - will use position-based matching")
            if enableDetailedDebug {
              logger.trace("DETAILED PATH RESOLUTION: Generic container has index - will use position-based matching")
            }
            return true
          }
          
          // Special handling for AXIdentifier attribute
          // Try matching with different variants of identifier attributes
          if segment.attributes.keys.contains("AXIdentifier") {
            let expectedIdentifier = segment.attributes["AXIdentifier"]!
            logger.trace("DETAILED PATH RESOLUTION: Trying alternate identifier matching for \(expectedIdentifier)")
            
            // Try using different variations of identifier attribute names
            for altIdAttr in ["identifier", "Identifier"] {
              var altIdRef: CFTypeRef?
              let altIdStatus = AXUIElementCopyAttributeValue(element, altIdAttr as CFString, &altIdRef)
              
              if altIdStatus == .success, let altIdValue = altIdRef as? String {
                if altIdValue == expectedIdentifier {
                  logger.trace("DETAILED PATH RESOLUTION: Found match on alternate identifier attribute '\(altIdAttr)' with value '\(altIdValue)'")
                  return true
                }
              }
            }
          }
          
          // For AXGroups that are parents of AXButtons or structural elements, be more lenient
          if let unwrappedIndex = segmentIndex, unwrappedIndex < segments.count - 1 {
            // Check if the next segment is a button or other common interactive element
            let nextSegment = segments[unwrappedIndex + 1]
            if nextSegment.role == "AXButton" || nextSegment.role == "AXMenuItem" || 
               nextSegment.role == "AXRadioButton" || nextSegment.role == "AXCheckBox" {
              // This is a generic container that directly contains interactive elements
              // Such containers are often structural and we should be more lenient in matching
              logger.trace("DETAILED PATH RESOLUTION: More lenient matching for generic container that holds interactive elements")
              return true
            }
          }
        }

        logger.trace("FAILED - Attribute \(normalizedName) not found ✗")
        if enableDetailedDebug {
          logger.trace("DETAILED PATH RESOLUTION: FAILED - Attribute \(normalizedName) not found ✗")
        }
        return false
      }

      // Convert attribute value to string for logging
      let actualValue: String =
        if let stringValue = attributeRef as? String {
          stringValue
        } else if let numberValue = attributeRef as? NSNumber {
          numberValue.stringValue
        } else if let boolValue = attributeRef as? Bool {
          boolValue ? "true" : "false"
        } else {
          String(describing: attributeRef!)
        }

      logger.trace("Found value: \"\(actualValue)\"")
      if enableDetailedDebug {
        logger.trace("DETAILED PATH RESOLUTION: Found value for \(normalizedName): \"\(actualValue)\"")
      }

      // Exact match check
      if actualValue == expectedValue {
        logger.trace(
          "ATTRIBUTE MATCH OK ✓ \(normalizedName)=\"\(actualValue)\" matches \"\(expectedValue)\"")
        if enableDetailedDebug {
          logger.trace("DETAILED PATH RESOLUTION: ATTRIBUTE MATCH OK ✓ \(normalizedName)=\"\(actualValue)\" matches \"\(expectedValue)\"")
        }
      } else {
        logger.trace(
          "ATTRIBUTE MISMATCH ✗ \(normalizedName)=\"\(actualValue)\" != \"\(expectedValue)\"")
        logger.trace("FAILED - Attribute \(normalizedName) did not match ✗")
        if enableDetailedDebug {
          logger.trace("DETAILED PATH RESOLUTION: ATTRIBUTE MISMATCH ✗")
          logger.trace("DETAILED PATH RESOLUTION: Actual value: \"\(actualValue)\"")
          logger.trace("DETAILED PATH RESOLUTION: Expected value: \"\(expectedValue)\"")
        }
        return false
      }
    }

    // All checks passed
    logger.trace("ALL ATTRIBUTES MATCHED ✓ - Element matches segment successfully")
    if enableDetailedDebug {
      logger.trace("DETAILED PATH RESOLUTION: ALL ATTRIBUTES MATCHED ✓ - Element matches segment successfully")
    }
    
    // DIAGNOSTIC: Log detailed segment match success information
    // Only log for special cases to avoid excessive output
    let isGenericContainer = (segment.role == "AXGroup" || segment.role == "AXBox" || segment.role == "AXGeneric" || segment.role == "AXSplitGroup")
    let isApplicationMatch = segment.role == "AXApplication"
    let isFirstSegmentAfterApp = (segmentIndex != nil && segmentIndex == 1) // First child after application
    
    if isGenericContainer || isApplicationMatch || isFirstSegmentAfterApp || enableDetailedDebug {
      let segmentDesc = segment.toString()
      logger.trace("DIAGNOSTIC: Element matches segment successfully: \(segmentDesc)")
      
      // Show detailed information about the element position for special cases
      var positionRef: CFTypeRef?
      if AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &positionRef) == .success,
         CFGetTypeID(positionRef!) == AXValueGetTypeID() {
         var position = CGPoint.zero
         AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
         logger.trace("DIAGNOSTIC: Matched element position: (\(position.x), \(position.y))")
      }
      
      // For key elements, log more details to the diagnostic file
      // This helps with understanding where in the hierarchy we are
      if let diagPath = ProcessInfo.processInfo.environment["MCP_AX_DIAGNOSTIC_LOG"] {
        // Build diagnostic information
        let segmentInfo = segment.toString()
        let roleStr = segment.role
        let attrStr = segment.attributes.map { key, val in "\(key)=\"\(val)\"" }.joined(separator: ", ")
        
        let matchMessage = """
        
        === MATCHED ELEMENT FOR SEGMENT \(segmentIndex ?? -1) ===
        Segment: \(segmentInfo)
        Role: \(roleStr)
        Attributes: \(attrStr)
        ElementID: \(elementID)
        
        """
        
        if let data = matchMessage.data(using: .utf8) {
          do {
            let fileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: diagPath))
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
          } catch {
            logger.trace("Failed to write match details to diagnostic log: \(error)")
          }
        }
      }
    }
    
    return true
  }
  
  /// Get a human-readable name for an AXError code
  private func getAXErrorName(_ error: AXError) -> String {
    switch error {
    case .success: "Success"
    case .failure: "Failure"
    case .illegalArgument: "Illegal Argument"
    case .invalidUIElement: "Invalid UI Element"
    case .invalidUIElementObserver: "Invalid UI Element Observer"
    case .cannotComplete: "Cannot Complete"
    case .attributeUnsupported: "Attribute Unsupported"
    case .actionUnsupported: "Action Unsupported"
    case .notificationUnsupported: "Notification Unsupported"
    case .notImplemented: "Not Implemented"
    case .notificationAlreadyRegistered: "Notification Already Registered"
    case .notificationNotRegistered: "Notification Not Registered"
    case .apiDisabled: "API Disabled"
    case .noValue: "No Value"
    case .parameterizedAttributeUnsupported: "Parameterized Attribute Unsupported"
    case .notEnoughPrecision: "Not Enough Precision"
    default: "Unknown Error (\(error.rawValue))"
    }
  }

  /// Get the normalized form of an attribute name for matching
  /// - Parameter attributeName: The original attribute name
  /// - Returns: The normalized attribute name
  private func getNormalizedAttributeName(_ attributeName: String) -> String {
    // Use the pathNormalizer for consistency with path generation
    PathNormalizer.normalizeAttributeName(attributeName)
  }

  /// Match an attribute value against an expected value
  /// - Parameters:
  ///   - element: The AXUIElement to check
  ///   - name: The attribute name
  ///   - expectedValue: The expected attribute value
  /// - Returns: True if the attribute matches the expected value
  ///
  /// This method tries multiple variants of the attribute name to handle inconsistencies in
  /// how attribute names might be specified in paths versus how they are accessed in the
  /// accessibility API. It has special handling for bundleIdentifier to ensure it works
  /// consistently regardless of attribute order or format.
  ///
  /// The matching strategy tries:
  /// 1. The original attribute name as provided
  /// 2. The normalized attribute name (from PathNormalizer)
  /// 3. For attributes with AX prefix: tries without the prefix (except bundleIdentifier)
  /// 4. For attributes without AX prefix: tries with the prefix (except bundleIdentifier)
  ///
  /// This ensures paths like these all work:
  /// - [@AXTitle="Calculator"][@bundleIdentifier="com.apple.calculator"]
  /// - [@bundleIdentifier="com.apple.calculator"][@AXTitle="Calculator"]
  /// - [@AXbundleIdentifier="com.apple.calculator"] (incorrect but handled for compatibility)
  private func attributeMatchesValue(_ element: AXUIElement, name: String, expectedValue: String)
    -> Bool
  {
    // First try with the original attribute name
    if tryAttributeMatch(element, attributeName: name, expectedValue: expectedValue) {
      return true
    }

    // Try with normalized attribute name
    let normalizedName = getNormalizedAttributeName(name)
    if normalizedName != name,
      tryAttributeMatch(
        element,
        attributeName: normalizedName,
        expectedValue: expectedValue,
      )
    {
      return true
    }

    // For special cases like bundleIdentifier that may not have AX prefix
    if name.hasPrefix("AX"), !normalizedName.contains("bundleIdentifier") {
      // Try without AX prefix for all except bundleIdentifier
      let withoutPrefix = String(name.dropFirst(2))
      if tryAttributeMatch(element, attributeName: withoutPrefix, expectedValue: expectedValue) {
        return true
      }
    } else if !name.hasPrefix("AX"), name != "bundleIdentifier" {
      // Try with AX prefix for normal attributes (not bundleIdentifier)
      let withPrefix = "AX\(name)"
      if tryAttributeMatch(element, attributeName: withPrefix, expectedValue: expectedValue) {
        return true
      }
    }

    // No match found with any variation
    return false
  }

  /// Helper method to try matching an attribute with a specific name
  /// - Parameters:
  ///   - element: The element to check
  ///   - attributeName: The attribute name to try
  ///   - expectedValue: The expected value
  /// - Returns: True if the attribute matches
  ///
  /// This helper method encapsulates the actual attribute access and comparison logic
  /// to avoid repetition in the main attributeMatchesValue method, which needs to try
  /// multiple name variants.
  private func tryAttributeMatch(
    _ element: AXUIElement, attributeName: String, expectedValue: String
  ) -> Bool {
    // Get the attribute value
    var attributeRef: CFTypeRef?
    let attributeStatus = AXUIElementCopyAttributeValue(
      element, attributeName as CFString, &attributeRef)

    // If we couldn't get the attribute, it doesn't match
    if attributeStatus != .success || attributeRef == nil {
      return false
    }

    // Convert attribute value to string for comparison
    let actualValue: String =
      if let stringValue = attributeRef as? String {
        stringValue
      } else if let numberValue = attributeRef as? NSNumber {
        numberValue.stringValue
      } else if let boolValue = attributeRef as? Bool {
        boolValue ? "true" : "false"
      } else {
        String(describing: attributeRef!)
      }

    // Check for exact match
    if actualValue == expectedValue {
      return true
    }

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
  public static func validatePath(
    _ pathString: String,
    strict: Bool = false,
  ) throws -> (isValid: Bool, warnings: [ElementPathError]) {
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
    if segmentStrings.count > 15, strict {
      warnings.append(
        ElementPathError.validationWarning(
          "Path has \(segmentStrings.count) segments, which might be excessive",
          suggestion: "Consider using a shorter path if possible",
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
        throw ElementPathError.invalidPathSyntax(
          String(segmentString),
          details: "Unknown error parsing segment at index \(i)",
        )
      }
    }

    // Validate first segment (should typically be AXApplication)
    let firstSegmentString = segmentStrings[0]
    do {
      let firstSegment = try parseSegment(String(firstSegmentString), segmentIndex: 0)

      if strict {
        if firstSegment.role != "AXApplication", firstSegment.role != "AXSystemWide" {
          warnings.append(
            ElementPathError.validationWarning(
              "First segment role is '\(firstSegment.role)' rather than 'AXApplication' or 'AXSystemWide'",
              suggestion:
                "Paths typically start with AXApplication for targeting specific applications",
            ))
        }

        if firstSegment.role == "AXApplication" {
          // Check if bundleIdentifier or title is provided for the application
          let hasBundleId = firstSegment.attributes["bundleIdentifier"] != nil
          let hasTitle =
            firstSegment.attributes["title"] != nil || firstSegment.attributes["AXTitle"] != nil

          if !hasBundleId, !hasTitle {
            warnings.append(
              ElementPathError.missingAttribute(
                String(firstSegmentString),
                suggestedAttribute: "bundleIdentifier or title",
                atSegment: 0,
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
  private static func validateSegment(_ segment: PathSegment, index: Int, strict: Bool)
    -> [ElementPathError]
  {
    var warnings: [ElementPathError] = []

    // Check for common role validation issues
    if segment.role.isEmpty {
      warnings.append(
        ElementPathError.validationWarning(
          "Empty role in segment at index \(index)",
          suggestion: "Specify a valid accessibility role like 'AXButton', 'AXTextField', etc.",
        ))
    }

    // Role should typically start with AX for standard elements
    if !segment.role.hasPrefix("AX"), strict {
      warnings.append(
        ElementPathError.validationWarning(
          "Role '\(segment.role)' doesn't have the standard 'AX' prefix",
          suggestion:
            "Consider using standard accessibility roles like 'AXButton', 'AXTextField', etc.",
        ))
    }

    // Check for empty attributes or invalid formats
    for (key, value) in segment.attributes {
      if value.isEmpty, strict {
        warnings.append(
          ElementPathError.validationWarning(
            "Empty value for attribute '\(key)' in segment at index \(index)",
            suggestion: "Consider removing the empty attribute or providing a meaningful value",
          ))
      }

      // Validate attribute name
      if key.isEmpty {
        warnings.append(
          ElementPathError.validationWarning(
            "Empty attribute name in segment at index \(index)",
            suggestion: "Specify a valid attribute name",
          ))
      }
    }

    // If it's a common UI element, check if it has the right attributes for reliable identification
    if index > 0, segment.attributes.isEmpty, segment.index == nil, strict {
      switch segment.role {
      case "AXButton", "AXMenuItem", "AXRadioButton", "AXCheckBox":
        warnings.append(
          ElementPathError.missingAttribute(
            segment.toString(),
            suggestedAttribute: "AXTitle or AXDescription",
            atSegment: index,
          ))

      case "AXTextField", "AXTextArea":
        warnings.append(
          ElementPathError.missingAttribute(
            segment.toString(),
            suggestedAttribute: "AXPlaceholderValue or AXIdentifier",
            atSegment: index,
          ))

      case "AXTable", "AXGrid", "AXList", "AXOutline":
        warnings.append(
          ElementPathError.missingAttribute(
            segment.toString(),
            suggestedAttribute: "AXIdentifier",
            atSegment: index,
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
  private static func checkForAmbiguityIssues(
    _ segmentStrings: [Substring],
    warnings: inout [ElementPathError],
    strict: Bool,
  ) {
    // Count segments with the same role in sequence
    var consecutiveSegments: [String: Int] = [:]
    var previousRole = ""

    for (i, segmentString) in segmentStrings.enumerated() {
      do {
        let segment = try parseSegment(String(segmentString), segmentIndex: i)

        if segment.role == previousRole {
          consecutiveSegments[segment.role, default: 1] += 1

          // If we have multiple segments with the same role in a row and no index is specified, warn about
          // ambiguity
          if consecutiveSegments[segment.role, default: 1] > 1, segment.index == nil, strict {
            warnings.append(
              ElementPathError.potentialAmbiguity(
                segment.toString(),
                details:
                  "Multiple consecutive '\(segment.role)' segments without index specification",
                atSegment: i,
              ))
          }
        } else {
          consecutiveSegments[segment.role] = 1
          previousRole = segment.role
        }

        // Warn about common generic roles without sufficient disambiguation
        if ["AXGroup", "AXBox", "AXGeneric"].contains(segment.role), segment.attributes.isEmpty,
          segment.index == nil, strict
        {
          warnings.append(
            ElementPathError.potentialAmbiguity(
              segment.toString(),
              details:
                "Generic role '\(segment.role)' without attributes or index may match multiple elements",
              atSegment: i,
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
    String(repeating: self, count: count)
  }
}

extension ElementPath {
  /// Diagnoses issues with a path resolution and provides detailed troubleshooting information
  /// - Parameters:
  ///   - pathString: The path string to diagnose
  ///   - accessibilityService: The accessibility service to use for resolution attempts
  /// - Returns: A diagnostic report with details about the issue and suggested solutions
  /// - Throws: ElementPathError if there's a critical error during diagnosis
  public static func diagnosePathResolutionIssue(
    _ pathString: String,
    using accessibilityService: AccessibilityServiceProtocol,
  ) async throws -> String {
    // Start with path validation
    var diagnosis = "Path Resolution Diagnosis for: \(pathString)\n"
    diagnosis += "=".repeating(80) + "\n\n"

    // Validate path syntax
    do {
      let (_, warnings) = try validatePath(pathString, strict: true)

      if !warnings.isEmpty {
        diagnosis += "VALIDATION WARNINGS:\n"
        for (i, warning) in warnings.enumerated() {
          diagnosis += "  \(i + 1). \(warning.description)\n"
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
      diagnosis +=
        "❌ Unexpected error resolving application element: \(error.localizedDescription)\n"
      return diagnosis
    }

    // Now try each segment in sequence
    for (i, segment) in path.segments.enumerated().dropFirst() {  // Skip first segment (app)
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
              // Use the normalized attribute name
              let normalizedAttrName = path.getNormalizedAttributeName(attrName)

              // Single check with normalized name
              do {
                let variantName = normalizedAttrName
                var attrRef: CFTypeRef?
                let status = AXUIElementCopyAttributeValue(child, variantName as CFString, &attrRef)
                if status == .success, let actualValue = convertAttributeToString(attrRef) {
                  diagnosis +=
                    "    - Attribute \(variantName): actual=\"\(actualValue)\", expected=\"\(expectedValue)\" "
                  if actualValue == expectedValue {
                    diagnosis += "✅ MATCH\n"
                    hasMatch = true
                  } else {
                    diagnosis += "❌ NO MATCH\n"
                  }
                }
              }
              if !hasMatch {
                diagnosis +=
                  "    - Attribute \(attrName): ❌ NOT FOUND or NO MATCH on this element\n"
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
        diagnosis +=
          "  3. Consider using the mcp-ax-inspector tool to see the exact element structure\n"
        diagnosis +=
          "  4. Try simplifying the path or using an index if there are many similar elements\n\n"
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
        diagnosis +=
          "  Example: \(segment.toString())[@AXTitle=\"SomeTitle\"] or \(segment.toString())[0]\n\n"

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
          let status = AXUIElementCopyAttributeValue(
            matchingChildren[0], attr as CFString, &attrRef)
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
    guard let attributeRef else { return nil }

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

extension ElementPath {}
