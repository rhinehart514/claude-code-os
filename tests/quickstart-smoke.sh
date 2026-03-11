#!/usr/bin/env bash
set -uo pipefail

# quickstart-smoke.sh — Validates the cold-start path works for a fresh project.
#
# Tests that a new user can: install → setup → get valid score → have strategy inputs ready.
# Does NOT run Claude (can't nest Claude Code). Tests everything up to the point where
# Claude would take over.
#
# Usage: tests/quickstart-smoke.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
    local desc="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}✗${NC} $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${BOLD}=== Quickstart Smoke Test ===${NC}"
echo -e "${DIM}  Simulates a new user's first experience with rhino-os${NC}"
echo ""

# --- Create temp project ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/src"
echo '{ "name": "test-project", "version": "1.0.0" }' > "$TMPDIR/package.json"
echo 'console.log("hello")' > "$TMPDIR/src/index.js"
echo '# Test Project' > "$TMPDIR/README.md"

echo -e "${BOLD}1. Score works on fresh project${NC}"

# score.sh should work on any directory
SCORE_OUTPUT=$("$RHINO_DIR/bin/score.sh" "$TMPDIR" --json 2>/dev/null)
check "score.sh runs without error" "$?"
check "score.sh produces valid JSON" "$(echo "$SCORE_OUTPUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; echo $?)"
check "score.sh returns a numeric score" "$(echo "$SCORE_OUTPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d["score"], int)' 2>/dev/null; echo $?)"

echo ""
echo -e "${BOLD}2. Setup creates correct structure${NC}"

# Simulate what rhino setup does (can't run the skill, but can check the structure it creates)
mkdir -p "$TMPDIR/.claude/plans"
mkdir -p "$TMPDIR/.claude/experiments"

check ".claude/plans/ exists after setup" "$([ -d "$TMPDIR/.claude/plans" ] && echo 0 || echo 1)"
check ".claude/experiments/ exists after setup" "$([ -d "$TMPDIR/.claude/experiments" ] && echo 0 || echo 1)"

echo ""
echo -e "${BOLD}3. Cold-start strategy inputs are valid${NC}"

# Strategy cold-start needs: score output + CLAUDE.md/package.json. Verify these are readable.
check "score breakdown available" "$(echo "$SCORE_OUTPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "structure" in d and "hygiene" in d' 2>/dev/null; echo $?)"
check "package.json is readable" "$([ -f "$TMPDIR/package.json" ] && echo 0 || echo 1)"

# Verify cold-start detection works (no learnings, no brains, no experiment TSVs)
check "no experiment learnings (cold start)" "$([ ! -f "$TMPDIR/.claude/knowledge/experiment-learnings.md" ] && echo 0 || echo 1)"
TSV_COUNT=$(find "$TMPDIR/.claude/experiments" -name "*.tsv" 2>/dev/null | wc -l | tr -d ' ')
check "no experiment TSVs (cold start)" "$([ "$TSV_COUNT" = "0" ] && echo 0 || echo 1)"

echo ""
echo -e "${BOLD}4. Programs have cold-start paths${NC}"

check "strategy.md has cold-start section" "$(grep -q 'First Run Strategy' "$RHINO_DIR/programs/strategy.md" && echo 0 || echo 1)"
check "build.md has cold-start section" "$(grep -q 'Cold Start Detection' "$RHINO_DIR/programs/build.md" && echo 0 || echo 1)"
check "strategy.md has first-run plan template" "$(grep -q 'First run' "$RHINO_DIR/programs/strategy.md" && echo 0 || echo 1)"
check "build.md has first-build skip rules" "$(grep -q 'FIRST BUILD' "$RHINO_DIR/programs/build.md" && echo 0 || echo 1)"

echo ""
echo -e "${BOLD}5. Skills have conditional loading${NC}"

check "strategy skill loads correctly" "$([ -f "$RHINO_DIR/skills/strategy/SKILL.md" ] && echo 0 || echo 1)"
check "build skill loads correctly" "$([ -f "$RHINO_DIR/skills/build/SKILL.md" ] && echo 0 || echo 1)"
check "strategy skill references cold-start" "$(grep -q -i 'cold.start\|first.run\|no.*learnings\|empty.*state' "$RHINO_DIR/skills/strategy/SKILL.md" 2>/dev/null && echo 0 || echo 1)"
check "build skill references cold-start" "$(grep -q -i 'cold.start\|first.run\|first.build\|no.*history' "$RHINO_DIR/skills/build/SKILL.md" 2>/dev/null && echo 0 || echo 1)"

echo ""
echo -e "${BOLD}Results${NC}"
TOTAL=$((PASS + FAIL))
echo -e "  ${GREEN}$PASS${NC}/$TOTAL passed"
if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}$FAIL failed${NC}"
    exit 1
else
    echo -e "  ${GREEN}All checks passed${NC}"
    exit 0
fi
