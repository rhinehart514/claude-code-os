# Knowledge System Template

This directory is a template for creating new learning agents — agents that build persistent knowledge across sessions and get smarter over time.

## The Pattern

A learning agent has:
1. **A knowledge base** — files that persist between sessions
2. **A search/discovery process** — how it finds new information
3. **A self-eval rubric** — how it grades its own output
4. **A feedback loop** — eval results feed back into search strategy

## Files in This Template

| File | Format | Purpose |
|------|--------|---------|
| `knowledge.md` | Markdown | Accumulated pattern-level insights. The "what do we know?" file. |
| `confidence-scores.jsonl` | JSONL | Track confidence in each pattern: WEAK → STRONG → CONFIRMED → DISPROVEN |
| `eval-history.jsonl` | JSONL | Score tracking across sessions. Enables trend detection in agent quality. |
| `search-strategy.md` | Markdown | Living document of what searches work and which don't. Self-adapts. |
| `acted-on.jsonl` | JSONL | Closes the loop: did acting on knowledge lead to results? |

### JSONL Format

Structured data uses [JSONL](https://jsonlines.org/) (one JSON object per line) instead of markdown tables. This enables:
- Machine-readable querying via `jq`
- Appending without parsing
- Deterministic updates

**confidence-scores.jsonl** — one entry per pattern:
```json
{"pattern":"example-pattern","confidence":"WEAK","updated":"2026-01-01","evidence_count":1,"notes":"seed entry"}
```
Confidence levels: `WEAK` → `STRONG` → `CONFIRMED` → `DISPROVEN`

**eval-history.jsonl** — one entry per eval session:
```json
{"date":"2026-01-01","session":0,"score":0,"finding":"seed entry","adjustment":"none"}
```

**acted-on.jsonl** — one entry per acted-on item:
```json
{"date_acted":"2026-01-01","item":"example","action":"tested","outcome":"pending","revenue":"none"}
```

### Querying Knowledge

Use the included query script:
```bash
# List confirmed patterns
./automation/scripts/query-knowledge.sh my-agent confirmed

# List weak patterns needing more evidence
./automation/scripts/query-knowledge.sh my-agent weak

# Show eval score trend
./automation/scripts/query-knowledge.sh my-agent eval-trend

# Find stale entries (not updated in 30+ days)
./automation/scripts/query-knowledge.sh my-agent stale 30
```

## How to Create a New Learning Agent

1. Copy this `_template/` directory to `knowledge/[agent-name]/`
2. Create an agent definition in `agents/[agent-name].md`
3. Create an eval rubric in `evals/rubrics/[agent-name]-rubric.md`
4. In the agent definition, add STEP 0: read all knowledge files before doing anything
5. Add self-eval as the final step (grade output against rubric)
6. Add search strategy self-update (what worked → repeat, what didn't → replace)

## The Compounding Rule

The knowledge base only compounds if:
1. Each session READS past evals and adjusts behavior
2. Confidence scores are UPDATED each session (not just added)
3. Dead ends are EXPLICITLY marked so the agent doesn't revisit them
4. The search strategy EVOLVES based on what's working
5. `acted-on.jsonl` closes the loop: "did acting on this knowledge lead to results?"

Without all 5, you have a search wrapper, not a learning system.

## Example: Money Scout

The `money-scout` agent is the reference implementation of this pattern:
- Scans for business opportunities across multiple platforms
- Builds a knowledge base of patterns, trends, and price points
- Self-evaluates each session against a rubric
- Adapts its search strategy based on what yields high-signal results
- Tracks which opportunities were acted on and what happened

See `knowledge/money-scout/` and `agents/money-scout.md` for the full implementation.
