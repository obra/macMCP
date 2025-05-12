// ABOUTME: This file extends UIInteractionService with direct action execution methods.
// ABOUTME: It provides helper methods for performing specific accessibility actions on elements.

import Foundation
import Logging
import MCP

/// Implementation of the performAction method for UIInteractionService
extension UIInteractionService {
    /// Perform a specific accessibility action on an element
    /// - Parameters:
    ///   - identifier: The element identifier
    ///   - action: The accessibility action to perform (e.g., "AXPress", "AXPick")
    ///   - appBundleId: Optional application bundle ID
    public func performAction(identifier: String, action: String, appBundleId: String? = nil) async throws {
        // Get the AXUIElement for the identifier
        let axElement: AXUIElement
        do {
            axElement = try await getAXUIElement(for: identifier, appBundleId: appBundleId)
        } catch {
            logger.error("Failed to get AXUIElement", metadata: [
                "id": .string(identifier),
                "error": .string(error.localizedDescription)
            ])
            throw MCPError.internalError("Failed to get element for action: \(error.localizedDescription)")
        }

        // Try to perform the action
        do {
            // Check if the action is supported by the element
            var actionNames: CFArray?
            let actionsResult = AXUIElementCopyActionNames(axElement, &actionNames)

            if actionsResult == .success, let actions = actionNames as? [String] {
                if !actions.contains(action) {
                    logger.error("Action not supported by element", metadata: [
                        "id": .string(identifier),
                        "action": .string(action),
                        "availableActions": .string(actions.joined(separator: ", "))
                    ])
                    throw MCPError.internalError("Action \(action) not supported by element. Available actions: \(actions.joined(separator: ", "))")
                }
            } else {
                // Couldn't get action names, but we'll still try the action
                logger.warning("Could not get action names from element", metadata: [
                    "id": .string(identifier),
                    "error": .string(getAXErrorName(actionsResult))
                ])
            }

            // Perform the specified action
            try AccessibilityElement.performAction(axElement, action: action)
            logger.debug("Action succeeded", metadata: [
                "id": .string(identifier),
                "action": .string(action)
            ])
        } catch {
            // Get detailed error info
            let nsError = error as NSError

            logger.error("Action failed", metadata: [
                "id": .string(identifier),
                "action": .string(action),
                "error": .string(error.localizedDescription),
                "code": .string("\(nsError.code)")
            ])

            throw MCPError.internalError("Failed to perform \(action) on element: \(error.localizedDescription)")
        }
    }

    /// Get a human-readable name for an AXError code
    private func getAXErrorName(_ error: AXError) -> String {
        switch error {
        case .success: return "Success"
        case .failure: return "Failure"
        case .illegalArgument: return "Illegal Argument"
        case .invalidUIElement: return "Invalid UI Element"
        case .invalidUIElementObserver: return "Invalid UI Element Observer"
        case .cannotComplete: return "Cannot Complete"
        case .attributeUnsupported: return "Attribute Unsupported"
        case .actionUnsupported: return "Action Unsupported"
        case .notificationUnsupported: return "Notification Unsupported"
        case .notImplemented: return "Not Implemented"
        case .notificationAlreadyRegistered: return "Notification Already Registered"
        case .notificationNotRegistered: return "Notification Not Registered"
        case .apiDisabled: return "API Disabled"
        case .noValue: return "No Value"
        case .parameterizedAttributeUnsupported: return "Parameterized Attribute Unsupported"
        case .notEnoughPrecision: return "Not Enough Precision"
        default: return "Unknown Error (\(error.rawValue))"
        }
    }
}