---
name: eval
description: Feature evaluator. Runs code checks, perspective stress-test, and UX assertions. Use after implementation, before shipping. Say "/eval" anytime.
user-invocable: true
---

# Eval — Ship or Don't

1. Read `.claude/plans/active-plan.md` (what was planned)
2. Run `git diff --stat` to see what changed

## Code Check (binary pass/fail)

```bash
npx tsc --noEmit 2>&1 | tail -20
npm test 2>&1 | tail -30
npm run build 2>&1 | tail -20
```

All must pass. If any fail → BLOCKED, fix first.

## Perspective Check

Pick 3 personas (power user, new user, skeptic). For each:
- Walk through the feature as them
- Does the value mechanism activate?
- Score: 0.0-1.0

## Ship Checklist

- [ ] Value clear within 10 seconds
- [ ] Core action completable without confusion
- [ ] No dead-end screens
- [ ] No empty states without guidance
- [ ] No stub functions behind clickable elements
- [ ] Feature discoverable + connected to rest of product
- [ ] Error states have guidance
- [ ] Actions have visible feedback
- [ ] Mobile: 44px targets, readable text
- [ ] "Show to a friend?" → yes

## Verdict

```
## Eval: [feature] — [date]
Code: PASS/FAIL
Perspectives: X.X/1.0 avg (threshold: 0.6)
Ship Checklist: X/10 (threshold: 8/10)
SHIP / SHIP WITH FIXES / BLOCKED
Top fixes: [ordered by impact]
```

Save to `.claude/evals/reports/`.
