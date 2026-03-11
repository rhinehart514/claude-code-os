# Who I Am
# TODO: Replace with your identity
Solo technical founder. Building [YOUR PROJECT] for [YOUR USERS].
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

## Skills — Your Commands

| Skill | What it does |
|-------|-------------|
| `/strategy` | What should we build? Maps creation loop, finds bottleneck, produces sprint plan. |
| `/build` | Build it. Reads plan, detects scope, executes, scores, keeps or discards. |
| `/experiment [dim]` | Autoresearch loop. Informed search, not random guessing. |
| `/eval` | Ship-readiness check. Deterministic + functional + ceiling tests. |
| `/design` | UI/UX audit against 11 taste dimensions. Finds violations, fixes them. |
| `/meta` | Self-improvement. Grades agents, applies fixes, tracks whether fixes worked. |
| `/product-eval` | Full product audit. "Would anyone use this?" |
| `/sweep` | Daily triage. GREEN/YELLOW/RED/GRAY across all projects. |
| `/scout` | Landscape intelligence. What works in 2026. |
| `/go` | Autonomous build loop. Strategy→build→score→taste→repeat. |
| `/score` | Structural quality score. |
| `/taste` | Visual product quality eval. |
| `/status` | System dashboard — all projects, agents, scores. |
| `/docs` | Generate context documents (platform-docs, architecture, styleguide). |
| `/council` | Agent brain summary — what each agent recommends. |
| `/smart-commit` | Conventional commit tied to active plan. |
| `/todofocus` | Am I on track? Scope enforcement. |
| `/setup` | Onboard a new project into rhino-os. |
| `/research-taste` | Research taste dimensions — patterns, exemplars, anti-patterns from the web. |

## The Loop
```
/strategy → sprint plan → /build (change → score → keep/discard) → /eval → /strategy
```

## Quick Reference
- Quick fix (typo, obvious bug, one-liner): just do it
- Non-trivial feature: `/build` (auto-starts in gate mode)
- Scope check: `/todofocus`
- Readiness check: `/eval`
- Commit: `/smart-commit`
- Market intelligence: `/scout`
- Daily triage: `/sweep`
- UI/UX work: `/design`
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
