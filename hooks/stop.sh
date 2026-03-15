#!/usr/bin/env bash
# stop.sh — Nudge when score cache is stale or too many uncommitted files.
# Hook: Stop event. Target: <50ms.
# Does NOT run rhino score — only checks file stats + git status.

set -euo pipefail

CACHE_FILE=".claude/cache/score-cache.json"
STALE_MINUTES=10

# Check score cache staleness
if [[ -f "$CACHE_FILE" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE") ))
    else
        cache_age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
    fi
    stale_seconds=$((STALE_MINUTES * 60))

    # Check for uncommitted changes
    changed_files=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    staged_files=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    total_uncommitted=$((changed_files + staged_files))

    if [[ $cache_age -gt $stale_seconds && $total_uncommitted -gt 0 ]]; then
        echo "score cache is $((cache_age / 60))m stale with $total_uncommitted uncommitted changes — consider running rhino score ."
    fi

    if [[ $total_uncommitted -gt 5 ]]; then
        echo "$total_uncommitted uncommitted files — consider atomic commits"
    fi
fi
