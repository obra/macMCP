#!/bin/bash
# Script to remove test files that have been migrated to new test directories

# List of files to remove
rm -f ./Tests/MacMCPTests/ApplicationTests/ApplicationManagementE2ETests.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/CalculatorTests/BasicArithmeticTest.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/CalculatorTests/CalculatorSmokeTest.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/CalculatorTests/SimpleCalculatorTest.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/ClipboardManagementE2ETests.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/TextEditTests/SimpleTextEditTest.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/TextEditTests/TextEditFormattingTest.swift
rm -f ./Tests/MacMCPTests/ApplicationTests/WindowManagementE2ETests.swift
rm -f ./Tests/MacMCPTests/MenuNavigationCalculatorTest.swift
rm -f ./Tests/MacMCPTests/Mocks/MockClipboardService.swift
rm -f ./Tests/MacMCPTests/ScreenshotToolE2ETests.swift
rm -f ./Tests/MacMCPTests/ToolTests/ApplicationManagementToolTests.swift
rm -f ./Tests/MacMCPTests/ToolTests/ClipboardManagementToolTests.swift
rm -f ./Tests/MacMCPTests/ToolTests/InterfaceExplorerToolTests.swift
rm -f ./Tests/MacMCPTests/ToolTests/WindowManagementToolTests.swift
rm -f ./Tests/MacMCPTests/UIInteractionToolE2ETests.swift

# Newly migrated tests
rm -f ./Tests/MacMCPTests/AccessibilityTests.swift
rm -f ./Tests/MacMCPTests/ActionLoggingTests.swift
rm -f ./Tests/MacMCPTests/ApplicationActivationTest.swift
rm -f ./Tests/MacMCPTests/ErrorHandlingTests.swift
rm -f ./Tests/MacMCPTests/KeyboardInteractionToolTests.swift
rm -f ./Tests/MacMCPTests/MenuNavigationTests.swift
rm -f ./Tests/MacMCPTests/UIElementTests.swift

echo "Migrated test files have been removed."