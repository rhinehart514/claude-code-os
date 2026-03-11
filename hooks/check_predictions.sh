#!/usr/bin/env bash
# check_predictions.sh — Stop hook
# At session end: check if predictions were logged, update the model.
# The learning happens HERE — between sessions, not during them.

cat > /dev/null  # drain stdin

CLAUDE_DIR="$HOME/.claude"
PRED_FILE="$CLAUDE_DIR/knowledge/predictions.tsv"
LEARNINGS_FILE="$CLAUDE_DIR/knowledge/experiment-learnings.md"
EDIT_COUNTER="$CLAUDE_DIR/state/.edit-count-session"
LOG_FILE="$CLAUDE_DIR/logs/thinking-health.tsv"

mkdir -p "$CLAUDE_DIR/logs"

today=$(date +%Y-%m-%d)
edits=0
[[ -f "$EDIT_COUNTER" ]] && edits=$(cat "$EDIT_COUNTER" 2>/dev/null || echo "0")

# Count today's predictions
predictions=0
correct=0
wrong=0
if [[ -f "$PRED_FILE" ]]; then
    predictions=$(grep -c "^$today" "$PRED_FILE" 2>/dev/null || echo "0")
    correct=$(grep "^$today" "$PRED_FILE" 2>/dev/null | awk -F'\t' '$6 == "yes"' | wc -l | tr -d ' ')
    wrong=$(grep "^$today" "$PRED_FILE" 2>/dev/null | awk -F'\t' '$6 == "no"' | wc -l | tr -d ' ')
fi

# Count model updates (wrong predictions that updated the model)
model_updates=0
if [[ -f "$PRED_FILE" ]]; then
    model_updates=$(grep "^$today" "$PRED_FILE" 2>/dev/null | awk -F'\t' '$6 == "no" && $7 != ""' | wc -l | tr -d ' ')
fi

# Log thinking health
if [[ ! -f "$LOG_FILE" ]]; then
    printf "date\tedits\tpredictions\tcorrect\twrong\tmodel_updates\tpred_rate\n" > "$LOG_FILE"
fi

pred_rate=0
if (( edits > 0 )); then
    pred_rate=$(( predictions * 100 / edits ))
fi

printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$today" "$edits" "$predictions" "$correct" "$wrong" "$model_updates" "$pred_rate" >> "$LOG_FILE"

# Reset edit counter for next session
rm -f "$EDIT_COUNTER"

# Check if learnings file was updated today
learnings_updated=false
if [[ -f "$LEARNINGS_FILE" ]]; then
    learnings_age=$(( $(date +%s) - $(stat -f %m "$LEARNINGS_FILE" 2>/dev/null || stat -c %Y "$LEARNINGS_FILE" 2>/dev/null || echo "0") ))
    if (( learnings_age < 86400 )); then
        learnings_updated=true
    fi
fi

# Summary output (goes to Stop hook log, not shown to user)
if (( edits > 5 && predictions == 0 )); then
    echo "THINKING: ${edits} edits, 0 predictions. System executed but didn't think."
elif (( wrong > 0 && model_updates == 0 )); then
    echo "THINKING: ${wrong} wrong predictions but 0 model updates. Wrong without learning."
fi

exit 0
