---
name: build
description: The build loop. Reads the active plan, detects scope (think/plan/build/experiment/fix), executes, measures, keeps or discards. Experiments extract learnings. Say "/build" to start building.
user-invocable: true
---

# Build — Execute the Plan

## Setup

### Cold-start check
If `~/.claude/knowledge/experiment-learnings.md` does not exist or is empty, AND no `.claude/experiments/*.tsv` files exist — this is a **first build**. Load only:
1. **Read active plan**: `.claude/plans/active-plan.md` — your contract. No plan? Run `/plan` first.
2. **Check autonomy**: Read `~/.claude/state/workspace.json` for this project's autonomy level.
Then skip to Execute — the program's "Cold Start Detection" section handles the rest.

### Returning build (accumulated state exists)
1. **Read your brain**: `~/.claude/state/brains/builder.json` — what's your next_move from last run?
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what works here?
3. **Read landscape model**: `~/.claude/agents/refs/landscape-2026.md` — what 2026 users expect.
4. **Read active plan**: `.claude/plans/active-plan.md` — this is your contract. No plan? Run `/plan` first.
5. **Check autonomy**: Read `~/.claude/state/workspace.json` for this project's autonomy level.
   - Check for session override at `~/.claude/state/.session-autonomy` (if exists and <2h old, use it)
   - Fall back to workspace.json entry for this project's path

## Execute

Read and execute `~/.claude/programs/build.md` with the context loaded above.

### Quick Reference (the program has full detail)

1. **Detect scope** — no plan = think. Plan exists = build tasks. Plateau = experiment. Debt = fix.
2. **Execute the loop** — implement → score → keep/discard → extract learning → next.

### Experiment Mode

When running experiments, the key difference from random guessing:
- Read learnings BEFORE hypothesizing
- Classify as exploration/exploitation/mixed based on accumulated patterns
- Read experimentation level from workspace.json: conservative/balanced/aggressive
  - **conservative**: cite known patterns only, small deltas, exploration_floor=0.1
  - **balanced**: mix known + unknown, exploration_floor=0.3
  - **aggressive**: prefer unknown territory, bigger swings, exploration_floor=0.5
- Extract a learning from every experiment (kept or discarded)
- Update `~/.claude/knowledge/experiment-learnings.md` every 3 experiments
- TSV schema: `commit	score	delta	status	description	learning`

## After Every Task

```bash
# Score check (find RHINO_DIR from env or default paths)
"${RHINO_DIR:-$HOME/rhino-os}/bin/score.sh" . --json    # must not drop
```

Run project-specific checks if applicable:
- TypeScript: `npx tsc --noEmit`
- Build: `npm run build` / `pnpm build`

## After Sprint Completion

When all sprint tasks are complete, check milestone progress:

1. Read `.claude/plans/milestones.md` — get current milestone's Definition of Done
2. Check each DoD criterion against the current state of the project
3. If any DoD criteria are now met → check them off in `milestones.md` (change `- [ ]` to `- [x]`)
4. Update the `Progress:` line to reflect new count (e.g., `Progress: 2/3 done criteria met`)
5. If ALL DoD criteria are met:
   - Move the entire milestone block to the `## Shipped` section with ship date and summary
   - Print: `"Milestone complete: [name]! Run /plan --brainstorm for what's next."`
6. If milestone is NOT complete → print remaining DoD items as context for next sprint

## During Experiments

When experiments discover something interesting (a pattern, a user insight, a technique):
- Append to the `## Ideas (not commitments)` section of `milestones.md` with `(from experiment)` tag
- Format: `- [idea] — [which loop link it targets] (from experiment)`

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/builder.json`:
   - `next_move`: what should happen next
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Commit based on autonomy**:
   - `manual`: present results and ask before committing
   - `guided`: commit with `/smart-commit`
   - `autonomous`: commit and continue to next task

3. **Update workspace**: If score changed, update `last_score` in `~/.claude/state/workspace.json`
