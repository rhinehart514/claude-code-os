---
name: go
description: Autonomous build loop. Runs plan→build→review→repeat until plateau or manual stop. Walk away and let it work. Say "/go" to start the loop.
user-invocable: true
---

# Go — Autonomous Build Loop

You are running the continuous build loop inline. Plan → build → review → repeat.

## Setup

1. **Check autonomy**: Read `~/.claude/state/workspace.json` for this project's autonomy level.
   - `manual` → refuse. Say: "Autonomous loop requires guided or autonomous mode. Run /setup to change."
   - `guided` → run, but pause at major decisions (strategy pivots, discard decisions)
   - `autonomous` → run fully autonomous

2. **Read your brain**: `~/.claude/state/brains/builder.json` — what's your next_move?
3. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md`
4. **Read go config from rhino.yml** (or use defaults):
   - `go.max_iterations`: 10
   - `go.plateau_threshold`: 3 consecutive flat scores before stopping
   - `go.taste_every_n`: 3 (run taste eval every N iterations)

5. **Read milestones**: `.claude/plans/milestones.md` — current milestone + DoD for stop condition
6. **Load or create go state**: `.claude/state/go-state.json`
   ```json
   {
     "iteration": 0,
     "last_score": null,
     "last_taste": null,
     "focus": "",
     "scores": [],
     "started": "[ISO timestamp]",
     "last_updated": "[ISO timestamp]",
     "status": "running"
   }
   ```

## The Loop

For each iteration (up to max_iterations):

### 1. Plan (iteration 1 or plan completed)
- If no `.claude/plans/active-plan.md` exists → run plan logic inline:
  - Read `~/.claude/programs/strategy.md` and execute
  - Read `.claude/plans/review-gaps.md` if it exists (from previous /review)
- If plan exists with remaining tasks → continue

### 2. Build Next Task
- Read the active plan, find the next uncompleted task
- Execute it (read and execute `~/.claude/programs/build.md` with task context)
- After each task: run score
  ```bash
  $RHINO_DIR/bin/score.sh . --json
  ```
  (Find RHINO_DIR from environment or default paths)

### 3. Score + Milestone Check
- Record score in go-state.json
- If score dropped → revert with `git reset --hard HEAD~1`, log as discard
- If score flat for `plateau_threshold` consecutive iterations → **STOP**
- If all sprint tasks done → check milestone DoD in `.claude/plans/milestones.md`:
  - Check off any newly-met criteria
  - If ALL DoD met → mark milestone shipped, **STOP** (milestone complete)

### 4. Review (every N iterations or plan complete)
- Every `taste_every_n` iterations, run review logic inline:
  - Run `$RHINO_DIR/bin/score.sh . --json` for structural score
  - Run `$RHINO_DIR/bin/taste.mjs` for visual eval (if UI exists)
  - Extract gaps, write to `.claude/plans/review-gaps.md`
- If plan is complete → run full review, then generate new plan from gaps

### 5. Commit
- If autonomy is `autonomous` → auto-commit with conventional message
- If autonomy is `guided` → present changes and commit with `/smart-commit`

### 6. Update State
- Update `.claude/state/go-state.json` with iteration count, scores, focus
- Update brain: `~/.claude/state/brains/builder.json` with next_move

## Stop Conditions
- **Milestone complete** — all DoD criteria in `milestones.md` are checked off
- Max iterations reached
- Plateau detected (N flat scores)
- Score dropped to RED territory (below stage ceiling floor)
- User interrupts

## After Stopping
1. Update go-state.json with `"status": "stopped"`
2. Run final review (score + taste + gap extraction)
3. Check milestone DoD in `.claude/plans/milestones.md` — update any newly-met criteria
4. Write `.claude/plans/review-gaps.md` for next session's `/plan`
5. Print summary:
   - If milestone completed:
     ```
     Milestone shipped: [name]
     [N iterations, X tasks completed]
     Score: [start] → [end]
     Taste: [start] → [end] (if ran)

     Run /plan --brainstorm to decide what's next.
     ```
   - Otherwise:
     ```
     Go loop: [N] iterations
     Milestone: [name] — [X/Y done criteria]
     Score: [start] → [end] (delta: [+/-X])
     Taste: [start] → [end] (if ran)
     Tasks completed: [N]
     Experiments: [kept]/[total]

     Tomorrow: run /plan to pick up where this left off.
     ```
6. Update brain with next_move for when loop resumes
