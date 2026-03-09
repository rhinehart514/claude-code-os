#!/usr/bin/env bash
# track_usage.sh — PostToolUse hook
# Logs tool invocations to usage.jsonl with project context.
# Extracts CODE STYLE patterns (not taste) to code-style.jsonl.
# Taste is macro judgment — what to build, kill, prioritize.
# Code style is formatting — camelCase, semicolons, indentation.
# Must be fast (<50ms). Never block tool execution.

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

[[ -z "$TOOL_NAME" ]] && exit 0

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Extract file path from tool input
FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"

# Detect project from file path
PROJECT=""
if [[ -n "$FILE_PATH" ]]; then
    PROJECT="$(echo "$FILE_PATH" | sed "s|^$HOME/||" | cut -d'/' -f1)"
fi

# Log usage (always)
echo "{\"ts\":\"$TS\",\"tool\":\"$TOOL_NAME\",\"project\":\"$PROJECT\",\"file\":\"$FILE_PATH\"}" >> "$LOG_DIR/usage.jsonl"

exit 0
