// ABOUTME: Utility for parsing, validating, and resolving menu paths
// ABOUTME: Handles fuzzy matching and path suggestion for menu navigation

import Foundation

/// Utility for working with menu paths and path resolution
public struct MenuPathResolver {
  /// Path separator used in menu paths
  public static let pathSeparator = " > "
  /// Build a path from an array of menu titles
  /// - Parameter menuTitles: Array of menu titles from top-level to item
  /// - Returns: Complete menu path string
  public static func buildPath(from menuTitles: [String]) -> String {
    return menuTitles.joined(separator: pathSeparator)
  }
  /// Parse a path string into individual menu title components
  /// - Parameter path: Menu path string (e.g., "File > Save As...")
  /// - Returns: Array of menu title components
  public static func parsePath(_ path: String) -> [String] {
    return path.components(separatedBy: pathSeparator).map {
      $0.trimmingCharacters(in: .whitespaces)
    }.filter {
      !$0.isEmpty
    }
  }
  /// Validate that a path string is properly formatted
  /// - Parameter path: Menu path to validate
  /// - Returns: True if path is valid format
  public static func validatePath(_ path: String) -> Bool {
    guard !path.isEmpty else { return false }
    // Check for invalid patterns
    if path.hasPrefix(pathSeparator) || path.hasSuffix(pathSeparator) { return false }
    // Check for consecutive separators
    if path.contains(pathSeparator + pathSeparator) { return false }
    let components = parsePath(path)
    guard !components.isEmpty else { return false }
    // Ensure no empty components after parsing
    return !components.contains { $0.isEmpty }
  }
  /// Find exact matches for a given path in a hierarchy
  /// - Parameters:
  ///   - path: Target path to find
  ///   - hierarchy: Menu hierarchy to search
  /// - Returns: Array of exact matching paths
  public static func findMatches(_ path: String, in hierarchy: MenuHierarchy) -> [String] {
    let allPaths = hierarchy.allPaths
    return allPaths.filter { $0 == path }
  }
  /// Find partial matches for a given path in a hierarchy
  /// - Parameters:
  ///   - path: Target path to find partial matches for
  ///   - hierarchy: Menu hierarchy to search
  /// - Returns: Array of paths that contain the target path as a substring
  public static func findPartialMatches(_ path: String, in hierarchy: MenuHierarchy) -> [String] {
    let allPaths = hierarchy.allPaths
    let lowercasePath = path.lowercased()
    return allPaths.filter { $0.lowercased().contains(lowercasePath) }.sorted { path1, path2 in
      // Prioritize exact prefix matches
      let path1Lower = path1.lowercased()
      let path2Lower = path2.lowercased()
      if path1Lower.hasPrefix(lowercasePath) && !path2Lower.hasPrefix(lowercasePath) { return true }
      if path2Lower.hasPrefix(lowercasePath) && !path1Lower.hasPrefix(lowercasePath) {
        return false
      }
      // Then sort by length (shorter paths first)
      return path1.count < path2.count
    }
  }
  /// Suggest similar paths using fuzzy matching
  /// - Parameters:
  ///   - path: Target path to find suggestions for
  ///   - hierarchy: Menu hierarchy to search
  ///   - maxSuggestions: Maximum number of suggestions to return
  /// - Returns: Array of suggested similar paths
  public static func suggestSimilar(
    _ path: String, in hierarchy: MenuHierarchy, maxSuggestions: Int = 5
  ) -> [String] {
    let allPaths = hierarchy.allPaths
    let pathComponents = parsePath(path)
    // First try partial matches
    let partialMatches = findPartialMatches(path, in: hierarchy)
    if !partialMatches.isEmpty { return Array(partialMatches.prefix(maxSuggestions)) }
    // Then try matching individual components
    var scoredPaths: [(String, Int)] = []
    for candidatePath in allPaths {
      let candidateComponents = parsePath(candidatePath)
      let score = calculatePathSimilarity(pathComponents, candidateComponents)
      if score > 0 { scoredPaths.append((candidatePath, score)) }
    }
    // Sort by score descending, then by path length ascending
    scoredPaths.sort { lhs, rhs in
      if lhs.1 == rhs.1 { return lhs.0.count < rhs.0.count }
      return lhs.1 > rhs.1
    }
    return Array(scoredPaths.prefix(maxSuggestions).map { $0.0 })
  }
  /// Calculate similarity score between two path component arrays
  /// - Parameters:
  ///   - components1: First path components
  ///   - components2: Second path components
  /// - Returns: Similarity score (higher is more similar)
  private static func calculatePathSimilarity(_ components1: [String], _ components2: [String])
    -> Int
  {
    var score = 0
    for component1 in components1 {
      for component2 in components2 {
        if component1.lowercased() == component2.lowercased() {
          score += 10  // Exact match
        } else if component1.lowercased().contains(component2.lowercased())
          || component2.lowercased().contains(component1.lowercased())
        {
          score += 5  // Partial match
        } else if levenshteinDistance(component1.lowercased(), component2.lowercased()) <= 2 {
          score += 2  // Similar spelling
        }
      }
    }
    return score
  }
  /// Calculate Levenshtein distance between two strings
  /// - Parameters:
  ///   - s1: First string
  ///   - s2: Second string
  /// - Returns: Edit distance between strings
  private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
    let a = Array(s1)
    let b = Array(s2)
    var matrix = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
    for i in 0...a.count { matrix[i][0] = i }
    for j in 0...b.count { matrix[0][j] = j }
    for i in 1...a.count {
      for j in 1...b.count {
        if a[i - 1] == b[j - 1] {
          matrix[i][j] = matrix[i - 1][j - 1]
        } else {
          matrix[i][j] = min(
            matrix[i - 1][j] + 1,  // deletion
            matrix[i][j - 1] + 1,  // insertion
            matrix[i - 1][j - 1] + 1  // substitution
          )
        }
      }
    }
    return matrix[a.count][b.count]
  }
}
