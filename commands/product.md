---
description: "Product thinking session (WHY). Understand who, trace why, surface assumptions, identify risks and gaps. /product runs full. /product assumptions zooms in. Does NOT brainstorm features — use /ideate for that."
---

# /product

The product thinking command. Not code quality — product quality. Not "does it work?" — "should it exist, who cares, and what's missing?"

This command analyzes direction, surfaces assumptions, and identifies risks. It does NOT brainstorm features or generate build ideas — that's /ideate's job.

## When to use this vs other commands

Five commands touch ideas. They answer different questions:

| Command | Role | Question |
|---------|------|----------|
| `/product` | **WHY** | Should this exist? Who cares? What assumptions are we making? |
| `/ideate` | **WHAT** | What specific things should we build next? |
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

Use `/product` when you're questioning direction, validating fit, or starting something new.
Use `/ideate` when direction is clear and you need concrete build ideas.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode |
|-------|------|
| (none) | Full product thinking session — all lenses |
| `user` or `journey` | User journey walkthrough only |
| `assumptions` or `risks` | Assumption audit only |
| `why` or `value` | Value chain trace only |
| `pitch` | Pitch clarity test only |
| `focus` or `cut` | Feature kill/focus exercise only |
| `signals` | Signal instrumentation check only |
| `delight` | Craft moment identification only |
| `[any text]` | Constrained product thinking around a topic |

## State to read (parallel)

1. `config/rhino.yml` — value hypothesis, user, features (maturity/weight/depends_on)
2. `rhino feature` — per-feature pass rates
3. `rhino score . --quiet` — current score
4. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — known patterns, unknowns
5. `.claude/plans/todos.yml` — backlog items
6. `.claude/plans/roadmap.yml` — current thesis
7. `git log --oneline -10` — recent work
8. README.md — what the product claims to be

Compute the product map (maturity × weight) and product completion %.

## The Seven Lenses

Run all seven in the full session. Each lens surfaces **gaps**. Gaps trigger inline research. Research sparks ideas.

### Lens 1: Who (user journey)

Construct the user journey from the persona in rhino.yml `value.user`:
- What's their entry point? (README? CLI? Web UI?)
- Walk each step. Score friction 1-5.
- Identify the **drop-off point** — where does the journey break?
- If playwright is available and a dev server is running, actually walk the product.

**When this surfaces a gap** → immediately research it. Example: "Step 3 requires terminal knowledge. Do SMB owners use terminals?" → WebSearch for user research on SMB technical literacy. Fold finding into the output.

**Gap found?** Flag it for `/ideate` — don't brainstorm solutions here.

### Lens 2: Why (value chain)

For each feature, trace: code → feature → assertion → value signal → hypothesis.

Flag:
- **Orphaned code**: files not in any feature's `code:` list
- **Orphaned features**: features with no assertions
- **Orphaned assertions**: assertions that don't connect to a value signal
- **Dead weight**: features where weight > 1 but maturity is planned (high importance, zero progress)

Compute: what % of assertions test infrastructure vs. value delivery?

**Gap found?** Flag orphaned/dead-weight items. `/ideate` can propose what to do with them.

### Lens 3: Assumptions (risk audit)

Extract every assumption the product makes:
- From value hypothesis: "Users get [X]" — are you sure they want X?
- From user definition: "[Who] uses this" — are you sure that's who?
- From features: each feature assumes its approach is right
- From signals: each signal assumes it measures what matters

Rank by **risk × ignorance**:
- Risk: if this assumption is wrong, how much of the product breaks? (1-5)
- Ignorance: how much evidence do you have? (none / anecdotal / tested / proven)
- Score = risk × (4 - evidence_level). Highest score = most dangerous assumption.

**When this surfaces a high-risk assumption** → immediately research it. WebSearch for validation data, check experiment-learnings.md for related patterns.

**High risk?** Flag for `/research` to validate, or `/ideate` to brainstorm tests.

### Lens 4: Focus (kill exercise)

Read all features with weights. Ask:
- If you could only keep 2 features, which 2 deliver on the hypothesis?
- Which features could be **deferred** without losing the core value?
- Are any weights wrong? (high weight on a nice-to-have, low weight on a must-have)
- Is any feature's `depends_on` chain blocking the critical path unnecessarily?

**Freed resources?** Note what could be redirected. `/ideate` generates the replacement ideas.

### Lens 5: Signals (measurement gap)

For each signal in rhino.yml `value.signals`:
- Is it being measured? (check assertions, code, external instrumentation)
- When was it last checked?
- What's the current value (if known)?

Compute: what % of your signals are actually instrumented?

**When this surfaces unmeasured signals** → propose the simplest assertion or check that would start measuring it.

**Unmeasured?** Note the gap. Instrumentation ideas belong in `/ideate`.

### Lens 6: Delight (craft moment)

Identify the **single most important moment** in the product experience — the 10 seconds where value is delivered. Then evaluate:
- Is there a loading/transition state?
- Is there a success state that feels rewarding?
- Is there surprise or personality in the micro-copy?
- Would a user screenshot this moment and share it?

**Not delightful?** Name what's missing. `/ideate [feature]` can brainstorm improvements.

### Lens 7: Pitch (clarity test)

Generate 3 pitch variants from the actual product state (not aspirational):
- **Elevator**: 1 sentence. No jargon.
- **Tweet**: 280 chars. Hook + value + who.
- **Hero**: Headline + subhead + CTA.

Run each through a clarity filter:
- Uses jargon? → fail
- Names a specific person with a specific problem? → pass
- States what changes for them? → pass
- Differentiates from alternatives? → bonus

If the pitch can't be written clearly, **the product isn't clear enough** — that's the most important finding of the entire session.

**Pitch unclear?** That's the verdict. `/ideate` can propose what would make it clear.

## Synthesis: The Product Brief

After all lenses, synthesize into a verdict:

```
── verdict ────────────────────────────────
  product clarity: **N/10**
  biggest risk: [top assumption, with evidence level]
  biggest opportunity: [the gap with highest impact — take to /ideate]
  drop-off point: [from user journey — where users leave]
  measurement gap: [N unmeasured signals out of M]

  "One paragraph. Opinionated. What a cofounder would say after spending
   an hour thinking about the product, not the code. Name the one thing
   that matters most right now."
```

## Output format

Full session uses all 7 lenses. Each lens is a section with analysis + inline research + ideas:

```
◆ product — [project name]

product: **64%** · score: 50 · 4 features · 3 assumptions untested

── who ────────────────────────────────────
  [journey map with friction scores]

  research: [inline finding from web search or knowledge model]

  gap: [friction point — take to /ideate]

── why ────────────────────────────────────
  [value chain trace]
  [orphaned items]

  gap: [orphaned/dead-weight items flagged]

── assumptions ────────────────────────────
  [ranked list, top 3 with research]

  research: [inline finding on top assumption]

  gap: [untested assumptions — take to /research]

── focus ──────────────────────────────────
  [keep/defer/kill for each feature]

  gap: [freed resources — take to /ideate]

── signals ────────────────────────────────
  [measured/unmeasured for each signal]

  gap: [unmeasured signals flagged]

── delight ────────────────────────────────
  [the key moment + what's missing]

── pitch ──────────────────────────────────
  elevator: "[one sentence]"
  tweet: "[280 chars]"
  hero: [headline + subhead]
  clarity: [pass/fail with reasons]

── verdict ────────────────────────────────
  [the synthesis — one opinionated paragraph]

/ideate              brainstorm what to build from the gaps
/research [topic]    validate the biggest risk
/plan                turn decisions into moves
```

## Inline Research Protocol

When a lens surfaces a gap or untested assumption:
1. Check experiment-learnings.md first — is this a known pattern?
2. If unknown → WebSearch for validation data (spend 30 seconds max per query)
3. If context7 is relevant (library/framework question) → query-docs
4. Fold the finding into the lens output as `research: [finding]`
5. If the finding changes the analysis, update the lens conclusion

Don't break flow for deep research. Surface-level validation inline. If something needs deep investigation, flag it for `/research` at the end.

## Tools to use

**Use Read** for all state files (rhino.yml, experiment-learnings.md, etc.)
**Use Bash** for `rhino score .`, `rhino feature`, `git log`
**Use WebSearch** for inline assumption validation (keep it fast — 1-2 queries per lens)
**Use context7** for library/framework questions
**Use playwright** for actual product walkthrough (if dev server available)
**Use AskUserQuestion** after the verdict — what resonates? which idea to pursue?

## What you never do
- Turn this into a 20-page report — each lens is 5-10 lines max
- Generate feature ideas — flag gaps, redirect to /ideate for brainstorming
- Do deep research inline — surface-level validation only, flag deep dives for /research
- Produce generic insights — "improve UX" is garbage, "add loading state to generate button" is specific
- Forget the product map — every idea connects back to maturity, weight, and the bottleneck
- Be sycophantic about the product — if it's not clear who it's for, say so

## If something breaks
- No value hypothesis: "Your product doesn't know what it's for. Write `value.hypothesis` in rhino.yml before anything else."
- No features: "No features defined. Run `/feature new [name]` — you need structure before product thinking."
- No dev server (can't use playwright): skip live walkthrough, trace journey from code
- WebSearch fails: use experiment-learnings.md + codebase analysis only
- Some lenses have no findings: skip them, don't pad

$ARGUMENTS
