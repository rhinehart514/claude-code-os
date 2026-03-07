#!/usr/bin/env bash
set -euo pipefail

# sweep.sh — Run the sweep agent via Claude Code
# Designed to be called by launchd or manually
#
# Usage: ./sweep.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/sweep-$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') — Starting sweep" >> "$LOG_FILE"

if ! command -v claude &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') — ERROR: claude CLI not found" >> "$LOG_FILE"
    exit 1
fi

claude --agent sweep \
    "Run the sweep. Produce the brief. Classify all items. Do NOT auto-dispatch RED items — list them for human review." \
    2>> "$LOG_FILE"

echo "$(date '+%Y-%m-%d %H:%M:%S') — Sweep complete" >> "$LOG_FILE"
