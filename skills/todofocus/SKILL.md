---
name: todofocus
description: Task focus and scope enforcement. Reads active plan, checks current task, detects drift, and blocks tangential work. Also serves as a lightweight "am I on track?" check. Say "/todofocus" anytime.
user-invocable: true
---

# Task Focus + Scope Check

1. Read `.claude/plans/active-plan.md`
2. Identify the current task being worked on
3. Run `git diff --stat` to see what files have changed
4. Compare current file changes against that task's scope

## Scope Check
For each changed file not in the plan:
- Is this a necessary dependency? (OK)
- Is this scope creep? (flag it)
- Is this a bug fix discovered during work? (OK, note it)

## Rules
- If working on something NOT in the current task → flag it and recommend stopping
- If the current task is done → suggest the next task from the plan
- If no plan exists → suggest creating one with the architect agent
- If all tasks are done → suggest running eval-runner
- If scope is growing beyond the plan → recommend re-scoping with architect

## Output Format
```
Current task: [task name]
Progress: [X/Y tasks complete]
On track: [yes/no]
Drift: [none / minor (N files outside plan) / scope creep — stop and re-scope]
Next: [next action]
```
