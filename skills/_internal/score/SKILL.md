---
name: score
description: Run structural score on the current project. Wraps bin/score.sh with context — trend, integrity warnings, comparison to last score. Say "/score" anytime.
user-invocable: true
---

# Score — Structural Quality Check

Run the rhino-os structural score on the current project.

## Execute

```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/score.sh" . --json
```

If RHINO_DIR is not set, try common locations: `~/rhino-os`, `~/Desktop/rhino-os`, or find via `which rhino`.

## Present Results

Parse the JSON output and present:

1. **Overall score**: X/100
2. **Dimensions**:
   - Build: X/100 (gate: pass/fail)
   - Structure: X/100
   - Hygiene: X/100
3. **Integrity warnings**: list any from `integrity_warnings` array
4. **Trend**: compare to previous scores in `.claude/scores/history.tsv` or score cache
5. **Stage context**: show the expected range for this project's stage from rhino.yml integrity section

## After

If score dropped, flag which dimension caused it.
If integrity warnings fired, explain what they mean and what to do.
Update workspace.json `last_score` if workspace helper is available.
