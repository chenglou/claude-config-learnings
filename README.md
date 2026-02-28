# Claude Code Permission Configs

Three setups depending on what you want.

> **Note:** `dontAsk` mode auto-denies most tools including Bash and WebSearch ([#11881](https://github.com/anthropics/claude-code/issues/11881)). `ask` rules are also ignored in `dontAsk` mode ([#16555](https://github.com/anthropics/claude-code/issues/16555)). The configs below use `PreToolUse` hooks to work around these. Bash `deny` rules in settings.json do work, but `dontAsk` won't auto-allow Bash without a hook or `allow` rule.

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

### Bash allow/deny rules partially work

Bash `deny` rules work (e.g. `Bash(rm *)` blocks rm). However, `dontAsk` mode does **not** auto-allow Bash — it auto-denies it. You need either `allow: ["Bash"]` or a `PreToolUse` hook to allow Bash commands. [#18846](https://github.com/anthropics/claude-code/issues/18846) is still open but deny rules are now enforced. Verified Feb 2026.

### dontAsk mode auto-denies tools

`dontAsk` mode auto-denies most tools (Bash, WebSearch, WebFetch, etc.) with "Permission to use X has been denied because Claude Code is running in don't ask mode." This is [#11881](https://github.com/anthropics/claude-code/issues/11881) (closed but still broken). A sub-agent variant is [#11934](https://github.com/anthropics/claude-code/issues/11934).

**Workaround:** Use a catch-all `PreToolUse` hook with empty matcher `""` that returns `permissionDecision: "allow"` (see `allow-all.sh`).

### dontAsk mode ignores ask rules

`dontAsk` overrides explicit `ask` rules — tools in the `ask` list get auto-denied instead of prompting. [#16555](https://github.com/anthropics/claude-code/issues/16555) (closed as not planned but still broken). Use `PreToolUse` hooks returning `permissionDecision: "ask"` instead.

### Repro steps

**Important:** User-level `~/.claude/settings.json` hooks merge with project-level hooks and can mask these bugs. To reproduce cleanly:

```bash
# 1. Temporarily move user-level settings
mv ~/.claude/settings.json ~/.claude/settings.json.bak

# 2. Create isolated test project
mkdir -p /tmp/claude-test/.claude
cd /tmp/claude-test && git init

# 3. Test dontAsk auto-deny (#11881): should allow WebSearch, but auto-denies it
echo '{"permissions":{"defaultMode":"dontAsk"}}' > .claude/settings.json
# Start Claude, ask it to web search → gets auto-denied

# 4. Test ask rules ignored (#16555): should prompt for WebSearch, but auto-denies it
echo '{"permissions":{"defaultMode":"dontAsk","ask":["WebSearch"]}}' > .claude/settings.json
# Start Claude, ask it to web search → gets auto-denied instead of prompting

# 5. Restore user settings
mv ~/.claude/settings.json.bak ~/.claude/settings.json
```
