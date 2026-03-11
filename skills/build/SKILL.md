---
name: build
description: "The build loop. Reads the active plan, detects scope, executes, measures, keeps or discards. Use /build to execute a plan, /build --experiment [dimension] to run the autoresearch loop."
user-invocable: true
---

# Build — Execute the Plan

## Flags

| Usage | What happens |
|-------|-------------|
| `/build` | Execute the active plan. Auto-detects scope. |
| `/build --experiment [dimension]` | Autoresearch loop on a specific dimension. |
| `/build --experiment` (no dimension) | Auto-detect weakest dimension, experiment on that. |

## Setup

1. **Read active plan**: `.claude/plans/active-plan.md` — your contract. No plan? Run `/plan` first.
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what works here.
3. **Read active plan or product model**: `.claude/plans/product-model.md` — what to target.

### Experiment setup (when `--experiment`)

Also load:
- **Latest taste report**: `.claude/evals/reports/taste-*.json` — current scores per dimension.
- **Experimentation level** from `~/.claude/state/workspace.json`:
  - conservative (moonshot_every_n: 10)
  - balanced (moonshot_every_n: 5, default)
  - aggressive (moonshot_every_n: 3)

## Execute

Read and execute `programs/build.md` with the context loaded above.

**Standard build**: Detect scope → execute → score → keep/discard → extract learning → next.

**Experiment mode**: Autoresearch loop. Each experiment builds knowledge.

```
Read learnings → Generate hypothesis (cite source) → Implement → Measure → Keep/Discard → Extract learning → Repeat
```

### TSV schema
`commit	score	delta	status	description	learning`

### Stop/pivot signals
- 3 discards in a row → re-read product model, switch change TYPE
- 5 keeps in a row → increase ambition
- Diminishing returns → switch to next-weakest dimension

## After Every Task

```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/score.sh" . --json    # must not drop
```

Run project-specific checks if applicable (tsc, build).

## After Sprint Completion

Check milestone progress in `.claude/plans/milestones.md` if it exists. Update DoD criteria.

## Teardown

1. **Update brain**: `~/.claude/state/brains/builder.json` — next_move, last_run, updated
2. **Commit based on autonomy**: manual=ask, guided=smart-commit, autonomous=commit+continue
3. **Update workspace**: last_score in `~/.claude/state/workspace.json`
