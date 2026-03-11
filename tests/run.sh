#!/usr/bin/env bash
set -uo pipefail
# NOTE: set -e intentionally omitted. Tests use pass/fail counters.

# run.sh — rhino-os self-eval. Brutal, deterministic, no LLM judges.
#
# Five tiers, percentage-based:
#   Tier 1: Deterministic  (does the code work?)
#   Tier 2: Functional     (do workflows produce correct outputs?)
#   Tier 3: Canary         (known inputs → known outputs, detects drift)
#   Tier 4: Capability     (can agents actually do their jobs?)
#   Tier 5: Autonomy       (how close to building a product with zero human?)
#
# Usage:
#   tests/run.sh              # all tiers, visual output
#   tests/run.sh --json       # machine-readable
#   tests/run.sh --tier 1     # run only tier 1
#   tests/run.sh --tier 2     # run only tier 2
#   tests/run.sh --tier 3     # run only tier 3

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_MODE="visual"
RUN_TIER="all"

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --tier) :;; # next arg is the tier number
        1|2|3|4|5) RUN_TIER="$arg" ;;
        --help|-h)
            echo "Usage: tests/run.sh [--json] [--tier 1|2|3]"
            exit 0
            ;;
    esac
done

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Test Framework ---
TIER=""
TIER_PASS=0
TIER_FAIL=0
TIER_TOTAL=0
TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_TOTAL=0
FAILED_TESTS=""
RESULTS_JSON="[]"

tier_start() {
    TIER="$1"
    TIER_PASS=0
    TIER_FAIL=0
    TIER_TOTAL=0
    [[ "$OUTPUT_MODE" == "visual" ]] && echo -e "\n${BOLD}━━━ Tier $TIER ━━━${NC}"
}

tier_end() {
    local pct=0
    [[ "$TIER_TOTAL" -gt 0 ]] && pct=$((TIER_PASS * 100 / TIER_TOTAL))

    TOTAL_PASS=$((TOTAL_PASS + TIER_PASS))
    TOTAL_FAIL=$((TOTAL_FAIL + TIER_FAIL))
    TOTAL_TOTAL=$((TOTAL_TOTAL + TIER_TOTAL))

    RESULTS_JSON=$(echo "$RESULTS_JSON" | jq \
        --arg tier "$TIER" --argjson pass "$TIER_PASS" --argjson fail "$TIER_FAIL" \
        --argjson total "$TIER_TOTAL" --argjson pct "$pct" \
        '. + [{"tier": $tier, "pass": $pass, "fail": $fail, "total": $total, "pct": $pct}]')

    if [[ "$OUTPUT_MODE" == "visual" ]]; then
        local color="$GREEN"
        [[ "$pct" -lt 90 ]] && color="$YELLOW"
        [[ "$pct" -lt 70 ]] && color="$RED"
        echo -e "\n  ${color}Tier $TIER: ${TIER_PASS}/${TIER_TOTAL} passed (${pct}%)${NC}"
    fi
}

assert() {
    local name="$1"
    local result="$2"  # 0 = pass, nonzero = fail
    local detail="${3:-}"

    TIER_TOTAL=$((TIER_TOTAL + 1))

    if [[ "$result" -eq 0 ]]; then
        TIER_PASS=$((TIER_PASS + 1))
        [[ "$OUTPUT_MODE" == "visual" ]] && echo -e "  ${GREEN}✓${NC} ${name}"
    else
        TIER_FAIL=$((TIER_FAIL + 1))
        FAILED_TESTS+="  [Tier $TIER] $name"
        [[ -n "$detail" ]] && FAILED_TESTS+=" — $detail"
        FAILED_TESTS+=$'\n'
        [[ "$OUTPUT_MODE" == "visual" ]] && echo -e "  ${RED}✗${NC} ${name}${detail:+ — $detail}"
    fi
}

# Helper: check file exists
assert_file() {
    local name="$1" path="$2"
    if [[ -f "$path" ]]; then
        assert "$name" 0
    else
        assert "$name" 1 "missing: $path"
    fi
}

# Helper: check command succeeds
assert_cmd() {
    local name="$1"
    shift
    local output
    output=$("$@" 2>&1)
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        assert "$name" 0
    else
        assert "$name" 1 "exit $rc"
    fi
}

# Helper: check output contains string
assert_contains() {
    local name="$1" output="$2" expected="$3"
    if echo "$output" | grep -q "$expected"; then
        assert "$name" 0
    else
        assert "$name" 1 "expected '$expected' not found"
    fi
}

# Helper: check output matches exact value
assert_equals() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        assert "$name" 0
    else
        assert "$name" 1 "expected '$expected', got '$actual'"
    fi
}

# Shared paths for capability/autonomy tiers
PROJECTS_DIR="$HOME/Desktop"
CLAUDE_HOME="$HOME/.claude"

# Create isolated temp dir for tests that need state
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

[[ "$OUTPUT_MODE" == "visual" ]] && echo -e "${BOLD}=== rhino-os self-eval ===${NC}"

# ============================================================
# TIER 1: DETERMINISTIC — Does the code work?
# Binary pass/fail. No judgment. Cheapest checks.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "1" ]]; then
tier_start "1: Deterministic"

# --- 1.1 File existence (every required file exists) ---
assert_file "bin/rhino exists" "$RHINO_DIR/bin/rhino"
assert_file "bin/score.sh exists" "$RHINO_DIR/bin/score.sh"
assert_file "bin/taste.mjs exists" "$RHINO_DIR/bin/taste.mjs"
assert_file "bin/lib/config.sh exists" "$RHINO_DIR/bin/lib/config.sh"
assert_file "bin/lib/brains.sh exists" "$RHINO_DIR/bin/lib/brains.sh"
assert_file "bin/lib/workspace.sh exists" "$RHINO_DIR/bin/lib/workspace.sh"
assert_file "install.sh exists" "$RHINO_DIR/install.sh"
assert_file "config/rhino.yml exists" "$RHINO_DIR/config/rhino.yml"
assert_file "config/CLAUDE.md exists" "$RHINO_DIR/config/CLAUDE.md"
assert_file "config/settings.json exists" "$RHINO_DIR/config/settings.json"
assert_file "agents/refs/score-integrity.md exists" "$RHINO_DIR/agents/refs/score-integrity.md"
assert_file "agents/refs/escalation.md exists" "$RHINO_DIR/agents/refs/escalation.md"

# All 6 agent prompts
for agent in builder scout strategist design-engineer sweep meta; do
    assert_file "agents/$agent.md exists" "$RHINO_DIR/agents/$agent.md"
done

# All user-facing skills (5 primary + 6 utility)
for skill in plan build research review go setup status meta docs council smart-commit; do
    assert_file "skills/$skill/SKILL.md exists" "$RHINO_DIR/skills/$skill/SKILL.md"
done

# All internal skills
for skill in eval product-eval experiment todofocus product-2026 strategy design sweep scout init score taste research-taste; do
    assert_file "skills/_internal/$skill/SKILL.md exists" "$RHINO_DIR/skills/_internal/$skill/SKILL.md"
done

# All hooks (including new autonomy_gate)
for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh thinking_nudge.sh check_predictions.sh post_edit_quality.sh autonomy_gate.sh; do
    assert_file "hooks/$hook exists" "$RHINO_DIR/hooks/$hook"
done

# All programs
assert_file "programs/build.md exists" "$HOME/.claude/programs/build.md"
assert_file "programs/strategy.md exists" "$HOME/.claude/programs/strategy.md"
assert_file "programs/review.md exists" "$HOME/.claude/programs/review.md"

# --- 1.2 Syntax checks (every script parses) ---
assert_cmd "bin/rhino parses (bash -n)" bash -n "$RHINO_DIR/bin/rhino"
assert_cmd "bin/score.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/score.sh"
assert_cmd "bin/lib/config.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/config.sh"
assert_cmd "bin/lib/brains.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/brains.sh"
assert_cmd "bin/lib/workspace.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/workspace.sh"
assert_cmd "install.sh parses (bash -n)" bash -n "$RHINO_DIR/install.sh"
assert_cmd "bin/taste.mjs parses (node --check)" node --check "$RHINO_DIR/bin/taste.mjs"

for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh thinking_nudge.sh check_predictions.sh post_edit_quality.sh autonomy_gate.sh; do
    assert_cmd "hooks/$hook parses (bash -n)" bash -n "$RHINO_DIR/hooks/$hook"
done

# --- 1.3 CLI routing (--help works for main and subcommands) ---
HELP_OUTPUT=$("$RHINO_DIR/bin/rhino" --help 2>&1 || true)
assert_contains "rhino --help outputs usage" "$HELP_OUTPUT" "usage\|Usage\|USAGE\|rhino"

SCORE_HELP=$("$RHINO_DIR/bin/score.sh" --help 2>&1 || true)
assert_contains "score.sh --help works" "$SCORE_HELP" "Usage\|usage"

TASTE_HELP=$(node "$RHINO_DIR/bin/taste.mjs" --help 2>&1 || true)
assert_contains "taste.mjs --help works" "$TASTE_HELP" "Usage\|usage"

# --- 1.4 Config reader works ---
# Source config.sh and test cfg() against known values
CFG_TEST=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg scoring.cache_ttl MISSING)
")
assert_equals "cfg() reads scoring.cache_ttl" "$CFG_TEST" "300"

CFG_DEFAULT=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg nonexistent.key FALLBACK)
")
assert_equals "cfg() returns default for missing key" "$CFG_DEFAULT" "FALLBACK"

# cfg() reads flow YAML objects as raw strings (not parsed into sub-keys)
# This is a known limitation: { width: 1440, height: 900 } is one value
CFG_FLOW=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg taste.viewports.desktop MISSING)
")
assert_contains "cfg() reads YAML flow object as string" "$CFG_FLOW" "1440"

# Standard 3-level nesting (non-flow) works
CFG_NESTED=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg scoring.build.ts_error_penalty MISSING)
")
assert_equals "cfg() reads 3-level nested key" "$CFG_NESTED" "-30"

# --- 1.5 JSON validity (brain files, any existing state files) ---
# Check any existing brain files
if compgen -G "$HOME/.claude/state/brains/*.json" > /dev/null 2>&1; then
    for brain in "$HOME/.claude/state/brains"/*.json; do
        [[ -f "$brain" ]] || continue
        bname=$(basename "$brain")
        assert_cmd "brain $bname is valid JSON" jq '.' "$brain"
    done
fi

# --- 1.6 No broken references ---
# Score integrity doc referenced by all scoring touchpoints
for file in \
    "$HOME/.claude/programs/build.md" \
    "$HOME/.claude/programs/strategy.md" \
    "$RHINO_DIR/skills/_internal/eval/SKILL.md" \
    "$RHINO_DIR/skills/_internal/product-eval/SKILL.md" \
    "$RHINO_DIR/skills/_internal/experiment/SKILL.md" \
    "$RHINO_DIR/agents/meta.md" \
    "$RHINO_DIR/agents/design-engineer.md"; do
    fname=$(basename "$file")
    if grep -q "score-integrity" "$file" 2>/dev/null; then
        assert "$fname references score-integrity.md" 0
    else
        assert "$fname references score-integrity.md" 1 "missing reference"
    fi
done

# --- 1.7 Executable permissions ---
assert_cmd "bin/rhino is executable" test -x "$RHINO_DIR/bin/rhino"

for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh thinking_nudge.sh check_predictions.sh post_edit_quality.sh autonomy_gate.sh; do
    if [[ -x "$RHINO_DIR/hooks/$hook" ]]; then
        assert "hooks/$hook is executable" 0
    else
        assert "hooks/$hook is executable" 1
    fi
done

tier_end
fi

# ============================================================
# TIER 2: FUNCTIONAL — Do workflows produce correct outputs?
# Tests that score.sh produces valid output, integrity detectors
# fire on known scenarios, config system handles edge cases.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "2" ]]; then
tier_start "2: Functional"

# --- 2.1 score.sh output format ---
# Run score on rhino-os itself (a non-web project — should handle gracefully)
SCORE_JSON=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --json --force 2>/dev/null || true)
if echo "$SCORE_JSON" | jq '.' >/dev/null 2>&1; then
    assert "score.sh --json produces valid JSON" 0

    # Check required fields
    for field in score build build_gate structure hygiene project_type; do
        if echo "$SCORE_JSON" | jq -e ".$field" >/dev/null 2>&1; then
            assert "score JSON has .$field" 0
        else
            assert "score JSON has .$field" 1 "missing field"
        fi
    done

    # Check integrity_warnings field exists (our new addition)
    if echo "$SCORE_JSON" | jq -e '.integrity_warnings' >/dev/null 2>&1; then
        assert "score JSON has .integrity_warnings" 0
    else
        assert "score JSON has .integrity_warnings" 1 "missing field"
    fi

    # Score is a number 0-100
    SCORE_VAL=$(echo "$SCORE_JSON" | jq '.score')
    if [[ "$SCORE_VAL" =~ ^[0-9]+$ ]] && [[ "$SCORE_VAL" -ge 0 ]] && [[ "$SCORE_VAL" -le 100 ]]; then
        assert "score is 0-100 integer" 0
    else
        assert "score is 0-100 integer" 1 "got: $SCORE_VAL"
    fi
else
    assert "score.sh --json produces valid JSON" 1 "invalid JSON output"
fi

# --- 2.2 score.sh --quiet produces single number ---
SCORE_QUIET=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
if [[ "$SCORE_QUIET" =~ ^[0-9]+$ ]]; then
    assert "score.sh --quiet outputs single number" 0
else
    assert "score.sh --quiet outputs single number" 1 "got: '$SCORE_QUIET'"
fi

# --- 2.3 score.sh determinism (same input → same output) ---
SCORE_A=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
SCORE_B=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
assert_equals "score.sh is deterministic (run twice)" "$SCORE_A" "$SCORE_B"

# --- 2.4 cfg() edge cases ---
# Empty value returns default
CFG_EMPTY=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg agents.budgets.builder DEFAULT_VAL)
")
# builder budget is ~ (tilde = null), should return default
assert_equals "cfg() treats ~ as empty (returns default)" "$CFG_EMPTY" "DEFAULT_VAL"

# Inline comments stripped
CFG_COMMENT=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg scoring.cache_ttl MISSING)
")
# Should be "300" not "300  # seconds before..."
if [[ "$CFG_COMMENT" =~ ^[0-9]+$ ]]; then
    assert "cfg() strips inline comments" 0
else
    assert "cfg() strips inline comments" 1 "got: '$CFG_COMMENT'"
fi

# --- 2.5 Integrity config exists and is readable ---
INTEGRITY_CEILING=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg integrity.max_single_commit_delta MISSING)
")
assert_equals "integrity.max_single_commit_delta configured" "$INTEGRITY_CEILING" "15"

INTEGRITY_PLATEAU=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg integrity.plateau_experiments MISSING)
")
assert_equals "integrity.plateau_experiments configured" "$INTEGRITY_PLATEAU" "5"

INTEGRITY_COSMETIC=$(bash -c "
    source '$RHINO_DIR/bin/lib/config.sh'
    echo \$(cfg integrity.cosmetic_only_warning MISSING)
")
assert_equals "integrity.cosmetic_only_warning configured" "$INTEGRITY_COSMETIC" "true"

# --- 2.6 rhino.yml has all required sections ---
for section in agents scoring taste knowledge context brains experiments integrity; do
    if grep -q "^# ── .* $section\|^${section}:" "$RHINO_DIR/config/rhino.yml" 2>/dev/null || \
       grep -q "^${section}:" "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
        assert "rhino.yml has $section section" 0
    else
        assert "rhino.yml has $section section" 1
    fi
done

# --- 2.7 Brain system produces valid JSON ---
# Simplified brains: each agent gets {agent, next_move, bias_awareness, last_run, updated}
BRAIN_TEST_DIR="$TMPDIR_TEST/brain-test"
mkdir -p "$BRAIN_TEST_DIR"
BRAIN_TEST_OUTPUT=$(bash -c "
    STATE_DIR='$BRAIN_TEST_DIR'
    RHINO_DIR='$RHINO_DIR'
    source '$RHINO_DIR/bin/lib/config.sh'
    source '$RHINO_DIR/bin/lib/brains.sh'
    _ensure_brain 'test-agent'
    cat '$BRAIN_TEST_DIR/brains/test-agent.json'
" 2>/dev/null)
if echo "$BRAIN_TEST_OUTPUT" | jq -e '.agent' >/dev/null 2>&1; then
    assert "brain system creates valid JSON" 0
else
    assert "brain system creates valid JSON" 1
fi

# --- 2.8 Taste rubric includes integrity rules ---
if grep -q "Score Integrity" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "taste.mjs rubric has Score Integrity section" 0
else
    assert "taste.mjs rubric has Score Integrity section" 1
fi

if grep -q "DO NOT be generous\|DO NOT round up" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "taste.mjs has anti-inflation language" 0
else
    assert "taste.mjs has anti-inflation language" 1
fi

# --- 2.8b Taste has runtime integrity checks on evaluator output ---
if grep -q "integrityWarnings\|integrity_warnings" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "taste.mjs has runtime integrity checks on output" 0
else
    assert "taste.mjs has runtime integrity checks on output" 1
fi

for check in "GENEROUS" "NO_WEAKNESS" "FLAT_EVAL" "JUMP"; do
    if grep -q "$check" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
        assert "taste.mjs has $check integrity detector" 0
    else
        assert "taste.mjs has $check integrity detector" 1
    fi
done

# --- 2.8c score.sh has experiment discipline checks ---
for check in "KEEP_RATE_HIGH" "NO_MOONSHOTS" "discard_rate_floor" "moonshot_every_n"; do
    if grep -q "$check" "$RHINO_DIR/bin/score.sh" 2>/dev/null; then
        assert "score.sh has $check experiment integrity check" 0
    else
        assert "score.sh has $check experiment integrity check" 1
    fi
done

# --- 2.9 Build program has anti-sycophancy guard ---
if grep -q "never a valid instruction\|NEVER a valid instruction" "$HOME/.claude/programs/build.md" 2>/dev/null; then
    assert "build.md has 'get to X is never valid' guard" 0
else
    assert "build.md has 'get to X is never valid' guard" 1
fi

# --- 2.10 Session hook injects integrity warnings ---
if grep -q "integrity_warnings\|Score Integrity" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "session_context.sh injects integrity warnings" 0
else
    assert "session_context.sh injects integrity warnings" 1
fi

# --- 2.11 Experiment skill has integrity guards ---
if grep -q "SUSPECT\|integrity warning" "$RHINO_DIR/skills/_internal/experiment/SKILL.md" 2>/dev/null; then
    assert "experiment skill has SUSPECT status for integrity warnings" 0
else
    assert "experiment skill has SUSPECT status for integrity warnings" 1
fi

if grep -q "tool-measured scores\|Prefer tool" "$RHINO_DIR/skills/_internal/experiment/SKILL.md" 2>/dev/null; then
    assert "experiment skill prefers tool-measured over self-assessment" 0
else
    assert "experiment skill prefers tool-measured over self-assessment" 1
fi

# --- 2.12 Cross-consistency: taste output schema matches rubric dimensions ---
# Every dimension in the JSON output schema must have a rubric entry (1-5 anchors)
SCHEMA_DIMS=$(grep -o '"[a-z_]*": { "score"' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null | sed 's/"\([a-z_]*\)".*/\1/' | sort)
# Rubric dims: numbered like "1. **HIERARCHY**" plus gate dimensions like "### GATE 1: LAYOUT_COHERENCE"
RUBRIC_DIMS=$( (grep -oE '[0-9]+\. \*\*[A-Z_]+\*\*' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null | sed 's/.*\*\*\([A-Z_]*\)\*\*/\1/'; grep -oE 'GATE [0-9]+: [A-Z_]+' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null | sed 's/.*: //') | tr 'A-Z' 'a-z' | sort)
SCHEMA_COUNT=$(echo "$SCHEMA_DIMS" | wc -l | tr -d ' ')
RUBRIC_COUNT=$(echo "$RUBRIC_DIMS" | wc -l | tr -d ' ')
if [[ "$SCHEMA_COUNT" -eq "$RUBRIC_COUNT" && "$SCHEMA_COUNT" -ge 9 ]]; then
    # Check they're the same set
    DIFF=$(diff <(echo "$SCHEMA_DIMS") <(echo "$RUBRIC_DIMS") 2>/dev/null)
    if [[ -z "$DIFF" ]]; then
        assert "taste: schema dimensions match rubric dimensions ($SCHEMA_COUNT/$RUBRIC_COUNT)" 0
    else
        assert "taste: schema dimensions match rubric dimensions" 1 "mismatch: $DIFF"
    fi
else
    assert "taste: schema dimensions match rubric dimensions" 1 "schema=$SCHEMA_COUNT rubric=$RUBRIC_COUNT"
fi

# --- 2.13 Cross-consistency: every agent in rhino.yml has a .md file ---
# Only grab the 4-space indented keys under budgets: (agent names), stop at blank line
for agent in $(awk '/^  budgets:/{found=1; next} found && /^    [a-z]/{gsub(/[: ].*/,""); gsub(/^    /,""); print} found && /^[^ ]|^$/{found=0}' "$RHINO_DIR/config/rhino.yml"); do
    # Map config names to file names (design→design-engineer)
    agent_file="$agent"
    [[ "$agent" == "design" ]] && agent_file="design-engineer"
    if [[ -f "$RHINO_DIR/agents/${agent_file}.md" ]]; then
        assert "agent $agent has agents/${agent_file}.md" 0
    else
        assert "agent $agent has agents/${agent_file}.md" 1 "missing"
    fi
done

# --- 2.14 Cross-consistency: every skill referenced in CLAUDE.md has a SKILL.md ---
for skill_dir in "$RHINO_DIR/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    [[ "$skill_name" == "_internal" ]] && continue
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        assert "skill $skill_name has SKILL.md" 0
    else
        assert "skill $skill_name has SKILL.md" 1
    fi
done

# --- 2.15 No broken internal references: programs reference files that exist in repo ---
BROKEN_REFS=0
BROKEN_LIST=""
for md_file in "$RHINO_DIR/agents"/*.md "$RHINO_DIR/programs"/*.md; do
    [[ -f "$md_file" ]] || continue
    base=$(basename "$md_file")
    # Find references to agents/refs/*.md files
    refs=$(grep -o 'agents/refs/[a-z_-]*.md' "$md_file" 2>/dev/null | sort -u)
    for ref in $refs; do
        if [[ ! -f "$RHINO_DIR/$ref" ]]; then
            BROKEN_REFS=$((BROKEN_REFS + 1))
            BROKEN_LIST="$BROKEN_LIST $base→$ref"
        fi
    done
done
if [[ "$BROKEN_REFS" -eq 0 ]]; then
    assert "no broken agents/refs/ references in programs or agents" 0
else
    assert "no broken agents/refs/ references in programs or agents" 1 "$BROKEN_REFS broken:$BROKEN_LIST"
fi

# --- 2.16 Score.sh reads ALL integrity config values it claims to enforce ---
# Every detector that reads cfg() must have a matching rhino.yml key
SCORE_CFG_READS=$(grep -o "cfg [a-z._]*" "$RHINO_DIR/bin/score.sh" 2>/dev/null | sed 's/cfg //' | sort -u)
for cfg_key in $SCORE_CFG_READS; do
    # Check that the leaf key name exists somewhere in rhino.yml
    leaf_key=$(echo "$cfg_key" | awk -F. '{print $NF}')
    if grep -q "$leaf_key" "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
        assert "score.sh cfg($cfg_key) has rhino.yml backing" 0
    else
        assert "score.sh cfg($cfg_key) has rhino.yml backing" 1 "dead config read"
    fi
done

# --- 2.17 HARD: COSMETIC-ONLY detector fires on crafted input ---
# Create project where only hygiene improved (structure flat)
COSMETIC_TEST_DIR="$TMPDIR_TEST/cosmetic-fire-test"
mkdir -p "$COSMETIC_TEST_DIR/src" "$COSMETIC_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$COSMETIC_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$COSMETIC_TEST_DIR/package.json"
# Seed history: structure=50 hygiene=50, then structure=50 hygiene=70 (hygiene up, structure flat)
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-01T00:00:00Z\t50\t50\t50\tnode\n" >> "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-02T00:00:00Z\t50\t50\t70\tnode\n" >> "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
COSMETIC_RESULT=$("$RHINO_DIR/bin/score.sh" "$COSMETIC_TEST_DIR" --json --force 2>/dev/null || true)
if echo "$COSMETIC_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null | grep -q "COSMETIC"; then
    assert "HARD: COSMETIC-ONLY detector fires on hygiene-only improvement" 0
else
    assert "HARD: COSMETIC-ONLY detector fires on hygiene-only improvement" 1 "detector didn't fire"
fi

# --- 2.18 HARD: INFLATION detector fires on big jump ---
INFLATION_TEST_DIR="$TMPDIR_TEST/inflation-fire-test"
mkdir -p "$INFLATION_TEST_DIR/src" "$INFLATION_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$INFLATION_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$INFLATION_TEST_DIR/package.json"
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-01T00:00:00Z\t50\t30\t30\tnode\n" >> "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-02T00:00:00Z\t50\t50\t50\tnode\n" >> "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
INFLATION_RESULT=$("$RHINO_DIR/bin/score.sh" "$INFLATION_TEST_DIR" --json --force 2>/dev/null || true)
if echo "$INFLATION_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null | grep -q "INFLATION"; then
    assert "HARD: INFLATION detector fires on +20 jump" 0
else
    assert "HARD: INFLATION detector fires on +20 jump" 1 "detector didn't fire"
fi

# --- 2.19 HARD: PLATEAU detector fires after N identical scores ---
PLATEAU_TEST_DIR="$TMPDIR_TEST/plateau-fire-test"
mkdir -p "$PLATEAU_TEST_DIR/src" "$PLATEAU_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$PLATEAU_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$PLATEAU_TEST_DIR/package.json"
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$PLATEAU_TEST_DIR/.claude/scores/history.tsv"
for i in 1 2 3 4 5 6; do
    printf "2026-01-%02dT00:00:00Z\t50\t50\t50\tnode\n" "$i" >> "$PLATEAU_TEST_DIR/.claude/scores/history.tsv"
done
PLATEAU_RESULT=$("$RHINO_DIR/bin/score.sh" "$PLATEAU_TEST_DIR" --json --force 2>/dev/null || true)
if echo "$PLATEAU_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null | grep -q "PLATEAU"; then
    assert "HARD: PLATEAU detector fires after 6 identical structure scores" 0
else
    assert "HARD: PLATEAU detector fires after 6 identical structure scores" 1 "detector didn't fire"
fi

# --- 2.20 HARD: Score.sh does NOT fire false INFLATION on small delta ---
NOFIRE_TEST_DIR="$TMPDIR_TEST/nofire-test"
mkdir -p "$NOFIRE_TEST_DIR/src" "$NOFIRE_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$NOFIRE_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$NOFIRE_TEST_DIR/package.json"
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$NOFIRE_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-01T00:00:00Z\t50\t48\t48\tnode\n" >> "$NOFIRE_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-02T00:00:00Z\t50\t50\t50\tnode\n" >> "$NOFIRE_TEST_DIR/.claude/scores/history.tsv"
NOFIRE_RESULT=$("$RHINO_DIR/bin/score.sh" "$NOFIRE_TEST_DIR" --json --force 2>/dev/null || true)
NOFIRE_WARNINGS=$(echo "$NOFIRE_RESULT" | jq -r '.integrity_warnings | length' 2>/dev/null || echo "0")
if [[ "$NOFIRE_WARNINGS" -eq 0 || "$NOFIRE_WARNINGS" == "null" ]]; then
    assert "HARD: no false INFLATION on +4 delta (under threshold)" 0
else
    warn_text=$(echo "$NOFIRE_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null)
    assert "HARD: no false INFLATION on +4 delta (under threshold)" 1 "false positive: $warn_text"
fi

# --- 2.21 HARD: session_context.sh produces non-empty output ---
# Remove cooldown marker so the test actually runs (marker causes silent exit within 30min)
rm -f "$HOME/.claude/state/.session-context-injected"
SESSION_OUT=$(bash "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null || true)
SESSION_LEN=${#SESSION_OUT}
if [[ "$SESSION_LEN" -gt 50 ]]; then
    assert "HARD: session_context.sh produces substantive output (${SESSION_LEN} chars)" 0
else
    assert "HARD: session_context.sh produces substantive output" 1 "only ${SESSION_LEN} chars"
fi

# --- 2.22 HARD: rhino bench command is defined ---
if grep -q "cmd_bench" "$RHINO_DIR/bin/rhino" 2>/dev/null; then
    assert "HARD: rhino bench command exists" 0
else
    assert "HARD: rhino bench command exists" 1
fi

# --- 2.23 Programs must have a measurable output ---
# Each program must reference at least one concrete command or file it writes
for prog in "$RHINO_DIR/programs"/*.md; do
    [[ -f "$prog" ]] || continue
    prog_name=$(basename "$prog" .md)
    has_output=false
    # Check for: bash code blocks, file write references, or tool commands
    if grep -qE '```bash|rhino |\.jsonl|\.json|\.tsv|\.md\b.*write|\.md\b.*update' "$prog" 2>/dev/null; then
        has_output=true
    fi
    if $has_output; then
        assert "program $prog_name references concrete outputs" 0
    else
        assert "program $prog_name references concrete outputs" 1 "no commands or file outputs found"
    fi
done

# --- 2.22 Boundary: no program or agent instructs writing to CLAUDE.md ---
CLAUDE_MD_WRITERS=""
for md_file in "$RHINO_DIR/programs"/*.md "$RHINO_DIR/agents"/*.md "$RHINO_DIR/skills"/*/SKILL.md "$RHINO_DIR/skills/_internal"/*/SKILL.md; do
    [[ -f "$md_file" ]] || continue
    base=$(basename "$(dirname "$md_file")")/$(basename "$md_file")
    # Match "update/write/edit CLAUDE.md" but exclude negations and meta-references (describing the rule itself)
    if grep -iE '(update|write|edit|append|modify).*CLAUDE\.md' "$md_file" 2>/dev/null \
        | grep -iv 'do not\|never\|don.t\|that.s a bug\|grep for\|scan.*for' \
        | grep -q .; then
        CLAUDE_MD_WRITERS="$CLAUDE_MD_WRITERS $base"
    fi
done
if [[ -z "$CLAUDE_MD_WRITERS" ]]; then
    assert "no program/agent/skill instructs writing to CLAUDE.md" 0
else
    assert "no program/agent/skill instructs writing to CLAUDE.md" 1 "found in:$CLAUDE_MD_WRITERS"
fi

# --- 2.24 Thinking protocol exists and is referenced ---
if [[ -f "$RHINO_DIR/agents/refs/thinking.md" ]]; then
    assert "thinking protocol exists" 0
else
    assert "thinking protocol exists" 1
fi

# --- 2.25 Thinking protocol is referenced by build.md ---
if grep -q "thinking.md" "$RHINO_DIR/programs/build.md" 2>/dev/null; then
    assert "build.md references thinking protocol" 0
else
    assert "build.md references thinking protocol" 1
fi

# --- 2.26 Thinking protocol is referenced by strategy.md ---
if grep -q "thinking.md" "$RHINO_DIR/programs/strategy.md" 2>/dev/null; then
    assert "strategy.md references thinking protocol" 0
else
    assert "strategy.md references thinking protocol" 1
fi

# --- 2.27 Thinking protocol is referenced by meta.md ---
if grep -q "thinking.md\|predictions.tsv" "$RHINO_DIR/programs/meta.md" 2>/dev/null; then
    assert "meta.md references thinking/predictions" 0
else
    assert "meta.md references thinking/predictions" 1
fi

# --- 2.28 Predictions tracking file exists with correct schema ---
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    pred_header=$(head -1 "$PRED_FILE")
    if echo "$pred_header" | grep -q "date.*agent.*prediction.*evidence.*result.*correct.*model_update"; then
        assert "predictions.tsv has correct schema" 0
    else
        assert "predictions.tsv has correct schema" 1 "header: $pred_header"
    fi
else
    assert "predictions.tsv has correct schema" 1 "file missing"
fi

# --- 2.29 build.md has prediction-before-action pattern ---
if grep -q "PREDICT:" "$RHINO_DIR/programs/build.md" 2>/dev/null && grep -q "WRONG IF:" "$RHINO_DIR/programs/build.md" 2>/dev/null; then
    assert "build.md enforces predict-before-act" 0
else
    assert "build.md enforces predict-before-act" 1
fi

# --- 2.30 experiment-learnings.md has causal model structure ---
LEARNINGS="$HOME/.claude/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS" ]]; then
    has_known=$(grep -c "Known Patterns\|high confidence" "$LEARNINGS" 2>/dev/null || echo "0")
    has_uncertain=$(grep -c "Uncertain Patterns\|worth testing" "$LEARNINGS" 2>/dev/null || echo "0")
    has_unknown=$(grep -c "Unknown Territory\|highest.*learning\|highest.*information" "$LEARNINGS" 2>/dev/null || echo "0")
    has_dead=$(grep -c "Dead Ends\|confirmed failure" "$LEARNINGS" 2>/dev/null || echo "0")
    zones=$((has_known > 0 ? 1 : 0))
    zones=$((zones + (has_uncertain > 0 ? 1 : 0)))
    zones=$((zones + (has_unknown > 0 ? 1 : 0)))
    zones=$((zones + (has_dead > 0 ? 1 : 0)))
    if [[ "$zones" -ge 3 ]]; then
        assert "experiment-learnings has causal model structure (${zones}/4 zones)" 0
    else
        assert "experiment-learnings has causal model structure" 1 "only ${zones}/4 zones found"
    fi
else
    assert "experiment-learnings has causal model structure" 1 "file missing"
fi

# --- 2.31 Strategy output template includes uncertainty mapping ---
if grep -q "Known.*Don.t Know\|Unknown.*highest\|Uncertain.*worth\|What We Know" "$RHINO_DIR/programs/strategy.md" 2>/dev/null; then
    assert "strategy.md includes uncertainty mapping in output" 0
else
    assert "strategy.md includes uncertainty mapping in output" 1
fi

# --- 2.32 HARD: session_context.sh surfaces prediction accuracy ---
if grep -q "predictions.tsv\|Prediction Accuracy\|pred_total\|pred_correct" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "HARD: session_context.sh surfaces prediction accuracy" 0
else
    assert "HARD: session_context.sh surfaces prediction accuracy" 1
fi

# --- 2.33 Skills read experiment learnings before acting ---
SKILLS_WITH_LEARNINGS=0
for skill_file in _internal/eval/SKILL.md _internal/product-eval/SKILL.md _internal/design/SKILL.md _internal/strategy/SKILL.md build/SKILL.md _internal/experiment/SKILL.md plan/SKILL.md review/SKILL.md research/SKILL.md; do
    if grep -q "experiment-learnings" "$RHINO_DIR/skills/$skill_file" 2>/dev/null; then
        SKILLS_WITH_LEARNINGS=$((SKILLS_WITH_LEARNINGS + 1))
    fi
done
if [[ "$SKILLS_WITH_LEARNINGS" -ge 5 ]]; then
    assert ">=5 skills read experiment-learnings.md" 0
else
    assert ">=5 skills read experiment-learnings.md (found $SKILLS_WITH_LEARNINGS)" 1
fi

# --- 2.34 Experiment skill references thinking protocol ---
if grep -q "thinking.md" "$RHINO_DIR/skills/_internal/experiment/SKILL.md" 2>/dev/null; then
    assert "experiment skill references thinking protocol" 0
else
    assert "experiment skill references thinking protocol" 1
fi

# --- 2.35 Workspace system produces valid JSON ---
WS_TEST_DIR="$TMPDIR_TEST/ws-test"
mkdir -p "$WS_TEST_DIR"
WS_TEST_OUTPUT=$(bash -c "
    WORKSPACE_FILE='$WS_TEST_DIR/workspace.json'
    source '$RHINO_DIR/bin/lib/workspace.sh'
    ws_register '/tmp/test-project' 'mvp' 'guided' 'balanced'
    cat '$WS_TEST_DIR/workspace.json'
" 2>/dev/null)
if echo "$WS_TEST_OUTPUT" | jq -e '.projects["test-project"].path' >/dev/null 2>&1; then
    assert "workspace ws_register creates valid JSON" 0
else
    assert "workspace ws_register creates valid JSON" 1
fi

# Workspace ws_get reads fields
WS_GET_TEST=$(bash -c "
    WORKSPACE_FILE='$WS_TEST_DIR/workspace.json'
    source '$RHINO_DIR/bin/lib/workspace.sh'
    echo \$(ws_get 'test-project' 'autonomy')
" 2>/dev/null)
assert_equals "workspace ws_get reads autonomy" "$WS_GET_TEST" "guided"

# Workspace focus is set on first register
WS_FOCUS_TEST=$(bash -c "
    WORKSPACE_FILE='$WS_TEST_DIR/workspace.json'
    source '$RHINO_DIR/bin/lib/workspace.sh'
    echo \$(ws_focus)
" 2>/dev/null)
assert_equals "workspace focus set on first register" "$WS_FOCUS_TEST" "test-project"

# --- 2.36 Autonomy gate hook parses and handles missing workspace gracefully ---
GATE_TEST=$(echo '{"tool_name":"Read"}' | bash "$RHINO_DIR/hooks/autonomy_gate.sh" 2>/dev/null; echo $?)
assert_equals "autonomy_gate allows non-gated tools" "$GATE_TEST" "0"

# --- 2.37 Settings.json has autonomy_gate.sh configured ---
if grep -q "autonomy_gate.sh" "$RHINO_DIR/config/settings.json" 2>/dev/null; then
    assert "settings.json has autonomy_gate.sh hook" 0
else
    assert "settings.json has autonomy_gate.sh hook" 1
fi

# --- 2.38 Enhanced skills read workspace.json ---
SKILLS_WITH_WORKSPACE=0
for skill_dir in "$RHINO_DIR/skills"/*/ "$RHINO_DIR/skills/_internal"/*/; do
    [[ ! -d "$skill_dir" ]] && continue
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    if grep -q "workspace.json\|autonomy" "$skill_file" 2>/dev/null; then
        SKILLS_WITH_WORKSPACE=$((SKILLS_WITH_WORKSPACE + 1))
    fi
done
if [[ "$SKILLS_WITH_WORKSPACE" -ge 8 ]]; then
    assert ">=8 skills read workspace/autonomy (found $SKILLS_WITH_WORKSPACE)" 0
else
    assert ">=8 skills read workspace/autonomy (found $SKILLS_WITH_WORKSPACE)" 1
fi

# --- 2.39 Enhanced skills have brain read/write ---
SKILLS_WITH_BRAIN=0
for skill in build plan review research go; do
    skill_file="$RHINO_DIR/skills/$skill/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    if grep -q "brains/" "$skill_file" 2>/dev/null; then
        SKILLS_WITH_BRAIN=$((SKILLS_WITH_BRAIN + 1))
    fi
done
for skill in strategy experiment eval design sweep scout meta; do
    skill_file="$RHINO_DIR/skills/_internal/$skill/SKILL.md"
    [[ -f "$skill_file" ]] || continue
    if grep -q "brains/" "$skill_file" 2>/dev/null; then
        SKILLS_WITH_BRAIN=$((SKILLS_WITH_BRAIN + 1))
    fi
done
if [[ "$SKILLS_WITH_BRAIN" -ge 7 ]]; then
    assert ">=7 core skills read/write brain files (found $SKILLS_WITH_BRAIN)" 0
else
    assert ">=7 core skills read/write brain files (found $SKILLS_WITH_BRAIN)" 1
fi

# --- 2.40 Session context reads workspace ---
if grep -q "workspace.json\|ws_autonomy\|WORKSPACE_FILE" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "session_context.sh reads workspace.json" 0
else
    assert "session_context.sh reads workspace.json" 1
fi

# --- 2.41 CLAUDE.md template references skills (not CLI commands) ---
if grep -q "/strategy\|/build\|/eval\|/setup" "$RHINO_DIR/config/CLAUDE.md" 2>/dev/null; then
    assert "CLAUDE.md template references skills" 0
else
    assert "CLAUDE.md template references skills" 1
fi

# --- 2.42 install.sh is idempotent (dry-run works) ---
INSTALL_DRY=$("$RHINO_DIR/install.sh" --check 2>&1 || true)
if echo "$INSTALL_DRY" | grep -q "dry-run\|skip\|already exists"; then
    assert "install.sh --check runs without errors" 0
else
    assert "install.sh --check runs without errors" 1
fi

tier_end
fi

# ============================================================
# TIER 3: CANARY — Known inputs → known outputs.
# These detect drift. If any canary fails, the scoring system
# is producing different results than expected.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "3" ]]; then
tier_start "3: Canary"

# --- 3.1 Scoring canary: empty project ---
# An empty directory should score 50/100 on structure and hygiene (no SRC_DIR)
EMPTY_DIR="$TMPDIR_TEST/empty-project"
mkdir -p "$EMPTY_DIR"
EMPTY_SCORE=$("$RHINO_DIR/bin/score.sh" "$EMPTY_DIR" --json --force 2>/dev/null || true)
if echo "$EMPTY_SCORE" | jq '.' >/dev/null 2>&1; then
    E_STRUCT=$(echo "$EMPTY_SCORE" | jq '.structure')
    E_HYGIENE=$(echo "$EMPTY_SCORE" | jq '.hygiene')
    # Empty project: no src dir → structure=50, hygiene=50
    assert_equals "canary: empty project structure=50" "$E_STRUCT" "50"
    assert_equals "canary: empty project hygiene=50" "$E_HYGIENE" "50"
else
    assert "canary: empty project produces valid JSON" 1
fi

# --- 3.2 Scoring canary: project with known issues ---
DIRTY_DIR="$TMPDIR_TEST/dirty-project"
mkdir -p "$DIRTY_DIR/src"
# package.json makes it detect as node project
echo '{"name":"test","scripts":{}}' > "$DIRTY_DIR/package.json"
# Create files with known hygiene issues
cat > "$DIRTY_DIR/src/index.ts" << 'TSEOF'
const x: any = "hello";
const y: any = 42;
const z: any = true;
const a: any = null;
const b: any = undefined;
const c: any = {};
console.log(x);
console.log(y);
console.log(z);
console.log(a);
console.log(b);
console.log(c);
// TODO: fix this
// FIXME: and this
// HACK: also this
// TODO: one more
// TODO: another
// TODO: yet another
TSEOF

DIRTY_SCORE=$("$RHINO_DIR/bin/score.sh" "$DIRTY_DIR" --json --force 2>/dev/null || true)
if echo "$DIRTY_SCORE" | jq '.' >/dev/null 2>&1; then
    D_HYGIENE=$(echo "$DIRTY_SCORE" | jq '.hygiene')
    # 6 any types (> 5 threshold = -10), 6 console.logs (> 5 = -5), 6 TODOs (> 5 = -5)
    # Score: 100 - 10 - 5 - 5 = 80
    assert_equals "canary: dirty project hygiene=80" "$D_HYGIENE" "80"
else
    assert "canary: dirty project produces valid JSON" 1
fi

# --- 3.3 Scoring canary: clean project ---
CLEAN_DIR="$TMPDIR_TEST/clean-project"
mkdir -p "$CLEAN_DIR/src"
echo '{"name":"test","scripts":{}}' > "$CLEAN_DIR/package.json"
cat > "$CLEAN_DIR/src/index.ts" << 'TSEOF'
const greeting: string = "hello";
export function greet(): string {
    return greeting;
}
TSEOF

CLEAN_SCORE=$("$RHINO_DIR/bin/score.sh" "$CLEAN_DIR" --json --force 2>/dev/null || true)
if echo "$CLEAN_SCORE" | jq '.' >/dev/null 2>&1; then
    C_HYGIENE=$(echo "$CLEAN_SCORE" | jq '.hygiene')
    # No issues → hygiene should be 100
    assert_equals "canary: clean project hygiene=100" "$C_HYGIENE" "100"
else
    assert "canary: clean project produces valid JSON" 1
fi

# --- 3.4 Config canary: all stage ceilings readable ---
for stage in mvp early growth mature; do
    CEIL=$(bash -c "
        source '$RHINO_DIR/bin/lib/config.sh'
        echo \$(cfg integrity.stage_ceilings.${stage}.score MISSING)
    " 2>/dev/null)
    # These are arrays stored as "[30, 65]" — cfg reads them as the raw value
    if [[ "$CEIL" != "MISSING" ]]; then
        assert "canary: stage ceiling $stage.score readable" 0
    else
        assert "canary: stage ceiling $stage.score readable" 1
    fi
done

# --- 3.5 Taste rubric canary: dimension count ---
# taste.mjs should score exactly 11 dimensions (9 original + layout_coherence + information_architecture)
DIM_COUNT=$(grep -c '"score": <1-5>' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null || echo "0")
assert_equals "canary: taste rubric has 11 scored dimensions" "$DIM_COUNT" "11"

# --- 3.5b Taste rubric coverage canary: structural dimensions exist ---
# The rubric must cover STRUCTURAL quality (layout, IA), not just experiential feel.
# This test exists because meta failed to catch that taste was blind to layout/IA for weeks.
# If you're tempted to remove these checks, ask: "what real product problem would I miss?"
RUBRIC_TEXT=$(cat "$RHINO_DIR/bin/taste.mjs" 2>/dev/null)
assert_contains "canary: taste rubric covers layout coherence" "$RUBRIC_TEXT" "LAYOUT_COHERENCE"
assert_contains "canary: taste rubric covers information architecture" "$RUBRIC_TEXT" "INFORMATION_ARCHITECTURE"
# Gate dimensions must appear BEFORE experiential dimensions (forces evaluator to check structure first)
GATE_POS=$(echo "$RUBRIC_TEXT" | grep -n "STRUCTURAL AUDIT" | head -1 | cut -d: -f1)
EXP_POS=$(echo "$RUBRIC_TEXT" | grep -n "Experiential Dimensions" | head -1 | cut -d: -f1)
if [[ -n "$GATE_POS" && -n "$EXP_POS" && "$GATE_POS" -lt "$EXP_POS" ]]; then
    assert "canary: structural audit comes before experiential dimensions" 0
else
    assert "canary: structural audit comes before experiential dimensions" 1 "gate=$GATE_POS exp=$EXP_POS"
fi
# Gate enforcement exists in code (not just prompt)
assert_contains "canary: taste.mjs enforces structural gate in code" "$RUBRIC_TEXT" "STRUCTURAL_GATE"

# --- 3.6 Score history format canary ---
# If history file exists, verify TSV format
HIST="$RHINO_DIR/.claude/scores/history.tsv"
if [[ -f "$HIST" ]]; then
    HEADER=$(head -1 "$HIST")
    assert_contains "canary: score history TSV has correct header" "$HEADER" "timestamp"
    assert_contains "canary: score history TSV has build column" "$HEADER" "build"
    assert_contains "canary: score history TSV has structure column" "$HEADER" "structure"
    assert_contains "canary: score history TSV has hygiene column" "$HEADER" "hygiene"
else
    # No history yet is fine — it's created on first run
    assert "canary: score history (skipped — no history yet)" 0
fi

# --- 3.7 Integrity detector canary: inflation detection threshold ---
# Verify the max_single_commit_delta value matches what score.sh reads
SCORE_READS_DELTA=$(grep "max_single_commit_delta\|max_delta" "$RHINO_DIR/bin/score.sh" | grep "cfg" | head -1)
if echo "$SCORE_READS_DELTA" | grep -q "integrity.max_single_commit_delta"; then
    assert "canary: score.sh reads integrity.max_single_commit_delta from config" 0
else
    assert "canary: score.sh reads integrity.max_single_commit_delta from config" 1
fi

# --- 3.8 Brain system canary: all agents have cold-start bias_awareness ---
for agent in scout strategist builder design-engineer sweep meta; do
    BIAS=$(bash -c "
        STATE_DIR=/tmp/rhino-test-state
        RHINO_DIR='$RHINO_DIR'
        source '$RHINO_DIR/bin/lib/config.sh'
        source '$RHINO_DIR/bin/lib/brains.sh'
        _brain_bias '$agent'
    " 2>/dev/null)
    if [[ -n "$BIAS" ]]; then
        assert "canary: $agent has cold-start bias_awareness" 0
    else
        assert "canary: $agent has cold-start bias_awareness" 1 "empty"
    fi
done

# --- 3.9 Scoring regression: dirty project triggers COSMETIC-ONLY warning ---
# A project with ONLY hygiene improvements (no build/structure change) should warn
COSMETIC_DIR="$TMPDIR_TEST/cosmetic-project"
mkdir -p "$COSMETIC_DIR/src"
echo "console.log('hello')" > "$COSMETIC_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$COSMETIC_DIR/package.json"
# Create history where only hygiene changed
mkdir -p "$COSMETIC_DIR/.claude/experiments"
printf "timestamp\tscore\tbuild\tstructure\thygiene\n2026-01-01\t60\t50\t50\t60\n2026-01-02\t65\t50\t50\t80\n" > "$COSMETIC_DIR/.claude/experiments/history.tsv"
COSMETIC_OUT=$("$RHINO_DIR/bin/score.sh" "$COSMETIC_DIR" --json --force 2>/dev/null || true)
if echo "$COSMETIC_OUT" | jq -e '.integrity_warnings' >/dev/null 2>&1; then
    assert "canary: score.sh emits integrity_warnings array in JSON" 0
else
    assert "canary: score.sh emits integrity_warnings array in JSON" 1 "missing integrity_warnings field"
fi

# --- 3.10 Scoring regression: score is bounded 0-100, never negative ---
# Score an empty dir and a minimal dir — both must be 0-100
for test_case in "$TMPDIR_TEST/empty-project" "$COSMETIC_DIR"; do
    tc_name=$(basename "$test_case")
    tc_score=$("$RHINO_DIR/bin/score.sh" "$test_case" --quiet --force 2>/dev/null || echo "-1")
    tc_score=$(echo "$tc_score" | tr -d '[:space:]')
    if [[ "$tc_score" =~ ^[0-9]+$ ]] && [[ "$tc_score" -ge 0 ]] && [[ "$tc_score" -le 100 ]]; then
        assert "canary: $tc_name score bounded 0-100 (got $tc_score)" 0
    else
        assert "canary: $tc_name score bounded 0-100" 1 "got: $tc_score"
    fi
done

# --- 3.11 Config canary: cfg() returns correct types for all integrity keys ---
INTEGRITY_KEYS="integrity.max_single_commit_delta integrity.plateau_experiments integrity.cosmetic_only_warning"
for key in $INTEGRITY_KEYS; do
    val=$(bash -c "
        RHINO_DIR='$RHINO_DIR'
        source '$RHINO_DIR/bin/lib/config.sh'
        cfg $key 'MISSING'
    " 2>/dev/null)
    if [[ "$val" != "MISSING" && -n "$val" ]]; then
        assert "canary: cfg($key) returns value ($val)" 0
    else
        assert "canary: cfg($key) returns value" 1 "got MISSING or empty"
    fi
done

# --- 3.12 Canary: grade history is append-only valid JSONL ---
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    BAD_LINES=0
    LINE_NUM=0
    while IFS= read -r line; do
        LINE_NUM=$((LINE_NUM + 1))
        [[ -z "$line" ]] && continue
        if ! echo "$line" | jq -e '.' >/dev/null 2>&1; then
            BAD_LINES=$((BAD_LINES + 1))
        fi
    done < "$CLAUDE_HOME/knowledge/meta/grades.jsonl"
    if [[ "$BAD_LINES" -eq 0 ]]; then
        assert "canary: grades.jsonl is valid JSONL ($LINE_NUM lines)" 0
    else
        assert "canary: grades.jsonl is valid JSONL" 1 "$BAD_LINES bad lines out of $LINE_NUM"
    fi
fi

# --- 3.13 Canary: landscape.json is valid JSON with required structure ---
if [[ -f "$CLAUDE_HOME/knowledge/landscape.json" ]]; then
    if jq -e '.positions | length' "$CLAUDE_HOME/knowledge/landscape.json" >/dev/null 2>&1; then
        lj_count=$(jq '.positions | length' "$CLAUDE_HOME/knowledge/landscape.json")
        # Each position must have id, position, confidence
        lj_valid=0
        lj_invalid=0
        for i in $(seq 0 $((lj_count - 1))); do
            has_id=$(jq -r ".positions[$i].id // empty" "$CLAUDE_HOME/knowledge/landscape.json" 2>/dev/null)
            has_conf=$(jq -r ".positions[$i].confidence // empty" "$CLAUDE_HOME/knowledge/landscape.json" 2>/dev/null)
            if [[ -n "$has_id" && -n "$has_conf" ]]; then
                lj_valid=$((lj_valid + 1))
            else
                lj_invalid=$((lj_invalid + 1))
            fi
        done
        if [[ "$lj_invalid" -eq 0 ]]; then
            assert "canary: landscape.json positions all have id+confidence ($lj_valid)" 0
        else
            assert "canary: landscape.json positions all have id+confidence" 1 "$lj_invalid invalid of $lj_count"
        fi
    else
        assert "canary: landscape.json has positions array" 1 "invalid JSON or missing .positions"
    fi
fi

# --- 3.14 Canary: portfolio.json structure ---
if [[ -f "$CLAUDE_HOME/knowledge/portfolio.json" ]]; then
    if jq -e '.projects' "$CLAUDE_HOME/knowledge/portfolio.json" >/dev/null 2>&1; then
        pj_count=$(jq '.projects | length' "$CLAUDE_HOME/knowledge/portfolio.json")
        # Each project should have call (BUY/HOLD/SELL) and path
        pj_valid=0
        for i in $(seq 0 $((pj_count - 1))); do
            has_call=$(jq -r ".projects[$i].call // empty" "$CLAUDE_HOME/knowledge/portfolio.json" 2>/dev/null)
            has_path=$(jq -r ".projects[$i].path // empty" "$CLAUDE_HOME/knowledge/portfolio.json" 2>/dev/null)
            [[ -n "$has_call" && -n "$has_path" ]] && pj_valid=$((pj_valid + 1))
        done
        if [[ "$pj_valid" -eq "$pj_count" ]]; then
            assert "canary: portfolio.json projects all have call+path ($pj_count)" 0
        else
            assert "canary: portfolio.json projects all have call+path" 1 "$pj_valid/$pj_count valid"
        fi
    fi
fi

tier_end
fi

# ============================================================
# TIER 4: CAPABILITY — Can agents actually do their jobs?
# Measures real outputs from real agent runs. These numbers
# should be LOW. They measure system effectiveness, not syntax.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "4" ]]; then
tier_start "4: Capability"

# --- 4.1 Agent artifact production ---
# Each agent MUST write its required output files. Measure what % actually did.
AGENT_ARTIFACTS_EXPECTED=0
AGENT_ARTIFACTS_FOUND=0

# Sweep → must write sweep-latest.md
AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
if [[ -f "$CLAUDE_HOME/state/sweep-latest.md" ]]; then
    sweep_age=$(( ($(date +%s) - $(stat -f %m "$CLAUDE_HOME/state/sweep-latest.md" 2>/dev/null || stat -c %Y "$CLAUDE_HOME/state/sweep-latest.md" 2>/dev/null || echo 0)) / 86400 ))
    if [[ "$sweep_age" -lt 7 ]]; then
        AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
        assert "sweep produced sweep-latest.md (<7d old)" 0
    else
        assert "sweep produced sweep-latest.md (<7d old)" 1 "${sweep_age}d old"
    fi
else
    assert "sweep produced sweep-latest.md (<7d old)" 1 "missing"
fi

# Strategist → must write portfolio.json
AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
if [[ -f "$CLAUDE_HOME/knowledge/portfolio.json" ]] && jq -e '.projects' "$CLAUDE_HOME/knowledge/portfolio.json" >/dev/null 2>&1; then
    AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
    assert "strategist produced portfolio.json with projects" 0
else
    assert "strategist produced portfolio.json with projects" 1
fi

# Strategist → must write a plan
AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
plan_found=false
for plan_dir in "$PROJECTS_DIR"/*/".claude/plans" "$CLAUDE_HOME/plans"; do
    if compgen -G "$plan_dir/active-plan.md" > /dev/null 2>&1; then
        plan_found=true
        break
    fi
done
if $plan_found; then
    AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
    assert "strategist produced active-plan.md somewhere" 0
else
    assert "strategist produced active-plan.md somewhere" 1
fi

# Scout → must write landscape.json
AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
if [[ -f "$CLAUDE_HOME/knowledge/landscape.json" ]] && jq -e '.positions' "$CLAUDE_HOME/knowledge/landscape.json" >/dev/null 2>&1; then
    pos_count=$(jq '.positions | length' "$CLAUDE_HOME/knowledge/landscape.json" 2>/dev/null)
    if [[ "$pos_count" -ge 3 ]]; then
        AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
        assert "scout produced landscape.json with ≥3 positions" 0
    else
        assert "scout produced landscape.json with ≥3 positions" 1 "only $pos_count"
    fi
else
    assert "scout produced landscape.json with ≥3 positions" 1
fi

# Meta → must write grades.jsonl
AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    grade_count=$(wc -l < "$CLAUDE_HOME/knowledge/meta/grades.jsonl" | tr -d ' ')
    if [[ "$grade_count" -ge 1 ]]; then
        AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
        assert "meta produced grades.jsonl ($grade_count entries)" 0
    else
        assert "meta produced grades.jsonl ($grade_count entries)" 1
    fi
else
    assert "meta produced grades.jsonl" 1
fi

# All 6 agents → must have written their brain files
for agent in builder scout strategist design-engineer sweep meta; do
    AGENT_ARTIFACTS_EXPECTED=$((AGENT_ARTIFACTS_EXPECTED + 1))
    brain="$CLAUDE_HOME/state/brains/${agent}.json"
    if [[ -f "$brain" ]]; then
        has_move=$(jq -r '.next_move // empty' "$brain" 2>/dev/null)
        if [[ -n "$has_move" ]]; then
            AGENT_ARTIFACTS_FOUND=$((AGENT_ARTIFACTS_FOUND + 1))
            assert "$agent brain has next_move" 0
        else
            assert "$agent brain has next_move" 1 "empty next_move"
        fi
    else
        assert "$agent brain has next_move" 1 "no brain file"
    fi
done

# --- 4.2 Experiment effectiveness ---
# Across all projects: what % of experiments were kept?
TOTAL_EXPERIMENTS=0
TOTAL_KEPT=0
TOTAL_DISCARDED=0

for tsv in "$PROJECTS_DIR"/*/.claude/experiments/*.tsv "$CLAUDE_HOME/experiments/"*.tsv; do
    [[ -f "$tsv" ]] || continue
    kept=$(grep -c 'keep' "$tsv" 2>/dev/null || echo 0)
    kept=${kept##*$'\n'}  # take last line if multi-line
    discarded=$(grep -c 'discard' "$tsv" 2>/dev/null || echo 0)
    discarded=${discarded##*$'\n'}
    TOTAL_KEPT=$((TOTAL_KEPT + kept))
    TOTAL_DISCARDED=$((TOTAL_DISCARDED + discarded))
    TOTAL_EXPERIMENTS=$((TOTAL_EXPERIMENTS + kept + discarded))
done

if [[ "$TOTAL_EXPERIMENTS" -gt 0 ]]; then
    keep_rate=$((TOTAL_KEPT * 100 / TOTAL_EXPERIMENTS))
    assert_msg="experiment keep rate: ${keep_rate}% ($TOTAL_KEPT/$TOTAL_EXPERIMENTS)"
    # Keep rate should be 30-70%. Below = bad hypotheses. Above = not being honest about discards.
    if [[ "$keep_rate" -ge 30 && "$keep_rate" -le 70 ]]; then
        assert "$assert_msg (healthy range 30-70%)" 0
    elif [[ "$keep_rate" -gt 70 ]]; then
        assert "$assert_msg — suspiciously high, are we honest about discards?" 1
    else
        assert "$assert_msg — too many failures, hypotheses are weak" 1
    fi
else
    assert "experiment keep rate (no experiments run yet)" 1 "0 experiments total"
fi

# --- 4.3 Agent brain freshness ---
# Are agents updating their brain files?
FRESH_BRAINS=0
for brain in "$CLAUDE_HOME/state/brains"/*.json; do
    [[ -f "$brain" ]] || continue
    brain_age=$(( ($(date +%s) - $(stat -f %m "$brain" 2>/dev/null || stat -c %Y "$brain" 2>/dev/null || echo 0)) / 86400 ))
    [[ "$brain_age" -lt 14 ]] && FRESH_BRAINS=$((FRESH_BRAINS + 1))
done
if [[ "$FRESH_BRAINS" -ge 3 ]]; then
    assert "≥3 agent brains updated in last 14 days" 0
else
    assert "≥3 agent brains updated in last 14 days" 1 "only $FRESH_BRAINS"
fi

# --- 4.4 Meta actually improving agents ---
# Meta should have applied fixes that improved grades
META_CYCLES=0
META_IMPROVEMENTS=0
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    META_CYCLES=$(wc -l < "$CLAUDE_HOME/knowledge/meta/grades.jsonl" | tr -d ' ')
    META_IMPROVEMENTS=$(grep -c 'improved' "$CLAUDE_HOME/knowledge/meta/grades.jsonl" 2>/dev/null || echo "0")
fi

# Need ≥3 meta cycles
if [[ "$META_CYCLES" -ge 3 ]]; then
    assert "meta has run ≥3 cycles" 0
else
    assert "meta has run ≥3 cycles" 1 "only $META_CYCLES"
fi

# At least 1 confirmed improvement
if [[ "$META_IMPROVEMENTS" -ge 1 ]]; then
    assert "meta has ≥1 confirmed improvement" 0
else
    assert "meta has ≥1 confirmed improvement" 1 "0 improvements tracked"
fi

# --- 4.5 Eval system producing actionable gaps ---
EVAL_COUNT=0
GAP_COUNT=0
for history_file in "$PROJECTS_DIR"/*/.claude/evals/reports/history.jsonl "$PROJECTS_DIR"/*/docs/evals/reports/history.jsonl; do
    [[ -f "$history_file" ]] || continue
    entries=$(wc -l < "$history_file" | tr -d ' ')
    EVAL_COUNT=$((EVAL_COUNT + entries))
    gaps=$(jq -r '.ceiling_gaps // .top_gaps // [] | length' "$history_file" 2>/dev/null | awk '{s+=$1} END{print s+0}')
    GAP_COUNT=$((GAP_COUNT + gaps))
done

if [[ "$EVAL_COUNT" -ge 2 ]]; then
    assert "eval system: ≥2 evals run across projects" 0
else
    assert "eval system: ≥2 evals run across projects" 1 "only $EVAL_COUNT"
fi

# Gaps should feed forward into plans
if [[ "$GAP_COUNT" -ge 3 ]]; then
    assert "eval system: ≥3 ceiling gaps identified" 0
else
    assert "eval system: ≥3 ceiling gaps identified" 1 "only $GAP_COUNT"
fi

# --- 4.6 Agent next_moves actionable ---
# At least 3 agents should have non-empty next_moves
ACTIONABLE=0
for brain in "$CLAUDE_HOME/state/brains"/*.json; do
    [[ -f "$brain" ]] || continue
    nm=$(jq -r '.next_move // empty' "$brain" 2>/dev/null)
    [[ -n "$nm" && ${#nm} -gt 10 ]] && ACTIONABLE=$((ACTIONABLE + 1))
done
if [[ "$ACTIONABLE" -ge 3 ]]; then
    assert "≥3 agents have actionable next_moves" 0
else
    assert "≥3 agents have actionable next_moves" 1 "only $ACTIONABLE"
fi

# --- 4.7 Taste eval producing real feedback ---
TASTE_REPORTS=0
for taste_report in "$PROJECTS_DIR"/*/.claude/evals/reports/taste-*.json; do
    [[ -f "$taste_report" ]] || continue
    TASTE_REPORTS=$((TASTE_REPORTS + 1))
done
if [[ "$TASTE_REPORTS" -ge 1 ]]; then
    assert "taste eval: ≥1 visual eval run" 0
else
    assert "taste eval: ≥1 visual eval run" 1 "never run"
fi

# Taste should produce a weakest_dimension (structured handoff to builder)
TASTE_HANDOFF=false
for taste_report in "$PROJECTS_DIR"/*/.claude/evals/reports/taste-*.json; do
    [[ -f "$taste_report" ]] || continue
    wd=$(jq -r '.weakest_dimension // empty' "$taste_report" 2>/dev/null)
    [[ -n "$wd" ]] && TASTE_HANDOFF=true && break
done
if $TASTE_HANDOFF; then
    assert "taste eval: produces weakest_dimension handoff" 0
else
    assert "taste eval: produces weakest_dimension handoff" 1
fi

# --- 4.8 Meta grades have test_before/test_after (eval-driven, not vibes) ---
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    RECENT_GRADES=$(tail -3 "$CLAUDE_HOME/knowledge/meta/grades.jsonl")
    GRADES_WITH_TESTS=0
    GRADES_CHECKED=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        GRADES_CHECKED=$((GRADES_CHECKED + 1))
        has_before=$(echo "$line" | jq -r '.test_before.pct // empty' 2>/dev/null)
        [[ -n "$has_before" ]] && GRADES_WITH_TESTS=$((GRADES_WITH_TESTS + 1))
    done <<< "$RECENT_GRADES"
    if [[ "$GRADES_CHECKED" -gt 0 && "$GRADES_WITH_TESTS" -eq "$GRADES_CHECKED" ]]; then
        assert "meta: recent grades have test_before numbers ($GRADES_WITH_TESTS/$GRADES_CHECKED)" 0
    else
        assert "meta: recent grades have test_before numbers" 1 "$GRADES_WITH_TESTS/$GRADES_CHECKED have test data"
    fi
fi

# --- 4.9 Meta stances are machine-verifiable (have verify_cmd) ---
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    RECENT_STANCES=$(tail -3 "$CLAUDE_HOME/knowledge/meta/grades.jsonl")
    VERIFIABLE=0
    STANCE_COUNT=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        has_stance=$(echo "$line" | jq -r '.stance.verify_cmd // empty' 2>/dev/null)
        [[ -n "$has_stance" ]] && VERIFIABLE=$((VERIFIABLE + 1))
        STANCE_COUNT=$((STANCE_COUNT + 1))
    done <<< "$RECENT_STANCES"
    if [[ "$STANCE_COUNT" -gt 0 && "$VERIFIABLE" -eq "$STANCE_COUNT" ]]; then
        assert "meta: recent stances have verify_cmd ($VERIFIABLE/$STANCE_COUNT)" 0
    else
        assert "meta: recent stances have verify_cmd" 1 "$VERIFIABLE/$STANCE_COUNT verifiable"
    fi
fi

# --- 4.10 Experiment learnings are growing (not empty, not stale) ---
LEARNINGS_FILE="$CLAUDE_HOME/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS_FILE" ]]; then
    LEARNINGS_LINES=$(wc -l < "$LEARNINGS_FILE" | tr -d ' ')
    LEARNINGS_SECTIONS=$(grep -c "^##\|^###" "$LEARNINGS_FILE" 2>/dev/null || echo 0)
    if [[ "$LEARNINGS_LINES" -ge 10 && "$LEARNINGS_SECTIONS" -ge 2 ]]; then
        assert "experiment learnings: substantive (${LEARNINGS_LINES}L, ${LEARNINGS_SECTIONS} sections)" 0
    else
        assert "experiment learnings: substantive" 1 "${LEARNINGS_LINES} lines, ${LEARNINGS_SECTIONS} sections — too thin"
    fi
else
    assert "experiment learnings: substantive" 1 "file missing"
fi

# --- 4.11 Agent brains have lessons (learning from experience, not just next_move) ---
BRAINS_WITH_LESSONS=0
BRAINS_TOTAL=0
for brain in "$CLAUDE_HOME/state/brains"/*.json; do
    [[ -f "$brain" ]] || continue
    BRAINS_TOTAL=$((BRAINS_TOTAL + 1))
    lesson_count=$(jq -r '.memory.lessons // [] | length' "$brain" 2>/dev/null || echo 0)
    [[ "$lesson_count" -ge 1 ]] && BRAINS_WITH_LESSONS=$((BRAINS_WITH_LESSONS + 1))
done
if [[ "$BRAINS_TOTAL" -gt 0 ]]; then
    if [[ "$BRAINS_WITH_LESSONS" -ge 3 ]]; then
        assert "≥3 agent brains have accumulated lessons ($BRAINS_WITH_LESSONS/$BRAINS_TOTAL)" 0
    else
        assert "≥3 agent brains have accumulated lessons" 1 "only $BRAINS_WITH_LESSONS/$BRAINS_TOTAL"
    fi
fi

# --- 4.12 Sweep identifies real problems (not all GREEN) ---
if [[ -f "$CLAUDE_HOME/state/sweep-latest.md" ]]; then
    has_yellow=$(grep -ci "YELLOW\|RED" "$CLAUDE_HOME/state/sweep-latest.md" 2>/dev/null || echo 0)
    has_green=$(grep -ci "GREEN" "$CLAUDE_HOME/state/sweep-latest.md" 2>/dev/null || echo 0)
    total_classifications=$((has_yellow + has_green))
    if [[ "$total_classifications" -ge 2 ]]; then
        assert "sweep: classifies with multiple tiers ($has_green GREEN, $has_yellow YELLOW/RED)" 0
    else
        assert "sweep: classifies with multiple tiers" 1 "only $total_classifications classifications found"
    fi
fi

# --- 4.13 Strategy produces causal diagnosis (not just lowest-score-wins) ---
for plan in "$PROJECTS_DIR"/*/.claude/plans/active-plan.md "$CLAUDE_HOME/plans/active-plan.md"; do
    [[ -f "$plan" ]] || continue
    # A good plan should have: tasks/steps, AND a rationale/diagnosis section
    has_tasks=$(grep -ciE '^\s*-\s*\[|^##.*task|^##.*step|^##.*sprint' "$plan" 2>/dev/null || echo 0)
    has_rationale=$(grep -ciE 'because|bottleneck|diagnosis|why|root cause|broken' "$plan" 2>/dev/null || echo 0)
    if [[ "$has_tasks" -ge 2 && "$has_rationale" -ge 1 ]]; then
        assert "strategy: active plan has tasks + rationale" 0
    else
        assert "strategy: active plan has tasks + rationale" 1 "tasks=$has_tasks rationale=$has_rationale"
    fi
    break  # only check first found plan
done

# --- 4.14 HARD: Scout positions have diverse confidence levels ---
# Good intelligence has strong, moderate, and speculative — not all one level
if [[ -f "$CLAUDE_HOME/knowledge/landscape.json" ]] && jq -e '.positions' "$CLAUDE_HOME/knowledge/landscape.json" >/dev/null 2>&1; then
    CONF_LEVELS=$(jq -r '.positions[].confidence' "$CLAUDE_HOME/knowledge/landscape.json" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [[ "$CONF_LEVELS" -ge 3 ]]; then
        assert "HARD: scout positions have ≥3 confidence levels ($CONF_LEVELS)" 0
    else
        assert "HARD: scout positions have ≥3 confidence levels" 1 "only $CONF_LEVELS distinct levels"
    fi
fi

# --- 4.15 HARD: Meta has applied fixes to ≥3 different files ---
# A meta that only fixes one file isn't learning broadly
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    UNIQUE_FIX_FILES=$(jq -r '.fix_applied.file // empty' "$CLAUDE_HOME/knowledge/meta/grades.jsonl" 2>/dev/null | sort -u | grep -c '.' || echo 0)
    if [[ "$UNIQUE_FIX_FILES" -ge 3 ]]; then
        assert "HARD: meta applied fixes to ≥3 different files ($UNIQUE_FIX_FILES)" 0
    else
        assert "HARD: meta applied fixes to ≥3 different files" 1 "only $UNIQUE_FIX_FILES"
    fi
fi

# --- 4.16 HARD: Meta has at least 1 failed/reverted fix (honest about failures) ---
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    HAS_FAILURE=$(grep -ciE 'reverted|dropped|no measurable|untested|failed' "$CLAUDE_HOME/knowledge/meta/grades.jsonl" 2>/dev/null || echo 0)
    if [[ "$HAS_FAILURE" -ge 1 ]]; then
        assert "HARD: meta has ≥1 honest failure/revert in history" 0
    else
        assert "HARD: meta has ≥1 honest failure/revert in history" 1 "0 failures across all cycles = suspiciously perfect"
    fi
fi

# --- 4.17 HARD: Experiment learnings cite specific evidence ---
# Good learnings have concrete numbers or file references, not vague claims
LEARNINGS_FILE="$CLAUDE_HOME/knowledge/experiment-learnings.md"
if [[ -f "$LEARNINGS_FILE" ]]; then
    EVIDENCE_LINES=$(grep -cE '[0-9]+\.[0-9]+|[0-9]+%|\+[0-9]+|→|from [0-9]+ to [0-9]+' "$LEARNINGS_FILE" 2>/dev/null || echo 0)
    TOTAL_LINES=$(wc -l < "$LEARNINGS_FILE" | tr -d ' ')
    if [[ "$TOTAL_LINES" -gt 0 ]]; then
        EVIDENCE_RATIO=$((EVIDENCE_LINES * 100 / TOTAL_LINES))
        if [[ "$EVIDENCE_RATIO" -ge 20 ]]; then
            assert "HARD: experiment learnings have concrete evidence (${EVIDENCE_RATIO}% of lines)" 0
        else
            assert "HARD: experiment learnings have concrete evidence" 1 "only ${EVIDENCE_RATIO}% of lines have numbers/data"
        fi
    fi
fi

# --- 4.18 HARD: Agent brains have DIFFERENT next_moves (not parroting) ---
# Agents should have independent, distinct plans
NEXT_MOVES=""
for brain in "$CLAUDE_HOME/state/brains"/*.json; do
    [[ -f "$brain" ]] || continue
    nm=$(jq -r '.next_move.action // .next_move // empty' "$brain" 2>/dev/null | head -1)
    [[ -n "$nm" ]] && NEXT_MOVES="$NEXT_MOVES|$nm"
done
UNIQUE_MOVES=$(echo "$NEXT_MOVES" | tr '|' '\n' | grep -c '.' || echo 0)
# Check they're actually different by looking at first 30 chars
DISTINCT_PREFIXES=$(echo "$NEXT_MOVES" | tr '|' '\n' | grep '.' | cut -c1-30 | sort -u | wc -l | tr -d ' ')
if [[ "$UNIQUE_MOVES" -ge 4 && "$DISTINCT_PREFIXES" -ge 4 ]]; then
    assert "HARD: ≥4 agents have distinct next_moves ($DISTINCT_PREFIXES unique)" 0
else
    assert "HARD: ≥4 agents have distinct next_moves" 1 "$DISTINCT_PREFIXES distinct of $UNIQUE_MOVES total"
fi

# --- 4.19 HARD: Eval history shows score CHANGES (not all same score) ---
EVAL_SCORE_VARIANCE=false
for history_file in "$PROJECTS_DIR"/*/.claude/evals/reports/history.jsonl "$PROJECTS_DIR"/*/docs/evals/reports/history.jsonl; do
    [[ -f "$history_file" ]] || continue
    UNIQUE_SCORES=$(jq -r '.score // .overall // empty' "$history_file" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    [[ "$UNIQUE_SCORES" -ge 2 ]] && EVAL_SCORE_VARIANCE=true && break
done
if $EVAL_SCORE_VARIANCE; then
    assert "HARD: eval history shows score variance (not flat)" 0
else
    assert "HARD: eval history shows score variance (not flat)" 1 "all evals same score or <2 evals"
fi

# --- 4.20 HARD: Score history TSV has ≥5 entries with variance ---
SCORE_VARIANCE=false
for tsv in "$PROJECTS_DIR"/*/.claude/scores/history.tsv; do
    [[ -f "$tsv" ]] || continue
    ENTRY_COUNT=$(tail -n +2 "$tsv" | wc -l | tr -d ' ')
    if [[ "$ENTRY_COUNT" -ge 5 ]]; then
        UNIQUE_STRUCTURES=$(tail -n +2 "$tsv" | cut -f3 | sort -u | wc -l | tr -d ' ')
        [[ "$UNIQUE_STRUCTURES" -ge 2 ]] && SCORE_VARIANCE=true && break
    fi
done
if $SCORE_VARIANCE; then
    assert "HARD: score history has ≥5 entries with structural variance" 0
else
    assert "HARD: score history has ≥5 entries with structural variance" 1
fi

# --- 4.21 HARD: Experiments have both keeps AND discards ---
if [[ "$TOTAL_EXPERIMENTS" -gt 5 ]]; then
    if [[ "$TOTAL_DISCARDED" -ge 1 && "$TOTAL_KEPT" -ge 1 ]]; then
        assert "HARD: experiments have both keeps ($TOTAL_KEPT) and discards ($TOTAL_DISCARDED)" 0
    else
        assert "HARD: experiments have both keeps and discards" 1 "kept=$TOTAL_KEPT discarded=$TOTAL_DISCARDED"
    fi
fi

# --- 4.X Thinking system health ---
# Does the thinking infrastructure actually exist and produce output?

# thinking_nudge.sh is wired in settings.json
if grep -q "thinking_nudge" "$RHINO_DIR/config/settings.json" 2>/dev/null; then
    assert "thinking nudge wired in settings.json" 0
else
    assert "thinking nudge wired in settings.json" 1
fi

# check_predictions.sh is wired in settings.json
if grep -q "check_predictions" "$RHINO_DIR/config/settings.json" 2>/dev/null; then
    assert "prediction checker wired in settings.json" 0
else
    assert "prediction checker wired in settings.json" 1
fi

# rhino.yml has thinking config
if grep -q "thinking:" "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
    assert "rhino.yml has thinking config section" 0
else
    assert "rhino.yml has thinking config section" 1
fi

# CLAUDE.md template references thinking protocol
if grep -q "thinking.md\|How To Think\|Predict before" "$RHINO_DIR/config/CLAUDE.md" 2>/dev/null; then
    assert "CLAUDE.md template has thinking protocol" 0
else
    assert "CLAUDE.md template has thinking protocol" 1
fi

# Session context is opinionated (has recommendation engine)
if grep -q "recommends\|RECOMMENDATION\|opinionated" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "session_context.sh has recommendation engine" 0
else
    assert "session_context.sh has recommendation engine" 1
fi

# thinking-health.tsv tracking exists or will be created
if grep -q "thinking-health" "$RHINO_DIR/hooks/check_predictions.sh" 2>/dev/null; then
    assert "check_predictions.sh logs to thinking-health.tsv" 0
else
    assert "check_predictions.sh logs to thinking-health.tsv" 1
fi

# --- 4.x Learning health diagnostic tests ---

# meta.md has learning health diagnostic
if grep -q "learning_health\|Is the system learning" "$RHINO_DIR/programs/meta.md" 2>/dev/null; then
    assert "meta.md has learning health diagnostic" 0
else
    assert "meta.md has learning health diagnostic" 1
fi

# session_context.sh surfaces learning engine health
if grep -q "Learning Engine" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "session_context.sh surfaces learning engine health" 0
else
    assert "session_context.sh surfaces learning engine health" 1
fi

# check_predictions.sh output consumed by session_context
if grep -q "thinking-health.tsv" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    assert "session_context.sh consumes thinking-health.tsv from check_predictions" 0
else
    assert "session_context.sh consumes thinking-health.tsv from check_predictions" 1
fi

tier_end
fi

# ============================================================
# TIER 5: AUTONOMY — How close to zero-human product building?
# These measure the END GOAL. Most should fail right now.
# 100% here = rhino-os can build a profitable product alone.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "5" ]]; then
tier_start "5: Autonomy"

# --- 5.1 Full loop completion ---
# Has strategy → plan → build → score → eval ever completed end-to-end
# without human intervention? Check for evidence of the complete chain.
LOOP_COMPLETE=false

# Evidence: a plan exists AND experiments ran against it AND an eval ran after
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    has_plan=false
    has_experiments=false
    has_eval=false

    [[ -f "$project/.claude/plans/active-plan.md" ]] && has_plan=true
    compgen -G "$project/.claude/experiments/*.tsv" > /dev/null 2>&1 && has_experiments=true
    compgen -G "$project/.claude/evals/reports/history.jsonl" > /dev/null 2>&1 && has_eval=true
    compgen -G "$project/docs/evals/reports/history.jsonl" > /dev/null 2>&1 && has_eval=true

    if $has_plan && $has_experiments && $has_eval; then
        LOOP_COMPLETE=true
        break
    fi
done

if $LOOP_COMPLETE; then
    assert "full loop: plan → experiment → eval completed for ≥1 project" 0
else
    assert "full loop: plan → experiment → eval completed for ≥1 project" 1
fi

# --- 5.2 Score improvement without human ---
# Did experiments actually move scores up? (evidence of autonomous improvement)
AUTONOMOUS_IMPROVEMENT=false
for tsv in "$PROJECTS_DIR"/*/.claude/experiments/*.tsv; do
    [[ -f "$tsv" ]] || continue
    # Check if there's a positive delta on a kept experiment
    if grep -q 'keep' "$tsv" 2>/dev/null; then
        max_delta=$(grep 'keep' "$tsv" | awk -F'\t' '{gsub(/[^0-9.-]/,"",$3); if($3+0 > max) max=$3+0} END{print max+0}')
        if awk "BEGIN { exit !($max_delta > 0) }" 2>/dev/null; then
            AUTONOMOUS_IMPROVEMENT=true
            break
        fi
    fi
done
if $AUTONOMOUS_IMPROVEMENT; then
    assert "autonomous: experiments improved scores without human" 0
else
    assert "autonomous: experiments improved scores without human" 1
fi

# --- 5.3 Multi-sprint continuity ---
# Has the system run >1 sprint cycle? (strategy → build → eval → strategy again)
EVAL_ENTRIES=0
for history_file in "$PROJECTS_DIR"/*/.claude/evals/reports/history.jsonl "$PROJECTS_DIR"/*/docs/evals/reports/history.jsonl; do
    [[ -f "$history_file" ]] || continue
    entries=$(wc -l < "$history_file" | tr -d ' ')
    EVAL_ENTRIES=$((EVAL_ENTRIES + entries))
done
if [[ "$EVAL_ENTRIES" -ge 3 ]]; then
    assert "multi-sprint: ≥3 eval cycles completed" 0
else
    assert "multi-sprint: ≥3 eval cycles completed" 1 "only $EVAL_ENTRIES"
fi

# --- 5.4 Recovery without human ---
# Has meta detected and fixed a broken agent autonomously?
META_FIXES=0
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    META_FIXES=$(jq -r 'select(.fix_applied != null) | .fix_applied.file' "$CLAUDE_HOME/knowledge/meta/grades.jsonl" 2>/dev/null | wc -l | tr -d ' ')
fi
if [[ "$META_FIXES" -ge 2 ]]; then
    assert "self-heal: meta applied ≥2 fixes autonomously" 0
else
    assert "self-heal: meta applied ≥2 fixes autonomously" 1 "only $META_FIXES"
fi

# --- 5.5 Agent disagreement resolved by evidence ---
# Has at least one conflict been resolved via credibility (not human override)?
# Check that agent brains have been updated (evidence of agent loop running)
BRAIN_UPDATES=0
for brain_file in "$CLAUDE_HOME/state/brains/"*.json; do
    [[ -f "$brain_file" ]] || continue
    if jq -e '.next_move != null and .next_move != ""' "$brain_file" >/dev/null 2>&1; then
        BRAIN_UPDATES=$((BRAIN_UPDATES + 1))
    fi
done
if [[ "$BRAIN_UPDATES" -ge 2 ]]; then
    assert "evidence-based: ≥2 agent brains have next_move populated" 0
else
    assert "evidence-based: ≥2 agent brains have next_move populated" 1
fi

# --- 5.6 Taste score above MVP floor ---
# Has any project reached taste ≥2.5/5 (50/100)?
TASTE_ABOVE_FLOOR=false
for taste_report in "$PROJECTS_DIR"/*/.claude/evals/reports/taste-*.json; do
    [[ -f "$taste_report" ]] || continue
    score=$(jq -r '.score_100 // 0' "$taste_report" 2>/dev/null)
    if [[ "$score" -ge 50 ]]; then
        TASTE_ABOVE_FLOOR=true
        break
    fi
done
if $TASTE_ABOVE_FLOOR; then
    assert "product quality: taste ≥50/100 (MVP floor)" 0
else
    assert "product quality: taste ≥50/100 (MVP floor)" 1
fi

# --- 5.7 Distribution mechanism exists ---
# Does any project have sharing/OG/viral infrastructure?
DISTRIBUTION=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    src=""
    [[ -d "$project/src" ]] && src="$project/src"
    [[ -d "$project/apps/web/src" ]] && src="$project/apps/web/src"
    [[ -z "$src" ]] && continue

    og=$(grep -rn "og:title\|og:image\|twitter:card" --include="*.tsx" --include="*.ts" "$src" 2>/dev/null | wc -l | tr -d ' ')
    share=$(grep -rn "navigator.share\|ShareSheet\|share.*modal\|copy.*link\|clipboard" --include="*.tsx" --include="*.ts" "$src" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$og" -gt 0 && "$share" -gt 0 ]]; then
        DISTRIBUTION=true
        break
    fi
done
if $DISTRIBUTION; then
    assert "distribution: OG tags + share mechanism in ≥1 project" 0
else
    assert "distribution: OG tags + share mechanism in ≥1 project" 1
fi

# --- 5.8 Return mechanism exists ---
# Does any project have push notifications or return triggers?
RETURN_PULL=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    src=""
    [[ -d "$project/src" ]] && src="$project/src"
    [[ -d "$project/apps/web/src" ]] && src="$project/apps/web/src"
    [[ -z "$src" ]] && continue

    push=$(grep -rn "sendNotification\|pushNotification\|messaging().send\|web-push\|push.*permission\|Notification.requestPermission" --include="*.tsx" --include="*.ts" "$src" 2>/dev/null | wc -l | tr -d ' ')
    digest=$(grep -rn "digest\|since.*left\|while.*away\|activity.*summary" --include="*.tsx" --include="*.ts" "$src" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$push" -gt 0 || "$digest" -gt 0 ]]; then
        RETURN_PULL=true
        break
    fi
done
if $RETURN_PULL; then
    assert "retention: push notifications or return triggers exist" 0
else
    assert "retention: push notifications or return triggers exist" 1
fi

# --- 5.9 Real user signal ---
# Does any project have analytics, user tracking, or revenue?
REAL_SIGNAL=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    # Check for analytics integrations
    if grep -rq "posthog\|analytics\|gtag\|mixpanel\|vercel/analytics\|plausible" --include="*.ts" --include="*.tsx" --include="*.json" "$project" 2>/dev/null; then
        REAL_SIGNAL=true
        break
    fi
done
if $REAL_SIGNAL; then
    assert "real signal: analytics or tracking integrated in ≥1 project" 0
else
    assert "real signal: analytics or tracking integrated in ≥1 project" 1 "all scoring is synthetic"
fi

# --- 5.10 Revenue ---
# Does any project have payment/billing infrastructure?
REVENUE=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    if grep -rq "stripe\|paddle\|lemon.*squeezy\|billing\|subscription\|payment" --include="*.ts" --include="*.tsx" --include="*.json" "$project" 2>/dev/null; then
        REVENUE=true
        break
    fi
done
if $REVENUE; then
    assert "revenue: payment infrastructure in ≥1 project" 0
else
    assert "revenue: payment infrastructure in ≥1 project" 1 "no path to ROI"
fi

# --- 5.11 Deployed and accessible ---
# Is any project actually deployed and live?
DEPLOYED=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    if [[ -f "$project/vercel.json" ]] || [[ -f "$project/.vercel/project.json" ]] || grep -q "NEXT_PUBLIC_.*URL" "$project/.env"* 2>/dev/null; then
        DEPLOYED=true
        break
    fi
done
if $DEPLOYED; then
    assert "deployed: ≥1 project has deployment config" 0
else
    assert "deployed: ≥1 project has deployment config" 1 "nothing is live"
fi

# --- 5.12 Overnight autonomous run ---
# Has the system ever run agents autonomously (via LaunchAgent/cron)?
# Evidence: log files on different dates with >2 lines (not just start/complete from manual)
AUTONOMOUS_RUNS=0
for log in "$CLAUDE_HOME/logs"/*.log; do
    [[ -f "$log" ]] || continue
    lines=$(wc -l < "$log" | tr -d ' ')
    [[ "$lines" -ge 5 ]] && AUTONOMOUS_RUNS=$((AUTONOMOUS_RUNS + 1))
done
if [[ "$AUTONOMOUS_RUNS" -ge 3 ]]; then
    assert "autonomous runs: ≥3 substantive agent logs found" 0
else
    assert "autonomous runs: ≥3 substantive agent logs found" 1 "only $AUTONOMOUS_RUNS"
fi

# --- 5.13 Meta loss curve is improving (test pass rate trending up, not flat) ---
# When test suite grows, raw pct can drop even as the system improves (adding harder tests).
# Fix: compare absolute pass counts when total changes. Only flag regression when pass count drops.
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    # Get last 5 cycles' pass count and total
    RECENT_DATA=$(tail -5 "$CLAUDE_HOME/knowledge/meta/grades.jsonl" | while IFS= read -r line; do
        pass=$(echo "$line" | jq -r '.test_after.pass // .test_before.pass // empty' 2>/dev/null)
        total=$(echo "$line" | jq -r '.test_after.total // .test_before.total // empty' 2>/dev/null)
        pct=$(echo "$line" | jq -r '.test_after.pct // .test_before.pct // empty' 2>/dev/null)
        [[ -n "$pass" && -n "$total" ]] && echo "$pass/$total/$pct"
    done)
    DATA_COUNT=$(echo "$RECENT_DATA" | grep -c '[0-9]' || echo 0)
    if [[ "$DATA_COUNT" -ge 3 ]]; then
        FIRST_PASS=$(echo "$RECENT_DATA" | head -1 | cut -d/ -f1)
        FIRST_TOTAL=$(echo "$RECENT_DATA" | head -1 | cut -d/ -f2)
        FIRST_PCT=$(echo "$RECENT_DATA" | head -1 | cut -d/ -f3)
        LAST_PASS=$(echo "$RECENT_DATA" | tail -1 | cut -d/ -f1)
        LAST_TOTAL=$(echo "$RECENT_DATA" | tail -1 | cut -d/ -f2)
        LAST_PCT=$(echo "$RECENT_DATA" | tail -1 | cut -d/ -f3)
        if [[ "$LAST_TOTAL" -gt "$FIRST_TOTAL" && "$LAST_PASS" -ge "$FIRST_PASS" ]]; then
            # Test suite grew AND pass count held or improved — that's progress, not regression
            assert "meta: test pass rate not declining (${FIRST_PASS}/${FIRST_TOTAL}→${LAST_PASS}/${LAST_TOTAL}, suite grew)" 0
        elif [[ "$LAST_PCT" -ge "$FIRST_PCT" ]]; then
            assert "meta: test pass rate not declining (${FIRST_PCT}%→${LAST_PCT}%)" 0
        else
            assert "meta: test pass rate not declining" 1 "${FIRST_PASS}/${FIRST_TOTAL}→${LAST_PASS}/${LAST_TOTAL} (${FIRST_PCT}%→${LAST_PCT}%)"
        fi
    else
        assert "meta: test pass rate not declining" 1 "only $DATA_COUNT data points"
    fi
fi

# --- 5.14 Feedback loops are connected (outputs feed inputs) ---
# Check that the chain exists: experiment → learnings → next hypothesis
LOOP_CONNECTED=0
LOOP_TOTAL=3

# Loop 1: experiment-learnings.md has content from experiments
if [[ -f "$CLAUDE_HOME/knowledge/experiment-learnings.md" ]]; then
    if grep -qi "what works\|dead end\|pattern\|experiment" "$CLAUDE_HOME/knowledge/experiment-learnings.md" 2>/dev/null; then
        LOOP_CONNECTED=$((LOOP_CONNECTED + 1))
    fi
fi

# Loop 2: meta grades track test numbers (meta → evals → meta)
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    recent_has_tests=$(tail -1 "$CLAUDE_HOME/knowledge/meta/grades.jsonl" | jq -r '.test_before.pct // empty' 2>/dev/null)
    [[ -n "$recent_has_tests" ]] && LOOP_CONNECTED=$((LOOP_CONNECTED + 1))
fi

# Loop 3: session context injects scores (scoring → sessions → agents)
if grep -q "TASTE_REPORT\|taste.*score\|score.*inject" "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null; then
    LOOP_CONNECTED=$((LOOP_CONNECTED + 1))
fi

if [[ "$LOOP_CONNECTED" -ge 3 ]]; then
    assert "feedback loops: all $LOOP_TOTAL connected" 0
else
    assert "feedback loops: all $LOOP_TOTAL connected" 1 "only $LOOP_CONNECTED/$LOOP_TOTAL"
fi

# --- 5.15 System self-knowledge: rhino test pass rate recorded in an accessible place ---
# The system should know its own health — check that test results are logged somewhere
# beyond just grades.jsonl (which only meta reads)
SELF_KNOWLEDGE=false
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    # At minimum, the latest grade should have test numbers
    latest_pct=$(tail -1 "$CLAUDE_HOME/knowledge/meta/grades.jsonl" | jq -r '.test_after.pct // .test_before.pct // empty' 2>/dev/null)
    [[ -n "$latest_pct" ]] && SELF_KNOWLEDGE=true
fi
if $SELF_KNOWLEDGE; then
    assert "self-knowledge: system health metrics logged ($latest_pct%)" 0
else
    assert "self-knowledge: system health metrics logged" 1 "no test results in grades"
fi

# --- 5.16 HARD: Score improved ≥10 points from first to latest across any project ---
SCORE_IMPROVEMENT=false
for tsv in "$PROJECTS_DIR"/*/.claude/scores/history.tsv; do
    [[ -f "$tsv" ]] || continue
    entries=$(tail -n +2 "$tsv" | wc -l | tr -d ' ')
    [[ "$entries" -lt 3 ]] && continue
    first_struct=$(tail -n +2 "$tsv" | head -1 | cut -f3)
    last_struct=$(tail -1 "$tsv" | cut -f3)
    if [[ "$first_struct" =~ ^[0-9]+$ && "$last_struct" =~ ^[0-9]+$ ]]; then
        delta=$((last_struct - first_struct))
        [[ "$delta" -ge 10 ]] && SCORE_IMPROVEMENT=true && break
    fi
done
if $SCORE_IMPROVEMENT; then
    assert "HARD: structure score improved ≥10 points in ≥1 project" 0
else
    assert "HARD: structure score improved ≥10 points in ≥1 project" 1
fi

# --- 5.17 HARD: Taste score improved between first and latest eval ---
TASTE_IMPROVING=false
for taste_history in "$PROJECTS_DIR"/*/.claude/evals/taste-history.tsv; do
    [[ -f "$taste_history" ]] || continue
    entries=$(tail -n +2 "$taste_history" | wc -l | tr -d ' ')
    [[ "$entries" -lt 2 ]] && continue
    first_score=$(tail -n +2 "$taste_history" | head -1 | cut -f2)
    last_score=$(tail -1 "$taste_history" | cut -f2)
    if [[ -n "$first_score" && -n "$last_score" ]]; then
        # Use awk for decimal comparison
        if awk "BEGIN { exit !($last_score > $first_score) }" 2>/dev/null; then
            TASTE_IMPROVING=true
            break
        fi
    fi
done
if $TASTE_IMPROVING; then
    assert "HARD: taste score improved between evals" 0
else
    assert "HARD: taste score improved between evals" 1
fi

# --- 5.18 HARD: System ran for ≥3 days with agent activity on each ---
ACTIVE_DAYS=0
if [[ -d "$CLAUDE_HOME/logs" ]]; then
    ACTIVE_DAYS=$(for log in "$CLAUDE_HOME/logs"/*.log; do
        [[ -f "$log" ]] || continue
        lines=$(wc -l < "$log" | tr -d ' ')
        [[ "$lines" -ge 3 ]] && stat -f "%Sm" -t "%Y-%m-%d" "$log" 2>/dev/null || stat -c "%y" "$log" 2>/dev/null | cut -d' ' -f1
    done | sort -u | wc -l | tr -d ' ')
fi
if [[ "$ACTIVE_DAYS" -ge 3 ]]; then
    assert "HARD: agent activity on ≥3 distinct days ($ACTIVE_DAYS)" 0
else
    assert "HARD: agent activity on ≥3 distinct days" 1 "only $ACTIVE_DAYS"
fi

# --- 5.19 HARD: An experiment learning was CITED in a later experiment hypothesis ---
LEARNING_CITED=false
for tsv in "$PROJECTS_DIR"/*/.claude/experiments/*.tsv; do
    [[ -f "$tsv" ]] || continue
    # Check if any experiment row references learnings/patterns
    if grep -qi "learning\|pattern\|previous.*showed\|based on.*experiment\|informed by" "$tsv" 2>/dev/null; then
        LEARNING_CITED=true
        break
    fi
done
if $LEARNING_CITED; then
    assert "HARD: experiment cites previous learning (informed search)" 0
else
    assert "HARD: experiment cites previous learning (informed search)" 1 "all experiments are random guesses"
fi

# --- 5.20 HARD: Product has ≥3 completed user flows (not just scaffolding) ---
COMPLETED_FLOWS=0
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    src=""
    [[ -d "$project/src" ]] && src="$project/src"
    [[ -d "$project/apps/web/src" ]] && src="$project/apps/web/src"
    [[ -z "$src" ]] && continue

    # Count route files with actual content (>50 lines = real UI, not scaffold)
    for route_file in $(find "$src" -name "page.tsx" -o -name "index.tsx" 2>/dev/null | head -20); do
        lines=$(wc -l < "$route_file" | tr -d ' ')
        [[ "$lines" -ge 50 ]] && COMPLETED_FLOWS=$((COMPLETED_FLOWS + 1))
    done
done
if [[ "$COMPLETED_FLOWS" -ge 3 ]]; then
    assert "HARD: ≥3 completed user flows (pages >50 lines) ($COMPLETED_FLOWS)" 0
else
    assert "HARD: ≥3 completed user flows (pages >50 lines)" 1 "only $COMPLETED_FLOWS"
fi

# --- 5.21 HARD: Real user visited the product (not just the developer) ---
# Evidence: analytics shows >1 unique visitor, or auth has >1 user, or feedback exists
REAL_USERS=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project" ]] || continue
    # Check for user-facing auth that implies multiple users
    if grep -rq "createUser\|signUp\|register.*user\|UserButton\|SignInButton" --include="*.ts" --include="*.tsx" "$project/src" "$project/apps" 2>/dev/null; then
        REAL_USERS=true
        break
    fi
done
if $REAL_USERS; then
    assert "HARD: product has user auth (path to real users)" 0
else
    assert "HARD: product has user auth (path to real users)" 1
fi

# --- 5.22 HARD: Meta test pass rate increased from cycle 1 to latest ---
# Early cycles (1-13) lack test_before/test_after. Use absolute pass counts when available.
if [[ -f "$CLAUDE_HOME/knowledge/meta/grades.jsonl" ]]; then
    # Find first entry with test data (skip early cycles without it)
    FIRST_ENTRY=$(grep -m1 '"test_before"\|"test_after"' "$CLAUDE_HOME/knowledge/meta/grades.jsonl")
    LATEST_ENTRY=$(tail -1 "$CLAUDE_HOME/knowledge/meta/grades.jsonl")
    if [[ -n "$FIRST_ENTRY" ]]; then
        FIRST_PASS=$(echo "$FIRST_ENTRY" | jq -r '.test_before.pass // .test_after.pass // empty' 2>/dev/null)
        FIRST_TOTAL=$(echo "$FIRST_ENTRY" | jq -r '.test_before.total // .test_after.total // empty' 2>/dev/null)
        LATEST_PASS=$(echo "$LATEST_ENTRY" | jq -r '.test_after.pass // .test_before.pass // empty' 2>/dev/null)
        LATEST_TOTAL=$(echo "$LATEST_ENTRY" | jq -r '.test_after.total // .test_before.total // empty' 2>/dev/null)
        if [[ -n "$FIRST_PASS" && -n "$LATEST_PASS" ]]; then
            if [[ "$LATEST_PASS" -gt "$FIRST_PASS" ]]; then
                assert "HARD: meta test rate improved first→latest (${FIRST_PASS}/${FIRST_TOTAL}→${LATEST_PASS}/${LATEST_TOTAL})" 0
            else
                assert "HARD: meta test rate improved first→latest" 1 "${FIRST_PASS}/${FIRST_TOTAL}→${LATEST_PASS}/${LATEST_TOTAL} (flat or declining)"
            fi
        else
            assert "HARD: meta test rate improved first→latest" 1 "missing pass count data"
        fi
    else
        assert "HARD: meta test rate improved first→latest" 1 "no cycles with test data found"
    fi
fi

# --- 5.23 HARD: System produced a commit without human writing the code ---
AUTONOMOUS_COMMIT=false
for project in "$PROJECTS_DIR"/*/; do
    [[ -d "$project/.git" ]] || continue
    # Look for commits with experiment/build/agent markers
    if cd "$project" && git log --oneline -20 2>/dev/null | grep -qi "experiment\|auto\|agent\|builder\|rhino"; then
        AUTONOMOUS_COMMIT=true
        break
    fi
    cd "$RHINO_DIR" 2>/dev/null
done
cd "$RHINO_DIR" 2>/dev/null
if $AUTONOMOUS_COMMIT; then
    assert "HARD: ≥1 autonomous commit (experiment/agent-driven)" 0
else
    assert "HARD: ≥1 autonomous commit (experiment/agent-driven)" 1
fi

tier_end
fi

# ============================================================
# FINAL REPORT
# ============================================================
if [[ "$TOTAL_TOTAL" -eq 0 ]]; then
    echo "No tests ran."
    exit 1
fi

TOTAL_PCT=$((TOTAL_PASS * 100 / TOTAL_TOTAL))

case "$OUTPUT_MODE" in
    json)
        jq -n \
            --argjson tiers "$RESULTS_JSON" \
            --argjson pass "$TOTAL_PASS" \
            --argjson fail "$TOTAL_FAIL" \
            --argjson total "$TOTAL_TOTAL" \
            --argjson pct "$TOTAL_PCT" \
            --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{date: $date, pass: $pass, fail: $fail, total: $total, pct: $pct, tiers: $tiers}'
        ;;
    visual)
        echo ""
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        local_color="$GREEN"
        [[ "$TOTAL_PCT" -lt 90 ]] && local_color="$YELLOW"
        [[ "$TOTAL_PCT" -lt 70 ]] && local_color="$RED"

        echo -e "  ${BOLD}Overall: ${local_color}${TOTAL_PASS}/${TOTAL_TOTAL} passed (${TOTAL_PCT}%)${NC}"

        if [[ -n "$FAILED_TESTS" ]]; then
            echo ""
            echo -e "  ${RED}Failed:${NC}"
            echo "$FAILED_TESTS"
        fi

        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Integrity check on our own score
        if [[ "$TOTAL_PCT" -eq 100 ]]; then
            echo -e "\n  ${YELLOW}⚠ 100% pass rate. Are the tests hard enough?${NC}"
        fi
        ;;
esac

# Exit with failure if any test failed
[[ "$TOTAL_FAIL" -gt 0 ]] && exit 1
exit 0
