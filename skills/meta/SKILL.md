---
name: meta
description: Self-improvement loop. Grades agent outputs, applies fixes, tracks whether fixes worked. Each cycle makes every other agent smarter. Say "/meta" for a manual meta cycle.
user-invocable: true
---

# Meta — The Training Loop

## Setup

1. **Read your brain**: `~/.claude/state/brains/meta.json` — what's your next_move?
2. **Read artifact failures**: `~/.claude/logs/artifact-failures.jsonl` — highest-priority signal (agents that ran but produced nothing)
3. **Read previous grades**: `~/.claude/knowledge/meta/grades.jsonl` — what was graded last time?
4. **Read workspace**: `~/.claude/state/workspace.json` — system-wide context
5. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json

## Execute

Read and execute `~/.claude/programs/meta.md` with the context loaded above.

### What This Does
1. Self-heal (syntax checks, broken symlinks, config validation)
2. Seven evaluations: score calibration, experiment efficiency, rule effectiveness, program clarity, taste accuracy, scoring gaps, agent output quality
3. Checks whether the learning engine is working
4. Grades each agent (A-F) with specific rationale
5. Applies ONE fix per cycle (to agent prompt, program, or script)
6. Checks if LAST cycle's fix improved anything

### Key Principle
Grade on ARTIFACTS PRODUCED, not prose quality. If an agent writes a beautiful report but doesn't write its state file, it's an F.

## Output

Appends to `~/.claude/knowledge/meta/grades.jsonl`
Applies one fix to the system

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/meta.json`:
   - `next_move`: what the next meta cycle should focus on
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Autonomy behavior**:
   - `manual`: present grades and proposed fix, ask before applying
   - `guided`: apply fix, present summary
   - `autonomous`: apply fix, log changes, continue
