#!/usr/bin/env bash
# post_commit.sh — Invalidate score cache after git commit.
# Hook: PostToolUse (matcher: Bash). Target: <50ms.
# Parses hook input JSON for git commit commands. Skips amend.

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract the command from hook input JSON
COMMAND=$(echo "$INPUT" | grep -o '"input"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"input"[[:space:]]*:[[:space:]]*"//;s/"$//' 2>/dev/null || true)

# Only act on git commit (not amend)
if echo "$COMMAND" | grep -q 'git commit' 2>/dev/null; then
    if echo "$COMMAND" | grep -q '\-\-amend' 2>/dev/null; then
        exit 0
    fi

    CACHE_FILE=".claude/cache/score-cache.json"
    if [[ -f "$CACHE_FILE" ]]; then
        rm -f "$CACHE_FILE"
    fi

    # Print committed hash
    HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "???")
    echo "committed $HASH — score cache cleared"
fi
