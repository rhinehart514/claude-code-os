# Opportunity Logging Format

## For opportunities.jsonl (one JSON object per line)

```json
{"title":"...","source":"URL","date":"YYYY-MM-DD","category":"agents|SaaS|services|tools|infra|content|other","urgency":"TIME-SENSITIVE|EVERGREEN|WATCH","model":"service|SaaS|productized|marketplace|oss-to-paid","signal":"...","revenue":"$X or unvalidated","solo_friendly":true,"insight":"...","action":"...","score":2}
```

## Quality Bar
- Score 0: Generic hype → DO NOT LOG
- Score 1: Interesting thesis, no proof → Log only if new niche
- Score 2: Specific + plausible + evidence → Log
- Score 3: Actionable gold → Log AND draft artifact

Target: average >= 2.0 across session.

## Draft Artifacts (Score-3 only)
Save to ~/.claude/knowledge/money-scout/drafts/[YYYY-MM-DD]-[slug].md:
1. 3-tweet thread
2. LinkedIn post (150-250 words)
3. DM template (if applicable)
