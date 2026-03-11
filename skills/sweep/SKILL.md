---
name: sweep
description: Daily triage and system health check. Scans all projects in workspace, checks builds, classifies as GREEN/YELLOW/RED/GRAY. Say "/sweep" for a manual health check.
user-invocable: true
---

# Sweep — System Health

## Setup

1. **Read your brain**: `~/.claude/state/brains/sweep.json` — what's your next_move?
2. **Read workspace**: `~/.claude/state/workspace.json` — get all active projects
3. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json

## Execute

Read and execute the agent prompt at `~/.claude/agents/sweep.md`.

### Multi-Project Sweep

Read `~/.claude/state/workspace.json` and iterate all active projects:

For each project:
1. `cd` to project path
2. Run health checks:
   - Syntax checks on scripts
   - Build status (if applicable)
   - Git status (uncommitted work, stale PRs)
   - Score freshness
   - Taste freshness
3. Classify: GREEN / YELLOW / RED / GRAY

If 3+ active projects, consider using Agent tool to sweep in parallel.

### System-Level Checks
- Agent artifact freshness (brains, landscape, portfolio)
- Sprint progress vs actual git history
- Hook health (are all hooks firing?)
- Knowledge freshness (experiment-learnings, patterns, predictions)

## Output

Write unified report to `~/.claude/state/sweep-latest.md`:
```markdown
# Sweep — [date]

## [project-name]: [GREEN/YELLOW/RED/GRAY]
[summary of findings]

## System Health
[agent artifacts, knowledge, hooks]

## Focus Recommendation
[which project needs attention and why]
```

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/sweep.json`:
   - `next_move`: what needs attention most urgently
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Autonomy behavior**:
   - `manual`: present report, ask before any remediation
   - `guided`: present report, auto-fix GREEN/YELLOW items
   - `autonomous`: present report, fix GREEN/YELLOW, flag RED for review
