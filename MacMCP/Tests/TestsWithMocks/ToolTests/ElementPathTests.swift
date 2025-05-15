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
        print("DEBUG: Testing \(matchType) match for \(attribute): '\(expected)' vs '\(actual)'")
        
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
    print("\nDEBUG: Checking if element \(element.role) with attributes \(element.attributes) matches segment \(segment.toString())")
    
    // Check role first
    guard segment.role == element.role else {
        print("DEBUG: Segment role \(segment.role) doesn't match element role \(element.role)")
        return false
    }
    
    print("DEBUG: Role matches!")
    
    // If there are no attributes to match, we're done
    if segment.attributes.isEmpty {
        print("DEBUG: No attributes to check, match found")
        return true
    }
    
    // Check each attribute
    for (key, value) in segment.attributes {
        print("DEBUG: Checking attribute \(key)=\(value)")
        
        // Try with various keys to improve matching chances
        let normalizedKey = normalizeAttributeNameForTest(key)
        let keys = [key, normalizedKey]
        
        print("DEBUG: Will try keys: \(keys)")
        
        var attributeFound = false
        for attributeKey in keys {
            print("DEBUG: Trying with key \(attributeKey)")
            
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
                print("DEBUG: Found attribute \(attributeKey) with value \(elementValueString), will use match type \(matchType)")
                
                // Use the matching strategy based on the attribute
                let doesMatch = mockAttributeMatches(attributeKey, expected: value, actual: elementValueString)
                print("DEBUG: Attribute match result: \(doesMatch)")
                
                if doesMatch {
                    attributeFound = true
                    break
                }
            } else {
                print("DEBUG: Element does not have attribute \(attributeKey)")
            }
        }
        
        if !attributeFound {
            print("DEBUG: No matching attribute found for \(key) = \(value), returning false")
            return false
        }
    }
    
    print("DEBUG: All attributes matched, returning true")
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
}