# Who I Am
# TODO: Replace with your identity
Solo technical founder. Building [YOUR PROJECT] for [YOUR USERS].
Code for startup escape velocity. Be opinionated. State recommendation + tradeoff + why-now.

# The Goal
Every line of code serves one purpose: make a user love this product and come back.
Not clean code. Not clever architecture. Not passing tests. Those are means.
The end is: user opens this → gets value → feels delighted → tells someone → comes back.

# How To Work

## Before Everything
- If unsure what to work on: use `strategist` agent
- If codebase feels slow or broken: use `builder` agent in doctor mode

## Before Coding
- If this is a non-trivial feature: use `builder` agent (auto-starts in gate mode)
- If quick fix (typo, obvious bug, one-liner): just do it

## During Implementation
- Read `.claude/plans/active-plan.md` if it exists — that's your contract
- Before creating any file: grep for existing patterns and match them exactly
- Before creating any component: check shared packages first
- If scope is growing: use `/todofocus` to check alignment
- If your task is done: use `/todofocus` to confirm and get next task

## After Implementation
- Use `/eval` to check ship-readiness
- If eval passes: use `/smart-commit` for conventional commits tied to the plan
- If eval fails: fix issues, re-run eval

## Rules
- When coding, read `.claude/rules/coding.md` if it exists
- When testing, read `.claude/rules/testing.md` if it exists
- When doing product work, the `product-2026` skill loads automatically
- For each repo: read THAT repo's CLAUDE.md for project-specific context

## What NOT To Do
- Don't start editing files before thinking through value prop + workflow impact (unless quick fix)
- Don't create components that exist in shared packages
- Don't introduce dead ends, empty states without guidance, or internal terminology
- Don't build features requiring more users than the product currently has
- Don't build consumption before creation if creation is the bottleneck
- Don't assume — if context is missing, re-read the plan and relevant files

## How To Invoke Agents
Say "use [agent name]" or just describe the need:
- "what should I work on?" → strategist
- "should we build this?" / "plan this" / "build task 1" / "fix the debt" → builder
- "am I on track?" → /todofocus
- "ready to ship?" → /eval
- "what's trending?" → scout
- "what needs attention?" → sweep
- "how does my UI feel?" / "fix the design" → design-engineer

## After Compaction
Re-read: (1) your task plan, (2) relevant files to the current task. Do not continue from memory alone.
