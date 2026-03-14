#!/usr/bin/env bash
# feature.sh — List, view, and detect features
set -euo pipefail

_FEAT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$_FEAT_SOURCE" ]]; do _FEAT_SOURCE="$(readlink "$_FEAT_SOURCE")"; done
RHINO_DIR="$(cd "$(dirname "$_FEAT_SOURCE")/.." && pwd)"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# Find beliefs file
BELIEFS_FILE=""
for bf in "lens/product/eval/beliefs.yml" "config/evals/beliefs.yml"; do
    [[ -f "$bf" ]] && BELIEFS_FILE="$bf" && break
done

# Get features from beliefs.yml
get_features() {
    [[ -z "$BELIEFS_FILE" ]] && return
    grep '^\s*feature:' "$BELIEFS_FILE" 2>/dev/null | sed 's/.*feature: *//' | sort -u
}

# Get assertion count for a feature
count_assertions() {
    local feat="$1"
    [[ -z "$BELIEFS_FILE" ]] && echo "0" && return
    # Count beliefs that have this feature
    local count=0
    local in_belief=false current_feat=""
    while IFS= read -r line; do
        if echo "$line" | grep -q '^\s*- id:'; then
            if [[ "$in_belief" == true && "$current_feat" == "$feat" ]]; then
                count=$((count + 1))
            fi
            in_belief=true
            current_feat=""
        fi
        if echo "$line" | grep -q '^\s*feature:'; then
            current_feat=$(echo "$line" | sed 's/.*feature: *//')
        fi
    done < "$BELIEFS_FILE"
    # Last belief
    if [[ "$in_belief" == true && "$current_feat" == "$feat" ]]; then
        count=$((count + 1))
    fi
    echo "$count"
}

# === List all features ===
cmd_list() {
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}features${NC}"
    echo ""

    local features
    features=$(get_features)

    if [[ -z "$features" ]]; then
        echo -e "  ${DIM}No features defined. Add feature: fields to beliefs.yml${NC}"
        echo -e "  ${DIM}or run: rhino feature detect${NC}"
        echo ""
        return
    fi

    # Read from score cache if available
    local cache=".claude/cache/score-cache.json"

    while IFS= read -r feat; do
        [[ -z "$feat" ]] && continue
        local count pass total pct color bar

        if [[ -f "$cache" ]] && command -v jq &>/dev/null; then
            pass=$(jq -r ".features.\"$feat\".pass // 0" "$cache" 2>/dev/null) || pass=0
            total=$(jq -r ".features.\"$feat\".total // 0" "$cache" 2>/dev/null) || total=0
        else
            total=$(count_assertions "$feat")
            pass="?"
        fi

        if [[ "$total" -gt 0 && "$pass" != "?" ]]; then
            pct=$((pass * 100 / total))
            if [[ "$pct" -ge 70 ]]; then color="$GREEN"
            elif [[ "$pct" -ge 40 ]]; then color="$YELLOW"
            else color="$RED"
            fi
            # Mini bar (10 chars)
            local filled=$((pct / 10)) empty=$((10 - pct / 10))
            bar=""
            for ((i=0; i<filled; i++)); do bar+="█"; done
            for ((i=0; i<empty; i++)); do bar+="░"; done
            printf "  %-14s ${color}${bar}${NC}  %s/%s\n" "$feat" "$pass" "$total"
        else
            printf "  %-14s ${DIM}%s assertions${NC}\n" "$feat" "$total"
        fi
    done <<< "$features"

    echo ""
}

# === View one feature ===
cmd_view() {
    local feat="$1"
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}$feat${NC}"
    echo ""

    if [[ -z "$BELIEFS_FILE" ]]; then
        echo -e "  ${DIM}No beliefs.yml found${NC}"
        return
    fi

    # Run eval for just this feature
    local eval_output
    eval_output=$("$RHINO_DIR/bin/eval.sh" . --feature "$feat" 2>/dev/null) || eval_output=""

    if [[ -n "$eval_output" ]]; then
        echo "$eval_output" | grep '^\s*\[' | while IFS= read -r line; do
            if echo "$line" | grep -q '\[PASS\]'; then
                echo -e "    ${GREEN}✓${NC} $(echo "$line" | sed 's/.*\[PASS\] //')"
            elif echo "$line" | grep -q '\[FAIL\]'; then
                echo -e "    ${RED}✗${NC} $(echo "$line" | sed 's/.*\[FAIL\] //')"
            elif echo "$line" | grep -q '\[WARN\]'; then
                echo -e "    ${YELLOW}⚠${NC} $(echo "$line" | sed 's/.*\[WARN\] //')"
            fi
        done
    else
        echo -e "  ${DIM}No assertions for feature '$feat'${NC}"
    fi

    echo ""
}

# === Detect features from codebase ===
cmd_detect() {
    echo ""
    echo -e "  ${CYAN}◆${NC} ${BOLD}feature detect${NC}"
    echo ""

    local found=0

    # Next.js route groups: app/(group)/
    if [[ -d "app" ]]; then
        for d in app/\(*/; do
            [[ ! -d "$d" ]] && continue
            local name
            name=$(basename "$d" | tr -d '()')
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(route group: $d)${NC}"
            found=$((found + 1))
        done
    fi

    # Top-level src directories
    if [[ -d "src" ]]; then
        for d in src/*/; do
            [[ ! -d "$d" ]] && continue
            local name
            name=$(basename "$d")
            [[ "$name" == "components" || "$name" == "lib" || "$name" == "utils" || "$name" == "styles" || "$name" == "types" ]] && continue
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(src directory: $d)${NC}"
            found=$((found + 1))
        done
    fi

    # Package.json workspaces
    if [[ -f "package.json" ]] && grep -q '"workspaces"' package.json 2>/dev/null; then
        for ws in packages/*/; do
            [[ ! -d "$ws" ]] && continue
            local name
            name=$(basename "$ws")
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(workspace: $ws)${NC}"
            found=$((found + 1))
        done
    fi

    # CLI project: named scripts in bin/
    if [[ -d "bin" ]]; then
        for f in bin/*.sh bin/*.mjs; do
            [[ ! -f "$f" ]] && continue
            local name
            name=$(basename "$f" | sed 's/\.[^.]*$//')
            [[ "$name" == "rhino" || "$name" == "lib" ]] && continue
            echo -e "  ${GREEN}▸${NC} ${BOLD}$name${NC}  ${DIM}(script: $f)${NC}"
            found=$((found + 1))
        done
    fi

    # Existing features from beliefs.yml
    local existing
    existing=$(get_features)
    if [[ -n "$existing" ]]; then
        echo ""
        echo -e "  ${DIM}Already defined in beliefs.yml:${NC}"
        while IFS= read -r f; do
            [[ -n "$f" ]] && echo -e "    ${DIM}· $f${NC}"
        done <<< "$existing"
    fi

    if [[ "$found" -eq 0 && -z "$existing" ]]; then
        echo -e "  ${DIM}No features detected. Add feature: fields to beliefs.yml manually.${NC}"
    fi

    echo ""
}

# === Main ===
case "${1:-}" in
    ""|list) cmd_list ;;
    detect)  cmd_detect ;;
    help|--help|-h)
        echo "Usage: rhino feature [list|detect|<name>]"
        echo "  list      Show all features with pass rates"
        echo "  detect    Auto-detect features from codebase"
        echo "  <name>    Show detail for one feature"
        ;;
    *) cmd_view "$1" ;;
esac
