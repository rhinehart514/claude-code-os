# Standards — What Quality Means

This is taste, not process. What 0.1% looks like, and the traps that fake it.

## The Measurement Hierarchy

Three tiers, in order of what matters:

1. **Value** — Does the user get something they care about? (the only thing that matters)
2. **Craft** — Is the experience well-made? (amplifies value, can't replace it)
3. **Health** — Is the code clean and stable? (enables craft, invisible to users)

Most dev tools measure bottom-up: health → craft → maybe value. rhino-os measures top-down. A product with rough edges that delivers clear value beats a polished product that doesn't.

**How they map to tools:**
- `rhino score .` → Health (structural lint: build, structure, hygiene)
- `rhino taste` → Craft (visual eval: hierarchy, polish, tone, density)
- `rhino eval .` → Value (assertion pass rate: do the things that matter actually work?)

Score and taste are SUPPORTING metrics. They tell you the code is healthy and the UI looks good. But a 100/100 score with zero value is a beautiful corpse. **Eval pass rate is the north star.**

## The Value Checklist

Before every feature, ask these. If you can't answer them, you're building in the dark.

1. **Who gets value?** — Name the human. "Users" is not a name. "A solo founder who just cloned this and wants their project to get better in one session" is.
2. **What changes for them?** — After they use this feature, what's different? If nothing is measurably different, it's not value.
3. **How fast?** — Time from "I found this" to "I got value." Every minute is a chance to lose them. Target: value in the first session, ideally first 5 minutes.
4. **Would they notice if it disappeared?** — If you removed this feature tomorrow, would anyone complain? If not, it's not value — it's furniture.
5. **What's the return trigger?** — Why would they come back tomorrow? If there's no pull, they won't.

## The UX Checklist (Craft Layer)

After every feature or significant UI change, check your own work against these.
LLMs consistently miss them. You will too unless you explicitly check.

1. **Empty state** — What does a new user with zero data see? Blank screen = bug. Add guidance, a CTA, sample content.
2. **Dead ends** — After the user completes the action, where do they go? Every page leads somewhere.
3. **Loading states** — Every async operation: loading, success, error. Skeleton > spinner > nothing.
4. **Visual hierarchy** — What's the first thing the eye hits? One primary action per screen. Secondary elements recede.
5. **First-time experience** — Pretend you've never seen the product. Is it obvious what to do? If it requires prior context, explain it.
6. **Mobile** — Does it work at 390px? Tables readable? Touch targets 44px? No horizontal scroll.
7. **User feedback** — After every action, does something visible change? Silent actions feel broken.
8. **Form edge cases** — Required indicators, inline validation, error messages by the field, disabled submit until valid, no double-submit.
9. **Navigation coherence** — Can the user get back? Can they find this page from main nav?
10. **Information density** — Too much? Progressive disclosure. Too little? More context. Match density to task.

These aren't polish. They're the gap between "code that works" and "product users love."

## Anti-Gaming Heuristics

Scores lie when you let them. Watch for:

- **Cosmetic-only changes** — Shuffled comments, renamed variables, reformatted code. If the user can't see the difference, the score shouldn't change.
- **Inflation** — 15+ point jump in one commit? Something's wrong. Real improvement is incremental.
- **Plateau** — Score hasn't moved in 5+ experiments? The current approach is exhausted. Rethink, don't iterate.
- **Stage ceiling** — An MVP scoring 95/100? The score is wrong, not the product.

Fix the product, not the score. The score is a thermometer, not a thermostat.

## Experiment Discipline

When running experiments (autoresearch-style):

- **One mutable file** per experiment. Multi-file = feature, not experiment.
- **Immutable eval harness** — score.sh and taste.mjs cannot change during an experiment.
- **15-minute cap** — Longer = feature, not experiment.
- **Mechanical keep/discard** — Score up AND target dimension improved → keep. Otherwise → revert. No negotiation.
- **Moonshot every 5th** — Every 5th experiment must be high-risk, high-information. Explore unknown territory.
