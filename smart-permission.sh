#!/bin/bash
# LLM-based permission decisions using conversation context
# Only calls API for potentially dangerous commands
# Requires: ANTHROPIC_API_KEY environment variable

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')

# Auto-allow obviously safe commands (don't waste API calls)
if echo "$COMMAND" | grep -qE '^(ls|pwd|cat|head|tail|echo|which|whoami|date|uname|env|printenv|mkdir|touch|cp|mv|find|grep|wc|sort|uniq|diff|file|stat|df|du|ps|top|htop|man|help|git status|git log|git diff|git branch|git show|git fetch|git pull|git add|git commit|git push|npm|npx|yarn|pnpm|bun|bunx|node|python|python3|cargo|go |make)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

# No API key - fall back to simple pattern matching
if [ -z "$ANTHROPIC_API_KEY" ]; then
  if echo "$COMMAND" | grep -qE '^rm\s|^git\s+reset|^git\s+clean|^chmod|^chown|^sudo|>\s*/'; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"No API key - please confirm"}}'
  else
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  fi
  exit 0
fi

# For other commands, ask the LLM
TRANSCRIPT=$(cat "$TRANSCRIPT_PATH" 2>/dev/null | tail -c 50000)

PROMPT="You're deciding if a Bash command should be auto-allowed, denied, or needs user confirmation.

Command: $COMMAND

Recent conversation:
$TRANSCRIPT

Rules:
- ALLOW: routine dev commands, file ops the user mentioned, git operations
- DENY: clearly destructive/unintended
- ASK: uncertain or potentially dangerous

Respond with exactly one word: ALLOW, DENY, or ASK"

RESPONSE=$(curl -s https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "$(jq -n --arg prompt "$PROMPT" '{
    "model": "claude-sonnet-4-20250514",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": $prompt}]
  }')" 2>/dev/null | jq -r '.content[0].text // "ASK"' | tr '[:lower:]' '[:upper:]' | head -c 10)

case "$RESPONSE" in
  *ALLOW*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved"}}'
    ;;
  *DENY*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by safety check"}}'
    ;;
  *)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Please confirm"}}'
    ;;
esac
