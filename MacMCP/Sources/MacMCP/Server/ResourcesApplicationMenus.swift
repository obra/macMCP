// ABOUTME: ResourcesApplicationMenus.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

/// Resource handler for application menus
open class ApplicationMenusResourceHandler: ResourceHandler, @unchecked Sendable {
  /// The URI pattern for this resource
  public let uriPattern = "macos://applications/{bundleId}/menus"
  /// Human-readable name for the resource
  public let name = "Application Menus"
  /// Description of the resource
  public let description = "Lists menu structure for a specific application"
  /// The menu navigation service to use
  private let menuNavigationService: any MenuNavigationServiceProtocol
  /// Logger for this handler
  private let logger: Logger
  /// Initialize with a menu navigation service
  /// - Parameters:
  ///   - menuNavigationService: The menu navigation service to use
  ///   - logger: The logger to use
  public init(menuNavigationService: any MenuNavigationServiceProtocol, logger: Logger) {
    self.menuNavigationService = menuNavigationService
    self.logger = logger
  }

  /// Handle a read request for this resource
  /// - Parameters:
  ///   - uri: The resource URI
  ///   - components: Parsed URI components
  /// - Returns: The resource content and metadata
  /// - Throws: Error if the resource cannot be read
  public func handleRead(uri: String, components: ResourceURIComponents) async throws -> (
    ResourcesRead.ResourceContent, ResourcesRead.ResourceMetadata?
  ) {
    logger.debug("Handling application menus read request", metadata: ["uri": "\(uri)"])
    // Extract parameters from the URI
    let parameters = try extractParameters(from: uri, pattern: uriPattern)
    guard let bundleId = parameters["bundleId"] else {
      throw ResourceURIError.missingParameter("bundleId")
    }
    // Parse query parameters
    let queryParams = components.parsedQueryParameters
    let includeSubmenus = queryParams.custom["includeSubmenus"]?.lowercased() == "true"
    let menuTitle = queryParams.custom["menuTitle"]
    do {
      // If a specific menu title is provided, get that menu's items
      if let menuTitle {
        // Get specific menu items
        let menuItems = try await menuNavigationService.getMenuItems(
          bundleId: bundleId,
          menuTitle: menuTitle,
          includeSubmenus: includeSubmenus,
        )
        // Encode the menu items as JSON
        let encoder = JSONConfiguration.encoder
        let jsonData = try encoder.encode(menuItems)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
          throw MCPError.internalError("Failed to encode menu items as JSON")
        }
        // Create metadata
        let metadata = ResourcesRead.ResourceMetadata(
          mimeType: "application/json",
          size: jsonString.count,
          additionalMetadata: [
            "bundleId": .string(bundleId), "menuTitle": .string(menuTitle),
            "itemCount": .double(Double(menuItems.count)),
          ],
        )
        return (.text(jsonString), metadata)
      } else {
        // Get all top-level menus
        let menus = try await menuNavigationService.getApplicationMenus(bundleId: bundleId)
        // Encode the menus as JSON
        let encoder = JSONConfiguration.encoder
        let jsonData = try encoder.encode(menus)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
          throw MCPError.internalError("Failed to encode menus as JSON")
        }
        // Create metadata
        let metadata = ResourcesRead.ResourceMetadata(
          mimeType: "application/json",
          size: jsonString.count,
          additionalMetadata: [
            "bundleId": .string(bundleId), "menuCount": .double(Double(menus.count)),
          ],
        )
        return (.text(jsonString), metadata)
      }
    } catch {
      logger.error(
        "Failed to get application menus",
        metadata: ["bundleId": "\(bundleId)", "error": "\(error.localizedDescription)"],
      )
      if let navigationError = error as? MenuNavigationError {
        throw MCPError.internalError("Menu navigation error: \(navigationError.description)")
      } else if let axError = error as? AccessibilityPermissions.Error {
        let permissionError = createPermissionError(
          message: "Accessibility permission denied: \(axError.localizedDescription)",
        )
        throw permissionError.asMCPError
      } else {
        throw MCPError.internalError(
          "Failed to get application menus: \(error.localizedDescription)",
        )
      }
    }
  }
}
