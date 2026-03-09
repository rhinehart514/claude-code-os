#!/usr/bin/env bash
set -euo pipefail

# score.sh — Computable product score. Your val_bpb.
#
# Outputs a single score (0-100) computed from:
#   1. Build health    — does it compile? (gate)
#   2. Structure       — dead ends, empty states (subtractive)
#   3. Product signals — share, push, OG, retention, social (additive + depth)
#   4. Capabilities    — features, routes, auth, search, media (additive)
#   5. Taste (IA+VA)   — identity, motion, feedback, polish, contextual UI (additive)
#   6. Code hygiene    — hardcoded values, any types, console.logs (subtractive)
#
# Key design: Taste has 20% weight — same as capabilities.
# The AI is pressured to build distinctiveness, not just functionality.
# Adding an animation, a branded component, a contextual empty state,
# a design token — all move the score up. Generic code doesn't.
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

# --- 3. Product Signals (0-100, additive + depth) ---
# Not binary — deeper implementation = more points
score_product() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # Share flow (0-20): button exists → +5, navigator.share call → +5, share CTA after creation → +5, share analytics → +5
    local share_files
    share_files=$(grep -rn "navigator\.share\|ShareSheet\|shareUrl\|useShare" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local share_cta
    share_cta=$(grep -rn "share.*button\|Share.*CTA\|copy.*link\|copy.*url" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$share_files" -ge 1 ]] && score=$((score + 5))
    [[ "$share_files" -ge 3 ]] && score=$((score + 5))
    [[ "$share_cta" -ge 1 ]] && score=$((score + 5))
    [[ "$share_cta" -ge 3 ]] && score=$((score + 5))

    # OG / link previews (0-15): meta tags exist → +5, per-page dynamic OG → +5, twitter cards → +5
    local og_files
    og_files=$(grep -rn "og:title\|og:image\|og:description\|openGraph" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local twitter_cards
    twitter_cards=$(grep -rn "twitter:card\|twitter:image" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$og_files" -ge 1 ]] && score=$((score + 5))
    [[ "$og_files" -ge 3 ]] && score=$((score + 5))
    [[ "$twitter_cards" -ge 1 ]] && score=$((score + 5))

    # Push notifications (0-15): permission request → +5, trigger exists → +5, multiple triggers → +5
    local push_setup
    push_setup=$(grep -rn "Notification\.requestPermission\|registerServiceWorker\|firebase.*messaging" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local push_triggers
    push_triggers=$(grep -rn "sendNotification\|pushNotification\|messaging()\.send" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$push_setup" -ge 1 ]] && score=$((score + 5))
    [[ "$push_triggers" -ge 1 ]] && score=$((score + 5))
    [[ "$push_triggers" -ge 3 ]] && score=$((score + 5))

    # Retention UX (0-15): "welcome back" / "since you left" → +5, unread badges → +5, digest/email → +5
    local retention_ux
    retention_ux=$(grep -rn "since you left\|welcome back\|new since last\|we missed you" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local unread_badges
    unread_badges=$(grep -rn "unreadCount\|badge.*count\|notification.*count\|unseen" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local digest
    digest=$(grep -rn "digest\|daily.*email\|weekly.*summary\|sendEmail.*recap" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$retention_ux" -ge 1 ]] && score=$((score + 5))
    [[ "$unread_badges" -ge 1 ]] && score=$((score + 5))
    [[ "$digest" -ge 1 ]] && score=$((score + 5))

    # Realtime (0-15): subscriptions → +5, optimistic updates → +5, presence → +5
    local realtime
    realtime=$(grep -rn "onSnapshot\|WebSocket\|EventSource\|\.subscribe(" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | grep -v "node_modules\|test\|spec" | wc -l | tr -d ' ')
    local optimistic
    optimistic=$(grep -rn "optimistic\|setQueryData\|mutate.*onMutate\|revalidate" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local presence
    presence=$(grep -rn "presence\|online.*users\|typing.*indicator\|is.*online" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$realtime" -ge 1 ]] && score=$((score + 5))
    [[ "$optimistic" -ge 1 ]] && score=$((score + 5))
    [[ "$presence" -ge 1 ]] && score=$((score + 5))

    # Social graph (0-10): follow/connect → +5, feed/timeline → +5
    local social
    social=$(grep -rn "follow\|connect.*user\|friend.*request\|add.*friend" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    local feed
    feed=$(grep -rn "feed\|timeline\|activity.*stream" --include="*.ts" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$social" -ge 1 ]] && score=$((score + 5))
    [[ "$feed" -ge 1 ]] && score=$((score + 5))

    # Cap at 100
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

# --- 6. Taste / IA+VA (0-100, additive) ---
# Measures resistance to AI convergence. Does the product have identity?
# Not perfect — but creates pressure toward distinctiveness.
score_taste() {
    [[ -z "$SRC_DIR" ]] && echo "0" && return

    local score=0

    # --- INFORMATION ARCHITECTURE ---

    # Custom navigation patterns (not just sidebar + header)
    local nav_patterns=0
    grep -rn "BottomNav\|TabBar\|CommandPalette\|SpotlightSearch\|Dock\|FloatingAction\|Drawer\|mobile.*nav\|bottom.*bar" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | while read -r f; do nav_patterns=$((nav_patterns + 1)); done
    nav_patterns=$(grep -rn "BottomNav\|TabBar\|CommandPalette\|SpotlightSearch\|Dock\|FloatingAction\|Drawer\|mobile.*nav\|bottom.*bar" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    # Multiple navigation patterns = richer IA (not just sidebar-for-everything)
    [[ "$nav_patterns" -ge 1 ]] && score=$((score + 5))
    [[ "$nav_patterns" -ge 3 ]] && score=$((score + 5))

    # Contextual/smart UI (shows different things based on state)
    local contextual
    contextual=$(grep -rn "isFirstVisit\|isNewUser\|hasContent\|isEmpty.*?\|onboarding\|getStarted\|firstTime\|showTutorial" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$contextual" -ge 1 ]] && score=$((score + 5))
    [[ "$contextual" -ge 3 ]] && score=$((score + 5))

    # Dynamic content ordering (not static lists)
    local dynamic_order
    dynamic_order=$(grep -rn "sort\|trending\|popular\|recommended\|personalized\|forYou\|suggested" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$dynamic_order" -ge 1 ]] && score=$((score + 5))
    [[ "$dynamic_order" -ge 3 ]] && score=$((score + 5))

    # --- VISUAL ARCHITECTURE ---

    # Design tokens exist and are used (not inline values)
    local token_files
    token_files=$(find "$SRC_DIR" -name "*token*" -o -name "*theme*" -o -name "*design-system*" 2>/dev/null | grep -v node_modules | wc -l | tr -d ' ')
    local token_usage
    token_usage=$(grep -rn "tokens\.\|theme\.\|designSystem\.\|--color-\|--spacing-\|--font-" --include="*.$COMP_EXT" --include="*.css" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$token_files" -ge 1 ]] && score=$((score + 5))
    [[ "$token_usage" -ge 5 ]] && score=$((score + 5))

    # Custom/branded components (not just raw shadcn/defaults)
    local branded
    branded=$(grep -rn "brand\|logo\|mascot\|custom.*icon\|illustration\|signature" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$branded" -ge 1 ]] && score=$((score + 5))
    [[ "$branded" -ge 3 ]] && score=$((score + 5))

    # Animations / transitions (not static)
    local animations
    animations=$(grep -rn "animate\|transition\|motion\|framer\|spring\|keyframes\|useSpring\|AnimatePresence" --include="*.$COMP_EXT" --include="*.css" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$animations" -ge 1 ]] && score=$((score + 5))
    [[ "$animations" -ge 5 ]] && score=$((score + 5))

    # Feedback patterns (not silent actions)
    local feedback
    feedback=$(grep -rn "toast\|Snackbar\|notification\|success.*message\|useToast\|sonner\|confetti\|haptic" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$feedback" -ge 1 ]] && score=$((score + 5))
    [[ "$feedback" -ge 3 ]] && score=$((score + 5))

    # Loading/skeleton states (polish, not blank screens)
    local loading_states
    loading_states=$(grep -rn "Skeleton\|skeleton\|Shimmer\|loading.*state\|isLoading.*?\|Spinner\|Placeholder" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$loading_states" -ge 1 ]] && score=$((score + 5))
    [[ "$loading_states" -ge 5 ]] && score=$((score + 5))

    # Responsive / mobile-specific UI (not just desktop shrunk)
    local mobile_specific
    mobile_specific=$(grep -rn "useMediaQuery\|useMobile\|isMobile\|md:\|lg:\|mobile.*layout\|MobileNav\|touch.*target" --include="*.$COMP_EXT" "$SRC_DIR" -l 2>/dev/null | wc -l | tr -d ' ')
    [[ "$mobile_specific" -ge 1 ]] && score=$((score + 5))
    [[ "$mobile_specific" -ge 5 ]] && score=$((score + 5))

    [[ "$score" -gt 100 ]] && score=100
    echo "$score"
}

# --- Compute all scores ---
BUILD=$(score_build_health)
STRUCTURE=$(score_structure)
PRODUCT=$(score_product)
CAPABILITIES=$(score_capabilities)
HYGIENE=$(score_hygiene)
TASTE=$(score_taste)

# --- Weighted total ---
# Taste gets real weight — it's the thing AI coding misses.
# Product + Capabilities = 40% (rewards building)
# Taste = 20% (rewards distinctiveness)
# Structure + Hygiene = 25% (rewards quality)
# Build = 15% (gate)
TOTAL=$(awk "BEGIN { printf \"%d\", ($BUILD * 0.10) + ($STRUCTURE * 0.10) + ($PRODUCT * 0.20) + ($CAPABILITIES * 0.20) + ($TASTE * 0.20) + ($HYGIENE * 0.20) }")

# --- Output ---
case "$OUTPUT_MODE" in
    score)
        echo "$TOTAL"
        ;;
    json)
        cat <<EOF
{"score":$TOTAL,"build":$BUILD,"structure":$STRUCTURE,"product":$PRODUCT,"capabilities":$CAPABILITIES,"taste":$TASTE,"hygiene":$HYGIENE,"project_type":"$PROJECT_TYPE","src_dir":"$SRC_DIR"}
EOF
        ;;
    breakdown)
        echo "=== Product Score: $TOTAL/100 ==="
        echo ""
        echo "  Build Health:     $BUILD/100  (10%)  — does it compile?"
        echo "  Structure:        $STRUCTURE/100  (10%)  — dead ends, empty states"
        echo "  Product Signals:  $PRODUCT/100  (20%)  — share, push, OG, retention, social"
        echo "  Capabilities:     $CAPABILITIES/100  (20%)  — features, routes, auth, search"
        echo "  Taste (IA+VA):    $TASTE/100  (20%)  — identity, motion, feedback, polish"
        echo "  Code Hygiene:     $HYGIENE/100  (20%)  — hardcoded colors, any, console.log"
        echo ""
        echo "  Project: $PROJECT_TYPE ($SRC_DIR)"
        echo ""
        echo "Score goes UP when you: add features, add distinctiveness, fix debt."
        echo "Score goes DOWN when you: break the build, add dead ends, add generic patterns."
        echo "Taste measures resistance to AI convergence — does this feel like YOUR product?"
        ;;
esac
