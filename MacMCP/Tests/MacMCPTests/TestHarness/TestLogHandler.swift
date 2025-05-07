// ABOUTME: This file implements a testable logging handler for the MCP tools testing framework.
// ABOUTME: It captures log messages for inspection during test execution.

import Foundation
import Logging
import XCTest

/// A custom LogHandler implementation for testing that captures log messages
public struct TestLogHandler: LogHandler, @unchecked Sendable {
    /// Struct representing a captured log message
    public struct LogEntry: Equatable, Sendable {
        /// The log level
        public let level: Logger.Level
        
        /// The log message
        public let message: String
        
        /// Additional metadata
        public let metadata: Logger.Metadata?
        
        /// Source file
        public let file: String
        
        /// Source function
        public let function: String
        
        /// Source line
        public let line: UInt
        
        /// When the message was logged
        public let timestamp: Date
        
        /// Create a new log entry
        public init(
            level: Logger.Level,
            message: String,
            metadata: Logger.Metadata? = nil,
            file: String,
            function: String,
            line: UInt,
            timestamp: Date = Date()
        ) {
            self.level = level
            self.message = message
            self.metadata = metadata
            self.file = file
            self.function = function
            self.line = line
            self.timestamp = timestamp
        }
    }
    
    /// Array of captured log entries (use an actor for thread safety)
    private class EntryStore: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [LogEntry] = []
        
        func add(_ entry: LogEntry) {
            lock.lock()
            defer { lock.unlock() }
            entries.append(entry)
        }
        
        func getAll() -> [LogEntry] {
            lock.lock()
            defer { lock.unlock() }
            return entries
        }
        
        func clear() {
            lock.lock()
            defer { lock.unlock() }
            entries.removeAll()
        }
    }
    
    private let store = EntryStore()
    
    /// Get all entries
    public var entries: [LogEntry] {
        return store.getAll()
    }
    
    /// The logger label
    public let label: String
    
    /// The current log level
    public var logLevel: Logger.Level
    
    /// Logger metadata
    public var metadata: Logger.Metadata = [:]
    
    /// Get or set a metadata value
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }
    
    /// Create a new test logger with optional label and log level
    public init(label: String, level: Logger.Level = .trace) {
        self.label = label
        self.logLevel = level
    }
    
    /// Log a message - required by LogHandler protocol
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard level >= self.logLevel else { return }
        
        let entry = LogEntry(
            level: level,
            message: message.description,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
        
        store.add(entry)
        
        // Print to console for debugging during tests
        print("[\(level)] \(message)")
    }
    
    /// Reset the logger by clearing all entries
    public func reset() {
        store.clear()
    }
    
    /// Get entries filtered by log level
    public func getEntries(level: Logger.Level) -> [LogEntry] {
        return entries.filter { $0.level == level }
    }
    
    /// Get entries containing a specific message substring
    public func getEntries(containingMessage substring: String) -> [LogEntry] {
        return entries.filter { $0.message.contains(substring) }
    }
    
    /// Check if the logger contains a message with the given substring
    public func containsMessage(substring: String, level: Logger.Level? = nil) -> Bool {
        return entries.contains { entry in
            let levelMatch = level == nil || entry.level == level
            let messageMatch = entry.message.contains(substring)
            return levelMatch && messageMatch
        }
    }
    
    /// Count entries of a specific level
    public func countEntries(level: Logger.Level) -> Int {
        return getEntries(level: level).count
    }
    
    /// Assert that a log message with the given level and content exists
    public func assertLogged(
        _ message: String,
        level: Logger.Level,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = containsMessage(substring: message, level: level)
        
        XCTAssertTrue(
            found,
            "Expected log message containing '\(message)' at level \(level), but not found",
            file: file,
            line: line
        )
    }
    
    /// Assert that no log message with the given level and content exists
    public func assertNotLogged(
        _ message: String,
        level: Logger.Level,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let found = containsMessage(substring: message, level: level)
        
        XCTAssertFalse(
            found,
            "Expected no log message containing '\(message)' at level \(level), but one was found",
            file: file,
            line: line
        )
    }
}

/// Extension to create a Logger with a TestLogHandler
extension Logger {
    /// Create a test logger that captures log messages
    public static func testLogger(label: String, level: Logger.Level = .trace) -> (Logger, TestLogHandler) {
        let testHandler = TestLogHandler(label: label, level: level)
        let logger = Logger(label: label) { _ in testHandler }
        return (logger, testHandler)
    }
}