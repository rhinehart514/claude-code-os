---
name: eval
description: Feature evaluator. Runs eval spec (TDD for AI) — deterministic checks, functional assertions, ceiling tests, perspective stress-test. Calibrated to 2026 market. Gaps feed forward into future plans. Say "/eval" anytime.
user-invocable: true
---

# Eval — Is This Ready?

## Setup

1. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what does the system know?
2. **Read workspace**: `~/.claude/state/workspace.json` — project stage and context
3. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json

> **Score integrity**: Read `agents/refs/score-integrity.md` before scoring. Scores are diagnostic, not goals.
> **Founder trust**: Your job is to INFORM, not to pressure. Report what you see. The founder decides the timeline.

## Step 0: Load Context

Before evaluating, read:
1. **Previous eval reports** — `.claude/evals/reports/history.jsonl` and most recent report. What ceiling gaps keep recurring?
2. **Product context** — the project's CLAUDE.md. Who is the user? What stage?
3. **Experiment learnings** — loaded above

## Step 1: Load the Eval Spec

Look for eval spec in order:
1. `.claude/evals/[feature-name].yml`
2. `.claude/plans/active-eval.md`
3. Generate assertions on-the-fly from active plan. Warn: "No eval spec found."

Read `git diff --stat` to see what changed.

## Step 2: Tier 1 — Deterministic (binary pass/fail)

Run every command in the `deterministic` section. All must pass. If any fail → BLOCKED.

## Step 3: Tier 2 — Functional Assertions

Walk through each assertion. Verify by reading code, checking exports, tracing data flow.
Score: PASS / FAIL / CANT_VERIFY. All must pass.

## Step 4: Tier 3 — Ceiling Tests (push hard)

### Market Calibration (2026)
Compare to: Instagram, TikTok, Discord, Notion, Arc. Not other startups.

### Scoring (0.0-1.0)
- 1.0 = User would screenshot and share
- 0.8 = Polished, intentional, branded
- 0.6 = Functional and fine
- 0.4 = Generic, template-y
- 0.2 = Wrong approach
- 0.0 = Fundamental misunderstanding

### Mandatory Ceiling Dimensions (always include)
1. **Escape velocity**: Does this compound?
2. **UI/UX uniqueness**: Template or branded?
3. **IA benefit**: Right thing at right time?
4. **Return pull**: Reason to come back?

## Step 5: Perspective Check

Simulate being each persona. Does their value_moment happen?

## Step 6: Verdict

Write structured report with all tiers, ceiling gaps, market position.

## Step 7: Save Report

Save to `.claude/evals/reports/[feature]-[date].md`
Append to `.claude/evals/reports/history.jsonl`

## Teardown

1. **Autonomy behavior**:
   - `manual`: present report, ask if they want to see full details
   - `guided`: present summary + top gaps
   - `autonomous`: write report, feed gaps into next /strategy or /build cycle
2. **Update workspace**: record eval verdict in project state
