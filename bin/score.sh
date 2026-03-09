#!/usr/bin/env bash
set -euo pipefail

# score.sh — Computable product score. Your training loss.
#
# Outputs a single score (0-100) computed from:
#   1. Build health    — does it compile? (gate)
#   2. Structure       — dead ends, empty states (subtractive)
#   3. Product signals — share, push, OG, retention, social (additive + depth)
#   4. Capabilities    — features, routes, auth, search, media (additive)
#   5. Code hygiene    — hardcoded values, any types, console.logs (subtractive)
#
# This is the CHEAP proxy — runs every commit, pure grep, no opinions.
# For actual taste evaluation (the expensive eval), use: rhino taste eval
# That uses Playwright screenshots + Claude vision to judge from USER perspective.
#
# Usage:
#   score.sh [project-dir]              # single number
#   score.sh [project-dir] --json       # machine-readable
#   score.sh [project-dir] --breakdown  # show all sub-scores

PROJECT_DIR="."
OUTPUT_MODE="score"

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --breakdown) OUTPUT_MODE="breakdown" ;;
        --help|-h)
            echo "Usage: score.sh [project-dir] [--json] [--breakdown]"
            exit 0
            ;;
        -*) ;; # skip unknown flags
        *) PROJECT_DIR="$arg" ;;
    esac
done

cd "$PROJECT_DIR"

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

# --- 1. Build Health (0-100, gate) ---
score_build_health() {
    local score=100

    if [[ -f "tsconfig.json" ]] || find . -name "tsconfig.json" -maxdepth 3 2>/dev/null | grep -q .; then
        local ts_errors
        ts_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
        if [[ "$ts_errors" -gt 0 ]]; then
            score=$((score - 30))
        fi
    fi

    if grep -q '"build"' package.json 2>/dev/null; then
        if ! npm run build > /dev/null 2>&1; then
            score=$((score - 50))
        fi
    fi

    echo "$score"
}

# --- 2. Structure (0-100, subtractive) ---
score_structure() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Count pages
    local total_pages
    total_pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" -o -name "index.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    [[ "$total_pages" -eq 0 ]] && total_pages=1

    # Dead-end screens
    local dead_ends=0
    dead_ends=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | while read -r f; do
        if ! grep -ql "Link\|href\|router\|navigate\|onClick" "$f" 2>/dev/null; then
            echo "$f"
        fi
    done | wc -l | tr -d ' ')

    if [[ "$dead_ends" -gt 0 ]]; then
        local dead_pct=$((dead_ends * 100 / total_pages))
        score=$((score - dead_pct / 2))
    fi

    # Empty states without CTAs
    local empty_states
    empty_states=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local empty_with_cta
    empty_with_cta=$(grep -rn "empty\|no.*yet\|nothing.*here\|get started" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | xargs grep -l "Link\|button\|onClick\|href" 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$empty_states" -gt 0 ]]; then
        local cta_pct=$((empty_with_cta * 100 / empty_states))
        local missing_pct=$((100 - cta_pct))
        score=$((score - missing_pct / 3))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# --- 3. Product Signals (0-100) ---
# Measures FLOW COMPLETION, not feature existence.
# "Does share exist?" is useless. "Can a user go from creation → someone else sees it?" is useful.
score_product() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # --- CREATION → DISTRIBUTION flow (0-30) ---
    # Can a user create something AND get it to other people?
    # Points scale with flow depth: create → save → share → link preview → someone sees it
    local has_create=0 has_save=0 has_share=0 has_preview=0
    # Creation: forms, editors, or creation UI
    [[ $(grep -rn "onSubmit\|handleSubmit\|createPost\|editor\|compose\|publish" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_create=1
    # Save/persist: mutation, API call after creation
    [[ $(grep -rn "mutation\|\.post(\|\.put(\|addDoc\|setDoc\|insertOne" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_save=1
    # Share: after creation, can you send it to someone?
    [[ $(grep -rn "navigator\.share\|copy.*link\|copy.*url\|shareUrl\|ShareSheet" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_share=1
    # Link preview: if shared, does it look good?
    [[ $(grep -rn "og:title\|og:image\|openGraph" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_preview=1

    local creation_flow=$((has_create + has_save + has_share + has_preview))
    # 0 steps = 0, 1 = 5, 2 = 10, 3 = 20, 4 = 30 (full flow = disproportionate reward)
    case "$creation_flow" in
        4) score=$((score + 30)) ;;
        3) score=$((score + 20)) ;;
        2) score=$((score + 10)) ;;
        1) score=$((score + 5)) ;;
    esac

    # --- RETURN PULL flow (0-30) ---
    # Does anything pull the user back after they leave?
    local has_notif=0 has_unread=0 has_return_ux=0 has_digest=0
    # Notification infrastructure
    [[ $(grep -rn "Notification\.requestPermission\|sendNotification\|pushNotification" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_notif=1
    # Unread/unseen state (something changed since you left)
    [[ $(grep -rn "unreadCount\|unseen\|badge.*count\|new.*since" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_unread=1
    # Return-specific UX (welcome back, what you missed)
    [[ $(grep -rn "since you left\|welcome back\|what you missed\|new since last" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_return_ux=1
    # Digest/email pull
    [[ $(grep -rn "digest\|daily.*email\|weekly.*summary\|recap" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_digest=1

    local return_flow=$((has_notif + has_unread + has_return_ux + has_digest))
    case "$return_flow" in
        4) score=$((score + 30)) ;;
        3) score=$((score + 20)) ;;
        2) score=$((score + 10)) ;;
        1) score=$((score + 5)) ;;
    esac

    # --- SOCIAL flow (0-20) ---
    # Can users see each other? Does more users = better product?
    local has_profiles=0 has_follow=0 has_feed=0 has_realtime=0
    [[ $(grep -rn "UserProfile\|user.*avatar\|ProfilePage\|member.*list" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_profiles=1
    [[ $(grep -rn "follow\|connect.*user\|friend.*request\|join.*group" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_follow=1
    [[ $(grep -rn "feed\|timeline\|activity.*stream\|recent.*posts" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_feed=1
    [[ $(grep -rn "onSnapshot\|WebSocket\|presence\|typing.*indicator" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ') -ge 1 ]] && has_realtime=1

    local social_flow=$((has_profiles + has_follow + has_feed + has_realtime))
    case "$social_flow" in
        4) score=$((score + 20)) ;;
        3) score=$((score + 15)) ;;
        2) score=$((score + 10)) ;;
        1) score=$((score + 5)) ;;
    esac

    # --- REAL USER SIGNAL (0-20) ---
    # Check for analytics/tracking — is anyone measuring real usage?
    local has_analytics=0 has_error_tracking=0
    [[ $(grep -rn "posthog\|mixpanel\|plausible\|gtag\|analytics\.track\|trackEvent" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_analytics=1
    [[ $(grep -rn "sentry\|bugsnag\|errorBoundary\|captureException" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ') -ge 1 ]] && has_error_tracking=1

    [[ "$has_analytics" -eq 1 ]] && score=$((score + 10))
    [[ "$has_error_tracking" -eq 1 ]] && score=$((score + 10))

    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# --- 4. Capabilities (0-100, additive) ---
# How many user-facing features exist? Rewards feature creation.
score_capabilities() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # Count unique routes/pages (more complete app = higher score)
    local pages
    pages=$(find "$SRC_DIR" -name "page.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    # 1-3 pages = 10pts, 4-8 = 20pts, 9-15 = 30pts, 16+ = 40pts
    if [[ "$pages" -ge 16 ]]; then score=$((score + 40))
    elif [[ "$pages" -ge 9 ]]; then score=$((score + 30))
    elif [[ "$pages" -ge 4 ]]; then score=$((score + 20))
    elif [[ "$pages" -ge 1 ]]; then score=$((score + 10))
    fi

    # Count unique components (more = richer UI)
    local components
    components=$(find "$SRC_DIR" -name "*.$COMP_EXT" 2>/dev/null | wc -l | tr -d ' ')
    # 1-10 = 5pts, 11-30 = 10pts, 31-60 = 15pts, 61+ = 20pts
    if [[ "$components" -ge 61 ]]; then score=$((score + 20))
    elif [[ "$components" -ge 31 ]]; then score=$((score + 15))
    elif [[ "$components" -ge 11 ]]; then score=$((score + 10))
    elif [[ "$components" -ge 1 ]]; then score=$((score + 5))
    fi

    # API routes (backend functionality)
    local api_routes
    api_routes=$(find "$SRC_DIR" -path "*/api/*" -name "route.*" 2>/dev/null | wc -l | tr -d ' ')
    # 1-3 = 5pts, 4-10 = 10pts, 11+ = 15pts
    if [[ "$api_routes" -ge 11 ]]; then score=$((score + 15))
    elif [[ "$api_routes" -ge 4 ]]; then score=$((score + 10))
    elif [[ "$api_routes" -ge 1 ]]; then score=$((score + 5))
    fi

    # Auth system
    local auth
    auth=$(grep -rn "signIn\|signUp\|useAuth\|useSession\|getServerSession\|auth()\|currentUser" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$auth" -ge 1 ]] && score=$((score + 10))

    # Search
    local search
    search=$(grep -rn "useSearch\|search.*query\|search.*results\|SearchBar\|searchParams" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$search" -ge 1 ]] && score=$((score + 5))

    # File upload / media
    local media
    media=$(grep -rn "upload\|dropzone\|FileInput\|file.*input\|image.*upload\|useUpload" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$media" -ge 1 ]] && score=$((score + 5))

    # Analytics / tracking
    local analytics
    analytics=$(grep -rn "analytics\|trackEvent\|posthog\|mixpanel\|gtag\|plausible" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$analytics" -ge 1 ]] && score=$((score + 5))

    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# --- 5. Code Hygiene (0-100, subtractive) ---
score_hygiene() {
    [[ -z "$SRC_DIR" ]] && echo "50" && return

    local score=100

    # Hardcoded colors
    local hardcoded_colors
    hardcoded_colors=$(grep -rn '#[0-9A-Fa-f]\{6\}' --include="*.$COMP_EXT" --include="*.css" "$SRC_DIR" 2>/dev/null | grep -v 'node_modules\|tokens\|\.svg\|tailwind\|theme' | wc -l | tr -d ' ')
    if [[ "$hardcoded_colors" -gt 20 ]]; then score=$((score - 25))
    elif [[ "$hardcoded_colors" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$hardcoded_colors" -gt 5 ]]; then score=$((score - 10))
    fi

    # `any` types
    local any_count
    any_count=$(grep -rn ": any\b" --include="*.ts" --include="*.tsx" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|\.d\.ts" | wc -l | tr -d ' ')
    if [[ "$any_count" -gt 20 ]]; then score=$((score - 25))
    elif [[ "$any_count" -gt 10 ]]; then score=$((score - 15))
    elif [[ "$any_count" -gt 3 ]]; then score=$((score - 10))
    fi

    # console.log in production
    local console_count
    console_count=$(grep -rn "console\.\(log\|warn\|error\)" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules\|test\|spec\|__test__" | wc -l | tr -d ' ')
    if [[ "$console_count" -gt 20 ]]; then score=$((score - 20))
    elif [[ "$console_count" -gt 10 ]]; then score=$((score - 10))
    elif [[ "$console_count" -gt 3 ]]; then score=$((score - 5))
    fi

    # TODO/FIXME count (unfinished work)
    local todo_count
    todo_count=$(grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" 2>/dev/null | grep -v "node_modules" | wc -l | tr -d ' ')
    if [[ "$todo_count" -gt 20 ]]; then score=$((score - 15))
    elif [[ "$todo_count" -gt 10 ]]; then score=$((score - 10))
    elif [[ "$todo_count" -gt 3 ]]; then score=$((score - 5))
    fi

    [[ "$score" -lt 0 ]] && score=0
    echo "$score"
}

# --- Taste is NOT scored here. ---
# Taste requires LOOKING at the product, not grepping code.
# Use: rhino taste eval (Playwright + Claude vision)
# That's your eval loss. This file is training loss.

# --- Compute all scores ---
BUILD=$(score_build_health)
STRUCTURE=$(score_structure)
PRODUCT=$(score_product)
CAPABILITIES=$(score_capabilities)
HYGIENE=$(score_hygiene)

# --- Weighted total ---
# This is training loss — cheap, computable, every commit.
# Taste is measured separately via: rhino taste eval (expensive, visual, on-demand)
#
# Product + Capabilities = 50% (rewards building features)
# Structure + Hygiene = 30% (rewards quality)
# Build = 20% (gate — if it doesn't compile, nothing else matters)
TOTAL=$(awk "BEGIN { printf \"%d\", ($BUILD * 0.20) + ($STRUCTURE * 0.15) + ($PRODUCT * 0.25) + ($CAPABILITIES * 0.25) + ($HYGIENE * 0.15) }")

# --- Check for most recent taste eval ---
TASTE_SCORE=""
TASTE_FILE=""
if [[ -d ".claude/evals/reports" ]]; then
    TASTE_FILE=$(ls -t .claude/evals/reports/taste-*.json 2>/dev/null | head -1)
    if [[ -n "$TASTE_FILE" ]] && command -v jq &> /dev/null; then
        TASTE_SCORE=$(jq -r '.score_100 // empty' "$TASTE_FILE" 2>/dev/null)
    fi
fi

# --- Output ---
case "$OUTPUT_MODE" in
    score)
        echo "$TOTAL"
        ;;
    json)
        if [[ -n "$TASTE_SCORE" ]]; then
            cat <<EOF
{"score":$TOTAL,"build":$BUILD,"structure":$STRUCTURE,"product":$PRODUCT,"capabilities":$CAPABILITIES,"hygiene":$HYGIENE,"taste_eval":$TASTE_SCORE,"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
EOF
        else
            cat <<EOF
{"score":$TOTAL,"build":$BUILD,"structure":$STRUCTURE,"product":$PRODUCT,"capabilities":$CAPABILITIES,"hygiene":$HYGIENE,"taste_eval":null,"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
EOF
        fi
        ;;
    breakdown)
        echo "=== Product Score: $TOTAL/100 ==="
        echo ""
        echo "  Build Health:     $BUILD/100  (20%)  — does it compile?"
        echo "  Structure:        $STRUCTURE/100  (15%)  — dead ends, empty states"
        echo "  Product Flows:    $PRODUCT/100  (25%)  — creation→distribution, return pull, social"
        echo "  Capabilities:     $CAPABILITIES/100  (25%)  — routes, components, auth, search"
        echo "  Code Hygiene:     $HYGIENE/100  (15%)  — hardcoded colors, any, console.log"
        echo ""
        if [[ -n "$TASTE_SCORE" ]]; then
            echo "  Taste (visual):   $TASTE_SCORE/100  — last eval: $(basename "$TASTE_FILE")"
        else
            echo "  Taste (visual):   not yet evaluated — run: rhino taste eval"
        fi
        echo ""
        echo "  Project: $PROJECT_TYPE ($SRC_DIR)"
        echo ""
        echo "  Training loss (this score): computable, every commit, grep-based."
        echo "  Eval loss (taste):          visual, on-demand, Playwright + Claude vision."
        echo "  Run 'rhino taste eval' to score taste from the user's perspective."
        ;;
esac
