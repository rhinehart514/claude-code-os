---
description: "Quick task capture. /todo fix the login bug. /todo lists current todos. /todo done 1 marks one complete."
---

# /todo

Fast task capture. No planning, no ceremony. You think of something, you capture it.

## What to do

Parse `$ARGUMENTS` and route:

### No arguments → list todos
Read `.claude/plans/todos.yml`. Show each todo with its index, feature (if any), and status. Group by feature if features exist. Show count: "N todos (M done)."

If no todos exist: "No todos. Add one: `/todo fix the login bug`"

### `done [number]` → mark complete
Mark the todo at that index as done in todos.yml. Show what was completed.

### Anything else → add a todo
The entire argument is the todo text. Parse it for a feature name if one is mentioned (e.g., "/todo auth: fix the login bug" → feature: auth, text: "fix the login bug").

Add to `.claude/plans/todos.yml`:
```yaml
- text: "[the todo]"
  feature: "[feature if detected]"
  added: [date]
  status: todo
```

If todos.yml doesn't exist, create it.

Output: "Added: [todo text]" — one line, done.

### `clear` → remove completed todos
Remove all todos with `status: done` from todos.yml. Show how many were cleared.

## The point

Todos are lighter than plans. A plan is a strategic document with predictions and acceptance criteria. A todo is "fix the login bug." Both matter. Todos feed into `/plan` — when /plan runs, it reads todos.yml and may promote todos to plan tasks.

## If something breaks
- todos.yml doesn't exist: create it when adding the first todo
- todos.yml is malformed: recreate from scratch, noting what was lost

$ARGUMENTS
