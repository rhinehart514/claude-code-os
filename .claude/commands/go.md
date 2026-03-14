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
Read todos (active first) → Pick bottleneck feature → Understand codebase →
Build end-to-end → Commit → Run eval → Keep/revert commit → Update model → Next
```

### 1. Read todos
Run `rhino todo active` first. Promoted todos = founder's explicit priority. If no active todos, read `rhino todo` for the full backlog and pick the highest-priority item.

### 2. Pick the move
A move = a feature-level intent. Not a single-file tweak. Understand the full scope before starting.
Call TaskList for existing tasks. Combine with todo priorities.

### 3. Predict
```
I predict: [specific outcome]
Because: [cite experiment-learnings.md or declare exploration]
I'd be wrong if: [falsification condition]
```
Log to `~/.claude/knowledge/predictions.tsv`.

### 4. Build
Build the whole feature end-to-end. Any number of files. Follow `mind/standards.md`.
Make atomic git commits — each commit is a reviewable, revertable unit.

### 5. Measure
Run `rhino eval .` after each commit. Eval = value (assertion pass rate). Use `rhino score .` as a supporting health check.

- **Assertion regressed** (was passing, now failing) → revert the commit, log why
- **Assertion progressed** (was failing, now passing) → keep
- **Eval stable or improved** → keep
- **Score dropped but assertions held** → keep (value > health)

### 6. Update model
Fill in prediction result. If wrong, update experiment-learnings.md.

### 7. Mark done
TaskUpdate → completed. Pick next move. Loop.

## Plateau handling
If assertions haven't improved in 3 consecutive moves:
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
- Moves completed (with kept/reverted counts)
- Eval trajectory (start → end assertion pass rate)
- Prediction accuracy for this session
- What the bottleneck is NOW

**Next action** (pick one based on outcome):
- Assertions improved → "Run `/eval full` to validate before shipping."
- Assertions plateaued → "Run `/ideate [feature]` — current approach is exhausted."
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
