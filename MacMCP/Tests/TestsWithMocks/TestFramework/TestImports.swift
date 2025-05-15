// ABOUTME: This file provides common imports and type definitions for mock-based tests.
// ABOUTME: It ensures consistent access to MacMCP types and mocks across test files.

import Foundation
import CoreGraphics
import AppKit
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
public typealias UIElementScope = MacMCP.UIElementScope
public typealias WindowOrderMode = MacMCP.WindowOrderMode

// MCP Tools
public typealias ScreenshotTool = MacMCP.ScreenshotTool
public typealias UIInteractionTool = MacMCP.UIInteractionTool
public typealias InterfaceExplorerTool = MacMCP.InterfaceExplorerTool
public typealias KeyboardInteractionTool = MacMCP.KeyboardInteractionTool
public typealias ApplicationManagementTool = MacMCP.ApplicationManagementTool
public typealias WindowManagementTool = MacMCP.WindowManagementTool
public typealias MenuNavigationTool = MacMCP.MenuNavigationTool
public typealias ClipboardManagementTool = MacMCP.ClipboardManagementTool
public typealias OpenApplicationTool = MacMCP.OpenApplicationTool

// MCP Types
public typealias Value = MCP.Value
public typealias Tool = MCP.Tool

// Due to the module restructuring, MockClipboardService is now directly in this module
// and doesn't need to be imported from MacMCP