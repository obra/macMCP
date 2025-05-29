// ABOUTME: Shared helper for UI change detection across all interaction tools
// ABOUTME: Provides consistent parameter extraction and response formatting with opaque ID mapping

import Foundation
import Logging
import MCP

public enum ChangeDetectionHelper {
  /// Extract change detection parameters from request
  public static func extractChangeDetectionParams(_ params: [String: Value]) -> (
    detectChanges: Bool, delay: TimeInterval
  ) {
    let detectChanges = params["detectChanges"]?.boolValue ?? true
    let delayMs = params["changeDetectionDelay"]?.intValue ?? 200
    let delay = TimeInterval(delayMs) / 1000.0
    return (detectChanges, delay)
  }

  /// Format response with UI changes using opaque IDs
  public static func formatResponse(message: String, uiChanges: UIChanges?, logger: Logger) -> [Tool
    .Content
  ] {
    if let changes = uiChanges, changes.hasChanges {
      var response = ["interaction": ["success": true, "result": message]] as [String: Any]
      var changesDict: [String: Any] = [:]
      if !changes.newElements.isEmpty {
        changesDict["newElements"] = changes.newElements.map { element in
          formatElementForResponse(element)
        }
      }
      if !changes.removedElements.isEmpty {
        // Convert removed element paths to opaque IDs
        changesDict["removedElements"] = changes.removedElements.map { path in
          (try? OpaqueIDEncoder.encode(path)) ?? path
        }
      }
      if !changes.modifiedElements.isEmpty {
        changesDict["modifiedElements"] = changes.modifiedElements.map { change in
          [
            "before": formatElementForResponse(change.before),
            "after": formatElementForResponse(change.after),
          ]
        }
      }
      response["uiChanges"] = changesDict
      do {
        let jsonData = try JSONSerialization.data(
          withJSONObject: response, options: [.prettyPrinted],
        )
        if let jsonString = String(data: jsonData, encoding: .utf8) { return [.text(jsonString)] }
      } catch { logger.warning("Failed to serialize UI changes response: \(error)") }
    }
    // Fallback to simple message
    return [.text(message)]
  }

  /// Format a single UI element for response with opaque ID
  private static func formatElementForResponse(_ element: UIElement) -> [String: Any] {
    // Use EnhancedElementDescriptor with verbosity reduction for consistent formatting
    let descriptor = EnhancedElementDescriptor.from(
      element: element,
      maxDepth: 1,
      showCoordinates: false, // Exclude frame for reduced verbosity
    )
    // Convert to dictionary for JSON serialization
    do {
      let jsonData = try JSONEncoder().encode(descriptor)
      if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
        return jsonObject
      }
    } catch {
      // Fallback to manual formatting if encoding fails
      let opaqueID = (try? OpaqueIDEncoder.encode(element.path)) ?? element.path
      return [
        "id": opaqueID, "role": element.role, "description": element.elementDescription ?? "",
      ]
    }
    // Final fallback
    return ["id": element.path, "role": element.role]
  }

  /// Add change detection schema properties to a tool's input schema
  public static func addChangeDetectionSchemaProperties() -> [String: Value] {
    [
      "detectChanges": .object([
        "type": .string("boolean"),
        "description": .string(
          "Enable automatic UI change detection after interaction (default: true)"),
        "default": .bool(true),
      ]),
      "changeDetectionDelay": .object([
        "type": .string("integer"),
        "description": .string("Milliseconds to wait before capturing UI changes (default: 200)"),
        "default": .int(200),
      ]),
    ]
  }
}
