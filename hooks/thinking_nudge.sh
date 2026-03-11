#!/usr/bin/env bash
# thinking_nudge.sh — PostToolUse hook on Edit/Write
# Tracks edits in session. After N edits without a prediction logged,
# nudges the agent to predict before continuing.
# This is the enforcement layer for the thinking protocol.

INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

# Only count Edit/Write tool uses
[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0

CLAUDE_DIR="$HOME/.claude"
STATE_DIR="$CLAUDE_DIR/state"
COUNTER_FILE="$STATE_DIR/.edit-count-session"
PRED_FILE="$CLAUDE_DIR/knowledge/predictions.tsv"

mkdir -p "$STATE_DIR"

# Increment edit counter
if [[ -f "$COUNTER_FILE" ]]; then
    COUNTER_AGE=$(( $(date +%s) - $(stat -f %m "$COUNTER_FILE" 2>/dev/null || stat -c %Y "$COUNTER_FILE" 2>/dev/null || echo "0") ))
    # Reset counter if file is >2 hours old (new session)
    if (( COUNTER_AGE > 7200 )); then
        echo "1" > "$COUNTER_FILE"
    else
        count=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
        echo "$(( count + 1 ))" > "$COUNTER_FILE"
    fi
else
    echo "1" > "$COUNTER_FILE"
fi

count=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")

# After 3 edits, check if any predictions have been logged today
today=$(date +%Y-%m-%d)
today_predictions=0
if [[ -f "$PRED_FILE" ]]; then
    today_predictions=$(grep -c "^$today" "$PRED_FILE" 2>/dev/null || echo "0")
fi

if (( count == 3 && today_predictions == 0 )); then
    echo "--- rhino-os thinking nudge ---"
    echo "3 edits this session, 0 predictions logged."
    echo "The thinking protocol asks: what did you PREDICT would happen before making these changes?"
    echo "Log predictions to ~/.claude/knowledge/predictions.tsv — even retroactively."
    echo "Format: date	agent	prediction	evidence	result	correct	model_update"
    echo "This is how the system learns. Without predictions, outcomes are noise."
    echo "--- end thinking nudge ---"
fi

# After 5 edits with 0 predictions: BLOCKING escalation
if (( count >= 5 && today_predictions == 0 )); then
    echo "--- rhino-os BLOCKING ---"
    echo "BLOCKING: ${count} edits, 0 predictions logged today."
    echo "Log at least one prediction before continuing."
    echo "Format: date	agent	prediction	evidence	result	correct	model_update"
    echo "File: ~/.claude/knowledge/predictions.tsv"
    echo "The system cannot learn from changes it didn't predict."
    echo "--- end blocking ---"
fi

# Every 20 edits, surface the knowledge model
if (( count % 20 == 0 && count > 0 )); then
    LEARNINGS="$CLAUDE_DIR/knowledge/experiment-learnings.md"
    if [[ -f "$LEARNINGS" ]]; then
        unknown_count=$(grep -c "never tested\|zero data\|0 experiments" "$LEARNINGS" 2>/dev/null || echo "0")
        if (( unknown_count > 0 )); then
            echo "--- rhino-os knowledge nudge ---"
            echo "${count} edits this session. ${unknown_count} unknown territories in experiment-learnings.md."
            echo "Are you working in known territory (exploiting) or exploring unknowns?"
            echo "If exploiting: cite the pattern you're building on."
            echo "If exploring: name what you're trying to learn."
            echo "--- end knowledge nudge ---"
        fi
    fi
fi

exit 0
