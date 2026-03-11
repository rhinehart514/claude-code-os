#!/usr/bin/env bash
# capture_knowledge.sh — Post-session knowledge extraction hook
# Fires on Stop event. Captures observable artifacts (git, usage, plan state).
# Does NOT call claude -p (no session memory available).

INPUT="$(cat)"

CLAUDE_DIR="$HOME/.claude"
LOG_DIR="$CLAUDE_DIR/logs"
KNOWLEDGE_DIR="$CLAUDE_DIR/knowledge"
USAGE_FILE="$LOG_DIR/usage.jsonl"
CAPTURE_LOCK="$LOG_DIR/.capture-lock"

# Prevent concurrent captures
if [[ -f "$CAPTURE_LOCK" ]]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$CAPTURE_LOCK" 2>/dev/null || stat -c %Y "$CAPTURE_LOCK" 2>/dev/null || echo "0") ))
    if (( lock_age < 300 )); then
        exit 0
    fi
fi

# Count tool uses in the last 30 minutes (macOS-compatible awk)
if [[ -f "$USAGE_FILE" ]]; then
    thirty_min_ago=$(date -u -v-30M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
    if [[ -n "$thirty_min_ago" ]]; then
        tool_count=$(awk -v cutoff="$thirty_min_ago" '
            {
                if (match($0, /"ts":"[^"]+"/)) {
                    ts = substr($0, RSTART+6, RLENGTH-7)
                    if (ts >= cutoff) count++
                }
            }
            END { print count+0 }
        ' "$USAGE_FILE")
    else
        tool_count=0
    fi
else
    tool_count=0
fi

# Skip trivial sessions
if (( tool_count < 5 )); then
    exit 0
fi

# Detect current project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Create capture lock
echo "$$" > "$CAPTURE_LOCK"
trap 'rm -f "$CAPTURE_LOCK"' EXIT

# Determine output file
SESSION_KNOWLEDGE="$KNOWLEDGE_DIR/sessions"
mkdir -p "$SESSION_KNOWLEDGE"
SESSION_FILE="$SESSION_KNOWLEDGE/${PROJECT_NAME}.md"
TODAY="$(date +%Y-%m-%d)"

# Capture from observable artifacts (no claude -p — it has no session memory)
CAPTURE=""

# 1. Git activity
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    recent_commits=$(git -C "$PROJECT_DIR" log --oneline -10 --since="30 minutes ago" 2>/dev/null || true)
    if [[ -n "$recent_commits" ]]; then
        CAPTURE+="### Commits
$recent_commits
"
    fi

    uncommitted=$(git -C "$PROJECT_DIR" diff --stat 2>/dev/null | tail -5)
    if [[ -n "$uncommitted" ]]; then
        CAPTURE+="### Uncommitted
$uncommitted
"
    fi
fi

# 2. Tool activity count
if (( tool_count > 0 )); then
    CAPTURE+="### Activity
${tool_count} tool calls in last 30m
"
fi

# 3. Active plan state (check project-local first, then global)
PLAN_FILE=""
for plan_path in "$PROJECT_DIR/.claude/plans/active-plan.md" "$CLAUDE_DIR/plans/active-plan.md"; do
    [[ -f "$plan_path" ]] && PLAN_FILE="$plan_path" && break
done
if [[ -n "$PLAN_FILE" ]]; then
    plan_title=$(head -3 "$PLAN_FILE" | grep -E '^#' | head -1 || echo "Active plan exists")
    CAPTURE+="### Plan
$plan_title
"
fi

# 4. Plan progress — completed vs remaining tasks
if [[ -n "$PLAN_FILE" ]]; then
    completed_tasks=$(grep -c '\[x\]' "$PLAN_FILE" 2>/dev/null || echo "0")
    remaining_tasks=$(grep -c '\[ \]' "$PLAN_FILE" 2>/dev/null || echo "0")
    if [[ "$completed_tasks" -gt 0 || "$remaining_tasks" -gt 0 ]]; then
        CAPTURE+="### Progress
$completed_tasks done, $remaining_tasks remaining
"
    fi
    next_task=$(grep -m1 '\[ \]' "$PLAN_FILE" 2>/dev/null | sed 's/.*\[ \] //')
    if [[ -n "$next_task" ]]; then
        CAPTURE+="### Next
$next_task
"
    fi
fi

# 5. Taste signals recorded today
TASTE_FILE="$KNOWLEDGE_DIR/taste.jsonl"
if [[ -f "$TASTE_FILE" ]] && command -v jq &>/dev/null; then
    today_taste=$(grep "$TODAY" "$TASTE_FILE" 2>/dev/null | head -5)
    if [[ -n "$today_taste" ]]; then
        taste_summary=$(echo "$today_taste" | jq -r '"[\(.domain)] \(.signal)"' 2>/dev/null)
        if [[ -n "$taste_summary" ]]; then
            CAPTURE+="### Taste signals
$taste_summary
"
        fi
    fi
fi

# 6. Founder taste capture — detect taste statements in recent session artifacts
# Look for taste-related keywords in recent changes to CLAUDE.md, plans, or docs
FOUNDER_TASTE_FILE="$KNOWLEDGE_DIR/founder-taste.md"
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    # Check recent commit messages and diffs for taste signals
    taste_keywords="looks like|feels like|I like how|I want it to|should look|should feel|too cluttered|too sparse|too generic|more like|inspired by|Linear|Notion|Discord|Arc|beautiful|ugly|clean|messy|polished|rough"
    recent_taste=$(git -C "$PROJECT_DIR" log --oneline -5 --since="30 minutes ago" --format="%s" 2>/dev/null | grep -iE "$taste_keywords" | head -3)
    if [[ -n "$recent_taste" ]]; then
        CAPTURE+="### Taste Preferences Detected
$recent_taste
"
        # Append to founder-taste.md if it exists
        if [[ -f "$FOUNDER_TASTE_FILE" ]]; then
            {
                echo "- [auto-captured $TODAY]: $recent_taste"
                echo "  - Context: commit message in $PROJECT_NAME"
                echo "  - Strength: weak (auto-detected, needs confirmation)"
            } >> "$FOUNDER_TASTE_FILE"
        fi
    fi
fi

# Skip if nothing to capture
if [[ -z "$CAPTURE" ]]; then
    exit 0
fi

# Append to session knowledge
{
    echo ""
    echo "## $TODAY $(date +%H:%M) — $PROJECT_NAME"
    echo "$CAPTURE"
} >> "$SESSION_FILE"

# Prune entries older than 60 days (macOS-compatible awk)
if [[ -f "$SESSION_FILE" ]]; then
    sixty_days_ago=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d '60 days ago' +%Y-%m-%d 2>/dev/null || echo "")
    if [[ -n "$sixty_days_ago" ]]; then
        tmpfile=$(mktemp)
        awk -v cutoff="$sixty_days_ago" '
            BEGIN { printing = 1 }
            /^## [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/ {
                if (match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
                    dt = substr($0, RSTART, 10)
                    printing = (dt >= cutoff)
                }
            }
            printing { print }
        ' "$SESSION_FILE" > "$tmpfile" && mv "$tmpfile" "$SESSION_FILE" || rm -f "$tmpfile"
    fi
fi

exit 0
