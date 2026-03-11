---
name: setup
description: Onboard any project into rhino-os. Detects project type, creates .claude/ structure, sets autonomy and experimentation levels, registers in workspace. Say "/setup" in any project.
user-invocable: true
---

# Setup — Project Onboarding

You are onboarding this project into rhino-os. Follow these steps exactly.

## Step 1: Detect Project Type

Check for these files in the current directory to determine project type:
- `package.json` → check for `next`, `react`, `vue`, `svelte` in dependencies → **Next.js / React / Vue / Svelte / Node**
- `pyproject.toml` or `setup.py` or `requirements.txt` → **Python**
- `Cargo.toml` → **Rust**
- `go.mod` → **Go**
- `Gemfile` → **Ruby**
- None of the above → **Plain**

Read `package.json` if it exists to identify the framework more precisely.

## Step 2: Create .claude/ Structure

Create these directories:
```
.claude/plans/
.claude/experiments/
.claude/evals/reports/
.claude/scores/
.claude/cache/
.claude/state/
```

## Step 3: Copy CLAUDE.md Template

Read `$RHINO_DIR/config/CLAUDE.md` (or `~/.claude/agents/../config/CLAUDE.md` — find it via the rhino-os install).

If a `CLAUDE.md` already exists in the project root, ask the user if they want to merge or replace. If no CLAUDE.md exists, copy the template.

After copying, tell the user: "Fill in the `# Who I Am` and `# The Goal` sections with your project's identity."

## Step 4: Ask Configuration Questions

Ask these three questions (use the AskUserQuestion tool or ask inline):

### 4a. Autonomy Level
"What autonomy level for this project?"
- **manual** — I approve everything. No auto-commits, no sub-agents.
- **guided** — I set direction, agent executes. Auto-commits via /smart-commit. (recommended)
- **autonomous** — Full loop. /go runs strategy→build→score→repeat with minimal supervision.

Default: `guided`

### 4b. Experimentation Level
"How aggressive should experiments be?"
- **conservative** — Mostly exploit known patterns. Small, safe changes.
- **balanced** — Mix of known patterns and exploration. (recommended)
- **aggressive** — Prefer unknown territory. Bigger swings, higher discard rate expected.

Default: `balanced`

### 4c. Project Stage
"What stage is this project?"
- **mvp** — Pre-launch, still finding product-market fit
- **early** — Launched, early users, iterating fast
- **growth** — Product-market fit found, scaling
- **mature** — Established, optimizing

Default: `mvp`

## Step 5: Scan for Features

Look for routes/pages to auto-detect features:
- **Next.js**: `app/*/page.tsx` or `pages/*.tsx`
- **React Router**: grep for `<Route` patterns
- **Python/Flask/Django**: grep for route decorators
- **Plain**: ask the user what the main features are

Present the detected features and ask: "Are these the main features? Add or remove any."

## Step 6: Generate features.yml

Write `.claude/features.yml`:
```yaml
# Features — maps feature names to routes/entry points
# Used by taste eval for feature-specific scoring

features:
  feature-name:
    routes:
      - /path
      - /other-path
    description: What this feature does
```

## Step 7: Run Baseline Score

Run: `Bash("$RHINO_DIR/bin/score.sh" . --json)` (find RHINO_DIR from the installed rhino binary or environment).

If score.sh isn't available, skip with a note: "Install rhino CLI tools with ./install.sh to enable scoring."

## Step 7b: Generate Learning Agenda

Generate `.claude/plans/learning-agenda.md` — the day-1 curriculum that ensures the first experiments are deliberate, not random.

The agenda is stage-aware:
- **mvp** → exploration-heavy: "learn what users want" — unknowns about user behavior, creation flow, value prop
- **early** → validation-heavy: "confirm the loop" — unknowns about retention triggers, sharing mechanics, engagement patterns
- **growth** → optimization-heavy: "find the ceiling" — unknowns about scaling bottlenecks, conversion funnels, feature ceiling

Write:
```markdown
# Learning Agenda — [project-name]

Stage: [stage] | Generated: [date]

## What We Don't Know
The 3 highest-information-value unknowns for this project, based on type + stage:
1. [unknown] — why this matters, what we'd do differently if we knew
2. [unknown] — why this matters, what we'd do differently if we knew
3. [unknown] — why this matters, what we'd do differently if we knew

## First 3 Experiments
Deliberate exploration targeting the unknowns above (not random building):
1. [experiment targeting unknown 1] — hypothesis, expected learning
2. [experiment targeting unknown 2] — hypothesis, expected learning
3. [experiment targeting unknown 3] — hypothesis, expected learning

## What To Read First
- `agents/refs/thinking.md` — the thinking protocol
- `~/.claude/knowledge/experiment-learnings.md` — cross-project learnings
- `agents/refs/landscape-2026.md` — what wins in 2026

## Graduation Criteria
- [ ] 3+ predictions logged to predictions.tsv
- [ ] 3+ experiment learnings recorded for this project
- [ ] At least 2 of the 3 unknowns above reduced (moved to Known or Uncertain)
```

When graduation criteria are all checked off and a real plan exists in `.claude/plans/active-plan.md`, the agenda stops showing in session context.

## Step 8: Register in Workspace

Run workspace registration. Source the workspace helper and register:
```bash
source "$RHINO_DIR/bin/lib/workspace.sh"
ws_register "$(pwd)" "[stage]" "[autonomy]" "[experimentation]"
```

Or write directly to `~/.claude/state/workspace.json` using the schema:
```json
{
  "projects": {
    "[project-name]": {
      "path": "[absolute-path]",
      "stage": "[stage]",
      "autonomy": "[autonomy]",
      "experimentation": "[experimentation]",
      "features": ["[feature1]", "[feature2]"],
      "last_score": null,
      "last_taste": null,
      "active": true
    }
  },
  "focus": "[project-name]",
  "updated": "[ISO timestamp]"
}
```

If workspace.json already exists, merge (don't overwrite other projects).

## Step 9: Print Next Steps

```
Project onboarded: [name]
  Type: [detected type]
  Stage: [stage]
  Autonomy: [level]
  Experimentation: [level]
  Features: [count] detected
  Baseline score: [score or "pending"]

Next steps:
  1. Fill in CLAUDE.md identity and goal sections
  2. Run /experiment to start learning (learning agenda generated)
  3. Graduate the agenda, then run /strategy for your first sprint
```
