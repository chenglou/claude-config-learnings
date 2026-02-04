# Claude Code Hooks: Permission Behavior Findings

Tested on Claude Code (latest stable), Feb 2026.

## Permission Settings

### Permission Modes

| Mode | Behavior |
|------|----------|
| `default` | Prompts for most operations |
| `acceptEdits` | Auto-allows file operations (Read, Write, Edit) |
| `dontAsk` | Auto-allows everything |
| `bypassPermissions` | Skips all permission checks |

### Rule Evaluation Order

**deny → allow → ask**

1. `deny` rules checked first (blocks if matched)
2. `allow` rules checked second (auto-allows if matched)
3. `ask` rules checked last (prompts if matched)

### Rule Syntax

```
Bash(rm:*)        ✓ correct (`:*` is deprecated, use ` *`)
Bash(rm *)        ✓ correct (space before *)
Bash(rm -rf *)    ✗ wrong
Read(**/.env)     ✓ glob patterns for files
```

> **Warning:** Bash `allow` and `deny` rules are currently broken and not enforced. See [#18846](https://github.com/anthropics/claude-code/issues/18846). Use `PreToolUse` hooks instead.

### Why "allow all except prompt for X" is impossible with settings

If you use `allow: ["Bash"]`, all bash commands match the allow rule before reaching `ask` rules.

If you don't allow bash broadly, all bash commands prompt (defeating the purpose).

**Solution:** Use a `PreToolUse` hook that returns `permissionDecision: "ask"` for specific patterns.

### dontAsk mode + ask rules

`dontAsk` mode ignores `ask` rules entirely - they behave like `deny` instead of prompting.

### Recommended: dontAsk + PreToolUse hooks

Since Bash `allow`/`deny` rules are broken, and `dontAsk` mode may auto-deny Write/Edit ([#11934](https://github.com/anthropics/claude-code/issues/11934)), the recommended setup is:
- `defaultMode: "dontAsk"` - baseline (buggy but still useful)
- `PreToolUse` hook on Bash - handles allow/deny/prompt for commands
- `PreToolUse` hooks on Write/Edit - explicitly return `permissionDecision: "allow"` to work around dontAsk bugs

The hook runs before the permission system decides, so it overrides the buggy dontAsk behavior.

## Hook Events

| Event | When it fires |
|-------|---------------|
| `PreToolUse` | Before every tool call, regardless of permission mode |
| `PermissionRequest` | Only when a permission dialog is about to be shown |

### PermissionRequest does NOT fire if:

- Command is auto-allowed (via mode or allow list)
- Running in `-p` (print/non-interactive) mode
- `dontAsk` or `bypassPermissions` mode is active

## PreToolUse Decision Control

| Hook output | Result |
|-------------|--------|
| `permissionDecision: "allow"` | Auto-allows, bypasses permission system |
| `permissionDecision: "deny"` | Blocks the command |
| `permissionDecision: "ask"` | Shows permission dialog |
| Exit 0, no output | Proceeds to normal permission checking |

Example:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by hook"
  }
}
```

## PermissionRequest Decision Control

| Hook output | Result |
|-------------|--------|
| `behavior: "allow"` | Grants permission silently |
| `behavior: "deny"` | Denies permission |
| Exit 0, no output | Dialog shows normally (user decides) |

No "ask" option - only allow/deny. But exit 0 with no output = dialog shows.

Example:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
```

## Hook Types

| Type | Can return "ask"? | Can read files? |
|------|-------------------|-----------------|
| `command` | Yes (three-way: allow/deny/ask) | Via shell commands |
| `prompt` | No (binary: ok true/false) | No |
| `agent` | No (binary: ok true/false) | Yes (has Read, Grep, Glob tools) |

For three-way decisions (allow/deny/ask), must use `type: "command"` hook.

## Hook Input

Hooks receive JSON on stdin with:
- `session_id` - current session
- `transcript_path` - path to conversation JSON file
- `tool_name` - e.g., "Bash"
- `tool_input` - e.g., `{"command": "rm file.txt"}`
- `permission_mode` - current mode

The `transcript_path` can be read by agent hooks or shell scripts to get full conversation context.

## Testing Notes

- `-p` mode doesn't support interactive permission dialogs (commands block or timeout)
- `acceptEdits` mode auto-allows file operations without triggering `PermissionRequest`
- **Hook changes in settings require a new Claude session to take effect**
- `--version` flags appear to be special-cased as always-allowed (e.g., `python3 --version` works even when other python3 commands are blocked)
