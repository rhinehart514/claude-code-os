---
name: experiment
description: Autonomous experiment loop with learning accumulation. Each experiment builds knowledge that makes the next one smarter. Karpathy autoresearch applied to product — informed search, not random guessing. Say "/experiment [dimension]" to start.
user-invocable: true
---

# Experiment — Informed Search, Not Random Guessing

## Setup

1. **Read your brain**: `~/.claude/state/brains/builder.json` — experiments use the builder brain
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — this is your accumulated intelligence
3. **Read landscape model**: `~/.claude/agents/refs/landscape-2026.md` — what 2026 users expect
4. **Read workspace**: `~/.claude/state/workspace.json` — get experimentation level for this project:
   - **conservative** (exploration_floor: 0.1, moonshot_every_n: 10): mostly exploitation, rare moonshots
   - **balanced** (exploration_floor: 0.3, moonshot_every_n: 5): current defaults
   - **aggressive** (exploration_floor: 0.5, moonshot_every_n: 3): lots of exploration, frequent moonshots
5. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json
   - `manual`: pause at every keep/discard decision
   - `guided`: run autonomously, pause at discard decisions
   - `autonomous`: fully autonomous, never stop
6. **Read taste knowledge**: If experimenting on a taste dimension, read `~/.claude/knowledge/taste-knowledge/{dimension}.md` — patterns, anti-patterns, exemplars grounded in research. If the file doesn't exist or is stale (>14 days), run inline research: WebSearch for "[dimension] UX best practices 2025 2026", synthesize top patterns, write the knowledge file, then continue.

> **Thinking protocol**: Read `agents/refs/thinking.md`. Every experiment is a prediction. Every result updates the model.
> **Score integrity**: Read `agents/refs/score-integrity.md`. Prefer tool-measured scores. If integrity warnings fire, mark as SUSPECT.

## Execute

You are an autonomous researcher with a memory. Read and follow the full experiment protocol below.

### Step 0: Setup + Load Knowledge

1. Read the project's CLAUDE.md — what you're building and for whom
2. Read `.claude/plans/product-model.md` — the creation loop map. Which link is the bottleneck?
3. Read experiment learnings (loaded above)
4. Read `.claude/evals/reports/history.jsonl` or `docs/evals/reports/history.jsonl`
5. Read most recent taste report in `.claude/evals/reports/taste-*.json`
5b. **Load dimension knowledge**: Read `~/.claude/knowledge/taste-knowledge/{target-dimension}.md` if it exists. This grounds your hypothesis in researched patterns rather than guessing. If the file is empty or stale, research inline: WebSearch for patterns, write findings to the knowledge file, then continue.
6. Parse the user's request: target dimension + starting score
7. **Read `.claude/plans/learning-agenda.md`** if it exists — check for unchecked graduation criteria
8. Create experiment branch: `git checkout -b exp/[dimension]/[date]`
9. Create experiment log at `.claude/experiments/[dimension]-[date].tsv`

**Curriculum mode**: If `learning-agenda.md` exists and has unchecked `- [ ]` graduation criteria:
- Experiments MUST target the agenda's "What We Don't Know" items, not random dimensions
- Mode forced to **exploration** regardless of experiment-learnings density
- After each experiment, check if a graduation criterion was met → check it off (change `- [ ]` to `- [x]`)
- When all criteria met, announce: "Learning agenda complete. Ready for /strategy."
- Curriculum mode is self-terminating: once all criteria are checked, normal mode resumes

10. Classify your knowledge state:
   - **Exploration mode** (<5 patterns): diverse hypotheses, build the model
   - **Exploitation mode** (10+ patterns): hypotheses FROM known patterns, maintain exploration_floor
   - **Mixed** (5-10 patterns): 50/50

### Step 1: The Loop

LOOP UNTIL INTERRUPTED:

**1a. Generate Hypothesis** — four sources: **dimension knowledge (highest weight for taste experiments)**, learnings, product model, taste/score evidence.
If a taste knowledge file exists for this dimension, your hypothesis MUST cite a specific pattern or anti-pattern from it. "I think X will work because the wayfinding knowledge file shows that [pattern] works in [exemplar]."
If no knowledge file exists, declare "exploring unknown territory — no researched knowledge for this dimension yet."
Write hypothesis BEFORE coding with: what, rationale, expected outcome, disproof condition, type.

**1b. Ambition check** — rate 1-5. Reject 1-2 (cosmetic). Last 3 were all 3? Next must be 4+.
Moonshot rule: every Nth experiment (from experimentation level config) MUST be high-risk.

**1c. Implement** — focused change, one hypothesis, substantive enough to actually fail.

**1d. Commit** — `git commit -m "exp: [hypothesis in 10 words]"`

**1e. Measure** — run target dimension eval. Score 0.0-1.0. Be honest.

**1f. Decide + Extract Learning**
- Score improved >= min_keep_delta → KEEP
- Below threshold → DISCARD → `git reset --hard HEAD~1`
- Extract learning: what type, did it work, WHY (the mechanism, not the result)
- If the experiment discovered a new pattern not in the knowledge file, append it to `~/.claude/knowledge/taste-knowledge/{dimension}.md` under "## Patterns" or "## Anti-Patterns" as appropriate.

**1g. Log** — append to TSV

**1h. Update Learnings** (every 3 experiments) — update experiment-learnings.md

**1i. Next** — go to 1a. If 5 discards in a row: re-read product model, switch strategy. If 5 keeps in a row: increase ambition.

### Step 2: Wrap Up

1. Final learnings update to experiment-learnings.md
2. Post findings (Discussion/PR/markdown)
3. Summary with what worked, what didn't, model updates
4. Update history.jsonl

## Teardown

1. **Update brain**: `~/.claude/state/brains/builder.json` with experiment insights as next_move
2. Leave the experiment branch for human review
3. Update workspace.json `last_score` if applicable
