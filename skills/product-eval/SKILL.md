---
name: product-eval
description: Full product audit against 2026 consumer standards. Not a feature eval — a "would anyone use this?" eval. Runs against the whole app. Say "/product-eval" anytime.
user-invocable: true
---

# Product Eval — Would Anyone Care?

This is not a code check. This is a product check. You are a 19-year-old who just got a link. You have Instagram, TikTok, Discord, iMessage, and GroupMe on your phone. You give new apps about 4 seconds.

## Step 0: Context

1. Read the project's CLAUDE.md — who is the user, what stage, what's the core loop?
2. Read previous product eval reports in `.claude/evals/reports/product-eval-*.md`
3. Read `.claude/evals/reports/history.jsonl` for recurring ceiling gaps
4. Read docs like PRODUCT-STRATEGY.md, PERSPECTIVES.md if they exist

## Step 1: The 4-Second Test

Read the landing/marketing page. Answer honestly:

- **What is this?** Can you tell in 4 seconds? Not from the tagline — from the FEELING of the page.
- **Who is it for?** Does the page signal its audience visually, not just in copy?
- **Why now?** Is there urgency or just information?
- **Would you tap "Sign up"?** Or close the tab?

Score: 0.0-1.0. A 0.5 means "I'd consider it if someone I trust told me to." A 0.8 means "I'm signing up right now."

## Step 2: The Empty Room Test

Read the main authenticated pages (feed/home, spaces list, profile). Simulate a new user who just signed up, knows nobody, has joined nothing.

- **What do they see?** Read the actual empty states in the code.
- **Does the product feel alive or dead?** "No events right now" = dead. "3 orgs near you are posting right now" = alive.
- **Is there a clear first action?** Not "explore" — a specific thing to DO.
- **How many taps to first value?** From signup to "I made something and someone saw it."

Score: 0.0-1.0. Compare to: opening Discord for the first time (guided server discovery), opening Instagram (instant content), opening Duolingo (immediate lesson).

## Step 3: The Creation-to-Distribution Test

Read the creation flow and everything that happens after creating something.

- **Creation speed**: Taps from intent to output. Under 3 taps is great, over 5 is friction.
- **Distribution**: After creating, how does it reach people? Is "share" the primary action or an afterthought?
- **Channel fit**: Can the output go where the audience already is? (GroupMe, iMessage, Instagram stories, Snapchat). Or does it only live inside the app?
- **Social proof on the output**: When someone receives the shared thing, does it show activity? ("47 people voted") Or is it cold?

Score: 0.0-1.0. A 0.8 means the created thing reaches people as easily as sending a text.

## Step 4: The Day 3 Test

Simulate returning to the app 3 days later. Read the home/feed page.

- **Is anything different from day 1?** New content, notifications, "since you left" signals?
- **Does the app know you?** Personalization, context from your orgs, smart defaults?
- **Is there a pull mechanism?** Push notifications, email digest, "your poll got 200 votes"?
- **What would make you NOT open this?** Be honest about the alternative (checking GroupMe instead).

Score: 0.0-1.0. A 0.3 means the second visit is identical to the first. A 0.8 means the app surprised you with something relevant.

## Step 5: The Competitive Gut Check

For each major screen, compare to the app the user would otherwise use for this job:

| Screen | Competing With | Question |
|--------|---------------|----------|
| Feed/Home | Instagram Explore, Discord home | Is there always something here? |
| Spaces | Discord servers, GroupMe groups | Can I feel the vibe before entering? |
| Create | Instagram Stories polls, Google Forms | Is this faster AND better? |
| Events | UB events portal, word of mouth | Would I check here first? |
| Profile | LinkedIn, Instagram bio | Does this make me look good? |
| Share output | iMessage link, GroupMe post | Does this preview well? |

For each: WINS / LOSES / TIES. Be honest. Ties go to the incumbent (the app they already use).

## Step 6: The Identity Test

Read the design system, components, and overall visual treatment.

- **Could you swap the logo and mistake this for another app?** If yes, the identity is too generic.
- **Is there a signature interaction?** Something only this product does. A feeling, an animation, a moment.
- **Does the visual language match the audience?** College students, not enterprise. Culture, not productivity.
- **Is there warmth?** Photography, illustration, personality in copy, humor — anything human?
- **The screenshot test**: Would a user screenshot any screen and share it because it looks cool?

Score: 0.0-1.0. A 0.3 means "dark mode SaaS template." A 0.8 means "I know exactly what app this is from a screenshot."

## Step 7: Escape Velocity Assessment

These determine whether the product can break out or will stay stuck:

- **Network effects**: Does the product get better as more people use it? How specifically?
- **Content compounding**: Does user-generated content accumulate value, or is each creation isolated?
- **Habit formation**: What's the trigger → action → reward → investment loop? Is it real?
- **Viral coefficient**: If one person creates something, how many new people see it? Through what channel?
- **Switching cost**: After 30 days of use, what would you lose by leaving?

Score each 0.0-1.0.

## Step 8: Verdict

```markdown
## Product Eval: [product] — [date]

### The 4-Second Test: X.X/1.0
[What a new visitor sees and feels]

### The Empty Room Test: X.X/1.0
[What a new user with no connections experiences]

### Creation-to-Distribution: X.X/1.0
[How fast creation reaches people]

### Day 3 Return: X.X/1.0
[Whether there's a reason to come back]

### Competitive Position
| Screen | vs. | Verdict |
|--------|-----|---------|
| [screen] | [competitor] | WINS/LOSES/TIES |

### Identity: X.X/1.0
[Template or branded?]

### Escape Velocity
| Dimension | Score | Assessment |
|-----------|-------|------------|
| Network effects | X.X | [how specifically] |
| Content compounding | X.X | [isolated or accumulating] |
| Habit formation | X.X | [trigger→action→reward→investment] |
| Viral coefficient | X.X | [one creates, how many see?] |
| Switching cost | X.X | [what you'd lose by leaving] |

### Overall: X.X/1.0
[One sentence: would this product survive its first 100 users?]

### What's Keeping This Generic
[Ranked list: the specific things making this feel like every other app]

### The 3 Changes That Would Matter Most
[Not features — product-level shifts that change the trajectory]
1. [Change]: [Why this changes the outcome, not just the product]
2. [Change]: [Why]
3. [Change]: [Why]

### Ceiling Gaps (feed forward to builder)
- [gap] → [what the next plan must address]
```

## Step 9: Save Report

Save to `.claude/evals/reports/product-eval-[date].md`

Append to `.claude/evals/reports/history.jsonl`:
```json
{"date":"2026-03-08","type":"product-eval","feature":"full-product","four_second":0.5,"empty_room":0.3,"creation_distribution":0.6,"day3_return":0.2,"identity":0.3,"escape_velocity":0.35,"overall":0.38,"verdict":"NOT READY","top_gaps":["distribution is an afterthought","empty states kill momentum","visual identity is generic dark mode"]}
```

This feeds into builder gate mode. The next feature decision must account for these scores. If escape_velocity is 0.35, don't build another feature — fix the distribution loop.
