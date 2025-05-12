// ABOUTME: This file extends UIInteractionService with direct action execution methods.
// ABOUTME: It provides helper methods for performing specific accessibility actions on elements.

import Foundation
import Logging

/// Extension for UIInteractionService adding additional action handling
extension UIInteractionService {
    /// Perform a specific accessibility action on an element
    /// - Parameters:
    ///   - identifier: The element identifier
    ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
    ///   - appBundleId: Optional application bundle ID
    public func performAction(identifier: String, action: String, appBundleId: String? = nil) async throws {
        // Find the element first
        guard let uiElement = try await findUIElement(identifier: identifier, appBundleId: appBundleId) else {
            throw createError("Element not found: \(identifier)", code: 2000)
        }
        
        // Get the AXUIElement for the identifier
        let axElement = try await getAXUIElement(for: identifier, appBundleId: appBundleId)
        
        // Try to perform the action
        do {
            try AccessibilityElement.performAction(axElement, action: action)
            logger.debug("\(action) succeeded", metadata: ["id": .string(identifier)])
        } catch {
            // Get detailed error info
            let nsError = error as NSError
            
            logger.error("\(action) failed", metadata: [
                "id": .string(identifier),
                "error": .string(error.localizedDescription),
                "domain": .string(nsError.domain),
                "code": .string("\(nsError.code)"),
                "userInfo": .string("\(nsError.userInfo)")
            ])
            
            // Create a more informative error with context and suggestions
            var context: [String: String] = [
                "elementId": identifier,
                "errorCode": "\(nsError.code)",
                "errorDomain": nsError.domain,
                "action": action
            ]
            
            throw createInteractionError(
                message: "Failed to perform \(action) action on element",
                context: context,
                underlyingError: error
            )
        }
    }
}