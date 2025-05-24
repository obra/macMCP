// ABOUTME: ResourcesUIElement.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Resource handler for UI elements
open class UIElementResourceHandler: ResourceHandler, @unchecked Sendable {
    /// The URI pattern for this resource
    public let uriPattern = "macos://ui/{uiPath*}"
    
    /// Human-readable name for the resource
    public let name = "UI Element"
    
    /// Description of the resource
    public let description = "Provides access to UI elements by path"
    
    /// The accessibility service to use
    private let accessibilityService: any AccessibilityServiceProtocol
    
    /// Logger for this handler
    private let logger: Logger
    
    /// Initialize with an accessibility service
    /// - Parameters:
    ///   - accessibilityService: The accessibility service to use
    ///   - logger: The logger to use
    public init(accessibilityService: any AccessibilityServiceProtocol, logger: Logger) {
        self.accessibilityService = accessibilityService
        self.logger = logger
    }
    
    /// Handle a read request for this resource
    /// - Parameters:
    ///   - uri: The resource URI
    ///   - components: Parsed URI components
    /// - Returns: The resource content and metadata
    /// - Throws: Error if the resource cannot be read
    public func handleRead(uri: String, components: ResourceURIComponents) async throws -> (ResourcesRead.ResourceContent, ResourcesRead.ResourceMetadata?) {
        logger.debug("Handling UI element read request", metadata: ["uri": "\(uri)"])
        
        // Parse the URI properly using the URI parser
        let parsedURI: ResourceURIComponents
        do {
            parsedURI = try ResourceURIParser.parse(uri)
        } catch {
            throw ResourceURIError.invalidURIFormat(uri)
        }
        
        // The URI path components should start with "ui"
        let pathComponents = parsedURI.pathComponents
        if pathComponents.isEmpty || pathComponents[0] != "ui" {
            throw ResourceURIError.invalidURIFormat("Path must start with 'ui': \(uri)")
        }
        
        // Extract the UI element path without the 'ui' prefix but maintain the rest of the path structure
        // (For now, we don't need this since we're using the full URI)
        
        // Build the full element path
        let fullPath = uri
        
        // Parse query parameters - use the values properly extracted by the parser
        let queryParams = components.parsedQueryParameters
        let maxDepth = queryParams.maxDepth
        
        // Look directly at the parsed query parameters
        let interactableValue = queryParams.interactable
        logger.debug("parsed query params: \(queryParams.custom), direct interactable value: \(interactableValue)")
        
        let interactableOnly = interactableValue
        logger.debug("interactableOnly flag: \(interactableOnly)")
        
        do {
            // Look up the element by path
            let element = try await accessibilityService.findElementByPath(path: fullPath)
            
            guard let element = element else {
                throw MCPError.invalidParams("Element not found for path: \(fullPath)")
            }
            
            // Debug the query parameters and interactableOnly flag - print individual keys
            logger.debug("Query parameters keys: \(queryParams.custom.keys)")
            for (key, value) in queryParams.custom {
                logger.debug("Query parameter: \(key) = \(value)")
            }
            logger.debug("interactableOnly flag: \(interactableOnly)")
            
            // Print components directly for debugging
            logger.debug("Raw URI components path: \(components.path)")
            logger.debug("Raw URI components query params: \(components.queryParameters)")
            
            // For interactable=true query parameter, we filter the entire tree to interactable elements
            if interactableOnly {
                // First, collect all interactable elements in the tree up to maxDepth
                var interactableElements: [UIElement] = []
                let limit = queryParams.limit
                
                // Recursive function to find interactable elements
                func findInteractableElements(in element: UIElement, depth: Int) {
                    // Check if this element is interactable
                    let isInteractable = element.actions.contains { action in
                        ["AXPress", "AXClick", "AXRaise", "AXFocus"].contains(action)
                    }
                    
                    if isInteractable {
                        interactableElements.append(element)
                        if interactableElements.count >= limit {
                            return
                        }
                    }
                    
                    // Recurse into children if we haven't reached max depth
                    if depth < maxDepth {
                        for child in element.children {
                            findInteractableElements(in: child, depth: depth + 1)
                            if interactableElements.count >= limit {
                                return
                            }
                        }
                    }
                }
                
                // Start the search with the root element
                findInteractableElements(in: element, depth: 0)
                
                logger.debug("Found \(interactableElements.count) interactable elements")
                
                // Convert to descriptors with paths
                let descriptors = interactableElements.map { element in
                    EnhancedElementDescriptor.from(
                        element: element,
                        maxDepth: 0  // Don't include children for interactable list
                    )
                }
                
                logger.debug("Created \(descriptors.count) element descriptors")
                
                // Verify that we're encoding an array when interactable=true
                logger.debug("Encoding \(descriptors.count) interactable elements as JSON array")
                
                // Encode as JSON
                let encoder = JSONConfiguration.encoder
                let jsonData = try encoder.encode(descriptors)
                
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    throw MCPError.internalError("Failed to encode interactable elements as JSON")
                }
                
                // Verify array format for debugging
                logger.debug("JSON response first char: \(jsonString.first ?? Character("?"))")
                logger.debug("JSON response last char: \(jsonString.last ?? Character("?"))")
                
                // Create metadata - ensure interactableCount is included
                let additionalMetadata: [String: Value] = [
                    "path": .string(fullPath),
                    "interactableCount": .double(Double(interactableElements.count)),
                    "maxDepth": .double(Double(maxDepth)),
                    "limit": .double(Double(limit))
                ]
                
                // Debug log the metadata
                logger.debug("Setting interactableCount metadata: \(interactableElements.count)")
                logger.debug("Full additionalMetadata: \(additionalMetadata)")
                
                let metadata = ResourcesRead.ResourceMetadata(
                    mimeType: "application/json",
                    size: jsonString.count,
                    additionalMetadata: additionalMetadata
                )
                
                return (.text(jsonString), metadata)
            }
            
            // Convert to EnhancedElementDescriptor with children based on maxDepth
            let descriptor = EnhancedElementDescriptor.from(
                element: element,
                maxDepth: maxDepth
            )
            
            // Encode the descriptor as JSON
            let encoder = JSONConfiguration.encoder
            let jsonData = try encoder.encode(descriptor)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode element as JSON")
            }
            
            // Create metadata
            let metadata = ResourcesRead.ResourceMetadata(
                mimeType: "application/json",
                size: jsonString.count,
                additionalMetadata: [
                    "path": .string(fullPath),
                    "role": .string(element.role),
                    "hasChildren": .bool(!element.children.isEmpty),
                    "childCount": .double(Double(element.children.count))
                ]
            )
            
            return (.text(jsonString), metadata)
        } catch {
            logger.error("Failed to get UI element", metadata: [
                "path": "\(fullPath)",
                "error": "\(error.localizedDescription)"
            ])
            
            if let pathError = error as? ElementPathError {
                throw MCPError.invalidParams("Invalid element path: \(pathError.description)")
            } else if let axError = error as? AccessibilityPermissions.Error {
                let permissionError = createPermissionError(
                    message: "Accessibility permission denied: \(axError.localizedDescription)"
                )
                throw permissionError.asMCPError
            } else if let mcpError = error as? MCPError {
                throw mcpError
            } else {
                throw MCPError.internalError("Failed to get UI element: \(error.localizedDescription)")
            }
        }
    }
}