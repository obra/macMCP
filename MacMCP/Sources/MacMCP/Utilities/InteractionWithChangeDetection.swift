// ABOUTME: Wrapper utility for performing interactions with automatic UI change detection
// ABOUTME: Captures before/after UI snapshots and provides diff results alongside interaction results

import Foundation
import Logging

public struct InteractionResult<T> {
  public let result: T
  public let uiChanges: UIChanges?
  public init(result: T, uiChanges: UIChanges? = nil) {
    self.result = result
    self.uiChanges = uiChanges
  }
}

public struct InteractionWithChangeDetection {
  private let changeDetectionService: UIChangeDetectionServiceProtocol
  private let logger = Logger(label: "InteractionWithChangeDetection")
  public init(changeDetectionService: UIChangeDetectionServiceProtocol) {
    self.changeDetectionService = changeDetectionService
  }
  public func performWithChangeDetection<T>(
    scope: UIElementScope = .focusedApplication,
    detectChanges: Bool = true,
    delay: TimeInterval = 0.2,
    maxDepth: Int = 10,
    interaction: () async throws -> T
  ) async throws -> InteractionResult<T> {
    var beforeSnapshot: [String: UIElement]?
    // Capture before snapshot if change detection is enabled
    if detectChanges {
      do {
        beforeSnapshot = try await changeDetectionService.captureUISnapshot(
          scope: scope, maxDepth: maxDepth)
        logger.debug("Captured before snapshot with \(beforeSnapshot?.count ?? 0) elements")
      } catch {
        logger.warning("Failed to capture before snapshot: \(error)")
        // Continue without change detection rather than failing the interaction
      }
    }
    // Perform the actual interaction
    let result = try await interaction()
    logger.debug("Interaction completed successfully")
    var changes: UIChanges?
    // Capture after snapshot and detect changes if enabled
    if detectChanges, let before = beforeSnapshot {
      do {
        // Wait for UI to settle after interaction
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        let afterSnapshot = try await changeDetectionService.captureUISnapshot(
          scope: scope, maxDepth: maxDepth)
        logger.debug("Captured after snapshot with \(afterSnapshot.count) elements")
        changes = changeDetectionService.detectChanges(before: before, after: afterSnapshot)
        if let changes = changes, changes.hasChanges {
          logger.info(
            "UI changes detected: \(changes.newElements.count) new, \(changes.removedElements.count) removed, \(changes.modifiedElements.count) modified"
          )
        } else {
          logger.debug("No UI changes detected")
        }
      } catch {
        logger.warning("Failed to capture after snapshot or detect changes: \(error)")
        // Continue without change detection results rather than failing
      }
    }
    return InteractionResult(result: result, uiChanges: changes)
  }
}
