# Claude Code Hooks: Permission Behavior Findings

Tested on Claude Code (latest stable), Feb 2026.

## Hook Event Timing

| Event | When it fires |
|-------|---------------|
| `PreToolUse` | Before every tool call, regardless of permission mode |
| `PermissionRequest` | Only when a permission dialog is about to be shown |

Key insight: `PermissionRequest` does NOT fire if:
- The command is auto-allowed (via `acceptEdits` mode or allow list)
- Running in `-p` (print/non-interactive) mode

## PreToolUse Decision Control

| Hook output | Result |
|-------------|--------|
| `permissionDecision: "allow"` | Auto-allows, bypasses permission system |
| `permissionDecision: "deny"` | Blocks the command |
| `permissionDecision: "ask"` | Shows permission dialog |
| Exit 0, no output | Proceeds to normal permission checking |

Example allow response:
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
| Exit 0, no output | **Dialog shows normally** (user decides) |

No "ask" option - only allow/deny. But exit 0 with no output = dialog shows.

Example allow response:
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

## Permission Settings: Allow/Deny Lists

Deny rules have **highest priority** (evaluated before allow).

```json
{
  "permissions": {
    "allow": ["Bash"],
    "deny": [
      "Bash(rm -rf *)",
      "Read(**/.env)"
    ]
  }
}
```

Evaluation order:
1. Deny rules (first match blocks)
2. Ask rules
3. Allow rules

## Smart Permission Hook (Three-Way Decision)

To have an LLM decide allow/deny/ask based on context, use `PreToolUse` with a command hook:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/smart-permission.sh"
          }
        ]
      }
    ]
  }
}
```

The script reads `transcript_path` from stdin JSON, calls an LLM API with context, and returns:
- `permissionDecision: "allow"` for safe commands
- `permissionDecision: "deny"` for dangerous commands
- `permissionDecision: "ask"` when uncertain (shows dialog)

## Agent/Prompt Hooks Limitation

`type: "agent"` and `type: "prompt"` hooks can only return `{"ok": true/false}`:
- `ok: true` → allow
- `ok: false` → deny
- No "ask" option, no "no output" option

For three-way decisions, must use `type: "command"` hook.

## Testing Notes

- Hooks require `--debug` flag to fire in some scenarios (unclear why)
- `-p` mode doesn't support interactive permission dialogs
- `acceptEdits` mode auto-allows many operations without triggering `PermissionRequest`
- Hook input includes `transcript_path` - agents can Read this file for full conversation context
