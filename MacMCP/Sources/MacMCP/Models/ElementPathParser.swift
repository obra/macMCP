// ABOUTME: ElementPathParser handles parsing and validation of element path strings
// ABOUTME: Converts string representations to ElementPath objects with proper error handling

import Foundation
import MacMCPUtilities

/// Parser for ElementPath strings with validation capabilities
public struct ElementPathParser {
  /// The path ID prefix (macos://ui/)
  public static let pathPrefix = "macos://ui/"

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
    // Combined pattern to handle both escaped and unescaped quotes
    let attributePattern = "\\[@([^=]+)=\\\\?\"((?:[^\"]|\\\\\")*?)\\\\?\"\\]"  // Captures attribute name and value
    let indexPattern = "#([+-]?\\w+)"  // Captures the index (could be anywhere in the segment)

    // Extract the role
    guard let roleRange = segmentString.range(of: rolePattern, options: .regularExpression) else {
      throw ElementPathError.invalidSegmentRole(segmentString)
    }

    let role = String(segmentString[roleRange])

    // Extract attributes using regex groups
    var attributes: [String: String] = [:]
    
    // Use NSRegularExpression to extract attributes with proper group capture
    if let regex = try? NSRegularExpression(pattern: attributePattern) {
      let nsString = segmentString as NSString
      let range = NSRange(location: 0, length: nsString.length)
      let matches = regex.matches(in: segmentString, options: [], range: range)
      
      for match in matches {
        if match.numberOfRanges >= 3 {
          let nameRange = Range(match.range(at: 1), in: segmentString)!
          let valueRange = Range(match.range(at: 2), in: segmentString)!
          
          let name = String(segmentString[nameRange])
          var value = String(segmentString[valueRange])
          
          // Unescape quotes in the value
          value = value.replacingOccurrences(of: "\\\"", with: "\"")
          
          // Normalize the attribute name during parsing
          let normalizedName = PathNormalizer.normalizeAttributeName(name)
          attributes[normalizedName] = value
        }
      }
    }

    // Extract index if present
    var index: Int? = nil
    if let regex = try? NSRegularExpression(pattern: indexPattern) {
      let nsString = segmentString as NSString
      let range = NSRange(location: 0, length: nsString.length)
      if let match = regex.firstMatch(in: segmentString, options: [], range: range), match.numberOfRanges >= 2 {
        let indexRange = Range(match.range(at: 1), in: segmentString)!
        let indexString = String(segmentString[indexRange])
        if let parsedIndex = Int(indexString) {
          index = parsedIndex
        } else {
          throw ElementPathError.invalidIndexSyntax("#\(indexString)", atSegment: segmentIndex)
        }
      }
    }

    return PathSegment(role: role, attributes: attributes, index: index)
  }

  /// Check if a string is an element path
  /// - Parameter string: The string to check
  /// - Returns: True if the string is an element path
  public static func isElementPath(_ string: String) -> Bool {
    string.hasPrefix(pathPrefix)
  }

  /// Validate a path string and return warnings
  /// - Parameters:
  ///   - pathString: The path string to validate
  ///   - strict: Whether to use strict validation
  /// - Returns: Validation result with any warnings
  /// - Throws: ElementPathError for critical validation failures
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
          // Check if bundleId or title is provided for the application
          let hasBundleId = firstSegment.attributes["bundleId"] != nil
          let hasTitle =
            firstSegment.attributes["title"] != nil || firstSegment.attributes["AXTitle"] != nil

          if !hasBundleId, !hasTitle {
            warnings.append(
              ElementPathError.missingAttribute(
                String(firstSegmentString),
                suggestedAttribute: "bundleId or title",
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

// MARK: - String Extensions for Parsing

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