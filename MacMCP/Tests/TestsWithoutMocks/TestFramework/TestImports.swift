// ABOUTME: TestImports.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import CoreGraphics
import Foundation
import Logging
import MCP

@testable import MacMCP

// Re-export MacMCP types
public typealias UIElement = MacMCP.UIElement
public typealias FrameSource = MacMCP.FrameSource

// Accessibility Service types
public typealias AccessibilityElement = MacMCP.AccessibilityElement
public typealias AccessibilityService = MacMCP.AccessibilityService
public typealias AccessibilityServiceProtocol = MacMCP.AccessibilityServiceProtocol
public typealias ApplicationService = MacMCP.ApplicationService
public typealias ApplicationServiceProtocol = MacMCP.ApplicationServiceProtocol
public typealias ScreenshotService = MacMCP.ScreenshotService
public typealias ScreenshotServiceProtocol = MacMCP.ScreenshotServiceProtocol
public typealias UIInteractionService = MacMCP.UIInteractionService
public typealias UIInteractionServiceProtocol = MacMCP.UIInteractionServiceProtocol
public typealias MenuNavigationService = MacMCP.MenuNavigationService
public typealias MenuNavigationServiceProtocol = MacMCP.MenuNavigationServiceProtocol
public typealias ClipboardService = MacMCP.ClipboardService
public typealias ClipboardServiceProtocol = MacMCP.ClipboardServiceProtocol

// MCP Tools
public typealias ScreenshotTool = MacMCP.ScreenshotTool
public typealias UIInteractionTool = MacMCP.UIInteractionTool
public typealias InterfaceExplorerTool = MacMCP.InterfaceExplorerTool
public typealias KeyboardInteractionTool = MacMCP.KeyboardInteractionTool
public typealias ApplicationManagementTool = MacMCP.ApplicationManagementTool
public typealias WindowManagementTool = MacMCP.WindowManagementTool
public typealias MenuNavigationTool = MacMCP.MenuNavigationTool
public typealias ClipboardManagementTool = MacMCP.ClipboardManagementTool

// MCP Types
public typealias Value = MCP.Value
public typealias Tool = MCP.Tool

// Test Framework Types
