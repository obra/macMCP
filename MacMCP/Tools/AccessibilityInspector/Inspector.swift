// ABOUTME: Core functionality for inspecting accessibility trees in macOS applications
// ABOUTME: Handles application access, element traversal, and attribute retrieval

import Foundation
import Logging
import Cocoa
import ApplicationServices

// Configure a logger for the inspector
private let inspectorLogger = Logger(label: "com.anthropic.mac-mcp.inspector")

/// Represents a UI element with all its accessibility properties
class UIElementNode {
    let element: AXUIElement
    let role: String
    let role_description: String?
    let subrole: String?
    let title: String?
    let identifier: String?
    let frame: NSRect?
    let description: String?
    let help: String?
    let value: Any?
    let valueDescription: String?
    let focused: Bool
    let selected: Bool
    let expanded: Bool?
    let required: Bool?
    let placeholder: String?
    let label: String?
    let childrenCount: Int
    let hasParent: Bool
    let hasWindow: Bool
    let hasTopLevelUIElement: Bool
    let attributes: [String: Any]
    let parameterizedAttributes: [String]
    let actions: [String]
    var children: [UIElementNode]
    let index: Int
    let isEnabled: Bool
    let isClickable: Bool
    let isVisible: Bool
    
    init(element: AXUIElement, index: Int) {
        self.element = element
        self.index = index
        
        // Get basic properties
        self.role = UIElementNode.getAttribute(element, attribute: kAXRoleAttribute) as? String ?? "Unknown"
        self.role_description = UIElementNode.getAttribute(element, attribute: kAXRoleDescriptionAttribute) as? String
        self.subrole = UIElementNode.getAttribute(element, attribute: kAXSubroleAttribute) as? String
        self.title = UIElementNode.getAttribute(element, attribute: kAXTitleAttribute) as? String
        self.identifier = UIElementNode.getAttribute(element, attribute: kAXIdentifierAttribute) as? String
        
        // Get position and size
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if let positionValue = UIElementNode.getAttribute(element, attribute: kAXPositionAttribute) as? AnyObject {
            AXValueGetValue(positionValue as! AXValue, AXValueType.cgPoint, &position)
        }
        
        if let sizeValue = UIElementNode.getAttribute(element, attribute: kAXSizeAttribute) as? AnyObject {
            AXValueGetValue(sizeValue as! AXValue, AXValueType.cgSize, &size)
        }
        
        self.frame = NSRect(origin: position, size: size)
        
        // Additional text properties
        self.description = UIElementNode.getAttribute(element, attribute: kAXDescriptionAttribute) as? String
        self.help = UIElementNode.getAttribute(element, attribute: kAXHelpAttribute) as? String
        self.value = UIElementNode.getAttribute(element, attribute: kAXValueAttribute)
        self.valueDescription = UIElementNode.getAttribute(element, attribute: kAXValueDescriptionAttribute) as? String
        self.placeholder = UIElementNode.getAttribute(element, attribute: kAXPlaceholderValueAttribute) as? String
        self.label = UIElementNode.getAttribute(element, attribute: kAXLabelValueAttribute) as? String
        
        // State properties
        self.focused = UIElementNode.getAttribute(element, attribute: kAXFocusedAttribute) as? Bool ?? false
        self.selected = UIElementNode.getAttribute(element, attribute: kAXSelectedAttribute) as? Bool ?? false
        self.expanded = UIElementNode.getAttribute(element, attribute: kAXExpandedAttribute) as? Bool
        self.required = UIElementNode.getAttribute(element, attribute: "AXRequired") as? Bool
        
        // Relationship properties
        self.hasParent = UIElementNode.getAttribute(element, attribute: kAXParentAttribute) != nil
        self.hasWindow = UIElementNode.getAttribute(element, attribute: kAXWindowAttribute) != nil
        self.hasTopLevelUIElement = UIElementNode.getAttribute(element, attribute: kAXTopLevelUIElementAttribute) != nil
        
        // Get all attributes
        var attributeNamesRef: CFArray?
        AXUIElementCopyAttributeNames(element, &attributeNamesRef)
        
        var attributeDict = [String: Any]()
        if let attributeNames = attributeNamesRef as? [String] {
            for attr in attributeNames {
                if let value = UIElementNode.getAttribute(element, attribute: attr) {
                    attributeDict[attr] = value
                }
            }
        }
        self.attributes = attributeDict
        
        // Get parameterized attributes
        var paramAttrNamesRef: CFArray?
        AXUIElementCopyParameterizedAttributeNames(element, &paramAttrNamesRef)
        self.parameterizedAttributes = (paramAttrNamesRef as? [String]) ?? []
        
        // Get all actions
        var actionNamesRef: CFArray?
        AXUIElementCopyActionNames(element, &actionNamesRef)
        self.actions = (actionNamesRef as? [String]) ?? []
        
        // Set computed properties
        self.isEnabled = UIElementNode.getAttribute(element, attribute: kAXEnabledAttribute) as? Bool ?? false
        
        // Determine if element is clickable based on role and actions
        let clickableRoles = ["AXButton", "AXCheckBox", "AXRadioButton", "AXMenuItem", "AXMenuButton", "AXPopUpButton"]
        self.isClickable = clickableRoles.contains(self.role) || self.actions.contains(kAXPressAction)
        
        // Determine if element is visible (if it has a non-zero size or doesn't have a size attribute but is still meaningful)
        let hasSize = self.frame != nil && (self.frame!.size.width > 0 || self.frame!.size.height > 0)
        let isHidden = UIElementNode.getAttribute(element, attribute: "AXHidden") as? Bool ?? false
        self.isVisible = hasSize && !isHidden
        
        // Initialize children as empty (will be populated by inspector)
        self.children = []
        
        // Get children count
        if let childrenArray = UIElementNode.getAttribute(element, attribute: kAXChildrenAttribute) as? [AXUIElement] {
            self.childrenCount = childrenArray.count
        } else {
            self.childrenCount = 0
        }
    }
    
    /// Safely gets an attribute value from an accessibility element
    static func getAttribute(_ element: AXUIElement, attribute: String) -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        
        if result == .success, let value = value {
            return value
        }
        return nil
    }
}

/// The main inspector class responsible for accessibility tree traversal
class Inspector {
    private let appId: String?
    private let pid: Int?
    private let maxDepth: Int
    private var elementIndex = 0
    
    init(appId: String?, pid: Int?, maxDepth: Int) {
        self.appId = appId
        self.pid = pid
        self.maxDepth = maxDepth
    }
    
    /// Inspects the application and returns the root UI element node
    func inspectApplication() throws -> UIElementNode {
        inspectorLogger.info("Inspecting application", metadata: ["appId": .string(appId ?? ""), "pid": .stringConvertible(pid ?? 0)])
        
        // Find the application
        guard let app = try findApplication() else {
            throw InspectionError.applicationNotFound
        }
        
        // Verify accessibility permissions
        if !checkAccessibilityPermissions() {
            throw InspectionError.accessibilityPermissionDenied
        }
        
        // Get the AXUIElement for the application
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Reset element counter
        elementIndex = 0
        
        // Create the root node
        let rootNode = UIElementNode(element: appElement, index: elementIndex)
        elementIndex += 1
        
        // Traverse the accessibility hierarchy
        try populateChildren(for: rootNode, depth: 0)
        
        return rootNode
    }
    
    /// Recursively populates children for a node
    private func populateChildren(for node: UIElementNode, depth: Int) throws {
        // Stop if we've reached the maximum depth
        if depth >= maxDepth {
            inspectorLogger.warning("Reached maximum depth (\(maxDepth))")
            return
        }
        
        // Get the children
        var childrenRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(node.element, kAXChildrenAttribute as CFString, &childrenRef)
        
        if result != AXError.success {
            if result == AXError.noValue || result == AXError.attributeUnsupported {
                // No children
                return
            } else {
                throw InspectionError.unexpectedError("Failed to get children: \(result)")
            }
        }
        
        // Process children
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                let childNode = UIElementNode(element: child, index: elementIndex)
                elementIndex += 1
                node.children.append(childNode)
                
                // Recursively populate grandchildren
                try populateChildren(for: childNode, depth: depth + 1)
            }
        }
    }
    
    /// Finds the application by bundle ID or process ID
    private func findApplication() throws -> NSRunningApplication? {
        if let bundleId = appId {
            let apps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleId }
            if apps.isEmpty {
                inspectorLogger.error("No running application found with bundle ID: \(bundleId)")
                return nil
            }
            return apps.first
        } else if let processId = pid {
            return NSRunningApplication(processIdentifier: pid_t(processId))
        }
        return nil
    }
    
    /// Checks if the application has accessibility permissions
    private func checkAccessibilityPermissions() -> Bool {
        // Use the options dictionary to avoid prompting the user
        // Since we can't directly access kAXTrustedCheckOptionPrompt safely due to concurrency issues,
        // we'll just check if the process is trusted without prompting
        return AXIsProcessTrusted()
    }
}