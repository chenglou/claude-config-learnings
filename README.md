# Claude Code Permission Configs

Three setups depending on what you want.

## Case 1: Auto-allow all, block dangerous commands

No prompts. Dangerous commands are denied outright with a custom message.

**Requires a hook** (settings-only is broken, see [Appendix](#appendix-settings-only-approach-broken)).

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
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/simple-deny-dangerous.sh"
          }
        ]
      }
    ]
  }
}
```

Setup:
```bash
mkdir -p ~/.claude/hooks
cp simple-deny-dangerous.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/simple-deny-dangerous.sh
```

## Case 2: Auto-allow all, prompt for dangerous commands

No prompts for normal commands. Dangerous commands show a permission dialog.

**Requires a hook** (settings-only can't do this).

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
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/simple-prompt-dangerous.sh"
          }
        ]
      }
    ]
  }
}
```

Setup:
```bash
mkdir -p ~/.claude/hooks
cp simple-prompt-dangerous.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/simple-prompt-dangerous.sh
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

Setup:
```bash
mkdir -p ~/.claude/hooks
cp smart-permission.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/smart-permission.sh
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

## Appendix: Settings-only approach (broken)

> **Warning:** The `allow` and `deny` rules in settings.json are **not enforced** for Bash commands. This is a known bug: [#18846](https://github.com/anthropics/claude-code/issues/18846). Use hooks instead.

The following config **does not work** as expected:

`~/.claude/settings.json`:
```json
{
  "permissions": {
    "additionalDirectories": ["~", "/tmp", "/private/tmp"],
    "defaultMode": "dontAsk",
    "deny": [
      "Bash(rm:*)",
      "Bash(git reset:*)",
      "Bash(git clean:*)",
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/*.pem)",
      "Read(**/*.key)"
    ]
  }
}
```

This *should* auto-allow everything except the denied patterns, but the Bash deny rules are ignored. The Read rules may work.
