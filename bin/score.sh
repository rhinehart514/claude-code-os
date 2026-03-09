#!/usr/bin/env bash
set -euo pipefail

# score.sh — Computable product score. Your val_bpb.
#
# Outputs a single score (0-100) computed from:
#   1. Build health (does it compile?)
#   2. Structural signals (dead ends, empty states, accessibility)
#   3. Product signals (share integrations, notifications, link previews)
#   4. Code hygiene (hardcoded values, any types, console.logs)
#
# Auto-detects project type. Works for any web product.
# Projects can add custom checks via .claude/score.yml
#
# Usage:
#   score.sh                    # full score
#   score.sh --json             # machine-readable output
#   score.sh --breakdown        # show all sub-scores
#   score.sh --dimension X      # score one dimension only

# --- Config ---
PROJECT_DIR="${1:-.}"
cd "$PROJECT_DIR"

OUTPUT_MODE="score"  # score | json | breakdown
TARGET_DIMENSION=""

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --breakdown) OUTPUT_MODE="breakdown" ;;
        --dimension) shift; TARGET_DIMENSION="${2:-}" ;;
        --help|-h)
            echo "Usage: score.sh [project-dir] [--json] [--breakdown] [--dimension X]"
            exit 0
            ;;
    esac
done

# --- Detect project type ---
PROJECT_TYPE="unknown"
SRC_DIR=""

if [[ -f "package.json" ]]; then
    if grep -q '"next"' package.json 2>/dev/null; then
        PROJECT_TYPE="nextjs"
    elif grep -q '"react"' package.json 2>/dev/null; then
        PROJECT_TYPE="react"
    elif grep -q '"vue"' package.json 2>/dev/null; then
        PROJECT_TYPE="vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then
        PROJECT_TYPE="svelte"
    else
        PROJECT_TYPE="node"
    fi
fi

# Find source directory
if [[ -d "apps/web/src" ]]; then
    SRC_DIR="apps/web/src"
elif [[ -d "src" ]]; then
    SRC_DIR="src"
elif [[ -d "app" ]]; then
    SRC_DIR="app"
fi

# Component extensions
COMP_EXT="tsx"
if [[ "$PROJECT_TYPE" == "vue" ]]; then COMP_EXT="vue"; fi
if [[ "$PROJECT_TYPE" == "svelte" ]]; then COMP_EXT="svelte"; fi

# --- Scoring functions ---
# Each returns a score 0-100 for its dimension

score_build_health() {
    local score=100

    # TypeScript check
    if [[ -f "tsconfig.json" ]] || find . -name "tsconfig.json" -maxdepth 3 2>/dev/null | grep -q .; then
        local ts_errors
        ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
        if [[ "$ts_errors" -gt 0 ]]; then
            score=$((score - 30))
        fi
    fi

    # Build check
    if grep -q '"build"' package.json 2>/dev/null; then
        if ! npm run build > /dev/null 2>&1; then
            score=$((score - 50))
        fi
    fi

    # Test check
    if grep -q '"test"' package.json 2>/dev/null; then
        if ! npm test > /dev/null 2>&1; then
            score=$((score - 20))
        fi
    fi

    echo "$score"
}

score_structure() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100
    local total_pages=0
    local dead_ends=0
    local empty_states=0
    local empty_with_cta=0

    # Count pages/routes
    total_pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" -o -name "index.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$total_pages" -eq 0 ]] && total_pages=1

    # Dead-end screens (pages with no outbound navigation)
    if [[ "$COMP_EXT" == "tsx" ]] || [[ "$COMP_EXT" == "vue" ]]; then
        dead_ends=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | while read -r f; do
            if ! grep -ql "Link\|href\|router\|navigate\|onClick" "$f" 2>/dev/null; then
                echo "$f"
            fi
        done | wc -l | tr -d ' ')
    fi

    # Empty states
    empty_states=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    empty_with_cta=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | xargs grep -l "Link\|button\|onClick\|href" 2>/dev/null | wc -l | tr -d ' ')

    # Deductions
    if [[ "$total_pages" -gt 0 ]] && [[ "$dead_ends" -gt 0 ]]; then
        local dead_pct=$((dead_ends * 100 / total_pages))
        score=$((score - dead_pct / 2))
    fi

    if [[ "$empty_states" -gt 0 ]]; then
        local cta_pct
        if [[ "$empty_states" -gt 0 ]]; then
            cta_pct=$((empty_with_cta * 100 / empty_states))
        else
            cta_pct=100
        fi
        local missing_pct=$((100 - cta_pct))
        score=$((score - missing_pct / 3))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

score_product() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0
    local checks=0
    local passed=0

    # Share integrations (user-facing share actions, not imports)
    checks=$((checks + 1))
    local shares
    shares=$(grep -rn "navigator\.share\|ShareSheet\|shareUrl\|useShare" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$shares" -gt 0 ]] && passed=$((passed + 1))

    # Link preview / OG tags (actual meta tags, not Next.js metadata type)
    checks=$((checks + 1))
    local og_tags
    og_tags=$(grep -rn "og:title\|og:image\|og:description\|twitter:card\|openGraph" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$og_tags" -gt 0 ]] && passed=$((passed + 1))

    # Push / notification triggers (actual send calls, not SDK imports)
    checks=$((checks + 1))
    local push
    push=$(grep -rn "sendNotification\|pushNotification\|messaging()\.send\|Notification\.requestPermission\|web-push" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$push" -gt 0 ]] && passed=$((passed + 1))

    # Return/retention signals (explicit returning-user UX, not generic state)
    checks=$((checks + 1))
    local retention
    retention=$(grep -rn "since you left\|welcome back\|new since last\|last visited\|daily digest\|we missed you" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$retention" -gt 0 ]] && passed=$((passed + 1))

    # Real-time / live features (actual subscriptions, not query helpers)
    checks=$((checks + 1))
    local realtime
    realtime=$(grep -rn "onSnapshot\|WebSocket\|EventSource\|\.subscribe(" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | grep -v "node_modules\|test\|spec" | wc -l | tr -d ' ')
    [[ "$realtime" -gt 0 ]] && passed=$((passed + 1))

    if [[ "$checks" -gt 0 ]]; then
        score=$((passed * 100 / checks))
    fi

    echo "$score"
}

score_hygiene() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Hardcoded colors (should use tokens)
    local hardcoded_colors
    hardcoded_colors=$(grep -rn '#[0-9A-Fa-f]\{6\}' --include="*.$COMP_EXT" --include="*.css" "$SRC_DIR" 2>/dev/null | grep -v 'node_modules\|tokens\|\.svg\|tailwind\|theme' | wc -l | tr -d ' ')
    if [[ "$hardcoded_colors" -gt 10 ]]; then
        score=$((score - 20))
    elif [[ "$hardcoded_colors" -gt 5 ]]; then
        score=$((score - 10))
    fi

    # `any` types
    local any_count
    any_count=$(grep -rn ": any\b" --include="*.ts" --include="*.tsx" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|\.d\.ts" | wc -l | tr -d ' ')
    if [[ "$any_count" -gt 10 ]]; then
        score=$((score - 20))
    elif [[ "$any_count" -gt 3 ]]; then
        score=$((score - 10))
    fi

    # console.log in production code
    local console_count
    console_count=$(grep -rn "console\.\(log\|warn\|error\)" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|test\|spec\|__test__" | wc -l | tr -d ' ')
    if [[ "$console_count" -gt 10 ]]; then
        score=$((score - 15))
    elif [[ "$console_count" -gt 3 ]]; then
        score=$((score - 5))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# --- Compute scores ---
BUILD=$(score_build_health)
STRUCTURE=$(score_structure)
PRODUCT=$(score_product)
HYGIENE=$(score_hygiene)

# --- Weighted total ---
# Build health is pass/fail (high weight), product signals matter most for val_bpb equivalent
TOTAL=$(awk "BEGIN { printf \"%d\", ($BUILD * 0.25) + ($STRUCTURE * 0.25) + ($PRODUCT * 0.30) + ($HYGIENE * 0.20) }")

# --- Read custom checks if they exist ---
CUSTOM_SCORE=""
if [[ -f ".claude/score.yml" ]] || [[ -f ".claude/score.yaml" ]]; then
    SCORE_CONFIG=".claude/score.yml"
    [[ -f ".claude/score.yaml" ]] && SCORE_CONFIG=".claude/score.yaml"
    # Custom checks would be parsed here in a future version
    # For now, just note that the config exists
    CUSTOM_SCORE="(custom config detected but not yet parsed)"
fi

# --- Output ---
case "$OUTPUT_MODE" in
    score)
        echo "$TOTAL"
        ;;
    json)
        cat <<EOF
{"score":$TOTAL,"build":$BUILD,"structure":$STRUCTURE,"product":$PRODUCT,"hygiene":$HYGIENE,"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
EOF
        ;;
    breakdown)
        echo "=== Product Score: $TOTAL/100 ==="
        echo ""
        echo "  Build Health:     $BUILD/100  (25%)"
        echo "  Structure:        $STRUCTURE/100  (25%)"
        echo "  Product Signals:  $PRODUCT/100  (30%)"
        echo "  Code Hygiene:     $HYGIENE/100  (20%)"
        echo ""
        echo "  Project Type:     $PROJECT_TYPE"
        echo "  Source Dir:       $SRC_DIR"
        [[ -n "$CUSTOM_SCORE" ]] && echo "  $CUSTOM_SCORE"
        echo ""
        echo "This is your val_bpb. Higher = better."
        echo "Run after every commit. Score should never go down."
        ;;
esac
