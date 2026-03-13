#!/usr/bin/env bash
# session_start.sh — SessionStart hook (v6)
# Boot card: project state, score, plan, staleness, integrity, prediction accuracy.
set -euo pipefail

PROJECT_DIR=$(pwd)
INPUT=$(cat)
SESSION_TYPE=$(echo "$INPUT" | jq -r '.type // "startup"' 2>/dev/null || echo "startup")

# --- Project name ---
PROJECT_NAME=""
if [[ -f "$PROJECT_DIR/config/rhino.yml" ]]; then
    PROJECT_NAME=$(grep -m1 '^name:' "$PROJECT_DIR/config/rhino.yml" 2>/dev/null | sed 's/^name: *//' || true)
fi
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(basename "$PROJECT_DIR")

# --- Last score + integrity ---
SCORE_DISPLAY=""
INTEGRITY_WARNINGS=""
SCORE_CACHE="$PROJECT_DIR/.claude/cache/score-cache.json"
if [[ -f "$SCORE_CACHE" ]] && command -v jq &>/dev/null; then
    TOTAL=$(jq -r '.total // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    BUILD=$(jq -r '.build // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    STRUCT=$(jq -r '.structure // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    HYGIENE=$(jq -r '.hygiene // "?"' "$SCORE_CACHE" 2>/dev/null || echo "?")
    SCORE_DISPLAY="Score: ${TOTAL}/100 (Build:${BUILD} Struct:${STRUCT} Hygiene:${HYGIENE})"

    # Surface integrity warnings
    WARNINGS_JSON=$(jq -r '.integrity_warnings // [] | .[]' "$SCORE_CACHE" 2>/dev/null || true)
    if [[ -n "$WARNINGS_JSON" ]]; then
        INTEGRITY_WARNINGS="$WARNINGS_JSON"
    fi
fi

# --- Active plan ---
PLAN_FILE=""
for p in "$PROJECT_DIR/.claude/plans/active-plan.md" "$HOME/.claude/plans/active-plan.md"; do
    if [[ -f "$p" ]]; then PLAN_FILE="$p"; break; fi
done

TASKS_REMAINING=0
NEXT_TASK=""
PLAN_STALE=""
if [[ -n "$PLAN_FILE" ]]; then
    TOTAL_TASKS=$(grep -c '^\- \[' "$PLAN_FILE" 2>/dev/null || echo 0)
    DONE_TASKS=$(grep -c '^\- \[x\]' "$PLAN_FILE" 2>/dev/null || echo 0)
    TASKS_REMAINING=$((TOTAL_TASKS - DONE_TASKS))
    NEXT_TASK=$(grep -m1 '^\- \[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/^- \[ \] //' || true)

    # Staleness check (>24h)
    if [[ "$(uname)" == "Darwin" ]]; then
        PLAN_MTIME=$(stat -f %m "$PLAN_FILE" 2>/dev/null || echo 0)
    else
        PLAN_MTIME=$(stat -c %Y "$PLAN_FILE" 2>/dev/null || echo 0)
    fi
    NOW=$(date +%s)
    AGE_HOURS=$(( (NOW - PLAN_MTIME) / 3600 ))
    if (( AGE_HOURS > 24 )); then
        PLAN_STALE="(${AGE_HOURS}h old — consider /plan)"
    fi
fi

# --- Strategy staleness ---
STRATEGY_STALE=""
PRODUCT_MODEL="$PROJECT_DIR/.claude/plans/product-model.md"
if [[ -f "$PRODUCT_MODEL" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        STRAT_MTIME=$(stat -f %m "$PRODUCT_MODEL" 2>/dev/null || echo 0)
    else
        STRAT_MTIME=$(stat -c %Y "$PRODUCT_MODEL" 2>/dev/null || echo 0)
    fi
    NOW=${NOW:-$(date +%s)}
    STRAT_AGE_DAYS=$(( (NOW - STRAT_MTIME) / 86400 ))
    if (( STRAT_AGE_DAYS > 3 )); then
        STRATEGY_STALE="Strategy: ${STRAT_AGE_DAYS}d old — stale"
    fi
fi

# --- Assertion status (value signal) ---
ASSERT_DISPLAY=""
BELIEFS_FILE="$PROJECT_DIR/config/evals/beliefs.yml"
if [[ -f "$BELIEFS_FILE" ]]; then
    TOTAL_BELIEFS=$(grep -c '^\s*- id:' "$BELIEFS_FILE" 2>/dev/null || echo "0")
    if (( TOTAL_BELIEFS > 0 )); then
        ASSERT_DISPLAY="Assertions: ${TOTAL_BELIEFS} planted"
    fi
fi

# --- Prediction accuracy (last 10) ---
PRED_DISPLAY=""
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    PRED_COUNT=$(tail -n +2 "$PRED_FILE" | wc -l | tr -d ' ')
    if (( PRED_COUNT > 0 )); then
        # Count correct predictions in last 10
        CORRECT=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$5 == "yes" { c++ } END { print c+0 }')
        RECENT=$(tail -n +2 "$PRED_FILE" | tail -10 | wc -l | tr -d ' ')
        FILLED=$(tail -n +2 "$PRED_FILE" | tail -10 | awk -F'\t' '$5 != "" { c++ } END { print c+0 }')
        if (( FILLED > 0 )); then
            PRED_DISPLAY="Predictions: ${CORRECT}/${FILLED} correct"
        else
            PRED_DISPLAY="Predictions: ${PRED_COUNT} logged, 0 graded"
        fi
    fi
fi

# === Output ===
echo ""
echo "rhino-os booted"
echo ""

LINE1="Project: ${PROJECT_NAME}"
[[ -n "$SCORE_DISPLAY" ]] && LINE1="$LINE1 | $SCORE_DISPLAY"
echo "$LINE1"

if [[ -n "$PLAN_FILE" && "$TASKS_REMAINING" -gt 0 ]]; then
    PLAN_LINE="Active plan: $TASKS_REMAINING tasks remaining"
    [[ -n "$PLAN_STALE" ]] && PLAN_LINE="$PLAN_LINE $PLAN_STALE"
    echo "$PLAN_LINE"
    [[ -n "$NEXT_TASK" ]] && echo "-> NEXT: $NEXT_TASK"
elif [[ -z "$SCORE_DISPLAY" ]]; then
    echo "No score yet — run: rhino score ."
fi

# Alerts line (integrity + strategy + predictions)
ALERTS=""
[[ -n "$INTEGRITY_WARNINGS" ]] && ALERTS="INTEGRITY: $(echo "$INTEGRITY_WARNINGS" | head -1)"
[[ -n "$STRATEGY_STALE" ]] && ALERTS="${ALERTS:+$ALERTS | }$STRATEGY_STALE"
[[ -n "$ASSERT_DISPLAY" ]] && ALERTS="${ALERTS:+$ALERTS | }$ASSERT_DISPLAY"
[[ -n "$PRED_DISPLAY" ]] && ALERTS="${ALERTS:+$ALERTS | }$PRED_DISPLAY"
[[ -n "$ALERTS" ]] && echo "$ALERTS"

# --- Compaction recovery ---
if [[ "$SESSION_TYPE" == "compact" ]]; then
    echo ""
    echo "Context compacted. Re-read:"
    echo "  1. mind/thinking.md"
    echo "  2. ~/.claude/knowledge/experiment-learnings.md"
    echo "  3. .claude/plans/active-plan.md"
fi
