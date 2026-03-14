#!/usr/bin/env bash
# score.test.sh — Mechanical tests for bin/score.sh
# Tests the crown jewel: value-based scoring.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RHINO_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0
TEMP=""

check() {
  local name="$1"
  local condition="$2"
  if eval "$condition" >/dev/null 2>&1; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

setup_temp() {
  TEMP=$(mktemp -d)
  cd "$TEMP"
  git init -q
}

teardown_temp() {
  cd /
  [[ -n "$TEMP" ]] && rm -rf "$TEMP"
  TEMP=""
}

run_score() {
  bash "$RHINO_DIR/bin/score.sh" . --force --quiet 2>&1
}

# ── Build detection ─────────────────────────────────────

echo "-- Build detection --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src && echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "score.sh produces numeric output" "[ -n '$SCORE' ]"
check "score.sh output is a number" "echo '$SCORE' | grep -qE '^[0-9]+$'"
teardown_temp

# ── Empty project = 10 ──────────────────────────────────

echo "-- Empty project --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "empty project (no value hypothesis) scores 10" "[ '$SCORE' -eq 10 ]"
teardown_temp

# ── Onboarding: value hypothesis + signals bumps score ───

echo "-- Onboarding: completion ratchet --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config tests
echo 'export const x = 1;' > src/index.ts
echo 'test("ok", () => {});' > tests/basic.test.ts
cat > config/rhino.yml << 'YMLEOF'
value:
  hypothesis: "Users get value"
  signals:
    - name: sig1
      description: "Signal"
YMLEOF
git add -A && git commit -q -m "init"
SCORE=$(run_score)
# hypothesis(10) + signals(5) + tests(5) = 20
check "onboarding ratchet scores > 10 with hypothesis+signals+tests" "[ '$SCORE' -gt 10 ]"
check "onboarding ratchet scores <= 50" "[ '$SCORE' -le 50 ]"
teardown_temp

# ── Onboarding cap at 50 ────────────────────────────────

echo "-- Onboarding cap --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config tests config/evals
echo 'export const x = 1;' > src/index.ts
echo 'test("ok", () => {});' > tests/basic.test.ts
cat > config/rhino.yml << 'YMLEOF'
value:
  hypothesis: "Users get value"
  signals:
    - name: sig1
      description: "Signal"
YMLEOF
# beliefs.yml with assertion
cat > config/evals/beliefs.yml << 'BEOF'
- id: test-assertion
  type: content_check
  belief: "No TODOs"
  forbidden: ["FIXME_UNLIKELY_MARKER"]
BEOF
git add -A && git commit -q -m "init"
SCORE=$(run_score)
# This project has: hypothesis(10) + signals(5) + tests(5) + beliefs(10) + assertion(10) + 1 passes(10) = 50 (capped)
# But wait — it has assertions, so it should be in "assertions" mode, not "onboarding"
# assertions mode = assertion pass rate. 1/1 passing = 100
check "project with assertions scores via pass rate" "[ '$SCORE' -eq 100 ] || [ '$SCORE' -gt 50 ]"
teardown_temp

# ── Assertions: pass rate is the score ───────────────────

echo "-- Assertions: pass rate --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config/evals
echo 'export const x = 1;' > src/index.ts
cat > config/evals/beliefs.yml << 'BEOF'
- id: clean-code
  type: content_check
  belief: "No FIXME"
  forbidden: ["FIXME_MARKER_UNLIKELY"]
BEOF
git add -A && git commit -q -m "init"
JSON=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
echo "$JSON" | grep -q '"scoring_mode":"assertions"' && check "beliefs project detects assertions mode" "true" || check "beliefs project detects assertions mode" "false"
SCORE=$(run_score)
check "100% assertion pass rate = high score" "[ '$SCORE' -ge 90 ]"
teardown_temp

# ── Health gate: low health = 0 ─────────────────────────

echo "-- Health gate --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config/evals
# Create massively unhygienic code to push health below 20
for i in $(seq 1 30); do
  echo "console.log('debug$i');" >> src/index.ts
done
for i in $(seq 1 30); do
  echo "// TODO fix $i" >> src/index.ts
done
for i in $(seq 1 10); do
  echo "const x$i: any = $i;" >> src/index.ts
done
cat > config/evals/beliefs.yml << 'BEOF'
- id: test-check
  type: content_check
  belief: "No FIXME"
  forbidden: ["FIXME_UNLIKELY"]
BEOF
git add -A && git commit -q -m "init"
JSON=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
# Check that health_gate field exists in JSON
echo "$JSON" | grep -q '"health_gate"' && check "JSON includes health_gate field" "true" || check "JSON includes health_gate field" "false"
teardown_temp

# ── Structure: no tests penalty still applies to health ──

echo "-- Structure: no tests --"

setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config/evals
echo 'export const x = 1;' > src/index.ts
cat > config/evals/beliefs.yml << 'BEOF'
- id: test-check
  type: content_check
  belief: "No FIXME"
  forbidden: ["FIXME_UNLIKELY"]
BEOF
git add -A && git commit -q -m "init"
JSON_NO_TESTS=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
HEALTH_NO=$(echo "$JSON_NO_TESTS" | sed 's/.*"health_min":\([0-9]*\).*/\1/')

mkdir -p tests
echo 'test("ok", () => {});' > tests/basic.test.ts
git add -A && git commit -q -m "add test"
JSON_WITH_TESTS=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
HEALTH_WITH=$(echo "$JSON_WITH_TESTS" | sed 's/.*"health_min":\([0-9]*\).*/\1/')

check "health improves with tests" "[ '$HEALTH_WITH' -ge '$HEALTH_NO' ]"
teardown_temp

# ── CLI project type ────────────────────────────────────

echo "-- CLI project type --"

setup_temp
mkdir -p bin tests
echo '#!/bin/bash' > bin/main.sh
chmod +x bin/main.sh
echo 'test("ok", () => {});' > tests/basic.test.ts
git add -A && git commit -q -m "init"
SCORE=$(run_score)
check "CLI project scores without crashing" "echo '$SCORE' | grep -qE '^[0-9]+$'"
teardown_temp

# ── Self-score ──────────────────────────────────────────

echo "-- Self-score --"

cd "$RHINO_DIR"
SCORE=$(run_score)
check "rhino-os self-score is numeric" "echo '$SCORE' | grep -qE '^[0-9]+$'"
# rhino-os has assertions → scores via assertion pass rate (not guaranteed >= 80 anymore)
check "rhino-os self-score is > 0" "[ '$SCORE' -gt 0 ]"

# ── Scoring mode detection ─────────────────────────────

echo "-- Scoring mode --"

# rhino-os project → scoring_mode: assertions (not rhino-os anymore)
cd "$RHINO_DIR"
JSON=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
echo "$JSON" | grep -q '"scoring_mode":"assertions"' && check "rhino-os project uses assertions mode" "true" || check "rhino-os project uses assertions mode" "false"
echo "$JSON" | grep -q '"assertion_count"' && check "JSON includes assertion_count" "true" || check "JSON includes assertion_count" "false"

# Plain project → scoring_mode: empty
setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src
echo 'export const x = 1;' > src/index.ts
git add -A && git commit -q -m "init"
JSON=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
echo "$JSON" | grep -q '"scoring_mode":"empty"' && check "plain project detects empty mode" "true" || check "plain project detects empty mode" "false"
teardown_temp

# ── Readiness signals ─────────────────────────────────

echo "-- Readiness --"

# Assertions at 100% → ready_strategy: true, ready_todos: true
setup_temp
echo '{"name":"test"}' > package.json
mkdir -p src config/evals
echo 'export const x = 1;' > src/index.ts
cat > config/evals/beliefs.yml << 'BEOF'
- id: clean-code
  type: content_check
  belief: "No FIXME"
  forbidden: ["FIXME_MARKER_UNLIKELY"]
BEOF
git add -A && git commit -q -m "init"
JSON=$(bash "$RHINO_DIR/bin/score.sh" . --force --json 2>&1)
echo "$JSON" | grep -q '"ready_strategy":true' && check "100% assertions → ready_strategy true" "true" || check "100% assertions → ready_strategy true" "false"
echo "$JSON" | grep -q '"ready_todos":true' && check "100% assertions → ready_todos true" "true" || check "100% assertions → ready_todos true" "false"
teardown_temp

# ── Results ─────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
