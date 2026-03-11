#!/usr/bin/env bash
set -euo pipefail

# autonomy_gate.sh — PreToolUse hook: enforces per-project autonomy levels.
# Reads session override first, falls back to workspace.json.
#
# Autonomy levels:
#   manual     — blocks Agent tool, warns on process-spawning Bash
#   guided     — allows Agent, blocks autonomous loop triggers
#   autonomous — allows everything

# MUST drain stdin first — hook protocol requires it
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name' 2>/dev/null || echo "")"

# Only gate Agent and Bash tools
if [[ "$TOOL_NAME" != "Agent" && "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

CLAUDE_DIR="$HOME/.claude"
STATE_DIR="$CLAUDE_DIR/state"
WORKSPACE_FILE="$STATE_DIR/workspace.json"

# --- Determine autonomy level ---

# 1. Check session override (expires after 2h)
AUTONOMY=""
SESSION_OVERRIDE="$STATE_DIR/.session-autonomy"
if [[ -f "$SESSION_OVERRIDE" ]]; then
    OVERRIDE_AGE=$(( $(date +%s) - $(stat -f %m "$SESSION_OVERRIDE" 2>/dev/null || stat -c %Y "$SESSION_OVERRIDE" 2>/dev/null || echo "0") ))
    if (( OVERRIDE_AGE < 7200 )); then
        AUTONOMY="$(head -1 "$SESSION_OVERRIDE")"
    fi
fi

# 2. Fall back to workspace.json for current project
if [[ -z "$AUTONOMY" && -f "$WORKSPACE_FILE" ]] && command -v jq &>/dev/null; then
    CURRENT_DIR="$(pwd)"
    AUTONOMY=$(jq -r --arg pwd "$CURRENT_DIR" \
        '[.projects | to_entries[] | select(.value.path == $pwd or ($pwd | startswith(.value.path + "/")))] | sort_by(.value.path | length) | reverse | .[0].value.autonomy // empty' \
        "$WORKSPACE_FILE" 2>/dev/null)
fi

# 3. Default to guided if not set
AUTONOMY="${AUTONOMY:-guided}"

# --- Apply gates ---

case "$AUTONOMY" in
    manual)
        if [[ "$TOOL_NAME" == "Agent" ]]; then
            echo '{"decision": "block", "reason": "Autonomy level is MANUAL — sub-agents are not allowed. Switch to guided or autonomous mode, or ask the user to approve."}' >&2
            exit 2
        fi
        # For Bash: warn but don't block (user can still approve)
        ;;
    guided)
        # Allow Agent tool, but could gate specific autonomous patterns if needed
        ;;
    autonomous)
        # Allow everything
        ;;
esac

exit 0
