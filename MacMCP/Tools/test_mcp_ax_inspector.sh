#!/bin/bash
# Test script for mcp-ax-inspector path features

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Path to the mcp-ax-inspector executable
INSPECTOR="./.build/debug/mcp-ax-inspector"
APP_ID="com.apple.calculator"
OUTPUT_DIR="./test-output"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to run a test and save output
run_test() {
    local test_name="$1"
    local command="$2"
    local output_file="$OUTPUT_DIR/${test_name}.txt"
    
    echo -e "${YELLOW}Running test: ${test_name}${NC}"
    echo "Command: $command"
    echo "Saving output to: $output_file"
    
    # Run the command and save output
    eval "$command" > "$output_file"
    
    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Test completed successfully!${NC}"
        # Get the file size
        local size=$(wc -l < "$output_file")
        echo "Output has $size lines"
    else
        echo -e "\033[0;31mTest failed!${NC}"
    fi
    echo ""
}

# Basic test: show Calculator UI
run_test "basic" "$INSPECTOR --app-id $APP_ID --max-depth 20"

# Test showing paths
run_test "show_paths" "$INSPECTOR --app-id $APP_ID --show-paths --max-depth 20"

# Test highlighting paths
run_test "highlight_paths" "$INSPECTOR --app-id $APP_ID --highlight-paths --max-depth 20"

# Test filtering by path
run_test "path_filter_button" "$INSPECTOR --app-id $APP_ID --path-filter 'AXButton'"

# Test filtering by path with attribute
run_test "path_filter_attribute" "$INSPECTOR --app-id $APP_ID --path-filter '[@AXDescription=\"7\"]'"

# Test interactive paths
run_test "interactive_paths" "$INSPECTOR --app-id $APP_ID --interactive-paths"

# Test combining multiple path options
run_test "combined_path_options" "$INSPECTOR --app-id $APP_ID --interactive-paths --highlight-paths"

# Test path filter with other filters
run_test "path_with_other_filters" "$INSPECTOR --app-id $APP_ID --path-filter 'AXButton' --hide-invisible"

echo -e "${GREEN}All tests completed!${NC}"
echo "Test outputs saved to: $OUTPUT_DIR"
echo "Review the output files to verify the correct functioning of path features."