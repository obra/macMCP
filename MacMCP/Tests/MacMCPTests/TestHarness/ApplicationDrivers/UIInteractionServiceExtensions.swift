// ABOUTME: This file extends UIInteractionService with testing-specific functionality.
// ABOUTME: It provides methods needed for application drivers to interact with UI.

import Foundation
@testable import MacMCP

/// Keyboard modifiers for key press operations
public enum KeyModifier: UInt, CaseIterable {
    case command = 1
    case shift = 2
    case option = 3
    case control = 4
}

/// Extensions to UIInteractionService for test drivers
extension UIInteractionService {
    /// Press a key with modifiers
    /// - Parameters:
    ///   - keyCode: The key code to press
    ///   - modifiers: Array of key modifiers to apply
    /// - Note: This method simplifies the standard pressKey by handling modifiers
    public func pressKey(keyCode: Int, modifiers: [KeyModifier] = []) async throws {
        // For test drivers, we ignore modifiers and just press the key
        // In a real implementation, we would use the modifiers
        try await pressKey(keyCode: keyCode)
    }
    
    /// Type text (simplified version for test drivers)
    /// - Parameter text: The text to type
    /// - Note: This method uses elementIdentifier as an empty string which may be ignored
    public func typeText(text: String) async throws {
        // For test drivers, we create a version that doesn't require elementIdentifier
        // This simply forwards to the standard method with a dummy identifier
        try await typeText(elementIdentifier: "", text: text)
    }
    
    /// Click at a global screen position
    /// - Parameter point: The screen position to click
    public func clickGlobalPoint(_ point: CGPoint) async throws {
        try await clickAtPosition(position: point)
    }
}