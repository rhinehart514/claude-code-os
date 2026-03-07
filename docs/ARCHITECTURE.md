# Architecture

## System Overview

rhino-os is an operating system layer for Claude Code. Agents, skills, rules, hooks, and shared state — connected via the filesystem.

```
+-----------------------------------------------------------+
|                    CLAUDE CODE CLI                          |
+-----------------------------------------------------------+
|                                                            |
|  +-------------+  +---------------+  +-----------------+  |
|  |   Agents    |  |   Skills      |  |   Rules         |  |
|  |             |  |               |  |                 |  |
|  | strategist  |  | todofocus     |  | quality-bar     |  |
|  | builder     |  | smart-commit  |  | product-        |  |
|  | design-     |  | eval          |  | reasoning       |  |
|  |  engineer   |  | product-2026  |  |                 |  |
|  | scout       |  +---------------+  +-----------------+  |
|  | sweep       |                                           |
|  +---+---+-----+  +---------------+  +-----------------+  |
|      |   |         |   Hooks       |  |   Knowledge     |  |
|      |   |         |               |  |                 |  |
|      v   v         | ideation      |  | scout/          |  |
|  +---+---+-----+   | readonly      |  | design-engineer/|  |
|  |   State     |   +---------------+  +-----------------+  |
|  | (shared)    |                                           |
|  | sweep-      |                                           |
|  | latest.md   |                                           |
|  +-------------+                                           |
+-----------------------------------------------------------+
```

## How Agents Communicate

No agent can invoke another agent. Instead: **filesystem as IPC.**

```
sweep runs
  → writes ~/.claude/state/sweep-latest.md (structured findings)
  → executes GREEN/YELLOW items inline (doesn't just classify)

builder runs (later, same day or next day)
  → reads state/sweep-latest.md in Step 0
  → if sweep flagged RED items for this project, auto-selects mode
  → no human copy-paste needed

strategist runs
  → reads state/sweep-latest.md (what's on fire?)
  → reads knowledge/scout/knowledge.md (market context)
  → doesn't re-scan projects sweep already covered

design-engineer runs
  → reads state/sweep-latest.md (design-related items?)
  → loads refs selectively by mode (saves context)
```

**The rule:** Sweep is the entry point. It writes state. Other agents read it. The user just invokes agents — the context flows through files.

## Design Principles

### 1. Momentum Over Process
One agent (builder) handles gate → plan → build → doctor. No 4-agent pipeline. Skip modes you don't need.

### 2. Minimal Manual Input
Agents read shared state from prior runs. The user doesn't relay information between agents. Sweep writes findings, builder reads them. Mode detection is automatic.

### 3. Context Efficiency
Agents load only what they need for the current mode. Design-engineer in audit mode doesn't load design-taste.md. Knowledge files have enforced max sizes with pruning rules. Every token of context should be working.

### 4. Knowledge Compounds (with limits)
Learning agents read accumulated knowledge, grade output, and adapt. But knowledge files have max sizes (150 lines for knowledge.md, 80 for search-strategy.md). Agents prune stale entries at end of session. Unbounded knowledge degrades performance.

### 5. Safety by Default
- Sweep requires human approval for RED items
- Budget-capped automated agents
- Hooks enforce ideation-mode readonly
- No agent auto-deploys or communicates externally

## File Layout

```
~/rhino-os/                  →  ~/.claude/
  agents/*.md                →  agents/*.md (symlinked)
  agents/refs/*.md           →  agents/refs/*.md (symlinked — reference docs)
  skills/*/SKILL.md          →  skills/*/SKILL.md (symlinked)
  rules/*.md                 →  rules/*.md (symlinked)
  hooks/*                    →  hooks/* (symlinked)
  config/CLAUDE.md           →  CLAUDE.md (symlinked, unless user has their own)
  config/settings.json       →  settings.json (merged, not replaced)
  config/config.json         →  config.json (merged, not replaced)
  knowledge/_template/       →  knowledge/ (seeded, not symlinked — user data)
                                state/ (created by install, written by agents)
                                plans/ (created by install, written by builder)
```

## State Directory Convention

`~/.claude/state/` holds ephemeral inter-agent state. Files here are overwritten each run.

| File | Written By | Read By | Contents |
|------|-----------|---------|----------|
| `sweep-latest.md` | sweep | builder, strategist, design-engineer | Structured triage: executed items, pending RED items with suggested agent+mode, focus recommendation |

State files older than 7 days are stale. Sweep deletes them during system audit.

## What This Is Not

This is not a process manager, scheduler, or runtime. There is no daemon. Agents are markdown files. State is files. The "OS" is a convention for how those files connect. The install script creates symlinks. That's the entire infrastructure.
