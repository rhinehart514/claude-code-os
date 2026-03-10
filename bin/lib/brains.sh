#!/usr/bin/env bash
# brains.sh — Simplified agent brain system for rhino-os.
# Each agent gets: next_move, bias_awareness, last_run, updated.
# No stances, no credibility, no conflicts. Just signal.
# Sourced by bin/rhino.

BRAINS_DIR="$STATE_DIR/brains"

# Agent-specific bias awareness (good signal — kept from original)
_brain_bias() {
    case "$1" in
        scout)           echo 'Market surprises you. Bias toward 0.5-0.7 conviction. Overconfidence on market predictions is your biggest risk.' ;;
        strategist)      echo 'You tend to accept scout market reads uncritically. Challenge with portfolio evidence. Your blind spot is sunk-cost bias on existing projects.' ;;
        builder)         echo 'You overestimate how much score improvement a single change will produce. Stake claims you can actually measure.' ;;
        design-engineer) echo 'You bias toward subjective taste judgments. Cite taste eval evidence, not vibes. "I feel" loses to "The score says."' ;;
        sweep)           echo 'Track your false alarm rate. If >50% of REDs turn out to be non-issues, lower conviction on safety calls.' ;;
        meta)            echo 'You are the referee. Your bias is toward finding problems even when the system is working. Sometimes no fix is the right fix.' ;;
        *)               echo '' ;;
    esac
}

# Ensure brains directory exists
_ensure_brains_dir() {
    mkdir -p "$BRAINS_DIR"
}

# Get brain file path for an agent
_brain_path() {
    echo "$BRAINS_DIR/${1}.json"
}

# Create brain if it doesn't exist — simple JSON, no template file needed
_ensure_brain() {
    local agent="$1"
    local brain_file
    brain_file="$(_brain_path "$agent")"

    if [[ ! -f "$brain_file" ]]; then
        _ensure_brains_dir

        local bias
        bias="$(_brain_bias "$agent")"
        local now
        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        if command -v jq &>/dev/null; then
            jq -n \
               --arg agent "$agent" \
               --arg bias "$bias" \
               --arg now "$now" \
               '{
                   agent: $agent,
                   next_move: "",
                   bias_awareness: $bias,
                   last_run: $now,
                   updated: $now
               }' > "$brain_file"
        else
            cat > "$brain_file" <<EOF
{
  "agent": "$agent",
  "next_move": "",
  "bias_awareness": "$bias",
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated": ""
}
EOF
        fi

        echo -e "${DIM}  brain created: $agent${NC}" >&2
    fi
}

# Inject brain content into agent prompt
# Usage: inject_brain "agent_name"
# Outputs next_move + bias_awareness to stdout
inject_brain() {
    local agent="$1"
    _ensure_brain "$agent"

    local brain_file
    brain_file="$(_brain_path "$agent")"

    local next_move=""
    local bias=""

    if command -v jq &>/dev/null; then
        next_move=$(jq -r '.next_move // "" | if type == "object" then .action // "" else . end' "$brain_file" 2>/dev/null)
        bias=$(jq -r '.bias_awareness // ""' "$brain_file" 2>/dev/null)
    fi

    cat <<BRAIN_EOF

--- Your Brain (persistent memory) ---
After running, update your brain file at $brain_file with:
- next_move: what should happen next and why
- last_run: current timestamp
- updated: current timestamp

Your bias: ${bias:-none}
Your next_move from last run: ${next_move:-none}
--- End Brain ---
BRAIN_EOF
}
