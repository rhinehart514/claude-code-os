#!/usr/bin/env bash
set -euo pipefail

# trail.sh — Render the evidence trail from session logs
# Reads .claude/sessions/*.yml and shows the arc of improvement.

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
SESSIONS_DIR="$PROJECT_DIR/.claude/sessions"

# Colors
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[0;36m'
C_NC='\033[0m'

if [[ ! -d "$SESSIONS_DIR" ]] || ! ls "$SESSIONS_DIR"/*.yml >/dev/null 2>&1; then
    echo ""
    echo -e "  ${C_DIM}no sessions yet — run /go to start the trail${C_NC}"
    echo ""
    exit 0
fi

# --- Aggregate session data ---
TOTAL_SESSIONS=0
TOTAL_MOVES=0
TOTAL_KEPT=0
TOTAL_REVERTED=0
SCORES=""
ACCURACIES=""
LEARNINGS=""

for session in "$SESSIONS_DIR"/*.yml; do
    [[ ! -f "$session" ]] && continue
    TOTAL_SESSIONS=$((TOTAL_SESSIONS + 1))

    # Parse simple YAML fields (top-level only, no nesting)
    moves=$(grep -m1 '^moves:' "$session" 2>/dev/null | sed 's/^moves:[[:space:]]*//' || echo "0")
    kept=$(grep -m1 '^kept:' "$session" 2>/dev/null | sed 's/^kept:[[:space:]]*//' || echo "0")
    reverted=$(grep -m1 '^reverted:' "$session" 2>/dev/null | sed 's/^reverted:[[:space:]]*//' || echo "0")
    score_after=$(grep -m1 '^score_after:' "$session" 2>/dev/null | sed 's/^score_after:[[:space:]]*//' || echo "")

    [[ "$moves" =~ ^[0-9]+$ ]] && TOTAL_MOVES=$((TOTAL_MOVES + moves))
    [[ "$kept" =~ ^[0-9]+$ ]] && TOTAL_KEPT=$((TOTAL_KEPT + kept))
    [[ "$reverted" =~ ^[0-9]+$ ]] && TOTAL_REVERTED=$((TOTAL_REVERTED + reverted))
    [[ -n "$score_after" && "$score_after" =~ ^[0-9]+$ ]] && SCORES="${SCORES:+$SCORES }$score_after"

    # Collect prediction accuracy per session
    pred_correct=$(grep -c 'correct: yes' "$session" 2>/dev/null || echo "0")
    pred_partial=$(grep -c 'correct: partial' "$session" 2>/dev/null || echo "0")
    pred_total=$(grep -c 'correct:' "$session" 2>/dev/null || echo "0")
    if [[ "$pred_total" -gt 0 ]]; then
        # partial = 0.5 credit
        effective=$(awk "BEGIN { printf \"%d\", $pred_correct + $pred_partial * 0.5 }")
        acc=$((effective * 100 / pred_total))
        ACCURACIES="${ACCURACIES:+$ACCURACIES }${acc}%"
    fi

    # Collect learnings
    in_learnings=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^learnings: ]]; then
            in_learnings=true
            continue
        fi
        if $in_learnings; then
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]] ]]; then
                learning=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                LEARNINGS="${LEARNINGS}${learning}\n"
            else
                in_learnings=false
            fi
        fi
    done < "$session"
done

# --- Keep rate ---
DECIDABLE=$((TOTAL_KEPT + TOTAL_REVERTED))
KEEP_RATE=""
if [[ "$DECIDABLE" -gt 0 ]]; then
    KEEP_RATE="$((TOTAL_KEPT * 100 / DECIDABLE))%"
fi

# --- Output ---
echo ""
echo -e "  ${C_CYAN}◆${C_NC} ${C_BOLD}trail${C_NC} — ${TOTAL_SESSIONS} sessions, ${TOTAL_MOVES} moves${KEEP_RATE:+, ${KEEP_RATE} kept}"
echo ""

# Score trajectory
if [[ -n "$SCORES" ]]; then
    SCORE_LINE="  ${C_DIM}score${C_NC}     "
    FIRST=true
    for s in $SCORES; do
        if $FIRST; then
            SCORE_LINE="${SCORE_LINE}${s}"
            FIRST=false
        else
            SCORE_LINE="${SCORE_LINE} ${C_DIM}───${C_NC} ${s}"
        fi
    done
    echo -e "$SCORE_LINE"
fi

# Prediction accuracy trajectory
if [[ -n "$ACCURACIES" ]]; then
    ACC_LINE="  ${C_DIM}accuracy${C_NC}  "
    FIRST=true
    for a in $ACCURACIES; do
        if $FIRST; then
            ACC_LINE="${ACC_LINE}${a}"
            FIRST=false
        else
            ACC_LINE="${ACC_LINE}  ${a}"
        fi
    done
    echo -e "$ACC_LINE"
fi

echo ""

# Top learnings (last 5, deduplicated)
if [[ -n "$LEARNINGS" ]]; then
    echo -e "  ${C_DIM}▾ top learnings${C_NC}"
    echo -e "$LEARNINGS" | grep -v '^$' | sort -u | tail -5 | while IFS= read -r l; do
        [[ -n "$l" ]] && echo -e "    ${C_DIM}·${C_NC} ${l}"
    done
    echo ""
fi

# --- Knowledge model growth ---
LEARNINGS_FILE="$PROJECT_DIR/.claude/knowledge/experiment-learnings.md"
[[ ! -f "$LEARNINGS_FILE" ]] && LEARNINGS_FILE="$HOME/.claude/knowledge/experiment-learnings.md"

if [[ -f "$LEARNINGS_FILE" ]]; then
    KNOWN_CT=$(awk '/^## Known Patterns/,/^## /' "$LEARNINGS_FILE" 2>/dev/null | grep -c '^\s*-\s' || echo "0")
    UNCERTAIN_CT=$(awk '/^## Uncertain Patterns/,/^## /' "$LEARNINGS_FILE" 2>/dev/null | grep -c '^\s*-\s' || echo "0")
    UNKNOWN_CT=$(awk '/^## Unknown Territory/,/^## /' "$LEARNINGS_FILE" 2>/dev/null | grep -c '^\s*-\s' || echo "0")
    DEAD_CT=$(awk '/^## Dead Ends/,/^## /' "$LEARNINGS_FILE" 2>/dev/null | grep -c '^\s*-\s' || echo "0")

    echo -e "  ${C_DIM}▾ knowledge model${C_NC}"
    echo -e "    ${C_GREEN}known${C_NC} ${KNOWN_CT}  ${C_YELLOW}uncertain${C_NC} ${UNCERTAIN_CT}  ${C_DIM}unknown${C_NC} ${UNKNOWN_CT}  ${C_RED}dead ends${C_NC} ${DEAD_CT}"
    echo ""
fi

# --- Prediction accuracy trend across sessions ---
PRED_FILE="$PROJECT_DIR/.claude/knowledge/predictions.tsv"
[[ ! -f "$PRED_FILE" ]] && PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"

if [[ -f "$PRED_FILE" ]]; then
    GRADED_ALL=$(tail -n +2 "$PRED_FILE" | awk -F'\t' '$6 != ""' 2>/dev/null)
    GRADED_TOTAL=$(echo "$GRADED_ALL" | grep -c '.' 2>/dev/null || echo "0")
    if [[ "$GRADED_TOTAL" -ge 3 ]]; then
        CORRECT_CT=$(echo "$GRADED_ALL" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
        PARTIAL_CT=$(echo "$GRADED_ALL" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
        EFFECTIVE=$(awk "BEGIN { printf \"%d\", ($CORRECT_CT + $PARTIAL_CT * 0.5) * 100 / $GRADED_TOTAL }")
        echo -e "  ${C_DIM}▾ prediction accuracy${C_NC}"
        echo -e "    ${C_BOLD}${EFFECTIVE}%${C_NC} overall (${GRADED_TOTAL} graded)  ${C_DIM}·${C_NC}  ${CORRECT_CT} correct, ${PARTIAL_CT} partial"

        # Show trend if enough data: accuracy of first half vs second half
        if [[ "$GRADED_TOTAL" -ge 6 ]]; then
            HALF=$((GRADED_TOTAL / 2))
            EARLY_CORRECT=$(echo "$GRADED_ALL" | head -"$HALF" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
            EARLY_PARTIAL=$(echo "$GRADED_ALL" | head -"$HALF" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
            EARLY_EFF=$(awk "BEGIN { printf \"%d\", ($EARLY_CORRECT + $EARLY_PARTIAL * 0.5) * 100 / $HALF }")
            LATE_CORRECT=$(echo "$GRADED_ALL" | tail -"$HALF" | awk -F'\t' '$6 == "yes" { c++ } END { print c+0 }')
            LATE_PARTIAL=$(echo "$GRADED_ALL" | tail -"$HALF" | awk -F'\t' '$6 == "partial" { c++ } END { print c+0 }')
            LATE_EFF=$(awk "BEGIN { printf \"%d\", ($LATE_CORRECT + $LATE_PARTIAL * 0.5) * 100 / $HALF }")
            if [[ "$LATE_EFF" -gt "$EARLY_EFF" ]]; then
                echo -e "    ${C_GREEN}↑${C_NC} trajectory: ${EARLY_EFF}% → ${LATE_EFF}% (improving)"
            elif [[ "$LATE_EFF" -lt "$EARLY_EFF" ]]; then
                echo -e "    ${C_RED}↓${C_NC} trajectory: ${EARLY_EFF}% → ${LATE_EFF}% (declining)"
            else
                echo -e "    ${C_DIM}→ trajectory: stable at ${LATE_EFF}%${C_NC}"
            fi
        fi
        echo ""
    fi
fi
