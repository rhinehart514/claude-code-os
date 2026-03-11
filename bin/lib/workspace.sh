#!/usr/bin/env bash
# workspace.sh — Central project registry for rhino-os.
# Manages ~/.claude/state/workspace.json — the multi-project registry.
#
# Usage (from any bin/ script or hook):
#   source "$(dirname "$0")/lib/workspace.sh"
#   ws_register "/path/to/project" "mvp" "guided" "balanced"
#   ws_get "hive" "path"
#   ws_current

WORKSPACE_FILE="${WORKSPACE_FILE:-$HOME/.claude/state/workspace.json}"

# Ensure workspace.json exists with valid structure
_ws_ensure() {
    local dir
    dir="$(dirname "$WORKSPACE_FILE")"
    mkdir -p "$dir"
    if [[ ! -f "$WORKSPACE_FILE" ]]; then
        cat > "$WORKSPACE_FILE" <<'EOF'
{
  "projects": {},
  "focus": "",
  "updated": ""
}
EOF
    fi
}

# Register a project in workspace.json
# Usage: ws_register "/path/to/project" "stage" "autonomy" "experimentation"
ws_register() {
    local project_path="$1"
    local stage="${2:-mvp}"
    local autonomy="${3:-guided}"
    local experimentation="${4:-balanced}"

    _ws_ensure

    local project_name
    project_name="$(basename "$project_path")"
    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if ! command -v jq &>/dev/null; then
        echo "Error: jq required for workspace management" >&2
        return 1
    fi

    # Add or update project
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$project_name" \
       --arg path "$project_path" \
       --arg stage "$stage" \
       --arg autonomy "$autonomy" \
       --arg experimentation "$experimentation" \
       --arg now "$now" \
       '.projects[$name] = {
           path: $path,
           stage: $stage,
           autonomy: $autonomy,
           experimentation: $experimentation,
           features: [],
           last_score: null,
           last_taste: null,
           active: true
       } | .updated = $now | if .focus == "" then .focus = $name else . end' \
       "$WORKSPACE_FILE" > "$tmp" && mv "$tmp" "$WORKSPACE_FILE"
}

# Get a field from a project
# Usage: ws_get "project_name" "field"
ws_get() {
    local project_name="$1"
    local field="$2"

    _ws_ensure

    if ! command -v jq &>/dev/null; then
        echo ""
        return
    fi

    jq -r --arg name "$project_name" --arg field "$field" \
        '.projects[$name][$field] // empty' "$WORKSPACE_FILE" 2>/dev/null
}

# Set a field on a project
# Usage: ws_set "project_name" "field" "value"
ws_set() {
    local project_name="$1"
    local field="$2"
    local value="$3"

    _ws_ensure

    if ! command -v jq &>/dev/null; then
        echo "Error: jq required" >&2
        return 1
    fi

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$project_name" \
       --arg field "$field" \
       --arg value "$value" \
       --arg now "$now" \
       '.projects[$name][$field] = $value | .updated = $now' \
       "$WORKSPACE_FILE" > "$tmp" && mv "$tmp" "$WORKSPACE_FILE"
}

# Set a numeric field on a project
# Usage: ws_set_num "project_name" "field" 72
ws_set_num() {
    local project_name="$1"
    local field="$2"
    local value="$3"

    _ws_ensure

    if ! command -v jq &>/dev/null; then return 1; fi

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$project_name" \
       --arg field "$field" \
       --argjson value "$value" \
       --arg now "$now" \
       '.projects[$name][$field] = $value | .updated = $now' \
       "$WORKSPACE_FILE" > "$tmp" && mv "$tmp" "$WORKSPACE_FILE"
}

# Set features array on a project
# Usage: ws_set_features "project_name" "feat1" "feat2" "feat3"
ws_set_features() {
    local project_name="$1"
    shift
    local features_json="[]"
    for f in "$@"; do
        features_json=$(echo "$features_json" | jq --arg f "$f" '. + [$f]')
    done

    _ws_ensure

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$project_name" \
       --argjson features "$features_json" \
       --arg now "$now" \
       '.projects[$name].features = $features | .updated = $now' \
       "$WORKSPACE_FILE" > "$tmp" && mv "$tmp" "$WORKSPACE_FILE"
}

# Get current project based on $PWD
# Returns project name if found, empty string otherwise
ws_current() {
    _ws_ensure

    if ! command -v jq &>/dev/null; then
        echo ""
        return
    fi

    local current_dir="${PWD}"
    jq -r --arg pwd "$current_dir" \
        '[.projects | to_entries[] | select(.value.path == $pwd or ($pwd | startswith(.value.path + "/")))] | sort_by(.value.path | length) | reverse | .[0].key // empty' \
        "$WORKSPACE_FILE" 2>/dev/null
}

# Get current project's autonomy level (with session override support)
# Returns: manual, guided, or autonomous
ws_autonomy() {
    local session_override="$HOME/.claude/state/.session-autonomy"

    # Check session override first (expires after 2h)
    if [[ -f "$session_override" ]]; then
        local override_age
        override_age=$(( $(date +%s) - $(stat -f %m "$session_override" 2>/dev/null || stat -c %Y "$session_override" 2>/dev/null || echo "0") ))
        if (( override_age < 7200 )); then
            head -1 "$session_override"
            return
        fi
    fi

    # Fall back to workspace.json
    local project
    project="$(ws_current)"
    if [[ -n "$project" ]]; then
        ws_get "$project" "autonomy"
    else
        echo "manual"
    fi
}

# List all active projects
# Output: one project name per line
ws_list_active() {
    _ws_ensure

    if ! command -v jq &>/dev/null; then return; fi

    jq -r '.projects | to_entries[] | select(.value.active == true) | .key' \
        "$WORKSPACE_FILE" 2>/dev/null
}

# Get the focus project name
ws_focus() {
    _ws_ensure
    jq -r '.focus // empty' "$WORKSPACE_FILE" 2>/dev/null
}

# Set the focus project
ws_set_focus() {
    local project_name="$1"
    _ws_ensure
    local tmp
    tmp="$(mktemp)"
    jq --arg name "$project_name" '.focus = $name' \
        "$WORKSPACE_FILE" > "$tmp" && mv "$tmp" "$WORKSPACE_FILE"
}
