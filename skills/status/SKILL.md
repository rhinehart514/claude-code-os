---
name: status
description: System dashboard. Shows all projects, agent brains, scores, taste, sweep state, and portfolio focus. Say "/status" for a full overview.
user-invocable: true
---

# Status — System Dashboard

Show a unified view of the rhino-os system state.

## 1. Workspace Overview

Read `~/.claude/state/workspace.json`. For each active project:
```
[project-name] ([stage]) — autonomy: [level], experimentation: [level]
  Path: [path]
  Last score: [score or "never"]
  Last taste: [taste or "never"]
  [FOCUS] ← if this is the focus project
```

## 2. Agent Council

Read all brain files from `~/.claude/state/brains/*.json`. For each:
```
[agent]: [next_move]
  Last run: [timestamp]
  Bias: [bias_awareness summary]
```

## 3. Latest Sweep

Read `~/.claude/state/sweep-latest.md`. Show the first 10 lines (summary + classification).

## 4. Score & Taste

For the focus project, show:
- Latest score from `.claude/cache/score-cache.json` or recent score run
- Latest taste from `.claude/evals/reports/taste-*.json`
- Integrity warnings if any
- Trend (improving/declining/flat)

## 5. Active Plan

Read `.claude/plans/active-plan.md` for the current project. Show title and task progress.

## 6. Knowledge Health

- Experiment learnings: line count + last updated
- Predictions: accuracy percentage
- Patterns: count of confirmed patterns

## 7. System Health

- Claude CLI: installed? version?
- rhino-os version
- Hooks: count of active hooks in settings.json
- Symlinks: count of valid agent/program symlinks

Present everything in a clean, scannable format. Group by section with clear headers.
