# rhino-os

**Your AI coding agent is powerful. But it has no memory, no strategy, and no taste.**

rhino-os fixes that. It's a brain for your AI coding agent — it decides what to build, builds it, scores the result, and learns from every cycle. You point it at a project and walk away.

## The problem

AI coding agents (Claude Code, OpenClaw, etc.) are incredible at executing tasks. But they:
- Don't know what to build next
- Can't tell if what they built is actually good
- Forget everything between sessions
- Have no strategy — they just do what you tell them

rhino-os turns a task executor into a **self-improving product engineer.**

## How it works (30 seconds)

```
You: "run strategy"
rhino-os: scans your project, finds the biggest bottleneck, writes a sprint plan

You: "let's build"
rhino-os: builds it, scores the result, keeps or discards, logs what it learned

You: "rhino go ."
rhino-os: does both with no human gate. point it at a project and go to sleep.
```

That's it. Three commands.

## The loop

```
strategy → plan → build → score → keep or discard → repeat
    ↑                                                    |
    └────────────── learnings feed back ─────────────────┘
```

Every cycle, rhino-os gets smarter about your project. It remembers what worked, what didn't, and why.

## What's inside

| Command | What it does |
|---------|-------------|
| `rhino strategy` | Looks at your project, finds the biggest bottleneck, writes a sprint plan |
| `rhino build` | Builds the plan, scores every change, keeps good ones, discards bad ones |
| `rhino sweep` | Daily health check — finds issues, fixes safe ones, flags risky ones |
| `rhino scout` | Researches your market — what competitors do, what users expect |
| `rhino score .` | Instant code quality check (2 seconds, free) |
| `rhino taste .` | Visual eval — takes screenshots, scores what it *sees* like a real user |
| `rhino meta` | Grades its own agents. If one is broken, it fixes the prompt automatically |
| `rhino go .` | Full autopilot — strategy + build + score, no human gate |

## Install (2 minutes)

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
```

Then in any project:

```bash
cd ~/your-project
rhino init .

# Open Claude Code and say:
#   "run strategy"  — to plan
#   "let's build"   — to build
#   "rhino go ."    — to do both
```

**Requirements:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with OAuth. macOS or Linux. Node 18+ for visual eval.

## Works with OpenClaw too

If you use [OpenClaw](https://github.com/openclaw/openclaw), rhino-os skills work out of the box.

**Why:** Both systems use the same `skills/*/SKILL.md` format. rhino-os ships 7 skills (`/build`, `/strategy`, `/sweep`, `/scout`, `/experiment`, `/design`, `/meta`) that OpenClaw can pick up directly.

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

- **`rhino score .`** — fast, free, every commit. Checks build health, structure, hygiene. Think of it as a linter for your whole project.
- **`rhino taste .`** — slow, expensive, on demand. Takes real screenshots and scores what it *sees*. 9 dimensions scored 1-5. This is how you know if your app is actually good.

## Five agents, one filesystem

Agents don't call each other. They communicate by reading and writing files:

```
Strategist  →  writes plans       →  Builder reads them
Builder     →  writes scores      →  Strategist reads them next cycle
Sweep       →  writes state       →  Strategist reads it
Scout       →  writes positions   →  Builder reads them
Meta        →  grades everyone    →  fixes broken prompts
```

If one agent fails, the others keep working. Meta catches silent failures within 48 hours.

## Anti-gaming (scores you can trust)

AI agents love to game metrics. rhino-os fights back:

- **Cosmetic-only detection** — moved some comments around but nothing real? Flagged.
- **Inflation cap** — score jumped 15+ points in one commit? Warning.
- **Plateau detection** — same score for 5 runs? You're stuck, not stable.
- **Stage ceilings** — your MVP scoring 95/100? Something's wrong.

Scores are diagnostic instruments, not goals.

## Knowledge compounds

Every session builds on the last:
- Experiment learnings (what worked, what didn't, and why)
- Market positions (evidence-backed strategic claims)
- Design preferences (accumulated taste signals)
- Session context (last session summary injected into the next one)

## Customize everything

| File | What it controls |
|------|-----------------|
| `config/rhino.yml` | Budgets, scoring thresholds, integrity guards |
| `agents/*.md` | Agent prompts — edit directly to change behavior |
| `programs/*.md` | Multi-step workflows — the actual brain |
| `skills/*/SKILL.md` | Slash command entry points |

See [docs/CUSTOMIZATION.md](docs/CUSTOMIZATION.md) for details.

## Uninstall

```bash
./uninstall.sh  # removes symlinks + LaunchAgents, keeps your knowledge files
```

## License

[MIT](LICENSE)
