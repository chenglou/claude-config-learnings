# Claude Code Permission Configs

Three setups depending on what you want.

> **Note:** `dontAsk` mode is buggy and may auto-deny tools ([#11934](https://github.com/anthropics/claude-code/issues/11934)). The configs below use `PreToolUse` hooks to explicitly allow them.

## Case 1: Auto-allow all, block dangerous commands

No prompts. Dangerous commands are denied outright with a custom message.

`~/.claude/settings.json`:
```json
{
  "permissions": {
    "additionalDirectories": ["~", "/tmp", "/private/tmp"],
    "defaultMode": "dontAsk"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/simple-deny-dangerous.sh"
        }]
      },
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/allow-all.sh"
        }]
      }
    ]
  }
}
```

Setup:
```bash
mkdir -p ~/.claude/hooks
cp simple-deny-dangerous.sh allow-all.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

## Case 2: Auto-allow all, prompt for dangerous commands

No prompts for normal commands. Dangerous commands show a permission dialog.

`~/.claude/settings.json`:
```json
{
  "permissions": {
    "additionalDirectories": ["~", "/tmp", "/private/tmp"],
    "defaultMode": "dontAsk"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/simple-prompt-dangerous.sh"
        }]
      },
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/allow-all.sh"
        }]
      }
    ]
  }
}
```

Setup:
```bash
mkdir -p ~/.claude/hooks
cp simple-prompt-dangerous.sh allow-all.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```

## Case 3: LLM decides based on conversation context

An LLM reads the conversation history and decides: allow, deny, or prompt.

**Requires a hook + API key.**

`~/.claude/settings.json`:
```json
{
  "permissions": {
    "additionalDirectories": ["~", "/tmp", "/private/tmp"],
    "defaultMode": "dontAsk"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/smart-permission.sh"
        }]
      },
      {
        "matcher": "",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/allow-all.sh"
        }]
      }
    ]
  }
}
```

Setup:
```bash
mkdir -p ~/.claude/hooks
cp smart-permission.sh allow-all.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
export ANTHROPIC_API_KEY=your-key
```

## Why settings-only can't do Case 2

Evaluation order is: deny → allow → ask

- If you `allow: ["Bash"]`, all bash is allowed before `ask` is checked
- If you don't allow bash broadly, everything prompts

So "allow all except prompt for X" requires a hook.

## More Details

See [hooks-permission-behavior.md](hooks-permission-behavior.md) for detailed findings on hook behavior.

---

## Appendix: Known bugs

### Bash allow/deny rules don't work

The `allow` and `deny` rules in settings.json are **not enforced** for Bash commands. This is a known bug: [#18846](https://github.com/anthropics/claude-code/issues/18846). Use `PreToolUse` hooks instead.

### dontAsk mode auto-denies tools

`dontAsk` mode may auto-deny Write, Edit, WebFetch, and other tools with "Permission to use X has been auto-denied in dontAsk mode." This is [#11934](https://github.com/anthropics/claude-code/issues/11934).

**Workaround:** Use a catch-all `PreToolUse` hook with empty matcher `""` that returns `permissionDecision: "allow"` (see `allow-all.sh`).
