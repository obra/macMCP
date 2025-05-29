#!/bin/bash

# ABOUTME: Script to check code formatting and linting without making changes
# ABOUTME: Useful for CI/CD and pre-commit validation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 Checking Swift code formatting and linting..."

cd "$PROJECT_ROOT"

# Check formatting with SwiftFormat (without changing files)
if command -v swiftformat &> /dev/null; then
    echo "📏 Checking code formatting..."
    
    # Use SwiftFormat --lint to check for formatting issues
    if swiftformat MacMCP/Sources MacMCP/Tests MacMCP/Tools --config .swiftformat --lint; then
        echo "✅ Code formatting is correct"
    else
        echo "❌ Formatting issues found"
        echo "Run ./scripts/format.sh to fix formatting issues"
        exit 1
    fi
else
    echo "⚠️  SwiftFormat not found. Install with: brew install swiftformat"
fi

# Run SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "🚨 Running SwiftLint..."
    swiftlint --config .swiftlint.yml --strict
    echo "✅ SwiftLint passed"
else
    echo "❌ SwiftLint not found. Install with: brew install swiftlint"
    exit 1
fi

echo "🎉 All checks passed!"