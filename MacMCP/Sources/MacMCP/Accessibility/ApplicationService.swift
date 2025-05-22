// ABOUTME: ApplicationService.swift
// ABOUTME: Part of MacMCP allowing LLMs to interact with macOS applications.

import AppKit
import Foundation
import Logging
import MCP

/// Information about an application
struct ApplicationInfo: Equatable {
  /// The application's bundle identifier
  let bundleId: String

  /// The application's name
  let name: String

  /// The application's URL
  let url: URL

  /// The application's process ID, if it's running
  var processId: Int32?

  /// Whether the application is running
  var isRunning: Bool {
    processId != nil
  }

  /// Create from a running application
  init(from runningApp: NSRunningApplication) {
    bundleId = runningApp.bundleIdentifier ?? ""
    name = runningApp.localizedName ?? ""
    url = runningApp.bundleURL ?? URL(fileURLWithPath: "")
    processId = runningApp.processIdentifier
  }

  /// Create from a URL
  init(url: URL, bundleId: String? = nil) {
    self.url = url
    name = url.deletingPathExtension().lastPathComponent

    if let passedBundleId = bundleId {
      self.bundleId = passedBundleId
    } else {
      // Try to get bundle ID from the URL
      if let bundle = Bundle(url: url) {
        self.bundleId = bundle.bundleIdentifier ?? ""
      } else {
        self.bundleId = ""
      }
    }
  }
}

/// Implementation of the ApplicationServiceProtocol for managing macOS applications
public actor ApplicationService: ApplicationServiceProtocol {
  /// Logger for the application service
  let logger: Logger

  /// Cache of known applications by bundle ID
  var appCache: [String: ApplicationInfo] = [:]

  /// Cache of applications by name (lowercase)
  private var nameToAppCache: [String: ApplicationInfo] = [:]

  /// Last refresh time for the cache
  private var lastCacheRefresh: Date = .distantPast

  /// Cache lifetime in seconds
  private let cacheLifetime: TimeInterval = 30

  /// Active application state observers
  private var applicationObservers: [String: @Sendable (ApplicationStateChange) async -> Void] = [:]

  /// Notification center for observing application notifications
  private let notificationCenter = NSWorkspace.shared.notificationCenter

  /// Whether we've set up the notification observers
  private var observersConfigured = false

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
    "preview": "com.apple.Preview",
  ]

  /// Initialize with a logger
  /// - Parameter logger: The logger to use
  public init(logger: Logger) {
    self.logger = logger

    // Initial cache population will happen on first use

    // Start task to configure application observers
    Task {
      await configureApplicationObservers()
    }
  }

  /// Refresh the application cache
  private func refreshCache() async {
    // If the cache is still fresh, don't refresh
    let now = Date()
    if now.timeIntervalSince(lastCacheRefresh) < cacheLifetime, !appCache.isEmpty {
      logger.debug(
        "Using cached application data",
        metadata: [
          "cacheAge": "\(now.timeIntervalSince(lastCacheRefresh))",
          "cacheEntries": "\(appCache.count)",
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

    logger.debug(
      "Application cache refreshed",
      metadata: [
        "runningApps": "\(runningApps.count)",
        "cachedApps": "\(appCache.count)",
        "cachedNames": "\(nameToAppCache.count)",
      ])
  }

  /// Find installed applications that aren't currently running
  private func findInstalledApplications() async {
    // Common paths to search for applications
    var searchPaths = [
      "/Applications",
      "/System/Applications",
      "/System/Library/CoreServices",
      "/Applications/Utilities",
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
          options: [.skipsHiddenFiles],
        ).filter { url in
          // Only include .app bundles
          url.pathExtension.lowercased() == "app"
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
            !name.isEmpty
          else {
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
        logger.warning(
          "Failed to read directory",
          metadata: [
            "path": "\(path)",
            "error": "\(error.localizedDescription)",
          ])
      }
    }
  }

  /// Find an application by bundle ID
  /// - Parameter bundleId: The bundle identifier to look for
  /// - Returns: ApplicationInfo if found, nil otherwise
  func findApplicationByBundleID(_ bundleId: String) async -> ApplicationInfo? {
    // Refresh the cache first
    await refreshCache()

    // Check exact match first
    if let appInfo = appCache[bundleId] {
      return appInfo
    }

    // If no exact match, try a case-insensitive search
    let lowerBundleID = bundleId.lowercased()
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
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    {
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

  /// Validate an application before launch
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application to validate
  ///   - url: Optional known URL for the application
  /// - Returns: ApplicationInfo with validated application details
  /// - Throws: MacMCPErrorInfo if the application validation fails
  func validateApplication(bundleId: String, url: URL? = nil) async throws
    -> ApplicationInfo
  {
    logger.debug(
      "Validating application",
      metadata: [
        "bundleId": "\(bundleId)",
        "providedURL": "\(url?.path ?? "none")",
      ])

    // First check if the application is already running
    if let appInfo = await findApplicationByBundleID(bundleId), appInfo.isRunning {
      logger.debug(
        "Application is already running",
        metadata: [
          "bundleId": "\(bundleId)",
          "applicationName": "\(appInfo.name)",
          "processId": "\(appInfo.processId ?? 0)",
        ])

      return appInfo
    }

    // If we have a specific URL provided, verify it
    if let url {
      // Check if the URL exists and is an application
      if !FileManager.default.fileExists(atPath: url.path) {
        logger.error(
          "Application URL does not exist",
          metadata: [
            "bundleId": "\(bundleId)",
            "url": "\(url.path)",
          ])

        throw createApplicationNotFoundError(
          message: "Application at path '\(url.path)' does not exist",
          context: [
            "bundleId": bundleId,
            "applicationPath": url.path,
          ],
        )
      }

      // Check if the URL points to a valid application bundle
      if url.pathExtension.lowercased() != "app" {
        logger.error(
          "URL is not an application bundle",
          metadata: [
            "bundleId": "\(bundleId)",
            "url": "\(url.path)",
          ])

        throw createApplicationNotFoundError(
          message: "Path '\(url.path)' is not a valid application bundle (.app)",
          context: [
            "bundleId": bundleId,
            "applicationPath": url.path,
          ],
        )
      }

      // Try to load the bundle to verify it's a valid application
      guard let bundle = Bundle(url: url) else {
        logger.error(
          "Failed to load application bundle",
          metadata: [
            "bundleId": "\(bundleId)",
            "url": "\(url.path)",
          ])

        throw createApplicationNotFoundError(
          message: "Failed to load application bundle at '\(url.path)'",
          context: [
            "bundleId": bundleId,
            "applicationPath": url.path,
          ],
        )
      }

      // Verify the bundle identifier matches (if specified)
      if !bundleId.isEmpty {
        let bundleId = bundle.bundleIdentifier ?? ""

        // If the provided bundle ID and the actual bundle ID don't match
        // (ignoring case), then this is likely not the right application
        if !bundleId.lowercased().contains(bundleId.lowercased()),
          !bundleId.lowercased().contains(bundleId.lowercased())
        {
          logger.warning(
            "Bundle identifier mismatch",
            metadata: [
              "providedBundleId": "\(bundleId)",
              "actualBundleId": "\(bundleId)",
              "url": "\(url.path)",
            ])

          // Allow it to continue, but log the warning
        }
      }

      // Create app info
      let appInfo = ApplicationInfo(url: url, bundleId: bundleId)

      // Update the cache
      if !appInfo.bundleId.isEmpty {
        appCache[appInfo.bundleId] = appInfo
        nameToAppCache[appInfo.name.lowercased()] = appInfo
      }

      return appInfo
    }

    // Look up the application in our cache
    if let appInfo = await findApplicationByBundleID(bundleId) {
      // Verify the application path still exists
      if !FileManager.default.fileExists(atPath: appInfo.url.path) {
        logger.warning(
          "Cached application path no longer exists",
          metadata: [
            "bundleId": "\(bundleId)",
            "url": "\(appInfo.url.path)",
          ])

        // Remove from cache and try one more lookup
        appCache.removeValue(forKey: bundleId)

        // Force a cache refresh
        lastCacheRefresh = .distantPast
        if let newAppInfo = await findApplicationByBundleID(bundleId) {
          return newAppInfo
        }

        // Fall through to the not found error
      } else {
        return appInfo
      }
    }

    // One last attempt with NSWorkspace
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
      // Create application info and add to cache
      let appInfo = ApplicationInfo(url: url, bundleId: bundleId)
      appCache[bundleId] = appInfo
      nameToAppCache[appInfo.name.lowercased()] = appInfo
      return appInfo
    }

    logger.error(
      "Application not found",
      metadata: [
        "bundleId": "\(bundleId)"
      ])

    throw createApplicationNotFoundError(
      message: "Application with bundle identifier '\(bundleId)' not found",
      context: [
        "bundleId": bundleId,
        "searchMethods": "Cache, NSWorkspace, File System",
      ],
    )
  }

  /// Opens an application by its bundle identifier.
  /// - Parameters:
  ///   - bundleId: The bundle identifier of the application to open (e.g., "com.apple.Safari")
  ///   - arguments: Optional array of command-line arguments to pass to the application
  ///   - hideOthers: Whether to hide other applications when opening this one
  /// - Returns: A boolean indicating whether the application was successfully opened
  /// - Throws: MacMCPErrorInfo if the application could not be opened
  public func openApplication(
    bundleId: String,
    arguments: [String]? = nil,
    hideOthers: Bool? = nil,
  ) async throws -> Bool {
    logger.debug(
      "Opening application",
      metadata: [
        "bundleId": "\(bundleId)",
        "arguments": "\(arguments ?? [])",
        "hideOthers": "\(hideOthers ?? false)",
      ])

    // Validate the application first
    let appInfo = try await validateApplication(bundleId: bundleId)

    // If the application is already running, activate it
    if appInfo.isRunning {
      logger.debug(
        "Application is already running, activating",
        metadata: [
          "bundleId": "\(bundleId)",
          "applicationName": "\(appInfo.name)",
          "processId": "\(appInfo.processId ?? 0)",
        ])

      // Activate the running application
      return try await activateApplication(bundleId: bundleId)
    }

    // Launch the application using its URL
    return try await launchApplication(
      url: appInfo.url,
      bundleId: bundleId,
      arguments: arguments,
      hideOthers: hideOthers,
    )
  }

  /// Verify that an application has properly initialized after launch
  /// - Parameters:
  ///   - application: The running application to verify
  ///   - timeout: Timeout in seconds (default is 5)
  /// - Returns: True if the application appears to be properly initialized
  /// - Throws: MacMCPErrorInfo if the application fails to initialize properly
  private func verifyApplicationLaunch(
    _ application: NSRunningApplication,
    timeout: TimeInterval = 5,
  ) async throws -> Bool {
    logger.debug(
      "Verifying application launch",
      metadata: [
        "bundleId": "\(application.bundleIdentifier ?? "unknown")",
        "applicationName": "\(application.localizedName ?? "Unknown")",
        "processIdentifier": "\(application.processIdentifier)",
      ])

    // Check if the application has finished launching
    if !application.isFinishedLaunching {
      logger.debug("Waiting for application to finish launching")

      // Wait for the app to finish launching
      let startTime = Date()
      var isLaunched = application.isFinishedLaunching

      while !isLaunched, Date().timeIntervalSince(startTime) < timeout {
        // Sleep briefly to avoid spinning
        try await Task.sleep(for: .milliseconds(100))

        // Refresh the app status
        isLaunched = application.isFinishedLaunching
      }

      // If we timed out, report the error
      if !isLaunched {
        logger.error(
          "Application failed to finish launching within timeout",
          metadata: [
            "bundleId": "\(application.bundleIdentifier ?? "unknown")",
            "timeout": "\(timeout)",
          ])

        throw createApplicationLaunchError(
          message: "Application timed out while launching",
          context: [
            "bundleId": application.bundleIdentifier ?? "unknown",
            "applicationName": application.localizedName ?? "Unknown",
            "timeout": "\(timeout)",
          ],
        )
      }
    }

    // Check if the application has any windows
    // Note: Some applications might not immediately create windows, so we need to wait
    logger.debug("Checking for application windows")

    // Get the application element
    let appElement = AccessibilityElement.applicationElement(pid: application.processIdentifier)

    // Check if the application is responding to accessibility queries
    let startTime = Date()
    var isAccessible = false

    while !isAccessible, Date().timeIntervalSince(startTime) < timeout {
      // Try to get the role to check if accessibility is working
      if (try? AccessibilityElement.getAttribute(appElement, attribute: "AXRole")) != nil {
        isAccessible = true
        break
      }

      // Sleep briefly to avoid spinning
      try await Task.sleep(for: .milliseconds(200))
    }

    if !isAccessible {
      logger.warning(
        "Application is not responding to accessibility queries",
        metadata: [
          "bundleId": "\(application.bundleIdentifier ?? "unknown")",
          "applicationName": "\(application.localizedName ?? "Unknown")",
          "timeout": "\(timeout)",
        ])

      // Don't fail verification completely, just log the warning
    }

    // Check for windows
    var hasWindows = false
    let windowCheckStartTime = Date()

    while !hasWindows, Date().timeIntervalSince(windowCheckStartTime) < timeout {
      // Try to find windows
      if let children = try? AccessibilityElement
        .getAttribute(appElement, attribute: "AXChildren") as? [AXUIElement]
      {
        for child in children {
          if let role = try? AccessibilityElement.getAttribute(child, attribute: "AXRole")
            as? String,
            role == "AXWindow"
          {
            // Check if the window is visible
            if let visible = try? AccessibilityElement.getAttribute(child, attribute: "AXVisible")
              as? Bool,
              visible == true
            {
              hasWindows = true
              break
            }
          }
        }
      }

      if hasWindows {
        break
      }

      // Sleep briefly to avoid spinning
      try await Task.sleep(for: .milliseconds(200))
    }

    if !hasWindows {
      logger.debug(
        "No visible windows detected for application",
        metadata: [
          "bundleId": "\(application.bundleIdentifier ?? "unknown")",
          "applicationName": "\(application.localizedName ?? "Unknown")",
          "timeout": "\(timeout)",
        ])

      // Don't fail - some apps are legitimately windowless or windows may not be immediately visible to
      // accessibility APIs
    } else {
      logger.debug("Application has visible windows")
    }

    // Verification passed
    return true
  }

  /// Launch an application with the given URL and parameters
  /// - Parameters:
  ///   - url: The URL of the application to launch
  ///   - bundleId: The bundle identifier for logging/error reporting
  ///   - arguments: Optional arguments to pass to the application
  ///   - hideOthers: Whether to hide other applications
  ///   - verificationTimeout: Optional timeout for post-launch verification in seconds (default is 5)
  /// - Returns: Whether the launch was successful
  /// - Throws: MacMCPErrorInfo if the launch fails
  private func launchApplication(
    url: URL,
    bundleId: String,
    arguments: [String]? = nil,
    hideOthers: Bool? = nil,
    verificationTimeout: TimeInterval = 5,
  ) async throws -> Bool {
    // Create a configuration for launching the app
    let configuration = NSWorkspace.OpenConfiguration()

    // Set app launch arguments if provided
    if let arguments {
      configuration.arguments = arguments
    }

    // Set creation options
    configuration.createsNewApplicationInstance = false  // Only create a new instance if needed
    configuration.activates = true

    do {
      // Launch the application
      let runningApplication = try await NSWorkspace.shared.openApplication(
        at: url,
        configuration: configuration,
      )

      // If successful and hideOthers is true, hide other applications
      if hideOthers == true {
        NSWorkspace.shared.hideOtherApplications()
      }

      // Update the cache with the running application
      updateCacheForRunningApp(runningApplication)

      logger.debug(
        "Application launched, verifying initialization",
        metadata: [
          "bundleId": "\(bundleId)",
          "applicationName": "\(runningApplication.localizedName ?? "Unknown")",
          "processIdentifier": "\(runningApplication.processIdentifier)",
        ])

      // Verify the application is properly initialized
      let verified = try await verifyApplicationLaunch(
        runningApplication, timeout: verificationTimeout)

      logger.debug(
        "Application opened and verified successfully",
        metadata: [
          "bundleId": "\(bundleId)",
          "applicationName": "\(runningApplication.localizedName ?? "Unknown")",
          "processIdentifier": "\(runningApplication.processIdentifier)",
          "verified": "\(verified)",
        ])

      return true
    } catch {
      logger.error(
        "Failed to open application",
        metadata: [
          "bundleId": "\(bundleId)",
          "url": "\(url.path)",
          "error": "\(error.localizedDescription)",
        ])

      throw createApplicationLaunchError(
        message: "Failed to open application with bundle identifier: \(bundleId)",
        context: [
          "bundleId": bundleId,
          "applicationPath": url.path,
          "error": error.localizedDescription,
        ],
      )
    }
  }

  /// Validates and resolves an application by name
  /// - Parameter name: The name of the application to validate
  /// - Returns: ApplicationInfo with validated application details
  /// - Throws: MacMCPErrorInfo if the application cannot be found
  func validateApplicationByName(_ name: String) async throws -> ApplicationInfo {
    logger.debug(
      "Validating application by name",
      metadata: [
        "name": "\(name)"
      ])

    // First check if there's a known system app with this name
    let lowerName = name.lowercased()
    if let bundleId = knownSystemApps[lowerName] {
      logger.debug(
        "Found known system app",
        metadata: [
          "name": "\(name)",
          "bundleId": "\(bundleId)",
        ])

      // Try to validate by bundle ID
      return try await validateApplication(bundleId: bundleId)
    }

    // Try to find the application by name in our cache
    if let appInfo = await findApplicationByName(name) {
      // Verify the app still exists at the path
      if !FileManager.default.fileExists(atPath: appInfo.url.path) {
        logger.warning(
          "Cached application path no longer exists",
          metadata: [
            "name": "\(name)",
            "url": "\(appInfo.url.path)",
          ])

        // Clear from name cache
        nameToAppCache.removeValue(forKey: lowerName)

        // Force a cache refresh
        lastCacheRefresh = .distantPast

        // Try again with a refreshed cache
        if let refreshedAppInfo = await findApplicationByName(name) {
          return refreshedAppInfo
        }

        // Continue to fallback methods if not found
      } else {
        return appInfo
      }
    }

    // As a last resort, try the older method of searching for the app directly

    // Look for exact path in Applications directory
    let exactAppPath = "/Applications/\(name).app"
    if FileManager.default.fileExists(atPath: exactAppPath) {
      let url = URL(fileURLWithPath: exactAppPath)

      // Create app info and run full validation on the URL
      let appInfo = ApplicationInfo(url: url)
      return try await validateApplication(
        bundleId: appInfo.bundleId,
        url: url,
      )
    }

    // Search in the Applications directory
    var foundMatch: URL? = nil
    let appDir = URL(fileURLWithPath: "/Applications")

    do {
      let appFiles = try FileManager.default.contentsOfDirectory(
        at: appDir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles],
      ).filter { url in
        url.pathExtension.lowercased() == "app"
      }

      // Look for exact, prefix, and substring matches in order of preference
      foundMatch = appFiles.first { url in
        let filename = url.deletingPathExtension().lastPathComponent
        return filename.lowercased() == lowerName
      }

      if foundMatch == nil {
        foundMatch = appFiles.first { url in
          let filename = url.deletingPathExtension().lastPathComponent
          return filename.lowercased().hasPrefix(lowerName)
        }
      }

      if foundMatch == nil {
        foundMatch = appFiles.first { url in
          let filename = url.deletingPathExtension().lastPathComponent
          return filename.lowercased().contains(lowerName)
        }
      }

      if let matchURL = foundMatch {
        // Create app info and run full validation on the URL
        let appInfo = ApplicationInfo(url: matchURL)
        return try await validateApplication(
          bundleId: appInfo.bundleId,
          url: matchURL,
        )
      }
    } catch {
      logger.warning(
        "Failed to search Applications directory",
        metadata: [
          "error": "\(error.localizedDescription)"
        ])
      // Continue to try other methods
    }

    // Try system directories as well
    for systemPath in [
      "/System/Applications",
      "/System/Library/CoreServices",
      "/Applications/Utilities",
    ] {
      do {
        let systemAppDir = URL(fileURLWithPath: systemPath)
        let systemAppFiles = try FileManager.default.contentsOfDirectory(
          at: systemAppDir,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles],
        ).filter { url in
          url.pathExtension.lowercased() == "app"
        }

        // Look for matches in order of preference
        foundMatch = systemAppFiles.first { url in
          let filename = url.deletingPathExtension().lastPathComponent
          return filename.lowercased() == lowerName
        }

        if foundMatch == nil {
          foundMatch = systemAppFiles.first { url in
            let filename = url.deletingPathExtension().lastPathComponent
            return filename.lowercased().hasPrefix(lowerName)
          }
        }

        if foundMatch == nil {
          foundMatch = systemAppFiles.first { url in
            let filename = url.deletingPathExtension().lastPathComponent
            return filename.lowercased().contains(lowerName)
          }
        }

        if let matchURL = foundMatch {
          // Create app info and run full validation
          let appInfo = ApplicationInfo(url: matchURL)
          return try await validateApplication(
            bundleId: appInfo.bundleId,
            url: matchURL,
          )
        }
      } catch {
        // Just continue to the next directory
      }
    }

    // If we get here, we failed to find the application
    logger.error(
      "Application not found by name",
      metadata: [
        "name": "\(name)"
      ])

    throw createApplicationNotFoundError(
      message: "Application with name '\(name)' not found",
      context: [
        "applicationName": name,
        "searchAttempts": "Cache, Known System Apps, System Directories, Applications Directory",
      ],
    )
  }

  /// Opens an application by its name.
  /// - Parameters:
  ///   - name: The name of the application to open (e.g., "Safari")
  ///   - arguments: Optional array of command-line arguments to pass to the application
  ///   - hideOthers: Whether to hide other applications when opening this one
  /// - Returns: A boolean indicating whether the application was successfully opened
  /// - Throws: MacMCPErrorInfo if the application could not be opened
  public func openApplication(
    name: String,
    arguments: [String]? = nil,
    hideOthers: Bool? = nil,
  ) async throws -> Bool {
    logger.debug(
      "Opening application by name",
      metadata: [
        "name": "\(name)",
        "arguments": "\(arguments ?? [])",
        "hideOthers": "\(hideOthers ?? false)",
      ])

    // Validate the application first
    let appInfo = try await validateApplicationByName(name)

    // If the application is already running, activate it
    if appInfo.isRunning {
      logger.debug(
        "Application is already running, activating",
        metadata: [
          "name": "\(name)",
          "actualName": "\(appInfo.name)",
          "bundleId": "\(appInfo.bundleId)",
          "processId": "\(appInfo.processId ?? 0)",
        ])

      // If it has a bundle ID, activate it
      if !appInfo.bundleId.isEmpty {
        return try await activateApplication(bundleId: appInfo.bundleId)
      }
    }

    // Launch by URL
    return try await launchApplication(
      url: appInfo.url,
      bundleId: appInfo.bundleId,
      arguments: arguments,
      hideOthers: hideOthers,
    )
  }

  /// Activates an already running application by bringing it to the foreground.
  /// - Parameter bundleId: The bundle identifier of the application to activate
  /// - Returns: A boolean indicating whether the application was successfully activated
  /// - Throws: MacMCPErrorInfo if the application could not be activated
  public func activateApplication(bundleId: String) async throws -> Bool {
    logger.debug(
      "Activating application",
      metadata: [
        "bundleId": "\(bundleId)"
      ])

    // Check the cache for a running app with this bundle ID
    if let appInfo = await findApplicationByBundleID(bundleId), appInfo.isRunning,
      let pid = appInfo.processId
    {
      // Found in cache, try to activate by PID
      if let app = NSRunningApplication(processIdentifier: pid) {
        let success = app.activate(options: [])

        if success {
          logger.debug(
            "Application activated successfully from cache",
            metadata: [
              "bundleId": "\(bundleId)",
              "applicationName": "\(appInfo.name)",
              "processIdentifier": "\(pid)",
            ])
          return true
        }

        // If activation failed, continue to try other methods
        logger.warning(
          "Failed to activate application from cache",
          metadata: [
            "bundleId": "\(bundleId)",
            "processIdentifier": "\(pid)",
          ])
      }
    }

    // Fall back to legacy approach if cache lookup fails
    // Find all running applications with this bundle ID
    let runningApplications = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleId)

    if !runningApplications.isEmpty {
      // Activate the first running instance (usually there's only one)
      let application = runningApplications.first!
      let success = application.activate(options: [])

      // Update the cache with the running application
      updateCacheForRunningApp(application)

      if success {
        logger.debug(
          "Application activated successfully",
          metadata: [
            "bundleId": "\(bundleId)",
            "applicationName": "\(application.localizedName ?? "Unknown")",
            "processIdentifier": "\(application.processIdentifier)",
          ])
        return true
      } else {
        logger.error(
          "Failed to activate application",
          metadata: [
            "bundleId": "\(bundleId)"
          ])

        throw createApplicationError(
          message: "Failed to activate application with bundle identifier: \(bundleId)",
          context: ["bundleId": bundleId],
        )
      }
    }

    // If not running, try to launch it
    if let appInfo = await findApplicationByBundleID(bundleId) {
      logger.debug(
        "Application is not running, attempting to launch",
        metadata: [
          "bundleId": "\(bundleId)",
          "applicationName": "\(appInfo.name)",
        ])

      return try await launchApplication(
        url: appInfo.url,
        bundleId: bundleId,
        arguments: nil,
        hideOthers: nil,
      )
    }

    // Not found in cache or running applications
    logger.error(
      "No running application found to activate",
      metadata: [
        "bundleId": "\(bundleId)"
      ])

    throw createApplicationNotFoundError(
      message: "No running application found with bundle identifier: \(bundleId)",
      context: ["bundleId": bundleId],
    )
  }

  /// Returns a dictionary of running applications.
  /// - Returns: A dictionary mapping bundle identifiers to application names
  /// - Throws: MacMCPErrorInfo if the running applications could not be retrieved
  public func getRunningApplications() async throws -> [String: String] {
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

    logger.debug(
      "Found running applications",
      metadata: [
        "count": "\(runningApps.count)"
      ])

    return runningApps
  }

  /// Set up application state change notification observers
  private func configureApplicationObservers() {
    // Skip if already configured
    guard !observersConfigured else {
      return
    }

    logger.debug("Configuring application state observers")

    // Observe application launch notifications
    notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] notification in
      guard let self else { return }

      // Extract relevant data from notification
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty
      else {
        return
      }

      // Create a copy of app data to pass to the actor
      let appData = (
        bundleId: bundleId,
        name: app.localizedName ?? "",
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )

      // Call the actor method from a detached task
      Task.detached {
        await self.handleApplicationLaunch(appData)
      }
    }

    // Observe application termination notifications
    notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] notification in
      guard let self else { return }

      // Extract relevant data from notification
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty
      else {
        return
      }

      // Create a copy of app data to pass to the actor
      let appData = (
        bundleId: bundleId,
        name: app.localizedName ?? "",
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )

      // Call the actor method from a detached task
      Task.detached {
        await self.handleApplicationTermination(appData)
      }
    }

    // Observe application activation notifications
    notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] notification in
      guard let self else { return }

      // Extract relevant data from notification
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty
      else {
        return
      }

      // Create a copy of app data to pass to the actor
      let appData = (
        bundleId: bundleId,
        name: app.localizedName ?? "",
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )

      // Call the actor method from a detached task for activation
      Task.detached {
        await self.handleApplicationActivation(appData)
      }

      // When a new app is activated, the previous app is deactivated
      // Find the previously active app and send a deactivation notification
      Task.detached {
        await self.handlePreviousApplicationDeactivation(exceptApp: bundleId)
      }
    }

    // Observe application hiding notifications
    notificationCenter.addObserver(
      forName: NSWorkspace.didHideApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] notification in
      guard let self else { return }

      // Extract relevant data from notification
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty
      else {
        return
      }

      // Create a copy of app data to pass to the actor
      let appData = (
        bundleId: bundleId,
        name: app.localizedName ?? "",
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )

      // Call the actor method from a detached task
      Task.detached {
        await self.handleApplicationHiding(appData)
      }
    }

    // Observe application unhiding notifications
    notificationCenter.addObserver(
      forName: NSWorkspace.didUnhideApplicationNotification,
      object: nil,
      queue: .main,
    ) { [weak self] notification in
      guard let self else { return }

      // Extract relevant data from notification
      guard
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
          as? NSRunningApplication,
        let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty
      else {
        return
      }

      // Create a copy of app data to pass to the actor
      let appData = (
        bundleId: bundleId,
        name: app.localizedName ?? "",
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )

      // Call the actor method from a detached task
      Task.detached {
        await self.handleApplicationUnhiding(appData)
      }
    }

    observersConfigured = true
    logger.debug("Application state observers configured")
  }

  /// Handle application launch event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationLaunch(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application launch",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Find the actual running application to get real data
    let runningApplications = NSWorkspace.shared.runningApplications
    if let app = runningApplications.first(where: { $0.processIdentifier == appData.processId }) {
      // Update cache with real application data
      updateCacheForRunningApp(app)
    } else {
      // If we can't find the app (rare), use the URL to create application info
      if let url = appData.url {
        let appInfo = ApplicationInfo(url: url, bundleId: appData.bundleId)
        appCache[appData.bundleId] = appInfo
        nameToAppCache[appData.name.lowercased()] = appInfo
      }
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: true,
      processId: appData.processId,
      isActive: appData.isActive,
      isFinishedLaunching: appData.isFinishedLaunching,
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .launched,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Handle application termination event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationTermination(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application termination",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Get existing application info from cache if available
    if var existingAppInfo = appCache[appData.bundleId] {
      // Update to mark as not running
      existingAppInfo.processId = nil
      appCache[appData.bundleId] = existingAppInfo
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: false,
      processId: nil,  // Set to nil because the app is terminated
      isActive: false,  // Terminated app can't be active
      isFinishedLaunching: false,  // Terminated app isn't launched
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .terminated,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Handle application activation event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationActivation(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application activation",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Find the actual running application to get real data
    let runningApplications = NSWorkspace.shared.runningApplications
    if let app = runningApplications.first(where: { $0.processIdentifier == appData.processId }) {
      // Update cache with real application data
      updateCacheForRunningApp(app)
    } else {
      // If we can't find the app (rare), use the URL to create application info
      if let url = appData.url {
        let appInfo = ApplicationInfo(url: url, bundleId: appData.bundleId)
        appCache[appData.bundleId] = appInfo
        nameToAppCache[appData.name.lowercased()] = appInfo
      }
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: true,
      processId: appData.processId,
      isActive: true,  // It's being activated
      isFinishedLaunching: appData.isFinishedLaunching,
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .activated,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Handle application hiding event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationHiding(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application hiding",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Find the actual running application to get real data
    let runningApplications = NSWorkspace.shared.runningApplications
    if let app = runningApplications.first(where: { $0.processIdentifier == appData.processId }) {
      // Update cache with real application data
      updateCacheForRunningApp(app)
    } else {
      // If we can't find the app (rare), use the URL to create application info
      if let url = appData.url {
        let appInfo = ApplicationInfo(url: url, bundleId: appData.bundleId)
        appCache[appData.bundleId] = appInfo
        nameToAppCache[appData.name.lowercased()] = appInfo
      }
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: true,
      processId: appData.processId,
      isActive: false,  // Hidden app can't be active
      isFinishedLaunching: appData.isFinishedLaunching,
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .hidden,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Handle application unhiding event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationUnhiding(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application unhiding",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Find the actual running application to get real data
    let runningApplications = NSWorkspace.shared.runningApplications
    if let app = runningApplications.first(where: { $0.processIdentifier == appData.processId }) {
      // Update cache with real application data
      updateCacheForRunningApp(app)
    } else {
      // If we can't find the app (rare), use the URL to create application info
      if let url = appData.url {
        let appInfo = ApplicationInfo(url: url, bundleId: appData.bundleId)
        appCache[appData.bundleId] = appInfo
        nameToAppCache[appData.name.lowercased()] = appInfo
      }
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: true,
      processId: appData.processId,
      isActive: appData.isActive,
      isFinishedLaunching: appData.isFinishedLaunching,
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .unhidden,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Handle application deactivation event
  /// - Parameter appData: Tuple containing application data extracted from the notification
  private func handleApplicationDeactivation(
    _ appData: (
      bundleId: String,
      name: String,
      processId: Int32,
      isActive: Bool,
      isFinishedLaunching: Bool,
      url: URL?
    )
  ) {
    logger.debug(
      "Handling application deactivation",
      metadata: [
        "bundleId": "\(appData.bundleId)",
        "name": "\(appData.name)",
        "processId": "\(appData.processId)",
      ])

    // Find the actual running application to get real data
    let runningApplications = NSWorkspace.shared.runningApplications
    if let app = runningApplications.first(where: { $0.processIdentifier == appData.processId }) {
      // Update cache with real application data
      updateCacheForRunningApp(app)
    } else {
      // If we can't find the app (rare), use the URL to create application info
      if let url = appData.url {
        let appInfo = ApplicationInfo(url: url, bundleId: appData.bundleId)
        appCache[appData.bundleId] = appInfo
        nameToAppCache[appData.name.lowercased()] = appInfo
      }
    }

    // Create application state info for the notification
    let stateInfo = ApplicationStateInfo(
      bundleId: appData.bundleId,
      name: appData.name,
      isRunning: true,
      processId: appData.processId,
      isActive: false,  // It's being deactivated
      isFinishedLaunching: appData.isFinishedLaunching,
      url: appData.url,
    )

    // Create state change notification
    let stateChange = ApplicationStateChange(
      type: .deactivated,
      application: stateInfo,
    )

    // Notify all observers
    Task {
      for (_, handler) in applicationObservers {
        await handler(stateChange)
      }
    }
  }

  /// Find the previously active application and send deactivation notification
  /// - Parameter exceptApp: The bundle ID of the app to exclude (usually the newly activated app)
  private func handlePreviousApplicationDeactivation(exceptApp: String) async {
    logger.debug("Finding previously active application for deactivation notification")

    // First, get all running applications that might have been active
    let runningApps = NSWorkspace.shared.runningApplications

    // Look for applications that are no longer active but might have been
    for app in runningApps where app.activationPolicy == .regular {
      // Skip the app that was just activated
      guard let bundleId = app.bundleIdentifier,
        !bundleId.isEmpty,
        bundleId != exceptApp
      else {
        continue
      }

      // If the app is not currently active but is running, assume it was deactivated
      if !app.isActive {
        logger.debug(
          "Found previously active application",
          metadata: [
            "bundleId": "\(bundleId)",
            "name": "\(app.localizedName ?? "")",
          ])

        // Create app data tuple to pass to the deactivation handler
        let appData = (
          bundleId: bundleId,
          name: app.localizedName ?? "",
          processId: app.processIdentifier,
          isActive: false,  // It's now inactive
          isFinishedLaunching: app.isFinishedLaunching,
          url: app.bundleURL,
        )

        // Handle the deactivation
        handleApplicationDeactivation(appData)

        // Only deactivate one app (the most recently active one)
        break
      }
    }
  }

  /// Start observing application state changes.
  /// - Parameter notificationHandler: The handler to call when applications launch or terminate
  /// - Returns: A unique identifier for this observation that can be used to stop it
  /// - Throws: MacMCPErrorInfo if the observation could not be started
  public func startObservingApplications(
    notificationHandler: @escaping @Sendable (ApplicationStateChange) async
      -> Void,
  ) async throws -> String {
    // Configure observers if needed
    configureApplicationObservers()

    // Generate a unique identifier for this observer
    let observerId = UUID().uuidString

    // Store the handler
    applicationObservers[observerId] = notificationHandler

    logger.debug(
      "Started observing application state changes",
      metadata: [
        "observerId": "\(observerId)",
        "activeObservers": "\(applicationObservers.count)",
      ])

    return observerId
  }

  /// Stop observing application state changes.
  /// - Parameter observerId: The identifier of the observation to stop
  /// - Throws: MacMCPErrorInfo if the observation could not be stopped
  public func stopObservingApplications(observerId: String) async throws {
    // Remove the observer
    if applicationObservers.removeValue(forKey: observerId) != nil {
      logger.debug(
        "Stopped observing application state changes",
        metadata: [
          "observerId": "\(observerId)",
          "activeObservers": "\(applicationObservers.count)",
        ])
    } else {
      logger.warning(
        "Observer not found",
        metadata: [
          "observerId": "\(observerId)"
        ])

      throw NSError(
        domain: "com.macos.mcp.applicationService",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Observer ID not found: \(observerId)"],
      )
    }
  }

  /// Check if an application is running.
  /// - Parameter bundleId: The bundle identifier of the application to check
  /// - Returns: True if the application is running, false otherwise
  /// - Throws: MacMCPErrorInfo if the check fails
  public func isApplicationRunning(bundleId: String) async throws -> Bool {
    // Check if it's in our cache
    if let appInfo = await findApplicationByBundleID(bundleId) {
      return appInfo.isRunning
    }

    // Check directly with NSRunningApplication as a fallback
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleId)
    return !runningApps.isEmpty
  }

  /// Get information about a running application.
  /// - Parameter bundleId: The bundle identifier of the application
  /// - Returns: Application information, or nil if the application is not running
  /// - Throws: MacMCPErrorInfo if the information could not be retrieved
  public func getApplicationInfo(bundleId: String) async throws -> ApplicationStateInfo? {
    // Check if it's in our cache
    if let appInfo = await findApplicationByBundleID(bundleId) {
      if appInfo.isRunning {
        // Find the application in the system to get the most up-to-date information
        if let pid = appInfo.processId,
          let app = NSRunningApplication(processIdentifier: pid)
        {
          // Return detailed information
          return ApplicationStateInfo(
            bundleId: bundleId,
            name: app.localizedName ?? appInfo.name,
            isRunning: true,
            processId: app.processIdentifier,
            isActive: app.isActive,
            isFinishedLaunching: app.isFinishedLaunching,
            url: app.bundleURL ?? appInfo.url,
          )
        }
      }
    }

    // Check directly with NSRunningApplication as a fallback
    let runningApps = NSRunningApplication.runningApplications(
      withBundleIdentifier: bundleId)
    if let app = runningApps.first {
      // Update our cache
      updateCacheForRunningApp(app)

      // Return detailed information
      return ApplicationStateInfo(
        bundleId: bundleId,
        name: app.localizedName ?? "",
        isRunning: true,
        processId: app.processIdentifier,
        isActive: app.isActive,
        isFinishedLaunching: app.isFinishedLaunching,
        url: app.bundleURL,
      )
    }

    // Application is not running
    return nil
  }
}
