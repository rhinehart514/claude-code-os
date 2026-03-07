# Design Engineer — Eval Rubric

Grade each session by mode. Threshold: 0.6 average.

## Init — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Detection accuracy | Correctly identified stack, styling, component lib | Got framework right, missed details | Wrong stack detection |
| Token extraction | Found all existing design tokens, documented exact values | Found most tokens | Invented tokens instead of detecting |
| Direction fit | Aesthetic matches what the project already is | Reasonable guess | Imposed a direction that contradicts existing code |
| system.md quality | Complete, specific, enforceable decisions | Partial, some vague sections | Template with placeholders unfilled |

## Audit — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Coverage | All 5 checks run (tokens, states, a11y, consistency, craft) | 3+ checks | Skimmed one file |
| Specificity | File:line, exact classes, proposed fix | General areas of concern | "Your UI needs work" |
| system.md enforcement | Cross-referenced every finding against design decisions | Mentioned system.md | Ignored it |
| Prioritization | Top 5 ranked by user impact + fix complexity | Unranked list | Raw grep dump |
| Score tracking | Appended to audit-history.jsonl, compared to last audit | Logged score | No history update |

## Build — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Pattern match | All new code matches codebase conventions exactly | Mostly consistent | Introduced new patterns |
| Completeness | Fixed ALL instances project-wide | Fixed most | Fixed one file |
| Safety | Build + types pass after changes | Minor warnings | Broke the build |
| Tier discipline | T1 auto-fixed, T2 read context, T3 asked first | Mostly followed | Changed architecture without asking |
| system.md update | New decisions documented for next session | Mentioned updates needed | No memory update |
| Anti-slop | Actively fought convergence — distinctive choices preserved | Neutral | Made it more generic |

## Red Flags (auto-deduct 0.2 each)

- "Clean and modern" without specifics (the phrase itself is AI slop)
- Ignoring accessibility
- Introducing a styling approach the project doesn't use
- Fixing one instance but leaving identical ones untouched
- Generating components that duplicate existing ones
- Not running build after changes
- Contradicting decisions in system.md
- Using Inter/blue-gray/shadow-sm/rounded-lg as defaults without checking what project actually uses
