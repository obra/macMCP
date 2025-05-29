// ABOUTME: UIInteractionServiceProtocol.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation

/// Direction for scrolling operations
public enum ScrollDirection: String, Codable, Sendable {
  case upward = "up"
  case downward = "down"
  case leftward = "left"
  case rightward = "right"
}

/// Protocol for UI interaction services
public protocol UIInteractionServiceProtocol {
  // MARK: - Path-based Element Interaction Methods

  /// Click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  func clickElementByPath(path: String, appBundleId: String?) async throws

  /// Double click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  func doubleClickElementByPath(path: String, appBundleId: String?) async throws

  /// Right click on a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the element
  func rightClickElementByPath(path: String, appBundleId: String?) async throws

  /// Type text into a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - text: The text to type
  ///   - appBundleId: Optional bundle ID of the application containing the element
  func typeTextByPath(path: String, text: String, appBundleId: String?) async throws

  /// Drag and drop from one element to another using paths
  /// - Parameters:
  ///   - sourcePath: The source element path using macos://ui/ notation
  ///   - targetPath: The target element path using macos://ui/ notation
  ///   - appBundleId: Optional bundle ID of the application containing the elements
  func dragElementByPath(sourcePath: String, targetPath: String, appBundleId: String?) async throws

  /// Scroll a UI element using its path
  /// - Parameters:
  ///   - path: The UI element path using macos://ui/ notation
  ///   - direction: The scroll direction
  ///   - amount: The amount to scroll (normalized 0-1)
  ///   - appBundleId: Optional bundle ID of the application containing the element
  func scrollElementByPath(
    path: String, direction: ScrollDirection, amount: Double, appBundleId: String?,
  )
    async throws

  /// Perform a specific accessibility action on an element by path
  /// - Parameters:
  ///   - path: The element path using macos://ui/ notation
  ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
  ///   - appBundleId: Optional application bundle ID
  func performActionByPath(path: String, action: String, appBundleId: String?) async throws

  // MARK: - Position-based methods

  /// Click at a specific screen position
  /// - Parameter position: The screen position to click
  func clickAtPosition(position: CGPoint) async throws

  /// Double click at a specific screen position
  /// - Parameter position: The screen position to double-click
  func doubleClickAtPosition(position: CGPoint) async throws

  /// Right click at a specific screen position
  /// - Parameter position: The screen position to right-click
  func rightClickAtPosition(position: CGPoint) async throws

  /// Press a specific key on the keyboard
  /// - Parameters:
  ///   - keyCode: The key code to press
  ///   - modifiers: Optional modifier flags to apply
  func pressKey(keyCode: Int, modifiers: CGEventFlags?) async throws
}
