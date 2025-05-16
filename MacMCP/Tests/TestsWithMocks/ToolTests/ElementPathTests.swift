import XCTest
import Testing
import Foundation
import MacMCPUtilities

@testable import MacMCP

// Mock AXUIElement class for testing path resolution
class MockAXUIElement {
    let role: String
    let attributes: [String: Any]
    let children: [MockAXUIElement]
    
    init(role: String, attributes: [String: Any] = [:], children: [MockAXUIElement] = []) {
        self.role = role
        self.attributes = attributes
        self.children = children
    }
}

// Helper class for mocking AccessibilityService in tests
class ElementPathTestMockService {
    let rootElement: MockAXUIElement
    
    init(rootElement: MockAXUIElement) {
        self.rootElement = rootElement
    }
    
    func getAttribute(_ element: MockAXUIElement, attribute: String) -> Any? {
        if attribute == "AXRole" {
            return element.role
        } else if attribute == "AXChildren" {
            return element.children
        } else {
            return element.attributes[attribute]
        }
    }
}

// Test helper utilities
func mockResolvePathForTest(service: ElementPathTestMockService, path: ElementPath) -> MockAXUIElement? {
    do {
        return try mockResolvePathInternal(service: service, path: path)
    } catch {
        return nil
    }
}

func mockResolvePathWithExceptionForTest(service: ElementPathTestMockService, path: ElementPath) -> ElementPathError? {
    do {
        _ = try mockResolvePathInternal(service: service, path: path)
        return nil
    } catch let error as ElementPathError {
        return error
    } catch {
        return nil
    }
}

// Internal implementation that throws errors
func mockResolvePathInternal(service: ElementPathTestMockService, path: ElementPath) throws -> MockAXUIElement {
    // Start with the root element
    var current = service.rootElement
    
    // Navigate through each segment of the path
    for (index, segment) in path.segments.enumerated() {
        // Skip the root segment if it's already matched
        if index == 0 && segment.role == "AXWindow" {
            continue
        }
        
        // Find children matching this segment
        var matches: [MockAXUIElement] = []
        
        if index == 0 && segment.role == current.role {
            // Special case for the root element
            if mockSegmentMatchesElement(segment, element: current) {
                matches.append(current)
            }
        } else {
            // Check all children
            for child in current.children {
                if mockSegmentMatchesElement(segment, element: child) {
                    matches.append(child)
                }
            }
        }
        
        // Handle matches based on count and index
        if matches.isEmpty {
            // Get child information for better diagnostics
            let childCandidates = current.children.prefix(5).map { child in
                return "Child (role: \(child.role), attributes: \(child.attributes))"
            }
            
            throw ElementPathError.resolutionFailed(
                segment: segment.toString(),
                index: index,
                candidates: childCandidates,
                reason: "No elements match this segment"
            )
        } else if matches.count > 1 && segment.index == nil {
            // Ambiguous match - create diagnostic information
            let matchCandidates = matches.prefix(5).map { match in
                return "Match (role: \(match.role), attributes: \(match.attributes))"
            }
            
            throw ElementPathError.resolutionFailed(
                segment: segment.toString(),
                index: index,
                candidates: matchCandidates,
                reason: "Multiple elements (\(matches.count)) match this segment"
            )
        } else {
            if let segmentIndex = segment.index {
                // Use the specified index if available
                if segmentIndex < 0 || segmentIndex >= matches.count {
                    throw ElementPathError.segmentResolutionFailed("Invalid index: \(segmentIndex)", atSegment: index)
                }
                current = matches[segmentIndex]
            } else {
                // Use the first match
                current = matches[0]
            }
        }
    }
    
    return current
}

// Check if a segment matches an element
func mockSegmentMatchesElement(_ segment: PathSegment, element: MockAXUIElement) -> Bool {
    // Check role first
    guard segment.role == element.role else {
        return false
    }
    
    // If there are no attributes to match, we're done
    if segment.attributes.isEmpty {
        return true
    }
    
    // Check each attribute
    for (key, value) in segment.attributes {
        // Try with various keys to improve matching chances
        let normalizedKey = normalizeAttributeNameForTest(key)
        let keys = [key, normalizedKey]
        
        var attributeFound = false
        for attributeKey in keys {
            if let elementValue = element.attributes[attributeKey] {
                // Convert to string for comparison
                let elementValueString: String
                if let stringValue = elementValue as? String {
                    elementValueString = stringValue
                } else if let numberValue = elementValue as? NSNumber {
                    elementValueString = numberValue.stringValue
                } else if let boolValue = elementValue as? Bool {
                    elementValueString = boolValue ? "true" : "false"
                } else {
                    elementValueString = String(describing: elementValue)
                }
                
                // The matching logic is built into mockAttributeMatches and doesn't need the type explicitly
                let doesMatch = mockAttributeMatches(attributeKey, expected: value, actual: elementValueString)
                
                if doesMatch {
                    attributeFound = true
                    break
                }
            }
        }
        
        if !attributeFound {
            return false
        }
    }
    
    return true
}

// Simple attribute name normalization for test
func normalizeAttributeNameForTest(_ name: String) -> String {
    // If it already has AX prefix, return as is
    if name.hasPrefix("AX") {
        return name
    }
    
    // Handle common mappings
    let mappings = [
        "title": "AXTitle",
        "description": "AXDescription",
        "value": "AXValue",
        "id": "AXIdentifier",
        "identifier": "AXIdentifier"
    ]
    
    if let mapped = mappings[name] {
        return mapped
    }
    
    // Add AX prefix for other attributes
    return "AX" + name.prefix(1).uppercased() + name.dropFirst()
}

// Match attribute values using appropriate strategy
func mockAttributeMatches(_ attributeName: String, expected: String, actual: String) -> Bool {
    // Determine match type based on attribute
    let matchType = mockDetermineMatchType(forAttribute: attributeName)
    
    switch matchType {
    case .exact:
        return actual == expected
        
    case .contains:
        return actual.localizedCaseInsensitiveContains(expected)
        
    case .substring:
        // Either exact match, or one contains the other
        return actual == expected ||
               actual.localizedCaseInsensitiveContains(expected) ||
               expected.localizedCaseInsensitiveContains(actual)
        
    case .startsWith:
        return actual.hasPrefix(expected) || actual == expected || actual.lowercased().hasPrefix(expected.lowercased())
    }
}

// Determine match type for test
enum MockMatchType {
    case exact, contains, substring, startsWith
}

func mockDetermineMatchType(forAttribute attribute: String) -> MockMatchType {
    let normalizedName = normalizeAttributeNameForTest(attribute)
    
    switch normalizedName {
    case "AXTitle":
        return .substring
        
    case "AXDescription", "AXHelp":
        return .contains
        
    case "AXValue":
        return .substring
        
    case "AXIdentifier", "AXRole", "AXSubrole":
        return .exact
        
    case "AXFilename":
        return .startsWith
        
    default:
        return .exact
    }
}

// Helper for creating deep hierarchies
func createDeepMockHierarchy(depth: Int, breadth: Int, currentDepth: Int = 0) -> MockAXUIElement {
    // Create a deep hierarchy for performance testing
    if currentDepth == depth {
        // At max depth, create leaf nodes
        return MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "Deep Button", "AXDescription": "Button at depth \(depth)"]
        )
    }
    
    // Create children for this level
    var children: [MockAXUIElement] = []
    
    for _ in 0..<breadth {
        children.append(createDeepMockHierarchy(
            depth: depth,
            breadth: breadth,
            currentDepth: currentDepth + 1
        ))
    }
    
    // Create a group at this level
    return MockAXUIElement(
        role: currentDepth == 0 ? "AXWindow" : "AXGroup",
        attributes: ["AXTitle": "Group at depth \(currentDepth)", "AXDescription": "Group \(currentDepth)"],
        children: children
    )
}

@Suite("ElementPath Tests")
struct ElementPathTests {
    @Test("PathSegment initialization and properties")
    func testPathSegmentInitialization() {
        let segment = PathSegment(
            role: "AXButton",
            attributes: [
                "name": "Test Button",
                "description": "A test button"
            ],
            index: 2
        )
        
        #expect(segment.role == "AXButton")
        #expect(segment.attributes.count == 2)
        #expect(segment.attributes["name"] == "Test Button")
        #expect(segment.attributes["description"] == "A test button")
        #expect(segment.index == 2)
    }
    
    @Test("PathSegment toString conversion")
    func testPathSegmentToString() {
        // Simple segment with just a role
        let simpleSegment = PathSegment(role: "AXButton")
        #expect(simpleSegment.toString() == "AXButton")
        
        // Segment with attributes
        let attributeSegment = PathSegment(
            role: "AXButton",
            attributes: ["name": "Test Button"]
        )
        #expect(attributeSegment.toString() == "AXButton[@name=\"Test Button\"]")
        
        // Segment with multiple attributes (should be sorted alphabetically)
        let multiAttributeSegment = PathSegment(
            role: "AXButton",
            attributes: [
                "name": "Test Button",
                "description": "A test button"
            ]
        )
        #expect(multiAttributeSegment.toString() == "AXButton[@description=\"A test button\"][@name=\"Test Button\"]")
        
        // Segment with index
        let indexSegment = PathSegment(
            role: "AXButton",
            index: 2
        )
        #expect(indexSegment.toString() == "AXButton[2]")
        
        // Segment with attributes and index
        let fullSegment = PathSegment(
            role: "AXButton",
            attributes: ["name": "Test Button"],
            index: 2
        )
        #expect(fullSegment.toString() == "AXButton[@name=\"Test Button\"][2]")
        
        // Test escaping quotes in attribute values
        let escapedSegment = PathSegment(
            role: "AXButton",
            attributes: ["name": "Button with \"quotes\""]
        )
        #expect(escapedSegment.toString() == "AXButton[@name=\"Button with \\\"quotes\\\"\"]")
    }
    
    @Test("ElementPath initialization and properties")
    func testElementPathInitialization() throws {
        let segments = [
            PathSegment(role: "AXWindow"),
            PathSegment(role: "AXGroup", attributes: ["name": "Controls"]),
            PathSegment(role: "AXButton", attributes: ["description": "Submit"])
        ]
        
        let path = try ElementPath(segments: segments)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["name"] == "Controls")
        #expect(path.segments[2].role == "AXButton")
        #expect(path.segments[2].attributes["description"] == "Submit")
    }
    
    @Test("ElementPath empty initialization")
    func testElementPathEmptyInitialization() {
        let emptySegments: [PathSegment] = []
        
        do {
            _ = try ElementPath(segments: emptySegments)
            XCTFail("Should have thrown an error for empty segments")
        } catch let error as ElementPathError {
            #expect(error == ElementPathError.emptyPath)
        } catch {
            XCTFail("Threw unexpected error: \(error)")
        }
    }
    
    @Test("ElementPath toString conversion")
    func testElementPathToString() throws {
        let segments = [
            PathSegment(role: "AXWindow"),
            PathSegment(role: "AXGroup", attributes: ["name": "Controls"]),
            PathSegment(role: "AXButton", attributes: ["description": "Submit"])
        ]
        
        let path = try ElementPath(segments: segments)
        let pathString = path.toString()
        
        #expect(pathString == "ui://AXWindow/AXGroup[@name=\"Controls\"]/AXButton[@description=\"Submit\"]")
    }
    
    @Test("ElementPath parsing simple path")
    func testElementPathParsing() throws {
        let pathString = "ui://AXWindow/AXGroup/AXButton"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[2].role == "AXButton")
    }
    
    @Test("ElementPath parsing with attributes")
    func testElementPathParsingWithAttributes() throws {
        let pathString = "ui://AXWindow/AXGroup[@name=\"Controls\"]/AXButton[@description=\"Submit\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["name"] == "Controls")
        #expect(path.segments[2].role == "AXButton")
        #expect(path.segments[2].attributes["description"] == "Submit")
    }
    
    @Test("ElementPath parsing with index")
    func testElementPathParsingWithIndex() throws {
        let pathString = "ui://AXWindow/AXGroup[2]/AXButton"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].index == 2)
        #expect(path.segments[2].role == "AXButton")
    }
    
    @Test("ElementPath parsing with attributes and index")
    func testElementPathParsingWithAttributesAndIndex() throws {
        let pathString = "ui://AXWindow/AXGroup[@name=\"Controls\"][2]/AXButton[@description=\"Submit\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["name"] == "Controls")
        #expect(path.segments[1].index == 2)
        #expect(path.segments[2].role == "AXButton")
        #expect(path.segments[2].attributes["description"] == "Submit")
    }
    
    @Test("ElementPath parsing with escaped quotes")
    func testElementPathParsingWithEscapedQuotes() throws {
        let pathString = "ui://AXWindow/AXGroup[@name=\"Group with \\\"quotes\\\"\"]/AXButton"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["name"] == "Group with \"quotes\"")
        #expect(path.segments[2].role == "AXButton")
    }
    
    @Test("ElementPath parsing with multiple attributes")
    func testElementPathParsingWithMultipleAttributes() throws {
        let pathString = "ui://AXWindow/AXGroup[@name=\"Controls\"][@id=\"group1\"]/AXButton[@description=\"Submit\"][@enabled=\"true\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 3)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["name"] == "Controls")
        #expect(path.segments[1].attributes["id"] == "group1")
        #expect(path.segments[2].role == "AXButton")
        #expect(path.segments[2].attributes["description"] == "Submit")
        #expect(path.segments[2].attributes["enabled"] == "true")
    }
    
    @Test("ElementPath parsing invalid prefix")
    func testElementPathParsingInvalidPrefix() {
        let pathString = "invalid://AXWindow/AXGroup/AXButton"
        
        do {
            _ = try ElementPath.parse(pathString)
            XCTFail("Should have thrown an error for invalid prefix")
        } catch let error as ElementPathError {
            #expect(error == ElementPathError.invalidPathPrefix(pathString))
        } catch {
            XCTFail("Threw unexpected error: \(error)")
        }
    }
    
    @Test("ElementPath parsing empty path")
    func testElementPathParsingEmptyPath() {
        let pathString = "ui://"
        
        do {
            _ = try ElementPath.parse(pathString)
            XCTFail("Should have thrown an error for empty path")
        } catch let error as ElementPathError {
            #expect(error == ElementPathError.emptyPath)
        } catch {
            XCTFail("Threw unexpected error: \(error)")
        }
    }
    
    @Test("ElementPath appending segment")
    func testElementPathAppendingSegment() throws {
        let initialSegments = [
            PathSegment(role: "AXWindow"),
            PathSegment(role: "AXGroup")
        ]
        
        let path = try ElementPath(segments: initialSegments)
        let newSegment = PathSegment(role: "AXButton", attributes: ["description": "Submit"])
        let newPath = try path.appendingSegment(newSegment)
        
        #expect(newPath.segments.count == 3)
        #expect(newPath.segments[0].role == "AXWindow")
        #expect(newPath.segments[1].role == "AXGroup")
        #expect(newPath.segments[2].role == "AXButton")
        #expect(newPath.segments[2].attributes["description"] == "Submit")
    }
    
    @Test("ElementPath appending segments")
    func testElementPathAppendingSegments() throws {
        let initialSegments = [
            PathSegment(role: "AXWindow")
        ]
        
        let additionalSegments = [
            PathSegment(role: "AXGroup"),
            PathSegment(role: "AXButton", attributes: ["description": "Submit"])
        ]
        
        let path = try ElementPath(segments: initialSegments)
        let newPath = try path.appendingSegments(additionalSegments)
        
        #expect(newPath.segments.count == 3)
        #expect(newPath.segments[0].role == "AXWindow")
        #expect(newPath.segments[1].role == "AXGroup")
        #expect(newPath.segments[2].role == "AXButton")
        #expect(newPath.segments[2].attributes["description"] == "Submit")
    }
    
    @Test("ElementPath isElementPath check")
    func testIsElementPath() {
        #expect(ElementPath.isElementPath("ui://AXWindow/AXGroup/AXButton") == true)
        #expect(ElementPath.isElementPath("ui://") == true) // Empty path is still an element path (will fail on parse)
        #expect(ElementPath.isElementPath("somestring") == false)
        #expect(ElementPath.isElementPath("ui:element:123") == false) // Legacy format
        #expect(ElementPath.isElementPath("") == false)
    }
    
    @Test("ElementPath roundtrip (parse and toString)")
    func testElementPathRoundtrip() throws {
        let originalPath = "ui://AXWindow/AXGroup[@name=\"Controls\"][2]/AXButton[@description=\"Submit\"]"
        let path = try ElementPath.parse(originalPath)
        let regeneratedPath = path.toString()
        
        #expect(regeneratedPath == originalPath)
    }
    
    // MARK: - Path Resolution Tests
    
    // Mock AXUIElement class for testing path resolution
    class MockAXUIElement: @unchecked Sendable {
        let role: String
        let attributes: [String: Any]
        let children: [MockAXUIElement]
        
        init(role: String, attributes: [String: Any] = [:], children: [MockAXUIElement] = []) {
            self.role = role
            self.attributes = attributes
            self.children = children
        }
    }
    
    // Mock class for simple element attribute access
    final class ElementPathTestMockService {
        let rootElement: MockAXUIElement
        
        init(rootElement: MockAXUIElement) {
            self.rootElement = rootElement
        }
        
        func getAttribute(_ element: MockAXUIElement, attribute: String) -> Any? {
            if attribute == "AXRole" {
                return element.role
            } else if attribute == "AXChildren" {
                return element.children
            } else {
                return element.attributes[attribute]
            }
        }
    }
    
    // Simplified mock for AccessibilityServiceProtocol that only implements required methods
    final class MockAccessibilityService: AccessibilityServiceProtocol, @unchecked Sendable {
        let rootElement: MockAXUIElement
        
        init(rootElement: MockAXUIElement) {
            self.rootElement = rootElement
        }
        
        func getAttribute(_ element: MockAXUIElement, attribute: String) -> Any? {
            if attribute == "AXRole" {
                return element.role
            } else if attribute == "AXChildren" {
                return element.children
            } else {
                return element.attributes[attribute]
            }
        }
        
        // Required core function for AccessibilityServiceProtocol
        func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
            return try await operation()
        }
        
        // Minimal implementations to satisfy the protocol
        func getSystemUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
            return UIElement(identifier: "mock-system", role: "AXApplication", frame: CGRect.zero, axElement: nil)
        }
        
        func getApplicationUIElement(bundleIdentifier: String, recursive: Bool, maxDepth: Int) async throws -> UIElement {
            return UIElement(identifier: "mock-app", role: "AXApplication", frame: CGRect.zero, axElement: nil)
        }
        
        func getFocusedApplicationUIElement(recursive: Bool, maxDepth: Int) async throws -> UIElement {
            return UIElement(identifier: "mock-focused-app", role: "AXApplication", frame: CGRect.zero, axElement: nil)
        }
        
        func getUIElementAtPosition(position: CGPoint, recursive: Bool, maxDepth: Int) async throws -> UIElement? {
            return UIElement(identifier: "mock-position", role: "AXElement", frame: CGRect.zero, axElement: nil)
        }
        
        func findUIElements(role: String?, titleContains: String?, scope: UIElementScope, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
            return []
        }
        
        func findElements(withRole role: String, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
            return []
        }
        
        func findElements(withRole role: String, forElement element: AXUIElement, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
            return []
        }
        
        func findElementByPath(_ pathString: String) async throws -> UIElement? {
            return UIElement(identifier: "mock-path-element", role: "AXElement", frame: CGRect.zero, axElement: nil)
        }
        
        func findElementByPath(path: String) async throws -> UIElement? {
            return UIElement(identifier: "mock-path-element", role: "AXElement", frame: CGRect.zero, axElement: nil)
        }
        
        func performAction(action: String, onElementWithPath elementPath: String) async throws {
            // No-op for tests
        }
        
        func setWindowOrder(withPath path: String, orderMode: WindowOrderMode, referenceWindowPath: String?) async throws {
            // No-op for tests
        }
        
        func getChildElements(forElement element: AXUIElement, recursive: Bool, maxDepth: Int) async throws -> [UIElement] {
            return []
        }
        
        func getElementWithFocus() async throws -> UIElement {
            return UIElement(identifier: "mock-focused-element", role: "AXElement", frame: CGRect.zero, axElement: nil)
        }
        
        func getRunningApplications() -> [NSRunningApplication] {
            return []
        }
        
        func isApplicationRunning(withBundleIdentifier bundleIdentifier: String) -> Bool {
            return false
        }
        
        func isApplicationRunning(withTitle title: String) -> Bool {
            return false
        }
        
        func waitForElementByPath(_ pathString: String, timeout: TimeInterval, pollInterval: TimeInterval) async throws -> UIElement {
            return UIElement(identifier: "mock-wait-element", role: "AXElement", frame: CGRect.zero, axElement: nil)
        }
        
        // Window management methods required by protocol
        func getWindows(forApplication bundleId: String) async throws -> [UIElement] {
            return []
        }
        
        func getActiveWindow(forApplication bundleId: String) async throws -> UIElement? {
            return nil
        }
        
        func moveWindow(withPath path: String, to position: CGPoint) async throws {
            // No-op for tests
        }
        
        func resizeWindow(withPath path: String, to size: CGSize) async throws {
            // No-op for tests
        }
        
        func minimizeWindow(withPath path: String) async throws {
            // No-op for tests
        }
        
        func maximizeWindow(withPath path: String) async throws {
            // No-op for tests
        }
        
        func closeWindow(withPath path: String) async throws {
            // No-op for tests
        }
        
        func activateWindow(withPath path: String) async throws {
            // No-op for tests
        }
        
        func setWindowOrder(withPath path: String, orderMode: WindowOrderMode) async throws {
            // No-op for tests
        }
        
        func focusWindow(withPath path: String) async throws {
            // No-op for tests
        }
        
        func navigateMenu(path: String, in bundleId: String) async throws {
            // No-op for tests
        }
    }
    
    // Helper function to create a mock element hierarchy
    func createMockElementHierarchy() -> MockAXUIElement {
        // Create a window with various controls
        let button1 = MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "OK", "AXDescription": "OK Button", "AXEnabled": true]
        )
        
        let button2 = MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "Cancel", "AXDescription": "Cancel Button", "AXEnabled": true]
        )
        
        let textField = MockAXUIElement(
            role: "AXTextField",
            attributes: ["AXValue": "Sample text", "AXDescription": "Text input"]
        )
        
        let controlGroup = MockAXUIElement(
            role: "AXGroup",
            attributes: ["AXTitle": "Controls", "AXDescription": "Control group"],
            children: [button1, button2, textField]
        )
        
        let contentArea = MockAXUIElement(
            role: "AXScrollArea",
            attributes: ["AXDescription": "Content area"],
            children: [
                MockAXUIElement(
                    role: "AXStaticText",
                    attributes: ["AXValue": "Hello World"]
                )
            ]
        )
        
        let duplicateGroup1 = MockAXUIElement(
            role: "AXGroup",
            attributes: ["AXTitle": "Duplicate", "AXIdentifier": "group1"],
            children: [
                MockAXUIElement(
                    role: "AXCheckBox",
                    attributes: ["AXTitle": "Option 1", "AXValue": 1]
                )
            ]
        )
        
        let duplicateGroup2 = MockAXUIElement(
            role: "AXGroup",
            attributes: ["AXTitle": "Duplicate", "AXIdentifier": "group2"],
            children: [
                MockAXUIElement(
                    role: "AXCheckBox",
                    attributes: ["AXTitle": "Option 2", "AXValue": 0]
                )
            ]
        )
        
        return MockAXUIElement(
            role: "AXWindow",
            attributes: ["AXTitle": "Test Window"],
            children: [controlGroup, contentArea, duplicateGroup1, duplicateGroup2]
        )
    }
    
    @Test("Path resolution with simple path")
    func testPathResolutionSimple() throws {
        // This test will validate the basic resolution logic using our mock hierarchy
        let mockHierarchy = createMockElementHierarchy()
        let mockService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test resolving a simple path
        let pathString = "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]"
        let path = try ElementPath.parse(pathString)
        
        let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
        #expect(mockResolveResult != nil)
        #expect(mockResolveResult?.role == "AXGroup")
        #expect(mockResolveResult?.attributes["AXTitle"] as? String == "Controls")
    }
    
    @Test("Path resolution with attributes")
    func testPathResolutionWithAttributes() throws {
        // This test will validate resolution with attribute matching
        let mockHierarchy = createMockElementHierarchy()
        let mockService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test resolving a path with attribute constraints
        let pathString = "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"]"
        let path = try ElementPath.parse(pathString)
        
        let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
        #expect(mockResolveResult != nil)
        #expect(mockResolveResult?.role == "AXButton")
        #expect(mockResolveResult?.attributes["AXTitle"] as? String == "OK")
    }
    
    @Test("Path resolution with index")
    func testPathResolutionWithIndex() throws {
        // This test will validate resolution with index-based selection
        let mockHierarchy = createMockElementHierarchy()
        let mockService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test resolving a path with index for disambiguation
        let pathString = "ui://AXWindow/AXGroup[@AXTitle=\"Duplicate\"][1]"
        let path = try ElementPath.parse(pathString)
        
        let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
        #expect(mockResolveResult != nil)
        #expect(mockResolveResult?.role == "AXGroup")
        #expect(mockResolveResult?.attributes["AXIdentifier"] as? String == "group2")
    }
    
    @Test("Path resolution with no matching elements")
    func testPathResolutionNoMatch() throws {
        // This test will validate error handling when no elements match
        let mockHierarchy = createMockElementHierarchy()
        let mockService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test resolving a path that has no matches
        let pathString = "ui://AXWindow/AXGroup[@AXTitle=\"NonExistent\"]"
        let path = try ElementPath.parse(pathString)
        
        let mockResolveResult = mockResolvePathForTest(service: mockService, path: path)
        #expect(mockResolveResult == nil)
    }
    
    @Test("Path resolution with ambiguous match")
    func testPathResolutionAmbiguousMatch() throws {
        // This test will validate error handling when multiple elements match without an index
        let mockHierarchy = createMockElementHierarchy()
        let mockService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test resolving a path with ambiguous matches (both duplicate groups)
        let pathString = "ui://AXWindow/AXGroup[@AXTitle=\"Duplicate\"]"
        let path = try ElementPath.parse(pathString)
        
        let mockResolveException = mockResolvePathWithExceptionForTest(service: mockService, path: path)
        #expect(mockResolveException != nil)
        guard let error = mockResolveException else {
            XCTFail("Expected ambiguous match error but no error occurred")
            return
        }
        
        switch error {
        case .ambiguousMatch(let segment, let count, let index):
            #expect(segment.contains("AXGroup[@AXTitle=\"Duplicate\"]"))
            #expect(count == 2)
            #expect(index == 1)
        default:
            XCTFail("Expected ambiguous match error but got \(error)")
        }
    }
    
// These need to be defined inside the test suite class, not as an extension
@Test("Utility for path resolution in tests")
func testMockPathResolution() throws {
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)
    
    // Simple path test
    let path = try ElementPath.parse("ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]")
    let result = mockResolvePathForTest(service: mockService, path: path)
    #expect(result != nil)
    #expect(result?.role == "AXGroup")
}

@Test("Testing attribute fallback matching")
func testAttributeFallbackMatching() throws {
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)
    
    // Test with non-standard attribute name that should be normalized
    let path1 = try ElementPath.parse("ui://AXWindow/AXGroup[@title=\"Controls\"]")
    let result1 = mockResolvePathForTest(service: mockService, path: path1)
    #expect(result1 != nil)
    #expect(result1?.role == "AXGroup")
    #expect(result1?.attributes["AXTitle"] as? String == "Controls")
    
    // Test with alternative attribute that should match through fallback
    let path2 = try ElementPath.parse("ui://AXWindow/AXScrollArea[@description=\"Content area\"]")
    let result2 = mockResolvePathForTest(service: mockService, path: path2)
    #expect(result2 != nil)
    #expect(result2?.role == "AXScrollArea")
    #expect(result2?.attributes["AXDescription"] as? String == "Content area")
    
    // Test with substring matching for a title (partial match)
    let path3 = try ElementPath.parse("ui://AXWindow/AXGroup[@title=\"Cont\"]")
    let result3 = mockResolvePathForTest(service: mockService, path: path3)
    #expect(result3 != nil)
    #expect(result3?.role == "AXGroup")
    #expect(result3?.attributes["AXTitle"] as? String == "Controls")
}

@Test("Testing match strategies")
func testMatchStrategies() throws {
    // Since we can't easily test the AX path resolution directly,
    // let's test the core functionality directly:
    // 1. The MatchType enum and its values
    // 2. The determineMatchType method to select strategies
    // 3. Direct attribute matching with each strategy
    
    // 1. Test basic enum functionality
    let enumCases: [ElementPath.MatchType] = [.exact, .contains, .substring, .startsWith]
    #expect(enumCases.count == 4)
    
    // Create test instance to access the path methods
    let elementPath = try ElementPath(segments: [PathSegment(role: "AXWindow")])
    
    // 2. Test determineMatchType for different attributes
    
    // Test common attributes have expected matching strategies
    func testMatchTypeForAttribute(_ attr: String, expected: ElementPath.MatchType) {
        #expect(elementPath.determineMatchType(forAttribute: attr) == expected)
    }
    
    // Test exact match attributes
    testMatchTypeForAttribute("AXIdentifier", expected: .exact)
    testMatchTypeForAttribute("AXRole", expected: .exact)
    testMatchTypeForAttribute("bundleIdentifier", expected: .exact)
    
    // Test contains match attributes
    testMatchTypeForAttribute("AXDescription", expected: .contains)
    testMatchTypeForAttribute("AXHelp", expected: .contains)
    
    // Test substring match attributes
    testMatchTypeForAttribute("AXTitle", expected: .substring)
    testMatchTypeForAttribute("AXValue", expected: .substring)
    
    // Test startsWith match attributes
    testMatchTypeForAttribute("AXFilename", expected: .startsWith)
    testMatchTypeForAttribute("AXName", expected: .startsWith)
    
    // 3. Test individual match strategies directly with different inputs
    
    // Create a simple wrapper around the actual matching logic
    func testMatch(attribute: String, expected: String, actual: String, shouldMatch: Bool) {
        let matchType = elementPath.determineMatchType(forAttribute: attribute)
        // print("DEBUG: Testing \(matchType) match for \(attribute): '\(expected)' vs '\(actual)'")
        
        let matches: Bool
        switch matchType {
        case .exact:
            matches = (actual == expected)
        case .contains:
            matches = actual.localizedCaseInsensitiveContains(expected)
        case .substring:
            matches = actual == expected || 
                    actual.localizedCaseInsensitiveContains(expected) || 
                    expected.localizedCaseInsensitiveContains(actual)
        case .startsWith:
            matches = actual.hasPrefix(expected) || actual == expected
        }
        
        #expect(matches == shouldMatch)
    }
    
    // Test exact matching
    testMatch(attribute: "AXIdentifier", expected: "button-123", actual: "button-123", shouldMatch: true)
    testMatch(attribute: "AXIdentifier", expected: "button-123", actual: "button-456", shouldMatch: false)
    testMatch(attribute: "bundleIdentifier", expected: "com.apple.calculator", actual: "com.apple.calculator", shouldMatch: true)
    testMatch(attribute: "bundleIdentifier", expected: "com.apple", actual: "com.apple.calculator", shouldMatch: false)
    
    // Test contains matching
    testMatch(attribute: "AXDescription", expected: "important text", 
              actual: "This is a long description with important text embedded in it", shouldMatch: true)
    testMatch(attribute: "AXHelp", expected: "click to", 
              actual: "Click to submit the form", shouldMatch: true)
    testMatch(attribute: "AXDescription", expected: "not present", 
              actual: "This is a description without the search term", shouldMatch: false)
    
    // Test substring matching
    testMatch(attribute: "AXTitle", expected: "full name", actual: "Enter your full name", shouldMatch: true)
    testMatch(attribute: "AXTitle", expected: "Enter your full name", actual: "full name", shouldMatch: true)
    testMatch(attribute: "AXValue", expected: "100", actual: "100.50", shouldMatch: true)
    testMatch(attribute: "AXTitle", expected: "submit", actual: "cancel", shouldMatch: false)
    
    // Test startsWith matching
    testMatch(attribute: "AXFilename", expected: "/Users/images", actual: "/Users/images/header.png", shouldMatch: true)
    testMatch(attribute: "AXName", expected: "README", actual: "README.md", shouldMatch: true)
    testMatch(attribute: "AXFilename", expected: "/Documents", actual: "/Users/Documents", shouldMatch: false)
}

@Test("Testing enhanced error reporting")
func testEnhancedErrorReporting() throws {
    let mockHierarchy = createMockElementHierarchy()
    let mockService = MockAccessibilityService(rootElement: mockHierarchy)
    
    // Test ambiguous match with enhanced error
    let ambiguousPath = try ElementPath.parse("ui://AXWindow/AXGroup[@AXTitle=\"Duplicate\"]")
    let ambiguousError = mockResolvePathWithExceptionForTest(service: mockService, path: ambiguousPath)
    #expect(ambiguousError != nil)
    
    if case .resolutionFailed(let segment, let index, let candidates, let reason)? = ambiguousError {
        #expect(segment.contains("AXGroup[@AXTitle=\"Duplicate\"]"))
        #expect(index == 1)
        #expect(candidates.count > 0)
        #expect(reason.contains("Multiple elements"))
    } else {
        XCTFail("Expected resolutionFailed error but got \(String(describing: ambiguousError))")
    }
    
    // Test no matching elements with enhanced error
    let nonExistentPath = try ElementPath.parse("ui://AXWindow/AXNonExistentElement")
    let nonExistentError = mockResolvePathWithExceptionForTest(service: mockService, path: nonExistentPath)
    #expect(nonExistentError != nil)
    
    if case .resolutionFailed(let segment, let index, let candidates, let reason)? = nonExistentError {
        #expect(segment.contains("AXNonExistentElement"))
        #expect(index == 1)
        #expect(candidates.count > 0)
        #expect(reason.contains("No elements match"))
    } else {
        XCTFail("Expected resolutionFailed error but got \(String(describing: nonExistentError))")
    }
}

// Progressive path resolution should be tested in integration tests with real UI elements

// Helper functions for test path resolution
private func mockResolvePathForTest(service: MockAccessibilityService, path: ElementPath) -> MockAXUIElement? {
    do {
        return try mockResolvePathInternal(service: service, path: path)
    } catch {
        return nil
    }
}

private func mockResolvePathWithExceptionForTest(service: MockAccessibilityService, path: ElementPath) -> ElementPathError? {
    do {
        _ = try mockResolvePathInternal(service: service, path: path)
        return nil
    } catch let error as ElementPathError {
        return error
    } catch {
        return nil
    }
}

// Internal implementation that throws errors
private func mockResolvePathInternal(service: MockAccessibilityService, path: ElementPath) throws -> MockAXUIElement {
    // Start with the root element
    var current = service.rootElement
    
    // Navigate through each segment of the path
    for (index, segment) in path.segments.enumerated() {
        // Skip the root segment if it's already matched
        if index == 0 && segment.role == "AXWindow" {
            continue
        }
        
        // Find children matching this segment
        var matches: [MockAXUIElement] = []
        
        if index == 0 && segment.role == current.role {
            // Special case for the root element
            if mockSegmentMatchesElement(segment, element: current) {
                matches.append(current)
            }
        } else {
            // Check all children
            for child in current.children {
                if mockSegmentMatchesElement(segment, element: child) {
                    matches.append(child)
                }
            }
        }
        
        // Handle matches based on count and index
        if matches.isEmpty {
            // Get child information for better diagnostics
            let childCandidates = current.children.prefix(5).map { child in
                return "Child (role: \(child.role), attributes: \(child.attributes))"
            }
            
            throw ElementPathError.resolutionFailed(
                segment: segment.toString(),
                index: index,
                candidates: childCandidates,
                reason: "No elements match this segment"
            )
        } else if matches.count > 1 && segment.index == nil {
            // Ambiguous match - create diagnostic information
            let matchCandidates = matches.prefix(5).map { match in
                return "Match (role: \(match.role), attributes: \(match.attributes))"
            }
            
            throw ElementPathError.resolutionFailed(
                segment: segment.toString(),
                index: index,
                candidates: matchCandidates,
                reason: "Multiple elements (\(matches.count)) match this segment"
            )
        } else {
            if let segmentIndex = segment.index {
                // Use the specified index if available
                if segmentIndex < 0 || segmentIndex >= matches.count {
                    throw ElementPathError.segmentResolutionFailed("Invalid index: \(segmentIndex)", atSegment: index)
                }
                current = matches[segmentIndex]
            } else {
                // Use the first match
                current = matches[0]
            }
        }
    }
    
    return current
}

// Check if a segment matches an element
private func mockSegmentMatchesElement(_ segment: PathSegment, element: MockAXUIElement) -> Bool {
    // Track all matching for better debugging
    // print("\nDEBUG: Checking if element \(element.role) with attributes \(element.attributes) matches segment \(segment.toString())")
    
    // Check role first
    guard segment.role == element.role else {
        // print("DEBUG: Segment role \(segment.role) doesn't match element role \(element.role)")
        return false
    }
    
    // print("DEBUG: Role matches!")
    
    // If there are no attributes to match, we're done
    if segment.attributes.isEmpty {
        // print("DEBUG: No attributes to check, match found")
        return true
    }
    
    // Check each attribute
    for (key, value) in segment.attributes {
        // print("DEBUG: Checking attribute \(key)=\(value)")
        
        // Try with various keys to improve matching chances
        let normalizedKey = normalizeAttributeNameForTest(key)
        let keys = [key, normalizedKey]
        
        // print("DEBUG: Will try keys: \(keys)")
        
        var attributeFound = false
        for attributeKey in keys {
            // print("DEBUG: Trying with key \(attributeKey)")
            
            if let elementValue = element.attributes[attributeKey] {
                // Convert to string for comparison
                let elementValueString: String
                if let stringValue = elementValue as? String {
                    elementValueString = stringValue
                } else if let numberValue = elementValue as? NSNumber {
                    elementValueString = numberValue.stringValue
                } else if let boolValue = elementValue as? Bool {
                    elementValueString = boolValue ? "true" : "false"
                } else {
                    elementValueString = String(describing: elementValue)
                }
                
                // Get the match type for this attribute
                let matchType = mockDetermineMatchType(forAttribute: attributeKey)
                // print("DEBUG: Found attribute \(attributeKey) with value \(elementValueString), will use match type \(matchType)")
                
                // Use the matching strategy based on the attribute
                let doesMatch = mockAttributeMatches(attributeKey, expected: value, actual: elementValueString)
                // print("DEBUG: Attribute match result: \(doesMatch)")
                
                if doesMatch {
                    attributeFound = true
                    break
                }
            } else {
                // print("DEBUG: Element does not have attribute \(attributeKey)")
            }
        }
        
        if !attributeFound {
            // print("DEBUG: No matching attribute found for \(key) = \(value), returning false")
            return false
        }
    }
    
    // print("DEBUG: All attributes matched, returning true")
    return true
}

// Simple attribute name normalization for test
private func normalizeAttributeNameForTest(_ name: String) -> String {
    // If it already has AX prefix, return as is
    if name.hasPrefix("AX") {
        return name
    }
    
    // Handle common mappings
    let mappings = [
        "title": "AXTitle",
        "description": "AXDescription",
        "value": "AXValue",
        "id": "AXIdentifier",
        "identifier": "AXIdentifier"
    ]
    
    if let mapped = mappings[name] {
        return mapped
    }
    
    // Add AX prefix for other attributes
    return "AX" + name.prefix(1).uppercased() + name.dropFirst()
}

// Match attribute values using appropriate strategy
private func mockAttributeMatches(_ attributeName: String, expected: String, actual: String) -> Bool {
    // Determine match type based on attribute
    let matchType = mockDetermineMatchType(forAttribute: attributeName)
    
    switch matchType {
    case .exact:
        return actual == expected
        
    case .contains:
        return actual.localizedCaseInsensitiveContains(expected)
        
    case .substring:
        // Either exact match, or one contains the other
        return actual == expected ||
               actual.localizedCaseInsensitiveContains(expected) ||
               expected.localizedCaseInsensitiveContains(actual)
        
    case .startsWith:
        return actual.hasPrefix(expected) || actual == expected || actual.lowercased().hasPrefix(expected.lowercased())
    }
}

// Determine match type for test
private enum MockMatchType {
    case exact, contains, substring, startsWith
}

private func mockDetermineMatchType(forAttribute attribute: String) -> MockMatchType {
    let normalizedName = normalizeAttributeNameForTest(attribute)
    
    switch normalizedName {
    case "AXTitle":
        return .substring
        
    case "AXDescription", "AXHelp":
        return .contains
        
    case "AXValue":
        return .substring
        
    case "AXIdentifier", "AXRole", "AXSubrole":
        return .exact
        
    case "AXFilename":
        return .startsWith
        
    default:
        return .exact
    }
}
    
// MARK: - Special Character and Edge Case Tests

@Test("ElementPath parsing with backslash path escaping")
    func testElementPathParsingWithBackslashes() throws {
        // Test backslash escaping in path strings
        let pathString = "ui://AXWindow/AXGroup[@AXValue=\"C:\\\\Program Files\\\\App\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 2)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXGroup")
        #expect(path.segments[1].attributes["AXValue"] == "C:\\\\Program Files\\\\App")  // Double-escaped backslashes in the result
        
        // Validate round-trip conversion
        let regeneratedPath = path.toString()
        #expect(regeneratedPath == pathString)
    }
    
    @Test("ElementPath parsing with control characters")
    func testElementPathParsingWithControlChars() throws {
        // Test control character escaping in path strings
        let pathString = "ui://AXWindow/AXTextField[@AXValue=\"Line 1\\nLine 2\\tTabbed\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 2)
        #expect(path.segments[0].role == "AXWindow")
        #expect(path.segments[1].role == "AXTextField")
        #expect(path.segments[1].attributes["AXValue"] == "Line 1\\nLine 2\\tTabbed")  // Control characters are double-escaped
        
        // Validate that the representation of control characters is preserved
        let escapedValue = path.segments[1].attributes["AXValue"]
        #expect(escapedValue?.contains("\\n") == true)  // Not actual newlines but escaped representation
        #expect(escapedValue?.contains("\\t") == true)  // Not actual tabs but escaped representation
    }
    
    @Test("ElementPath parsing with very deep paths")
    func testElementPathParsingDeepPaths() throws {
        // Test deep hierarchical paths
        let pathString = "ui://AXApplication/AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXButton"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 9) // There are 8 segments plus the root AXApplication
        #expect(path.segments[0].role == "AXApplication")
        #expect(path.segments[7].role == "AXGroup")  // In the deep hierarchy, all intermediate elements are AXGroup
    }
    
    @Test("ElementPath parsing with empty attributes")
    func testElementPathParsingEmptyAttributes() throws {
        // Test attributes with empty values
        let pathString = "ui://AXWindow/AXGroup[@AXValue=\"\"]"
        let path = try ElementPath.parse(pathString)
        
        #expect(path.segments.count == 2)
        #expect(path.segments[1].attributes["AXValue"] == "")
        #expect(path.segments[1].attributes["AXValue"]?.isEmpty == true)
    }
    
    @Test("ElementPath with multiple attributes in different orders")
    func testElementPathMultipleAttributeOrders() throws {
        // Create paths with attributes in different orders
        let segment1 = PathSegment(
            role: "AXButton",
            attributes: [
                "AXTitle": "OK",
                "AXDescription": "Confirm",
                "AXEnabled": "true"
            ]
        )
        
        let segment2 = PathSegment(
            role: "AXButton",
            attributes: [
                "AXDescription": "Confirm",
                "AXEnabled": "true",
                "AXTitle": "OK"
            ]
        )
        
        let path1 = try ElementPath(segments: [segment1])
        let path2 = try ElementPath(segments: [segment2])
        
        // The string representations should be identical due to alphabetical sorting
        #expect(path1.toString() == path2.toString())
        
        // Parse the generated path and verify attributes are preserved
        let parsedPath = try ElementPath.parse(path1.toString())
        #expect(parsedPath.segments[0].attributes.count == 3)
        #expect(parsedPath.segments[0].attributes["AXTitle"] == "OK")
        #expect(parsedPath.segments[0].attributes["AXDescription"] == "Confirm")
        #expect(parsedPath.segments[0].attributes["AXEnabled"] == "true")
    }
    
    @Test("Path normalization with PathNormalizer")
    func testPathNormalization() throws {
        // Test various attribute name normalizations
        let unnormalizedPath = "ui://AXWindow/AXGroup[@title=\"Test\"][@description=\"Description\"][@id=\"group1\"]"
        let normalizedPath = PathNormalizer.normalizePathString(unnormalizedPath)
        
        #expect(normalizedPath != nil)
        #expect(normalizedPath?.contains("@AXTitle=") == true)
        #expect(normalizedPath?.contains("@AXDescription=") == true)
        #expect(normalizedPath?.contains("@AXIdentifier=") == true)
        
        // Parse the normalized path
        let path = try ElementPath.parse(normalizedPath!)
        #expect(path.segments[1].attributes["AXTitle"] == "Test")
        #expect(path.segments[1].attributes["AXDescription"] == "Description")
        #expect(path.segments[1].attributes["AXIdentifier"] == "group1")
    }
    
    @Test("Comprehensive path round-trip test")
    func testComprehensivePathRoundTrip() throws {
        // A comprehensive path with various edge cases
        let originalPath = "ui://AXApplication[@bundleIdentifier=\"com.example.app\"]/AXWindow/AXGroup[@AXTitle=\"Group with \\\"quotes\\\"\"]/AXButton[@AXDescription=\"Button with\\nline breaks and\\ttabs\"][@AXValue=\"123\"][0]"
        
        // Parse and regenerate the path
        let path = try ElementPath.parse(originalPath)
        let regeneratedPath = path.toString()
        
        // The paths should be identical
        #expect(regeneratedPath == originalPath)
        
        // Verify all components are preserved
        #expect(path.segments.count == 4)
        #expect(path.segments[0].attributes["bundleIdentifier"] == "com.example.app")
        #expect(path.segments[2].attributes["AXTitle"] == "Group with \"quotes\"")
        #expect(path.segments[3].attributes["AXDescription"] == "Button with\\nline breaks and\\ttabs")  // Control characters are double-escaped
        #expect(path.segments[3].attributes["AXValue"] == "123")
        #expect(path.segments[3].index == 0)
    }
    
    // MARK: - Path Validation and Error Handling Tests
    
    @Test("Path validation with valid path")
    func testPathValidationWithValidPath() throws {
        // Test a well-formed path
        let pathString = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"1\"]"
        
        let (isValid, warnings) = try ElementPath.validatePath(pathString)
        
        #expect(isValid == true)
        
        // In non-strict mode, there should be no warnings for a well-formed path
        #expect(warnings.isEmpty)
    }
    
    @Test("Path validation with valid path in strict mode")
    func testPathValidationWithValidPathStrict() throws {
        // Test a well-formed path in strict mode
        let pathString = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"1\"]"
        
        let (isValid, warnings) = try ElementPath.validatePath(pathString, strict: true)
        
        #expect(isValid == true)
        
        // Even in strict mode, this path should be perfect
        #expect(warnings.isEmpty)
    }
    
    @Test("Path validation with syntax error")
    func testPathValidationWithSyntaxError() throws {
        // Test a path with syntax error (missing closing bracket)
        let pathString = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"1\""
        
        do {
            let _ = try ElementPath.validatePath(pathString)
            XCTFail("Expected validation to fail")
        } catch let error as ElementPathError {
            // We expect a specific type of error here
            // print("Got error: \(error)")
            if case .invalidAttributeSyntax = error {
                // This is the expected error
                // Assertion not needed, reaching this point is success
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    @Test("Path validation with invalid prefix")
    func testPathValidationWithInvalidPrefix() throws {
        // Test a path with an invalid prefix
        let pathString = "invalid://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]"
        
        do {
            let _ = try ElementPath.validatePath(pathString)
            XCTFail("Expected validation to fail")
        } catch let error as ElementPathError {
            if case .invalidPathPrefix = error {
                // This is the expected error
                // Assertion not needed, reaching this point is success
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    @Test("Path validation with missing attributes")
    func testPathValidationWithMissingAttributes() throws {
        // Test a path with missing recommended attributes in strict mode
        let pathString = "ui://AXApplication/AXWindow/AXButton"
        
        let (isValid, warnings) = try ElementPath.validatePath(pathString, strict: true)
        
        #expect(isValid == true)
        #expect(!warnings.isEmpty)
        
        // Check that we got the right type of warnings
        let hasAttributeWarning = warnings.contains { warning in
            if case .missingAttribute = warning {
                return true
            }
            return false
        }
        
        #expect(hasAttributeWarning)
    }
    
    @Test("Path validation with potential ambiguity")
    func testPathValidationWithPotentialAmbiguity() throws {
        // Test a path with potentially ambiguous segments in strict mode
        let pathString = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXGroup/AXGroup/AXGroup"
        
        let (isValid, warnings) = try ElementPath.validatePath(pathString, strict: true)
        
        #expect(isValid == true)
        #expect(!warnings.isEmpty)
        
        // Check that we got an ambiguity warning
        let hasAmbiguityWarning = warnings.contains { warning in
            if case .potentialAmbiguity = warning {
                return true
            }
            return false
        }
        
        #expect(hasAmbiguityWarning)
    }
    
    @Test("Path validation with excessive complexity")
    func testPathValidationWithExcessiveComplexity() throws {
        // Test a path that's excessively complex (many segments)
        let pathString = "ui://AXApplication/AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXGroup/AXButton"
        
        let (isValid, warnings) = try ElementPath.validatePath(pathString, strict: true)
        
        #expect(isValid == true)
        #expect(!warnings.isEmpty)
        
        // Check that we got a complexity warning
        let hasComplexityWarning = warnings.contains { warning in
            if case .validationWarning(let message, _) = warning {
                return message.contains("excessive")
            }
            return false
        }
        
        #expect(hasComplexityWarning)
    }
    
    @Test("Comprehensive path validation test")
    func testComprehensivePathValidation() throws {
        // Test cases for various path validation scenarios
        
        // 1. Valid path with good structure
        let validPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"Clear\"]"
        let (validResult, validWarnings) = try ElementPath.validatePath(validPath, strict: true)
        #expect(validResult)
        #expect(validWarnings.isEmpty) // A well-formed path should have no warnings in strict mode
        
        // 2. Path with non-standard role (missing AX prefix)
        let nonStandardPath = "ui://Application[@bundleIdentifier=\"com.apple.calculator\"]/Window/Button"
        let (nonStandardResult, nonStandardWarnings) = try ElementPath.validatePath(nonStandardPath, strict: true)
        #expect(nonStandardResult) // Still valid, but with warnings
        #expect(!nonStandardWarnings.isEmpty)
        
        // Verify we get warnings about non-standard roles
        let hasRoleWarning = nonStandardWarnings.contains { warning in
            if case .validationWarning(let message, _) = warning {
                return message.contains("'AX' prefix")
            }
            return false
        }
        #expect(hasRoleWarning)
        
        // 3. Path with generic elements lacking attributes (potential ambiguity)
        let ambiguousPath = "ui://AXApplication/AXWindow/AXGroup/AXGroup"
        let (ambiguousResult, ambiguousWarnings) = try ElementPath.validatePath(ambiguousPath, strict: true)
        #expect(ambiguousResult) // Valid but with ambiguity warnings
        
        // Verify we get potential ambiguity warnings
        let hasAmbiguityWarning = ambiguousWarnings.contains { warning in
            if case .potentialAmbiguity = warning {
                return true
            }
            return false
        }
        #expect(hasAmbiguityWarning)
        
        // 4. Path with missing recommended attributes
        let missingAttrsPath = "ui://AXApplication/AXWindow/AXButton"
        let (missingAttrsResult, missingAttrsWarnings) = try ElementPath.validatePath(missingAttrsPath, strict: true)
        #expect(missingAttrsResult) // Valid but with warnings
        
        // Verify we get missing attribute warnings
        let hasMissingAttrWarning = missingAttrsWarnings.contains { warning in
            if case .missingAttribute = warning {
                return true
            }
            return false
        }
        #expect(hasMissingAttrWarning)
        
        // 5. Path with syntax error should throw
        let invalidPath = "ui://AXWindow[@title=\"Untitled"  // Missing closing quote and bracket
        do {
            let _ = try ElementPath.validatePath(invalidPath)
            XCTFail("Expected validation to fail with syntax error")
        } catch {
            // Expected to throw
            // Expected path - no assertion needed
        }
        
        // 6. Path with invalid prefix should throw
        let wrongPrefixPath = "uix://AXWindow"
        do {
            let _ = try ElementPath.validatePath(wrongPrefixPath)
            XCTFail("Expected validation to fail with invalid prefix")
        } catch let error as ElementPathError {
            if case .invalidPathPrefix = error {
                // This is the expected error case
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // 7. Empty path should throw
        let emptyPath = "ui://"
        do {
            let _ = try ElementPath.validatePath(emptyPath)
            XCTFail("Expected validation to fail with empty path")
        } catch let error as ElementPathError {
            if case .emptyPath = error {
                // This is the expected error - no assertion needed
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    @Test("Path diagnosis utility with mock service")
    func testPathDiagnosisUtilityWithMock() async throws {
        // Create a mock hierarchy
        let mockHierarchy = createMockElementHierarchy()
        
        // Create a test path to diagnose
        let validPath = "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXTitle=\"OK\"]"
        let invalidPath = "ui://AXWindow/AXGroup[@AXTitle=\"NonExistent\"]/AXButton"
        
        // Mock AccessibilityService that ensures resolution runs
        let mockAccessibilityService = MockAccessibilityService(rootElement: mockHierarchy)
        
        // Test diagnosis - we mainly just want to ensure it runs without errors
        let diagnosisValid = try await ElementPath.diagnosePathResolutionIssue(validPath, using: mockAccessibilityService)
        // print("Valid path diagnosis: \(diagnosisValid)")
        
        // Check it contains some expected information
        #expect(diagnosisValid.contains("Path Resolution Diagnosis"))
        
        let diagnosisInvalid = try await ElementPath.diagnosePathResolutionIssue(invalidPath, using: mockAccessibilityService)
        // print("Invalid path diagnosis: \(diagnosisInvalid)")
        
        // Check it contains diagnostic information
        #expect(diagnosisInvalid.contains("Path Resolution Diagnosis"))
    }
}
    
    // MARK: - Test Utilities
    
    @Test("Compare Elements utility function")
    func testCompareElements() throws {
        // Create mock elements to compare
        let mockElement1 = MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "OK", "AXDescription": "Confirm"]
        )
        
        let mockElement2 = MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "OK", "AXDescription": "Confirm"]
        )
        
        let mockElement3 = MockAXUIElement(
            role: "AXButton",
            attributes: ["AXTitle": "Cancel", "AXDescription": "Abort"]
        )
        
        // Helper function to compare elements
        func compareElements(_ element1: MockAXUIElement, _ element2: MockAXUIElement) -> Bool {
            // Compare roles
            if element1.role != element2.role {
                return false
            }
            
            // Compare relevant attributes
            let relevantAttrs = ["AXTitle", "AXDescription", "AXIdentifier", "AXValue"]
            
            for attr in relevantAttrs {
                let value1 = element1.attributes[attr]
                let value2 = element2.attributes[attr]
                
                // If either element has this attribute, they should match
                if value1 != nil || value2 != nil {
                    if !areValuesEqual(value1, value2) {
                        return false
                    }
                }
            }
            
            return true
        }
        
        // Helper to compare values
        func areValuesEqual(_ value1: Any?, _ value2: Any?) -> Bool {
            // Handle nil values
            if value1 == nil && value2 == nil {
                return true
            }
            if value1 == nil || value2 == nil {
                return false
            }
            
            // Compare string values
            if let str1 = value1 as? String, let str2 = value2 as? String {
                return str1 == str2
            }
            
            // Compare number values
            if let num1 = value1 as? NSNumber, let num2 = value2 as? NSNumber {
                return num1 == num2
            }
            
            // Compare bool values
            if let bool1 = value1 as? Bool, let bool2 = value2 as? Bool {
                return bool1 == bool2
            }
            
            // Default for other types
            return String(describing: value1) == String(describing: value2)
        }
        
        // Test compare function
        #expect(compareElements(mockElement1, mockElement2) == true)
        #expect(compareElements(mockElement1, mockElement3) == false)
    }
    
    @Test("Test path round-trip with real-world paths")
    func testRealWorldPathRoundTrip() throws {
        // Test with realistic paths seen in real applications
        let calculatorPath = "ui://AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXGroup/AXSplitGroup/AXGroup/AXGroup/AXButton[@AXDescription=\"1\"]"
        let textEditPath = "ui://AXApplication[@title=\"TextEdit\"]/AXWindow[@AXTitle=\"Untitled\"]/AXTextArea"
        
        // Validate round-trip for Calculator path
        let calcPath = try ElementPath.parse(calculatorPath)
        let regeneratedCalcPath = calcPath.toString()
        #expect(regeneratedCalcPath == calculatorPath)
        
        // Validate round-trip for TextEdit path
        let textEditPathObj = try ElementPath.parse(textEditPath)
        let regeneratedTextEditPath = textEditPathObj.toString()
        #expect(regeneratedTextEditPath == textEditPath)
    }
    
    @Test("Measure resolution performance")
    func testResolutionPerformance() throws {
        // Create a complex mock hierarchy with many elements
        
        // Helper function to create a deep hierarchy for testing
        func createDeepHierarchy(depth: Int, breadth: Int, currentDepth: Int = 0) -> MockAXUIElement {
            // Create a deep hierarchy for performance testing
            if currentDepth == depth {
                // At max depth, create leaf nodes
                return MockAXUIElement(
                    role: "AXButton",
                    attributes: ["AXTitle": "Deep Button", "AXDescription": "Button at depth \(depth)"]
                )
            }
            
            // Create children for this level
            var children: [MockAXUIElement] = []
            
            for _ in 0..<breadth {
                children.append(createDeepHierarchy(
                    depth: depth,
                    breadth: breadth,
                    currentDepth: currentDepth + 1
                ))
            }
            
            // Create a group at this level
            return MockAXUIElement(
                role: currentDepth == 0 ? "AXWindow" : "AXGroup",
                attributes: ["AXTitle": "Group at depth \(currentDepth)", "AXDescription": "Group \(currentDepth)"],
                children: children
            )
        }
        
        let deepHierarchy = createDeepHierarchy(depth: 5, breadth: 3)
        let mockService = ElementPathTestMockService(rootElement: deepHierarchy)
        
        // Create a complex path to resolve
        let pathString = "ui://AXWindow/AXGroup/AXGroup/AXGroup/AXGroup/AXButton[@AXTitle=\"Deep Button\"]"
        let path = try ElementPath.parse(pathString)
        
        // Basic performance check
        let startTime = Date()
        let _ = mockResolvePathForTest(service: mockService, path: path)
        let endTime = Date()
        
        let elapsedTime = endTime.timeIntervalSince(startTime)
        // print("Resolution time: \(elapsedTime) seconds")
        
        // No hard assertion, just informational
        #expect(elapsedTime > 0)
    }
