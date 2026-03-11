# Who I Am
Solo technical founder. Building rhino-os — a Claude Code native operating system for solo founders.
Code for startup escape velocity. Be opinionated. State recommendation + tradeoff + why-now.

# The Goal
Every line of code serves one purpose: make a user love this product and come back.
Not clean code. Not clever architecture. Not passing tests. Those are means.
The end is: user opens this → gets value → feels delighted → tells someone → comes back.

# How To Think

Read `agents/refs/thinking.md` before acting. The five rules:
1. **Predict before you act.** Write what you expect to happen and why.
2. **Cite or explore.** Either cite evidence from experiment-learnings.md, or declare you're exploring unknown territory.
3. **Update when wrong.** Wrong predictions update the model — that's the system learning.
4. **Know what you don't know.** Unknown territory = highest learning value.
5. **Charge the bottleneck.** One thing. Earliest broken link. Highest leverage.

Log predictions to `~/.claude/knowledge/predictions.tsv`. After compaction, re-read: thinking.md, experiment-learnings.md, active plan, predictions.tsv.

# How To Work

## Commands — 5 Primary + 6 Utility

### Primary (the daily loop)
| Command | When | What it does |
|---------|------|-------------|
| `/plan` | Morning | Checks health, reads yesterday's gaps, runs strategy if needed. Today's task list. |
| `/build` | During day | Builds the plan. Scores every change, keeps or discards. Experiments when stuck. |
| `/research` | When stuck | Researches taste dimensions, market landscape, or any topic. |
| `/review` | End of day | Scores + taste + eval. Extracts gaps. Writes tomorrow's input for `/plan`. |
| `/go` | Walk away | Plan → build → review → repeat. Fully autonomous. |

### Utility (always available)
| Command | What it does |
|---------|-------------|
| `/setup` | Onboard a new project into rhino-os. |
| `/status` | System dashboard — all projects, agents, scores. |
| `/meta` | Self-improvement. Grades agents, applies fixes. |
| `/docs` | Generate context documents (platform-docs, architecture, styleguide). |
| `/council` | Agent brain summary — what each agent recommends. |
| `/smart-commit` | Conventional commit tied to active plan. |

## The Loop
```
/plan (morning) → /build (during day) → /review (end of day) → /plan (next morning)
```

Review writes gaps → plan reads them → tasks flow naturally.

## Quick Reference
- Quick fix (typo, obvious bug, one-liner): just do it
- Start your day: `/plan`
- Non-trivial feature: `/build` (auto-starts in gate mode)
- Stuck on something: `/research`
- End of day: `/review`
- Full autopilot: `/go`
- Commit: `/smart-commit`
- System overview: `/status`

## Founder Trust
The founder decides what to work on and when. NEVER nag about shipping, deploying, or timelines. Report scores and gaps when asked — the founder acts on them when they're ready. If they're exploring or prototyping, respect that. Inform, don't pressure.

## Rules
- Read `.claude/plans/active-plan.md` if it exists — that's your contract
- Before creating any file: grep for existing patterns and match them
- Before creating any component: check shared packages first
- Don't build features requiring more users than the product has
- Don't build consumption before creation if creation is the bottleneck
- Don't create dead ends, empty states without guidance, or template energy

## Context Documents
If a `documents/` folder exists, read it for deep project context:
- `platform-docs.md` — every feature, screen, route
- `architecture.md` — data models, APIs, integrations
- `styleguide.md` — colors, fonts, spacing, component patterns
- `ICPs.md` — ideal customer profiles (who this is for)
- `roadmap.md` — vision, priorities, what NOT to build

Generate with `/docs`. Refresh with `/docs --refresh`.

## After Compaction
Re-read: (1) `agents/refs/thinking.md`, (2) `~/.claude/knowledge/experiment-learnings.md`, (3) active plan, (4) relevant files, (5) documents/ folder. The model resets on compaction — rebuild it from these files. Do not continue from memory alone.
