#!/usr/bin/env bash
# track_usage.sh — PostToolUse hook that logs tool invocations to JSONL
# Appended to ~/.claude/logs/usage.jsonl
# Must be fast (<100ms) and never block tool execution

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only log if we got a tool name
if [[ -n "$TOOL_NAME" ]]; then
    LOG_DIR="$HOME/.claude/logs"
    mkdir -p "$LOG_DIR"
    TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL_NAME\"}" >> "$LOG_DIR/usage.jsonl"
fi

exit 0
