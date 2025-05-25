// ABOUTME: ElementPathError defines errors that can occur when working with element paths
// ABOUTME: Provides detailed error descriptions and equatable comparison for testing

import Foundation

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

  /// Index is out of range for the number of matching elements
  case indexOutOfRange(Int, availableCount: Int, atSegment: Int)
  
  /// Multiple matches found but no index specified for disambiguation
  case ambiguousMatchNoIndex(String, matchCount: Int, atSegment: Int)
  
  /// Index specified but only one element matches (index unnecessary)
  case unnecessaryIndex(Int, atSegment: Int)
  
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
    case .indexOutOfRange(let index, let availableCount, let segmentIndex):
      return "Index \(index) is out of range at segment \(segmentIndex). Only \(availableCount) elements match this segment (valid indices: 0-\(availableCount - 1))."
    case .ambiguousMatchNoIndex(let segment, let matchCount, let segmentIndex):
      return "Ambiguous match at segment \(segmentIndex): \(matchCount) elements match '\(segment)' but no index specified. Use #0, #1, #2, etc. to select a specific element."
    case .unnecessaryIndex(let index, let segmentIndex):
      return "Unnecessary index #\(index) at segment \(segmentIndex): only one element matches this segment. Consider removing the index for cleaner paths."
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
      .indexOutOfRange(let lhsIndex, let lhsCount, let lhsSegment),
      .indexOutOfRange(let rhsIndex, let rhsCount, let rhsSegment)
    ):
      lhsIndex == rhsIndex && lhsCount == rhsCount && lhsSegment == rhsSegment
    case (
      .ambiguousMatchNoIndex(let lhsSegment, let lhsCount, let lhsIndex),
      .ambiguousMatchNoIndex(let rhsSegment, let rhsCount, let rhsIndex)
    ):
      lhsSegment == rhsSegment && lhsCount == rhsCount && lhsIndex == rhsIndex
    case (
      .unnecessaryIndex(let lhsIndex, let lhsSegment),
      .unnecessaryIndex(let rhsIndex, let rhsSegment)
    ):
      lhsIndex == rhsIndex && lhsSegment == rhsSegment
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