---
name: design
description: Design engineer with taste. Audits UI/UX against the 11 taste dimensions (including layout coherence + information architecture), finds violations with file:line precision, fixes them. Say "/design" for a design audit or fix pass.
user-invocable: true
---

# Design — Taste Engineering

## Setup

1. **Read your brain**: `~/.claude/state/brains/design-engineer.json` — what's your next_move?
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what design changes actually move taste scores?
3. **Read workspace**: `~/.claude/state/workspace.json` — project stage, autonomy level
4. **Check autonomy**: session override at `~/.claude/state/.session-autonomy`, else workspace.json

## Execute

Read and execute the agent prompt at `~/.claude/agents/design-engineer.md`.

### What This Does
- Audits against 11 taste dimensions (hierarchy, breathing room, contrast, polish, emotional tone, density, wayfinding, scroll, distinctiveness, layout coherence, information architecture)
- Anti-slop checklist (non-default font, non-blue accent, varied spacing, etc.)
- Finds violations at file:line precision
- Compares against real products (Discord, Notion, Linear) not abstract "good"
- Fixes violations in priority order

### Reference
Full taste framework: `~/.claude/agents/refs/design-taste.md`

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/design-engineer.json`:
   - `next_move`: which taste dimension needs work next
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Commit based on autonomy**:
   - `manual`: present changes for review
   - `guided`: commit with `/smart-commit`
   - `autonomous`: commit and update taste score
