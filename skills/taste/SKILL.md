---
name: taste
description: Run visual taste eval on the current project. Wraps bin/taste.mjs with context — weakest dimension, suggested action, feature breakdown. Say "/taste" anytime.
user-invocable: true
---

# Taste — Visual Quality Eval

Run the rhino-os taste evaluation on the current project.

## Execute

```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/taste.mjs"
```

If a feature is specified (e.g., `/taste spaces`), pass it:
```bash
"${RHINO_DIR:-$HOME/rhino-os}/bin/taste.mjs" --feature [feature-name]
```

## Present Results

Parse the output and present:

1. **Overall taste score**: X/100
2. **11 Dimensions**: score each 1-5
   - hierarchy, breathing_room, contrast, polish, emotional_tone
   - information_density, wayfinding, distinctiveness, scroll_experience
   - layout_coherence, information_architecture
3. **Weakest dimension**: which one and why
4. **One thing**: the single most impactful fix
5. **Would return?**: yes/no assessment
6. **Would recommend?**: yes/no assessment

## Context

- Compare to previous taste evals in `.claude/evals/taste-history.tsv`
- Show trend: improving/declining/flat
- If feature-specific, show how this feature compares to others
- Show integrity warnings if taste scores seem inflated vs stage ceiling

## After

Update workspace.json `last_taste` if workspace helper is available.
Suggest: "Run /build to address the weakest dimension" or "Run /experiment [dimension] for targeted improvement."
