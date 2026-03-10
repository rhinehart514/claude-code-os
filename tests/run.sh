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
assert_file "config/rhino.yml exists" "$RHINO_DIR/config/rhino.yml"
assert_file "agents/refs/score-integrity.md exists" "$RHINO_DIR/agents/refs/score-integrity.md"
assert_file "agents/refs/escalation.md exists" "$RHINO_DIR/agents/refs/escalation.md"

# All 6 agent prompts
for agent in builder scout strategist design-engineer sweep meta; do
    assert_file "agents/$agent.md exists" "$RHINO_DIR/agents/$agent.md"
done

# All 6 skills
for skill in eval product-eval experiment smart-commit todofocus product-2026; do
    assert_file "skills/$skill/SKILL.md exists" "$RHINO_DIR/skills/$skill/SKILL.md"
done

# All 4 hooks
for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh; do
    assert_file "hooks/$hook exists" "$RHINO_DIR/hooks/$hook"
done

# Both programs
assert_file "programs/build.md exists" "$HOME/.claude/programs/build.md"
assert_file "programs/strategy.md exists" "$HOME/.claude/programs/strategy.md"

# --- 1.2 Syntax checks (every script parses) ---
assert_cmd "bin/rhino parses (bash -n)" bash -n "$RHINO_DIR/bin/rhino"
assert_cmd "bin/score.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/score.sh"
assert_cmd "bin/lib/config.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/config.sh"
assert_cmd "bin/lib/brains.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/brains.sh"
assert_cmd "bin/taste.mjs parses (node --check)" node --check "$RHINO_DIR/bin/taste.mjs"

for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh; do
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
    "$RHINO_DIR/skills/eval/SKILL.md" \
    "$RHINO_DIR/skills/product-eval/SKILL.md" \
    "$RHINO_DIR/skills/experiment/SKILL.md" \
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

for hook in session_context.sh capture_knowledge.sh track_usage.sh enforce_ideation_readonly.sh; do
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
if grep -q "SUSPECT\|integrity warning" "$RHINO_DIR/skills/experiment/SKILL.md" 2>/dev/null; then
    assert "experiment skill has SUSPECT status for integrity warnings" 0
else
    assert "experiment skill has SUSPECT status for integrity warnings" 1
fi

if grep -q "tool-measured scores\|Prefer tool" "$RHINO_DIR/skills/experiment/SKILL.md" 2>/dev/null; then
    assert "experiment skill prefers tool-measured over self-assessment" 0
else
    assert "experiment skill prefers tool-measured over self-assessment" 1
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
# taste.mjs should score exactly 9 dimensions
DIM_COUNT=$(grep -c '"score": <1-5>' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null || echo "0")
assert_equals "canary: taste rubric has 9 scored dimensions" "$DIM_COUNT" "9"

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
