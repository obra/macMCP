// ABOUTME: This file extends AccessibilityService with window management functionality.
// ABOUTME: It provides methods for manipulating window position, size, and state.

import Foundation
import AppKit
import Logging
import ApplicationServices // Required for AXUIElement and AXValue functions

/// Extension to AccessibilityService for window management operations
extension AccessibilityService {
    
    /// Find a window element by its identifier
    /// - Parameter identifier: Window identifier
    /// - Returns: The AXUIElement representing the window
    private func findWindowElement(withIdentifier identifier: String) async throws -> AXUIElement {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            throw AccessibilityPermissions.Error.permissionDenied
        }

        // Element identifier methods have been removed
        // This code needs to be updated to use findElementByPath instead
        // For now, throw an error to prevent using legacy identifiers
        logger.error(
            "Legacy element identifier methods have been removed",
            metadata: ["identifier": .string(identifier)]
        )
        throw NSError(
            domain: "com.macos.mcp.accessibility",
            code: MacMCPErrorCode.invalidElementId,
            userInfo: [NSLocalizedDescriptionKey: "Legacy element identifiers are no longer supported. Use window paths instead of window identifiers."]
        )
    }
    
    /// Move a window to a new position
    /// - Parameters:
    ///   - identifier: Window identifier
    ///   - point: Target position
    public func moveWindow(
        withIdentifier identifier: String,
        to point: CGPoint
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Create a position value - convert point to CFTypeRef for AXUIElementSetAttributeValue
        let pointValue = NSValue(point: point)
        
        // Set the position attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXPositionAttribute as CFString,
            pointValue
        )
        
        if error != AXError.success {
            logger.error("Failed to move window: \(error.rawValue)")
            throw createInteractionError(
                message: "Failed to move window",
                context: [
                    "windowId": identifier,
                    "targetX": "\(point.x)",
                    "targetY": "\(point.y)",
                    "axError": "\(error.rawValue)"
                ]
            ).asMCPError
        }
    }
    
    /// Resize a window
    /// - Parameters:
    ///   - identifier: Window identifier
    ///   - size: Target size
    public func resizeWindow(
        withIdentifier identifier: String,
        to size: CGSize
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Create a size value - convert size to CFTypeRef for AXUIElementSetAttributeValue
        let sizeValue = NSValue(size: size)
        
        // Set the size attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        
        if error != AXError.success {
            logger.error("Failed to resize window: \(error.rawValue)")
            throw createInteractionError(
                message: "Failed to resize window",
                context: [
                    "windowId": identifier,
                    "targetWidth": "\(size.width)",
                    "targetHeight": "\(size.height)",
                    "axError": "\(error.rawValue)"
                ]
            ).asMCPError
        }
    }
    
    /// Minimize a window
    /// - Parameter identifier: Window identifier
    public func minimizeWindow(
        withIdentifier identifier: String
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Set the minimized attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXMinimizedAttribute as CFString,
            true as CFBoolean
        )
        
        if error != AXError.success {
            logger.error("Failed to minimize window: \(error.rawValue)")
            throw createInteractionError(
                message: "Failed to minimize window",
                context: [
                    "windowId": identifier,
                    "axError": "\(error.rawValue)"
                ]
            ).asMCPError
        }
    }
    
    /// Maximize (zoom) a window
    /// - Parameter identifier: Window identifier
    public func maximizeWindow(
        withIdentifier identifier: String
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // First check if the window supports the zoom action
        var actionsArray: CFArray? = nil
        let actionsError = AXUIElementCopyActionNames(windowElement, &actionsArray)

        if actionsError != AXError.success || actionsArray == nil {
            throw createInteractionError(
                message: "Failed to get window actions",
                context: [
                    "windowId": identifier,
                    "axError": "\(actionsError.rawValue)"
                ]
            ).asMCPError
        }
        
        let actions = actionsArray as! [CFString]
        let axZoomAction = "AXZoom" as CFString
        if actions.contains(axZoomAction) {
            // Perform zoom action
            let zoomError = AXUIElementPerformAction(windowElement, axZoomAction)
            if zoomError != AXError.success {
                logger.error("Failed to maximize window: \(zoomError.rawValue)")
                throw createInteractionError(
                    message: "Failed to maximize window",
                    context: [
                        "windowId": identifier,
                        "axError": "\(zoomError.rawValue)"
                    ]
                ).asMCPError
            }
        } else {
            // Fallback to attempting to resize to screen size
            if let mainScreen = NSScreen.main {
                let screenSize = mainScreen.visibleFrame.size
                try await resizeWindow(withIdentifier: identifier, to: screenSize)
                
                // Move to the top-left of the visible screen area
                let topLeft = CGPoint(x: mainScreen.visibleFrame.origin.x, y: mainScreen.visibleFrame.origin.y)
                try await moveWindow(withIdentifier: identifier, to: topLeft)
            } else {
                logger.error("Failed to maximize window: Zoom action not supported and couldn't get screen size")
                throw createInteractionError(
                    message: "Failed to maximize window: Zoom action not supported",
                    context: ["windowId": identifier]
                ).asMCPError
            }
        }
    }
    
    /// Close a window
    /// - Parameter identifier: Window identifier
    public func closeWindow(
        withIdentifier identifier: String
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Check if the window supports the close action
        var actionsArray: CFArray? = nil
        let actionsError = AXUIElementCopyActionNames(windowElement, &actionsArray)

        if actionsError != AXError.success || actionsArray == nil {
            throw createInteractionError(
                message: "Failed to get window actions",
                context: [
                    "windowId": identifier,
                    "axError": "\(actionsError.rawValue)"
                ]
            ).asMCPError
        }
        
        let actions = actionsArray as! [CFString]
        let axCloseButton = "AXCloseButton" as CFString
        if actions.contains(axCloseButton) {
            // Get the close button
            var closeButtonRef: CFTypeRef? = nil
            let buttonError = AXUIElementCopyAttributeValue(
                windowElement,
                axCloseButton,
                &closeButtonRef
            )

            if buttonError == AXError.success && closeButtonRef != nil {
                // Cast and press the close button
                let closeButton = closeButtonRef as! AXUIElement
                let axPressAction = "AXPress" as CFString
                let pressError = AXUIElementPerformAction(closeButton, axPressAction)
                if pressError != AXError.success {
                    logger.error("Failed to press close button: \(pressError.rawValue)")
                    throw createInteractionError(
                        message: "Failed to press close button",
                        context: [
                            "windowId": identifier,
                            "axError": "\(pressError.rawValue)"
                        ]
                    ).asMCPError
                }
            } else {
                logger.error("Failed to get close button: \(buttonError.rawValue)")
                throw createInteractionError(
                    message: "Failed to get close button",
                    context: [
                        "windowId": identifier,
                        "axError": "\(buttonError.rawValue)"
                    ]
                ).asMCPError
            }
        } else {
            logger.error("Window does not support close action")
            throw createActionNotSupportedError(
                message: "Window does not support close action",
                context: ["windowId": identifier]
            ).asMCPError
        }
    }
    
    /// Activate (bring to front) a window
    /// - Parameter identifier: Window identifier
    public func activateWindow(
        withIdentifier identifier: String
    ) async throws {
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Get the window's application
        var appElementRef: CFTypeRef? = nil
        let appError = AXUIElementCopyAttributeValue(
            windowElement,
            kAXParentAttribute as CFString,
            &appElementRef
        )

        if appError != AXError.success || appElementRef == nil {
            logger.error("Failed to get parent application: \(appError.rawValue)")
            throw createInteractionError(
                message: "Failed to get parent application",
                context: [
                    "windowId": identifier,
                    "axError": "\(appError.rawValue)"
                ]
            ).asMCPError
        }
        
        // Get the Process ID
        var pid: pid_t = 0
        let appElement = appElementRef as! AXUIElement
        let pidError = AXUIElementGetPid(appElement, &pid)
        
        if pidError != AXError.success {
            logger.error("Failed to get process ID: \(pidError.rawValue)")
            throw createInteractionError(
                message: "Failed to get process ID",
                context: [
                    "windowId": identifier,
                    "axError": "\(pidError.rawValue)"
                ]
            ).asMCPError
        }
        
        // Activate the application
        if let app = NSRunningApplication(processIdentifier: pid) {
            if !app.isActive {
                let activationSuccess = app.activate(options: .activateIgnoringOtherApps)
                if !activationSuccess {
                    logger.error("Failed to activate application")
                    throw createInteractionError(
                        message: "Failed to activate application",
                        context: ["windowId": identifier, "pid": "\(pid)"]
                    ).asMCPError
                }
            }
            
            // Now set the window as the main window
            let mainError = AXUIElementSetAttributeValue(
                windowElement,
                kAXMainAttribute as CFString,
                true as CFBoolean
            )
            
            if mainError != AXError.success {
                logger.error("Failed to set window as main: \(mainError.rawValue)")
                throw createInteractionError(
                    message: "Failed to set window as main",
                    context: [
                        "windowId": identifier,
                        "axError": "\(mainError.rawValue)"
                    ]
                ).asMCPError
            }
        } else {
            logger.error("Failed to get NSRunningApplication for pid \(pid)")
            throw createInteractionError(
                message: "Failed to get running application",
                context: ["windowId": identifier, "pid": "\(pid)"]
            ).asMCPError
        }
    }
    
    /// Set the window order (front, back, above, below)
    /// - Parameters:
    ///   - identifier: Window identifier
    ///   - orderMode: Ordering mode
    ///   - referenceWindowId: Reference window ID for relative positioning
    public func setWindowOrder(
        withIdentifier identifier: String,
        orderMode: WindowOrderMode,
        referenceWindowId: String?
    ) async throws {
        // We don't need to store windowElement here as we're using window numbers directly
        _ = try await findWindowElement(withIdentifier: identifier)
        
        switch orderMode {
        case .front:
            // Make the application active first
            try await activateWindow(withIdentifier: identifier)
            
            // Then use Core Graphics to move the window to the front
            if let windowNumber = getWindowNumber(fromIdentifier: identifier) {
                // Use dispatch async to call this on the main thread
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                }

                // Use MainActor dispatch to place window in front
                Task { @MainActor in
                    if let window = NSApp.window(withWindowNumber: windowNumber) {
                        window.orderFront(nil)
                    }
                }
            }
            
        case .back:
            // Use Core Graphics to move the window to the back
            if let windowNumber = getWindowNumber(fromIdentifier: identifier) {
                // Use MainActor dispatch to place window in back
                Task { @MainActor in
                    if let window = NSApp.window(withWindowNumber: windowNumber) {
                        window.orderBack(nil)
                    }
                }
            }
            
        case .above, .below:
            // These modes require a reference window
            guard let refId = referenceWindowId else {
                logger.error("Reference window ID required for \(orderMode.rawValue) mode")
                throw createInteractionError(
                    message: "Reference window ID required for \(orderMode.rawValue) mode",
                    context: ["windowId": identifier, "orderMode": orderMode.rawValue]
                ).asMCPError
            }
            
            // We just need to verify the reference window exists
            _ = try await findWindowElement(withIdentifier: refId)
            
            // Get window numbers for both windows
            guard let windowNumber = getWindowNumber(fromIdentifier: identifier),
                  let refWindowNumber = getWindowNumber(fromIdentifier: refId) else {
                logger.error("Failed to get window numbers")
                throw createInteractionError(
                    message: "Failed to get window numbers",
                    context: ["windowId": identifier, "referenceWindowId": refId]
                ).asMCPError
            }
            
            // Use MainActor to properly order windows
            Task { @MainActor in
                if let window = NSApp.window(withWindowNumber: windowNumber),
                   let refWindow = NSApp.window(withWindowNumber: refWindowNumber) {
                    if orderMode == .above {
                        // Move this window above the reference window
                        window.order(.above, relativeTo: refWindow.windowNumber)
                    } else {  // .below
                        // Move this window below the reference window
                        window.order(.below, relativeTo: refWindow.windowNumber)
                    }
                }
            }
        }
    }
    
    /// Focus a window (give it keyboard focus)
    /// - Parameter identifier: Window identifier
    public func focusWindow(
        withIdentifier identifier: String
    ) async throws {
        
        // Activate the window first
        try await activateWindow(withIdentifier: identifier)
        
        let windowElement = try await findWindowElement(withIdentifier: identifier)
        
        // Set the focused attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXFocusedAttribute as CFString,
            true as CFBoolean
        )
        
        if error != AXError.success {
            throw createInteractionError(
                message: "Failed to focus window",
                context: [
                    "windowId": identifier,
                    "axError": "\(error.rawValue)"
                ]
            ).asMCPError
        }
    }
    
    /// Get the NSWindow number for a window with the given identifier
    /// - Parameter identifier: Window identifier
    /// - Returns: Window number if available
    private func getWindowNumber(fromIdentifier identifier: String) -> Int? {
        // This is a helper method to convert from accessibility identifiers to window numbers
        // Currently this is a simple placeholder - in a real implementation we'd need
        // to correlate accessibility elements with window numbers
        
        // For now, we'll attempt to parse the identifier if it's a number
        if let windowNumber = Int(identifier) {
            return windowNumber
        }
        
        // In real implementation, we would find all windows and match attributes
        // but this requires traversing window lists and matching against accessibility elements
        return nil
    }
}