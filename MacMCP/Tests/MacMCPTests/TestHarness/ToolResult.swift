// ABOUTME: This file defines the ToolResult and UIStateResult classes for test verification.
// ABOUTME: It provides parsing and inspection of tool outputs.

import Foundation
import MCP

/// Generic result object from a tool invocation
public struct ToolResult {
    /// The raw content returned by the tool
    public let content: [Tool.Content]
    
    /// Create a new tool result
    /// - Parameter content: The tool content
    public init(content: [Tool.Content]) {
        self.content = content
    }
    
    /// Create a new tool result from a single content item
    /// - Parameter content: The tool content
    public init(content: Tool.Content) {
        self.content = [content]
    }
    
    /// Get the text content if available
    /// - Returns: Text content or nil
    public func getTextContent() -> String? {
        for item in content {
            if case .text(let text) = item {
                return text
            }
        }
        return nil
    }
    
    /// Get the image data if available
    /// - Returns: Image data as base64 string or nil
    public func getImageData() -> (data: String, mimeType: String)? {
        for item in content {
            if case .image(let data, let mimeType, _) = item {
                return (data: data, mimeType: mimeType)
            }
        }
        return nil
    }
    
    /// Check if the result is empty
    /// - Returns: True if there's no content
    public var isEmpty: Bool {
        return content.isEmpty
    }
    
    /// Get the first content item
    /// - Returns: First content item or nil
    public var first: Tool.Content? {
        return content.first
    }
    
    /// Number of content items
    public var count: Int {
        return content.count
    }
}

/// Helper function to parse a UI element from JSON
private func parseUIElement(from dict: [String: Any]) throws -> UIElementRepresentation {
    // Extract required fields
    guard let identifier = dict["identifier"] as? String else {
        throw NSError(
            domain: "UIStateResult",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Element missing identifier"]
        )
    }
    
    guard let role = dict["role"] as? String else {
        throw NSError(
            domain: "UIStateResult",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Element missing role"]
        )
    }
    
    // Extract optional fields
    let title = dict["title"] as? String
    let value = dict["value"] as? String
    let description = dict["description"] as? String
    
    // Extract frame
    let frame: CGRect
    if let frameDict = dict["frame"] as? [String: Any],
       let x = frameDict["x"] as? CGFloat,
       let y = frameDict["y"] as? CGFloat,
       let width = frameDict["width"] as? CGFloat,
       let height = frameDict["height"] as? CGFloat {
        frame = CGRect(x: x, y: y, width: width, height: height)
    } else {
        frame = .zero
    }
    
    // Extract capabilities
    var capabilities: [String: Bool] = [:]
    if let capsDict = dict["capabilities"] as? [String: Bool] {
        capabilities = capsDict
    }
    
    // Extract actions
    var actions: [String] = []
    if let actionsArray = dict["actions"] as? [String] {
        actions = actionsArray
    }
    
    // Recursively parse children
    var children: [UIElementRepresentation] = []
    if let childrenArray = dict["children"] as? [[String: Any]] {
        for childDict in childrenArray {
            children.append(try parseUIElement(from: childDict))
        }
    }
    
    return UIElementRepresentation(
        identifier: identifier,
        role: role,
        title: title,
        value: value,
        description: description,
        frame: frame,
        children: children,
        capabilities: capabilities,
        actions: actions
    )
}

/// Result specifically from the UIStateTool
public class UIStateResult {
    /// The elements in the UI state
    public let elements: [UIElementRepresentation]
    
    /// The raw UI state result
    public let rawContent: [Tool.Content]
    
    /// Create a new UI state result
    /// - Parameter rawContent: The raw tool output
    public init(rawContent: [Tool.Content]) throws {
        self.rawContent = rawContent
        
        // Extract the JSON text from the content
        guard let jsonText = ToolResult(content: rawContent).getTextContent() else {
            throw NSError(
                domain: "UIStateResult",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No text content found in UIStateTool result"]
            )
        }
        
        // Parse the JSON
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(
                domain: "UIStateResult",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert text to data"]
            )
        }
        
        do {
            // Parse as an array of element dictionaries
            let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
            guard let elementDicts = jsonArray else {
                throw NSError(
                    domain: "UIStateResult",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "JSON is not an array of dictionaries"]
                )
            }
            
            // Initialize elements first to avoid self capture in closure
            var parsedElements: [UIElementRepresentation] = []
            for dict in elementDicts {
                parsedElements.append(try parseUIElement(from: dict))
            }
            
            self.elements = parsedElements
        } catch {
            throw NSError(
                domain: "UIStateResult",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse UI state JSON: \(error.localizedDescription)"]
            )
        }
    }
    
    /// Find an element matching the criteria
    /// - Parameter criteria: The criteria to match
    /// - Returns: The first matching element or nil
    public func findElement(matching criteria: ElementCriteria) -> UIElementRepresentation? {
        func search(in elements: [UIElementRepresentation]) -> UIElementRepresentation? {
            for element in elements {
                if criteria.matches(element) {
                    return element
                }
                
                if let found = search(in: element.children) {
                    return found
                }
            }
            return nil
        }
        
        return search(in: elements)
    }
    
    /// Find all elements matching the criteria
    /// - Parameter criteria: The criteria to match
    /// - Returns: Array of matching elements
    public func findElements(matching criteria: ElementCriteria) -> [UIElementRepresentation] {
        var results: [UIElementRepresentation] = []
        
        func search(in elements: [UIElementRepresentation]) {
            for element in elements {
                if criteria.matches(element) {
                    results.append(element)
                }
                
                search(in: element.children)
            }
        }
        
        search(in: elements)
        return results
    }
    
    /// Check if an element matching the criteria exists
    /// - Parameter criteria: The criteria to match
    /// - Returns: True if a matching element exists
    public func hasElement(matching criteria: ElementCriteria) -> Bool {
        return findElement(matching: criteria) != nil
    }
    
    /// Count elements matching the criteria
    /// - Parameter criteria: The criteria to match
    /// - Returns: Number of matching elements
    public func countElements(matching criteria: ElementCriteria) -> Int {
        return findElements(matching: criteria).count
    }
}