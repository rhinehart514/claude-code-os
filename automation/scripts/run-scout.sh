#!/usr/bin/env bash
set -euo pipefail

# run-scout.sh — Run the scout agent via Claude Code
# Designed to be called by launchd or manually
#
# Usage: ./run-scout.sh [--max-budget-usd N]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.claude/logs"
LOG_FILE="$LOG_DIR/scout-$(date +%Y-%m-%d).log"
MAX_BUDGET="${1:-2.00}"

mkdir -p "$LOG_DIR"

echo "$(date '+%Y-%m-%d %H:%M:%S') — Starting scout session" >> "$LOG_FILE"
echo "Budget cap: \$$MAX_BUDGET" >> "$LOG_FILE"

if ! command -v claude &> /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') — ERROR: claude CLI not found" >> "$LOG_FILE"
    exit 1
fi

claude --agent scout \
    --print \
    --max-turns 50 \
    "Run a standard scouting session. Budget cap: \$$MAX_BUDGET. Follow all steps in order." \
    >> "$LOG_FILE" 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') — Scout session complete" >> "$LOG_FILE"
