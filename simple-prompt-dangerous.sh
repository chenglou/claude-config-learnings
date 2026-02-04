#!/bin/bash
# Prompts for dangerous commands, auto-allows everything else
# Usage: Copy to ~/.claude/hooks/ and chmod +x

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '^rm\s|^git\s+reset|^git\s+clean'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Potentially dangerous command"}}'
else
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
fi
