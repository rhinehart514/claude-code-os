---
name: status
description: System dashboard. Shows all projects, agent brains, scores, taste, sweep state, and portfolio focus. Say "/status" for a full overview.
user-invocable: true
---

# Status — System Dashboard

Show a unified view of the rhino-os system state. Lead with what the founder cares about — progress, not internals.

## 1. Project Progress (always first)

For the focus project (from `~/.claude/state/workspace.json`), read `.claude/plans/milestones.md` and show:

```
## [project-name] — [stage]

Milestone: [name] — [X/Y done] — [N days in]
Sprint: [title] — [X/Y tasks]
Health: GREEN | Score: [X] | Taste: [X]
Ideas queued: [N]

Trajectory (last 5):
  Score: [val] → [val] → [val] → [val] → [val]
  Taste: [val] → [val] → [val] → [val] → [val]
```

If no milestones.md exists, show score/taste/plan progress without milestone context.

## 2. Other Active Projects

For each non-focus active project in workspace.json:
```
[project-name] ([stage]) — Score: [X] | Taste: [X]
```

## 3. Active Plan

Read `.claude/plans/active-plan.md` for the current project. Show title and task progress.

## 4. Agent Council

Read all brain files from `~/.claude/state/brains/*.json`. For each:
```
[agent]: [next_move]
  Last run: [timestamp]
```

## 5. Knowledge & System Health (verbose)

Show by default as a compact summary. Full detail with `--verbose`:

**Knowledge**:
- Experiment learnings: line count + last updated
- Predictions: accuracy percentage
- Patterns: count of confirmed patterns

**System**:
- Claude CLI: installed? version?
- rhino-os version
- Hooks: count of active hooks in settings.json
- Symlinks: count of valid agent/program symlinks

**Latest Sweep**:
Read `~/.claude/state/sweep-latest.md`. Show classification only (GREEN/YELLOW/RED). Full sweep with `--verbose`.

Present everything in a clean, scannable format. Progress first, internals last.
