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
  public static let applicationManagement = "\(prefix)_manage_app_state"

  /// Window management tool
  public static let windowManagement = "\(prefix)_manage_windows"

  /// Menu navigation tool
  public static let menuNavigation = "\(prefix)_navigate_menus"

  /// Clipboard management tool
  public static let clipboardManagement = "\(prefix)_manage_clipboard"

  /// Interface explorer tool (consolidates UI state, interactive elements, and capabilities)
  public static let interfaceExplorer = "\(prefix)_explore_ui"

  /// Keyboard interaction tool
  public static let keyboardInteraction = "\(prefix)_use_keyboard"

  /// Onboarding tool for AI assistants
  public static let onboarding = "\(prefix)_onboarding"

  /// Legacy tool names (for backward compatibility)
  public static let openApplication = "\(prefix)_open_application"
}
