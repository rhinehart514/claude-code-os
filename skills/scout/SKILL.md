---
name: scout
description: Landscape intelligence. Forms opinionated positions about what works in 2026. Scans competitors, validates the landscape model, updates knowledge. Say "/scout" for a manual scan.
user-invocable: true
---

# Scout — Landscape Intelligence

## Setup

1. **Read your brain**: `~/.claude/state/brains/scout.json` — what's your next_move?
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what patterns work?
3. **Read workspace**: `~/.claude/state/workspace.json` — which projects to focus research on (BUY projects get 60%+ of time)
4. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json

## Execute

Read and execute the agent prompt at `~/.claude/agents/scout.md`.

### What This Does
- Portfolio-directed research (focus on active/BUY projects)
- Validates and updates positions in `~/.claude/knowledge/landscape.json`
- Challenges and updates `~/.claude/agents/refs/landscape-2026.md` with new evidence
- Forms new positions (opinionated statements, not trends)
- Required: Devil's Advocate section, "What I Didn't Find" must be longest section (min 10 items)

## Output

Updates:
- `~/.claude/knowledge/landscape.json`
- `~/.claude/agents/refs/landscape-2026.md`
- `~/.claude/knowledge/scout/knowledge.md`

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/scout.json`:
   - `next_move`: which landscape area needs investigation
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Autonomy behavior**:
   - `manual`: present findings, ask before updating landscape model
   - `guided`: update landscape model, present summary
   - `autonomous`: update everything, log changes
