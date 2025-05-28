#!/bin/bash

# ABOUTME: Script to format Swift code using swift-format and check with SwiftLint
# ABOUTME: Provides unified formatting workflow for the project

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🎨 Formatting Swift code..."

# Check if swift-format is available
if ! command -v swift-format &> /dev/null; then
    echo "❌ swift-format not found. Install with: brew install swift-format"
    exit 1
fi

# Format all Swift files
find "$PROJECT_ROOT/MacMCP/Sources" -name "*.swift" -exec swift-format --configuration "$PROJECT_ROOT/.swift-format" -i {} \;
find "$PROJECT_ROOT/MacMCP/Tests" -name "*.swift" -exec swift-format --configuration "$PROJECT_ROOT/.swift-format" -i {} \;
find "$PROJECT_ROOT/MacMCP/Tools" -name "*.swift" -exec swift-format --configuration "$PROJECT_ROOT/.swift-format" -i {} \;

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