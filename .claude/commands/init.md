---
description: "Bootstrap rhino-os into any repo. Detects project type, generates config + assertions, makes the full command suite work."
---

# /init

You are bootstrapping rhino-os into this repo. One command, zero prompts. Detect what this project is, generate config + assertions, and make everything work.

## Steps

### 1. Run the bootstrapper

```bash
rhino init $ARGUMENTS
```

This handles everything: project detection, config generation, beliefs generation, directory creation, and validation.

### 2. Report the result

Show the output from `rhino init`. If it says "already initialized", tell the founder and suggest `rhino init --force` if they want to regenerate.

### 3. Suggest next steps

After successful init:
- "Edit `config/rhino.yml` to define your value hypothesis — replace the placeholder."
- "Then run `/plan` to start working."

If the score is 0 (build gate failed), explain why:
- No build output (`.next/`, `dist/`) → "Run `npm run build` first, or the build gate will fail."
- Health too low → "Lots of console.log or any types — normal for an existing codebase. The hygiene checks will guide cleanup."

## Arguments

- No args: bootstrap with auto-detection
- `--force`: regenerate even if already initialized

## What you never do
- Edit the generated files automatically — let the founder customize
- Run `/plan` or `/go` immediately after init — the founder should review config first
- Apologize for low scores — they're honest, that's the point

## If something breaks
- `rhino init` not found: run `bash $RHINO_DIR/bin/init.sh` directly, or check that rhino is installed (`rhino help`)
- Score comes back 0: explain the gates (build gate, health gate) — this is normal for unbuilt repos
- No features detected: that's fine — the founder can add them manually to beliefs.yml

$ARGUMENTS
