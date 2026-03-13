#!/usr/bin/env bash
# todo.sh — Read/write .claude/plans/todos.yml
# Persistent backlog that survives across plans.

set -euo pipefail

_BACKLOG_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_BACKLOG_SOURCE" ]]; do
    _BACKLOG_SOURCE="$(readlink "$_BACKLOG_SOURCE")"
done
RHINO_DIR="$(cd "$(dirname "$_BACKLOG_SOURCE")/.." && pwd)"

BACKLOG_FILE="$RHINO_DIR/.claude/plans/todos.yml"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helpers ─────────────────────────────────────────────

todo_exists() {
    [[ -f "$BACKLOG_FILE" ]]
}

# Get all item IDs
item_ids() {
    grep '^ *- id:' "$BACKLOG_FILE" 2>/dev/null | sed 's/.*id: *//'
}

# Get a field for a specific item ID
item_field() {
    local id="$1"
    local field="$2"
    awk -v id="$id" -v field="$field" '
        /^ *- id:/ { found = ($0 ~ "id: *" id "$") }
        found && $0 ~ "^ *" field ":" {
            sub(/^[^:]+: */, "")
            gsub(/^"/, ""); gsub(/"$/, "")
            print
            exit
        }
        found && /^ *- id:/ && !($0 ~ "id: *" id "$") { exit }
    ' "$BACKLOG_FILE"
}

priority_color() {
    case "$1" in
        urgent) echo -e "${RED}●${NC}" ;;
        high)   echo -e "${YELLOW}●${NC}" ;;
        medium) echo -e "${CYAN}·${NC}" ;;
        low)    echo -e "${DIM}·${NC}" ;;
        *)      echo -e "${DIM}·${NC}" ;;
    esac
}

priority_sort_key() {
    case "$1" in
        urgent) echo "0" ;;
        high)   echo "1" ;;
        medium) echo "2" ;;
        low)    echo "3" ;;
        *)      echo "4" ;;
    esac
}

# ── Commands ────────────────────────────────────────────

cmd_show() {
    if ! todo_exists; then
        echo -e "  ${DIM}No todos.yml — backlog is empty${NC}"
        return 0
    fi

    local total
    total=$(grep -c '^ *- id:' "$BACKLOG_FILE" 2>/dev/null) || true
    [[ -z "$total" ]] && total=0

    if [[ "$total" -eq 0 ]]; then
        echo -e "  ${DIM}Backlog empty${NC}"
        return 0
    fi

    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}Backlog${NC}  ${DIM}${total} items${NC}"
    echo ""

    # Collect and sort by priority
    local items=()
    while IFS= read -r id; do
        local priority title context
        priority=$(item_field "$id" "priority")
        title=$(item_field "$id" "title")
        context=$(item_field "$id" "context")
        local sort_key
        sort_key=$(priority_sort_key "$priority")
        items+=("${sort_key}|${id}|${priority}|${title}|${context}")
    done <<< "$(item_ids)"

    # Sort and display
    printf '%s\n' "${items[@]}" | sort | while IFS='|' read -r _ id priority title context; do
        local marker
        marker=$(priority_color "$priority")
        echo -e "  ${marker} ${title}  ${DIM}[${id}]${NC}"
        [[ -n "$context" ]] && echo -e "    ${DIM}${context}${NC}"
    done

    echo ""
}

cmd_add() {
    local title="$1"
    local priority="${2:-medium}"

    if [[ -z "$title" ]]; then
        echo "Usage: rhino todo add \"title\" [priority]"
        return 1
    fi

    # Generate ID from title
    local id
    id=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 30)

    local today
    today=$(date '+%Y-%m-%d')

    if ! todo_exists; then
        mkdir -p "$(dirname "$BACKLOG_FILE")"
        cat > "$BACKLOG_FILE" << EOF
# todos.yml — Persistent backlog

items:
EOF
    fi

    cat >> "$BACKLOG_FILE" << EOF

  - id: ${id}
    title: "${title}"
    priority: ${priority}
    context: ""
    source: "manual"
    created: ${today}
EOF

    echo -e "  ${GREEN}+${NC} ${title}  ${DIM}[${id}] ${priority}${NC}"
}

cmd_done() {
    local target_id="$1"
    if [[ -z "$target_id" ]]; then
        echo "Usage: rhino todo done <item-id>"
        return 1
    fi
    if ! todo_exists; then
        echo "No todos.yml found"
        return 1
    fi
    if ! grep -q "id: ${target_id}$" "$BACKLOG_FILE" 2>/dev/null; then
        echo "Item '$target_id' not found"
        return 1
    fi

    # Remove the item block (from - id: to next - id: or end)
    awk -v id="$target_id" '
        /^ *- id:/ {
            if ($0 ~ "id: *" id "$") { skip = 1; next }
            else { skip = 0 }
        }
        skip && /^ *[^ -]/ { next }
        skip && /^ *$/ { next }
        !skip { print }
    ' "$BACKLOG_FILE" > "${BACKLOG_FILE}.tmp" && mv "${BACKLOG_FILE}.tmp" "$BACKLOG_FILE"

    echo -e "  ${GREEN}✓${NC} ${target_id} removed"
}

# ── Main ────────────────────────────────────────────────

case "${1:-show}" in
    show|list|"") cmd_show ;;
    add)          shift; cmd_add "${1:-}" "${2:-medium}" ;;
    done|rm)      shift; cmd_done "${1:-}" ;;
    *)
        echo "Usage: rhino todo [show|add \"title\" [priority]|done <id>]"
        exit 1
        ;;
esac
