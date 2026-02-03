#!/bin/bash
# Smart permission hook example - uses Opus to evaluate commands based on conversation context
# Place in ~/.claude/hooks/smart-permission.sh and chmod +x

INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

# Only evaluate Bash commands (other tools pass through)
if [ "$TOOL_NAME" != "Bash" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

# Read transcript for context
TRANSCRIPT=$(cat "$TRANSCRIPT_PATH" 2>/dev/null | tail -c 50000)  # Last 50KB

# Build prompt
PROMPT="You're deciding if a Bash command should be auto-allowed, denied, or needs user confirmation.

Command: $COMMAND

Recent conversation context:
$TRANSCRIPT

Rules:
- ALLOW: routine dev commands (tests, builds, linting), file ops the user mentioned, git operations
- DENY: clearly destructive/unintended (rm -rf on wrong paths, dropping databases, etc.)
- ASK: uncertain, potentially dangerous, or user should verify

Respond with exactly one word: ALLOW, DENY, or ASK"

# Call Opus API
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
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Auto-approved by Opus"}}'
    ;;
  *DENY*)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by Opus safety check"}}'
    ;;
  *)
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Opus uncertain - please confirm"}}'
    ;;
esac
