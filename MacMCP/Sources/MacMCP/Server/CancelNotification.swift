// ABOUTME: This file defines the Cancel notification type for the MCP protocol.
// ABOUTME: It provides a way for clients to request cancellation of in-progress operations.

import Foundation
import MCP

/// The cancel notification for aborting in-progress operations
public struct CancelNotification: MCP.Notification {
    public static let name = "$/cancelRequest"
    
    /// Parameters for cancel notification
    public struct Parameters: Codable, Hashable, Sendable {
        /// The ID of the request to cancel
        public let id: String
        
        /// Create new parameters
        public init(id: String) {
            self.id = id
        }
    }
}