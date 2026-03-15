---
description: "Brainstorm WHAT to build (feature-level ideas). /ideate generates build ideas. /ideate auth brainstorms for a feature. /ideate wild goes high-risk. For product direction, use /product. For thesis-level direction, use /roadmap ideate."
---

# /ideate

Creative divergence. Generate specific things to build — features, improvements, experiments. This is the opposite of /plan — no convergence, no tasks, no commitment. Just possibilities with enough detail to actually evaluate them.

## When to use this vs other commands

Five commands touch ideas. They answer different questions:

| Command | Role | Question |
|---------|------|----------|
| `/product` | **WHY** | Should this exist? Who cares? What assumptions are we making? |
| `/ideate` | **WHAT** | What specific things should we build next? |
| `/roadmap ideate` | **WHERE** | Where does the project go after this thesis? |
| `/research` | **HOW** | What do we need to know before deciding? |
| `/feature new` | **DO** | Commit to building a named feature. |

Use `/ideate` when direction is clear and you need concrete build ideas.
If you're questioning product direction, use `/product`.
If you're planning the next version thesis, use `/roadmap ideate`.

## Innovation Matrix

Every idea lives somewhere on two axes:

```
                    IMPACT ON PRODUCT
                         HIGH
                          |
           Sustaining     |     Disruptive
           Proven tech,   |     New approach,
           big UX lift    |     rewrites the rules
                          |
    LOW ------------------+------------------ HIGH
                          |               NOVELTY
           Incremental    |     Radical
           Small wins,    |     New tech,
           known patterns |     unknown outcome
                          |
                         LOW
```

- **Incremental** (low novelty, low impact): polish, optimization, known patterns applied to known problems. Low risk, low learning.
- **Sustaining** (low novelty, high impact): proven approaches applied where they'd make a big difference. Best ROI.
- **Radical** (high novelty, low impact): new technique or technology, applied to a contained area. High learning.
- **Disruptive** (high novelty, high impact): new approach that changes how the product fundamentally works. High risk, high reward.

Use this matrix to ensure ideation sessions don't cluster in one quadrant.

## Routing

Parse `$ARGUMENTS`:

### No arguments → product-level ideation

Read the current state:
1. `rhino feature` — what features exist, what's their state
2. `.claude/knowledge/experiment-learnings.md` (fall back to `~/.claude/knowledge/`) — Unknown Territory section
3. `config/rhino.yml` — value hypothesis, user definition, **feature maturity/weight/depends_on**
4. Recent git history — what's been built recently
5. Current scores if available (`rhino score .`)
6. `~/.claude/cache/last-retro.yml` — recent retro findings (if exists). Avoid proposing ideas in Dead End territory. Use stale patterns as brainstorming seeds — stale patterns are underexplored, not disproven.
7. `.claude/plans/todos.yml` — backlog items (ideas already captured but not built)
8. `.claude/plans/plan.yml` — active plan tasks
9. `.claude/plans/roadmap.yml` — current thesis and evidence_needed items. Identify `todo` and `partial` evidence items for the current version.

**Compute the product map** before generating ideas:
- Calculate product completion % from feature maturity × weight
- Identify the bottleneck (lowest-maturity, highest-weight feature)
- Identify `planned` features — these are the biggest opportunity for ideas
- Identify dependency gaps — features that depend on incomplete features

**Idea generation is informed by the product map:**
- At least 1 idea must target the bottleneck feature or its dependencies
- At least 1 idea must target a `planned` or `building` feature (not just polish)
- Ideas that would move a feature from `building → working` get priority over `working → polished`
- If product completion is <50%, bias toward Sustaining quadrant (proven patterns, high impact). If >70%, bias toward Radical/Disruptive (time to push boundaries).

**Thesis-aware ideation:**
- At least 1 of the 4 ideas MUST directly target an unproven (`todo` or `partial`) evidence item from the current thesis in roadmap.yml
- Tag that idea with `advances: [evidence_id]` in the brief
- Ideas that prove/disprove the thesis are higher value than ideas that just improve features — they decide what the NEXT version is about

Generate **4 ideas**, one per quadrant.

10. Count Unknown Territory entries in `experiment-learnings.md`. At least 1 of 4 ideas MUST target an Unknown Territory entry. Prefer the Radical quadrant for unknowns. Cite the specific entry.

### Feature name → feature-level ideation
`/ideate auth`, `/ideate scoring`

Focused brainstorm scoped to that feature:
1. Read the feature's assertions, code, pass rate
2. Read its maturity, weight, and dependencies from rhino.yml
3. Check what depends ON this feature — ideas here unblock downstream
4. Generate 4 ideas using the matrix, biased toward moving this feature to its next maturity level (e.g., building→working needs core functionality; working→polished needs edge cases and tests)

### `wild` → high-risk ideation
Moonshot mode. Generate 3 ideas that are all **Disruptive quadrant**:
- Have <30% chance of working
- Would be transformative if they did work
- Are in Unknown Territory (highest information value)
- Must each cite a specific Unknown Territory entry from experiment-learnings.md

### `[any text]` → constrained ideation
`/ideate "what if we dropped auth entirely"`, `/ideate "mobile-first redesign"`

Take the constraint/prompt and generate 3-4 ideas within that frame. Map each to a quadrant.

## The Idea Brief

Every idea must be a **brief**, not a bullet point. Each contains:

- **What**: 3-5 sentences describing what the user sees and does differently. Walk through the interaction step by step.
- **Why now**: What evidence or current state makes this the right moment? Cite experiment-learnings.md, current scores, recent history.
- **Who benefits**: Name the specific human and their specific situation.
- **What changes**: The measurable difference. What assertion would pass after this ships?
- **What kills it**: The failure mode. Be specific.
- **What you'd learn**: Even if the idea fails, what does the attempt teach you?
- **Assertions** (draft): 2-3 testable beliefs, previewed but NOT committed.

## Output format

```
◆ ideate — [scope or "product"]

  v8.0: **43%** · thesis: "Someone who isn't us can complete a loop without help"
  product: **64%** · score: 92 · bottleneck: **learning** (building, w:4)
  6 features · 3 unknowns · 5 backlog items · 2 unproven evidence items

▸ **Auto-grade predictions** — sustaining
  what: Session start hook reads predictions.tsv, checks git log for
        outcomes, fills in result/correct automatically. Founder sees
        "3 predictions graded since last session" on boot.
  why now: 16 predictions logged, only 8 graded. Manual grading is
           the bottleneck in the learning loop.
  who: the system itself — compounds over sessions
  changes: learning feature 48→65+ (prediction grading is #1 gap)
  kills it: predictions too vague to grade mechanically
  learns: whether mechanical grading is possible or needs human judgment
  draft assertions:
    - predictions with filled result columns are auto-graded on session start
    - grading accuracy matches human judgment >80% of the time

▸ **Visual score timeline** — incremental
  what: `rhino score .` appends to history.tsv (already does). New
        `/eval timeline` shows a sparkline of last 20 scores inline.
        Founder sees the trajectory, not just the number.
  why now: history.tsv has 1957 entries but no visualization
  who: solo founder checking if changes helped
  changes: scoring feature 58→65+ (trend visualization is PARTIAL)
  kills it: sparklines in terminal look bad at small widths
  learns: whether visual trends change founder behavior

▸ **Lens marketplace** — radical
  what: `rhino lens install github.com/user/lens-name` pulls a lens
        from any git repo. Lenses have a manifest.yml declaring what
        they measure. Community can build domain-specific measurement.
  why now: lens system is 80% of a registry (research confirmed)
  who: developer who wants rhino-os for their specific stack
  changes: install feature — makes rhino-os extensible
  kills it: no community yet. Marketplace without suppliers is empty
  learns: whether the lens abstraction is good enough for external use

▸ **Kill the CLI** — disruptive
  what: Remove bin/ entirely. Everything happens through slash commands.
        Score, eval, taste — all invoked as /eval, /score, not rhino eval.
        The product IS the Claude Code experience, not a CLI wrapper.
  why now: founder said "transform from CLI to within Claude Code"
  who: any Claude Code user — zero install friction
  changes: install feature goes to 100 (nothing to install)
  kills it: loses CI/script integration. Some users need CLI.
  learns: whether Claude Code commands can fully replace a CLI

[Present with AskUserQuestion — which direction interests you?]
```

## Materializing the Idea

When the founder picks an idea from the AskUserQuestion:

1. **Write feature to `config/rhino.yml`**:
   - `delivers:` from the idea's What field
   - `for:` from the idea's Who field
   - `code:` from a codebase scan (Glob for related files)
   - `status: active`
   - `weight:` estimated importance to value hypothesis (1-5)
   - `maturity: planned` (new features start as planned)
   - `depends_on:` if this feature requires another feature to work first
   - `origin: ideate`

2. **Convert draft assertions to `lens/product/eval/beliefs.yml`**:
   - Auto-detect type: `file_check` (file exists), `content_check` (file contains text), `score_trend` (score delta), `command_check` (command exits 0), `llm_judge` (Claude evaluates claim vs code)
   - Set `severity: warn` for all draft assertions

3. **Run baseline eval**: `rhino eval . --feature [name] --fresh`

4. **Log prediction**: "I predict [name] will start at [PARTIAL/MISSING] because [evidence]"
   Write to `.claude/knowledge/predictions.tsv`.

5. **Output** using `/feature new` template + "planted N assertions from idea brief"

```
/go [name]           build the new feature
/eval [name]         check progress
/research [topic]    validate before building
```

**Formatting rules:**
- Header: `◆ ideate — [scope]`
- Thesis line: `v[N]: **[pct]%**` version completion + current thesis quoted
- Context line: what was read (feature count, score, unknowns, unproven evidence count)
- Each idea: `▸ **[Name]** — [quadrant]` with brief fields indented
- Brief fields: what/why now/who/changes/kills it/learns/draft assertions
- No more than 5 ideas (paradox of choice)
- AskUserQuestion at the end — which direction?
- Bottom: 2-3 relevant next commands

## What makes good ideation

- **Specific, not generic.** "Add social features" is garbage. Walk through the interaction.
- **Grounded in evidence.** Cite experiment-learnings.md, scores, git history.
- **Includes the failure mode.** Every idea must include why it might not work.
- **Generates assertions.** An idea that can't be expressed as a testable belief isn't concrete enough.
- **Covers the matrix.** If all ideas cluster in one quadrant, push into the others.
- **Explores unknowns.** At least 1 of 4 ideas targets Unknown Territory from experiment-learnings.md. If `/retro` recently surfaced new unknowns (`~/.claude/cache/last-retro.yml`), 2 of 4 should target unknowns.

## Tools to use

**Use AskUserQuestion** for every decision point. Ideation is collaborative.

**Use WebSearch** when an idea needs external validation.

**Use Read** to check codebase state before proposing changes.

## What you never do
- Converge too early — this is divergence time, not planning
- Write code — ideation produces assertions and directions, not implementations
- Skip the failure mode — every idea must include why it might not work
- Generate thin ideas — a sentence is not an idea, a brief is an idea
- Cluster in one quadrant — spread across the innovation matrix
- Generate more than 5 ideas — paradox of choice kills momentum

## If something breaks
- No features defined: ideate at the product level, suggest `/feature new [name]`
- No experiment-learnings.md: ideate from codebase and config/rhino.yml only
- AskUserQuestion not available: present ideas as numbered list, ask for selection
- predictions.tsv missing: skip prediction logging, note it for the founder
- rhino.yml missing features: ideate at product level from README + code scan

$ARGUMENTS
