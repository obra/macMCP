// ABOUTME: This file implements the base testing harness for MacMCP tools.
// ABOUTME: It provides service initialization and tool creation functionality.

import Foundation
import Logging
@testable import MacMCP

/// Base class for testing MCP tools directly
public class ToolTestHarness {
    // Common services used by tools
    public let accessibilityService: AccessibilityService
    public let applicationService: ApplicationService
    public let screenshotService: ScreenshotService
    public let interactionService: UIInteractionService
    
    // Logger that can be inspected in tests
    public let logger: Logger
    public let testHandler: TestLogHandler
    
    /// Initialize the test harness with optional services
    /// - Parameters:
    ///   - accessibilityService: Optional accessibility service to use
    ///   - applicationService: Optional application service to use
    ///   - screenshotService: Optional screenshot service to use
    ///   - interactionService: Optional interaction service to use
    ///   - logger: Optional logger to use
    public init(
        accessibilityService: AccessibilityService? = nil,
        applicationService: ApplicationService? = nil,
        screenshotService: ScreenshotService? = nil,
        interactionService: UIInteractionService? = nil,
        logger: Logger? = nil,
        testHandler: TestLogHandler? = nil
    ) {
        // If logger is provided, use it; otherwise create a test logger
        if let logger = logger, let testHandler = testHandler {
            self.logger = logger
            self.testHandler = testHandler
        } else {
            let (log, handler) = Logger.testLogger(label: "test.harness")
            self.logger = log
            self.testHandler = handler
        }
        
        // Create or use provided services
        self.accessibilityService = accessibilityService ?? AccessibilityService(logger: self.logger)
        self.applicationService = applicationService ?? ApplicationService(logger: self.logger)
        
        let accService = self.accessibilityService
        
        // For screenshot and interaction services, we need to provide the accessibility service
        if let screenshotService = screenshotService {
            self.screenshotService = screenshotService
        } else {
            self.screenshotService = ScreenshotService(
                accessibilityService: accService,
                logger: self.logger
            )
        }
        
        if let interactionService = interactionService {
            self.interactionService = interactionService
        } else {
            self.interactionService = UIInteractionService(
                accessibilityService: accService,
                logger: self.logger
            )
        }
    }
    
    /// Creates a UIStateTool instance
    /// - Returns: A configured UIStateTool
    public func createUIStateTool() -> UIStateTool {
        return UIStateTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    /// Creates a ScreenshotTool instance
    /// - Returns: A configured ScreenshotTool
    public func createScreenshotTool() -> ScreenshotTool {
        return ScreenshotTool(
            screenshotService: screenshotService,
            logger: logger
        )
    }
    
    /// Creates a UIInteractionTool instance
    /// - Returns: A configured UIInteractionTool
    public func createUIInteractionTool() -> UIInteractionTool {
        return UIInteractionTool(
            interactionService: interactionService,
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    /// Creates an OpenApplicationTool instance
    /// - Returns: A configured OpenApplicationTool
    public func createOpenApplicationTool() -> OpenApplicationTool {
        return OpenApplicationTool(
            applicationService: applicationService,
            logger: logger
        )
    }
    
    /// Creates a WindowManagementTool instance
    /// - Returns: A configured WindowManagementTool
    public func createWindowManagementTool() -> WindowManagementTool {
        return WindowManagementTool(
            accessibilityService: accessibilityService,
            logger: logger
        )
    }
    
    /// Creates a MenuNavigationTool instance
    /// - Returns: A configured MenuNavigationTool
    public func createMenuNavigationTool() -> MenuNavigationTool {
        return MenuNavigationTool(
            accessibilityService: accessibilityService,
            interactionService: interactionService,
            logger: logger
        )
    }
    
    /// Creates a test application driver for a specific application type
    /// - Parameter appType: The type of application to create a driver for
    /// - Returns: A configured application driver
    public func createApplicationDriver(_ appType: ApplicationDrivers.TestApplicationType) -> TestApplicationDriver {
        switch appType {
        case .calculator:
            return CalculatorDriver(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .textEdit:
            return TextEditDriver(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        case .safari:
            return SafariDriver(
                applicationService: applicationService,
                accessibilityService: accessibilityService,
                interactionService: interactionService
            )
        }
    }
    
    /// Create a calculator driver
    /// - Returns: A configured calculator driver
    public func createCalculatorDriver() -> CalculatorDriver {
        return CalculatorDriver(
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Create a TextEdit driver
    /// - Returns: A configured TextEdit driver
    public func createTextEditDriver() -> TextEditDriver {
        return TextEditDriver(
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
    
    /// Create a Safari driver
    /// - Returns: A configured Safari driver
    public func createSafariDriver() -> SafariDriver {
        return SafariDriver(
            applicationService: applicationService,
            accessibilityService: accessibilityService,
            interactionService: interactionService
        )
    }
}