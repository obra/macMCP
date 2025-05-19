# MacMCPUtilities Guide

This document provides an overview of the `MacMCPUtilities` library, which contains shared utility functionality used across the MacMCP project.

## Overview

`MacMCPUtilities` is a library target within the MacMCP package that provides common utility functions, standardizing implementation patterns across different parts of the codebase. It's designed to centralize frequently used functionality to improve consistency and reduce code duplication.

## Available Utilities

### PathNormalizer

The `PathNormalizer` class provides utilities for standardizing and normalizing UI element paths.

#### Purpose

Path-based element identification is the primary method for referencing UI elements in MacMCP. The `PathNormalizer` ensures consistent formatting and handling of these paths by:

1. Standardizing attribute names
2. Properly escaping special characters in attribute values
3. Normalizing path formats

#### Key Functions

```swift
// Convert attribute names to their standard form (e.g., "title" → "AXTitle")
static func normalizeAttributeName(_ name: String) -> String

// Properly escape special characters in attribute values
static func escapeAttributeValue(_ value: String) -> String

// Unescape previously escaped attribute values
static func unescapeAttributeValue(_ value: String) -> String

// Normalize a complete path string
static func normalizePathString(_ path: String) -> String?
```

#### Attribute Name Standardization

The PathNormalizer standardizes common attribute names to ensure consistency:

| Common Name   | Standardized Name |
|---------------|-------------------|
| title         | AXTitle           |
| description   | AXDescription     |
| value         | AXValue           |
| id/identifier | AXIdentifier      |
| help          | AXHelp            |
| enabled       | AXEnabled         |
| focused       | AXFocused         |
| selected      | AXSelected        |
| bundleId      | bundleIdentifier  |

#### Special Character Escaping

When working with paths, attribute values that contain special characters are properly escaped:

- Quotes: `"` → `\"`
- Backslashes: `\` → `\\`
- Control characters: `\n` → `\\n`, `\t` → `\\t`, `\r` → `\\r`

#### Usage Example

```swift
// Normalize an attribute name
let normalizedName = PathNormalizer.normalizeAttributeName("title")
// Result: "AXTitle"

// Escape an attribute value with special characters
let escapedValue = PathNormalizer.escapeAttributeValue("Button with \"quotes\"")
// Result: "Button with \\\"quotes\\\""

// Normalize a complete path
let path = "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXDescription=\"OK\"]"
let normalizedPath = PathNormalizer.normalizePathString(path)
// Result: "ui://AXWindow/AXGroup[@AXTitle=\"Controls\"]/AXButton[@AXDescription=\"OK\"]"
```

## When to Use MacMCPUtilities

Use the utilities in this library when:

1. You need to work with path-based element identifiers
2. You need to ensure consistent handling of attributes and paths
3. You're implementing functionality that might be needed in multiple parts of the codebase

## Future Utilities

As the project evolves, more utilities will be added to `MacMCPUtilities` to standardize common patterns. This helps maintain a clean and consistent codebase.