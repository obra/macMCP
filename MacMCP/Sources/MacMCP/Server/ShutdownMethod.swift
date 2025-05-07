// ABOUTME: This file defines the Shutdown method for the MCP protocol.
// ABOUTME: It handles graceful server shutdown requests.

import Foundation
import MCP

/// The shutdown method for the MCP protocol
public enum Shutdown: MCP.Method {
    public static let name = "shutdown"
    
    /// Empty parameters for shutdown
    public struct Parameters: Codable, Hashable, Sendable {}
    
    /// Empty result for shutdown
    public struct Result: Codable, Hashable, Sendable {}
}