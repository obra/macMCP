// ABOUTME: ApplicationsResourceHandler.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Handler for the applications resource
public struct ApplicationsResourceHandler: ResourceHandler {
    /// Resource URI pattern
    public let uriPattern = "applications"
    
    /// Resource name
    public let name = "Running Applications"
    
    /// Resource description
    public let description = "List of currently running applications"
    
    /// The application service
    private let applicationService: ApplicationServiceProtocol
    
    /// Logger for this handler
    private let logger: Logger
    
    /// Initialize with an application service
    /// - Parameters:
    ///   - applicationService: The application service
    ///   - logger: The logger
    public init(applicationService: ApplicationServiceProtocol, logger: Logger) {
        self.applicationService = applicationService
        self.logger = logger
    }
    
    /// Handle a resource read request
    /// - Parameters:
    ///   - uri: The resource URI
    ///   - components: Parsed URI components
    /// - Returns: The resource content and metadata
    /// - Throws: Error if the resource cannot be read
    public func handleRead(uri: String, components: ResourceURIComponents) async throws -> (ResourcesRead.ResourceContent, ResourcesRead.ResourceMetadata?) {
        logger.debug("Handling applications resource read", metadata: ["uri": "\(uri)"])
        
        // Get running applications
        let runningApps = try await applicationService.getRunningApplications()
        
        // Serialize to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(runningApps)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw MCPError.internalError("Failed to encode running applications as JSON")
            }
            
            // Create metadata
            let metadata = ResourcesRead.ResourceMetadata(
                mimeType: mimeType,
                size: jsonString.utf8.count
            )
            
            return (.text(jsonString), metadata)
        } catch {
            logger.error("Error encoding running applications: \(error.localizedDescription)")
            throw MCPError.internalError("Failed to encode running applications: \(error.localizedDescription)")
        }
    }
}