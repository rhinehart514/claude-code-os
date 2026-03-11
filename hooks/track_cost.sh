#!/usr/bin/env bash
# track_cost.sh — Stop hook that summarizes session cost from usage.jsonl
# Logs per-session cost estimate to cost-history.tsv
# Helps identify expensive patterns over time.

INPUT="$(cat)"

LOG_DIR="$HOME/.claude/logs"
USAGE_FILE="$LOG_DIR/usage.jsonl"
COST_FILE="$LOG_DIR/cost-history.tsv"

mkdir -p "$LOG_DIR"

# Initialize TSV if needed
if [[ ! -f "$COST_FILE" ]]; then
    printf "date\tproject\ttool_calls\tedit_count\tread_count\tbash_count\tagent_count\tduration_min\n" > "$COST_FILE"
fi

# Count tools used in last session (last 2 hours — generous window)
if [[ ! -f "$USAGE_FILE" ]]; then
    exit 0
fi

TWO_HOURS_AGO=$(date -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
[[ -z "$TWO_HOURS_AGO" ]] && exit 0

# Extract session stats using awk (fast, no jq dependency for hot path)
STATS=$(awk -v cutoff="$TWO_HOURS_AGO" '
BEGIN { total=0; edits=0; reads=0; bashes=0; agents=0; first_ts=""; last_ts="" }
{
    if (match($0, /"ts":"([^"]+)"/, m)) {
        ts = m[1]
        if (ts >= cutoff) {
            total++
            if (first_ts == "") first_ts = ts
            last_ts = ts
            if (match($0, /"tool":"Edit"/)) edits++
            else if (match($0, /"tool":"Read"/)) reads++
            else if (match($0, /"tool":"Bash"/)) bashes++
            else if (match($0, /"tool":"Agent"/)) agents++
        }
    }
}
END {
    # Estimate duration from first to last tool use
    # Quick approximation: count minutes between first and last
    printf "%d\t%d\t%d\t%d\t%d\n", total, edits, reads, bashes, agents
}
' "$USAGE_FILE")

TOTAL=$(echo "$STATS" | cut -f1)
EDITS=$(echo "$STATS" | cut -f2)
READS=$(echo "$STATS" | cut -f3)
BASHES=$(echo "$STATS" | cut -f4)
AGENTS=$(echo "$STATS" | cut -f5)

# Skip trivial sessions
if (( TOTAL < 5 )); then
    exit 0
fi

# Detect project
PROJECT_NAME="$(basename "$(pwd)")"
TODAY="$(date +%Y-%m-%d_%H:%M)"

# Estimate duration from first/last tool timestamps
FIRST_TS=$(awk -v cutoff="$TWO_HOURS_AGO" '
{
    if (match($0, /"ts":"([^"]+)"/, m) && m[1] >= cutoff) { print m[1]; exit }
}' "$USAGE_FILE")
LAST_TS=$(tail -1 "$USAGE_FILE" | grep -oP '"ts":"[^"]+"' | cut -d'"' -f4 2>/dev/null || echo "")

DURATION_MIN="?"
if [[ -n "$FIRST_TS" && -n "$LAST_TS" ]]; then
    # Convert ISO timestamps to epoch (macOS)
    first_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$FIRST_TS" +%s 2>/dev/null || echo "0")
    last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_TS" +%s 2>/dev/null || echo "0")
    if (( first_epoch > 0 && last_epoch > 0 )); then
        DURATION_MIN=$(( (last_epoch - first_epoch) / 60 ))
    fi
fi

# Append to cost history
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$TODAY" "$PROJECT_NAME" "$TOTAL" "$EDITS" "$READS" "$BASHES" "$AGENTS" "$DURATION_MIN" \
    >> "$COST_FILE"

# Prune entries older than 90 days
NINETY_DAYS_AGO=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d 2>/dev/null || echo "")
if [[ -n "$NINETY_DAYS_AGO" ]]; then
    tmpfile=$(mktemp)
    awk -v cutoff="$NINETY_DAYS_AGO" 'NR==1 || $1 >= cutoff' "$COST_FILE" > "$tmpfile" && mv "$tmpfile" "$COST_FILE" || rm -f "$tmpfile"
fi

exit 0
