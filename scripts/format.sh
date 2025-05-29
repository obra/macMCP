#!/bin/bash

# ABOUTME: Script to format Swift code using swift-format and check with SwiftLint
# ABOUTME: Provides unified formatting workflow for the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🎨 Formatting Swift code..."

# Check if SwiftFormat is available
if ! command -v swiftformat &> /dev/null; then
    echo "❌ SwiftFormat not found. Install with: brew install swiftformat"
    exit 1
fi

# Format all Swift files using SwiftFormat
swiftformat "$PROJECT_ROOT/MacMCP/Sources" "$PROJECT_ROOT/MacMCP/Tests" "$PROJECT_ROOT/MacMCP/Tools" --config "$PROJECT_ROOT/.swiftformat"

echo "✅ Swift code formatted successfully"

# Run SwiftLint to check for remaining issues
echo "🔍 Running SwiftLint..."
cd "$PROJECT_ROOT"

if command -v swiftlint &> /dev/null; then
    swiftlint --config .swiftlint.yml
    echo "✅ SwiftLint check completed"
else
    echo "⚠️  SwiftLint not found. Install with: brew install swiftlint"
fi