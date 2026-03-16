---
name: retro
description: "What did we learn? Grade predictions, update the knowledge model, detect staleness. The command that closes the learning loop."
---

!tail -n +2 .claude/knowledge/predictions.tsv 2>/dev/null | awk -F'\t' '$5 == "" { c++ } END { print c+0 " ungraded" }' || echo "0 ungraded"

# /retro

The command that closes the learning loop. Predictions without grading are noise — this turns them into signal.

## Routing

Parse `$ARGUMENTS`:

### No arguments → full retro
Grade ungraded predictions, surface accuracy trend, detect stale knowledge, flag dead ends.

### `accuracy` → just the number
Show prediction accuracy and calibration assessment. One line.

### `stale` → knowledge staleness check
Scan experiment-learnings.md for entries older than 30 days without new evidence.

## Steps

### 1. Read state (parallel)
Read these simultaneously:
1. `.claude/knowledge/predictions.tsv` — all predictions (fall back to `~/.claude/knowledge/`)
2. `.claude/knowledge/experiment-learnings.md` — knowledge model (fall back to `~/.claude/knowledge/`)
3. `git log --oneline -20` — recent commits (evidence for grading)
4. `.claude/scores/history.tsv` — score history (evidence for grading)
5. `.claude/plans/strategy.yml` — unknowns that predictions might resolve
6. `config/rhino.yml` features section — maturity, weight (for product completion context)
7. `.claude/plans/todos.yml` — todo completion rate

### 1.5. Auto-grade with grade.sh (mechanical first pass)
Run `bash bin/grade.sh` first. This mechanically grades any predictions with extractable directional claims (e.g., "raise X from N to M") by comparing against score-cache.json. Review the auto-grades for correctness. Then manually grade the remainder that grade.sh couldn't handle.

### 2. Find remaining ungraded predictions
Predictions where `correct` column (5th) is still empty after grade.sh. For each:
- Read the prediction text and evidence
- Check git log, score history, and code state for outcomes
- Propose a grade: `yes`, `no`, or `partial`
- Write a `model_update` when the prediction was wrong

### 3. Grade them
For each ungraded prediction, update the TSV row:
- Fill in `result` column with what actually happened
- Fill in `correct` column with yes/no/partial
- Fill in `model_update` column when wrong (what changes about the model)

### 4. Update knowledge model
For wrong predictions:
- Identify WHY the prediction was wrong (the mechanism was different)
- Check if experiment-learnings.md needs an update:
  - New pattern discovered → add to Uncertain or Known
  - Existing pattern disproven → move to Dead Ends
  - Uncertain pattern confirmed → promote to Known (if 3+ experiments)

### 5. Detect staleness + prune
Scan experiment-learnings.md:
- Known Patterns: any entry >30 days without new evidence? Flag as potentially stale.
- Dead Ends: any entry that keeps showing up in recent predictions? Flag as "revisiting dead end."
- Unknown Territory: entries that have been unknown for >30 days without a first experiment? Flag as neglected.

**Pruning rules:**
1. Entries >30 days without new evidence → move to a `## Stale Patterns` section (don't delete — move)
2. Dead ends >60 days with no citations in predictions.tsv → move to `## Archived Dead Ends`
3. Report: "N stale patterns — consider re-testing or archiving"

### 6. Check maturity transitions
Review recent work and determine if any features should change maturity:
- Feature with 100% assertion pass rate + tests → consider promoting to `polished`
- Feature with >50% assertions passing → consider promoting to `working`
- Feature that had code added since last retro → consider promoting from `planned` to `building`
- Propose maturity updates in the output. Don't auto-write — let the founder confirm.

### 7. Compute accuracy
- Total graded predictions
- Correct (yes=1, partial=0.5, no=0)
- Accuracy = correct / total
- Assessment: 50-70% = well-calibrated, >70% = too safe, <50% = model needs work

## Output format

```
◆ retro — N ungraded, M stale

product: **64%** · score: 50 · todos: 8/14 done

▾ grading
  ✓ "prediction text" → outcome (yes)
  ✗ "prediction text" → what happened instead (no)
    model update: moved X from Uncertain → Dead Ends
  · "prediction text" → partially confirmed (partial)

accuracy: **63%** (10/16) — well-calibrated
trend: ↑ from 55% (improving)

▾ stale knowledge (N entries)
  · "pattern name" — last evidence 45 days ago
  · "pattern name" — in Dead Ends but cited in 2 recent predictions

▾ pruned
  · Moved "X" to Stale Patterns (no evidence in 35 days)
  · Archived "Y" from Dead Ends (60+ days, no citations)

▾ maturity updates (proposed)
  · scoring: working → polished (100% assertions, tests exist)
  · deploy: planned → building (code added this session)

▾ model updates
  ▸ Move "X" from Uncertain → Known (3+ experiments now)
  ▸ Add "Z" to Unknown Territory (discovered gap)

artifact: ~/.claude/cache/last-retro.yml (for /plan and /ideate)

/plan       apply learnings to next session
/research   explore the unknowns surfaced above
/ideate     brainstorm from stale patterns
```

**Formatting rules:**
- Header: `◆ retro — [counts]`
- Grading section: ✓/✗/· prefix, quoted prediction, → outcome, (grade)
- Model updates indented under wrong predictions
- Accuracy: bold percentage, parenthetical details, em-dash assessment
- Stale knowledge: · prefix, quoted pattern name, how long stale
- Bottom: 2-3 relevant next commands

### 7. Write retro artifact
Write `~/.claude/cache/last-retro.yml` so /ideate and /plan can read it:
```yaml
date: YYYY-MM-DD
product_completion: 64
accuracy: 63
accuracy_trend: improving  # improving / stable / declining
graded_count: 3
stale_patterns:
  - "pattern name — last evidence 45 days ago"
dead_ends_archived: 1
model_updates:
  - "Moved X from Uncertain → Known"
unknowns_surfaced:
  - "new unknown from grading"
maturity_proposals:
  - feature: scoring
    from: working
    to: polished
    reason: "100% assertions, tests exist"
```

## Tools to use

**Use Read** to read predictions.tsv, experiment-learnings.md, strategy.yml
**Use Bash** to run `git log --oneline -20` and read history.tsv
**Use Edit** to update predictions.tsv rows (fill in result/correct/model_update)
**Use Edit** to update experiment-learnings.md when model changes

## What you never do
- Skip grading because "there's not enough evidence" — make your best call, mark partial if unsure
- Grade predictions as "yes" when the outcome was different from what was predicted (even if the result was good)
- Delete predictions — they're the training signal
- Modify the predictions.tsv format or column order
- Add predictions (that's /plan's job)

## If something breaks
- predictions.tsv missing: "No predictions logged yet. Run `/plan` to start the learning loop."
- experiment-learnings.md missing: "No knowledge model. Run `/plan` to initialize it."
- All predictions already graded: "All caught up. Accuracy: X%. Run `/plan` to make new predictions."
- TSV parsing fails: check for tab-separated format, 6 columns (date, prediction, evidence, result, correct, model_update)

$ARGUMENTS
