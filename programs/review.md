# Review Program

End-of-day review. Measure honestly, extract gaps, bridge to tomorrow's plan.

> Read `agents/refs/thinking.md`. Predict → Act → Measure → Update Model.

## Anti-sycophancy

If everything looks great, you're probably not looking hard enough. Compare to the last review — if ALL scores improved, flag it: are the improvements real or cosmetic?

## Step 1: Structural Score

```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/score.sh" . --json
```

Record: overall, per-dimension breakdown, integrity warnings, delta from sprint baseline.

If integrity warnings exist: surface them prominently. They override all other findings.

## Step 2: Visual Taste Eval (if applicable)

Run if project has a UI and dev server is available:
```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/taste.mjs"
```

Record: overall taste, weakest dimension, one specific fix, would-return/would-recommend.

Skip if: no UI, build broken, or `--score-only` flag.

## Step 3: Feature Eval (if eval spec exists)

Check `.claude/evals/[current-feature].yml` or `docs/evals/[current-feature].yml`. If found, run it.

## Step 4: Extract Gaps

For each issue:
1. **Classify**: high (blocks user value), medium (degrades experience), low (cosmetic)
2. **Map to bottleneck**: which creation loop link?
3. **Generate task**: gap → specific action with file path

**Recurrence detection**: Read previous reviews (`.claude/evals/reports/review-*.md`). Same gap 3+ times → escalate to HIGH: "Recurring gap (seen {N} times). Previous fixes didn't address root cause."

## Step 5: Generate Tomorrow's Tasks

Top 5 gaps → concrete tasks:
```
Task: [specific action]
File: [exact path]
Why: [which gap + which loop link]
Expected impact: [which score/dimension moves]
```

## Step 6: Write Outputs

1. **Review report**: `.claude/evals/reports/review-[YYYY-MM-DD].md`
2. **Bridge file**: `.claude/plans/review-gaps.md` — what `/plan` reads tomorrow
3. **Eval history**: append to `.claude/evals/reports/history.jsonl`

## Step 7: Print Summary

```
## Review — [date]

Score: [X] ([+/-Y])  Taste: [X] ([+/-Y])  Health: [GREEN/YELLOW/RED]

Top gaps:
1. [gap] → [task]
2. [gap] → [task]
3. [gap] → [task]

Tomorrow: start with [#1 task]. Run /plan for full context.
```
