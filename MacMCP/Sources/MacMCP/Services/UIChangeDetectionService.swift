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
  public init(
    newElements: [UIElement] = [], removedElements: [String] = [],
    modifiedElements: [UIElementChange] = []
  ) {
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

  public func captureUISnapshot(scope: UIElementScope, maxDepth: Int = 10) async throws -> [String:
    UIElement
  ] {
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
      maxDepth: maxDepth,
    )
    var snapshot: [String: UIElement] = [:]
    for element in elements {
      snapshot[element.path] = element
    }
    logger.debug("Captured snapshot with \(snapshot.count) elements")
    return snapshot
  }

  public func detectChanges(before: [String: UIElement], after: [String: UIElement]) -> UIChanges {
    // Build trees from both snapshots
    let beforeTrees = buildTrees(from: before)
    let afterTrees = buildTrees(from: after)
    
    // Find tree roots that are completely new or removed
    let beforeRootPaths = Set(beforeTrees.map { $0.path })
    let afterRootPaths = Set(afterTrees.map { $0.path })
    
    let newRootPaths = afterRootPaths.subtracting(beforeRootPaths)
    let removedRootPaths = beforeRootPaths.subtracting(afterRootPaths)
    
    // For new root trees, include the entire tree
    let newElements = afterTrees.filter { newRootPaths.contains($0.path) }
    
    // For existing trees, find subtrees with changes
    let existingRootPaths = beforeRootPaths.intersection(afterRootPaths)
    var modifiedElements: [UIElementChange] = []
    var changedSubtrees: [UIElement] = []
    
    for rootPath in existingRootPaths {
      let beforeTree = beforeTrees.first { $0.path == rootPath }!
      let afterTree = afterTrees.first { $0.path == rootPath }!
      
      // Find changed subtrees within this root
      let (changes, subtrees) = findChangedSubtrees(before: beforeTree, after: afterTree)
      modifiedElements.append(contentsOf: changes)
      changedSubtrees.append(contentsOf: subtrees)
    }
    
    // Combine new elements with changed subtrees
    let allNewElements = newElements + changedSubtrees
    
    let changes = UIChanges(
      newElements: allNewElements,
      removedElements: Array(removedRootPaths),
      modifiedElements: modifiedElements
    )
    
    logger.debug(
      "Tree-based changes: \(allNewElements.count) new/changed trees, \(removedRootPaths.count) removed trees, \(modifiedElements.count) element modifications"
    )
    return changes
  }
  
  /// Build trees from a flat element map
  private func buildTrees(from elementMap: [String: UIElement]) -> [UIElement] {
    // Find root elements (those with no parent in the map)
    let allPaths = Set(elementMap.keys)
    var rootElements: [UIElement] = []
    
    for (path, element) in elementMap {
      // Check if this element has a parent in the map
      let hasParentInMap = allPaths.contains { candidateParentPath in
        candidateParentPath != path && path.hasPrefix(candidateParentPath + "/")
      }
      
      if !hasParentInMap {
        rootElements.append(element)
      }
    }
    
    return rootElements.sorted { $0.path < $1.path }
  }
  
  /// Find changed subtrees by pruning unchanged parts from the tree
  private func findChangedSubtrees(before: UIElement, after: UIElement) -> ([UIElementChange], [UIElement]) {
    var modifications: [UIElementChange] = []
    var changedSubtrees: [UIElement] = []
    
    // Check if this subtree has any changes (recursive)
    let subtreeHasChanges = hasChangesInSubtree(before: before, after: after)
    
    if subtreeHasChanges {
      // If the root elements are different, record the modification
      if before != after {
        modifications.append(UIElementChange(before: before, after: after))
      }
      
      // Prune this tree to only include changed parts
      let prunedTree = pruneUnchangedParts(before: before, after: after)
      if let pruned = prunedTree {
        changedSubtrees.append(pruned)
      }
    }
    
    return (modifications, changedSubtrees)
  }
  
  /// Check if a subtree has any changes recursively
  private func hasChangesInSubtree(before: UIElement, after: UIElement) -> Bool {
    // Different elements means change
    if before != after {
      return true
    }
    
    // Check children - if counts differ, there's a change
    if before.children.count != after.children.count {
      return true
    }
    
    // Check each child recursively
    for (beforeChild, afterChild) in zip(before.children, after.children) {
      if hasChangesInSubtree(before: beforeChild, after: afterChild) {
        return true
      }
    }
    
    return false
  }
  
  /// Prune unchanged parts from a tree, keeping only changed subtrees
  private func pruneUnchangedParts(before: UIElement, after: UIElement) -> UIElement? {
    var keptChildren: [UIElement] = []
    
    // Process children
    let minChildCount = min(before.children.count, after.children.count)
    
    // Check existing children
    for i in 0..<minChildCount {
      let beforeChild = before.children[i]
      let afterChild = after.children[i]
      
      if hasChangesInSubtree(before: beforeChild, after: afterChild) {
        if let prunedChild = pruneUnchangedParts(before: beforeChild, after: afterChild) {
          keptChildren.append(prunedChild)
        }
      }
    }
    
    // Add any completely new children
    if after.children.count > before.children.count {
      keptChildren.append(contentsOf: after.children[minChildCount...])
    }
    
    // If this element changed OR has changed children, keep it
    if before != after || !keptChildren.isEmpty {
      // Create pruned version with only kept children
      let prunedElement = UIElement(
        path: after.path,
        role: after.role,
        title: after.title,
        value: after.value,
        elementDescription: after.elementDescription,
        identifier: after.identifier,
        frame: after.frame,
        normalizedFrame: after.normalizedFrame,
        viewportFrame: after.viewportFrame,
        frameSource: after.frameSource,
        parent: after.parent,
        children: keptChildren,
        attributes: after.attributes,
        actions: after.actions,
        axElement: after.axElement
      )
      
      // Set parent relationships
      for child in keptChildren {
        child.parent = prunedElement
      }
      
      return prunedElement
    }
    
    return nil
  }
}
