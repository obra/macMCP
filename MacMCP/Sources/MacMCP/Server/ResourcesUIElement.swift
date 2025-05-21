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
        
        // Extract the UI path - needs special handling since it can contain multiple segments
        let uiPath: String
        
        // Extract the UI path based on the URI pattern
        if uri.hasPrefix("macos://ui/") {
            // Path should be everything after "macos://ui/"
            uiPath = String(uri.dropFirst(11))
        } else {
            throw ResourceURIError.invalidURIFormat(uri)
        }
        
        // Build the full element path
        let fullPath = "macos://ui/\(uiPath)"
        
        // Parse query parameters
        let queryParams = components.parsedQueryParameters
        let maxDepth = Int(queryParams.custom["maxDepth"] ?? "5") ?? 5
        let interactableOnly = queryParams.custom["interactable"]?.lowercased() == "true"
        
        do {
            // Look up the element by path
            let element = try await accessibilityService.findElementByPath(path: fullPath)
            
            guard let element = element else {
                throw MCPError.invalidParams("Element not found for path: \(fullPath)")
            }
            
            // For interactable=true query parameter, we filter the entire tree to interactable elements
            if interactableOnly {
                // First, collect all interactable elements in the tree up to maxDepth
                var interactableElements: [UIElement] = []
                let limit = Int(queryParams.custom["limit"] ?? "100") ?? 100
                
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
                
                // Convert to descriptors with paths
                let descriptors = interactableElements.map { element in
                    ElementDescriptor.from(
                        element: element,
                        includeChildren: false,
                        includePath: true
                    )
                }
                
                // Encode as JSON
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(descriptors)
                
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    throw MCPError.internalError("Failed to encode interactable elements as JSON")
                }
                
                // Create metadata
                let metadata = ResourcesRead.ResourceMetadata(
                    mimeType: "application/json",
                    size: jsonString.count,
                    additionalMetadata: [
                        "path": .string(fullPath),
                        "interactableCount": .double(Double(interactableElements.count)),
                        "maxDepth": .double(Double(maxDepth)),
                        "limit": .double(Double(limit))
                    ]
                )
                
                return (.text(jsonString), metadata)
            }
            
            // Convert to ElementDescriptor with children based on maxDepth
            let includeChildren = maxDepth > 0
            let descriptor = ElementDescriptor.from(
                element: element,
                includeChildren: includeChildren,
                includePath: true
            )
            
            // Encode the descriptor as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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