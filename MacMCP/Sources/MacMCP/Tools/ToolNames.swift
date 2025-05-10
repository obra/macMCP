// ABOUTME: Defines constants for all tool names to ensure consistency
// ABOUTME: This prevents string literal usage and enforces standardized naming

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

    /// Application opening tool
    public static let openApplication = "\(prefix)_open_application"

    /// Window management tool
    public static let windowManagement = "\(prefix)_window_management"

    /// Menu navigation tool
    public static let menuNavigation = "\(prefix)_menu_navigation"


    /// Interface explorer tool (consolidates UI state, interactive elements, and capabilities)
    public static let interfaceExplorer = "\(prefix)_interface_explorer"
}