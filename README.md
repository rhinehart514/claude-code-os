# rhino-os

A knowledge-compounding strategy engine for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Built for solo technical founders who need strategic clarity, not more workflow automation.

```
5 Agents  ·  3 Intelligence Layers  ·  1 MCP Server  ·  1 CLI
Thick-skinned. Charges forward. Kills what isn't working.
```

## What is this?

The Claude Code ecosystem has 40+ workflow orchestrators, 100+ agent collections, and 349+ skills. All commodity. rhino-os doesn't compete there.

rhino-os is a **strategic operating system** that layers on top of Claude Code. It does three things no other system does:

1. **Portfolio intelligence** — Evaluates your entire project landscape with Buy/Sell/Hold verdicts, kill criteria, and focus prescriptions. Not project-level cheerleading — portfolio-level hard calls.
2. **Landscape positions** — Maintains opinionated strategic beliefs (not trend lists) that agents reason FROM. "AI wrappers are dead" isn't a trend — it's a position with evidence and implications that shapes every recommendation.
3. **Taste learning** — Observes your decisions over time and builds a preference profile. Every agent reads it before acting. By week four, agents know your judgment patterns.

The builder and design-engineer agents are just hands. The intelligence layers are the brain.

## Who is this for?

Solo technical founders running 1-3 projects who use Claude Code daily. You're building fast, juggling priorities, and need a system that:

- Tells you what to kill (not just what to build)
- Remembers your preferences across sessions
- Maintains strategic context between conversations
- Gets sharper the more you use it

If you're on a team, use something else. If you want a prettier CLI, use something else. If you want more agents and skills, there are 349 other options.

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- macOS or Linux (macOS for LaunchAgent automation)
- Node.js 18+ (for MCP server)
- `jq` recommended (`brew install jq`) for `rhino status` details

## Setup

```bash
git clone https://github.com/laneyfraass/rhino-os.git ~/rhino-os
cd ~/rhino-os
./install.sh
```

The installer is idempotent (safe to re-run). It:

1. Symlinks agents, skills, rules, and hooks into `~/.claude/`
2. Merges `settings.json` and `config.json` (preserves your existing config)
3. Seeds knowledge directories from templates
4. Copies `landscape.json` to `~/.claude/knowledge/` (won't overwrite existing)
5. Installs the MCP server (`rhino-state`) and API server dependencies
6. Links the `rhino` CLI to `~/bin/rhino`
7. Optionally installs macOS LaunchAgents for scheduled sweep/scout

```bash
# Skip LaunchAgents (e.g., on Linux):
./install.sh --no-launchd

# Verify everything:
rhino doctor
```

After install, edit `~/.claude/CLAUDE.md` with your identity and project info.

## Usage

### CLI Commands

```bash
# Strategic (weekly)
rhino strategy               # Portfolio evaluation — Buy/Sell/Hold verdicts
rhino scout                  # Update landscape positions from market signals

# Operational (daily)
rhino sweep                  # Daily triage — what needs attention?
rhino status                 # System health, knowledge freshness, intelligence stats

# Building
rhino build                  # Auto-detects mode (gate → plan → build → doctor)
rhino build "implement task 3"   # Build a specific task
rhino build "gate"           # Should I build this? (ideation mode)

# Design
rhino design                 # Auto-detect design mode
rhino design "audit"         # Visual audit of current project

# Knowledge
rhino capture                # Extract session decisions/preferences to knowledge
rhino backup                 # Snapshot all knowledge to timestamped backup

# System
rhino doctor                 # Health check (symlinks, MCP, LaunchAgents, state)
rhino serve                  # Start API server on localhost:7890
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `RHINO_BUDGET` | per-agent defaults | Override Claude budget cap (e.g., `RHINO_BUDGET=5.00 rhino scout`) |
| `RHINO_PORT` | `7890` | API server port |
| `RHINO_API_KEY` | — | API server authentication key |

### First Run

1. `rhino doctor` — verify installation
2. `rhino strategy` — the strategist will auto-discover projects in `~/` with `.git` directories and populate your portfolio
3. Review the Buy/Sell/Hold verdicts. Update project stages and user counts as needed.
4. `rhino scout` — populates landscape positions with market intelligence
5. Start building: `rhino build`

## The Three Intelligence Layers

### Portfolio Model (`rhino_portfolio`)

Structured JSON tracking every project, every feature, every kill criterion. The strategist reads the entire portfolio before making any recommendation.

```
rhino_portfolio(action: "evaluate")
→ project-a → BUY  (core loop complete, 12 users, clear moat)
→ project-b → HOLD (useful but commodity market, don't chase stars)
→ project-c → SELL (no users in 60 days, kill trigger hit)

FOCUS WARNING: 3 active projects. 1 project at 100% = escape velocity.
3 at 33% = none escape.
```

Kill criteria are checked automatically: "No real user need in 30 days", "Can't name one person who'd pay", "Core loop incomplete for >2 months".

### Landscape Positions (`rhino_landscape`)

Opinionated beliefs about what works right now. Not trends — positions with evidence and implications that every agent reasons from.

```
[STRONG] "AI wrappers are dead — the wedge is proprietary data + workflow"
  Implications: Any product wrapping Claude/GPT API is on borrowed time
  Evidence: Anthropic shipping natively, enterprise consolidating spend

[STRONG] "Solo founders win on context engineering + distribution, not product quality"
  Implications: Stop polishing. Focus on reaching users.

[MODERATE] "Knowledge compounding is the only defensible innovation in AI dev tools"
  Implications: The taste/preference learning system is genuinely novel
```

Positions have IDs for easy update/removal. Substring matching works too:

```
rhino_landscape(action: "update", position: "ai wrappers")
→ matches "AI wrappers are dead — the wedge is proprietary data + workflow"
```

Scout maintains these. Strategist reasons from them. Every recommendation references a position.

### Taste Signals (`rhino_taste`)

Observations about your preferences, recorded as agents watch you work. Duplicate signals get deduplicated with strength promotion (weak → moderate → strong).

```
[product]   "Rejects onboarding flows — wants users dropped into value immediately"   [strong]
[design]    "Prefers dense data layouts over whitespace"                               [moderate]
[strategy]  "Kills features aggressively when no user signal exists"                   [moderate]
[technical] "Prefers simple bash over complex TypeScript when both work"               [weak]
```

Every agent reads taste before acting. The design-engineer uses it instead of generic design rubrics. The builder respects your technical preferences. The strategist aligns recommendations with your judgment patterns.

## Architecture

```
~/.claude/
├── agents/              # Symlinked agent definitions
│   ├── strategist.md    # Portfolio strategy, Buy/Sell/Hold
│   ├── builder.md       # Gate → Plan → Build → Doctor
│   ├── design-engineer.md # Visual eval, design systems
│   ├── scout.md         # Market intelligence, landscape maintenance
│   └── sweep.md         # Daily triage, system health
├── skills/              # User-invocable skills
│   ├── eval/            # Ship-readiness checks
│   ├── smart-commit/    # Conventional commits tied to plans
│   ├── todofocus/       # Scope enforcement
│   └── product-2026/    # Product strategy reasoning
├── rules/               # Always-on coding rules
│   ├── quality-bar.md
│   └── product-reasoning.md
├── hooks/               # Event-driven automation
│   ├── enforce_ideation_readonly.sh  # Blocks edits during ideation
│   ├── track_usage.sh               # Tool call logging
│   └── capture_knowledge.sh         # Session knowledge extraction
├── knowledge/           # Intelligence layer data (gitignored)
│   ├── portfolio.json   # Project portfolio model
│   ├── landscape.json   # Strategic positions
│   ├── taste.jsonl      # Preference signals
│   └── sessions/        # Captured session knowledge
├── state/               # Inter-agent operational state
├── logs/                # Session and usage logs
└── config.json          # MCP server registration

~/rhino-os/              # Source repo
├── src/
│   ├── mcp-server/      # rhino-state MCP server (9 tools)
│   └── api-server/      # REST API for programmatic access
├── bin/rhino             # CLI wrapper
├── install.sh           # Idempotent installer
└── uninstall.sh         # Clean removal
```

### How agents communicate

Agents share state through the filesystem, not direct calls:

- **MCP tools** (`rhino_*`) read/write structured data in `~/.claude/knowledge/`
- **State files** in `~/.claude/state/` pass operational context (e.g., sweep writes `sweep-latest.md`, strategist reads it)
- **Knowledge files** in `~/.claude/knowledge/{agent}/` accumulate per-agent learnings

This means agents work asynchronously. The sweep runs, writes state, and the strategist picks it up on the next run.

## MCP Tools Reference

The `rhino-state` MCP server provides 9 tools that agents use automatically:

| Tool | Purpose |
|------|---------|
| `rhino_portfolio` | Read, add, update, remove, or evaluate projects |
| `rhino_landscape` | Read, add, update, or remove strategic positions |
| `rhino_taste` | Record, read, or query preference signals (with dedup) |
| `rhino_get_state` | Read inter-agent state files |
| `rhino_set_state` | Write inter-agent state files |
| `rhino_query_knowledge` | Query agent knowledge with confidence filtering |
| `rhino_update_knowledge` | Append or replace knowledge files |
| `rhino_log_session` | Log session metadata (agent, cost, duration) |
| `rhino_get_usage` | Query usage stats by period and grouping |
| `rhino_backup_knowledge` | Snapshot all knowledge to timestamped backup |

## Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `enforce_ideation_readonly.sh` | PreToolUse (Edit/Write/Bash) | Blocks file edits during ideation/gate mode |
| `track_usage.sh` | PostToolUse (all) | Logs every tool call to `usage.jsonl` |
| `capture_knowledge.sh` | Manual (`rhino capture`) | Extracts session decisions/preferences to knowledge |

Knowledge capture is opt-in — run `rhino capture` when you want to save a session's learnings. It won't auto-fire on every session stop.

## Uninstall

```bash
cd ~/rhino-os
./uninstall.sh
```

Removes symlinks and LaunchAgents. Your knowledge files in `~/.claude/knowledge/` are preserved (delete manually if desired).

## Honest Limitations

**The taste system requires sessions to compound.** It starts empty. First week is generic. By week four, agents know your judgment patterns.

**Portfolio evaluation is only as good as the data.** You need to populate the portfolio with your actual projects. The strategist can auto-discover projects in `~/`, but you need to confirm stages and user counts.

**Landscape positions are opinionated and sometimes wrong.** That's the point — they're positions, not facts. Scout revises them when evidence changes.

**Budget caps are real.** The `rhino` CLI passes `--max-budget-usd` to Claude. Default is $2.00 for most agents. Override with `RHINO_BUDGET`.

**Knowledge files are gitignored.** They live in `~/.claude/knowledge/`, not in the repo. Use `rhino backup` regularly.

**This is a solo founder tool.** It assumes one person making all decisions. Team dynamics, code review workflows, and multi-person taste profiles are not supported.

## Credits

Informed by [PAHF](https://arxiv.org/abs/2602.16173) (preference learning from feedback), [compound engineering](https://every.to/chain-of-thought/compound-engineering-how-every-codes-with-agents) (knowledge loops), and [HBR portfolio management](https://hbr.org/2026/01/manage-your-ai-investments-like-a-portfolio) (Buy/Sell/Hold for AI investments).

## License

MIT
