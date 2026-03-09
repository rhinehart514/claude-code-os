#!/usr/bin/env bash
# config.sh — Shared config reader for rhino-os components.
# Sources rhino.yml and provides cfg() function.
#
# Usage (from any bin/ script):
#   source "$(dirname "$0")/lib/config.sh"
#   cache_ttl=$(cfg scoring.cache_ttl 300)

_RHINO_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_RHINO_CONFIG_FILE="$_RHINO_CONFIG_DIR/config/rhino.yml"

# Read a dotted key from rhino.yml.
# Usage: cfg "agents.budgets.scout" "default_value"
cfg() {
    local key="$1"
    local default="${2:-}"
    if [[ ! -f "$_RHINO_CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    local IFS='.'
    read -ra parts <<< "$key"
    local matched=0
    local target_indent=-1

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        local stripped="${line#"${line%%[![:space:]]*}"}"
        local spaces=$(( ${#line} - ${#stripped} ))

        # If we've matched some parts but indent went back, reset
        if [[ "$matched" -gt 0 && "$target_indent" -ge 0 && "$spaces" -le "$target_indent" && "$matched" -lt "${#parts[@]}" ]]; then
            matched=0
            target_indent=-1
        fi

        if [[ "$stripped" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*):(.*)$ ]]; then
            local ykey="${BASH_REMATCH[1]}"
            local yval="${BASH_REMATCH[2]}"
            yval="${yval#"${yval%%[![:space:]]*}"}"

            if [[ "$ykey" == "${parts[$matched]}" ]]; then
                ((matched++))
                target_indent=$spaces
                if [[ "$matched" -eq "${#parts[@]}" ]]; then
                    # Strip inline comments and trailing whitespace
                    yval="${yval%%[[:space:]]#*}"
                    yval="${yval%"${yval##*[![:space:]]}"}"
                    if [[ -z "$yval" || "$yval" == "~" ]]; then
                        echo "$default"
                    else
                        echo "$yval"
                    fi
                    return
                fi
            fi
        fi
    done < "$_RHINO_CONFIG_FILE"
    echo "$default"
}
