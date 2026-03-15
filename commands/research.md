---
description: "Explore unknown territory. /research picks the top unknown. /research auth digs into a feature. /research docs <lib> pulls real-time docs. /research site <url> analyzes a live site. /research claude-code maps extension points."
---

# /research

You are a cofounder doing research — filling gaps in the knowledge model so the next build session is smarter. This is the multi-source intelligence engine.

## Routing

Parse `$ARGUMENTS`:

| Input | Mode | Primary tools |
|-------|------|---------------|
| (none) | Top unknown | All available |
| `auth`, `scoring` | Feature deep-dive | Grep/Glob + context7 + WebSearch |
| `"topic"` | Free-form | WebSearch + WebFetch + context7 |
| `docs <library>` | Library docs | context7 (resolve-library-id → query-docs) |
| `site <url>` | Live site analysis | playwright (navigate, snapshot, evaluate) |
| `claude-code` | Claude Code capabilities | context7 docs + ~/.claude/ introspection |
| `competitor <name>` | Competitive analysis | WebSearch + playwright + synthesis |

### No arguments → pick the top unknown
Read `.claude/knowledge/experiment-learnings.md`, find the **Unknown Territory** section. Pick the unknown with the highest information value (the one that, if answered, would change the most decisions).

State what you're researching and why it's the top priority.

### Feature name → research that feature
`/research auth`, `/research scoring`

Deep dive into the feature:
1. Read all assertions for the feature (`rhino feature [name]`)
2. Trace the codebase — find every file related to this feature (grep, imports, dependencies)
3. Map what exists vs what's missing
4. Pull library docs via context7 if the feature uses external frameworks
5. WebSearch for best practices, competitor approaches, common patterns
6. Update experiment-learnings.md with findings (under Uncertain Patterns or Unknown Territory)

### `docs <library>` → real-time library documentation
`/research docs react`, `/research docs next.js`, `/research docs tailwind`

The most accurate source of library knowledge. Uses context7 MCP:
1. Call `resolve-library-id` with the library name to get the context7 ID
2. Call `query-docs` with the ID and a relevant topic query
3. Synthesize findings — real docs beat web search hallucinations every time
4. Cross-reference with codebase usage (Grep/Glob)

### `site <url>` → live site analysis
`/research site https://example.com`

Visual and structural analysis of a live site using playwright:
1. `browser_navigate` to the URL
2. `browser_snapshot` for accessibility tree / structure
3. `browser_take_screenshot` for visual analysis
4. `browser_evaluate` for DOM inspection (heading hierarchy, click targets, etc.)
5. `browser_network_requests` if performance matters
6. Synthesize into findings with evidence

### `claude-code` → Claude Code capabilities research
Map what Claude Code provides and what rhino-os extends:
1. Read `~/.claude/` directory structure — rules, commands, hooks, settings
2. Use context7 to pull Claude Code documentation
3. Introspect available MCP tools (context7, playwright, Vercel)
4. Map extension points: what can be customized, what's fixed
5. Identify gaps — what rhino-os should use but doesn't

### `competitor <name>` → competitive analysis
`/research competitor cursor`, `/research competitor devin`

1. WebSearch for the competitor's features, pricing, reviews
2. If they have a public site, use playwright to analyze UX
3. Map their approach vs rhino-os approach
4. Identify what they do that we don't, and vice versa
5. Synthesize into actionable findings

### Quoted topic → investigate anything
`/research "mobile layouts"`, `/research "social proof mechanics"`

Free-form research:
1. Auto-select sources based on topic (see multi-source protocol below)
2. Cross-reference findings across sources
3. Form hypotheses with evidence
4. Write findings to experiment-learnings.md

## Multi-source investigation protocol

### 1. Source selection
Auto-determine which sources to use based on the topic:

- **docs** (context7): resolve-library-id → query-docs. Use when the topic involves a library, framework, or API. Real-time accurate docs vs web search hallucinations.
- **web** (WebSearch + WebFetch): blog posts, discussions, best practices. Use for patterns, approaches, industry knowledge.
- **site** (playwright): browser_navigate + browser_snapshot + browser_evaluate. Use when visual or structural analysis of a live product matters.
- **codebase** (Grep/Glob/Read): internal patterns, existing implementations. Always check.
- **knowledge** (experiment-learnings.md): avoid re-researching known patterns. Check what we already know.

### 2. Cross-referencing
Findings from one source feed queries to another:
- Web reveals a pattern → check codebase for existing usage → pull docs for the library
- Codebase uses a library → pull context7 docs → web search for advanced patterns
- Site analysis reveals a technique → web search for implementation → check docs

### 3. Actionable output
Every research session must end with one of:
- **Task proposal** — specific work for /plan to pick up
- **Assertion proposal** — testable belief for beliefs.yml
- **Model update** — pattern added to experiment-learnings.md
- **Specific next experiment** — what to try and what it would prove

## The research protocol

Every research session produces:

### 1. Prediction
```
I predict: [what I expect to find]
Because: [prior knowledge or "exploring unknown territory"]
I'd be wrong if: [what would surprise me]
```
Log to `.claude/knowledge/predictions.tsv`.

### 2. Investigation
Use these tools based on the route:
- **context7** — resolve-library-id + query-docs for any library/framework docs. Prefer this over web search for technical documentation.
- **WebSearch + WebFetch** — external knowledge, best practices, competitor analysis
- **playwright** — browser_navigate, browser_snapshot, browser_evaluate for live site analysis
- **Grep/Glob/Read** — codebase exploration
- **Agent (Explore)** — deep codebase analysis when needed

Run multiple sources in parallel where possible.

### 3. Synthesis
Don't dump raw findings. Synthesize into the output format below.

### 4. Model update
Write findings to `.claude/knowledge/experiment-learnings.md`:
- New known pattern → add to Known Patterns with evidence
- Hypothesis formed → add to Uncertain Patterns with "Needs:" line
- New unknown discovered → add to Unknown Territory
- Dead end confirmed → add to Dead Ends

### 5. Write research artifact
Write `~/.claude/cache/last-research.yml` so /plan can read it:
```yaml
date: YYYY-MM-DD
topic: [what was researched]
mode: [docs|site|feature|free-form|claude-code|competitor|top-unknown]
findings:
  - finding: [one-line summary]
    source: [context7|web|playwright|codebase|knowledge]
    detail: [2-3 sentences]
suggested_tasks:
  - [task description for /plan to pick up]
suggested_assertions:
  - [testable belief for beliefs.yml]
model_updates:
  - section: [Known|Uncertain|Unknown|Dead Ends]
    entry: [what was added/changed]
```

### 6. Grade prediction
Fill in the prediction result in predictions.tsv. Was I right? What did I learn?

## Output format

```
◆ research — [topic or feature name]

  predict: [what I expected to find]
  because: [evidence or "unknown territory"]
  sources: [context7, web, codebase, playwright — which were used]

▾ findings
  · [finding 1] — [source: context7/web/playwright/codebase]
    [2-3 sentences of detail]

  · [finding 2] — [source]
    [2-3 sentences of detail]

  · [finding 3] — [source]
    [2-3 sentences of detail]

▾ what this changes
  · [how the next build session should be different]
  · [what pattern was confirmed/denied]

▾ model update
  Known:     +1 pattern (or "no new patterns")
  Uncertain: +1 hypothesis (or "none")
  Unknown:   +1 new unknown (or "none surfaced")
  Dead ends: +1 confirmed (or "none")

  verdict: ✓ prediction correct | ✗ wrong — [what surprised me] | — partial

▾ actionable
  · task: [specific work for /plan]
  · assert: [testable belief for beliefs.yml]
  · next: [highest-information experiment to run]

/plan [feature]   turn findings into tasks
/go [feature]     build on what we learned
/ideate           brainstorm from new patterns
```

**Formatting rules:**
- Header: `◆ research — [topic]`
- Prediction block: predict/because/sources, indented
- Findings: bullet list with source attribution, each with detail
- Model update: compact summary of what changed in experiment-learnings.md
- Verdict: ✓/✗/— with explanation
- Actionable: task proposals, assertion proposals, next experiments
- Bottom: 2-3 relevant next commands

## Tools to use

**Use context7** (resolve-library-id → query-docs) for any library or framework documentation. This is the biggest upgrade — real-time accurate docs vs web search hallucinations. Always prefer context7 for technical docs.

**Use playwright** (browser_navigate, browser_snapshot, browser_evaluate) for live site analysis. Visual and structural understanding of real products.

**Use WebSearch and WebFetch** for external research — blog posts, discussions, patterns, competitor analysis.

**Use Agent (Explore)** for deep codebase analysis — tracing dependencies, mapping architecture.

**Use Agent (general-purpose)** for parallel research threads — e.g., research competitors AND codebase simultaneously.

## What you never do
- Research without a prediction (rule 1: predict before you act)
- Dump raw search results without synthesis
- Skip the model update — research that doesn't update the model didn't happen
- Skip the research artifact — /plan needs last-research.yml to incorporate findings
- Research for longer than 15 minutes without producing a finding
- Output walls of raw text — use the template above
- Use web search for library docs when context7 is available — context7 is more accurate

## If something breaks
- context7 fails: fall back to WebSearch + WebFetch for docs
- playwright fails: fall back to WebSearch for site analysis
- WebSearch fails: use codebase-only research + experiment-learnings.md
- No experiment-learnings.md: create it with the standard template
- No predictions.tsv: create it with headers

$ARGUMENTS
