// ABOUTME: ResourcesApplicationWindows.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Resource handler for application windows
open class ApplicationWindowsResourceHandler: ResourceHandler, @unchecked Sendable {
    /// The URI pattern for this resource
    public let uriPattern = "macos://applications/{bundleId}/windows"
    
    /// Human-readable name for the resource
    public let name = "Application Windows"
    
    /// Description of the resource
    public let description = "Lists all windows for a specific application"
    
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
        logger.debug("Handling application windows read request", metadata: ["uri": "\(uri)"])
        
        // Extract parameters from the URI
        let parameters = try extractParameters(from: uri, pattern: uriPattern)
        
        guard let bundleId = parameters["bundleId"] else {
            throw ResourceURIError.missingParameter("bundleId")
        }
        
        // Parse query parameters
        let queryParams = components.parsedQueryParameters
        let includeMinimized = queryParams.custom["includeMinimized"]?.lowercased() == "true"
        
        do {
            // Get the application element
            let appElement = try await accessibilityService.getApplicationUIElement(
                bundleId: bundleId,
                recursive: true,
                maxDepth: 2  // Only need shallow depth for windows
            )
            
            // Find all window elements
            var windows: [WindowDescriptor] = []
            
            // Look for window elements in the children
            for child in appElement.children {
                if child.role == AXAttribute.Role.window {
                    if let window = WindowDescriptor.from(element: child) {
                        // Filter minimized windows if needed
                        if includeMinimized || !window.isMinimized {
                            windows.append(window)
                        }
                    }
                }
            }
            
            // Encode the windows as JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(windows)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode windows as JSON")
            }
            
            // Create metadata
            let metadata = ResourcesRead.ResourceMetadata(
                mimeType: "application/json",
                size: jsonString.count,
                additionalMetadata: [
                    "bundleId": .string(bundleId),
                    "windowCount": .double(Double(windows.count))
                ]
            )
            
            return (.text(jsonString), metadata)
        } catch {
            logger.error("Failed to get application windows", metadata: [
                "bundleId": "\(bundleId)",
                "error": "\(error.localizedDescription)"
            ])
            
            if let axError = error as? AccessibilityPermissions.Error {
                let permissionError = createPermissionError(
                    message: "Accessibility permission denied: \(axError.localizedDescription)"
                )
                throw permissionError.asMCPError
            } else {
                throw MCPError.internalError("Failed to get application windows: \(error.localizedDescription)")
            }
        }
    }
}