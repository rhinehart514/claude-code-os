---
name: go
description: Autonomous build loop. Runs strategy→build→score→taste→repeat until plateau or manual stop. Replaces CLI rhino go. Say "/go" to start the loop.
user-invocable: true
---

# Go — Autonomous Build Loop

You are running the continuous build loop inline. This replaces the CLI `rhino go` command.

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

5. **Load or create go state**: `.claude/state/go-state.json`
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

### 1. Check for Plan
- If no `.claude/plans/active-plan.md` exists → run `/strategy` inline (read and execute `~/.claude/programs/strategy.md`)
- If plan exists → continue

### 2. Build Next Task
- Read the active plan, find the next uncompleted task
- Execute it (read and execute `~/.claude/programs/build.md` with task context)
- After each task: run score
  ```bash
  $RHINO_DIR/bin/score.sh . --json
  ```
  (Find RHINO_DIR from environment or default paths)

### 3. Score Check
- Record score in go-state.json
- If score dropped → revert with `git reset --hard HEAD~1`, log as discard
- If score flat for `plateau_threshold` consecutive iterations → **STOP**

### 4. Taste Check (every N iterations)
- Every `taste_every_n` iterations, run taste eval:
  ```bash
  $RHINO_DIR/bin/taste.mjs
  ```
- Pick the weakest dimension/feature from taste output
- If plan is complete AND taste ran → generate new plan targeting the weakness

### 5. Commit
- If autonomy is `autonomous` → auto-commit with conventional message
- If autonomy is `guided` → present changes and commit with `/smart-commit`

### 6. Update State
- Update `.claude/state/go-state.json` with iteration count, scores, focus
- Update brain: `~/.claude/state/brains/builder.json` with next_move

## Stop Conditions
- Max iterations reached
- Plateau detected (N flat scores)
- Score dropped to RED territory (below stage ceiling floor)
- User interrupts

## After Stopping
1. Update go-state.json with `"status": "stopped"`
2. Print summary:
   ```
   Go loop: [N] iterations
   Score: [start] → [end] (delta: [+/-X])
   Taste: [start] → [end] (if ran)
   Tasks completed: [N]
   Experiments: [kept]/[total]
   ```
3. Update brain with next_move for when loop resumes
