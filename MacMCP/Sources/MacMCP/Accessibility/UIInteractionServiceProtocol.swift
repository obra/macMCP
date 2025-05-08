// ABOUTME: This file defines the protocol for interacting with UI elements.
// ABOUTME: It provides interfaces for clicking, typing, and other UI operations.

import Foundation

/// Direction for scrolling operations
public enum ScrollDirection: String, Codable, Sendable {
    case up
    case down
    case left
    case right
}

/// Protocol for UI interaction services
public protocol UIInteractionServiceProtocol {
    /// Click on a UI element by its identifier
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - appBundleId: Optional bundle ID of the application containing the element
    func clickElement(identifier: String, appBundleId: String?) async throws
    
    /// Click at a specific screen position
    /// - Parameter position: The screen position to click
    func clickAtPosition(position: CGPoint) async throws
    
    /// Double click on a UI element
    /// - Parameter identifier: The UI element identifier
    func doubleClickElement(identifier: String) async throws
    
    /// Right click on a UI element
    /// - Parameter identifier: The UI element identifier
    func rightClickElement(identifier: String) async throws
    
    /// Type text into a UI element
    /// - Parameters:
    ///   - elementIdentifier: The UI element identifier
    ///   - text: The text to type
    func typeText(elementIdentifier: String, text: String) async throws
    
    /// Press a specific key on the keyboard
    /// - Parameter keyCode: The key code to press
    func pressKey(keyCode: Int) async throws
    
    /// Drag and drop from one element to another
    /// - Parameters:
    ///   - sourceIdentifier: The source element identifier
    ///   - targetIdentifier: The target element identifier
    func dragElement(sourceIdentifier: String, targetIdentifier: String) async throws
    
    /// Scroll a UI element
    /// - Parameters:
    ///   - identifier: The UI element identifier
    ///   - direction: The scroll direction
    ///   - amount: The amount to scroll (normalized 0-1)
    func scrollElement(identifier: String, direction: ScrollDirection, amount: Double) async throws
}