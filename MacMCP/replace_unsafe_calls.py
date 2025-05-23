#!/usr/bin/env python3

"""
Script to replace unsafe AXUIElementCopyAttributeValue calls with SafeAttributeAccess methods.

This script identifies patterns and suggests replacements for the 106+ direct calls
scattered throughout the codebase.
"""

import re
import os
import sys
from pathlib import Path

def analyze_patterns(file_path):
    """Analyze a Swift file for unsafe attribute access patterns."""
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Pattern for direct AXUIElementCopyAttributeValue calls
    pattern = r'AXUIElementCopyAttributeValue\(([^,]+),\s*"([^"]+)"\s*as\s*CFString,\s*&([^)]+)\)'
    
    matches = re.finditer(pattern, content)
    
    results = []
    for match in matches:
        element = match.group(1).strip()
        attribute = match.group(2)
        var_ref = match.group(3).strip()
        
        # Get some context around the match
        start = max(0, match.start() - 100)
        end = min(len(content), match.end() + 100)
        context = content[start:end]
        
        results.append({
            'element': element,
            'attribute': attribute,
            'var_ref': var_ref,
            'full_match': match.group(0),
            'context': context,
            'start': match.start(),
            'end': match.end()
        })
    
    return results

def suggest_replacement(match_info):
    """Suggest a SafeAttributeAccess replacement for a match."""
    
    attribute = match_info['attribute']
    element = match_info['element']
    
    # Common attribute type mappings
    if attribute in ['AXChildren', 'AXWindows', 'AXMenus', 'AXTabs']:
        return f"SafeAttributeAccess.getArrayAttribute({element}, attribute: \"{attribute}\")"
    elif attribute in ['AXRole', 'AXTitle', 'AXDescription', 'AXIdentifier', 'AXValue']:
        return f"SafeAttributeAccess.getStringAttribute({element}, attribute: \"{attribute}\")"
    elif attribute in ['AXEnabled', 'AXFocused', 'AXSelected', 'AXHidden', 'AXVisible']:
        return f"SafeAttributeAccess.getBoolAttribute({element}, attribute: \"{attribute}\")"
    elif attribute in ['AXFrame']:
        return f"SafeAttributeAccess.getRectAttribute({element}, attribute: \"{attribute}\")"
    elif attribute in ['AXPosition']:
        return f"SafeAttributeAccess.getPointAttribute({element}, attribute: \"{attribute}\")"
    elif attribute in ['AXSize']:
        return f"SafeAttributeAccess.getSizeAttribute({element}, attribute: \"{attribute}\")"
    else:
        return f"SafeAttributeAccess.getAttribute({element}, attribute: \"{attribute}\")"

def main():
    """Main function to analyze and suggest replacements."""
    
    if len(sys.argv) != 2:
        print("Usage: python3 replace_unsafe_calls.py <source_directory>")
        sys.exit(1)
    
    source_dir = Path(sys.argv[1])
    
    if not source_dir.exists():
        print(f"Directory {source_dir} does not exist")
        sys.exit(1)
    
    # Find all Swift files
    swift_files = list(source_dir.rglob("*.swift"))
    
    print(f"Analyzing {len(swift_files)} Swift files...")
    
    total_matches = 0
    
    for swift_file in swift_files:
        matches = analyze_patterns(swift_file)
        
        if matches:
            print(f"\n=== {swift_file.relative_to(source_dir)} ===")
            print(f"Found {len(matches)} unsafe calls:")
            
            for i, match in enumerate(matches, 1):
                print(f"\n{i}. Line area around unsafe call:")
                print(f"   Attribute: {match['attribute']}")
                print(f"   Element: {match['element']}")
                print(f"   Current: {match['full_match']}")
                print(f"   Suggested: {suggest_replacement(match)}")
                
                # Show context with line numbers (approximate)
                lines_before = match['context'][:match['context'].find(match['full_match'])].count('\n')
                print(f"   Context: ...{match['context'].strip()[:100]}...")
            
            total_matches += len(matches)
    
    print(f"\n=== SUMMARY ===")
    print(f"Total unsafe calls found: {total_matches}")
    print(f"Files affected: {len([f for f in swift_files if analyze_patterns(f)])}")
    
    print(f"\nNext steps:")
    print(f"1. Review suggestions above")
    print(f"2. Update SafeAttributeAccess.swift if needed")  
    print(f"3. Replace calls systematically, testing as you go")
    print(f"4. Focus on high-impact files first (UIInteractionService, ElementPath)")

if __name__ == "__main__":
    main()