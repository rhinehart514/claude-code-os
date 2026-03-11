---
name: research-taste
description: Autonomously researches taste dimensions to build grounded knowledge. WebSearch + WebFetch for patterns, exemplars, anti-patterns. Say "/research-taste [dimension]" or "/research-taste all" for full refresh.
user-invocable: true
---

# Research Taste — Grounded Taste Dimension Research

## Setup
1. **Read taste definitions**: `agents/refs/design-taste.md` — the 11 dimensions and current definitions
2. **Read freshness index**: `~/.claude/knowledge/taste-knowledge/_index.md` if it exists — which dimensions are stale?
3. **Read founder preferences**: `~/.claude/knowledge/founder-taste.md` if it exists — ground research in founder taste
4. **Check autonomy**: read workspace.json for current autonomy level

## Execute

### Step 0: Determine Target
- If user specifies a dimension name (e.g., "wayfinding"), research that one
- If user says "all", research all 11 dimensions
- If user says "stale", only research dimensions older than 14 days (from _index.md)
- Default freshness TTL: 14 days. Skip if researched within TTL unless --force

The 11 dimensions:
`hierarchy`, `breathing_room`, `contrast`, `polish`, `emotional_tone`, `information_density`, `wayfinding`, `distinctiveness`, `scroll_experience`, `layout_coherence`, `information_architecture`

### Step 1: Research Loop (per dimension)

For each dimension to research:

**1a. WebSearch** — search for:
- "[dimension] UX best practices 2025 2026"
- "[dimension] design patterns examples"
- "best [dimension] in web apps"
- Product-specific: "how [Linear/Notion/Discord/Arc] handles [dimension]"

Search strategy (from scout): classify searches as high-yield, standard, low-yield. Start with high-yield. Move to standard if high-yield is thin. Skip low-yield unless forced.

**1b. WebFetch** — fetch top 3-5 results from search. Extract:
- Specific patterns (mechanisms, not opinions)
- Exemplar products with specific implementation details
- Anti-patterns with reasons they fail
- Cognitive/UX research backing (if found)

**1c. Synthesize** — write/update the knowledge file at `~/.claude/knowledge/taste-knowledge/{dimension}.md`

Format:
```markdown
# {Dimension Title} — {One-line description}

## Last Researched: {date}
## Sources: {URLs and products studied}
## Freshness: {days since last research} days (refresh if >14 days)

## Patterns (what works)
- Pattern: {specific mechanism}
  - Why: {cognitive/UX reason}
  - Exemplar: {product + specific implementation}
  - Evidence: {source or observation}

## Anti-Patterns (what fails)
- Anti-pattern: {what to avoid}
  - Why it fails: {mechanism}
  - Example: {product that does this badly}

## Founder Calibration
- {Any founder preferences from founder-taste.md for this dimension}
- {Or "No founder preferences recorded yet"}

## Scoring Guide (grounded)
- 5/5: {specific bar, citing exemplar from patterns above}
- 3/5: {specific bar}
- 1/5: {specific bar}
```

**1d. Update Index** — update `~/.claude/knowledge/taste-knowledge/_index.md`:
```markdown
# Taste Knowledge Index

| Dimension | Last Researched | Staleness | Sources |
|-----------|----------------|-----------|---------|
| wayfinding | 2026-03-11 | fresh | 5 |
...
```

### Step 2: Summary
After researching all targeted dimensions, output:
- Which dimensions were researched
- Key patterns discovered
- Which dimensions need founder calibration (no preferences recorded)
- Next recommended research target

## Output
Creates/updates:
- `~/.claude/knowledge/taste-knowledge/{dimension}.md` — one per researched dimension
- `~/.claude/knowledge/taste-knowledge/_index.md` — freshness tracker

## Teardown
- No brain to update (this skill doesn't have its own brain)
- Log to predictions.tsv if a prediction was made about research quality
