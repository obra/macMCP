# MacMCP - macOS Accessibility Model Context Protocol Server


# HEADS UP. THIS IS AN INCREDIBLY DANGEROUS TOOL.

## BY DEFINITION, THIS IS GIVING AN LLM THE ABILITY TO DO ANYTHING YOUR MAC CAN DO. AS YOU.

## THINK LONG AND HARD BEFORE YOU DECIDE TO YOLO AND RUN IT ON A MAC THAT HAS PERMISSION TO DO....ANYTHING.




⚠️ **IMPORTANT DISCLAIMERS** ⚠️
- **This project needs a better name** - "MacMCP" is a placeholder
- **Largely untested in production** - Use at your own risk
- **This README was written by an LLM** - Content may be inaccurate or incomplete
- **Caveat emptor** - Buyer beware, use with caution

MacMCP is a Model Context Protocol (MCP) server that exposes macOS accessibility APIs to Large Language Models (LLMs) over the stdio protocol. It enables LLMs like Claude to interact with macOS applications using the same accessibility APIs available to users, allowing them to perform user-level tasks such as browsing the web, creating presentations, working with spreadsheets, or using messaging applications.

## Features

### Core Capabilities
- **UI Exploration**: Discover and analyze macOS application interfaces
- **UI Interaction**: Click, type, scroll, and interact with UI elements
- **Screenshot Capture**: Take screenshots of the screen or specific UI elements  
- **Application Management**: Launch and manage macOS applications
- **Window Management**: Move, resize, minimize, and maximize application windows
- **Menu Navigation**: Navigate application menus and activate menu items
- **Keyboard Interaction**: Execute keyboard shortcuts and type text
- **Clipboard Management**: Manage clipboard content including text and images

### Accessibility Tools
- **Interface Explorer**: Enhanced UI exploration with state and capabilities information
- **Screenshot Tool**: Capture screenshots for visual context
- **UI Interaction Tool**: Perform precise UI interactions
- **Application Tool**: Open and manage applications
- **Window Management Tool**: Control window positioning and state
- **Menu Navigation Tool**: Access application menu systems
- **Keyboard Tool**: Send keyboard input and shortcuts
- **Clipboard Tool**: Read and write clipboard content

## Requirements

- **macOS**: 13.0 or later
- **Swift**: 6.1 or later  
- **Accessibility Permissions**: Required for UI interaction functionality

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd MacMCP
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. Build for release (recommended for production):
   ```bash
   swift build -c release
   ```

### Grant Accessibility Permissions

MacMCP requires accessibility permissions to interact with UI elements:

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Add the MacMCP executable to the list of allowed applications
3. Verify permissions with:
   ```bash
   swift run check_permissions
   ```

## Usage

### Running the Server

```bash
# Debug build
./.build/debug/MacMCP

# Release build  
./.build/release/MacMCP

# With debug logging
./.build/debug/MacMCP --debug
```

### Integration with Claude Desktop

MacMCP is designed to work with Claude Desktop and other MCP-compatible clients. Configure your MCP client to use MacMCP as a stdio-based server.

## Development

### Project Structure

```
Sources/MacMCP/
├── Accessibility/          # Core accessibility services
├── Models/                 # Data models and shared types
├── Server/                 # MCP server implementation
├── Tools/                  # MCP tools for LLM interaction
├── Utilities/              # Helper utilities and extensions
└── main.swift             # Application entry point

Tools/
├── AccessibilityInspector/     # Native accessibility inspector
└── MCPAccessibilityInspector/  # MCP-based inspector (recommended)
```

### Accessibility Inspector Tools

MacMCP provides two accessibility inspector tools for debugging and development:

#### MCP-Based Inspector (Recommended)
Shows exactly what the MCP server sees and provides to LLMs:

```bash
# Build the tools
swift build

# Inspect an application
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP

# Filter by element type
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --filter "role=AXButton"

# Explore application menus
./.build/debug/mcp-ax-inspector --app-id com.apple.TextEdit --mcp-path ./.build/debug/MacMCP --menu-detail

# Get window information
./.build/debug/mcp-ax-inspector --app-id com.apple.calculator --mcp-path ./.build/debug/MacMCP --window-detail
```

#### Native Inspector
Provides direct access to macOS accessibility APIs:

```bash
# Inspect application directly
./.build/debug/ax-inspector --app-id com.apple.calculator

# Filter and save output
./.build/debug/ax-inspector --app-id com.apple.calculator --filter "role=button" --save output.txt
```

### Testing

MacMCP uses a comprehensive testing approach with real application interaction:

```bash
# Run all tests (must be serialized for UI tests)
swift test --no-parallel

# Run specific test
swift test --filter BasicArithmeticTest --no-parallel

# Run with verbose output
swift test --verbose --no-parallel

# Run with code coverage
swift test --no-parallel --enable-code-coverage
```

#### Test Categories

1. **TestsWithMocks**: Unit tests with mocked dependencies
2. **TestsWithoutMocks**: Integration tests with real macOS applications

Tests interact with real applications like Calculator and TextEdit to ensure accessibility features work correctly in practice.

### Development Workflow

1. **Explore UI**: Use the MCP-based inspector to understand application structure
2. **Write Tests**: Create tests that define expected functionality (TDD approach)
3. **Implement**: Build features using the established patterns
4. **Verify**: Run tests to ensure functionality works with real applications

## Architecture

### Core Components

- **MCPServer**: Central server managing MCP protocol and tool registration
- **Accessibility Services**: Core services for UI interaction, screenshots, and application management
- **MCP Tools**: Individual tools exposed to LLMs for specific functionality
- **Models**: Data structures representing UI elements and system state
- **Utilities**: Helper functions for error handling, logging, and common operations

### Key Principles

1. **Real Interaction**: No mocks - always interact with real macOS APIs
2. **Accessibility First**: Built on macOS accessibility APIs for robust UI interaction  
3. **Test-Driven**: Comprehensive testing with real applications
4. **Error Resilience**: Proper error handling and graceful degradation
5. **LLM-Friendly**: Designed for optimal LLM interaction patterns

## Contributing

1. Follow the existing code style and patterns
2. Write comprehensive tests for new functionality
3. Use the accessibility inspector tools to understand UI structure
4. Ensure all tests pass with `swift test --no-parallel`
5. Document new tools and significant functionality changes

## License

[License information to be added]

## Support

For issues and questions:
- Check the `docs/` directory for detailed documentation
- Use the accessibility inspector tools for debugging UI interactions
- Review test cases for usage examples
- File issues with detailed reproduction steps
