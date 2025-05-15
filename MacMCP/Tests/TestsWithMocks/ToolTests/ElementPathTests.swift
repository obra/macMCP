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
}