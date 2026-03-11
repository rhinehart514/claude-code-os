#!/usr/bin/env bash
set -uo pipefail

# ia-audit.sh — Lightweight IA health check. Grep-based.
#
# Finds: orphan routes, dead-end pages, empty states without CTAs.
# Output: summary + ia_health score (linked_routes / total_routes * 100)
#
# Usage:
#   ia-audit.sh [project-dir]              # visual output
#   ia-audit.sh [project-dir] --json       # machine-readable
#   ia-audit.sh [project-dir] --quiet      # single number

PROJECT_DIR="."
OUTPUT_MODE="visual"

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --quiet|-q) OUTPUT_MODE="quiet" ;;
        --help|-h)
            echo "Usage: ia-audit.sh [project-dir] [--json] [--quiet]"
            exit 0
            ;;
        -*) ;;
        *) PROJECT_DIR="$arg" ;;
    esac
done

cd "$PROJECT_DIR"

# --- Detect framework and route files ---
ROUTE_FILES=()
COMP_EXT="tsx"

if [[ -d "apps/web/src/app" ]]; then
    # Next.js monorepo
    while IFS= read -r f; do ROUTE_FILES+=("$f"); done < <(find apps/web/src/app -name "page.tsx" -o -name "page.jsx" 2>/dev/null)
elif [[ -d "src/app" ]]; then
    # Next.js app router
    while IFS= read -r f; do ROUTE_FILES+=("$f"); done < <(find src/app -name "page.tsx" -o -name "page.jsx" 2>/dev/null)
elif [[ -d "src/routes" ]]; then
    # SvelteKit
    COMP_EXT="svelte"
    while IFS= read -r f; do ROUTE_FILES+=("$f"); done < <(find src/routes -name "+page.svelte" 2>/dev/null)
elif [[ -d "app" ]]; then
    # Next.js or Remix
    while IFS= read -r f; do ROUTE_FILES+=("$f"); done < <(find app -name "page.tsx" -o -name "page.jsx" -o -name "route.tsx" 2>/dev/null | grep -v node_modules)
elif [[ -d "src/pages" ]]; then
    # Pages router / Vue / etc
    while IFS= read -r f; do ROUTE_FILES+=("$f"); done < <(find src/pages -name "*.tsx" -o -name "*.vue" -o -name "*.jsx" 2>/dev/null)
fi

TOTAL=${#ROUTE_FILES[@]}

if [[ "$TOTAL" -eq 0 ]]; then
    case "$OUTPUT_MODE" in
        quiet) echo "0" ;;
        json) echo '{"ia_health":0,"total_routes":0,"orphan_routes":[],"dead_ends":[],"empty_states_no_cta":[]}' ;;
        visual) echo "No route files found. Cannot audit IA." ;;
    esac
    exit 0
fi

# --- Find nav files (where routes should be linked) ---
NAV_CONTENT=""
for pattern in "nav" "Nav" "sidebar" "Sidebar" "header" "Header" "layout" "Layout"; do
    while IFS= read -r f; do
        NAV_CONTENT+="$(cat "$f" 2>/dev/null) "
    done < <(find . -name "*${pattern}*.$COMP_EXT" -o -name "*${pattern}*.tsx" -o -name "*${pattern}*.jsx" 2>/dev/null | grep -v node_modules | head -20)
done

# --- Check each route ---
ORPHANS=()
DEAD_ENDS=()
LINKED=0

for route in "${ROUTE_FILES[@]}"; do
    # Extract route path from file path (e.g., src/app/dashboard/page.tsx → /dashboard)
    route_path=$(echo "$route" | sed -E 's|.*/app/||; s|/page\.[tj]sx$||; s|/\+page\.svelte$||; s|^\.$|/|; s|^|/|' | sed 's|//|/|g')

    # Is this route linked from nav/layout?
    is_linked=false
    if echo "$NAV_CONTENT" | grep -qF "$route_path" 2>/dev/null; then
        is_linked=true
    fi
    # Also check for Link/href to this route in any file
    if ! $is_linked; then
        if grep -rq "href=[\"']${route_path}[\"']\|to=[\"']${route_path}[\"']" --include="*.$COMP_EXT" --include="*.tsx" --include="*.jsx" . 2>/dev/null | grep -v node_modules | head -1 > /dev/null 2>&1; then
            is_linked=true
        fi
    fi

    if $is_linked; then
        LINKED=$((LINKED + 1))
    else
        ORPHANS+=("$route_path ($route)")
    fi

    # Dead end check: page has no outbound Link/href/onClick
    if ! grep -ql "Link\|href=\|router\.\(push\|replace\)\|navigate\|onClick" "$route" 2>/dev/null; then
        DEAD_ENDS+=("$route_path ($route)")
    fi
done

# --- Empty states without CTAs ---
EMPTY_NO_CTA=()
SRC_DIR=""
[[ -d "apps/web/src" ]] && SRC_DIR="apps/web/src"
[[ -d "src" ]] && SRC_DIR="src"
[[ -d "app" ]] && SRC_DIR="app"

if [[ -n "$SRC_DIR" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        if ! grep -ql "Link\|button\|onClick\|href\|Button" "$f" 2>/dev/null; then
            EMPTY_NO_CTA+=("$f")
        fi
    done < <(grep -rl "empty\|no.*yet\|nothing.*here\|get started\|No items\|No results" --include="*.$COMP_EXT" --include="*.tsx" --include="*.jsx" "$SRC_DIR" 2>/dev/null | grep -v node_modules)
fi

# --- Calculate score ---
if [[ "$TOTAL" -gt 0 ]]; then
    IA_HEALTH=$((LINKED * 100 / TOTAL))
else
    IA_HEALTH=0
fi

# --- Output ---
case "$OUTPUT_MODE" in
    quiet)
        echo "$IA_HEALTH"
        ;;
    json)
        orphan_json="["
        first=true
        for o in "${ORPHANS[@]+"${ORPHANS[@]}"}"; do
            $first || orphan_json+=","
            orphan_json+="\"$o\""
            first=false
        done
        orphan_json+="]"

        dead_json="["
        first=true
        for d in "${DEAD_ENDS[@]+"${DEAD_ENDS[@]}"}"; do
            $first || dead_json+=","
            dead_json+="\"$d\""
            first=false
        done
        dead_json+="]"

        empty_json="["
        first=true
        for e in "${EMPTY_NO_CTA[@]+"${EMPTY_NO_CTA[@]}"}"; do
            $first || empty_json+=","
            empty_json+="\"$e\""
            first=false
        done
        empty_json+="]"

        cat <<EOF
{"ia_health":$IA_HEALTH,"total_routes":$TOTAL,"linked_routes":$LINKED,"orphan_count":${#ORPHANS[@]},"dead_end_count":${#DEAD_ENDS[@]},"empty_no_cta_count":${#EMPTY_NO_CTA[@]},"orphan_routes":$orphan_json,"dead_ends":$dead_json,"empty_states_no_cta":$empty_json}
EOF
        ;;
    visual)
        echo ""
        echo "=== IA Audit ==="
        echo ""
        echo "  Routes: $TOTAL total, $LINKED linked"
        echo "  IA Health: ${IA_HEALTH}%"
        echo ""

        if [[ ${#ORPHANS[@]} -gt 0 ]]; then
            echo "  Orphan routes (not linked from nav):"
            for o in "${ORPHANS[@]}"; do
                echo "    · $o"
            done
            echo ""
        fi

        if [[ ${#DEAD_ENDS[@]} -gt 0 ]]; then
            echo "  Dead-end pages (no outbound links):"
            for d in "${DEAD_ENDS[@]}"; do
                echo "    · $d"
            done
            echo ""
        fi

        if [[ ${#EMPTY_NO_CTA[@]} -gt 0 ]]; then
            echo "  Empty states without CTAs:"
            for e in "${EMPTY_NO_CTA[@]}"; do
                echo "    · $e"
            done
            echo ""
        fi

        if [[ ${#ORPHANS[@]} -eq 0 && ${#DEAD_ENDS[@]} -eq 0 && ${#EMPTY_NO_CTA[@]} -eq 0 ]]; then
            echo "  No issues found."
        fi
        ;;
esac
