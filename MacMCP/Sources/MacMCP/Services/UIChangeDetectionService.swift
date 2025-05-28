// ABOUTME: Service for detecting changes in UI state between before/after snapshots
// ABOUTME: Provides diff functionality to track new, removed, and modified UI elements

import Foundation
import Logging

public struct UIElementChange {
    public let before: UIElement
    public let after: UIElement
    
    public init(before: UIElement, after: UIElement) {
        self.before = before
        self.after = after
    }
}

public struct UIChanges {
    public let newElements: [UIElement]
    public let removedElements: [String]
    public let modifiedElements: [UIElementChange]
    
    public init(newElements: [UIElement] = [], removedElements: [String] = [], modifiedElements: [UIElementChange] = []) {
        self.newElements = newElements
        self.removedElements = removedElements
        self.modifiedElements = modifiedElements
    }
    
    public var hasChanges: Bool {
        !newElements.isEmpty || !removedElements.isEmpty || !modifiedElements.isEmpty
    }
}

public protocol UIChangeDetectionServiceProtocol {
    func captureUISnapshot(scope: UIElementScope, maxDepth: Int) async throws -> [String: UIElement]
    func detectChanges(before: [String: UIElement], after: [String: UIElement]) -> UIChanges
}

public final class UIChangeDetectionService: UIChangeDetectionServiceProtocol {
    private let accessibilityService: AccessibilityServiceProtocol
    private let logger = Logger(label: "UIChangeDetectionService")
    
    public init(accessibilityService: AccessibilityServiceProtocol) {
        self.accessibilityService = accessibilityService
    }
    
    public func captureUISnapshot(scope: UIElementScope, maxDepth: Int = 10) async throws -> [String: UIElement] {
        logger.debug("Capturing UI snapshot with scope: \(scope), maxDepth: \(maxDepth)")
        
        let elements = try await accessibilityService.findUIElements(
            role: nil,
            title: nil,
            titleContains: nil,
            value: nil,
            valueContains: nil,
            description: nil,
            descriptionContains: nil,
            textContains: nil,
            anyFieldContains: nil,
            isInteractable: nil,
            isEnabled: nil,
            inMenus: nil,
            inMainContent: nil,
            elementTypes: nil,
            scope: scope,
            recursive: true,
            maxDepth: maxDepth
        )
        
        var snapshot: [String: UIElement] = [:]
        for element in elements {
            snapshot[element.path] = element
        }
        
        logger.debug("Captured snapshot with \(snapshot.count) elements")
        return snapshot
    }
    
    public func detectChanges(before: [String: UIElement], after: [String: UIElement]) -> UIChanges {
        let beforeIds = Set(before.keys)
        let afterIds = Set(after.keys)
        
        // Find new and removed elements
        let newElementIds = afterIds.subtracting(beforeIds)
        let removedElementIds = beforeIds.subtracting(afterIds)
        let commonIds = beforeIds.intersection(afterIds)
        
        // Find modified elements (any property change)
        var modifiedElements: [UIElementChange] = []
        for commonId in commonIds {
            let beforeElement = before[commonId]!
            let afterElement = after[commonId]!
            
            if beforeElement != afterElement {
                modifiedElements.append(UIElementChange(before: beforeElement, after: afterElement))
            }
        }
        
        // Build result
        let newElements = newElementIds.compactMap { after[$0] }
        let removedElements = Array(removedElementIds)
        
        let changes = UIChanges(
            newElements: newElements,
            removedElements: removedElements,
            modifiedElements: modifiedElements
        )
        
        logger.debug("Detected changes: \(newElements.count) new, \(removedElements.count) removed, \(modifiedElements.count) modified")
        
        return changes
    }
}