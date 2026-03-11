# Meta Program — rhino-os Improves Itself

You are the training loop. Measure → apply one fix → verify. The evals are your loss function. grades.jsonl is your loss curve.

## Step 0: Run Evals (MANDATORY)

```bash
cd $(dirname $(readlink ~/bin/rhino))/..
tests/run.sh --json 2>/dev/null
```

Record the BEFORE numbers. After your fix, run again. If any tier drops, revert.

### The Tiers

- **Tier 1**: Does the code work? (syntax, file existence, config) — target: 100%
- **Tier 2**: Do integrity checks work? (score detectors, taste guards) — target: 100%
- **Tier 3**: Known inputs → known outputs? (canary tests) — target: 100%
- **Tier 4**: Do agents produce value? (artifacts, experiments, evals) — target: 80%+
- **Tier 5**: How autonomous is the system? (full loop, multi-sprint) — target: 60%+

## Step 1: Read System State

1. Read `~/.claude/knowledge/meta/grades.jsonl` — what did you change last time?
2. Read brain files from `~/.claude/state/brains/`
3. Read `~/.claude/knowledge/experiment-learnings.md` — is the learning engine growing?
4. Read `~/.claude/knowledge/predictions.tsv` — are predictions being made and getting more accurate?
5. Read `~/.claude/logs/artifact-failures.jsonl` if it exists

## Step 2: Diagnose

Look at eval results. What failed? Why?

**Priority order:**

**A. What's broken?** (failing tests, syntax errors) — fix first.

**B. What's blind?** Check taste screenshots against scores. If scores say 3+ but screenshots look bad, fix the rubric. A blind system looks healthy while the product rots. This is the silent killer.

**C. What's dishonest?** (inflated scores, circular self-assessment, dead config)

**D. What's slow?** (stale agents, broken feedback loops)

## Step 3: Apply ONE Fix

Highest-leverage fix from diagnosis. One fix per cycle — can't attribute improvement otherwise.

## Step 4: Verify

```bash
tests/run.sh --json 2>/dev/null
```

Compare BEFORE and AFTER:
1. Tests improved or held → fix is good
2. Tests dropped → revert immediately
3. Tests unchanged → log as "no measurable impact"

One fix. Test before/after. Drop = revert.

## Step 5: Log

Append to `~/.claude/knowledge/meta/grades.jsonl`:

```json
{"date":"YYYY-MM-DD","cycle":N,"test_before":{"pass":X,"total":Y,"pct":Z},"test_after":{"pass":X,"total":Y,"pct":Z},"fix_applied":{"file":"path","change":"what","rationale":"why"},"fix_verified":"tests held|tests improved|tests dropped — reverted|no measurable impact"}
```

Update `~/.claude/state/brains/meta.json`.

## Escalation

| Signal | Action |
|--------|--------|
| Pass rate improving | Keep going |
| Pass rate ≥95% for 3+ cycles | Audit the loss function — tests might be too easy. Run lens B. |
| Pass rate flat 2+ cycles | Fix something structural |
| Pass rate flat 4+ cycles | Architecture change needed |
| All tests pass but founder reports problems | CRITICAL blindness. Add the missing measurement first. |

## The Goal

Each meta cycle answers TWO questions:
1. Did pass rate go up, stay flat, or go down?
2. Would these tests catch the problems the founder actually has?

Question 1 without question 2 is Goodhart's Law.
