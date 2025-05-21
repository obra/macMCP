// ABOUTME: ResourceTemplates.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation
import MCP

/// Factory for creating resource templates
public struct ResourceTemplateFactory {
    /// Create templates for all supported resource types
    /// - Returns: Array of resource templates
    public static func createTemplates() -> [ListResourceTemplates.Template] {
        [
            createUIElementTemplate(),
            createApplicationMenusTemplate(),
            createApplicationWindowsTemplate()
        ]
    }
    
    /// Create a template for UI elements
    /// - Returns: A UI element resource template
    private static func createUIElementTemplate() -> ListResourceTemplates.Template {
        ListResourceTemplates.Template(
            id: "macos://ui/{path}",
            name: "UI Element",
            description: "Access a UI element by path",
            parameters: [
                ListResourceTemplates.Parameter(
                    name: "path",
                    description: "The path to the UI element following ElementPath syntax",
                    type: "string",
                    required: true,
                    enumValues: ["AXApplication[@bundleIdentifier=\"com.apple.finder\"]", 
                                "AXApplication[@bundleIdentifier=\"com.apple.calculator\"]/AXWindow/AXButton[@AXTitle=\"1\"]"]
                ),
                ListResourceTemplates.Parameter(
                    name: "maxDepth",
                    description: "Maximum depth of children to include (default: 5)",
                    type: "integer",
                    required: false
                ),
                ListResourceTemplates.Parameter(
                    name: "interactable",
                    description: "Set to true to return an array of all interactable elements in the tree",
                    type: "boolean",
                    required: false
                ),
                ListResourceTemplates.Parameter(
                    name: "limit",
                    description: "Maximum number of elements to return when interactable=true (default: 100)",
                    type: "integer",
                    required: false
                )
            ]
        )
    }
    
    /// Create a template for application menus
    /// - Returns: An application menus resource template
    private static func createApplicationMenusTemplate() -> ListResourceTemplates.Template {
        ListResourceTemplates.Template(
            id: "macos://applications/{bundleId}/menus",
            name: "Application Menus",
            description: "Get menu structure for an application",
            parameters: [
                ListResourceTemplates.Parameter(
                    name: "bundleId",
                    description: "The bundle identifier of the application",
                    type: "string",
                    required: true,
                    enumValues: ["com.apple.finder", "com.apple.calculator"]
                ),
                ListResourceTemplates.Parameter(
                    name: "menuTitle",
                    description: "Get items for a specific menu by title",
                    type: "string",
                    required: false,
                    enumValues: ["File", "Edit", "View"]
                ),
                ListResourceTemplates.Parameter(
                    name: "includeSubmenus",
                    description: "Whether to include submenu items",
                    type: "boolean",
                    required: false
                )
            ]
        )
    }
    
    /// Create a template for application windows
    /// - Returns: An application windows resource template
    private static func createApplicationWindowsTemplate() -> ListResourceTemplates.Template {
        ListResourceTemplates.Template(
            id: "macos://applications/{bundleId}/windows",
            name: "Application Windows",
            description: "Get windows for an application",
            parameters: [
                ListResourceTemplates.Parameter(
                    name: "bundleId",
                    description: "The bundle identifier of the application",
                    type: "string",
                    required: true,
                    enumValues: ["com.apple.finder", "com.apple.textedit"]
                ),
                ListResourceTemplates.Parameter(
                    name: "includeMinimized",
                    description: "Whether to include minimized windows",
                    type: "boolean",
                    required: false
                )
            ]
        )
    }
    
}