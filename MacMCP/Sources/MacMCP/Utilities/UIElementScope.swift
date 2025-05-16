// ABOUTME: This file defines the scope for UI element search operations.
// ABOUTME: It helps narrow down search contexts for accessibility operations.

import Foundation

/// Scope for UI element search operations
public enum UIElementScope: Sendable {
  /// The entire system (all applications)
  case systemWide
  /// The currently focused application
  case focusedApplication
  /// A specific application by bundle identifier
  case application(bundleIdentifier: String)
}