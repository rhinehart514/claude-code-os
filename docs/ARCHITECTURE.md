# Architecture

## System Overview

rhino-os is an operating system layer for Claude Code. It transforms loose agent definitions, skills, and rules into a coherent, version-controlled system.

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
|  +-------------+  +---------------+  +-----------------+  |
|                    |   Hooks       |  |   Knowledge     |  |
|                    |               |  |                 |  |
|                    | ideation      |  | scout/          |  |
|                    | readonly      |  | design-engineer/|  |
|                    +---------------+  +-----------------+  |
|                                                            |
+-----------------------------------------------------------+
```

## Design Principles

### 1. Momentum Over Process
One agent (builder) handles gate → plan → build → doctor. No 4-agent pipeline. Skip modes you don't need.

### 2. Earn Existence
Every agent has evaluation criteria. If it doesn't produce value above its API cost, it gets revised or killed.

### 3. Knowledge Compounds
Learning agents (scout, design-engineer) read accumulated knowledge before acting, grade output after, and adapt.

### 4. Safety by Default
- Sweep requires human approval for RED items
- Budget-capped automated agents
- Hooks enforce ideation-mode readonly
- No agent auto-deploys or communicates externally

## Agent Dispatch Flow

```
User intent
    |
    +-- "what should I build?" --> strategist
    |
    +-- "what needs attention?" --> sweep (daily triage)
    |
    +-- "build this feature" --> builder (auto: gate -> plan -> build)
    |
    +-- "fix this bug" --> (just do it -- quick fix path)
    |
    +-- "this feels slow" --> builder "doctor"
    |
    +-- "am I on track?" --> /todofocus (skill)
    |
    +-- "ready to ship?" --> /eval (skill)
    |
    +-- "what's trending?" --> scout
    |
    +-- "how does my UI feel?" --> design-engineer
```

## File Layout

The repo mirrors `~/.claude/` structure. `install.sh` creates individual file symlinks (not directory symlinks) so you can have project-specific agents alongside OS agents.

```
~/rhino-os/                -->  ~/.claude/
  agents/*.md              -->  agents/*.md (symlinked)
  skills/*/SKILL.md        -->  skills/*/SKILL.md (symlinked)
  rules/*.md               -->  rules/*.md (symlinked)
  hooks/*                  -->  hooks/* (symlinked)
  config/CLAUDE.md         -->  CLAUDE.md (symlinked, unless user has their own)
  config/settings.json     -->  settings.json (merged, not replaced)
  config/config.json       -->  config.json (merged, not replaced)
  knowledge/_template/     -->  knowledge/ (seeded, not symlinked -- user data)
```
