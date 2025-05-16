// ABOUTME: This file extends AccessibilityService with window management functionality.
// ABOUTME: It provides methods for manipulating window position, size, and state.

import Foundation
@preconcurrency import AppKit
import Logging
@preconcurrency import ApplicationServices // Required for AXUIElement and AXValue functions

/// Extension to AccessibilityService for window management operations
extension AccessibilityService {
    
    /// Find a window element by its path
    /// - Parameter path: Window element path
    /// - Returns: The AXUIElement representing the window
    private func findWindowElement(withPath path: String) async throws -> AXUIElement {
        // First check permissions
        guard AccessibilityPermissions.isAccessibilityEnabled() else {
            throw AccessibilityPermissions.Error.permissionDenied
        }

        // Parse the path
        let parsedPath = try ElementPath.parse(path)
        
        // Resolve the path to get the AXUIElement
        return try await parsedPath.resolve(using: self)
    }
    
    /// Move a window to a new position
    /// - Parameters:
    ///   - path: Window element path
    ///   - point: Target position
    public func moveWindow(
        withPath path: String,
        to point: CGPoint
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Create a position value - convert point to CFTypeRef for AXUIElementSetAttributeValue
        let pointValue = NSValue(point: point)
        
        // Set the position attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXPositionAttribute as CFString,
            pointValue as CFTypeRef
        )
        
        // Check for errors
        if error != .success {
            logger.error("Failed to move window", metadata: [
                "path": .string(path),
                "point": .string("\(point)"),
                "error": .string("\(error)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to move window: \(error)"]
            )
        }
    }
    
    /// Resize a window
    /// - Parameters:
    ///   - path: Window element path
    ///   - size: Target size
    public func resizeWindow(
        withPath path: String,
        to size: CGSize
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Create a size value - convert size to CFTypeRef for AXUIElementSetAttributeValue
        let sizeValue = NSValue(size: size)
        
        // Set the size attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXSizeAttribute as CFString,
            sizeValue as CFTypeRef
        )
        
        // Check for errors
        if error != .success {
            logger.error("Failed to resize window", metadata: [
                "path": .string(path),
                "size": .string("\(size)"),
                "error": .string("\(error)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resize window: \(error)"]
            )
        }
    }
    
    /// Minimize a window
    /// - Parameter path: Window element path
    public func minimizeWindow(
        withPath path: String
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Perform the minimize action
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXMinimizedAttribute as CFString,
            true as CFTypeRef
        )
        
        // Check for errors
        if error != .success {
            logger.error("Failed to minimize window", metadata: [
                "path": .string(path),
                "error": .string("\(error)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to minimize window: \(error)"]
            )
        }
    }
    
    /// Maximize (zoom) a window
    /// - Parameter path: Window element path
    public func maximizeWindow(
        withPath path: String
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Look up the AXPress action on the zoom button
        var zoomButtonRef: AXUIElement?
        let zoomButtonError = AXUIElementCopyAttributeValue(
            windowElement,
            kAXZoomButtonAttribute as CFString,
            &zoomButtonRef
        )
        
        if zoomButtonError == .success && zoomButtonRef != nil {
            // Perform the AXPress action on the zoom button
            let pressError = AXUIElementPerformAction(zoomButtonRef!, kAXPressAction as CFString)
            if pressError != .success {
                logger.error("Failed to press zoom button", metadata: [
                    "path": .string(path),
                    "error": .string("\(pressError)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to maximize window: \(pressError)"]
                )
            }
        } else {
            // Alternate approach: use the special UI actions if available
            let pressError = AXUIElementPerformAction(windowElement, "AXZoom" as CFString)
            if pressError != .success {
                logger.error("Failed to zoom window", metadata: [
                    "path": .string(path),
                    "error": .string("\(pressError)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to maximize window: \(pressError)"]
                )
            }
        }
    }
    
    /// Close a window
    /// - Parameter path: Window element path
    public func closeWindow(
        withPath path: String
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Look up the AXPress action on the close button
        var closeButtonRef: AXUIElement?
        let closeButtonError = AXUIElementCopyAttributeValue(
            windowElement,
            kAXCloseButtonAttribute as CFString,
            &closeButtonRef
        )
        
        if closeButtonError == .success && closeButtonRef != nil {
            // Perform the AXPress action on the close button
            let pressError = AXUIElementPerformAction(closeButtonRef!, kAXPressAction as CFString)
            if pressError != .success {
                logger.error("Failed to press close button", metadata: [
                    "path": .string(path),
                    "error": .string("\(pressError)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to close window: \(pressError)"]
                )
            }
        } else {
            logger.error("Failed to get close button", metadata: [
                "path": .string(path),
                "error": .string("\(closeButtonError)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get close button: \(closeButtonError)"]
            )
        }
    }
    
    /// Activate (bring to front) a window
    /// - Parameter path: Window element path
    public func activateWindow(
        withPath path: String
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Get the application element that contains this window
        var appElement: AXUIElement?
        let appError = AXUIElementCopyAttributeValue(
            windowElement,
            kAXParentAttribute as CFString,
            &appElement
        )
        
        if appError == .success && appElement != nil {
            // Activate the application first
            var pid: pid_t = 0
            let pidError = AXUIElementGetPid(appElement!, &pid)
            if pidError == .success {
                let app = NSRunningApplication(processIdentifier: pid)
                app?.activate(options: [.activateIgnoringOtherApps])
            }
        }
        
        // Now raise the window
        let raiseError = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
        if raiseError != .success {
            logger.error("Failed to raise window", metadata: [
                "path": .string(path),
                "error": .string("\(raiseError)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to activate window: \(raiseError)"]
            )
        }
    }
    
    /// Set the window order (front, back, above, below)
    /// - Parameters:
    ///   - path: Window element path
    ///   - orderMode: Order mode (front, back, above, below)
    ///   - referenceWindowPath: Reference window path for relative positioning
    public func setWindowOrder(
        withPath path: String,
        orderMode: WindowOrderMode,
        referenceWindowPath: String?
    ) async throws {
        let windowElement = try await findWindowElement(withPath: path)
        
        // Handle the reference window if provided
        var referenceElement: AXUIElement? = nil
        if let refPath = referenceWindowPath {
            referenceElement = try await findWindowElement(withPath: refPath)
        }
        
        // Apply the ordering based on the mode
        switch orderMode {
        case .front:
            // Bring window to front
            let error = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
            if error != .success {
                logger.error("Failed to bring window to front", metadata: [
                    "path": .string(path),
                    "error": .string("\(error)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to bring window to front: \(error)"]
                )
            }
            
        case .back:
            // Send window to back
            // Note: macOS doesn't have a direct kAXLowerAction, so we need to use a workaround
            // Get all windows and place this one at the bottom of the z-order
            let error = AXUIElementPerformAction(windowElement, "AXLower" as CFString)
            if error != .success {
                logger.error("Failed to send window to back", metadata: [
                    "path": .string(path),
                    "error": .string("\(error)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to send window to back: \(error)"]
                )
            }
            
        case .above:
            // Place window above reference window
            if referenceElement == nil {
                logger.error("Reference window required for above ordering", metadata: [
                    "path": .string(path)
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.invalidActionParams,
                    userInfo: [NSLocalizedDescriptionKey: "Reference window path required for above ordering"]
                )
            }
            
            // Custom window ordering is complex in macOS and may require app-specific implementations
            // This uses a general approach that may not work in all apps
            let error = AXUIElementPerformAction(windowElement, kAXRaiseAction as CFString)
            if error != .success {
                logger.error("Failed to place window above reference", metadata: [
                    "path": .string(path),
                    "refPath": referenceWindowPath.map { .string($0) } ?? "nil",
                    "error": .string("\(error)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to place window above reference: \(error)"]
                )
            }
            
        case .below:
            // Place window below reference window
            if referenceElement == nil {
                logger.error("Reference window required for below ordering", metadata: [
                    "path": .string(path)
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.invalidActionParams,
                    userInfo: [NSLocalizedDescriptionKey: "Reference window path required for below ordering"]
                )
            }
            
            // This is a workaround since macOS doesn't directly support placing one window below another
            // First lower this window, then raise the reference
            let lowerError = AXUIElementPerformAction(windowElement, "AXLower" as CFString)
            let raiseError = AXUIElementPerformAction(referenceElement!, kAXRaiseAction as CFString)
            
            if lowerError != .success || raiseError != .success {
                logger.error("Failed to place window below reference", metadata: [
                    "path": .string(path),
                    "refPath": referenceWindowPath.map { .string($0) } ?? "nil",
                    "lowerError": .string("\(lowerError)"),
                    "raiseError": .string("\(raiseError)")
                ])
                throw NSError(
                    domain: "com.macos.mcp.accessibility",
                    code: MacMCPErrorCode.accessibilityError,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to place window below reference: \(lowerError), \(raiseError)"]
                )
            }
        }
    }
    
    /// Focus a window (give it keyboard focus)
    /// - Parameter path: Window element path
    public func focusWindow(
        withPath path: String
    ) async throws {
        
        // Activate the window first
        try await activateWindow(withPath: path)
        
        let windowElement = try await findWindowElement(withPath: path)
        
        // Set the focused attribute
        let error = AXUIElementSetAttributeValue(
            windowElement,
            kAXMainAttribute as CFString,
            true as CFTypeRef
        )
        
        // Check for errors
        if error != .success {
            logger.error("Failed to focus window", metadata: [
                "path": .string(path),
                "error": .string("\(error)")
            ])
            throw NSError(
                domain: "com.macos.mcp.accessibility",
                code: MacMCPErrorCode.accessibilityError,
                userInfo: [NSLocalizedDescriptionKey: "Failed to focus window: \(error)"]
            )
        }
    }
}