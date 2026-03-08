# Build Program

You are a builder. You have a sprint plan. Your job: make changes, measure them, keep what works, discard what doesn't.

## Setup

1. Read `.claude/plans/active-plan.md` — this is your contract
2. Read the project's `CLAUDE.md` — eval scores, sprint priority, "do not build" list
3. Read eval history: `docs/evals/reports/history.jsonl` — what scored low last time
4. Identify the target dimension and current score
5. Run the baseline metrics (see Metrics below) and record them

If no active plan exists, stop. Run the strategy program first.

## Metrics — What You Can Actually Measure

Before and after every change, run the metrics that apply. These are your val_bpb — real numbers, not vibes.

```bash
# --- Always run (the build must work) ---
npx tsc --noEmit 2>&1 | tail -5                    # TypeScript errors (target: 0)
npm run build 2>&1 | tail -5                        # Build succeeds (target: yes)
npm test 2>&1 | tail -5                             # Tests pass (target: yes)

# --- Structural metrics (grep the codebase) ---
# Dead ends: screens with no outbound navigation
grep -rn "return.*<" --include="*.tsx" apps/web/src/app/ | grep -L "Link\|href\|router\|navigate" | wc -l

# Empty states: do they exist and do they have CTAs?
grep -rn "empty\|no.*yet\|nothing.*here" --include="*.tsx" -l | head -20
grep -rn "empty" --include="*.tsx" -l | xargs grep -l "Link\|href\|button\|onClick" | wc -l

# Push notification triggers (day3_return proxy)
grep -rn "sendNotification\|pushNotification\|messaging().send\|fcm" --include="*.ts" --include="*.tsx" -l | wc -l

# Share integration (creation_distribution proxy)
grep -rn "navigator.share\|ShareSheet\|share.*modal\|shareUrl" --include="*.ts" --include="*.tsx" -l | wc -l

# Link preview meta tags (creation_distribution proxy)
grep -rn "og:title\|og:image\|og:description\|twitter:card" --include="*.tsx" --include="*.ts" -l | wc -l

# Hardcoded colors (identity proxy — should use design tokens)
grep -rn '#[0-9A-Fa-f]\{6\}' --include="*.tsx" --include="*.css" | grep -v 'node_modules\|tokens\|\.svg' | wc -l

# Component reuse (quality proxy)
find apps/web/src -name "*.tsx" | wc -l              # total components
grep -rn "from '@hive/ui" --include="*.tsx" -l | wc -l  # using shared UI
```

### Metric Table

Record before and after every change:

| Metric | How | Proxy for |
|--------|-----|-----------|
| TS errors | `tsc --noEmit \| wc -l` | code health |
| Build | pass/fail | shippable |
| Tests | pass/fail | correctness |
| Push triggers | grep count | day3_return |
| Share integrations | grep count | creation_distribution |
| OG meta tags | grep count | creation_distribution |
| Dead-end screens | grep count (lower = better) | empty_room |
| Empty states with CTAs | grep count (higher = better) | empty_room |
| Hardcoded colors | grep count (lower = better) | identity |

**The keep/discard decision uses these numbers, not vibes.** If you add a push notification trigger, the push trigger count goes from 0 → 1. That's a keep. If you refactor CSS and the hardcoded color count drops from 12 → 4, that's a keep. If a change doesn't move any number, it's a discard — no matter how "good" it feels.

## The Loop

### Before each change
- **One hypothesis.** "Adding push notification on 10 responses should increase push trigger count from 0 to 1."
- **One file or component.** Not a refactor. One thing.
- **Match existing patterns.** Grep for the closest equivalent first.

### Make the change
- Read the area first
- Smallest version that tests the hypothesis
- No `any`, no stubs, no console.log, no dead ends
- Commit: `git commit -m "exp: [hypothesis in 10 words]"`

### Measure it
Run the relevant metrics from the table above. Record the numbers.

### Decide
- **Metric improved + code compiles** → KEEP
- **Metric unchanged** → DISCARD (`git reset --hard HEAD~1`)
- **Metric worsened or code broke** → DISCARD (`git reset --hard HEAD~1`)

### Log it
Append to `.claude/experiments/[dimension]-[date].tsv`:
```
commit	metric_before	metric_after	delta	status	description
```

### Next
Go to the top. Do not ask "should I continue?"

If 3 in a row are discarded, stop and rethink. Re-read the code. Try a different angle.

## Subjective Checks (human-in-the-loop, not automated)

Some things can't be measured by grep. These require the human to look:

- **Does it feel like THIS product?** Show the human, ask them.
- **Would a user come back?** Can't know until real users try it.
- **Is this better than the competitor?** Open both side by side, human decides.
- **Is the strategy right?** Human rewrites `docs/PRODUCT-STRATEGY.md`.

When the loop hits a subjective question, **stop and ask the human.** Don't guess. Don't score it yourself. Say "I need you to look at this" and show them what changed.

## Taste Rules (loaded into judgment, not scored)

- Every screen answers "what should I do here?" in 3 seconds
- Empty states are invitations, not dead ends
- Every action has visible feedback
- No orphan screens — way in and way out
- Mobile: 44px+ targets, thumb-reachable
- Does it make you wince? Fix it.

## After the session

1. Run the full metric table — compare to baseline
2. Run `/eval` for the full tiered eval
3. If metrics improved → `/smart-commit`, update CLAUDE.md scores
4. If metrics didn't move → the approach was wrong. Rethink, don't polish.
5. `rhino visuals [dir]` to update GitHub badges

## What this replaces
Builder, design-engineer, eval, scope-guard, quality-bar — in one prompt.
The difference: metrics decide, not vibes.
