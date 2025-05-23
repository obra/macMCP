// ABOUTME: CalculatorModel.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import MCP

@testable import MacMCP

/// Model for the macOS Calculator application
public final class CalculatorModel: BaseApplicationModel, @unchecked Sendable {
  /// Main window ID for the Calculator - can be set during tests
  public var windowId: String?
  /// Button identifiers on the macOS Calculator
  public enum Button {
    /// Digit buttons (0-9)
    public static let zero = "0"
    public static let one = "1"
    public static let two = "2"
    public static let three = "3"
    public static let four = "4"
    public static let five = "5"
    public static let six = "6"
    public static let seven = "7"
    public static let eight = "8"
    public static let nine = "9"

    /// Operation buttons
    public static let plus = "+"
    public static let minus = "-"
    public static let multiply = "×"
    public static let divide = "÷"
    public static let equals = "="
    public static let decimal = "."
    public static let percent = "%"
    public static let sign = "±"

    /// Control buttons
    public static let clear = "C"
    public static let allClear = "AC"
    public static let delete = "Delete"

    /// Button mappings for macOS calculator with path-based identifiers
    public static let buttonMappings: [String: String] = [
      "0":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"0\"]",
      "1":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]",
      "2":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"2\"]",
      "3":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"3\"]",
      "4":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"4\"]",
      "5":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"5\"]",
      "6":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"6\"]",
      "7":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"7\"]",
      "8":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"8\"]",
      "9":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"9\"]",
      "+":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Add\"]",
      "-":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Subtract\"]",
      "×":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Multiply\"]",
      "÷":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Divide\"]",
      "=":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Equals\"]",
      ".":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Decimal Point\"]",
      "%":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Percent\"]",
      "±":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Change Sign\"]",
      "C":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Clear\"]",
      "AC":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"All Clear\"]",
      "Delete":
        "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"Clear\"]",
    ]
  }

  /// Create a new Calculator model
  /// - Parameter toolChain: ToolChain instance for interacting with the calculator
  public init(toolChain: ToolChain) {
    super.init(
      bundleId: "com.apple.calculator",
      appName: "Calculator",
      toolChain: toolChain,
    )
  }

  /// Override to provide more robust window detection for Calculator
  /// - Returns: The main Calculator window, or nil if not found
  override public func getMainWindow() async throws -> UIElement? {
    // Try the parent implementation first
    if let parentResult = try await super.getMainWindow() {
      return parentResult
    }

    // If not found, try other approaches

    // Approach 1: Try to find any element with window role
    let windowCriteria = UIElementCriteria(role: "AXWindow")
    if let windowElement = try? await toolChain.findElement(
      matching: windowCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    ) {
      return windowElement
    }

    // Approach 2: Get the application element and assume it's the main container
    let appElement = try await toolChain.accessibilityService.getApplicationUIElement(
      bundleId: bundleId,
      recursive: false,  // Don't get children
    )

    return appElement
  }

  /// Find the display element in the Calculator
  /// - Returns: The display element, or nil if not found
  public func getDisplayElement() async throws -> UIElement? {
    // Get the main window first for reference
    let mainWindow = try await getMainWindow()
    if mainWindow == nil {
      return nil
    }

    // Try to find the display element using path-based identifier
    let displayPath =
      "macos://ui/AXApplication[@bundleId=\"com.apple.calculator\"]/AXWindow[@AXTitle=\"Calculator\"]/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXGroup/AXScrollArea[@AXDescription=\"Input\"]/AXStaticText"
    let directCriteria = UIElementCriteria(path: displayPath)

    if let element = try await toolChain.findElement(
      matching: directCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    ) {
      return element
    }

    // Look for the scroll area with description "Input"
    let scrollAreaCriteria = UIElementCriteria(
      role: "AXScrollArea",
      description: "Input",  // AXDescription attribute
    )

    if let scrollArea = try await toolChain.findElement(
      matching: scrollAreaCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 20,
    ) {
      // Return the first child if available
      if !scrollArea.children.isEmpty {
        return scrollArea.children.first
      }

      // Otherwise return the scroll area itself
      return scrollArea
    } else {
      return nil
    }
  }

  /// Get the current value shown in the Calculator display
  /// - Returns: The display value as a string, or nil if not found
  public func getDisplayValue() async throws -> String? {
    // Search for scroll area with description "Input"
    let scrollAreaCriteria = UIElementCriteria(
      role: "AXScrollArea",
      descriptionContains: "Input",  // Use contains for more flexible matching of AXDescription
    )

    // If that doesn't work, try a broader search
    let staticTextCriteria = UIElementCriteria(
      role: "AXStaticText",
    )

    // First try with the scroll area
    if let scrollArea = try await toolChain.findElement(
      matching: scrollAreaCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 15,
    ) {
      // Check for child elements (the static text element containing the actual value)
      if !scrollArea.children.isEmpty {
        for child in scrollArea.children {
          if let value = child.value {
            let stringValue = String(describing: value)

            // Clean up the string - remove invisible characters and whitespace
            let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
              .replacingOccurrences(of: "‎", with: "")  // Remove invisible character

            // If the value looks like a number, return it
            if !cleanValue.isEmpty {
              return cleanValue
            }
          }
        }
      }

      // Even if we don't find a value in the children, try getting the value from the scroll area itself
      if let areaValue = scrollArea.value {
        let stringValue = String(describing: areaValue)

        // Clean up the string - remove invisible characters and whitespace
        let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: "‎", with: "")  // Remove invisible character

        if !cleanValue.isEmpty {
          return cleanValue
        }
      }
    }

    // As a fallback, look for any static text element that might contain the display value
    let staticTextElements = try await toolChain.findElements(
      matching: staticTextCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 15,
    )

    // Check each static text element for a numeric value
    for element in staticTextElements {
      if let value = element.value {
        let stringValue = String(describing: value)
        let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
          .replacingOccurrences(of: "‎", with: "")

        // Check if it looks like a number
        if !cleanValue.isEmpty, Double(cleanValue) != nil || cleanValue == "0" {
          return cleanValue
        }
      }
    }

    return nil
  }

  /// Helper method to recursively search for display values in the UI hierarchy
  /// - Parameter element: The UI element to search
  /// - Returns: The display value if found, nil otherwise
  private func findDisplayValueInElement(_ element: UIElement) -> String? {
    // Check if this element has a value and is a static text element
    if element.role == "AXStaticText", let value = element.value {
      let stringValue = String(describing: value)

      // Clean up the string - remove invisible characters and whitespace
      let cleanValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "‎", with: "")  // Remove invisible character

      // Validate that it looks like a number (optional)
      if !cleanValue.isEmpty, Double(cleanValue) != nil || cleanValue == "0" {
        return cleanValue
      }
    }

    // Recursively check children
    for child in element.children {
      if let value = findDisplayValueInElement(child) {
        return value
      }
    }

    return nil
  }

  /// Find a Calculator button element using exact MCP element identifiers
  /// - Parameter button: The button identifier
  /// - Returns: The button element, or nil if not found
  public func findButton(_ button: String) async throws -> UIElement? {
    // Get the exact id mapping for this button
    guard let exactId = Button.buttonMappings[button] else {
      return nil
    }

    // APPROACH 1: Try direct description match (most reliable in practice)
    // This works because Calculator buttons consistently have descriptions like "1", "2", "+", etc.
    let descCriteria = UIElementCriteria(
      role: "AXButton",
      description: button,  // Matches AXDescription attribute
    )

    if let element = try await toolChain.findElement(
      matching: descCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    ) {
      return element
    }

    // APPROACH 2: Try exact ID match
    let idCriteria = UIElementCriteria(
      role: "AXButton",
      path: exactId,
    )

    if let element = try await toolChain.findElement(
      matching: idCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    ) {
      return element
    }

    // APPROACH 3: Try to find by partial ID match
    if exactId.contains(":") {
      let parts = exactId.split(separator: ":")
      if parts.count > 1 {
        let partialId = String(parts[1])
        let partialCriteria = UIElementCriteria(
          role: "AXButton",
          pathContains: partialId,
        )

        if let element = try await toolChain.findElement(
          matching: partialCriteria,
          scope: "application",
          bundleId: bundleId,
          maxDepth: 10,
        ) {
          return element
        }
      }
    }

    // APPROACH 4: Try to find by using broader criteria with case-insensitive matching
    let broadCriteria = UIElementCriteria(
      role: "AXButton",
      descriptionContains: button,  // Case-insensitive matching of AXDescription
    )

    if let element = try await toolChain.findElement(
      matching: broadCriteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    ) {
      return element
    }

    // APPROACH 5: Manual search through all buttons
    let buttonElements = try await toolChain.findElements(
      matching: UIElementCriteria(role: "AXButton"),
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    )

    for element in buttonElements {
      // Check button description (most reliable for Calculator)
      if let description = element.elementDescription {
        if description == button || description.localizedCaseInsensitiveContains(button) {
          return element
        }
      }

      // Check exact path match
      if element.path == exactId {
        return element
      }

      // Check for the button name/value in any property
      if let title = element.title {
        if title == button || title.localizedCaseInsensitiveContains(button) {
          return element
        }
      }

      if let value = element.value {
        let stringValue = String(describing: value)
        if stringValue == button || stringValue.localizedCaseInsensitiveContains(button) {
          return element
        }
      }
    }

    return nil
  }

  /// Find the Calculator keypad view container
  /// - Returns: The keypad view element, or nil if not found
  private func findCalculatorKeypadView() async throws -> UIElement? {
    // Look for the group with identifier "CalculatorKeypadView"
    let criteria = UIElementCriteria(
      role: "AXGroup",
      pathContains: "CalculatorKeypadView",
    )

    return try await toolChain.findElement(
      matching: criteria,
      scope: "application",
      bundleId: bundleId,
      maxDepth: 10,
    )
  }

  /// Press a Calculator button using the default interaction method (AXPress)
  /// - Parameter button: The button identifier
  /// - Returns: True if the button was successfully pressed
  public func pressButton(_ button: String) async throws -> Bool {
    // For clear buttons, try to use the escape key as a fallback
    if button == "Delete" || button == "C" || button == "AC" {
      return try await toolChain.executeKeySequence(sequence: [["tap": .string("escape")]])
    }

    // Use the accessibility-based interaction by default
    return try await pressButtonViaAccessibility(button)
  }

  /// Clear the calculator
  /// - Returns: True if the calculator was successfully cleared
  public func clear() async throws -> Bool {
    // Try multiple clear buttons in order
    let clearButtons = ["Delete", "AC", "C", "Clear", "AllClear"]

    for button in clearButtons {
      do {
        if try await pressButton(button) {
          return true
        }
      } catch {
        // Try the next button
        continue
      }
    }

    // If all clear buttons fail, try using the escape key
    let result = try await toolChain.executeKeySequence(sequence: [["tap": .string("escape")]])
    return result
  }

  /// Enter a sequence of characters using button presses
  /// - Parameter sequence: The sequence to enter (e.g., "123+456=")
  /// - Returns: True if all buttons were successfully pressed
  public func enterSequence(_ sequence: String) async throws -> Bool {
    // Press each button in the sequence
    for char in sequence {
      let buttonId = String(char)

      // Map special characters if needed
      let mappedId: String =
        switch char {
        case "×": Button.multiply
        case "÷": Button.divide
        case "-": Button.minus
        case "−": Button.minus
        default: buttonId
        }

      if try await !pressButton(mappedId) {
        return false
      }

      // Brief pause between button presses
      try await Task.sleep(for: .milliseconds(100))
    }

    return true
  }

  /// Press a button using the AXPress action through accessibility APIs
  /// - Parameter button: The button identifier
  /// - Returns: True if the button was successfully pressed
  public func pressButtonViaAccessibility(_ button: String) async throws -> Bool {
    // Get the exact path mapping for this button directly from our map
    let path: String
    if let mappedPath = Button.buttonMappings[button] {
      path = mappedPath
    } else {
      // If button doesn't have a mapped path, try to find it via UI
      guard let buttonElement = try await findButton(button) else {
        throw NSError(
          domain: "CalculatorModel",
          code: 1000,
          userInfo: [NSLocalizedDescriptionKey: "Button not found: \(button)"],
        )
      }

      // Get the button element's path
      let elementPath = buttonElement.path

      // Check if path is empty
      if elementPath.isEmpty {
        throw NSError(
          domain: "CalculatorModel",
          code: 1001,
          userInfo: [NSLocalizedDescriptionKey: "Button found but has empty path: \(button)"],
        )
      }

      path = elementPath
    }

    // Use the direct approach for clicking with path
    do {
      // Use toolChain.interactionService.clickElementByPath directly
      try await toolChain.interactionService.clickElementByPath(
        path: path,
        appBundleId: bundleId,
      )

      // Give the UI time to update after the click
      try await Task.sleep(for: .milliseconds(300))

      return true
    } catch {
      // Fallback to the handler approach if the direct approach fails
      // Create the parameters with explicit values for safety
      let params: [String: Value] = [
        "action": .string("click"),
        "id": .string(path),
        "appBundleId": .string(bundleId),
      ]

      // Verify params object isn't empty before calling
      if params.isEmpty || params.count < 3 {
        return false
      }

      do {
        let result = try await toolChain.uiInteractionTool.handler(params)

        // Parse the result
        if let content = result.first, case .text(let text) = content {
          // Check for success message in the result
          return text.contains("success") || text.contains("clicked") || text.contains("true")
        } else if !result.isEmpty {
          return true  // Assume success if we got any result
        }

        return false
      } catch {
        return false
      }
    }
  }

  /// Click a button using mouse coordinates
  /// - Parameter button: The button identifier
  /// - Returns: True if the button was successfully clicked
  public func clickButtonWithMouse(_ button: String) async throws -> Bool {
    // Find the button element
    guard let buttonElement = try await findButton(button) else {
      throw NSError(
        domain: "CalculatorModel",
        code: 1000,
        userInfo: [NSLocalizedDescriptionKey: "Button not found: \(button)"],
      )
    }

    // Calculate the center point of the button
    let centerX = buttonElement.frame.origin.x + buttonElement.frame.size.width / 2
    let centerY = buttonElement.frame.origin.y + buttonElement.frame.size.height / 2
    let position = CGPoint(x: centerX, y: centerY)

    // Use the UIInteractionTool with coordinates to click via mouse
    let params: [String: Value] = [
      "action": .string("click"),
      "x": .double(Double(position.x)),
      "y": .double(Double(position.y)),
    ]

    let result = try await toolChain.uiInteractionTool.handler(params)

    // Parse the result
    if let content = result.first, case .text(let text) = content {
      // Check for success message in the result
      return text.contains("success") || text.contains("clicked") || text.contains("true")
    }

    return false
  }

  /// Override the terminate method to ensure calculator is properly closed
  /// - Returns: True if the application was successfully terminated
  override public func terminate() async throws -> Bool {
    // First try to use the applicationService to terminate the application
    let appTerminated = try await super.terminate()

    // If that didn't work, try direct approach with force termination
    if !appTerminated {
      // Terminate any existing calculator instances - use force if needed
      for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
        if !app.terminate() {
          _ = app.forceTerminate()
        }
      }

      // Give the system time to fully close the app
      try await Task.sleep(for: .milliseconds(1000))

      // Verify termination was successful
      let stillRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        .isEmpty
      if stillRunning {
        // One last desperate attempt with force termination
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
          _ = app.forceTerminate()
        }
        try await Task.sleep(for: .milliseconds(500))
      }
    }

    // Check if the app is still running
    let success = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    return success
  }

  /// Type a digit using keyboard input
  /// - Parameter digit: The digit to type
  /// - Returns: True if the key was successfully pressed
  public func typeDigit(_ digit: String) async throws -> Bool {
    guard digit.count == 1, let char = digit.first, ("0"..."9").contains(String(char)) else {
      throw NSError(
        domain: "CalculatorModel",
        code: 1002,
        userInfo: [NSLocalizedDescriptionKey: "Invalid digit: \(digit)"],
      )
    }

    // Use the keyboard interaction tool to type the digit
    return try await toolChain.typeTextWithKeyboard(text: digit)
  }

  /// Type an operator key using keyboard input
  /// - Parameter operator: The operator to type (+, -, *, /)
  /// - Returns: True if the key was successfully pressed
  public func typeOperator(_ operator: String) async throws -> Bool {
    // Use the keyboard interaction tool to type the operator
    try await toolChain.typeTextWithKeyboard(text: `operator`)
  }

  /// Type text directly using the keyboard interaction tool
  /// - Parameter text: The text to type
  /// - Returns: True if the text was successfully typed
  public func typeText(_ text: String) async throws -> Bool {
    try await toolChain.typeTextWithKeyboard(text: text)
  }

  /// Execute a sequence of keystrokes
  /// - Parameter sequence: The sequence to execute (e.g., [{"tap": "1"}, {"tap": "+"}, {"tap": "2"}])
  /// - Returns: True if the sequence was successfully executed
  public func executeKeySequence(_ sequence: [[String: Value]]) async throws -> Bool {
    try await toolChain.executeKeySequence(sequence: sequence)
  }
}
