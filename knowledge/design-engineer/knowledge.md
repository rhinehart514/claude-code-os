# Design Intelligence — Accumulated Knowledge

## The AI Slop Problem (2026)
- LLMs converge to the median of Tailwind tutorials scraped 2019-2024: Inter, blue-gray, rounded-lg, shadow-sm, p-4
- This is "distributional convergence" — every AI-built app looks the same
- Anthropic's own frontend-design plugin exists to fight this (~400 tokens, pushes toward distinctive choices)
- Fix: detect what the project already has, amplify its personality, don't impose defaults

## What Breaks in AI-Generated UI
- First screen looks great, second screen falls apart — AI optimizes for the demo
- Happy path only — no loading, empty, error, validation states
- Edge cases ignored: overflow text, long usernames, empty lists, slow networks
- Accessibility afterthought: focus indicators stripped, alt text missing, clickable divs
- Automated tools catch only 30% of WCAG issues
- 95.9% of top million websites fail basic WCAG 2.2

## Design Memory Is the Key Differentiator
- Without memory: spacing drifts (14px, 17px, 22px), button heights vary (36px, 38px, 40px)
- Dammyjay93/interface-design plugin solved this with system.md per project
- "Decisions compound. A spacing value chosen once becomes a pattern."
- "Consistency beats perfection. A coherent system with imperfect values beats scattered interface with correct ones."

## Component Libraries (2026)
- shadcn/ui: dominant React/Next.js, copy-paste (you own code)
- Radix Primitives: headless, accessible, underneath shadcn
- Ark UI / Park UI: multi-framework (React, Solid, Vue)
- Bits UI / Melt UI: Svelte ecosystem
- Tailwind v4: CSS-first config, new color system
- Headless UI: Tailwind Labs, simpler than Radix

## AI Design Tools (2026)
- v0.dev: highest UI quality, no backend, credit-limited
- bolt.new: full-stack but token-heavy, breaks at 15-20 components
- lovable.dev: good code but minimal comments, Supabase-coupled
- All share: 80% done, last 20% takes longer than building manually

## Solo Founder Brand Shortcuts
- Looka/Sologo: logo + brand kit in under an hour
- Khroma: AI color palette from preferences
- Fontjoy: AI font pairing
- Real shortcut: pick ONE distinctive font, ONE accent color, enforce everywhere

## What Makes Products Feel Amateur
- Spacing inconsistency (#1 tell)
- No visual hierarchy (everything same size/weight/color)
- Missing state handling (blank screens, spinners without context)
- Mixed styling approaches in same component
- z-index chaos (arbitrary values without a scale)

## Dead Ends
<!-- Investigated and not worth pursuing -->
