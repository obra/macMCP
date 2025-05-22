// ABOUTME: ToolChain.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import Logging
import MCP

@testable import MacMCP

/// Accessibility permission status enum for mocks
public enum AccessibilityPermissionStatus: String, Codable {
  case authorized
  case denied
  case unknown
}

/// Mock of AccessibilityServiceProtocol for testing
public class MockAccessibilityService: @unchecked Sendable, AccessibilityServiceProtocol {
  // MARK: - Protocol Required Methods

  public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
    // Just execute the operation - we'll handle special cases elsewhere
    return try await operation()
  }

  public func findElementByPath(path: String) async throws -> UIElement? {
    // Special case for the path used in the testElementScope test
    if path == "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow" {
      // Create a window element with child elements specifically for this test
      let windowElement = createMockUIElement(
        role: "AXWindow", 
        title: "Calculator",
        customPath: path
      )
      
      // Create a display element
      let displayElement = createMockUIElement(
        role: "AXStaticText", 
        title: "Calculator Display",
        value: "0",
        customPath: path + "/AXGroup/AXStaticText[@AXTitle=\"Calculator Display\"]"
      )
      
      // Create buttons
      let button1 = createMockUIElement(
        role: "AXButton", 
        title: "One",
        elementDescription: "1",
        customPath: path + "/AXGroup/AXButton[@AXDescription=\"1\"]",
        attributes: ["visible": true, "enabled": true]
      )
      
      let button2 = createMockUIElement(
        role: "AXButton", 
        title: "Two",
        elementDescription: "2",
        customPath: path + "/AXGroup/AXButton[@AXDescription=\"2\"]",
        attributes: ["visible": true, "enabled": true]
      )
      
      // Create a window with children
      return UIElement(
        path: windowElement.path,
        role: windowElement.role,
        title: windowElement.title,
        value: windowElement.value,
        elementDescription: windowElement.elementDescription,
        frame: windowElement.frame,
        frameSource: windowElement.frameSource,
        children: [displayElement, button1, button2],
        attributes: windowElement.attributes,
        actions: windowElement.actions
      )
    }
    
    // Handle other Calculator app paths
    if path.contains("Calculator") {
      // Handle specific paths for Calculator elements
      if path.contains("AXButton") {
        // Extract button description if available
        var description = ""
        if let descStart = path.range(of: "AXDescription=\""),
           let descEnd = path.range(of: "\"", range: descStart.upperBound..<path.endIndex)
        {
          let startIndex = path.index(descStart.upperBound, offsetBy: 0)
          description = String(path[startIndex..<descEnd.lowerBound])
        }
        
        // Create a button element with the specified description
        return createMockUIElement(
          role: "AXButton", 
          title: "Button \(description)", 
          elementDescription: description,
          customPath: path,
          attributes: ["visible": true, "enabled": true]
        )
      } else if path.contains("AXWindow") {
        // Create a window element
        return createMockUIElement(
          role: "AXWindow", 
          title: "Calculator",
          customPath: path
        )
      } else if path.contains("AXStaticText") {
        // Create a text element (like the display)
        return createMockUIElement(
          role: "AXStaticText", 
          title: "Calculator Display",
          value: "0",
          customPath: path
        )
      } else if path.contains("AXApplication") {
        // For application paths, create an application element with a window child
        let appElement = createMockUIElement(
          role: "AXApplication", 
          title: "Calculator",
          customPath: path
        )
        
        // Create a window child
        let windowElement = createMockUIElement(
          role: "AXWindow", 
          title: "Calculator",
          customPath: path + "/AXWindow[@AXTitle=\"Calculator\"]"
        )
        
        // Return app with window child
        return UIElement(
          path: appElement.path,
          role: appElement.role,
          title: appElement.title,
          value: appElement.value,
          elementDescription: appElement.elementDescription,
          frame: appElement.frame,
          frameSource: appElement.frameSource,
          children: [windowElement],
          attributes: appElement.attributes,
          actions: appElement.actions
        )
      }
    }
    
    // Default fallback for other paths
    let parts = path.split(separator: "/")
    if let lastPart = parts.last {
      let role = String(lastPart.split(separator: "[").first ?? "AXUnknown")
      return createMockUIElement(role: role, title: "Path Element")
    }
    return nil
  }

  public func performAction(action _: String, onElementWithPath _: String) async throws {
    // Mock implementation - do nothing
  }

  public func getSystemUIElement(recursive _: Bool, maxDepth _: Int) async throws -> UIElement {
    createMockUIElement(role: "AXApplication", title: "System")
  }

  public func getApplicationUIElement(
    bundleId: String,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> UIElement {
    if bundleId == "com.apple.calculator" {
      // Create a proper Calculator app hierarchy
      let calculatorApp = createMockUIElement(
        role: "AXApplication", 
        title: "Calculator"
      )
      
      // Create a window element as a child
      let calculatorWindow = createMockUIElement(
        role: "AXWindow", 
        title: "Calculator",
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
      )
      
      // Create display element
      let displayElement = createMockUIElement(
        role: "AXStaticText", 
        title: "Calculator Display",
        value: "0",
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXStaticText[@AXTitle=\"Calculator Display\"]"
      )
      
      // Create a few buttons for tests
      let buttonElements: [UIElement] = [
        createMockUIElement(
          role: "AXButton", 
          title: "One",
          elementDescription: "1",
          customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXButton[@AXDescription=\"1\"]",
          attributes: ["visible": true, "enabled": true]
        ),
        createMockUIElement(
          role: "AXButton", 
          title: "Two",
          elementDescription: "2",
          customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXButton[@AXDescription=\"2\"]",
          attributes: ["visible": true, "enabled": true]
        )
      ]
      
      // Add children to calculatorApp
      var appAttributes = calculatorApp.attributes
      appAttributes["children"] = [calculatorWindow]
      
      // Add children to the window
      var windowChildren: [UIElement] = [displayElement]
      windowChildren.append(contentsOf: buttonElements)
      
      // Create a window element with children
      let windowWithChildren = UIElement(
        path: calculatorWindow.path,
        role: calculatorWindow.role,
        title: calculatorWindow.title,
        value: calculatorWindow.value,
        elementDescription: calculatorWindow.elementDescription,
        frame: calculatorWindow.frame,
        frameSource: calculatorWindow.frameSource,
        children: windowChildren,
        attributes: calculatorWindow.attributes,
        actions: calculatorWindow.actions
      )
      
      // Return the app with its hierarchy
      return UIElement(
        path: calculatorApp.path,
        role: calculatorApp.role,
        title: calculatorApp.title,
        value: calculatorApp.value,
        elementDescription: calculatorApp.elementDescription,
        frame: calculatorApp.frame,
        frameSource: calculatorApp.frameSource,
        children: [windowWithChildren],
        attributes: appAttributes,
        actions: calculatorApp.actions
      )
    } else {
      // Default for non-Calculator apps
      return createMockUIElement(role: "AXApplication", title: bundleId)
    }
  }

  public func getFocusedApplicationUIElement(recursive _: Bool, maxDepth _: Int) async throws
    -> UIElement
  {
    createMockUIElement(role: "AXApplication", title: "Focused App")
  }

  public func getUIElementAtPosition(
    position _: CGPoint,
    recursive _: Bool,
    maxDepth _: Int,
  ) async throws -> UIElement? {
    // Create a Calculator button element that would be at a position
    return createMockUIElement(
      role: "AXButton", 
      title: "Element at Position",
      elementDescription: "5", // Arbitrary button description for Calculator
      customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXButton[@AXDescription=\"5\"]",
      attributes: ["visible": true, "enabled": true]
    )
  }

  public func findUIElements(
    role: String?,
    title: String?,
    titleContains: String?,
    value: String?,
    valueContains: String?,
    description: String?,
    descriptionContains: String?,
    scope: UIElementScope,
    recursive: Bool,
    maxDepth: Int,
  ) async throws -> [UIElement] {
    // Create mock UI elements based on request parameters
    var elements: [UIElement] = []
    
    // Support for Calculator mock elements
    if case .application(let bundleId) = scope, bundleId == "com.apple.calculator" {
      // Create a mock Calculator application element
      let calculatorApp = createMockUIElement(role: "AXApplication", title: "Calculator")
      
      // Create a mock Calculator window
      let calculatorWindow = createMockUIElement(
        role: "AXWindow", 
        title: "Calculator",
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]"
      )
      
      // Create numeric button elements for Calculator
      var buttonElements = createMockCalculatorButtons()
      
      // Create some buttons with enhanced capabilities for the specific tests
      let buttonWithCapabilities = createMockUIElement(
        role: "AXButton", 
        title: "One With Capabilities",
        elementDescription: "1",
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXButton[@AXDescription=\"1\"]",
        attributes: [
          "visible": true, 
          "enabled": true,
          "capabilities": ["clickable", "pressable"]
        ]
      )
      
      // Replace the standard buttons with our enhanced ones for these tests
      buttonElements = [buttonWithCapabilities] + buttonElements
      
      // Create a mock display element
      let displayElement = createMockUIElement(
        role: "AXStaticText", 
        title: "Calculator Display",
        value: "0",
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXStaticText[@AXTitle=\"Calculator Display\"]"
      )
      
      // Filter based on role if specified
      if let targetRole = role {
        switch targetRole {
        case "AXButton":
          elements = buttonElements
        case "AXStaticText":
          elements = [displayElement]
        case "AXWindow":
          elements = [calculatorWindow]
        case "AXApplication":
          elements = [calculatorApp]
        default:
          elements = [calculatorApp, calculatorWindow, displayElement] + buttonElements
        }
      } else {
        // If no role specified, return all elements
        elements = [calculatorApp, calculatorWindow, displayElement] + buttonElements
      }
      
      // Apply additional filters
      if let btnDescription = description {
        elements = elements.filter { element in
          element.elementDescription == btnDescription
        }
      }
      
      if let descriptionSubstring = descriptionContains {
        elements = elements.filter { element in
          element.elementDescription?.contains(descriptionSubstring) ?? false
        }
      }
      
      if let titleValue = title {
        elements = elements.filter { element in
          element.title == titleValue
        }
      }
      
      if let titleSubstring = titleContains {
        elements = elements.filter { element in
          element.title?.contains(titleSubstring) ?? false
        }
      }
    } else {
      // Return default system element for non-Calculator scope
      elements = [createMockUIElement(role: "AXApplication", title: "System")]
    }
    
    return elements
  }
  
  // Helper function to create mock Calculator buttons
  private func createMockCalculatorButtons() -> [UIElement] {
    let buttonData = [
      ("0", "Zero"),
      ("1", "One"),
      ("2", "Two"),
      ("3", "Three"),
      ("4", "Four"),
      ("5", "Five"),
      ("6", "Six"),
      ("7", "Seven"),
      ("8", "Eight"),
      ("9", "Nine"),
      ("+", "Plus"),
      ("-", "Minus"),
      ("×", "Multiply"),
      ("÷", "Divide"),
      ("=", "Equals"),
      (".", "Decimal"),
      ("%", "Percent"),
      ("±", "Sign"),
      ("C", "Clear"),
      ("AC", "All Clear"),
    ]
    
    return buttonData.map { (description, title) in
      createMockUIElement(
        role: "AXButton", 
        title: title,
        elementDescription: description,
        customPath: "macos://ui/AXApplication[@AXTitle=\"Calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXButton[@AXDescription=\"\(description)\"]",
        attributes: ["visible": true, "enabled": true]
      )
    }
  }

  // Legacy element identifier methods have been removed

  // Legacy element identifier methods have been removed

  public func moveWindow(withPath _: String, to _: CGPoint) async throws {
    // Do nothing in mock
  }

  public func resizeWindow(withPath _: String, to _: CGSize) async throws {
    // Do nothing in mock
  }

  public func minimizeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func maximizeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func closeWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func activateWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func setWindowOrder(
    withPath _: String,
    orderMode _: WindowOrderMode,
    referenceWindowPath _: String?,
  ) async throws {
    // Do nothing in mock
  }

  public func focusWindow(withPath _: String) async throws {
    // Do nothing in mock
  }

  public func navigateMenu(elementPath _: String, in _: String) async throws {
    // Do nothing in mock
  }

  // MARK: - Additional Methods

  public func getApplicationUIElement(
    bundleId _: String,
    launch _: Bool,
    recursive _: Bool,
  ) async throws -> UIElement? {
    // Return nil for simplified mock
    nil
  }

  // Legacy element identifier methods have been removed

  public func getUIElementFrame(_: AccessibilityElement) -> CGRect {
    .zero
  }

  public func performAction(_: AccessibilityElement, action _: String) async throws -> Bool {
    true
  }

  public func setAttribute(_: AccessibilityElement, name _: String, value _: Any) async throws
    -> Bool
  {
    true
  }

  public func getValue(_: AccessibilityElement, attribute _: String) -> Any? {
    nil
  }

  public func getWindowList(bundleId _: String) async throws -> [UIElement] {
    []
  }

  public func getMenuItemsForMenu(menuElement _: String, bundleId _: String) async throws
    -> [UIElement]
  {
    []
  }

  public func getApplicationMenus(bundleId _: String) async throws -> [UIElement] {
    []
  }

  public func activateMenuItem(menuPath _: String, bundleId _: String) async throws -> Bool {
    true
  }

  public func getAccessibilityPermissionStatus() async -> AccessibilityPermissionStatus {
    .authorized
  }

  // MARK: - Helper Methods

  private func createMockUIElement(
    role: String, 
    title: String? = nil, 
    value: String? = nil,
    elementDescription: String? = nil,
    customPath: String? = nil,
    attributes: [String: Any] = ["enabled": true, "visible": true]
  ) -> UIElement {
    var path: String
    
    if let customPath {
      // Use the provided custom path
      path = customPath
    } else {
      // Construct a path based on available properties
      path = "macos://ui/AXApplication[@AXRole=\"AXApplication\"]/"
      path += role
      
      // Add title if available
      if let title, !title.isEmpty {
        path += "[@AXTitle=\"\(title)\"]"
      }
      
      // Add description if available
      if let elementDescription, !elementDescription.isEmpty {
        path += "[@AXDescription=\"\(elementDescription)\"]"
      }
    }
    
    return UIElement(
      path: path,
      role: role,
      title: title,
      value: value,
      elementDescription: elementDescription,
      frame: CGRect(x: 0, y: 0, width: 100, height: 100),
      frameSource: .direct,
      attributes: attributes,
      actions: ["AXPress"],
    )
  }
}

/// Simplified ToolChain for unit tests with mocks
public final class ToolChain: @unchecked Sendable {
  /// Logger for the tool chain
  public let logger: Logger

  /// Mock AccessibilityService
  public let accessibilityService: MockAccessibilityService

  /// Initialize with a logger
  public init(logLabel: String = "mcp.toolchain.mock") {
    logger = Logger(label: logLabel)
    accessibilityService = MockAccessibilityService()
  }
}
