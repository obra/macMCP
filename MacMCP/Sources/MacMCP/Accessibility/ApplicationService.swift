// ABOUTME: This file implements the ApplicationService for working with macOS applications.
// ABOUTME: It provides methods to open, activate, and query running applications.

import Foundation
import AppKit
import Logging
import MCP

/// Information about an application
struct ApplicationInfo: Equatable {
    /// The application's bundle identifier
    let bundleIdentifier: String
    
    /// The application's name
    let name: String
    
    /// The application's URL
    let url: URL
    
    /// The application's process ID, if it's running
    var processId: Int32?
    
    /// Whether the application is running
    var isRunning: Bool {
        return processId != nil
    }
    
    /// Create from a running application
    init(from runningApp: NSRunningApplication) {
        self.bundleIdentifier = runningApp.bundleIdentifier ?? ""
        self.name = runningApp.localizedName ?? ""
        self.url = runningApp.bundleURL ?? URL(fileURLWithPath: "")
        self.processId = runningApp.processIdentifier
    }
    
    /// Create from a URL
    init(url: URL, bundleId: String? = nil) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        
        if let bundleId = bundleId {
            self.bundleIdentifier = bundleId
        } else {
            // Try to get bundle ID from the URL
            if let bundle = Bundle(url: url) {
                self.bundleIdentifier = bundle.bundleIdentifier ?? ""
            } else {
                self.bundleIdentifier = ""
            }
        }
    }
}

/// Implementation of the ApplicationServiceProtocol for managing macOS applications
public actor ApplicationService: ApplicationServiceProtocol {
    /// Logger for the application service
    private let logger: Logger
    
    /// Cache of known applications by bundle ID
    private var appCache: [String: ApplicationInfo] = [:]
    
    /// Cache of applications by name (lowercase)
    private var nameToAppCache: [String: ApplicationInfo] = [:]
    
    /// Last refresh time for the cache
    private var lastCacheRefresh: Date = .distantPast
    
    /// Cache lifetime in seconds
    private let cacheLifetime: TimeInterval = 30
    
    /// Known system applications and their bundle IDs
    private let knownSystemApps: [String: String] = [
        "calculator": "com.apple.calculator",
        "safari": "com.apple.safari",
        "mail": "com.apple.mail",
        "messages": "com.apple.messagesformacos",
        "notes": "com.apple.notes",
        "calendar": "com.apple.iCal",
        "reminders": "com.apple.reminders",
        "maps": "com.apple.maps",
        "photos": "com.apple.photos",
        "music": "com.apple.music",
        "terminal": "com.apple.terminal",
        "finder": "com.apple.finder",
        "system preferences": "com.apple.systempreferences",
        "system settings": "com.apple.systempreferences",
        "textedit": "com.apple.TextEdit",
        "preview": "com.apple.Preview"
    ]
    
    /// Initialize with a logger
    /// - Parameter logger: The logger to use
    public init(logger: Logger) {
        self.logger = logger
        
        // Initial cache population will happen on first use
    }
    
    /// Refresh the application cache
    private func refreshCache() async {
        // If the cache is still fresh, don't refresh
        let now = Date()
        if now.timeIntervalSince(lastCacheRefresh) < cacheLifetime && !appCache.isEmpty {
            logger.debug("Using cached application data", metadata: [
                "cacheAge": "\(now.timeIntervalSince(lastCacheRefresh))",
                "cacheEntries": "\(appCache.count)"
            ])
            return
        }
        
        logger.debug("Refreshing application cache")
        
        // Get all running applications
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Process running applications
        for app in runningApps where app.activationPolicy == .regular {
            // Skip if the bundle ID is missing or empty
            guard let bundleId = app.bundleIdentifier, !bundleId.isEmpty else {
                continue
            }
            
            let appInfo = ApplicationInfo(from: app)
            
            // Update the cache
            appCache[bundleId] = appInfo
            
            // Update the name cache (with lowercase name for case-insensitive lookup)
            if let name = app.localizedName, !name.isEmpty {
                nameToAppCache[name.lowercased()] = appInfo
            }
        }
        
        // Now find applications in the filesystem that aren't running
        await findInstalledApplications()
        
        // Mark the cache as refreshed
        lastCacheRefresh = now
        
        logger.debug("Application cache refreshed", metadata: [
            "runningApps": "\(runningApps.count)",
            "cachedApps": "\(appCache.count)",
            "cachedNames": "\(nameToAppCache.count)"
        ])
    }
    
    /// Find installed applications that aren't currently running
    private func findInstalledApplications() async {
        // Common paths to search for applications
        var searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Library/CoreServices",
            "/Applications/Utilities"
        ]
        
        // Add user-specific Applications folder
        let userPath = FileManager.default.homeDirectoryForCurrentUser.path
        searchPaths.append("\(userPath)/Applications")
        
        // Find all applications in the search paths
        for path in searchPaths {
            let dirURL = URL(fileURLWithPath: path)
            
            // Skip if the directory doesn't exist
            guard FileManager.default.fileExists(atPath: path) else {
                continue
            }
            
            // Get all .app bundles in this directory
            do {
                let appFiles = try FileManager.default.contentsOfDirectory(
                    at: dirURL,
                    includingPropertiesForKeys: [.isApplicationKey],
                    options: [.skipsHiddenFiles]
                ).filter { url in
                    // Only include .app bundles
                    return url.pathExtension.lowercased() == "app"
                }
                
                // Process each app bundle
                for appURL in appFiles {
                    // Try to get the bundle
                    guard let bundle = Bundle(url: appURL) else {
                        continue
                    }
                    
                    // Try to get the bundle ID and name
                    guard let bundleId = bundle.bundleIdentifier,
                          !bundleId.isEmpty,
                          let name = bundle.infoDictionary?["CFBundleName"] as? String,
                          !name.isEmpty else {
                        continue
                    }
                    
                    // Only add to the cache if not already present (running apps take precedence)
                    if appCache[bundleId] == nil {
                        let appInfo = ApplicationInfo(url: appURL, bundleId: bundleId)
                        appCache[bundleId] = appInfo
                        nameToAppCache[name.lowercased()] = appInfo
                    }
                }
            } catch {
                logger.warning("Failed to read directory", metadata: [
                    "path": "\(path)",
                    "error": "\(error.localizedDescription)"
                ])
            }
        }
    }
    
    /// Find an application by bundle ID
    /// - Parameter bundleIdentifier: The bundle identifier to look for
    /// - Returns: ApplicationInfo if found, nil otherwise
    private func findApplicationByBundleID(_ bundleIdentifier: String) async -> ApplicationInfo? {
        // Refresh the cache first
        await refreshCache()
        
        // Check exact match first
        if let appInfo = appCache[bundleIdentifier] {
            return appInfo
        }
        
        // If no exact match, try a case-insensitive search
        let lowerBundleID = bundleIdentifier.lowercased()
        for (id, info) in appCache where id.lowercased() == lowerBundleID {
            return info
        }
        
        // If still not found, try partial match
        for (id, info) in appCache where id.lowercased().contains(lowerBundleID) {
            return info
        }
        
        return nil
    }
    
    /// Find an application by name
    /// - Parameter name: The application name to look for
    /// - Returns: ApplicationInfo if found, nil otherwise
    private func findApplicationByName(_ name: String) async -> ApplicationInfo? {
        // Refresh the cache first
        await refreshCache()
        
        // Check if this is a known system app
        let lowerName = name.lowercased()
        if let bundleId = knownSystemApps[lowerName], let appInfo = appCache[bundleId] {
            return appInfo
        }
        
        // Check for exact match in name cache
        if let appInfo = nameToAppCache[lowerName] {
            return appInfo
        }
        
        // Check for prefix match
        for (cacheName, appInfo) in nameToAppCache where cacheName.hasPrefix(lowerName) {
            return appInfo
        }
        
        // Check for substring match
        for (cacheName, appInfo) in nameToAppCache where cacheName.contains(lowerName) {
            return appInfo
        }
        
        // As a last resort, try the workspace
        if let bundleId = knownSystemApps[lowerName], 
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            // Create application info and add to cache
            let appInfo = ApplicationInfo(url: url, bundleId: bundleId)
            appCache[bundleId] = appInfo
            nameToAppCache[lowerName] = appInfo
            return appInfo
        }
        
        return nil
    }
    
    /// Update the cache for a running application
    /// - Parameter app: The running application to update in the cache
    private func updateCacheForRunningApp(_ app: NSRunningApplication) {
        // Skip if the bundle ID is missing or empty
        guard let bundleId = app.bundleIdentifier, !bundleId.isEmpty else {
            return
        }
        
        let appInfo = ApplicationInfo(from: app)
        
        // Update the cache
        appCache[bundleId] = appInfo
        
        // Update the name cache (with lowercase name for case-insensitive lookup)
        if let name = app.localizedName, !name.isEmpty {
            nameToAppCache[name.lowercased()] = appInfo
        }
    }
    
    /// Opens an application by its bundle identifier.
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier of the application to open (e.g., "com.apple.Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    public func openApplication(bundleIdentifier: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        logger.info("Opening application", metadata: [
            "bundleIdentifier": "\(bundleIdentifier)",
            "arguments": "\(arguments ?? [])",
            "hideOthers": "\(hideOthers ?? false)"
        ])
        
        // First check if the application is already running
        if let appInfo = await findApplicationByBundleID(bundleIdentifier), appInfo.isRunning {
            logger.info("Application is already running, activating", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "applicationName": "\(appInfo.name)",
                "processId": "\(appInfo.processId ?? 0)"
            ])
            
            // Activate the running application
            return try await activateApplication(bundleIdentifier: bundleIdentifier)
        }
        
        // Look up the application in our cache
        guard let appInfo = await findApplicationByBundleID(bundleIdentifier) else {
            // One last attempt with NSWorkspace
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                // Found it with NSWorkspace, add to cache
                let appInfo = ApplicationInfo(url: url, bundleId: bundleIdentifier)
                appCache[bundleIdentifier] = appInfo
                nameToAppCache[appInfo.name.lowercased()] = appInfo
                
                // Continue with this URL
                return try await launchApplication(
                    url: url,
                    bundleIdentifier: bundleIdentifier,
                    arguments: arguments,
                    hideOthers: hideOthers
                )
            }
            
            logger.error("Application not found", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)"
            ])
            
            throw createApplicationNotFoundError(
                message: "Application with bundle identifier '\(bundleIdentifier)' not found",
                context: ["bundleIdentifier": bundleIdentifier]
            )
        }
        
        // Launch the application using its URL
        return try await launchApplication(
            url: appInfo.url,
            bundleIdentifier: bundleIdentifier,
            arguments: arguments,
            hideOthers: hideOthers
        )
    }
    
    /// Launch an application with the given URL and parameters
    /// - Parameters:
    ///   - url: The URL of the application to launch
    ///   - bundleIdentifier: The bundle identifier for logging/error reporting
    ///   - arguments: Optional arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications
    /// - Returns: Whether the launch was successful
    /// - Throws: MacMCPErrorInfo if the launch fails
    private func launchApplication(url: URL, bundleIdentifier: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        // Create a configuration for launching the app
        let configuration = NSWorkspace.OpenConfiguration()
        
        // Set app launch arguments if provided
        if let arguments = arguments {
            configuration.arguments = arguments
        }
        
        // Set creation options
        configuration.createsNewApplicationInstance = false  // Only create a new instance if needed
        configuration.activates = true
        
        do {
            // Launch the application
            let runningApplication = try await NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration
            )
            
            // If successful and hideOthers is true, hide other applications
            if hideOthers == true {
                NSWorkspace.shared.hideOtherApplications()
            }
            
            // Update the cache with the running application
            updateCacheForRunningApp(runningApplication)
            
            logger.info("Application opened successfully", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "applicationName": "\(runningApplication.localizedName ?? "Unknown")",
                "processIdentifier": "\(runningApplication.processIdentifier)"
            ])
            
            return true
        } catch {
            logger.error("Failed to open application", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "url": "\(url.path)",
                "error": "\(error.localizedDescription)"
            ])
            
            throw createApplicationLaunchError(
                message: "Failed to open application with bundle identifier: \(bundleIdentifier)",
                context: [
                    "bundleIdentifier": bundleIdentifier,
                    "applicationPath": url.path,
                    "error": error.localizedDescription
                ]
            )
        }
    }
    
    /// Opens an application by its name.
    /// - Parameters:
    ///   - name: The name of the application to open (e.g., "Safari")
    ///   - arguments: Optional array of command-line arguments to pass to the application
    ///   - hideOthers: Whether to hide other applications when opening this one
    /// - Returns: A boolean indicating whether the application was successfully opened
    /// - Throws: MacMCPErrorInfo if the application could not be opened
    public func openApplication(name: String, arguments: [String]? = nil, hideOthers: Bool? = nil) async throws -> Bool {
        logger.info("Opening application by name", metadata: [
            "name": "\(name)",
            "arguments": "\(arguments ?? [])",
            "hideOthers": "\(hideOthers ?? false)"
        ])
        
        // First check if there's a known system app with this name
        let lowerName = name.lowercased()
        if let bundleId = knownSystemApps[lowerName] {
            logger.debug("Found known system app", metadata: [
                "name": "\(name)",
                "bundleId": "\(bundleId)"
            ])
            
            // Try to open by bundle ID
            return try await openApplication(
                bundleIdentifier: bundleId,
                arguments: arguments,
                hideOthers: hideOthers
            )
        }
        
        // Try to find the application by name in our cache
        if let appInfo = await findApplicationByName(name) {
            if appInfo.isRunning {
                logger.info("Found running application with name", metadata: [
                    "name": "\(name)",
                    "actualName": "\(appInfo.name)",
                    "bundleId": "\(appInfo.bundleIdentifier)",
                    "processId": "\(appInfo.processId ?? 0)"
                ])
                
                // If it has a bundle ID, activate it
                if !appInfo.bundleIdentifier.isEmpty {
                    return try await activateApplication(bundleIdentifier: appInfo.bundleIdentifier)
                }
                
                // Otherwise, we'll launch it below
            }
            
            // Launch by URL
            return try await launchApplication(
                url: appInfo.url,
                bundleIdentifier: appInfo.bundleIdentifier,
                arguments: arguments,
                hideOthers: hideOthers
            )
        }
        
        // As a last resort, try the older method of searching for the app directly
        
        // Look for exact path in Applications directory
        let exactAppPath = "/Applications/\(name).app"
        if FileManager.default.fileExists(atPath: exactAppPath) {
            let url = URL(fileURLWithPath: exactAppPath)
            
            // Try to create app info and cache it
            let appInfo = ApplicationInfo(url: url)
            if !appInfo.bundleIdentifier.isEmpty {
                appCache[appInfo.bundleIdentifier] = appInfo
                nameToAppCache[lowerName] = appInfo
            }
            
            // Launch by URL
            return try await launchApplication(
                url: url,
                bundleIdentifier: appInfo.bundleIdentifier,
                arguments: arguments,
                hideOthers: hideOthers
            )
        }
        
        // Search in the Applications directory
        let appDir = URL(fileURLWithPath: "/Applications")
        do {
            let appFiles = try FileManager.default.contentsOfDirectory(
                at: appDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { url in
                return url.pathExtension.lowercased() == "app"
            }
            
            // Look for exact, prefix, and substring matches
            if let exactMatch = appFiles.first(where: { url in
                let filename = url.deletingPathExtension().lastPathComponent
                return filename.lowercased() == lowerName
            }) {
                // Try to create app info and cache it
                let appInfo = ApplicationInfo(url: exactMatch)
                if !appInfo.bundleIdentifier.isEmpty {
                    appCache[appInfo.bundleIdentifier] = appInfo
                    nameToAppCache[lowerName] = appInfo
                }
                
                // Launch by URL
                return try await launchApplication(
                    url: exactMatch,
                    bundleIdentifier: appInfo.bundleIdentifier,
                    arguments: arguments,
                    hideOthers: hideOthers
                )
            }
            
            // Try prefix match
            if let prefixMatch = appFiles.first(where: { url in
                let filename = url.deletingPathExtension().lastPathComponent
                return filename.lowercased().hasPrefix(lowerName)
            }) {
                // Try to create app info and cache it
                let appInfo = ApplicationInfo(url: prefixMatch)
                if !appInfo.bundleIdentifier.isEmpty {
                    appCache[appInfo.bundleIdentifier] = appInfo
                    nameToAppCache[lowerName] = appInfo
                }
                
                // Launch by URL
                return try await launchApplication(
                    url: prefixMatch,
                    bundleIdentifier: appInfo.bundleIdentifier,
                    arguments: arguments,
                    hideOthers: hideOthers
                )
            }
            
            // Try substring match
            if let substringMatch = appFiles.first(where: { url in
                let filename = url.deletingPathExtension().lastPathComponent
                return filename.lowercased().contains(lowerName)
            }) {
                // Try to create app info and cache it
                let appInfo = ApplicationInfo(url: substringMatch)
                if !appInfo.bundleIdentifier.isEmpty {
                    appCache[appInfo.bundleIdentifier] = appInfo
                    nameToAppCache[lowerName] = appInfo
                }
                
                // Launch by URL
                return try await launchApplication(
                    url: substringMatch,
                    bundleIdentifier: appInfo.bundleIdentifier,
                    arguments: arguments,
                    hideOthers: hideOthers
                )
            }
        } catch {
            logger.warning("Failed to search Applications directory", metadata: [
                "error": "\(error.localizedDescription)"
            ])
            // Continue to try other methods
        }
        
        // If we get here, we failed to find the application
        logger.error("Application not found by name", metadata: [
            "name": "\(name)"
        ])
        
        throw createApplicationNotFoundError(
            message: "Application with name '\(name)' not found",
            context: [
                "applicationName": name,
                "searchAttempts": "Cache, Known System Apps, Exact Path, Applications Directory"
            ]
        )
    }
    
    /// Activates an already running application by bringing it to the foreground.
    /// - Parameter bundleIdentifier: The bundle identifier of the application to activate
    /// - Returns: A boolean indicating whether the application was successfully activated
    /// - Throws: MacMCPErrorInfo if the application could not be activated
    public func activateApplication(bundleIdentifier: String) async throws -> Bool {
        logger.info("Activating application", metadata: [
            "bundleIdentifier": "\(bundleIdentifier)"
        ])
        
        // Check the cache for a running app with this bundle ID
        if let appInfo = await findApplicationByBundleID(bundleIdentifier), appInfo.isRunning, let pid = appInfo.processId {
            // Found in cache, try to activate by PID
            if let app = NSRunningApplication(processIdentifier: pid) {
                let success = app.activate(options: [.activateIgnoringOtherApps])
                
                if success {
                    logger.info("Application activated successfully from cache", metadata: [
                        "bundleIdentifier": "\(bundleIdentifier)",
                        "applicationName": "\(appInfo.name)",
                        "processIdentifier": "\(pid)"
                    ])
                    return true
                }
                
                // If activation failed, continue to try other methods
                logger.warning("Failed to activate application from cache", metadata: [
                    "bundleIdentifier": "\(bundleIdentifier)",
                    "processIdentifier": "\(pid)"
                ])
            }
        }
        
        // Fall back to legacy approach if cache lookup fails
        // Find all running applications with this bundle ID
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        if !runningApplications.isEmpty {
            // Activate the first running instance (usually there's only one)
            let application = runningApplications.first!
            let success = application.activate(options: [.activateIgnoringOtherApps])
            
            // Update the cache with the running application
            updateCacheForRunningApp(application)
            
            if success {
                logger.info("Application activated successfully", metadata: [
                    "bundleIdentifier": "\(bundleIdentifier)",
                    "applicationName": "\(application.localizedName ?? "Unknown")",
                    "processIdentifier": "\(application.processIdentifier)"
                ])
                return true
            } else {
                logger.error("Failed to activate application", metadata: [
                    "bundleIdentifier": "\(bundleIdentifier)"
                ])
                
                throw createApplicationError(
                    message: "Failed to activate application with bundle identifier: \(bundleIdentifier)",
                    context: ["bundleIdentifier": bundleIdentifier]
                )
            }
        }
        
        // If not running, try to launch it
        if let appInfo = await findApplicationByBundleID(bundleIdentifier) {
            logger.info("Application is not running, attempting to launch", metadata: [
                "bundleIdentifier": "\(bundleIdentifier)",
                "applicationName": "\(appInfo.name)"
            ])
            
            return try await launchApplication(
                url: appInfo.url,
                bundleIdentifier: bundleIdentifier,
                arguments: nil,
                hideOthers: nil
            )
        }
        
        // Not found in cache or running applications
        logger.error("No running application found to activate", metadata: [
            "bundleIdentifier": "\(bundleIdentifier)"
        ])
        
        throw createApplicationNotFoundError(
            message: "No running application found with bundle identifier: \(bundleIdentifier)",
            context: ["bundleIdentifier": bundleIdentifier]
        )
    }
    
    /// Returns a dictionary of running applications.
    /// - Returns: A dictionary mapping bundle identifiers to application names
    /// - Throws: MacMCPErrorInfo if the running applications could not be retrieved
    public func getRunningApplications() async throws -> [String: String] {
        logger.info("Getting running applications")
        
        // Refresh the cache to ensure we have up-to-date information
        await refreshCache()
        
        var runningApps: [String: String] = [:]
        
        // Use the cache to find running applications
        for (bundleId, appInfo) in appCache where appInfo.isRunning {
            runningApps[bundleId] = appInfo.name
        }
        
        // If the cache is empty, fall back to the legacy approach
        if runningApps.isEmpty {
            // Get all running applications
            let applications = NSWorkspace.shared.runningApplications
            
            // Filter to only user applications and extract bundle ID and name
            for app in applications where app.activationPolicy == .regular {
                if let bundleID = app.bundleIdentifier, let name = app.localizedName {
                    runningApps[bundleID] = name
                    
                    // Update the cache
                    updateCacheForRunningApp(app)
                }
            }
        }
        
        logger.info("Found running applications", metadata: [
            "count": "\(runningApps.count)"
        ])
        
        return runningApps
    }
}