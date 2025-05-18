// ABOUTME: ToolNames.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import Foundation

/// Constants for all MacMCP tool names
public enum ToolNames {
  /// Prefix for all macOS MCP tools
  public static let prefix = "macos"

  /// Generic ping tool (connectivity test)
  public static let ping = "\(prefix)_ping"

  /// Screenshot tool
  public static let screenshot = "\(prefix)_screenshot"

  /// UI interaction tool (click, type, etc.)
  public static let uiInteraction = "\(prefix)_ui_interact"

  /// Application management tool (replacing openApplication)
  public static let applicationManagement = "\(prefix)_application_management"

  /// Window management tool
  public static let windowManagement = "\(prefix)_window_management"

  /// Menu navigation tool
  public static let menuNavigation = "\(prefix)_menu_navigation"

  /// Clipboard management tool
  public static let clipboardManagement = "\(prefix)_clipboard_management"

  /// Interface explorer tool (consolidates UI state, interactive elements, and capabilities)
  public static let interfaceExplorer = "\(prefix)_interface_explorer"

  /// Keyboard interaction tool
  public static let keyboardInteraction = "\(prefix)_keyboard_interaction"

  /// Onboarding tool for AI assistants
  public static let onboarding = "\(prefix)_onboarding"

  /// Legacy tool names (for backward compatibility)
  public static let openApplication = "\(prefix)_open_application"
}
