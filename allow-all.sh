#!/bin/bash
# Allows all tools - workaround for dontAsk mode bugs (#11934)
# Usage: Copy to ~/.claude/hooks/ and chmod +x
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
