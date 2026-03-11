# Review Program

You are running the end-of-day review. Your job: measure the current state honestly, extract gaps, and bridge today's work to tomorrow's plan.

## How We Think — READ THIS FIRST

> **Thinking protocol**: Read `agents/refs/thinking.md`. Predict → Act → Measure → Update Model.

> **Score integrity**: Read `agents/refs/score-integrity.md`. Scores reveal where the product is weak, not what number to chase.

## Anti-sycophancy

If everything looks great, you're probably not looking hard enough. A review that finds zero gaps is suspicious — either the product is genuinely excellent (rare) or the review is lazy. Dig deeper.

Compare to the last review (`.claude/evals/reports/review-*.md`). If ALL scores improved, flag it:
- Are the improvements real or cosmetic?
- Did the same gaps recur 3x? That means previous "fixes" didn't actually work.
- Did any score regress that shouldn't have? (e.g., hygiene drops during a feature sprint)

## Step 1: Structural Score (always)

```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/score.sh" . --json
```

Record:
- Overall score
- Per-dimension breakdown (build, structure, hygiene)
- Integrity warnings (COSMETIC-ONLY, INFLATION, PLATEAU)
- Delta from sprint baseline (read from active plan or last review)

If integrity warnings exist: surface them prominently. They override all other findings.

## Step 2: Visual Taste Eval (if applicable)

**When to run taste:**
- Project has a UI (web app, mobile app, CLI with visual output)
- Dev server is available or can be started
- Not a pure library/backend/CLI tool

**When to skip:**
- No UI to evaluate
- Dev server can't start (build broken)
- `--score-only` flag was passed

If running:
```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/taste.mjs"
```

Record:
- Overall taste score (0-100)
- Weakest dimension
- One specific fix recommendation
- Would-return and would-recommend signals

## Step 3: Feature Eval (if eval spec exists)

Check for eval specs:
- `.claude/evals/[current-feature].yml`
- `docs/evals/[current-feature].yml`

If found, run the eval:
1. Deterministic checks (file existence, build passes, etc.)
2. Functional assertions (can user complete the flow?)
3. Ceiling tests (does this compare favorably to the best products?)

Record verdict: PASS / NEEDS_WORK / NOT_READY

## Step 4: Product Eval (unless --fast)

Full product audit — "would anyone use this?"

Skip if:
- `--fast` flag was passed
- Product eval ran in the last 48 hours (check `.claude/evals/reports/history.jsonl`)
- Project is a library/tool (not a consumer product)

If running, evaluate:
- Escape velocity (does usage compound?)
- UI/UX uniqueness (or is it template energy?)
- IA benefit (does the information architecture help users?)
- Return pull (would a user come back tomorrow unprompted?)

## Step 5: Extract Gaps

Gather all findings from Steps 1-4. For each issue found:

1. **Classify severity**: high (blocks user value), medium (degrades experience), low (cosmetic/hygiene)
2. **Map to bottleneck**: which creation loop link does this gap affect? (Create/Share/Discover/Engage/Return)
3. **Generate concrete task**: gap → specific action with file path

### Gap Ranking Algorithm

Primary sort: severity (high → medium → low)
Tie-break: bottleneck position (earlier in loop wins — Create gaps before Return gaps)
Secondary tie-break: recurrence (gaps that appeared in previous reviews rank higher)

### Recurrence Detection

Read previous review reports (`.claude/evals/reports/review-*.md`). If the same gap appears 3+ times:
- Escalate to HIGH severity regardless of original classification
- Flag: "Recurring gap (seen {N} times). Previous fixes didn't address root cause."
- This is the highest-priority signal — it means the system is cycling, not converging.

## Step 6: Generate Tomorrow's Tasks

Convert the top 5 gaps into concrete tasks:

For each gap:
```
Task: [specific action, not vague]
File: [exact file path to modify]
Why: [which gap this addresses + which loop link improves]
Expected impact: [which score/dimension moves]
```

Order by: gap severity (from Step 5 ranking)

## Step 7: Write Outputs

### Review Report

Write to `.claude/evals/reports/review-[YYYY-MM-DD].md`

### Bridge File

Write to `.claude/plans/review-gaps.md` — this is what `/plan` reads tomorrow.

The bridge file is intentionally simple. It contains:
- Top 3-5 gaps with concrete tasks
- Score deltas (so /plan knows the trajectory)
- Sprint progress (so /plan knows if the sprint should continue or pivot)

### Eval History

Append to `.claude/evals/reports/history.jsonl`:
```json
{
  "date": "[YYYY-MM-DD]",
  "type": "review",
  "score": [N],
  "taste": [N or null],
  "gaps_found": [N],
  "recurring_gaps": [N],
  "verdict": "[GREEN/YELLOW/RED]"
}
```

## Step 8: Print Summary

End with a concise summary the founder can scan in 10 seconds:

```
## Review — [date]

Score: [X] ([+/-Y])  Taste: [X] ([+/-Y])  Health: [GREEN/YELLOW/RED]

Top gaps:
1. [gap] → [task]
2. [gap] → [task]
3. [gap] → [task]

Tomorrow: start with [#1 task]. Run /plan for full context.
```
