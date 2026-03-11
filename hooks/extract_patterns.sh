#!/usr/bin/env bash
# extract_patterns.sh — Stop hook that mines session traces for recurring patterns
# Lighter version of ECC's "instinct extraction" — no background LLM, just signal detection.
# Looks for repeated tool sequences, frequently edited files, and recurring commands.
# Graduates patterns into ~/.claude/knowledge/patterns.tsv when seen 3+ times.

INPUT="$(cat)"

LOG_DIR="$HOME/.claude/logs"
USAGE_FILE="$LOG_DIR/usage.jsonl"
KNOWLEDGE_DIR="$HOME/.claude/knowledge"
PATTERNS_FILE="$KNOWLEDGE_DIR/patterns.tsv"
PATTERN_RAW="$LOG_DIR/pattern-raw.tsv"

mkdir -p "$KNOWLEDGE_DIR" "$LOG_DIR"

[[ ! -f "$USAGE_FILE" ]] && exit 0

# Initialize files if needed
if [[ ! -f "$PATTERNS_FILE" ]]; then
    printf "pattern\ttype\tcount\tfirst_seen\tlast_seen\tstatus\n" > "$PATTERNS_FILE"
fi
if [[ ! -f "$PATTERN_RAW" ]]; then
    printf "date\tpattern\ttype\n" > "$PATTERN_RAW"
fi

TWO_HOURS_AGO=$(date -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '2 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
[[ -z "$TWO_HOURS_AGO" ]] && exit 0
TODAY=$(date +%Y-%m-%d)

# --- 1. Detect frequently co-edited files (edited 2+ times in same session) ---
CO_EDITED=$(awk -v cutoff="$TWO_HOURS_AGO" '
{
    if (match($0, /"ts":"([^"]+)"/, t) && t[1] >= cutoff) {
        if (match($0, /"tool":"(Edit|Write)"/) && match($0, /"file":"([^"]+)"/, f)) {
            files[f[1]]++
        }
    }
}
END {
    for (f in files) if (files[f] >= 2) print f
}
' "$USAGE_FILE" 2>/dev/null)

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    printf "%s\t%s\thot_file\n" "$TODAY" "$file" >> "$PATTERN_RAW"
done <<< "$CO_EDITED"

# --- 2. Detect tool sequence patterns (bigrams: tool A → tool B) ---
BIGRAMS=$(awk -v cutoff="$TWO_HOURS_AGO" '
{
    if (match($0, /"ts":"([^"]+)"/, t) && t[1] >= cutoff) {
        if (match($0, /"tool":"([^"]+)"/, m)) {
            if (prev != "") {
                pair = prev "->" m[1]
                pairs[pair]++
            }
            prev = m[1]
        }
    }
}
END {
    for (p in pairs) if (pairs[p] >= 3) print p "\t" pairs[p]
}
' "$USAGE_FILE" 2>/dev/null)

while IFS=$'\t' read -r bigram count; do
    [[ -z "$bigram" ]] && continue
    printf "%s\t%s\ttool_sequence\n" "$TODAY" "$bigram" >> "$PATTERN_RAW"
done <<< "$BIGRAMS"

# --- 3. Graduate patterns seen 3+ times across sessions ---
# Count occurrences of each pattern in raw log
if [[ -f "$PATTERN_RAW" ]]; then
    # Get patterns with 3+ occurrences across different dates (macOS awk compatible)
    awk -F'\t' 'NR>1 && $2 != "" {
        key = $2 "\t" $3
        combo = key SUBSEP $1
        if (!(combo in seen)) { seen[combo] = 1; unique[key]++ }
        count[key]++
    }
    END {
        for (k in count) {
            if (unique[k] >= 3) print k "\t" count[k] "\t" unique[k]
        }
    }' "$PATTERN_RAW" 2>/dev/null | while IFS=$'\t' read -r pattern ptype total_count session_count; do
        [[ -z "$pattern" ]] && continue
        # Check if already graduated
        if ! grep -qF "$pattern" "$PATTERNS_FILE" 2>/dev/null; then
            printf "%s\t%s\t%s\t%s\t%s\tconfirmed\n" "$pattern" "$ptype" "$total_count" "$TODAY" "$TODAY" >> "$PATTERNS_FILE"
        else
            # Update last_seen and count
            tmpfile=$(mktemp)
            awk -F'\t' -v pat="$pattern" -v today="$TODAY" -v cnt="$total_count" '
                BEGIN { OFS="\t" }
                $1 == pat { $3 = cnt; $5 = today; print; next }
                { print }
            ' "$PATTERNS_FILE" > "$tmpfile" && mv "$tmpfile" "$PATTERNS_FILE" || rm -f "$tmpfile"
        fi
    done
fi

# --- 4. Prune raw log older than 30 days ---
THIRTY_DAYS_AGO=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d 2>/dev/null || echo "")
if [[ -n "$THIRTY_DAYS_AGO" && -f "$PATTERN_RAW" ]]; then
    tmpfile=$(mktemp)
    awk -v cutoff="$THIRTY_DAYS_AGO" 'NR==1 || $1 >= cutoff' "$PATTERN_RAW" > "$tmpfile" && mv "$tmpfile" "$PATTERN_RAW" || rm -f "$tmpfile"
fi

exit 0
