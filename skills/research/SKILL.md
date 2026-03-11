---
name: research
description: When you're stuck. Researches taste dimensions, market landscape, or any topic. Synthesizes findings into actionable knowledge. Say "/research [topic]" to dig in.
user-invocable: true
---

# Research — When You're Stuck

Your when-stuck command. Routes to the right research mode automatically.

## Setup

1. **Read workspace**: `~/.claude/state/workspace.json` — project context
2. **Read experiment learnings**: `~/.claude/knowledge/experiment-learnings.md` — what's already known
3. **Read taste knowledge index**: `~/.claude/knowledge/taste-knowledge/_index.md` — which dimensions are researched

## Execute

### Step 0: Route the Request

Parse the input to determine research mode:

| Input | Mode | What happens |
|-------|------|-------------|
| `/research` (no args) | Auto-detect | Check weakest taste dimension or current blocker → route to appropriate mode |
| `/research hierarchy` (taste dimension name) | Taste research | Research that taste dimension's patterns, exemplars, anti-patterns |
| `/research stale` | Taste refresh | Re-research dimensions older than 14 days |
| `/research [market topic]` | Market research | Scout-style landscape scan on that topic |
| `/research ideas` or `/research brainstorm` | Ideation | Product model + landscape + WebSearch → brainstorm options |
| `/research [any question]` | General research | WebSearch + synthesize findings |

**Taste dimension names** (triggers taste mode):
`hierarchy`, `breathing_room`, `contrast`, `polish`, `emotional_tone`, `information_density`, `wayfinding`, `distinctiveness`, `scroll_experience`, `layout_coherence`, `information_architecture`

### Mode: Taste Research

Execute the research-taste logic inline (from `skills/_internal/research-taste/SKILL.md`):

1. Read taste definitions from `agents/refs/design-taste.md`
2. Read freshness index — skip if researched within 14 days (unless `--force`)
3. Read founder preferences from `~/.claude/knowledge/founder-taste.md`
4. **WebSearch** for patterns, exemplars, anti-patterns
5. **WebFetch** top 3-5 results, extract specific mechanisms
6. **Synthesize** → write to `~/.claude/knowledge/taste-knowledge/{dimension}.md`
7. **Update index** → `~/.claude/knowledge/taste-knowledge/_index.md`

### Mode: Market Research

Execute scout logic inline (from `skills/_internal/scout/SKILL.md`):

1. Read current landscape positions from `~/.claude/knowledge/landscape.json`
2. Read landscape model from `agents/refs/landscape-2026.md`
3. **WebSearch** for the topic — competitors, trends, evidence
4. **WebFetch** top results, extract positions (opinionated statements, not trends)
5. **Synthesize** → update `~/.claude/knowledge/landscape.json` and `agents/refs/landscape-2026.md`
6. Required: "What I Didn't Find" section (min 5 items)

### Mode: General Research

1. **WebSearch** for the question/topic
2. **WebFetch** top 3-5 results
3. **Synthesize** findings into actionable knowledge
4. Write to `~/.claude/knowledge/research/{topic-slug}.md`
5. Surface the key insight: "Here's what I found and what it means for your project"

### Mode: Ideation

When triggered by `/research ideas` or `/research brainstorm`:

1. Read product model (`.claude/plans/product-model.md`) — identify weak loop links
2. Read landscape model (`agents/refs/landscape-2026.md`) — what wins in 2026
3. **WebSearch** for products solving similar problems to the current project
4. Synthesize into "patterns other products use for [weak link]"
5. Write to `~/.claude/knowledge/research/ideation-[date].md`
6. Read `.claude/plans/milestones.md` — append promising ideas to `## Ideas (not commitments)` section
   - Format: `- [idea] — [which loop link it targets] (from research)`

### Auto-detect Logic (no args)

1. Check current sprint plan — is there a blocker mentioned?
2. Check taste eval — is there a weakest dimension that hasn't been researched?
3. Check builder brain — did builder flag something it doesn't know?
4. Pick the highest-leverage research target based on these signals

## Output

Always ends with:
```
## Research Complete

**Topic**: [what was researched]
**Key finding**: [one actionable insight]
**Saved to**: [file path]
**Next step**: [what to do with this knowledge — usually "run /build"]
```

## Teardown

1. **Update scout brain** (if market research ran): `~/.claude/state/brains/scout.json`
2. **Update taste knowledge index** (if taste research ran)
3. Log to predictions.tsv if a prediction was made about research quality
