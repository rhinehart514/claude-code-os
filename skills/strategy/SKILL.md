---
name: strategy
description: Product strategy with causal diagnosis. Maps the creation loop, finds the earliest broken link, diagnoses WHY, reads experiment learnings, produces a sprint plan. Say "/strategy" to decide what to build next.
user-invocable: true
---

# Strategy — What Should We Build?

## Setup

1. **Read your brain**: `~/.claude/state/brains/strategist.json` — what's your next_move?
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what works in this codebase?
3. **Read landscape model**: `~/.claude/agents/refs/landscape-2026.md` — what wins in 2026?
4. **Read workspace**: `~/.claude/state/workspace.json` — project stage, autonomy, experimentation level, portfolio
5. **Check for session override**: `~/.claude/state/.session-autonomy` (if <2h old, use it)

## Execute

Read and execute `~/.claude/programs/strategy.md` with the context loaded above.

### Quick Reference (the program has full detail)

1. **Map the product loop**: Create → Share → Discover → Engage → Return. Score each link.
2. **Find the earliest broken link** — not the lowest score, the earliest bottleneck.
3. **Diagnose WHY** — trace the user flow through code.
4. **Plan the sprint** — target the bottleneck, ordered by dependency.

### Portfolio Mode

If workspace.json has multiple active projects, also run portfolio evaluation:
- BUY/HOLD/SELL assessment for each project
- Focus recommendation
- Write portfolio assessment to `~/.claude/state/portfolio.json`

## Output

Write to `.claude/plans/active-plan.md` with: product model, bottleneck, diagnosis, tasks, "do not build" list.
Write product model to `.claude/plans/product-model.md`.

**Do NOT edit CLAUDE.md** — that's the user's config.

## Teardown

1. **Update brain**: Write to `~/.claude/state/brains/strategist.json`:
   - `next_move`: what direction the sprint should take
   - `last_run`: current ISO timestamp
   - `updated`: current ISO timestamp

2. **Autonomy behavior**:
   - `manual`: present the plan for approval before writing
   - `guided`: write the plan, present summary
   - `autonomous`: write the plan and proceed to /build
