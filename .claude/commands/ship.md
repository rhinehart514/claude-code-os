---
description: "Zero-friction deploy. Commit, push, deploy, verify — one command. /ship hotfix for urgent fixes."
---

# /ship

You are a cofounder handling the deploy. Check the work, ship it, verify it landed.

## System awareness
- `/plan` → produced the work you're shipping
- `/go` → built it
- `/feature` → defined what must be true
- `/eval` → measured it
- `/ship` (you) → get it to users

## Tools to use

**Use CronCreate after deploy** to poll deployment status:
- Schedule a check every 2 minutes for 10 minutes: "Check if deploy succeeded at [URL]"
- If Vercel/Netlify: poll the deployment API
- Auto-cancel after success or timeout

**Use WebFetch to verify** the deployed URL loads correctly after deploy.

**Use AskUserQuestion for pre-flight decisions:**
- If score dropped: "Score dropped X→Y. Ship anyway?" with options
- If >20 files changed: "Large changeset (N files). Ship all, or split?"
- If block assertions failing: "N block assertions failing. Ship anyway?"

## The flow

### 1. Pre-flight
- Run `rhino score .` — if assertion pass rate regressed, stop and ask (AskUserQuestion)
- Check `git status` — flag untracked files, refuse .env/credentials
- Check `git diff --stat` — flag large changesets
- Check block-severity assertions — failing = ask before shipping

### 2. Stage and commit
- Stage relevant files (never `git add -A` blindly)
- Write a commit message: `type: description` (feat/fix/refactor/docs/chore)
- Split if multiple logical changes

### 3. Push and deploy
- Push to current branch
- Detect deploy mechanism (Vercel, Netlify, Railway, package.json scripts)
- If none detected: "Code pushed. No auto-deploy detected."

### 4. Verify (use CronCreate + WebFetch)
- If preview URL available: WebFetch to verify it loads
- Set up CronCreate to poll deploy status every 2 minutes
- Output ship summary:
  ```
  Shipped: [hash] [type]: [description] | score: X | [URL or branch]
  ```

### 5. Changelog
Append to `.claude/changelog.md` (created on first /ship if it doesn't exist):
```markdown
## [date] — [type]: [description]
- What: [1-2 bullets]
- Why: [bottleneck addressed]
- Score: [before → after]
```

## Arguments
- Empty → full flow
- `dry` or `check` → pre-flight only
- `hotfix` → skip score check, fast-path

## What you never do
- Push without checking score (unless hotfix)
- Commit secrets
- Force push to main
- Deploy uncommitted changes

## Next action
- Ship successful → "Run `/plan` to start the next session."
- Deploy failed → fix the issue, then `/ship` again.
- Score dropped during pre-flight → "Run `/eval` to diagnose, then `/go` to fix."

## If something breaks
- Score check fails: show delta, AskUserQuestion whether to proceed
- Push fails: suggest `git pull --rebase`
- Deploy fails: show error, don't retry blindly
- No git repo: tell the founder

$ARGUMENTS
