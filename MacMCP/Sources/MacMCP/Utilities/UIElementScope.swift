// ABOUTME: UIElementScope.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

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
