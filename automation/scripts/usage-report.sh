#!/usr/bin/env bash
set -euo pipefail

# usage-report.sh — Read usage.jsonl and report agent/tool usage stats
# Usage: ./usage-report.sh [days]  (default: 30)

USAGE_FILE="$HOME/.claude/logs/usage.jsonl"
DAYS="${1:-30}"

if [[ ! -f "$USAGE_FILE" ]]; then
    echo "No usage data found at $USAGE_FILE"
    echo "Install the track_usage.sh hook to start collecting data."
    exit 0
fi

if ! command -v jq &> /dev/null; then
    echo "jq required: brew install jq"
    exit 1
fi

CUTOFF="$(date -u -v-${DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$DAYS days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

echo "=== Usage Report (last ${DAYS} days) ==="
echo "Data: $USAGE_FILE"
echo "Since: $CUTOFF"
echo ""

echo "--- Tool Call Counts ---"
jq -r "select(.ts >= \"$CUTOFF\") | .tool" "$USAGE_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -20

echo ""
echo "--- Total Calls ---"
TOTAL=$(jq -r "select(.ts >= \"$CUTOFF\") | .tool" "$USAGE_FILE" 2>/dev/null | wc -l | tr -d ' ')
echo "$TOTAL tool calls in last $DAYS days"

echo ""
echo "--- Daily Average ---"
if [[ "$TOTAL" -gt 0 ]]; then
    echo "$(( TOTAL / DAYS )) calls/day"
fi

echo ""
echo "--- Unused Tools (in repo but not in logs) ---"
USED_TOOLS=$(jq -r "select(.ts >= \"$CUTOFF\") | .tool" "$USAGE_FILE" 2>/dev/null | sort -u)
# Resolve rhino-os install dir from symlink
RHINO_BIN="$(readlink "$HOME/bin/rhino" 2>/dev/null || echo "")"
RHINO_DIR="$(cd "$(dirname "$RHINO_BIN")/.." 2>/dev/null && pwd || echo "$HOME/rhino-os")"
for agent in "$RHINO_DIR"/agents/*.md; do
    name="$(basename "$agent" .md)"
    if ! echo "$USED_TOOLS" | grep -qi "$name"; then
        echo "  $name — no invocations in $DAYS days"
    fi
done
