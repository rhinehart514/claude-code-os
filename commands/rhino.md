---
description: "Project status dashboard. Shows where you are, what's working, what needs attention, and what to do next."
---

# /rhino

You are a cofounder giving the founder a complete mental model of where the product stands. Not a report — a map.

## Steps (run in parallel where possible)

### 1. Read everything

Run these simultaneously:
1. `rhino score . --quiet` — current score
2. `rhino feature` — features + pass rates
3. `git log --oneline -10` — recent work
4. TaskList — any active tasks
5. `.claude/knowledge/predictions.tsv` (fall back to `~/.claude/knowledge/predictions.tsv`) — predictions + accuracy
6. `.claude/plans/plan.yml` — active plan (if exists)
7. `.claude/plans/roadmap.yml` — current thesis + evidence progress
8. `.claude/plans/todos.yml` — backlog items
9. `config/rhino.yml` — project stage, mode, value hypothesis, features (with maturity/weight/depends_on)

**Compute two completion numbers:**
- **Product completion %** — cumulative weighted feature maturity (all features, all time)
- **Version completion %** — progress toward current thesis (evidence + relevant features + tagged todos). This is the number that resets on `/roadmap bump`.

### 2. Compute completion signals

From the data, compute:

**Feature maturity** — for each feature:
- If `maturity:` is set in rhino.yml, use it
- Otherwise auto-detect: no code files → planned, code exists but assertions <50% → building, assertions >50% → working, assertions 100% + tests exist → polished
- Map to completion: planned=0%, building=33%, working=66%, polished=100%

**Todo completion** — from todos.yml:
- Count: done / (done + active + backlog)
- Active items are in-flight, not complete

**Plan completion** — from plan.yml:
- Count: completed tasks / total tasks

**Prediction health** — from predictions.tsv:
- Accuracy rate (graded predictions)
- Staleness (days since last prediction)

**Roadmap progress** — from roadmap.yml:
- Evidence items: proven / total for current version

**Overall product completion** — weighted average:
- Each feature's maturity × weight, summed, divided by max possible
- This is the "how done is this product?" number

### 3. Render the dashboard

Three sections: product map, completion signals, opinion.

```
**[PROJECT NAME]**  stage: [stage]  ·  mode: [mode]

"[value hypothesis]"
for [user]

── v[X.Y]: "[thesis]" ─────────────────────

  version    ████████████░░░░░░░░  **43%**
  evidence   2/4  ██████████░░░░░░░░░░  first-init ✓  reach-plan ~  first-go ·  return ·
  todos      8/14 ███████████░░░░░░░░░  tagged to v[X.Y]
  features   3/5 working+              for this thesis

  at 80% → `/roadmap bump`

── product map ─────────────────────────────

  scoring    ████████████████████  polished   w:5
  commands   ████████████░░░░░░░░  working    w:5
  learning   ██████░░░░░░░░░░░░░░  building   w:4  ← bottleneck
  install    ████████████████████  polished   w:3
  docs       ████████████░░░░░░░░  working    w:3
  todo       ████████████░░░░░░░░  working    w:2
  self-diag  ████████████░░░░░░░░  working    w:2
                                              ─────
  product    ████████████░░░░░░░░  **64%**    score: 50

  scoring ──→ learning ──→ self-diag

── signals ─────────────────────────────────

  assertions 26/37 passing  ██████████████░░░░░░  70%
  plan       3/5 tasks      ████████████░░░░░░░░  60%
  predictions 10/16 graded  ████████████░░░░░░░░  63%

── recent ──────────────────────────────────

  [hash] [message]                           [days ago]
  [hash] [message]                           [days ago]
  [hash] [message]                           [days ago]
```

**Rendering rules:**

**Product map:**
- Features sorted by weight (highest first), then by maturity (worst first within same weight)
- Bar fill: planned=░░░░░░░░░░░░░░░░░░░░, building=██████░░░░░░░░░░░░░░, working=████████████░░░░░░░░, polished=████████████████████
- Weight shown as `w:N`
- Mark the lowest-maturity highest-weight feature as `← bottleneck`
- If `depends_on` exists for any features, show the dependency graph below the map using arrow notation: `A ──→ B ──→ C`
- Product completion % = sum(feature_maturity_pct × weight) / sum(weight × 100)

**Completion signals:**
- Each signal gets a bar + percentage
- Only show signals that have data (skip if no todos, no plan, etc.)
- These are all the "how done" signals from every subsystem

**Recent:**
- Last 3-5 commits with relative time
- If no commits in >3 days, flag staleness

### 4. Give one opinion

After the dashboard, give ONE opinionated recommendation. Bold it. Based on the **bottleneck** — the lowest-maturity, highest-weight feature.

Decision tree (check in this order):
- Version completion ≥ 80% → "**v[X.Y] is ready.** Evidence is in, features are there. `/roadmap bump` to graduate and start the next thesis."
- Version completion < 30% and version is new → "**Fresh thesis.** Read `/roadmap next` to see what v[X.Y] needs, then `/plan` to start."
- Bottleneck feature is `planned` → "**Define [feature]** — it's the highest-weight feature with no code. `/feature new [name]`"
- Bottleneck feature is `building` → "**Finish [feature]** — it's the critical path. `/go [feature]`"
- Bottleneck feature is `working` but assertions failing → "**Fix [feature]** — [N] assertions failing. `/go [feature]`"
- All features `working`+ → "**Polish or expand.** `/ideate` for what's next."
- Todos piling up (>10 undone) → "**Clear the backlog.** `/todo` to triage, `/plan` to prioritize."
- Plan exists, tasks incomplete → "**Resume the plan.** `/go [feature]` to pick up where you left off."
- No predictions in 7+ days → "**Knowledge is stale.** `/research` to refresh the model."
- Everything green → "**Ship it** or **raise the bar.** `/ship` or `/ideate wild`."

### 5. Command reference (compact, always shown)

```
**Commands** (17 total — type `/` to see all)
/plan [feature]    bottleneck → tasks
/go [feature]      autonomous build
/eval [taste|full] measurement
/todo [add|done]   backlog
/feature [name]    define & manage
/ideate [wild]     brainstorm
/product [lens]    product thinking + ideation
/research [topic]  explore unknowns
/roadmap           theses & learning
```

In **ship mode**, add `/ship` to the list.

## What you never do
- Turn this into a long report — the map IS the report
- Recommend more than one next action
- Skip the opinion — the founder wants direction, not data
- Show signals with no data — skip empty sections
- Make up completion numbers — only show what you can compute from real state

## If something breaks
- `rhino score .` fails: show "score: --" and proceed
- `rhino feature` fails: read beliefs.yml directly for pass rates
- roadmap.yml missing: skip roadmap signal
- predictions.tsv empty: show "predictions: none yet"
- plan.yml missing: skip plan signal
- todos.yml missing: skip todos signal
- No features in rhino.yml: show "no features defined — `/feature new [name]` to start"
- No maturity/weight fields: auto-detect maturity, default weight to 1

$ARGUMENTS
