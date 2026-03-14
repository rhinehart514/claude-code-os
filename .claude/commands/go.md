---
description: "Fully autonomous mode. Plan, predict, build, measure, update model, repeat. Accepts a feature name to scope: /go auth"
---

# /go

Autonomous creation loop. You plan, build, measure, and learn — no human in the loop until you hit a wall or plateau.

## Feature scoping

`$ARGUMENTS` can contain one or more feature names: `/go auth`, `/go auth scoring`, `/go auth scoring cli`.

**Single feature**: scope everything to that feature — tasks, assertions, files.

**Multiple features**: work on them sequentially, one at a time, measuring after each.

**No features**: execute the full plan. Work through tasks in priority order.

For each feature:
- Only work on tasks for that feature
- Only measure with `rhino eval . --feature [name]`
- If no plan exists, run `/plan [feature]` logic first

## Tools to use

**Use TaskList/TaskUpdate** to track progress. At loop start, call TaskList to find tasks. Mark in_progress when starting, completed when done. This replaces checking plan.yml checkboxes.

**Use WebFetch/WebSearch for research detours.** When you hit an unknown:
- Search for solutions, docs, examples
- Fetch relevant pages
- Update experiment-learnings.md with findings

## The loop

```
Read tasks → Pick task → Predict → Build → Measure → Update model → Next task
```

### 1. Pick the task
Call TaskList. Find next task with status todo.

### 2. Predict
```
I predict: [specific outcome]
Because: [cite experiment-learnings.md or declare exploration]
I'd be wrong if: [falsification condition]
```
Log to `~/.claude/knowledge/predictions.tsv`.

### 3. Build
Execute the task. Follow `mind/standards.md`.

### 4. Measure
Run `rhino score .` after every task. The score IS the assertion pass rate.

- **Assertion regressed** (was passing, now failing) → revert, log why
- **Assertion progressed** (was failing, now passing) → keep
- **Score up or flat** → keep
- **Score down >15** → revert immediately

### 5. Update model
Fill in prediction result. If wrong, update experiment-learnings.md.

### 6. Mark done
TaskUpdate → completed. Pick next task. Loop.

## Plateau handling
If score hasn't improved in 3 consecutive tasks:
1. Stop building — current approach is exhausted
2. Research inline (WebSearch, read experiment-learnings.md Unknown Territory)
3. If research produces a hypothesis → create new task, continue
4. If no hypothesis → stop the loop

## Crash recovery
- **Trivial** (syntax error, missing import): fix inline, retry once
- **Fundamental** (missing package, design flaw): skip task
- **3 consecutive crashes**: stop the loop, ask founder

## When the loop ends
Output:
- Tasks completed (with kept/reverted counts)
- Score trajectory (start → end)
- Prediction accuracy for this session
- What the bottleneck is NOW

**Next action** (pick one based on outcome):
- Score improved → "Run `/eval full` to validate before shipping."
- Score plateaued → "Run `/ideate [feature]` — current approach is exhausted."
- All tasks done → "Run `/ship` to deploy, or `/plan` for next session."
- New unknowns surfaced → "Run `/research [topic]` to fill the gap."

## What you never do
- Skip the prediction step
- Continue past plateau without researching
- Modify score.sh or eval.sh during the loop (immutable eval harness)

## If something breaks
- `rhino score .` fails: use git diff size as proxy, do NOT skip revert check
- No plan exists: run /plan logic inline first
- Dirty git state: `git stash` before starting

$ARGUMENTS
