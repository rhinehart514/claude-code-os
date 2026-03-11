#!/usr/bin/env bash
set -uo pipefail
# NOTE: set -e intentionally omitted. Tests use pass/fail counters.

# run.sh — rhino-os v4 self-eval. Deterministic, no LLM judges.
#
# Three tiers:
#   Tier 1: Deterministic  (does the code work?)
#   Tier 2: Functional     (do workflows produce correct outputs?)
#   Tier 3: Canary         (known inputs → known outputs, detects drift)
#
# Usage:
#   tests/run.sh              # all tiers, visual output
#   tests/run.sh --json       # machine-readable
#   tests/run.sh --tier 1     # run only tier 1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RHINO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_MODE="visual"
RUN_TIER="all"

for arg in "$@"; do
    case $arg in
        --json) OUTPUT_MODE="json" ;;
        --tier) :;; # next arg is the tier number
        1|2|3) RUN_TIER="$arg" ;;
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

assert_file() {
    local name="$1" path="$2"
    if [[ -f "$path" ]]; then assert "$name" 0; else assert "$name" 1 "missing: $path"; fi
}

assert_cmd() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then assert "$name" 0; else assert "$name" 1 "exit $?"; fi
}

assert_contains() {
    local name="$1" output="$2" expected="$3"
    if echo "$output" | grep -q "$expected"; then assert "$name" 0; else assert "$name" 1 "expected '$expected' not found"; fi
}

assert_equals() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then assert "$name" 0; else assert "$name" 1 "expected '$expected', got '$actual'"; fi
}

TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

[[ "$OUTPUT_MODE" == "visual" ]] && echo -e "${BOLD}=== rhino-os v4 self-eval ===${NC}"

# ============================================================
# TIER 1: DETERMINISTIC — Does the code work?
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "1" ]]; then
tier_start "1: Deterministic"

# --- 1.1 Core files exist ---
assert_file "bin/rhino exists" "$RHINO_DIR/bin/rhino"
assert_file "bin/score.sh exists" "$RHINO_DIR/bin/score.sh"
assert_file "bin/taste.mjs exists" "$RHINO_DIR/bin/taste.mjs"
assert_file "bin/ia-audit.sh exists" "$RHINO_DIR/bin/ia-audit.sh"
assert_file "bin/lib/config.sh exists" "$RHINO_DIR/bin/lib/config.sh"
assert_file "bin/lib/brains.sh exists" "$RHINO_DIR/bin/lib/brains.sh"
assert_file "bin/lib/workspace.sh exists" "$RHINO_DIR/bin/lib/workspace.sh"
assert_file "install.sh exists" "$RHINO_DIR/install.sh"
assert_file "config/rhino.yml exists" "$RHINO_DIR/config/rhino.yml"
assert_file "config/CLAUDE.md exists" "$RHINO_DIR/config/CLAUDE.md"
assert_file "config/settings.json exists" "$RHINO_DIR/config/settings.json"

# --- 1.2 All 4 programs exist ---
for prog in build strategy meta review; do
    assert_file "programs/$prog.md exists" "$RHINO_DIR/programs/$prog.md"
done

# --- 1.3 Programs are under 200-line limit ---
for prog in build strategy meta review; do
    lines=$(wc -l < "$RHINO_DIR/programs/$prog.md" | tr -d ' ')
    if [[ "$lines" -le 200 ]]; then
        assert "programs/$prog.md under 200 lines ($lines)" 0
    else
        assert "programs/$prog.md under 200 lines" 1 "$lines lines"
    fi
done

# --- 1.4 All 5 reference docs exist ---
for ref in thinking.md design-taste.md score-integrity.md landscape-2026.md escalation.md; do
    assert_file "agents/refs/$ref exists" "$RHINO_DIR/agents/refs/$ref"
done

# --- 1.5 No stale agent wrappers exist ---
stale_agents=$(ls "$RHINO_DIR/agents"/*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$stale_agents" -eq 0 ]]; then
    assert "no agent wrapper .md files in agents/" 0
else
    assert "no agent wrapper .md files in agents/" 1 "found $stale_agents"
fi

# --- 1.6 All 5 internal skills exist ---
for skill in score taste experiment strategy todofocus; do
    assert_file "skills/_internal/$skill/SKILL.md exists" "$RHINO_DIR/skills/_internal/$skill/SKILL.md"
done

# --- 1.7 Dead internal skills are gone ---
for dead in init design scout sweep product-eval product-2026 research-taste eval; do
    if [[ -d "$RHINO_DIR/skills/_internal/$dead" ]]; then
        assert "dead skill _internal/$dead removed" 1 "still exists"
    else
        assert "dead skill _internal/$dead removed" 0
    fi
done

# --- 1.8 User-facing skills exist ---
for skill in plan build research review go setup status meta docs council smart-commit; do
    assert_file "skills/$skill/SKILL.md exists" "$RHINO_DIR/skills/$skill/SKILL.md"
done

# --- 1.9 Syntax checks ---
assert_cmd "bin/rhino parses (bash -n)" bash -n "$RHINO_DIR/bin/rhino"
assert_cmd "bin/score.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/score.sh"
assert_cmd "bin/ia-audit.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/ia-audit.sh"
assert_cmd "bin/lib/config.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/config.sh"
assert_cmd "bin/lib/brains.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/brains.sh"
assert_cmd "bin/lib/workspace.sh parses (bash -n)" bash -n "$RHINO_DIR/bin/lib/workspace.sh"
assert_cmd "install.sh parses (bash -n)" bash -n "$RHINO_DIR/install.sh"
assert_cmd "bin/taste.mjs parses (node --check)" node --check "$RHINO_DIR/bin/taste.mjs"

for hook in hooks/*.sh; do
    [[ -f "$RHINO_DIR/$hook" ]] || continue
    hname=$(basename "$hook")
    assert_cmd "hooks/$hname parses (bash -n)" bash -n "$RHINO_DIR/$hook"
done

# --- 1.10 Executable permissions ---
assert_cmd "bin/rhino is executable" test -x "$RHINO_DIR/bin/rhino"
assert_cmd "bin/score.sh is executable" test -x "$RHINO_DIR/bin/score.sh"
assert_cmd "bin/ia-audit.sh is executable" test -x "$RHINO_DIR/bin/ia-audit.sh"

# --- 1.11 CLI routing ---
HELP_OUTPUT=$("$RHINO_DIR/bin/rhino" --help 2>&1 || true)
assert_contains "rhino --help outputs usage" "$HELP_OUTPUT" "usage\|Usage\|USAGE\|rhino"

SCORE_HELP=$("$RHINO_DIR/bin/score.sh" --help 2>&1 || true)
assert_contains "score.sh --help works" "$SCORE_HELP" "Usage\|usage"

IA_HELP=$("$RHINO_DIR/bin/ia-audit.sh" --help 2>&1 || true)
assert_contains "ia-audit.sh --help works" "$IA_HELP" "Usage\|usage"

# --- 1.12 Config reader works ---
CFG_TEST=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg scoring.cache_ttl MISSING)")
assert_equals "cfg() reads scoring.cache_ttl" "$CFG_TEST" "300"

CFG_DEFAULT=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg nonexistent.key FALLBACK)")
assert_equals "cfg() returns default for missing key" "$CFG_DEFAULT" "FALLBACK"

CFG_NESTED=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg scoring.build.ts_error_penalty MISSING)")
assert_equals "cfg() reads 3-level nested key" "$CFG_NESTED" "-30"

# --- 1.13 JSON validity for existing brain files ---
if compgen -G "$HOME/.claude/state/brains/*.json" > /dev/null 2>&1; then
    for brain in "$HOME/.claude/state/brains"/*.json; do
        [[ -f "$brain" ]] || continue
        bname=$(basename "$brain")
        assert_cmd "brain $bname is valid JSON" jq '.' "$brain"
    done
fi

# --- 1.14 No broken refs in programs ---
BROKEN_REFS=0
BROKEN_LIST=""
for md_file in "$RHINO_DIR/programs"/*.md; do
    [[ -f "$md_file" ]] || continue
    base=$(basename "$md_file")
    refs=$(grep -o 'agents/refs/[a-z_-]*.md' "$md_file" 2>/dev/null | sort -u)
    for ref in $refs; do
        if [[ ! -f "$RHINO_DIR/$ref" ]]; then
            BROKEN_REFS=$((BROKEN_REFS + 1))
            BROKEN_LIST="$BROKEN_LIST $base→$ref"
        fi
    done
done
if [[ "$BROKEN_REFS" -eq 0 ]]; then
    assert "no broken agents/refs/ references in programs" 0
else
    assert "no broken agents/refs/ references in programs" 1 "$BROKEN_REFS broken:$BROKEN_LIST"
fi

tier_end
fi

# ============================================================
# TIER 2: FUNCTIONAL — Do workflows produce correct outputs?
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "2" ]]; then
tier_start "2: Functional"

# --- 2.1 score.sh produces valid JSON with required fields ---
SCORE_JSON=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --json --force 2>/dev/null || true)
if echo "$SCORE_JSON" | jq '.' >/dev/null 2>&1; then
    assert "score.sh --json produces valid JSON" 0
    for field in score build build_gate structure hygiene project_type integrity_warnings; do
        if echo "$SCORE_JSON" | jq -e ".$field" >/dev/null 2>&1; then
            assert "score JSON has .$field" 0
        else
            assert "score JSON has .$field" 1 "missing field"
        fi
    done
    SCORE_VAL=$(echo "$SCORE_JSON" | jq '.score')
    if [[ "$SCORE_VAL" =~ ^[0-9]+$ ]] && [[ "$SCORE_VAL" -ge 0 ]] && [[ "$SCORE_VAL" -le 100 ]]; then
        assert "score is 0-100 integer" 0
    else
        assert "score is 0-100 integer" 1 "got: $SCORE_VAL"
    fi
else
    assert "score.sh --json produces valid JSON" 1 "invalid JSON"
fi

# --- 2.2 score.sh --quiet produces single number ---
SCORE_QUIET=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
if [[ "$SCORE_QUIET" =~ ^[0-9]+$ ]]; then
    assert "score.sh --quiet outputs single number" 0
else
    assert "score.sh --quiet outputs single number" 1 "got: '$SCORE_QUIET'"
fi

# --- 2.3 score.sh is deterministic ---
SCORE_A=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
SCORE_B=$("$RHINO_DIR/bin/score.sh" "$RHINO_DIR" --quiet --force 2>/dev/null || true)
assert_equals "score.sh is deterministic (run twice)" "$SCORE_A" "$SCORE_B"

# --- 2.4 ia-audit.sh produces valid JSON ---
IA_JSON=$("$RHINO_DIR/bin/ia-audit.sh" "$RHINO_DIR" --json 2>/dev/null || true)
if echo "$IA_JSON" | jq '.' >/dev/null 2>&1; then
    assert "ia-audit.sh --json produces valid JSON" 0
    for field in ia_health total_routes orphan_routes dead_ends empty_states_no_cta; do
        if echo "$IA_JSON" | jq -e ".$field" >/dev/null 2>&1; then
            assert "ia-audit JSON has .$field" 0
        else
            assert "ia-audit JSON has .$field" 1 "missing"
        fi
    done
else
    assert "ia-audit.sh --json produces valid JSON" 1
fi

# --- 2.5 ia-audit.sh --quiet produces single number ---
IA_QUIET=$("$RHINO_DIR/bin/ia-audit.sh" "$RHINO_DIR" --quiet 2>/dev/null || true)
if [[ "$IA_QUIET" =~ ^[0-9]+$ ]]; then
    assert "ia-audit.sh --quiet outputs single number" 0
else
    assert "ia-audit.sh --quiet outputs single number" 1 "got: '$IA_QUIET'"
fi

# --- 2.6 Integrity config values are readable ---
INTEGRITY_CEILING=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg integrity.max_single_commit_delta MISSING)")
assert_equals "integrity.max_single_commit_delta = 15" "$INTEGRITY_CEILING" "15"

INTEGRITY_PLATEAU=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg integrity.plateau_experiments MISSING)")
assert_equals "integrity.plateau_experiments = 5" "$INTEGRITY_PLATEAU" "5"

# --- 2.7 rhino.yml has required sections ---
for section in scoring taste experiments integrity; do
    if grep -q "^${section}:" "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
        assert "rhino.yml has $section section" 0
    else
        assert "rhino.yml has $section section" 1
    fi
done

# --- 2.8 Taste rubric has integrity rules ---
if grep -q "DO NOT be generous\|DO NOT round up" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "taste.mjs has anti-inflation language" 0
else
    assert "taste.mjs has anti-inflation language" 1
fi

for check in "GENEROUS" "NO_WEAKNESS" "FLAT_EVAL"; do
    if grep -q "$check" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
        assert "taste.mjs has $check integrity detector" 0
    else
        assert "taste.mjs has $check integrity detector" 1
    fi
done

# --- 2.9 score.sh has experiment discipline checks ---
for check in "KEEP_RATE_HIGH" "NO_MOONSHOTS" "discard_rate_floor" "moonshot_every_n"; do
    if grep -q "$check" "$RHINO_DIR/bin/score.sh" 2>/dev/null; then
        assert "score.sh has $check" 0
    else
        assert "score.sh has $check" 1
    fi
done

# --- 2.10 Build program has key enforcement ---
BUILDMD="$RHINO_DIR/programs/build.md"
if grep -q "NEVER valid\|NEVER a valid" "$BUILDMD" 2>/dev/null; then
    assert "build.md has anti-sycophancy guard" 0
else
    assert "build.md has anti-sycophancy guard" 1
fi

if grep -q "PREDICT:" "$BUILDMD" 2>/dev/null && grep -q "WRONG IF:" "$BUILDMD" 2>/dev/null; then
    assert "build.md enforces predict-before-act" 0
else
    assert "build.md enforces predict-before-act" 1
fi

if grep -q "predictions.tsv" "$BUILDMD" 2>/dev/null; then
    assert "build.md references predictions.tsv" 0
else
    assert "build.md references predictions.tsv" 1
fi

if grep -q "moonshot_every_n\|Moonshot enforcement" "$BUILDMD" 2>/dev/null; then
    assert "build.md has moonshot enforcement" 0
else
    assert "build.md has moonshot enforcement" 1
fi

if grep -q "discard rate floor\|Discard rate floor" "$BUILDMD" 2>/dev/null; then
    assert "build.md has discard rate floor" 0
else
    assert "build.md has discard rate floor" 1
fi

if grep -q "DRIFT\|Scope Guard\|scope guard" "$BUILDMD" 2>/dev/null; then
    assert "build.md has scope guard" 0
else
    assert "build.md has scope guard" 1
fi

if grep -q "git reset --hard HEAD~1" "$BUILDMD" 2>/dev/null; then
    assert "build.md has mechanical discard (git reset)" 0
else
    assert "build.md has mechanical discard (git reset)" 1
fi

# --- 2.11 Strategy has loop templates ---
STRATMD="$RHINO_DIR/programs/strategy.md"
if grep -q "Dev tool:" "$STRATMD" 2>/dev/null || grep -q "Dev tool" "$STRATMD" 2>/dev/null; then
    assert "strategy.md has non-consumer loop templates" 0
else
    assert "strategy.md has non-consumer loop templates" 1
fi

# --- 2.12 Experiment TSV schema ---
if grep -q "commit.*score.*delta.*status.*description.*learning" "$BUILDMD" 2>/dev/null; then
    assert "build.md documents 6-column experiment TSV schema" 0
else
    assert "build.md documents 6-column experiment TSV schema" 1
fi

# --- 2.13 COSMETIC-ONLY detector fires on crafted input ---
COSMETIC_TEST_DIR="$TMPDIR_TEST/cosmetic-fire-test"
mkdir -p "$COSMETIC_TEST_DIR/src" "$COSMETIC_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$COSMETIC_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$COSMETIC_TEST_DIR/package.json"
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-01T00:00:00Z\t50\t50\t50\tnode\n" >> "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-02T00:00:00Z\t50\t50\t70\tnode\n" >> "$COSMETIC_TEST_DIR/.claude/scores/history.tsv"
COSMETIC_RESULT=$("$RHINO_DIR/bin/score.sh" "$COSMETIC_TEST_DIR" --json --force 2>/dev/null || true)
if echo "$COSMETIC_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null | grep -q "COSMETIC"; then
    assert "COSMETIC-ONLY detector fires on hygiene-only improvement" 0
else
    assert "COSMETIC-ONLY detector fires on hygiene-only improvement" 1
fi

# --- 2.14 INFLATION detector fires on big jump ---
INFLATION_TEST_DIR="$TMPDIR_TEST/inflation-fire-test"
mkdir -p "$INFLATION_TEST_DIR/src" "$INFLATION_TEST_DIR/.claude/scores"
echo "console.log('x')" > "$INFLATION_TEST_DIR/src/index.js"
echo '{"name":"test","version":"1.0.0"}' > "$INFLATION_TEST_DIR/package.json"
printf "timestamp\tbuild\tstructure\thygiene\tproject_type\n" > "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-01T00:00:00Z\t50\t30\t30\tnode\n" >> "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
printf "2026-01-02T00:00:00Z\t50\t50\t50\tnode\n" >> "$INFLATION_TEST_DIR/.claude/scores/history.tsv"
INFLATION_RESULT=$("$RHINO_DIR/bin/score.sh" "$INFLATION_TEST_DIR" --json --force 2>/dev/null || true)
if echo "$INFLATION_RESULT" | jq -r '.integrity_warnings[]' 2>/dev/null | grep -q "INFLATION"; then
    assert "INFLATION detector fires on +40 jump" 0
else
    assert "INFLATION detector fires on +40 jump" 1
fi

# --- 2.15 PLATEAU detector fires ---
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
    assert "PLATEAU detector fires after 6 identical scores" 0
else
    assert "PLATEAU detector fires after 6 identical scores" 1
fi

# --- 2.16 No false INFLATION on small delta ---
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
    assert "no false INFLATION on +4 delta" 0
else
    assert "no false INFLATION on +4 delta" 1
fi

# --- 2.17 Programs have concrete outputs ---
for prog in "$RHINO_DIR/programs"/*.md; do
    [[ -f "$prog" ]] || continue
    prog_name=$(basename "$prog" .md)
    if grep -qE '```bash|rhino |\.jsonl|\.json|\.tsv|\.md\b' "$prog" 2>/dev/null; then
        assert "program $prog_name references concrete outputs" 0
    else
        assert "program $prog_name references concrete outputs" 1
    fi
done

# --- 2.18 No program instructs writing to CLAUDE.md ---
CLAUDE_MD_WRITERS=""
for md_file in "$RHINO_DIR/programs"/*.md "$RHINO_DIR/skills"/*/SKILL.md "$RHINO_DIR/skills/_internal"/*/SKILL.md; do
    [[ -f "$md_file" ]] || continue
    base=$(basename "$(dirname "$md_file")")/$(basename "$md_file")
    if grep -iE '(update|write|edit|append|modify).*CLAUDE\.md' "$md_file" 2>/dev/null \
        | grep -iv 'do not\|never\|don.t\|that.s a bug\|grep for\|scan.*for' \
        | grep -q .; then
        CLAUDE_MD_WRITERS="$CLAUDE_MD_WRITERS $base"
    fi
done
if [[ -z "$CLAUDE_MD_WRITERS" ]]; then
    assert "no program/skill instructs writing to CLAUDE.md" 0
else
    assert "no program/skill instructs writing to CLAUDE.md" 1 "found in:$CLAUDE_MD_WRITERS"
fi

# --- 2.19 Thinking protocol referenced by all programs ---
for prog in build strategy; do
    if grep -q "thinking.md" "$RHINO_DIR/programs/$prog.md" 2>/dev/null; then
        assert "$prog.md references thinking protocol" 0
    else
        assert "$prog.md references thinking protocol" 1
    fi
done

# --- 2.20 Workspace system produces valid JSON ---
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

# --- 2.21 Brain system produces valid JSON ---
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

# --- 2.22 session_context.sh produces output ---
rm -f "$HOME/.claude/state/.session-context-injected"
SESSION_OUT=$(bash "$RHINO_DIR/hooks/session_context.sh" 2>/dev/null || true)
if [[ ${#SESSION_OUT} -gt 30 ]]; then
    assert "session_context.sh produces substantive output (${#SESSION_OUT} chars)" 0
else
    assert "session_context.sh produces substantive output" 1 "only ${#SESSION_OUT} chars"
fi

# --- 2.23 Score.sh cfg reads have rhino.yml backing ---
SCORE_CFG_READS=$(grep -o "cfg [a-z._]*" "$RHINO_DIR/bin/score.sh" 2>/dev/null | sed 's/cfg //' | sort -u)
for cfg_key in $SCORE_CFG_READS; do
    leaf_key=$(echo "$cfg_key" | awk -F. '{print $NF}')
    if grep -q "$leaf_key" "$RHINO_DIR/config/rhino.yml" 2>/dev/null; then
        assert "score.sh cfg($cfg_key) has rhino.yml backing" 0
    else
        assert "score.sh cfg($cfg_key) has rhino.yml backing" 1 "dead config read"
    fi
done

# --- 2.24 design-taste.md has FAIL examples for all 11 dimensions ---
FAIL_COUNT=$(grep -c "FAIL examples" "$RHINO_DIR/agents/refs/design-taste.md" 2>/dev/null || echo "0")
if [[ "$FAIL_COUNT" -ge 11 ]]; then
    assert "design-taste.md has FAIL examples for all 11 dimensions ($FAIL_COUNT)" 0
else
    assert "design-taste.md has FAIL examples for all 11 dimensions" 1 "only $FAIL_COUNT found"
fi

# --- 2.25 ia-audit.sh is wired into score.sh ---
if grep -q "ia-audit.sh\|ia_audit" "$RHINO_DIR/bin/score.sh" 2>/dev/null; then
    assert "score.sh integrates ia-audit" 0
else
    assert "score.sh integrates ia-audit" 1
fi

tier_end
fi

# ============================================================
# TIER 3: CANARY — Known inputs → known outputs.
# ============================================================
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "3" ]]; then
tier_start "3: Canary"

# --- 3.1 Empty project scores 50/50 ---
EMPTY_DIR="$TMPDIR_TEST/empty-project"
mkdir -p "$EMPTY_DIR"
EMPTY_SCORE=$("$RHINO_DIR/bin/score.sh" "$EMPTY_DIR" --json --force 2>/dev/null || true)
if echo "$EMPTY_SCORE" | jq '.' >/dev/null 2>&1; then
    E_STRUCT=$(echo "$EMPTY_SCORE" | jq '.structure')
    E_HYGIENE=$(echo "$EMPTY_SCORE" | jq '.hygiene')
    assert_equals "canary: empty project structure=50" "$E_STRUCT" "50"
    assert_equals "canary: empty project hygiene=50" "$E_HYGIENE" "50"
else
    assert "canary: empty project produces valid JSON" 1
fi

# --- 3.2 Dirty project: known hygiene issues → predictable score ---
DIRTY_DIR="$TMPDIR_TEST/dirty-project"
mkdir -p "$DIRTY_DIR/src"
echo '{"name":"test","scripts":{}}' > "$DIRTY_DIR/package.json"
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
    # 6 any (>5 = -10), 6 console.log (>5 = -5), 6 TODOs (>5 = -5) → 80
    assert_equals "canary: dirty project hygiene=80" "$D_HYGIENE" "80"
else
    assert "canary: dirty project produces valid JSON" 1
fi

# --- 3.3 Clean project: no issues → hygiene=100 ---
CLEAN_DIR="$TMPDIR_TEST/clean-project"
mkdir -p "$CLEAN_DIR/src"
echo '{"name":"test","scripts":{}}' > "$CLEAN_DIR/package.json"
cat > "$CLEAN_DIR/src/index.ts" << 'TSEOF'
const greeting: string = "hello";
export function greet(): string { return greeting; }
TSEOF

CLEAN_SCORE=$("$RHINO_DIR/bin/score.sh" "$CLEAN_DIR" --json --force 2>/dev/null || true)
if echo "$CLEAN_SCORE" | jq '.' >/dev/null 2>&1; then
    C_HYGIENE=$(echo "$CLEAN_SCORE" | jq '.hygiene')
    assert_equals "canary: clean project hygiene=100" "$C_HYGIENE" "100"
else
    assert "canary: clean project produces valid JSON" 1
fi

# --- 3.4 Stage ceilings readable ---
for stage in mvp early growth mature; do
    CEIL=$(bash -c "source '$RHINO_DIR/bin/lib/config.sh'; echo \$(cfg integrity.stage_ceilings.${stage}.score MISSING)" 2>/dev/null)
    if [[ "$CEIL" != "MISSING" ]]; then
        assert "canary: stage ceiling $stage.score readable" 0
    else
        assert "canary: stage ceiling $stage.score readable" 1
    fi
done

# --- 3.5 Taste dimension count ---
DIM_COUNT=$(grep -c '"score": <1-5>' "$RHINO_DIR/bin/taste.mjs" 2>/dev/null || echo "0")
assert_equals "canary: taste rubric has 11 scored dimensions" "$DIM_COUNT" "11"

# --- 3.6 Taste covers structural dimensions ---
if grep -q "LAYOUT_COHERENCE" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "canary: taste covers layout coherence" 0
else
    assert "canary: taste covers layout coherence" 1
fi
if grep -q "INFORMATION_ARCHITECTURE" "$RHINO_DIR/bin/taste.mjs" 2>/dev/null; then
    assert "canary: taste covers information architecture" 0
else
    assert "canary: taste covers information architecture" 1
fi

# --- 3.7 Score history TSV format ---
HIST="$RHINO_DIR/.claude/scores/history.tsv"
if [[ -f "$HIST" ]]; then
    HEADER=$(head -1 "$HIST")
    assert_contains "canary: score history has timestamp" "$HEADER" "timestamp"
    assert_contains "canary: score history has structure" "$HEADER" "structure"
    assert_contains "canary: score history has hygiene" "$HEADER" "hygiene"
else
    assert "canary: score history (skipped — no history yet)" 0
fi

# --- 3.8 Score bounded 0-100 on all test projects ---
for test_case in "$TMPDIR_TEST/empty-project" "$DIRTY_DIR" "$CLEAN_DIR"; do
    tc_name=$(basename "$test_case")
    tc_score=$("$RHINO_DIR/bin/score.sh" "$test_case" --quiet --force 2>/dev/null || echo "-1")
    tc_score=$(echo "$tc_score" | tr -d '[:space:]')
    if [[ "$tc_score" =~ ^[0-9]+$ ]] && [[ "$tc_score" -ge 0 ]] && [[ "$tc_score" -le 100 ]]; then
        assert "canary: $tc_name score bounded 0-100 (got $tc_score)" 0
    else
        assert "canary: $tc_name score bounded 0-100" 1 "got: $tc_score"
    fi
done

# --- 3.9 ia-audit on empty project ---
IA_EMPTY=$("$RHINO_DIR/bin/ia-audit.sh" "$TMPDIR_TEST/empty-project" --json 2>/dev/null || true)
if echo "$IA_EMPTY" | jq '.' >/dev/null 2>&1; then
    IA_TOTAL=$(echo "$IA_EMPTY" | jq '.total_routes')
    assert_equals "canary: ia-audit empty project has 0 routes" "$IA_TOTAL" "0"
else
    assert "canary: ia-audit empty project produces valid JSON" 1
fi

# --- 3.10 ia-audit on project with routes ---
IA_TEST_DIR="$TMPDIR_TEST/ia-test-project"
mkdir -p "$IA_TEST_DIR/src/app/dashboard" "$IA_TEST_DIR/src/app/settings" "$IA_TEST_DIR/src/app/orphan"
echo '<Link href="/dashboard">Dashboard</Link>' > "$IA_TEST_DIR/src/app/page.tsx"
echo '<Link href="/settings">Settings</Link><a href="/">Back</a>' > "$IA_TEST_DIR/src/app/dashboard/page.tsx"
echo '<Link href="/">Home</Link>' > "$IA_TEST_DIR/src/app/settings/page.tsx"
echo '<p>This page has no links</p>' > "$IA_TEST_DIR/src/app/orphan/page.tsx"
echo '{"name":"test"}' > "$IA_TEST_DIR/package.json"

IA_ROUTES=$("$RHINO_DIR/bin/ia-audit.sh" "$IA_TEST_DIR" --json 2>/dev/null || true)
if echo "$IA_ROUTES" | jq '.' >/dev/null 2>&1; then
    assert "canary: ia-audit finds routes in test project" 0
    ia_dead=$(echo "$IA_ROUTES" | jq '.dead_end_count')
    if [[ "$ia_dead" -ge 1 ]]; then
        assert "canary: ia-audit detects dead-end page ($ia_dead found)" 0
    else
        assert "canary: ia-audit detects dead-end page" 1 "expected >=1, got $ia_dead"
    fi
else
    assert "canary: ia-audit finds routes in test project" 1
fi

# --- 3.11 Predictions TSV schema ---
PRED_FILE="$HOME/.claude/knowledge/predictions.tsv"
if [[ -f "$PRED_FILE" ]]; then
    pred_header=$(head -1 "$PRED_FILE")
    if echo "$pred_header" | grep -q "date.*agent.*prediction.*result.*correct"; then
        assert "canary: predictions.tsv has correct schema" 0
    else
        assert "canary: predictions.tsv has correct schema" 1 "header: $pred_header"
    fi
else
    assert "canary: predictions.tsv (skipped — not yet created)" 0
fi

# --- 3.12 Grades JSONL validity ---
if [[ -f "$HOME/.claude/knowledge/meta/grades.jsonl" ]]; then
    BAD_LINES=0
    LINE_NUM=0
    while IFS= read -r line; do
        LINE_NUM=$((LINE_NUM + 1))
        [[ -z "$line" ]] && continue
        if ! echo "$line" | jq -e '.' >/dev/null 2>&1; then
            BAD_LINES=$((BAD_LINES + 1))
        fi
    done < "$HOME/.claude/knowledge/meta/grades.jsonl"
    if [[ "$BAD_LINES" -eq 0 ]]; then
        assert "canary: grades.jsonl is valid JSONL ($LINE_NUM lines)" 0
    else
        assert "canary: grades.jsonl is valid JSONL" 1 "$BAD_LINES bad lines"
    fi
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

        if [[ "$TOTAL_PCT" -eq 100 ]]; then
            echo -e "\n  ${YELLOW}⚠ 100% pass rate. Are the tests hard enough?${NC}"
        fi
        ;;
esac

[[ "$TOTAL_FAIL" -gt 0 ]] && exit 1
exit 0
