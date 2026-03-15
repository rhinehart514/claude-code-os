# Plugin Install

## Install as a Claude Code plugin

```bash
# From your project directory:
claude plugin install rhino-os
```

This is the recommended path. The plugin system handles commands, mind files, and hooks automatically.

## Install manually (legacy)

```bash
git clone https://github.com/rhinehart514/rhino-os.git ~/rhino-os
cd ~/rhino-os && ./install.sh
source ~/.zshrc
```

Manual install symlinks everything into `~/.claude/`. Updates are `git pull && ./install.sh`.

## Dependencies

**Required:** [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working.

**Optional (for eval/taste):**
```bash
cd ~/rhino-os/bin && npm install   # installs yaml, js-yaml for eval
cd ~/rhino-os/lens/product/eval && npm install   # installs playwright for taste
```

Without these, `rhino score .` still works. `rhino eval .` and `rhino taste` need Node 18+.

## Get started

```bash
cd ~/your-project
claude                # start Claude Code — rhino-os boots automatically
```

Then type:
- `/plan` — find the bottleneck, get tasks
- `/go` — autonomous build loop
- `/eval` — check what's passing

## Commands

| Command | What it does |
|---------|-------------|
| `/plan` | Find the bottleneck, write tasks |
| `/go` | Autonomous build — keeps what passes, reverts what doesn't |
| `/eval` | Run assertions, see what's working |
| `/feature` | List features with pass rates |
| `/init` | Bootstrap into a new project |
| `/ship` | Commit, push, deploy |
| `/ideate` | Brainstorm possibilities |
| `/research` | Explore unknown territory |
| `/rhino` | Status dashboard |

Full docs: [README.md](README.md)
