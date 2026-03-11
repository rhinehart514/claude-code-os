---
name: council
description: Agent brain summary. Shows each agent's next_move, bias awareness, and last run time. Quick view of what every agent thinks should happen next. Say "/council" anytime.
user-invocable: true
---

# Council — Agent Brain Summary

Read all agent brain files and present a unified view of what each agent recommends.

## Execute

Read every `.json` file in `~/.claude/state/brains/`:

For each brain file, extract:
- `agent`: agent name
- `next_move`: what this agent thinks should happen next
- `bias_awareness`: what this agent tends to get wrong
- `last_run`: when it last ran
- `updated`: when brain was last updated

## Present

```
=== Agent Council ===

[agent-name] (last run: [relative time])
  Next move: [next_move]
  Bias: [bias_awareness]

[agent-name] (last run: [relative time])
  Next move: [next_move]
  Bias: [bias_awareness]

...
```

## Analysis

After listing all agents:

1. **Consensus**: Do multiple agents agree on direction? Highlight convergence.
2. **Conflicts**: Do any agents disagree? Flag the tension.
3. **Staleness**: Any agents not run in >7 days? Flag as potentially outdated.
4. **Recommendation**: Based on the council, what's the highest-leverage next action?

Keep the analysis brief — 2-3 sentences max.
