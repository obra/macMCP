// ABOUTME: This file defines the Keyboard Interaction Tool for MCP.
// ABOUTME: It provides intuitive keyboard shortcuts, typing, and key sequence capabilities.

import Foundation
import MCP
import Logging
import AppKit

/// Tool for interacting with the keyboard on macOS
public struct KeyboardInteractionTool: @unchecked Sendable {
    /// The name of the tool
    public let name = ToolNames.keyboardInteraction
    
    /// Description of the tool
    public let description = "Execute keyboard shortcuts, type text, and press keys with human-readable commands"
    
    /// Input schema for the tool
    public private(set) var inputSchema: Value
    
    /// Tool annotations
    public private(set) var annotations: Tool.Annotations
    
    /// The logger
    private let logger: Logger
    
    /// The interaction service for UI interactions
    private let interactionService: any UIInteractionServiceProtocol
    
    /// Create a new keyboard interaction tool
    /// - Parameters:
    ///   - interactionService: The UI interaction service
    ///   - logger: Optional logger to use
    public init(
        interactionService: any UIInteractionServiceProtocol,
        logger: Logger? = nil
    ) {
        self.interactionService = interactionService
        self.logger = logger ?? Logger(label: "mcp.tool.keyboard")
        
        // Set tool annotations
        self.annotations = .init(
            title: "Keyboard Interaction",
            readOnlyHint: false,
            destructiveHint: true,
            idempotentHint: false,
            openWorldHint: true
        )
        
        // Initialize inputSchema with an empty object first
        self.inputSchema = .object([:])
        
        // Create the input schema
        self.inputSchema = createInputSchema()
    }
    
    /// Create the input schema for the tool
    private func createInputSchema() -> Value {
        return .object([
            "type": .string("object"),
            "properties": .object([
                "action": .object([
                    "type": .string("string"),
                    "description": .string("The keyboard action to perform"),
                    "enum": .array([
                        .string("type_text"),
                        .string("key_sequence")
                    ])
                ]),
                "text": .object([
                    "type": .string("string"),
                    "description": .string("Text to type (required for type_text action)")
                ]),
                "sequence": .object([
                    "type": .string("array"),
                    "description": .string("Array of key events to execute (required for key_sequence action)")
                ])
            ]),
            "required": .array([.string("action")]),
            "additionalProperties": .bool(false)
        ])
    }
    
    /// Tool handler function (computed property that creates a handler capturing self)
    public var handler: @Sendable ([String: Value]?) async throws -> [Tool.Content] {
        // Return a closure that captures self and uses the injected interactionService
        return { [self] params in
            logger.info("Processing keyboard interaction request")
            
            do {
                let result = try await self.processRequest(params)
                return result
            } catch {
                logger.error("KeyboardInteractionTool.handler error: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    /// Process a keyboard interaction request
    /// - Parameters:
    ///   - params: The request parameters
    /// - Returns: The tool result content
    private func processRequest(
        _ params: [String: Value]?
    ) async throws -> [Tool.Content] {
        guard let params = params else {
            throw createError(
                message: "Parameters are required",
                context: ["toolName": name]
            ).asMCPError
        }
        
        // Get the action
        guard let actionValue = params["action"]?.stringValue else {
            throw createError(
                message: "Action is required",
                context: ["toolName": name]
            ).asMCPError
        }
        
        // Process based on action type
        switch actionValue {
        case "type_text":
            return try await handleTypeText(params)
        case "key_sequence":
            return try await handleKeySequence(params)
        default:
            throw createError(
                message: "Invalid action: \(actionValue). Must be one of: type_text, key_sequence",
                context: [
                    "toolName": name,
                    "providedAction": actionValue,
                    "validActions": "type_text, key_sequence"
                ]
            ).asMCPError
        }
    }
    
    /// Handle type_text action
    /// - Parameters:
    ///   - params: The request parameters
    /// - Returns: The tool result content
    private func handleTypeText(
        _ params: [String: Value]
    ) async throws -> [Tool.Content] {
        guard let text = params["text"]?.stringValue else {
            throw createError(
                message: "Text is required for type_text action",
                context: [
                    "toolName": name,
                    "action": "type_text",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        // Type the text
        logger.debug("Typing text", metadata: ["length": "\(text.count)"])
        
        for character in text {
            // Map each character to its key code and modifiers
            guard let keyCodeInfo = KeyCodeMapping.keyCodeForCharacter(character) else {
                throw createError(
                    message: "Unsupported character: \(character)",
                    context: [
                        "toolName": name,
                        "action": "type_text",
                        "character": String(character)
                    ]
                ).asMCPError
            }
            
            // Press the key with modifiers (if any)
            let keyCode = Int(keyCodeInfo.keyCode)
            let modifiers = keyCodeInfo.modifiers
            
            logger.debug("Typing character", metadata: [
                "character": "\(character)",
                "keyCode": "\(keyCode)",
                "modifiers": "\(modifiers)"
            ])
            
            try await interactionService.pressKey(keyCode: keyCode, modifiers: modifiers)
            
            // Add a small delay between keypresses for a more natural typing effect
            try await Task.sleep(for: .milliseconds(30))
        }
        
        // Return success message
        return [.text("Successfully typed \(text.count) characters")]
    }
    
    /// Handle key_sequence action
    /// - Parameters:
    ///   - params: The request parameters
    /// - Returns: The tool result content
    private func handleKeySequence(
        _ params: [String: Value]
    ) async throws -> [Tool.Content] {
        guard let sequenceArray = params["sequence"]?.arrayValue else {
            throw createError(
                message: "Sequence is required for key_sequence action",
                context: [
                    "toolName": name,
                    "action": "key_sequence",
                    "providedParams": "\(params.keys.joined(separator: ", "))"
                ]
            ).asMCPError
        }
        
        // Process the sequence
        logger.debug("Executing key sequence", metadata: ["steps": "\(sequenceArray.count)"])
        
        // Track currently pressed modifier keys
        var activeModifiers: [String: Bool] = [:]
        
        // Process each item in the sequence
        for (index, item) in sequenceArray.enumerated() {
            guard let itemObj = item.objectValue else {
                throw createError(
                    message: "Sequence item must be an object",
                    context: [
                        "toolName": name,
                        "action": "key_sequence",
                        "index": "\(index)"
                    ]
                ).asMCPError
            }
            
            logger.debug("Processing sequence item", metadata: ["index": "\(index)", "item": "\(itemObj)"])
            
            // Process based on the action type
            if let tapKey = itemObj["tap"]?.stringValue {
                // Handle TAP event (press and release a key)
                try await handleTapEvent(
                    key: tapKey,
                    modifiers: extractModifiers(from: itemObj),
                    activeModifiers: &activeModifiers
                )
            } else if let pressKey = itemObj["press"]?.stringValue {
                // Handle PRESS event (press a key without releasing)
                try await handlePressEvent(
                    key: pressKey,
                    activeModifiers: &activeModifiers
                )
            } else if let releaseKey = itemObj["release"]?.stringValue {
                // Handle RELEASE event (release a previously pressed key)
                try await handleReleaseEvent(
                    key: releaseKey,
                    activeModifiers: &activeModifiers
                )
            } else if let delayTime = itemObj["delay"]?.doubleValue {
                // Handle DELAY event (pause execution)
                try await handleDelayEvent(seconds: delayTime)
            } else {
                throw createError(
                    message: "Invalid sequence item, must contain one of: tap, press, release, or delay",
                    context: [
                        "toolName": name,
                        "action": "key_sequence",
                        "index": "\(index)",
                        "keys": "\(itemObj.keys.joined(separator: ", "))"
                    ]
                ).asMCPError
            }
        }
        
        // Ensure all modifier keys are released
        try await releaseAllModifiers(activeModifiers: &activeModifiers)
        
        // Return success message
        return [.text("Successfully executed key sequence with \(sequenceArray.count) commands")]
    }
    
    /// Extract modifier keys from a sequence item
    /// - Parameter item: The sequence item
    /// - Returns: Array of modifier key names, or nil if none
    private func extractModifiers(from item: [String: Value]) -> [String]? {
        guard let modifiersArray = item["modifiers"]?.arrayValue else {
            return nil
        }
        
        var modifiers: [String] = []
        for modifier in modifiersArray {
            if let modifierName = modifier.stringValue {
                modifiers.append(modifierName)
            }
        }
        
        return modifiers.isEmpty ? nil : modifiers
    }
    
    /// Handle a tap event (press and release a key, with optional modifiers)
    /// - Parameters:
    ///   - key: The key to tap
    ///   - modifiers: Optional modifier keys to hold during the tap
    ///   - activeModifiers: Dictionary of currently pressed modifier keys
    private func handleTapEvent(
        key: String,
        modifiers: [String]?,
        activeModifiers: inout [String: Bool]
    ) async throws {
        logger.debug("Handling tap event", metadata: [
            "key": "\(key)",
            "modifiers": modifiers != nil ? "\(modifiers!.joined(separator: ", "))" : "none"
        ])
        
        // If the key is a modifier key, just press and release it
        if KeyCodeMapping.isModifierKey(key) {
            // Get key code for the modifier
            guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(key) else {
                throw createError(
                    message: "Unsupported key: \(key)",
                    context: ["action": "tap", "key": key]
                ).asMCPError
            }
            
            // Press and release the modifier key
            try await interactionService.pressKey(keyCode: Int(keyCodeInfo.keyCode), modifiers: nil)
            return
        }
        
        // For regular keys with modifiers, we need to:
        // 1. Press any modifiers that aren't already active
        // 2. Press and release the key with all modifiers active
        // 3. Release any modifiers that weren't originally active
        
        let temporaryModifiers = try await pressTemporaryModifiers(
            requestedModifiers: modifiers,
            activeModifiers: &activeModifiers
        )
        
        // Calculate combined modifiers
        var combinedModifiers: CGEventFlags = []
        for (modKey, isActive) in activeModifiers {
            if isActive {
                let modFlag = KeyCodeMapping.modifierFlagsForNames([modKey])
                if !modFlag.isEmpty {
                    combinedModifiers.formUnion(modFlag)
                }
            }
        }
        
        // Get the key code for the key to tap
        guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(key) else {
            // Release temporary modifiers before throwing
            try await releaseTemporaryModifiers(temporaryModifiers: temporaryModifiers, activeModifiers: &activeModifiers)
            
            throw createError(
                message: "Unsupported key: \(key)",
                context: ["action": "tap", "key": key]
            ).asMCPError
        }
        
        // Press and release the key with all active modifiers
        try await interactionService.pressKey(
            keyCode: Int(keyCodeInfo.keyCode),
            modifiers: combinedModifiers.isEmpty ? nil : combinedModifiers
        )
        
        // Release temporary modifiers
        try await releaseTemporaryModifiers(
            temporaryModifiers: temporaryModifiers,
            activeModifiers: &activeModifiers
        )
    }
    
    /// Handle a press event (press a key without releasing it)
    /// - Parameters:
    ///   - key: The key to press
    ///   - activeModifiers: Dictionary of currently pressed modifier keys
    private func handlePressEvent(
        key: String,
        activeModifiers: inout [String: Bool]
    ) async throws {
        logger.debug("Handling press event", metadata: ["key": "\(key)"])
        
        // Get the key code
        guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(key) else {
            throw createError(
                message: "Unsupported key: \(key)",
                context: ["action": "press", "key": key]
            ).asMCPError
        }
        
        // For modifier keys, just mark them as active
        if KeyCodeMapping.isModifierKey(key) {
            activeModifiers[key] = true
            
            // For visual feedback and to ensure the key is actually pressed,
            // we'll create a key down event but not the corresponding key up
            let eventSource = CGEventSource(stateID: .combinedSessionState)
            let keyDownEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: keyCodeInfo.keyCode,
                keyDown: true
            )
            
            guard let keyDownEvent = keyDownEvent else {
                throw createError(
                    message: "Failed to create key event",
                    context: ["key": key, "keyCode": "\(keyCodeInfo.keyCode)"]
                ).asMCPError
            }
            
            keyDownEvent.post(tap: .cghidEventTap)
            return
        }
        
        // For non-modifier keys, we need to:
        // 1. Calculate all active modifiers
        // 2. Create a key down event without the corresponding up event
        
        // Calculate combined modifiers
        var combinedModifiers: CGEventFlags = []
        for (modKey, isActive) in activeModifiers {
            if isActive {
                let modFlag = KeyCodeMapping.modifierFlagsForNames([modKey])
                if !modFlag.isEmpty {
                    combinedModifiers.formUnion(modFlag)
                }
            }
        }
        
        // Create and post key down event
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        let keyDownEvent = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCodeInfo.keyCode,
            keyDown: true
        )
        
        guard let keyDownEvent = keyDownEvent else {
            throw createError(
                message: "Failed to create key event",
                context: ["key": key, "keyCode": "\(keyCodeInfo.keyCode)"]
            ).asMCPError
        }
        
        // Apply modifiers if any are active
        if !combinedModifiers.isEmpty {
            keyDownEvent.flags = combinedModifiers
        }
        
        keyDownEvent.post(tap: .cghidEventTap)
    }
    
    /// Handle a release event (release a previously pressed key)
    /// - Parameters:
    ///   - key: The key to release
    ///   - activeModifiers: Dictionary of currently pressed modifier keys
    private func handleReleaseEvent(
        key: String,
        activeModifiers: inout [String: Bool]
    ) async throws {
        logger.debug("Handling release event", metadata: ["key": "\(key)"])
        
        // Get the key code
        guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(key) else {
            throw createError(
                message: "Unsupported key: \(key)",
                context: ["action": "release", "key": key]
            ).asMCPError
        }
        
        // For modifier keys, mark them as inactive
        if KeyCodeMapping.isModifierKey(key) {
            activeModifiers[key] = false
        }
        
        // Calculate combined modifiers
        var combinedModifiers: CGEventFlags = []
        for (modKey, isActive) in activeModifiers {
            if isActive {
                let modFlag = KeyCodeMapping.modifierFlagsForNames([modKey])
                if !modFlag.isEmpty {
                    combinedModifiers.formUnion(modFlag)
                }
            }
        }
        
        // Create and post key up event
        let eventSource = CGEventSource(stateID: .combinedSessionState)
        let keyUpEvent = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCodeInfo.keyCode,
            keyDown: false
        )
        
        guard let keyUpEvent = keyUpEvent else {
            throw createError(
                message: "Failed to create key event",
                context: ["key": key, "keyCode": "\(keyCodeInfo.keyCode)"]
            ).asMCPError
        }
        
        // Apply modifiers if any are active
        if !combinedModifiers.isEmpty {
            keyUpEvent.flags = combinedModifiers
        }
        
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    /// Handle a delay event (pause execution)
    /// - Parameter seconds: Number of seconds to delay
    private func handleDelayEvent(seconds: Double) async throws {
        logger.debug("Handling delay event", metadata: ["seconds": "\(seconds)"])
        
        // Convert seconds to nanoseconds, ensuring reasonable bounds
        let boundedSeconds = min(max(seconds, 0.01), 10.0) // Between 10ms and 10s
        let nanoseconds = UInt64(boundedSeconds * 1_000_000_000)
        
        // Sleep for the specified duration
        try await Task.sleep(nanoseconds: nanoseconds)
    }
    
    /// Press temporary modifiers for a tap event
    /// - Parameters:
    ///   - requestedModifiers: Requested modifier keys
    ///   - activeModifiers: Currently active modifier keys
    /// - Returns: Array of temporary modifiers that were pressed
    private func pressTemporaryModifiers(
        requestedModifiers: [String]?,
        activeModifiers: inout [String: Bool]
    ) async throws -> [String] {
        var temporaryModifiers: [String] = []
        
        guard let modifiers = requestedModifiers, !modifiers.isEmpty else {
            return temporaryModifiers
        }
        
        for modifier in modifiers {
            // Skip if this modifier is already active
            if activeModifiers[modifier] == true {
                continue
            }
            
            // Get key code for this modifier
            guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(modifier) else {
                logger.warning("Unsupported modifier key", metadata: ["key": "\(modifier)"])
                continue
            }
            
            // Create and post key down event
            let eventSource = CGEventSource(stateID: .combinedSessionState)
            let keyDownEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: keyCodeInfo.keyCode,
                keyDown: true
            )
            
            guard let keyDownEvent = keyDownEvent else {
                logger.warning("Failed to create modifier key event", metadata: ["key": "\(modifier)"])
                continue
            }
            
            keyDownEvent.post(tap: .cghidEventTap)
            
            // Mark modifier as active and add to temporary list
            activeModifiers[modifier] = true
            temporaryModifiers.append(modifier)
            
            // Small delay to ensure modifier is registered
            try await Task.sleep(for: .milliseconds(10))
        }
        
        return temporaryModifiers
    }
    
    /// Release temporary modifiers after a tap event
    /// - Parameters:
    ///   - temporaryModifiers: Temporary modifiers to release
    ///   - activeModifiers: Currently active modifier keys
    private func releaseTemporaryModifiers(
        temporaryModifiers: [String],
        activeModifiers: inout [String: Bool]
    ) async throws {
        for modifier in temporaryModifiers {
            // Get key code for this modifier
            guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(modifier) else {
                continue
            }
            
            // Create and post key up event
            let eventSource = CGEventSource(stateID: .combinedSessionState)
            let keyUpEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: keyCodeInfo.keyCode,
                keyDown: false
            )
            
            guard let keyUpEvent = keyUpEvent else {
                continue
            }
            
            keyUpEvent.post(tap: .cghidEventTap)
            
            // Mark modifier as inactive
            activeModifiers[modifier] = false
            
            // Small delay to ensure modifier is registered
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    
    /// Release all active modifier keys
    /// - Parameter activeModifiers: Currently active modifier keys
    private func releaseAllModifiers(activeModifiers: inout [String: Bool]) async throws {
        // Get all active modifiers
        let modifiersToRelease = activeModifiers.filter { $0.value }.keys.map { $0 }
        
        for modifier in modifiersToRelease {
            // Get key code for this modifier
            guard let keyCodeInfo = KeyCodeMapping.keyCodeForKey(modifier) else {
                continue
            }
            
            // Create and post key up event
            let eventSource = CGEventSource(stateID: .combinedSessionState)
            let keyUpEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: keyCodeInfo.keyCode,
                keyDown: false
            )
            
            guard let keyUpEvent = keyUpEvent else {
                continue
            }
            
            keyUpEvent.post(tap: .cghidEventTap)
            
            // Mark modifier as inactive
            activeModifiers[modifier] = false
        }
    }
    
    /// Create a standard error
    private func createError(message: String, context: [String: String]) -> KeyboardInteractionError {
        return KeyboardInteractionError(message: message, context: context)
    }
}

/// Error type for keyboard interaction errors
struct KeyboardInteractionError: Swift.Error {
    let message: String
    let context: [String: String]
    
    var asMCPError: MCPError {
        return MCPError.invalidParams(message)
    }
}

