// ABOUTME: Defines standardized error codes for JSON-RPC error responses
// ABOUTME: Provides a unified approach to error handling across all MCP tools

import Foundation
import MCP

/// Standard JSON-RPC error codes as defined in the JSON-RPC 2.0 specification
/// https://www.jsonrpc.org/specification#error_object
public enum JSONRPCErrorCode {
    /// Invalid JSON was received by the server.
    /// An error occurred on the server while parsing the JSON text.
    public static let parseError = -32700
    
    /// The JSON sent is not a valid Request object.
    public static let invalidRequest = -32600
    
    /// The method does not exist / is not available.
    public static let methodNotFound = -32601
    
    /// Invalid method parameter(s).
    public static let invalidParams = -32602
    
    /// Internal JSON-RPC error.
    public static let internalError = -32603
    
    /// Reserved for implementation-defined server-errors.
    public static let serverErrorStart = -32099
    public static let serverErrorEnd = -32000
}

/// Application-specific error codes for MacMCP
/// These are outside the reserved JSON-RPC range
public enum MacMCPErrorCode {
    /// Base error code for permission errors
    public static let permissionBase = 1000
    
    /// Permission denied
    public static let permissionDenied = 1001
    
    /// Accessibility permission needed
    public static let accessibilityPermissionNeeded = 1002
    
    /// Screen recording permission needed
    public static let screenRecordingPermissionNeeded = 1003
    
    /// Base error code for element errors
    public static let elementBase = 2000
    
    /// Element not found
    public static let elementNotFound = 2001
    
    /// Element not visible
    public static let elementNotVisible = 2002
    
    /// Element not interactive
    public static let elementNotInteractive = 2003
    
    /// Invalid element identifier
    public static let invalidElementId = 2004
    
    /// Zero coordinates element
    public static let zeroCoordinatesElement = 2010
    
    /// Base error code for interaction errors
    public static let interactionBase = 3000
    
    /// Action failed
    public static let actionFailed = 3001
    
    /// Action not supported by element
    public static let actionNotSupported = 3002
    
    /// Invalid action parameters
    public static let invalidActionParams = 3003
    
    /// Base error code for screenshot errors
    public static let screenshotBase = 4000
    
    /// Screenshot failed
    public static let screenshotFailed = 4001
    
    /// Invalid screenshot region
    public static let invalidScreenshotRegion = 4002
    
    /// Base error code for application errors
    public static let applicationBase = 5000
    
    /// Application error
    public static let applicationError = 5001
    
    /// Base error code for application launch errors
    public static let applicationLaunchBase = 5100
    
    /// Application launch failed
    public static let applicationLaunchFailed = 5101
    
    /// Base error code for application not found errors
    public static let applicationNotFoundBase = 5200
    
    /// Application not found
    public static let applicationNotFound = 5201
    
    /// Application not running
    public static let applicationNotRunning = 5202
    
    /// Base error code for timeout errors
    public static let timeoutBase = 6000
    
    /// Operation timed out
    public static let operationTimeout = 6001
    
    /// Base error code for network errors
    public static let networkBase = 7000
    
    /// Network error
    public static let networkError = 7001
    
    /// Base error code for parsing errors
    public static let parsingBase = 8000
    
    /// Parsing error
    public static let parsingError = 8001
    
    /// Base error code for unknown errors
    public static let unknownBase = 9000
    
    /// Unknown error
    public static let unknownError = 9001
}

/// Extension to MacMCPErrorCategory for mapping to error codes
extension MacMCPErrorCategory {
    /// Get the base error code for this category
    public var baseErrorCode: Int {
        switch self {
        case .permissions:
            return MacMCPErrorCode.permissionBase
        case .accessibility:
            return MacMCPErrorCode.permissionBase  // Accessibility uses permission base
        case .interaction:
            return MacMCPErrorCode.interactionBase
        case .element:
            return MacMCPErrorCode.elementBase
        case .screenshot:
            return MacMCPErrorCode.screenshotBase
        case .application:
            return MacMCPErrorCode.applicationBase
        case .applicationLaunch:
            return MacMCPErrorCode.applicationLaunchBase
        case .applicationNotFound:
            return MacMCPErrorCode.applicationNotFoundBase
        case .network:
            return MacMCPErrorCode.networkBase
        case .parsing:
            return MacMCPErrorCode.parsingBase
        case .timeout:
            return MacMCPErrorCode.timeoutBase
        case .unknown:
            return MacMCPErrorCode.unknownBase
        }
    }
    
    /// Map to a standard JSON-RPC error code
    public var jsonrpcErrorCode: Int {
        switch self {
        case .permissions, .accessibility:
            return JSONRPCErrorCode.invalidRequest
        case .element, .interaction:
            return JSONRPCErrorCode.invalidParams
        case .parsing:
            return JSONRPCErrorCode.parseError
        case .applicationNotFound:
            return JSONRPCErrorCode.invalidRequest
        case .applicationLaunch:
            return JSONRPCErrorCode.invalidRequest
        default:
            return JSONRPCErrorCode.internalError
        }
    }
}

/// Extension to MCPError for easier creation from MacMCPErrorInfo
extension MCPError {
    /// Create an MCPError from a MacMCPErrorInfo
    static func from(_ error: MacMCPErrorInfo) -> MCPError {
        // Create a detailed error message
        let errorDetail = error.context.isEmpty
            ? error.message
            : "\(error.message) (\(error.context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")))"
        
        // Use the appropriate error type based on category
        switch error.category {
        case .parsing:
            return .parseError(errorDetail)
            
        case .element, .interaction:
            return .invalidParams(errorDetail)
            
        case .permissions, .accessibility, .applicationNotFound, .applicationLaunch:
            return .invalidRequest(errorDetail)
            
        case .application, .screenshot, .network, .timeout, .unknown:
            return .internalError(errorDetail)
        }
    }
}