# rhino-os

An operating system layer for Claude Code. Agents, skills, rules, and hooks for solo technical founders who ship.

```
5 Agents  ·  4 Skills  ·  2 Rules  ·  2 Hooks
Thick-skinned. Charges forward. Doesn't overthink.
```

## Quickstart

```bash
git clone https://github.com/YOUR_USERNAME/rhino-os.git ~/rhino-os
cd ~/rhino-os
./install.sh
```

Edit `~/.claude/CLAUDE.md` with your identity and project info. Then:

```bash
claude --agent sweep         # what needs attention?
claude --agent strategist    # what should I build?
claude --agent builder       # gate → plan → build → doctor
```

## Philosophy

### Momentum Over Process
The old system had a 4-agent pipeline (gate → architect → implementer → eval) before writing a line of code. That's ceremony, not velocity. Now `builder` handles the full lifecycle in one agent with modes. Skip what you don't need.

### Earn Existence
Every agent has evaluation criteria. If it doesn't produce value above its API cost, it gets revised or killed.

### Knowledge Compounds
Learning agents (scout) read accumulated knowledge before acting, grade output after, and adapt. Each session makes the next one better.

### Safety by Default
Sweep requires human approval for RED items. Automated agents are budget-capped. No agent auto-deploys or communicates externally.

## Agent Catalog

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| **strategist** | Product strategy, project prioritization | "What should I build?" |
| **builder** | Gate → Plan → Build → Doctor (4 modes) | Any implementation work |
| **design-engineer** | Visual eval, taste, design systems, UI fixes | "How does my UI feel?" |
| **scout** | Trend scanning, opportunity intelligence | Weekly or exploring new directions |
| **sweep** | Daily triage + system health audit | Start of day, "what needs attention?" |

## Skills

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `/todofocus` | "am I on track?" | Scope check against active plan |
| `/smart-commit` | after completing work | Conventional commit tied to plan |
| `/eval` | before shipping | Code check + perspectives + ship checklist |
| `product-2026` | auto-loads on product discussions | Product reasoning framework |

## Workflow

```
Start of day:
  claude --agent sweep              # What needs attention?

During work:
  claude --agent builder            # Auto-detects mode from context
  claude --agent builder "gate"     # Should I build this?
  claude --agent builder "plan"     # Produce ADR
  claude --agent builder "build"    # Implement from plan
  claude --agent builder "doctor"   # Diagnose/fix codebase
  /todofocus                        # Am I on track?
  /eval                             # Ready to ship?
  /smart-commit                     # Commit with context

Weekly:
  claude --agent scout              # What's trending?
  claude --agent strategist         # Am I building the right thing?

Design:
  claude --agent design-engineer              # Subjective review (default)
  claude --agent design-engineer "recommend"  # What would look good?
  claude --agent design-engineer "build"      # Fix + generate
```

## Installation Details

`install.sh` does the following:

1. **Symlinks individual files** from repo into `~/.claude/` (not whole directories)
2. **Backs up** existing files before overwriting
3. **Merges** `settings.json` and `config.json` via `jq` (preserves your MCP servers, hooks)
4. **Seeds** knowledge directories from templates (doesn't overwrite existing data)

The installer is idempotent — safe to re-run after pulling updates.

### Uninstall

```bash
./uninstall.sh
./uninstall.sh --restore-backup <DIR>
```

## Customization

- Add agents: create `agents/[name].md` and re-run `./install.sh`
- Add skills: create `skills/[name]/SKILL.md` and re-run
- Add rules: create `rules/[name].md` and re-run

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- macOS or Linux
- `jq` for config merging: `brew install jq`

## Honest Limitations

**It's markdown files pretending to be an operating system.** There is no kernel, no process manager, no scheduler. It's prompt engineering with symlinks. That's the entire "runtime."

**Budget caps are vibes, not enforcement.** The prompt says "$2.00 max." Nothing actually tracks spend. You'll find out what it cost on your Anthropic dashboard.

**Knowledge files are gitignored.** The most valuable part — accumulated intelligence — doesn't survive a machine wipe. The disposable parts are version-controlled. The irreplaceable parts aren't.

**This is one person's workflow exported as if it's a product.** The agent prompts encode specific opinions useful for one founder's context. Rewrite prompts to match your situation.

Steal the parts that work. Don't mistake the map for the territory.

## Credits

Inspired by [openclaw/openclaw](https://github.com/openclaw/openclaw) architecture patterns and [jimprosser/claude-code-cos](https://github.com/jimprosser/claude-code-cos) concept.
