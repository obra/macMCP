// ABOUTME: ResourceURIParserTests.swift
// ABOUTME: Unit tests for the ResourceURIParser class.

import Foundation
import Testing

@testable import MacMCP

@Suite(.serialized) struct ResourceURIParserTests {
  @Test("Test parsing simple URI with scheme") func testParseSimpleURIWithScheme() throws {
    let uri = "macos://applications"
    let components = try ResourceURIParser.parse(uri)
    #expect(components.scheme == "macos", "Scheme should be 'macos'")
    #expect(components.path == "/applications", "Path should be '/applications'")
    #expect(components.queryParameters.isEmpty, "Query parameters should be empty")
    #expect(
      components.pathComponents == ["applications"], "Path components should be ['applications']")
  }
  @Test("Test parsing URI with path components and scheme")
  func testParseURIWithPathComponentsAndScheme() throws {
    let uri = "macos://applications/com.apple.TextEdit/windows"
    let components = try ResourceURIParser.parse(uri)
    #expect(components.scheme == "macos", "Scheme should be 'macos'")
    #expect(
      components.path == "/applications/com.apple.TextEdit/windows",
      "Path should be '/applications/com.apple.TextEdit/windows'"
    )
    #expect(components.queryParameters.isEmpty, "Query parameters should be empty")
    #expect(
      components.pathComponents == ["applications", "com.apple.TextEdit", "windows"],
      "Path components should be ['applications', 'com.apple.TextEdit', 'windows']"
    )
  }
  @Test("Test parsing URI without scheme") func testParseURIWithoutScheme() throws {
    let uri = "applications/com.apple.TextEdit/windows"
    let components = try ResourceURIParser.parse(uri)
    #expect(components.scheme == "macos", "Scheme should be 'macos'")
    #expect(
      components.path == "/applications/com.apple.TextEdit/windows",
      "Path should be '/applications/com.apple.TextEdit/windows'"
    )
    #expect(components.queryParameters.isEmpty, "Query parameters should be empty")
    #expect(
      components.pathComponents == ["applications", "com.apple.TextEdit", "windows"],
      "Path components should be ['applications', 'com.apple.TextEdit', 'windows']"
    )
  }
  @Test("Test parsing URI with query parameters") func testParseURIWithQueryParameters() throws {
    let uri = "macos://applications/com.apple.TextEdit/windows?includeMinimized=true&maxDepth=3"
    let components = try ResourceURIParser.parse(uri)
    #expect(components.scheme == "macos", "Scheme should be 'macos'")
    #expect(
      components.path == "/applications/com.apple.TextEdit/windows",
      "Path should be '/applications/com.apple.TextEdit/windows'"
    )
    #expect(components.queryParameters.count == 2, "Should have 2 query parameters")
    #expect(
      components.queryParameters["includeMinimized"] == "true", "includeMinimized should be 'true'")
    #expect(components.queryParameters["maxDepth"] == "3", "maxDepth should be '3'")
  }
  @Test("Test parsing URI with leading slash") func testParseURIWithLeadingSlash() throws {
    let uri = "macos:///applications/com.apple.TextEdit/windows"
    let components = try ResourceURIParser.parse(uri)
    #expect(components.scheme == "macos", "Scheme should be 'macos'")
    #expect(
      components.path == "/applications/com.apple.TextEdit/windows",
      "Path should be '/applications/com.apple.TextEdit/windows'"
    )
    #expect(
      components.pathComponents == ["applications", "com.apple.TextEdit", "windows"],
      "Path components should be ['applications', 'com.apple.TextEdit', 'windows']"
    )
  }
  @Test("Test extracting parameters from URI with pattern") func testExtractParameters() throws {
    // Create a mock handler with a pattern
    let handler = MockResourceHandler(
      uriPattern: "macos://applications/{bundleId}/windows",
      name: "Windows",
      description: "Application windows"
    )
    // Test parameter extraction

    // Test with a matching URI
    let uri = "macos://applications/com.apple.TextEdit/windows"
    // Test with URI that has a scheme

    do {
      // Parse the URI into components
      _ = try ResourceURIParser.parse(uri)
      let params = try handler.extractParameters(from: uri, pattern: handler.uriPattern)
      // Extract parameters

      #expect(params.count == 1, "Should extract 1 parameter")
      #expect(params["bundleId"] == "com.apple.TextEdit", "bundleId should be 'com.apple.TextEdit'")
    } catch {
      // Handle any errors
      throw error
    }
    // Test with a URI without scheme
    let uriWithoutScheme = "applications/com.apple.TextEdit/windows"
    // Test with URI that doesn't have a scheme

    do {
      // Parse the URI without scheme into components
      _ = try ResourceURIParser.parse(uriWithoutScheme)
      let paramsWithoutScheme = try handler.extractParameters(
        from: uriWithoutScheme, pattern: handler.uriPattern)
      // Extract parameters from URI without scheme

      #expect(paramsWithoutScheme.count == 1, "Should extract 1 parameter")
      #expect(
        paramsWithoutScheme["bundleId"] == "com.apple.TextEdit",
        "bundleId should be 'com.apple.TextEdit'")
    } catch {
      // Handle any errors
      throw error
    }
  }
  @Test("Test formatting URI from path and query parameters") func testFormatURI() {
    let path = "/applications/com.apple.TextEdit/windows"
    let queryParams = ["includeMinimized": "true", "maxDepth": "3"]
    let uri = ResourceURIParser.formatURI(path: path, queryParams: queryParams)
    #expect(uri.hasPrefix("macos://"), "URI should start with 'macos://'")
    #expect(uri.contains("/applications/com.apple.TextEdit/windows"), "URI should contain the path")
    #expect(uri.contains("includeMinimized=true"), "URI should contain the query parameters")
    #expect(uri.contains("maxDepth=3"), "URI should contain the query parameters")
  }
  // Mock resource handler for testing
  private struct MockResourceHandler: ResourceHandler {
    let uriPattern: String
    let name: String
    let description: String
    func handleRead(uri: String, components: ResourceURIComponents) async throws -> (
      ResourcesRead.ResourceContent, ResourcesRead.ResourceMetadata?
    ) { return (.text("{}"), ResourcesRead.ResourceMetadata(mimeType: "application/json")) }
  }
}
