#!/usr/bin/env swift

// ABOUTME: Diagnostic script to find elements with duplicate IDs in Calculator menus
// ABOUTME: Helps identify differences between elements with the same ID

import Foundation
import Cocoa

// MARK: - Utility Functions
func checkAccessibilityPermission() -> Bool {
    let checkOptPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptPrompt: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func getElement(pid: pid_t) -> AXUIElement {
    return AXUIElementCreateApplication(pid)
}

func getElementAttribute(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    if error != .success {
        //print("Error getting attribute \(attribute): \(error.rawValue)")
        return nil
    }
    return value
}

func getAttributeNames(_ element: AXUIElement) -> [String]? {
    var names: CFArray?
    let error = AXUIElementCopyAttributeNames(element, &names)
    if error != .success {
        return nil
    }
    return names as? [String]
}

func getActionNames(_ element: AXUIElement) -> [String]? {
    var names: CFArray?
    let error = AXUIElementCopyActionNames(element, &names)
    if error != .success {
        return nil
    }
    return names as? [String]
}

func getTitle(_ element: AXUIElement) -> String? {
    if let value = getElementAttribute(element, attribute: kAXTitleAttribute as String) {
        return value as? String
    }
    return nil
}

func getChildren(_ element: AXUIElement) -> [AXUIElement]? {
    if let value = getElementAttribute(element, attribute: kAXChildrenAttribute as String) {
        return value as? [AXUIElement]
    }
    return nil
}

func getRole(_ element: AXUIElement) -> String? {
    if let value = getElementAttribute(element, attribute: kAXRoleAttribute as String) {
        return value as? String
    }
    return nil
}

func getDescription(_ element: AXUIElement) -> String? {
    if let value = getElementAttribute(element, attribute: kAXDescriptionAttribute as String) {
        return value as? String
    }
    return nil
}

func getEnabled(_ element: AXUIElement) -> Bool? {
    if let value = getElementAttribute(element, attribute: kAXEnabledAttribute as String) {
        return value as? Bool
    }
    return nil
}

func getIdentifier(_ element: AXUIElement) -> String? {
    if let value = getElementAttribute(element, attribute: kAXIdentifierAttribute as String) {
        return value as? String
    }
    return nil
}

func getPosition(_ element: AXUIElement) -> CGPoint? {
    if let value = getElementAttribute(element, attribute: kAXPositionAttribute as String),
       CFGetTypeID(value) == AXValueGetTypeID() {
        var point = CGPoint.zero
        if AXValueGetValue(value as! AXValue, .cgPoint, &point) {
            return point
        }
    }
    return nil
}

func getSize(_ element: AXUIElement) -> CGSize? {
    if let value = getElementAttribute(element, attribute: kAXSizeAttribute as String),
       CFGetTypeID(value) == AXValueGetTypeID() {
        var size = CGSize.zero
        if AXValueGetValue(value as! AXValue, .cgSize, &size) {
            return size
        }
    }
    return nil
}

func performPress(_ element: AXUIElement) -> Bool {
    let error = AXUIElementPerformAction(element, kAXPressAction as CFString)
    if error != .success {
        print("Error performing press: \(error.rawValue)")
        return false
    }
    return true
}

// MARK: - Main Functionality
// Get Calculator PID
func getCalculatorPID() -> pid_t? {
    let apps = NSWorkspace.shared.runningApplications
    if let calculator = apps.first(where: { $0.bundleIdentifier == "com.apple.calculator" }) {
        return calculator.processIdentifier
    }
    return nil
}

// Launch Calculator if it's not running
func launchCalculator() -> pid_t? {
    if let pid = getCalculatorPID() {
        print("Calculator is already running with PID \(pid)")
        return pid
    }
    
    print("Launching Calculator...")
    let configuration = NSWorkspace.OpenConfiguration()
    
    var pid: pid_t? = nil
    let semaphore = DispatchSemaphore(value: 0)
    
    NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: "/Applications/Calculator.app"),
        configuration: configuration
    ) { app, error in
        if let error = error {
            print("Error launching Calculator: \(error)")
        } else if let app = app {
            pid = app.processIdentifier
            print("Successfully launched Calculator with PID \(pid!)")
        }
        semaphore.signal()
    }
    
    _ = semaphore.wait(timeout: .now() + 5)
    return pid
}

func dumpElement(_ element: AXUIElement, indent: String = "") {
    print("\(indent)Role: \(getRole(element) ?? "nil")")
    print("\(indent)Title: \(getTitle(element) ?? "nil")")
    print("\(indent)Description: \(getDescription(element) ?? "nil")")
    print("\(indent)Identifier: \(getIdentifier(element) ?? "nil")")
    print("\(indent)Enabled: \(getEnabled(element) ?? false)")
    
    if let position = getPosition(element) {
        print("\(indent)Position: (\(position.x), \(position.y))")
    } else {
        print("\(indent)Position: nil")
    }
    
    if let size = getSize(element) {
        print("\(indent)Size: (\(size.width), \(size.height))")
    } else {
        print("\(indent)Size: nil")
    }
    
    // Dump all attributes
    print("\(indent)All Attributes:")
    if let attrNames = getAttributeNames(element) {
        for name in attrNames.sorted() {
            if let value = getElementAttribute(element, attribute: name) {
                var valueDescription = "nil"
                
                if CFGetTypeID(value) == AXValueGetTypeID() {
                    let type = AXValueGetType(value as! AXValue)
                    switch type {
                    case .cgPoint:
                        var point = CGPoint.zero
                        if AXValueGetValue(value as! AXValue, .cgPoint, &point) {
                            valueDescription = "CGPoint(\(point.x), \(point.y))"
                        }
                    case .cgSize:
                        var size = CGSize.zero
                        if AXValueGetValue(value as! AXValue, .cgSize, &size) {
                            valueDescription = "CGSize(\(size.width), \(size.height))"
                        }
                    case .cgRect:
                        var rect = CGRect.zero
                        if AXValueGetValue(value as! AXValue, .cgRect, &rect) {
                            valueDescription = "CGRect(x: \(rect.origin.x), y: \(rect.origin.y), w: \(rect.size.width), h: \(rect.size.height))"
                        }
                    case .cfRange:
                        var range = CFRange(location: 0, length: 0)
                        if AXValueGetValue(value as! AXValue, .cfRange, &range) {
                            valueDescription = "CFRange(location: \(range.location), length: \(range.length))"
                        }
                    default:
                        valueDescription = "<AXValue>"
                    }
                } else if let stringValue = value as? String {
                    valueDescription = "\"\(stringValue)\""
                } else if let boolValue = value as? Bool {
                    valueDescription = boolValue ? "true" : "false"
                } else if let numberValue = value as? NSNumber {
                    valueDescription = "\(numberValue)"
                } else if CFGetTypeID(value) == AXUIElementGetTypeID() {
                    valueDescription = "<AXUIElement>"
                } else if let arrayValue = value as? [AnyObject] {
                    if arrayValue.isEmpty {
                        valueDescription = "[]"
                    } else if CFGetTypeID(arrayValue[0]) == AXUIElementGetTypeID() {
                        valueDescription = "[\(arrayValue.count) AXUIElements]"
                    } else {
                        valueDescription = "[\(arrayValue.count) items]"
                    }
                } else {
                    valueDescription = "<\(CFGetTypeID(value))>"
                }
                
                print("\(indent)  \(name): \(valueDescription)")
            }
        }
    }
    
    // Dump available actions
    print("\(indent)Actions:")
    if let actionNames = getActionNames(element) {
        for action in actionNames {
            print("\(indent)  \(action)")
        }
    } else {
        print("\(indent)  None")
    }
}

// Find all elements with a specific ID
func findElementsWithID(_ element: AXUIElement, id: String, results: inout [AXUIElement], depth: Int = 0, maxDepth: Int = 25) {
    if depth > maxDepth {
        return
    }
    
    if let elementID = getIdentifier(element), elementID == id {
        results.append(element)
    }
    
    if let children = getChildren(element) {
        for child in children {
            findElementsWithID(child, id: id, results: &results, depth: depth + 1, maxDepth: maxDepth)
        }
    }
}

// Examine menu items
func examineMenuItems(_ appElement: AXUIElement) {
    print("\n----- Examining Calculator Menu Items -----")
    
    // Find the menu bar
    guard let children = getChildren(appElement),
          let menuBar = children.first(where: { getRole($0) == "AXMenuBar" }),
          let menuBarItems = getChildren(menuBar) else {
        print("Could not find menu bar")
        return
    }
    
    // Find the View menu
    guard let viewMenu = menuBarItems.first(where: { getTitle($0) == "View" }) else {
        print("Could not find View menu")
        return
    }
    
    print("View menu found with title: \(getTitle(viewMenu) ?? "nil")")
    
    // Activate the View menu to see its items
    print("Activating View menu...")
    if performPress(viewMenu) {
        print("View menu pressed")
        
        // Wait for menu to open
        usleep(500_000)
        
        // Log all menu items first
        print("\nLogging all menu items in the View menu:")
        if let menuChildren = getChildren(viewMenu) {
            for (i, child) in menuChildren.enumerated() {
                print("\nChild \(i) of View menu:")
                print("  Role: \(getRole(child) ?? "nil")")
                print("  Title: \(getTitle(child) ?? "nil")")
                print("  Description: \(getDescription(child) ?? "nil")")
                print("  Identifier: \(getIdentifier(child) ?? "nil")")

                // If this is the AXMenu, examine its children
                if getRole(child) == "AXMenu", let menuItems = getChildren(child) {
                    print("\n  Found AXMenu with \(menuItems.count) items:")

                    for (j, menuItem) in menuItems.enumerated() {
                        print("\n    Menu Item \(j):")
                        print("      Role: \(getRole(menuItem) ?? "nil")")
                        print("      Title: \(getTitle(menuItem) ?? "nil")")
                        print("      Description: \(getDescription(menuItem) ?? "nil")")
                        print("      Identifier: \(getIdentifier(menuItem) ?? "nil")")
                        print("      Enabled: \(getEnabled(menuItem) ?? false)")
                    }
                }
            }
        }

        // Search the entire application for elements with the problematic ID
        var elementsWithID: [AXUIElement] = []
        let targetID = "ui:menuAction::3fb7ecf54ec332b1" // The problematic ID from the test failure

        findElementsWithID(appElement, id: targetID, results: &elementsWithID)

        print("\nFound \(elementsWithID.count) elements with ID: \(targetID)")

        // If we don't find elements with the expected ID, let's try to find all menu items
        if elementsWithID.isEmpty {
            print("\nNo elements found with target ID. Looking for all AXMenuItem elements:")

            var menuItems: [AXUIElement] = []
            func findAllMenuItems(_ element: AXUIElement, results: inout [AXUIElement], depth: Int = 0, maxDepth: Int = 25) {
                if depth > maxDepth {
                    return
                }

                if getRole(element) == "AXMenuItem" {
                    results.append(element)
                }

                if let children = getChildren(element) {
                    for child in children {
                        findAllMenuItems(child, results: &results, depth: depth + 1, maxDepth: maxDepth)
                    }
                }
            }

            findAllMenuItems(appElement, results: &menuItems)
            print("Found \(menuItems.count) menu items in total")

            // Examine the first few menu items we found
            let itemsToExamine = min(menuItems.count, 5)

            for i in 0..<itemsToExamine {
                let element = menuItems[i]
                print("\n=== Menu Item \(i+1) ===")
                dumpElement(element)

                // Try to find any parent-child relationships
                print("\nParent information:")
                if let parentRef = getElementAttribute(element, attribute: kAXParentAttribute as String),
                   CFGetTypeID(parentRef) == AXUIElementGetTypeID() {
                    let parent = parentRef as! AXUIElement
                    print("  Parent Role: \(getRole(parent) ?? "nil")")
                    print("  Parent Title: \(getTitle(parent) ?? "nil")")
                    print("  Parent ID: \(getIdentifier(parent) ?? "nil")")
                } else {
                    print("  No parent information available")
                }
            }
        }

        // Dump detailed information about each matching element with the target ID
        for (i, element) in elementsWithID.enumerated() {
            print("\n=== Element \(i+1) with ID \(targetID) ===")
            dumpElement(element)

            // Try to find any parent-child relationships
            print("\nParent information:")
            if let parentRef = getElementAttribute(element, attribute: kAXParentAttribute as String),
               CFGetTypeID(parentRef) == AXUIElementGetTypeID() {
                let parent = parentRef as! AXUIElement
                print("  Parent Role: \(getRole(parent) ?? "nil")")
                print("  Parent Title: \(getTitle(parent) ?? "nil")")
                print("  Parent ID: \(getIdentifier(parent) ?? "nil")")
            } else {
                print("  No parent information available")
            }

            // Try to click this element to see what happens
            print("\nTrying to perform press action on this element:")
            let success = performPress(element)
            print("  Press action result: \(success ? "SUCCESS" : "FAILED")")

            // Wait a bit before trying the next element
            usleep(500_000)
        }
        
        // Click somewhere else to close the menu
        let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 100, height: 100)
        let randomPoint = CGPoint(x: screenBounds.width - 50, y: screenBounds.height - 50)
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, 
                                mouseCursorPosition: randomPoint, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, 
                             mouseCursorPosition: randomPoint, mouseButton: .left)
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - Main Execution
print("Starting Calculator menu diagnostic")

guard checkAccessibilityPermission() else {
    print("ERROR: Accessibility permission not granted!")
    print("Please enable in System Settings > Privacy & Security > Accessibility")
    exit(1)
}

guard let pid = launchCalculator() else {
    print("ERROR: Failed to get Calculator PID")
    exit(1)
}

let appElement = getElement(pid: pid)
print("Got application element")

// Ensure Calculator is frontmost
if let app = NSRunningApplication(processIdentifier: pid) {
    app.activate() // Use simple activate without deprecated option
    usleep(1_000_000) // Wait for activation
}

// Examine menu items to find duplicates
examineMenuItems(appElement)

print("\nDiagnostic complete")
exit(0)