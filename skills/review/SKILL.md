---
name: review
description: End-of-day review. Runs score + taste + eval, extracts gaps, generates tomorrow's task list. Bridges today's work to tomorrow's /plan. Say "/review" to wrap up.
user-invocable: true
---

# Review — End Your Day

Your end-of-day command. Measures everything, extracts gaps, writes tomorrow's input.

## Setup

1. **Read workspace**: `~/.claude/state/workspace.json` — project stage, autonomy
2. **Read active plan**: `.claude/plans/active-plan.md` — what was the sprint targeting?
3. **Read milestones**: `.claude/plans/milestones.md` — current milestone, DoD progress
4. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md`
5. **Read eval history**: `.claude/evals/reports/history.jsonl` or `docs/evals/reports/history.jsonl`
6. **Read score history**: `.claude/scores/history.tsv` or `.claude/evals/reports/taste-*.json` — for trajectory

## Execute

Read and execute `~/.claude/programs/review.md` with the context loaded above.

### Quick Reference (the program has full detail)

1. **Score** — always. Run `rhino score .` for structural health.
2. **Taste** — if UI exists and dev server available. Run taste eval.
3. **Eval** — if eval spec exists for current sprint feature.
4. **Product eval** — skip with `--fast`. Run for full audit otherwise.
5. **Extract gaps** — rank by impact, tie-break by bottleneck position.
6. **Generate tasks** — each gap becomes a concrete task with file path.
7. **Write bridge** — `review-gaps.md` feeds into tomorrow's `/plan`.

### Flags

- `/review` — full review (score + taste + eval + product-eval)
- `/review --fast` — quick review (score + taste only, skip product-eval)
- `/review --score-only` — just score, no visual eval

## Output

### Report (saved to `.claude/evals/reports/review-[date].md`)

```markdown
# Review — [date]

## Progress
Milestone: [name] — [X/Y done criteria]
Sprint: [X/Y tasks] — [N days elapsed]

## Trajectory
Score: [val] → [val] → [val] (last 5)
Taste: [val] → [val] → [val] (last 5)
Sprints completed: [N] this milestone

## Scores
- Structure: [X]/100
- Taste: [X]/100 (weakest: [dimension])
- Eval: [verdict] (if ran)

## What improved
- [specific improvement, citing task/commit]

## Gaps (ranked by impact)
1. [gap] — severity: [high/medium/low] — file: [path]
2. [gap] — severity: [high/medium/low] — file: [path]

## Tomorrow's Tasks
1. [task derived from gap #1]
2. [task derived from gap #2]
3. [task derived from gap #3]
```

### Bridge file (`.claude/plans/review-gaps.md`)

```markdown
# Review Gaps — [date]

## Progress
Milestone: [name] — [X/Y done criteria]
Sprint: [X/Y tasks] — [N days elapsed]
Score trajectory: [val] → [val] → [val]
Taste trajectory: [val] → [val] → [val]

## Top Gaps (feed into /plan)
1. [gap] — [concrete task] — [file path]
2. [gap] — [concrete task] — [file path]
3. [gap] — [concrete task] — [file path]

## Scores
- Score: [X] (delta: [+/-Y] from sprint start)
- Taste: [X] (delta: [+/-Y])

## Sprint Progress
- [X/Y] tasks completed
- Bottleneck moved from [N] to [M]
```

## Teardown

1. **Update experiment learnings**: If new patterns emerged from today's work, append to `~/.claude/knowledge/experiment-learnings.md`
2. **Update brain**: Write to `~/.claude/state/brains/builder.json`:
   - `next_move`: derived from top gap
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp
3. **Commit review report** based on autonomy:
   - `manual`: present report, ask before committing
   - `guided`: commit report automatically
   - `autonomous`: commit and log
