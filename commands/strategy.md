---
description: "What's the strategy? Shows current stage, bottleneck, loop health, unknowns, and graduation criteria. /strategy refresh re-diagnoses from current data."
---

# /strategy

Strategy as a first-class view, not a side-effect of /plan.

## Routing

Parse `$ARGUMENTS`:

### No arguments → show current strategy
Read strategy.yml and present the current state.

### `refresh` → re-diagnose
Re-read all data sources, re-score loop health, re-assess bottleneck, update strategy.yml.

### `stage [name]` → update stage
Valid stages: `one`, `some`, `many`, `growth`
Update `meta.stage` and `meta.stage_definition` in strategy.yml.

### `bottleneck [name]` → manually set bottleneck
Update `bottleneck.name` and `bottleneck.description` in strategy.yml.

## Steps (for refresh)

### 1. Read state (parallel)
1. `.claude/plans/strategy.yml` — current strategy
2. `rhino score .` — overall score
3. `rhino eval . --score --by-feature` — per-feature breakdown
4. `rhino feature` — feature health
5. `.claude/knowledge/predictions.tsv` — prediction accuracy (fall back to `~/.claude/knowledge/`)
6. `.claude/plans/roadmap.yml` — thesis progress
7. `.claude/scores/history.tsv` — score trend
8. `config/rhino.yml` features section — maturity, weight, depends_on for each feature

### 2. Score loop health (1-5 each)
For each loop stage, assess from evidence:
- **install**: Does `install.sh` work? Is it tested? (file checks, smoke test)
- **setup**: Does first session have guidance? (commands exist, /plan works)
- **first_loop**: Has the full loop been completed externally? (predictions, score deltas)
- **value**: Does the user get measurable improvement? (score trend, assertion graduation)
- **return**: Does the user come back? (session continuity, plan freshness)

### 3. Compute product completion
From `config/rhino.yml` features, compute weighted product completion:
- Map maturity to %: `planned`=0, `building`=33, `working`=66, `polished`=100
- Product completion = sum(maturity% * weight) / sum(weight)
- Feature bottleneck = lowest maturity% among highest-weight features (w:4+)

### 4. Identify bottleneck
The bottleneck is the earliest loop stage scoring ≤2/5. If multiple stages tie, pick the one that blocks downstream stages.

Cross-reference with the product map: if the feature bottleneck (highest-weight, lowest-maturity feature) maps to a loop stage, that loop stage is the bottleneck regardless of its score.

### 5. Check graduation criteria
Read `graduation:` section from strategy.yml. For each criterion, check if it's met from current data.

### 6. Surface unknowns
Read `unknowns:` section. Flag any that have been unresolved >30 days.

### 7. Update strategy.yml (if refresh)
Write updated loop scores, bottleneck, unknown status.

## Output format

```
◆ strategy

  stage: **one** — "core loop works for one person"
  bottleneck: **first-loop** — never proven end-to-end externally

  product completion: **62%**

  ▾ product map
    scoring     w:5  ██████░░░░  working     66%
    commands    w:5  ██████░░░░  working     66%
    learning    w:4  ███░░░░░░░  building    33%  ← feature bottleneck
    install     w:3  ██████████  polished   100%
    docs        w:3  ██████░░░░  working     66%
    self-diag   w:2  ██████░░░░  working     66%
    todo        w:2  ██████░░░░  working     66%

  ▾ loop health
    install:    ███░░  3/5
    setup:      ██░░░  2/5
    first_loop: █░░░░  1/5  ← bottleneck
    value:      █░░░░  1/5
    return:     █░░░░  1/5

  ▾ unknowns (N unresolved)
    ✓ external-project: resolved — HIVE monorepo bootstrapped
    ▸ loop-compounds: does the loop compound across sessions?
    · new-user-friction: what breaks first for new users?

  ▾ graduation criteria (one → some)
    ✓ 10+ predictions logged
    ✓ 3+ experiment learnings
    · 2/3 unknowns resolved (1/3)
    · FirstLoop score >= 2/3 (1/5)

/plan       work on the bottleneck
/research   explore unknowns
/roadmap    see version theses
/retro      grade predictions that inform strategy
```

**Formatting rules:**
- Header: `◆ strategy`
- Product completion: bold %, computed from weighted feature maturity
- Product map: features sorted by weight desc, showing weight, maturity bar (10 chars), maturity label, %. ← feature bottleneck on lowest-maturity high-weight feature
- Stage + bottleneck: bold names, em-dash descriptions
- Loop health: bar graph (█ filled, ░ empty), N/5, ← bottleneck marker
- Unknowns: ✓ resolved, ▸ high priority, · medium/low
- Graduation: ✓ met, · not met with current value
- Bottom: 2-3 relevant next commands

## Tools to use

**Use Read** to read strategy.yml, roadmap.yml, predictions.tsv
**Use Bash** to run `rhino score .`, `rhino eval . --score --by-feature`, `rhino feature`
**Use Edit** to update strategy.yml (refresh mode only)

## What you never do
- Change stage without evidence (stage transitions are thesis-level decisions)
- Remove unknowns (they're the map to highest-information experiments)
- Invent loop health scores — every number must cite evidence
- Set bottleneck to something that isn't a loop stage

## If something breaks
- strategy.yml missing: create it from template with stage=one, all loop health=1
- roadmap.yml missing: skip thesis progress section
- predictions.tsv missing: skip accuracy section, note "no predictions yet"
- rhino score fails: use git log + file state as evidence instead

$ARGUMENTS
