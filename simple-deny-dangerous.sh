#!/bin/bash
# Denies dangerous commands with custom message, auto-allows everything else
# Usage: Copy to ~/.claude/hooks/ and chmod +x

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if echo "$COMMAND" | grep -qE '^rm\s'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Instead of rm, use trash, which moves things to trash instead of perma-deleting"}}'
elif echo "$COMMAND" | grep -qE '^git\s+reset|^git\s+clean'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked: git reset and git clean are not allowed"}}'
else
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
fi
