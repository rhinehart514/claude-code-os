---
name: plan
description: Morning command. Checks sweep health, reads yesterday's review gaps, runs strategy if needed. Produces today's prioritized task list. Say "/plan" to start your day.
user-invocable: true
---

# Plan — Start Your Day

Your morning command. One output: what to work on today and why.

## Setup

1. **Read workspace**: `~/.claude/state/workspace.json` — project stage, autonomy, experimentation level
2. **Check autonomy**: session override at `~/.claude/state/.session-autonomy` (if <2h old, use it), else workspace.json
3. **Read milestones**: `.claude/plans/milestones.md` — current milestone, DoD progress, Ideas backlog
4. **Read brains**: `~/.claude/state/brains/strategist.json`, `~/.claude/state/brains/sweep.json` — what do agents recommend?
5. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what works in this codebase?

## Execute

### Path A: Active plan with uncompleted tasks

If `.claude/plans/active-plan.md` exists AND has unchecked tasks (`- [ ]`):

1. Read `.claude/plans/milestones.md` if it exists — get milestone name + DoD progress
2. Show sprint progress: X/Y tasks complete
3. Show milestone progress: `Milestone: [name] — [X/Y done criteria]`
4. Identify the next uncompleted task
5. Check if any score integrity warnings exist (`.claude/cache/score-cache.json`)
6. Check if yesterday's review left gaps in `.claude/plans/review-gaps.md`
   - If gaps exist AND they relate to the current sprint → surface as context
   - If gaps suggest a pivot → flag it but don't override the plan
7. If sprint is complete but milestone has unchecked DoD items → trigger Path D (brainstorm)
8. **Output**: "Continue sprint. Next task: [task]. [context from gaps if relevant]."

### Path B: No plan or all tasks complete

1. **Quick health check** (sweep logic inline):
   - Git status: uncommitted work? stale branches?
   - Score freshness: when was `rhino score .` last run?
   - Build status: does `npm run build` / `pnpm build` pass? (skip if no build script)
   - Classify: GREEN / YELLOW / RED
   - If RED → surface the blocker. Don't plan new work on a broken foundation.

2. **Read yesterday's review**:
   - Read `.claude/plans/review-gaps.md` if it exists
   - These gaps are the primary input to today's plan
   - If no review-gaps.md exists → that's fine, strategy will scan from scratch

3. **Run strategy** (inline):
   - Read and execute `~/.claude/programs/strategy.md` with:
     - Review gaps as the primary signal (if they exist)
     - Health check results as constraints (if RED/YELLOW items found)
     - Brain recommendations as secondary input
   - Strategy produces the sprint plan at `.claude/plans/active-plan.md`

4. **Read milestones**: If `.claude/plans/milestones.md` exists, link new sprint to current milestone:
   - Add sprint entry under `### Sprints` in milestones.md
   - Show milestone context in output

5. **Output**: Sprint plan summary + today's top 3 tasks + any health warnings

### Path D: Brainstorm

Triggered by `/plan --brainstorm` OR when Path A detects current sprint is complete but milestone isn't done.

1. Read `.claude/plans/milestones.md` — current milestone, Definition of Done, Ideas section
2. Read `~/.claude/knowledge/experiment-learnings.md` + product model (`.claude/plans/product-model.md`) + landscape model (`agents/refs/landscape-2026.md`)
3. Read product-eval reports (`.claude/evals/reports/product-eval-*.md`) for competitive/identity gaps
4. Generate **5 options** across three strategic layers — not just "what to build":
   - At least 1 **build option** (product change targeting a loop link)
   - At least 1 **messaging option** (reframe, reposition, new pitch — no code required)
   - At least 1 **landscape play** (competitive positioning, wedge strategy, partnership, distribution channel)
   - Each option includes: what it does (user-visible), which layer (build/messaging/landscape), which loop link it targets, estimated effort (1-3 sessions), risk/reward, a real product that did something similar
5. Present options. Founder picks or riffs → chosen direction becomes next sprint, linked to current milestone
6. Update `milestones.md`:
   - Append any interesting rejected ideas to the Ideas section
   - Add chosen sprint to the Sprints section under current milestone
7. Write sprint to `.claude/plans/active-plan.md` using full strategy output format (includes messaging + positioning sections)

### Path C: Learning agenda (first-time project)

If `.claude/plans/learning-agenda.md` exists with unchecked graduation criteria:
1. Show learning progress
2. Suggest running `/build` in experiment mode
3. Do NOT run strategy yet — the learning agenda must graduate first

## Output

Always ends with a clear, actionable task list:

```
## Today

Milestone: [name] — [X/Y done criteria]
Sprint: [X/Y tasks] or [new sprint started]
Health: [GREEN/YELLOW/RED]

1. [most important task] — [why, citing gap/bottleneck]
2. [second task] — [why]
3. [third task] — [why]
```

## Teardown

1. **Update brains**:
   - `~/.claude/state/brains/strategist.json`: update `next_move`, `last_run`, `updated`
   - `~/.claude/state/brains/sweep.json`: update `next_move`, `last_run`, `updated` (if health check ran)

2. **Autonomy behavior**:
   - `manual`: present plan for approval
   - `guided`: write plan, present summary, wait for "let's build"
   - `autonomous`: write plan and proceed to `/build`
