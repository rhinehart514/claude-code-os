# Design Engineer — Eval Rubric

Grade each session by mode. Threshold: 0.6 average.

## Mode 1: Scout — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Actionable | Exact steps to use each find | "Interesting trends" | Pure commentary |
| Novel | New finds not in knowledge.md | Confirming known patterns | Copy of last session |
| Specific | Font names, hex codes, configs | Tool recommendations | "Clean and modern" |
| Brief | 10-line output, no filler | Reasonable length | Multi-page report |

## Mode 2: Audit — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Coverage | All 5 checks run (tokens, states, a11y, consistency, read worst files) | 3+ checks | Skimmed one file |
| Specificity | File paths, line numbers, exact classes | General areas of concern | "Your UI needs work" |
| Prioritization | Top 10 ranked by user impact with fix complexity | Unranked list | Dump of grep output |
| The One Thing | Single highest-leverage fix, actionable | Reasonable suggestion | Vague direction |
| Codebase-aware | Matches project's actual stack/conventions | Mostly relevant | Generic advice |

## Mode 3: Build — Grade on (0.0-1.0 each)

| Dimension | 1.0 | 0.4 | 0.0 |
|-----------|-----|-----|-----|
| Pattern matching | New code matches existing codebase conventions exactly | Mostly consistent | Introduced new patterns |
| Completeness | Fixed ALL instances (not just one file) | Fixed most | Fixed one example |
| Safety | Build/types/lint pass after changes | Minor issues | Broke the build |
| Tier discipline | Tier 1 auto-fixed, Tier 3 asked first | Mostly followed | Changed architecture without asking |
| Impact | Visible improvement a user would notice | Technical improvement | Moved code around, looks the same |

## Red Flags (auto-deduct 0.2)

- Recommending Dribbble designs nobody ships
- "Clean and modern" without specifics
- Ignoring accessibility
- Introducing a new styling approach the project doesn't use
- Fixing one button but leaving 20 identical ones untouched
- Generating components that duplicate existing ones
- Not running build/lint after changes
