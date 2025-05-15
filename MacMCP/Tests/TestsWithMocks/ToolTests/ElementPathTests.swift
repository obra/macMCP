import XCTest
import Testing
import Foundation

@testable import MacMCP

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
    
    // Mock AccessibilityService for testing path resolution
    class MockAccessibilityService {
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
            throw ElementPathError.noMatchingElements(segment.toString(), atSegment: index)
        } else if matches.count > 1 && segment.index == nil {
            // Ambiguous match
            throw ElementPathError.ambiguousMatch(segment.toString(), matchCount: matches.count, atSegment: index)
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
    // Check role first
    guard segment.role == element.role else {
        return false
    }
    
    // Check each attribute
    for (key, value) in segment.attributes {
        guard let elementValue = element.attributes[key] else {
            return false
        }
        
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
        
        // Compare values
        if elementValueString != value {
            return false
        }
    }
    
    return true
}
}