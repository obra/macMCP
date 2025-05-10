# Keyboard Interaction Tool Specification

## Overview

The Keyboard Interaction Tool provides a high-level API for sending keyboard events to macOS applications through the MCP. It offers intuitive commands for typing text and executing key sequences, with support for modifiers and precise timing control.

## Tool Name

`keyboard_interaction`

## Actions

The tool supports two primary actions:

1. **type_text**: Type a string of text with standard timing
2. **key_sequence**: Execute a sequence of key events with precise control

## API Reference

### `type_text` Action

Types a string of text with standard timing between keystrokes.

**Parameters:**

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `text` | string | Text to type | Yes |

**Example:**

```json
{
  "action": "type_text",
  "text": "Hello world!"
}
```

### `key_sequence` Action

Executes a sequence of keyboard events with precise control.

**Parameters:**

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `sequence` | array | Array of key event objects | Yes |

Each object in the sequence array must be one of the following types:

#### Press Event

Press a key down and hold it (without releasing).

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `press` | string | Key to press down | Yes |
| `modifiers` | array | Modifier keys active during this event | No |

#### Release Event

Release a key that was previously pressed.

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `release` | string | Key to release | Yes |

#### Tap Event

Press and immediately release a key (shorthand for press+release).

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `tap` | string | Key to tap | Yes |
| `modifiers` | array | Modifier keys to hold during the tap | No |

#### Delay Event

Insert a pause in the sequence.

| Name | Type | Description | Required |
| ---- | ---- | ----------- | -------- |
| `delay` | number | Time to wait in seconds | Yes |

**Example:**

```json
{
  "action": "key_sequence",
  "sequence": [
    {"press": "command"},
    {"tap": "tab"},
    {"delay": 0.2},
    {"tap": "tab"},
    {"release": "command"}
  ]
}
```

## Key Names

The tool accepts the following key names:

### Letter Keys
`a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i`, `j`, `k`, `l`, `m`, `n`, `o`, `p`, `q`, `r`, `s`, `t`, `u`, `v`, `w`, `x`, `y`, `z`

### Number Keys
`0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`, `8`, `9`

### Special Keys
`space`, `return`, `tab`, `escape`, `delete`, `forwarddelete`

### Arrow Keys
`left`, `right`, `up`, `down`

### Function Keys
`f1`, `f2`, `f3`, `f4`, `f5`, `f6`, `f7`, `f8`, `f9`, `f10`, `f11`, `f12`

### Modifier Keys
`command`, `shift`, `option`, `control`

### Symbol Keys
`-` (minus), `=` (equals), `[` (left bracket), `]` (right bracket), `\` (backslash), `;` (semicolon), `'` (quote), `,` (comma), `.` (period), `/` (slash)

## Usage Examples

### Example 1: Save a document (Command+S)

```json
{
  "action": "key_sequence",
  "sequence": [
    {"tap": "s", "modifiers": ["command"]}
  ]
}
```

### Example 2: Select All and Copy (Command+A, Command+C)

```json
{
  "action": "key_sequence",
  "sequence": [
    {"tap": "a", "modifiers": ["command"]},
    {"delay": 0.2},
    {"tap": "c", "modifiers": ["command"]}
  ]
}
```

### Example 3: Type text with special formatting

```json
{
  "action": "key_sequence",
  "sequence": [
    {"tap": "h"},
    {"tap": "e"},
    {"tap": "l"},
    {"tap": "l"},
    {"tap": "o"},
    {"tap": "space"},
    {"tap": "w", "modifiers": ["shift"]},
    {"tap": "o"},
    {"tap": "r"},
    {"tap": "l"},
    {"tap": "d"},
    {"tap": "!", "modifiers": ["shift"]}
  ]
}
```

### Example 4: Press and hold arrow key for scrolling

```json
{
  "action": "key_sequence",
  "sequence": [
    {"press": "down"},
    {"delay": 1.0},
    {"release": "down"}
  ]
}
```

### Example 5: Type with standard behavior

```json
{
  "action": "type_text",
  "text": "Hello, world! This is a test of typing functionality."
}
```

## Implementation Notes

1. The tool should map key names to the appropriate macOS key codes internally
2. Standard timing for text input should be natural but responsive
3. Modifier keys should work correctly for international keyboards
4. Error handling should provide clear messages for invalid keys or sequences
5. When using modifiers with tap events, the modifiers should be automatically pressed before and released after the tap

## Error Handling

The tool should return appropriate error messages for:

1. Invalid key names
2. Invalid sequence operations
3. Releasing keys that weren't pressed
4. Other keyboard operation failures