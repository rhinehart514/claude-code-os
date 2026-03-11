# rhino-os

**Your AI coding agent is powerful. But it has no memory, no strategy, and no taste.**

rhino-os fixes that. It's a brain for your AI coding agent — it decides what to build, builds it, scores the result, and learns from every cycle. You point it at a project and walk away.

Inspired by [Karpathy's autoresearch](https://github.com/karpathy/autoresearch) — the same modify-measure-keep/discard loop, applied to product development instead of ML training.

![rhino-os overview](docs/screenshots/overview-hero.png)

## The problem

AI coding agents (Claude Code, OpenClaw, etc.) are incredible at executing tasks. But they:
- Don't know what to build next
- Can't tell if what they built is actually good
- Forget everything between sessions
- Have no strategy — they just do what you tell them

rhino-os turns a task executor into a **self-improving product engineer.**

## How it works (30 seconds)

```
You: "/plan"
rhino-os: checks health, reads yesterday's gaps, writes a sprint plan

You: "/build"
rhino-os: builds it, scores every change, keeps or discards, logs what it learned

You: "/go"
rhino-os: plan → build → review → repeat. walk away and go to sleep.
```

That's it. Three commands.

## The loop

```
plan → build → review → plan (next day)
  ↑                         |
  └── review gaps feed ─────┘
```

Every cycle, rhino-os gets smarter about your project. It remembers what worked, what didn't, and why.

## What's inside

### The daily loop (5 commands)

| Command | When | What it does |
|---------|------|-------------|
| `/plan` | Morning | Checks health, reads yesterday's gaps, runs strategy. Today's task list. |
| `/build` | During day | Builds the plan, scores every change, keeps good ones, discards bad ones |
| `/research` | When stuck | Researches taste dimensions, market landscape, or any topic |
| `/review` | End of day | Scores + taste + eval. Extracts gaps. Writes tomorrow's input for `/plan`. |
| `/go` | Walk away | Plan → build → review → repeat. Full autopilot. |

### Measurement (CLI)

| Command | What it does |
|---------|-------------|
| `rhino score .` | Instant structural quality check (2 seconds, free) |
| `rhino taste .` | Visual eval — takes screenshots, scores what it *sees* like a real user |
| `rhino bench` | Self-eval benchmark — runs the test suite across 3 tiers |
| `rhino status` | System health — workspace, scores, sweep state |

### System

| Command | What it does |
|---------|-------------|
| `rhino setup .` | Onboard a project — detect type, configure, baseline score |
| `rhino install` | Install/update rhino-os — symlinks, hooks, settings |
| `rhino config` | Show current configuration from rhino.yml |
| `rhino dashboard` | Score + experiments + evals unified view |

### Utility commands

| Command | What it does |
|---------|-------------|
| `/setup` | Onboard a new project |
| `/status` | System dashboard — all projects, scores |
| `/meta` | Self-improvement loop. Grades the system, applies one fix, verifies it worked |
| `/docs` | Generate context documents (platform-docs, architecture, styleguide) |
| `/council` | Agent brain summary — what each agent recommends |
| `/smart-commit` | Conventional commit tied to active plan |

## Proof it works

Real data from real agent runs. Not vanity metrics.

### Visual taste eval — 11 dimensions scored by Claude vision

The system takes Playwright screenshots of your app and scores what it *sees*. 40/100 here. Honest.

![Taste radar](docs/screenshots/taste-radar.png)

### Ship readiness — the system said NOT READY

Scored 0.35/1.0. Identified "Day 3 return" at 0.2 as the critical bottleneck. The strategist wrote a sprint plan targeting exactly that gap. It didn't tell us what we wanted to hear.

![Product eval](docs/screenshots/product-eval.png)

### Self-healing — 3 dead agents → 5/5 operational

Meta found that 3 agents were silently crashing. It diagnosed the root cause (CLAUDECODE env var blocking nested sessions), applied the fix, and verified all 5 agents came back online.

![Self-healing timeline](docs/screenshots/self-healing.png)

### System architecture — lean by design

Four programs. Five reference docs. Five internal skills. Zero agent wrappers. Every file fits in working context.

![Architecture](docs/screenshots/architecture.png)

See [all 10 charts with real data →](docs/graphs.html)

## Install (2 minutes)

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
```

Then in any project:

```bash
cd ~/your-project
rhino setup .

# Open Claude Code and say:
#   "run strategy"  — to plan
#   "let's build"   — to build
#   "rhino go ."    — to do both
```

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

## Works with OpenClaw too

If you use [OpenClaw](https://github.com/openclaw/openclaw), rhino-os skills work out of the box.

**Why:** Both systems use the same `skills/*/SKILL.md` format. rhino-os ships 11 skills that OpenClaw can pick up directly — including `/plan`, `/build`, `/review`, `/research`, `/go`, `/meta`, and more.

**How to use with OpenClaw:**

```bash
# 1. Clone rhino-os
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os

# 2. Copy the skills you want into your OpenClaw workspace
cp -r ~/rhino-os/skills/build ~/your-openclaw-workspace/skills/
cp -r ~/rhino-os/skills/strategy ~/your-openclaw-workspace/skills/

# 3. Copy the programs they reference
cp -r ~/rhino-os/programs ~/your-openclaw-workspace/

# 4. Copy the scoring script
cp ~/rhino-os/bin/score.sh ~/your-openclaw-workspace/bin/

# 5. Use them — say "/build" or "/strategy" in any OpenClaw channel
```

The scoring system (`score.sh`) is a standalone bash script with zero dependencies — it works anywhere.

> **Note:** Full agent orchestration (meta-grading, artifact verification, LaunchAgent automation) is Claude Code-native. OpenClaw users get the skills, scoring, and programs — which is the core value.

## Two-tier scoring

Like training loss vs eval loss in ML:

- **`rhino score .`** — fast, free, every commit. Checks build health, structure (including IA audit), hygiene. Think of it as a linter for your whole project.
- **`rhino taste .`** — slow, expensive, on demand. Takes real screenshots and scores what it *sees*. 11 dimensions scored 1-5 (including layout coherence and information architecture). This is how you know if your app is actually good.

## v4 architecture

Programs are the brain. No agent wrappers — programs do the thinking directly.

```
programs/          4 files, ~480 lines total (build, strategy, meta, review)
agents/refs/       5 reference docs (thinking, design-taste, score-integrity, landscape, escalation)
skills/_internal/  5 skills (score, taste, experiment, strategy, todofocus)
bin/               score.sh + ia-audit.sh + taste.mjs (measurement layer)
hooks/             session_context.sh (~110 lines — injects score + plan + warnings)
tests/             175 tests across 3 tiers, 100% deterministic
```

Experiment enforcement built into the build loop:
- Mandatory predictions before every change
- Mechanical keep/discard (no discretion — score went up or it didn't)
- Ratcheting (keep = commit stays, discard = hard reset)
- Moonshot forcing (every Nth experiment must be high-risk)
- Discard rate floor (below 25% = not exploring enough)
- Scope guard (flags drift from the plan)

## Anti-gaming (scores you can trust)

AI agents love to game metrics. rhino-os fights back:

- **Cosmetic-only detection** — moved some comments around but nothing real? Flagged.
- **Inflation cap** — score jumped 15+ points in one commit? Warning.
- **Plateau detection** — same score for 5 runs? You're stuck, not stable.
- **Stage ceilings** — your MVP scoring 95/100? Something's wrong.
- **IA audit** — orphan routes, dead-end pages, empty states without CTAs penalize structure score.

Scores are diagnostic instruments, not goals.

## Knowledge compounds

Every session builds on the last:
- Experiment learnings (what worked, what didn't, and why)
- Predictions log (calibration signal — are predictions getting more accurate?)
- Design preferences (accumulated taste signals)
- Session context (score + plan + warnings injected into every session)

## Customize everything

| File | What it controls |
|------|-----------------|
| `config/rhino.yml` | Scoring thresholds, integrity guards, experiment discipline |
| `programs/*.md` | Multi-step workflows — the actual brain |
| `skills/*/SKILL.md` | Slash command entry points |
| `agents/refs/*.md` | Reference docs — design taste, thinking protocol, landscape model |

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for details.

## Uninstall

```bash
./uninstall.sh  # removes symlinks + LaunchAgents, keeps your knowledge files
```

## License

[MIT](LICENSE)
