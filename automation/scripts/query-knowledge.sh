#!/usr/bin/env bash
set -euo pipefail

# query-knowledge.sh — Query JSONL knowledge files
# Usage:
#   ./query-knowledge.sh <agent> confirmed      — list CONFIRMED patterns
#   ./query-knowledge.sh <agent> weak            — list WEAK patterns
#   ./query-knowledge.sh <agent> eval-trend      — show eval scores over time
#   ./query-knowledge.sh <agent> stale [days]    — entries not updated in N days (default 30)

AGENT="${1:-}"
CMD="${2:-}"
DAYS="${3:-30}"
BASE="$HOME/.claude/knowledge"

if [[ -z "$AGENT" || -z "$CMD" ]]; then
    echo "Usage: ./query-knowledge.sh <agent> <command> [args]"
    echo ""
    echo "Commands:"
    echo "  confirmed    — list CONFIRMED patterns"
    echo "  weak         — list WEAK patterns"
    echo "  strong       — list STRONG patterns"
    echo "  eval-trend   — show eval scores over time"
    echo "  stale [N]    — entries not updated in N days (default 30)"
    echo ""
    echo "Example: ./query-knowledge.sh scout confirmed"
    exit 0
fi

if ! command -v jq &> /dev/null; then
    echo "jq required: brew install jq"
    exit 1
fi

case "$CMD" in
    confirmed|weak|strong|CONFIRMED|WEAK|STRONG)
        FILE="$BASE/$AGENT/confidence-scores.jsonl"
        LEVEL="$(echo "$CMD" | tr '[:lower:]' '[:upper:]')"
        if [[ ! -f "$FILE" ]]; then echo "No file: $FILE"; exit 0; fi
        echo "=== $LEVEL patterns for $AGENT ==="
        jq -r "select(.confidence == \"$LEVEL\") | \"[\(.updated)] \(.pattern) (evidence: \(.evidence_count))\"" "$FILE"
        ;;
    eval-trend)
        FILE="$BASE/$AGENT/eval-history.jsonl"
        if [[ ! -f "$FILE" ]]; then echo "No file: $FILE"; exit 0; fi
        echo "=== Eval trend for $AGENT ==="
        jq -r '"[\(.date)] session \(.session): \(.score) — \(.finding)"' "$FILE"
        ;;
    stale)
        FILE="$BASE/$AGENT/confidence-scores.jsonl"
        if [[ ! -f "$FILE" ]]; then echo "No file: $FILE"; exit 0; fi
        CUTOFF="$(date -u -v-${DAYS}d +%Y-%m-%d 2>/dev/null || date -u -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null)"
        echo "=== Stale entries (not updated since $CUTOFF) ==="
        jq -r "select(.updated < \"$CUTOFF\") | \"[\(.updated)] \(.pattern) — \(.confidence)\"" "$FILE"
        ;;
    *)
        echo "Unknown command: $CMD"
        echo "Run without args for usage."
        exit 1
        ;;
esac
