#!/usr/bin/env bash
# session_context.sh — PreToolUse hook: inject 3 things into every session.
# 1. Current score + integrity warnings (blocking)
# 2. Active plan task (what to work on)
# 3. Blocking warnings (integrity, thinking health)
# Fires once per session (30min cooldown).

cat > /dev/null  # drain stdin — hook protocol

CLAUDE_DIR="$HOME/.claude"
STATE_DIR="$CLAUDE_DIR/state"
KNOWLEDGE_DIR="$CLAUDE_DIR/knowledge"
MARKER="$STATE_DIR/.session-context-injected"

# Fast exit: skip if marker is < 30 min old
if [[ -f "$MARKER" ]]; then
    MARKER_AGE=$(( $(date +%s) - $(stat -f %m "$MARKER" 2>/dev/null || stat -c %Y "$MARKER" 2>/dev/null || echo "0") ))
    (( MARKER_AGE < 1800 )) && exit 0
fi

mkdir -p "$STATE_DIR"
date +%s > "$MARKER"

PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
CONTEXT=""

# --- 1. Current score + integrity warnings ---
CACHE_FILE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
    score=$(jq -r '.score // empty' "$CACHE_FILE" 2>/dev/null)
    structure=$(jq -r '.structure // empty' "$CACHE_FILE" 2>/dev/null)
    hygiene=$(jq -r '.hygiene // empty' "$CACHE_FILE" 2>/dev/null)
    taste=$(jq -r '.taste // "—"' "$CACHE_FILE" 2>/dev/null)
    warnings=$(jq -r '.integrity_warnings // [] | .[]' "$CACHE_FILE" 2>/dev/null)

    CONTEXT+="## Score: ${score}/100 (structure: $structure, hygiene: $hygiene, taste: $taste)
"
    if [[ -n "$warnings" ]]; then
        CONTEXT+="⚠ INTEGRITY: $warnings
Address warnings before building.
"
    fi
fi

# Taste weakest dimension
for taste_dir in "$PROJECT_DIR/.claude/evals/reports" "$PROJECT_DIR/docs/evals/reports"; do
    TASTE_REPORT=$(ls -t "$taste_dir"/taste-*.json 2>/dev/null | head -1)
    [[ -n "$TASTE_REPORT" ]] && break
done
if [[ -n "${TASTE_REPORT:-}" ]] && command -v jq &>/dev/null; then
    weakest=$(jq -r '.weakest_dimension // empty' "$TASTE_REPORT" 2>/dev/null)
    one_thing=$(jq -r '.one_thing // empty' "$TASTE_REPORT" 2>/dev/null)
    [[ -n "$weakest" ]] && CONTEXT+="Weakest: $weakest. $one_thing
"
fi

# --- 2. Active plan task ---
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/active-plan.md" "$CLAUDE_DIR/plans/active-plan.md"; do
    [[ -f "$p" ]] && PLAN_FILE="$p" && break
done
if [[ -n "$PLAN_FILE" ]]; then
    plan_title=$(head -1 "$PLAN_FILE" | sed 's/^# //')
    # Find first unchecked task
    next_task=$(grep -m1 '^\- \[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/^- \[ \] //')
    total=$(grep -c '^\- \[' "$PLAN_FILE" 2>/dev/null || echo "0")
    done_count=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo "0")
    CONTEXT+="
## Plan: $plan_title ($done_count/$total done)"
    [[ -n "$next_task" ]] && CONTEXT+="
Next: $next_task"
    CONTEXT+="
"
fi

# --- 3. Blocking warnings ---
# Thinking health
THINKING_FILE="$CLAUDE_DIR/logs/thinking-health.tsv"
if [[ -f "$THINKING_FILE" ]]; then
    th_last=$(tail -1 "$THINKING_FILE")
    th_pred_rate=$(echo "$th_last" | awk -F'\t' '{print $7}')
    th_edits=$(echo "$th_last" | awk -F'\t' '{print $2}')
    if [[ "$th_pred_rate" == "0" && "${th_edits:-0}" -gt 5 ]] 2>/dev/null; then
        CONTEXT+="
⚠ No predictions last session (${th_edits} edits). Predict before you act.
"
    fi
fi

# Workspace autonomy
WORKSPACE_FILE="$STATE_DIR/workspace.json"
if [[ -f "$WORKSPACE_FILE" ]] && command -v jq &>/dev/null; then
    autonomy=$(jq -r --arg pwd "$PROJECT_DIR" \
        '[.projects | to_entries[] | select(.value.path == $pwd)] | .[0].value.autonomy // empty' \
        "$WORKSPACE_FILE" 2>/dev/null)
    [[ -n "$autonomy" ]] && CONTEXT+="Autonomy: $autonomy
"
fi

# After compaction
CONTEXT+="
After compaction: re-read (1) agents/refs/thinking.md (2) active plan (3) experiment-learnings.md (4) relevant files.
"

if [[ -n "$CONTEXT" ]]; then
    echo "--- rhino-os ---"
    echo "$CONTEXT"
    echo "---"
fi

exit 0
