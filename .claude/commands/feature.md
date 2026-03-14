---
description: "Work with features. /feature lists them. /feature auth shows auth status. /feature detect finds new ones. /feature new payments creates one with assertions."
---

# /feature

Features are named parts of your product — auth, dashboard, onboarding, scoring. Each has its own assertions, its own pass rate, its own score.

## What to do

Parse `$ARGUMENTS` and route:

### No arguments → list all features
Run `rhino feature` to show all features with pass rates. Then give one opinion: "**[worst feature]** is the weakest — `/plan [feature]` to work on it."

### Feature name → show status + suggest next action
Run `rhino feature [name]` to show that feature's assertions. Then:
- If all passing: "**[feature]** is green. Nothing to do here."
- If some failing: list the failing assertions and say "Run `/go [feature]` to fix these, or `/assert [feature]` to redefine what matters."
- If no assertions: "**[feature]** has no assertions. Run `/assert [feature]` to define what it must do."

### `detect` → find features in the codebase
Run `rhino feature detect`. Show what was found. For each detected feature that doesn't have assertions yet, suggest: "Run `/assert [feature]` to plant assertions."

### `new [name]` → create a feature with assertions
1. Ask: "What does **[name]** do? One sentence."
2. Based on the answer, generate 3-5 assertions scoped to `feature: [name]` in beliefs.yml
3. Use types eval.sh can check mechanically (file_check, content_check, self_check). Only use dom_check/playwright_task if a dev server is running.
4. Run `rhino eval .` to get baseline pass rate
5. Output: "[name] created with N assertions. Score: X/N passing. Run `/go [name]` to start building."

## The point

Features make the product concrete. Instead of "improve the product," you say "fix auth." Instead of a wall of 20 assertions, you see 4 features with their own scores. The user always knows where to look and what to work on.

## If something breaks
- `rhino feature` fails: read beliefs.yml directly and list unique `feature:` values
- No beliefs.yml: tell the user to run `/assert` first
- No features in beliefs.yml: all assertions are unscoped — suggest adding `feature:` fields

$ARGUMENTS
