# Design Taste Framework

Subjective evaluation criteria for UI/UX. Not about correctness — about whether it *feels* right.

## The 11 Taste Dimensions

### 1. Hierarchy (does the eye know where to go?)
- **5/5**: Clear visual order. Primary action dominates. Supporting content recedes. The page "reads" naturally.
- **3/5**: Some hierarchy exists but competing elements. Two things fighting for attention.
- **1/5**: Everything is the same size, weight, and color. Flat information with no priority signal.

**How to check in code:**
- Look at font sizes used on a page — is there meaningful range? (e.g., text-3xl → text-base → text-sm)
- Look at font weights — is bold used sparingly or on everything?
- Look at colors — is there a clear primary vs secondary text color?
- Count CTAs per screen — more than 2 primary buttons = hierarchy failure

**FAIL examples (auto-cap at 1):**
- All text same size/weight on a page → hierarchy = 1 regardless of other qualities
- 3+ primary-styled buttons visible simultaneously → hierarchy ≤ 2
- No font size variation across an entire route (everything text-base) → hierarchy ≤ 2

### 2. Breathing Room (does the layout breathe?)
- **5/5**: Whitespace is intentional. Groups are separated. Nothing feels cramped. Spacious but not empty.
- **3/5**: Adequate spacing but uniform. Everything has the same gap. No rhythm.
- **1/5**: Elements crammed together. No padding. Borders touching. Walls of content.

**How to check in code:**
- Look at padding/gap values — is there a spacing rhythm? (e.g., 4 → 6 → 8 → 12)
- Section spacing should be larger than element spacing (macro > micro whitespace)
- Container max-widths — is content going edge-to-edge or contained?

**FAIL examples (auto-cap at 2):**
- `p-4` on everything with no variation → breathing_room ≤ 2
- No macro whitespace (section gaps same as element gaps) → breathing_room ≤ 2
- Content goes edge-to-edge with no max-width constraint → breathing_room ≤ 2

### 3. Contrast & Emphasis (do important things pop?)
- **5/5**: Primary actions unmissable. Clear difference between interactive and static. Active states obvious.
- **3/5**: Some contrast but could be stronger. Links don't quite stand out from text.
- **1/5**: Everything blends together. Can't tell what's clickable. No visual weight differences.

**How to check in code:**
- Button prominence — is the primary button visually distinct from secondary/ghost?
- Color contrast between bg and interactive elements
- Active/selected states — do tabs, nav items, toggles show state clearly?

**FAIL examples (auto-cap at 2):**
- Primary and secondary buttons visually identical → contrast ≤ 2
- No active/selected state on navigation items → contrast ≤ 2
- All text same color (no distinction between labels, values, links) → contrast = 1

### 4. Polish Signals (does it feel alive?)
- **5/5**: Hover states on everything interactive. Smooth transitions. Loading feedback. Micro-animations that add delight.
- **3/5**: Some hover states. Transitions exist but inconsistent. Loading states present.
- **1/5**: Dead clicks. No hover feedback. Jarring state changes. Elements appear/disappear without transition.

**How to check in code:**
- Search for `hover:` — how many interactive elements have it?
- Search for `transition` / `duration-` / `animate-` — any motion at all?
- Do modals/dropdowns animate in or just appear?
- Does button click have feedback (active state, loading spinner)?

**FAIL examples (auto-cap at 2):**
- Zero hover states on any interactive element → polish = 1
- Modals/dropdowns appear without any transition → polish ≤ 2
- No loading feedback anywhere (blind clicks) → polish ≤ 2

### 5. Emotional Tone (does it match the product?)
- **5/5**: The UI feels like the product's personality. A playful app feels playful. A serious tool feels serious.
- **3/5**: Neutral. Not offensive but not distinctive. Could be any product.
- **1/5**: Mismatch. A creative tool that looks like a tax app. A social product that feels corporate.

**Product type → Expected tone:**
- Developer tools → Precision, density, utility (dark mode, monospace accents, compact)
- Consumer/social → Warmth, approachability, playfulness (rounded, colorful, generous spacing)
- Finance/enterprise → Trust, sophistication, restraint (serif accents, muted palette, structured)
- Creative tools → Boldness, expressiveness (distinctive typography, unexpected color, asymmetry)
- Productivity → Clarity, efficiency, calm (clean lines, purposeful color, information-forward)

**FAIL examples (auto-cap at 2):**
- A social/creative product that looks like an enterprise dashboard → tone = 1
- Zero personality in any copy, illustration, or interaction → tone ≤ 2
- Color palette is entirely gray + one blue → tone ≤ 2

### 6. Information Density (right amount per screen?)
- **5/5**: Goldilocks — enough content to be useful, not so much it overwhelms. Scannable.
- **3/5**: Slightly off — either a bit sparse (lots of scrolling for little info) or a bit dense (need to concentrate).
- **1/5**: Extreme — either wastefully empty (a paragraph floating in a sea of white) or a wall of text/data.

**How to check in code:**
- Count distinct "sections" or "cards" per page — 3-7 is usually right
- Check for max-width constraints on text (prose should max at ~65 characters per line)
- Data tables — do they have pagination/scrolling or dump everything?

**FAIL examples (auto-cap at 2):**
- A paragraph floating alone on a full-width page → density = 1
- Wall of text with no section breaks, headings, or visual anchors → density ≤ 2
- Data table dumps 100+ rows with no pagination or virtual scroll → density ≤ 2

### 7. Flow & Wayfinding (can users navigate without thinking?)
- **5/5**: Next action is always obvious. Breadcrumbs/context present. Navigation is consistent. No dead ends.
- **3/5**: Navigation works but has dead ends or unclear "what next?" moments. Some pages lack back navigation.
- **1/5**: Users would get lost. No clear path. Navigation inconsistent between pages. Dead-end screens everywhere.

**How to check in code:**
- Pages with no outbound links or CTAs = dead ends
- Forms with no redirect after submit
- Empty states with no guidance on what to do
- Modals with no close button or escape handler
- Check that all pages are reachable from the main navigation

**FAIL examples (auto-cap at 2):**
- Any page with no outbound link or CTA (dead end) → wayfinding ≤ 2
- Empty states that say "No items" with no guidance → wayfinding ≤ 2
- Form submits with no redirect or confirmation → wayfinding ≤ 2

### 8. Scroll Experience (does scrolling reveal or exhaust?)
- **5/5**: Each scroll reveals something new. Sections have rhythm. The page has a beginning, middle, and end.
- **3/5**: Content flows but without surprise. Uniform sections that blur together.
- **1/5**: Endless scroll with no landmarks. Or everything above the fold with nothing below.

**How to check in code:**
- Section count vs page length — long pages need visual breaks (bg color shifts, dividers, illustrations)
- Is there a sticky nav or progress indicator for long pages?
- Do sections alternate visual patterns (text-left/image-right, then reversed)?
- Is there a clear ending (CTA, footer with value) vs just trailing off?

**FAIL examples (auto-cap at 2):**
- Long page with no visual breaks (same bg color, no dividers, no section rhythm) → scroll ≤ 2
- Everything above the fold, nothing below → scroll = 1
- Uniform card grid that repeats for 20+ items with no variation → scroll ≤ 2

### 9. Distinctiveness (is this memorable?)
- **5/5**: You'd recognize this product in a lineup. It has a visual identity — not just a framework's defaults.
- **3/5**: Competent but generic. Could be any product in this category.
- **1/5**: Pure framework defaults. Looks like the Tailwind tutorial template.

**What makes products distinctive (pick at least ONE):**
- A non-default font choice (Google Fonts has 1600+ options, not just Inter/Geist)
- An unexpected accent color (not blue, not purple)
- A unique layout approach (not just stacked cards)
- A micro-interaction that surprises (a clever loading animation, a satisfying toggle)
- A brand illustration style (even a simple one)
- An unconventional information pattern (bento grid, timeline, kanban)

**FAIL examples (auto-cap at 1):**
- Only Inter/system-ui + only blue/gray palette → distinctiveness = 1
- Every layout is sidebar + card grid + table → distinctiveness ≤ 2
- Could screenshot any page and it looks like the Tailwind docs starter → distinctiveness = 1

**Slop detector**: Could this screen be AI-generated from a generic prompt? If yes, distinctiveness capped at 2/5.

### 10. Layout Coherence (does the spatial system hold together?)
- **5/5**: Every page shares the same grid, alignment, and spacing system. Section widths are proportional. Cards align to a visible grid. Gutters are consistent. Mobile layouts thoughtfully reorganize content for thumb reach.
- **3/5**: Layout mostly works but inconsistencies appear — section widths vary without logic, spacing between elements changes page to page, mobile is just squeezed desktop.
- **1/5**: No layout system. Columns don't align, section widths are arbitrary, gutters shift between pages. Looks like multiple designers working without a shared spec.

**How to check in code:**
- Do all pages share the same max-width container?
- Are grid column counts consistent (or 2-col here, 3-col there, full-width elsewhere)?
- Are card/section aspect ratios intentional or arbitrary?
- Does mobile layout reflow or just shrink?
- Sidebar width, nav height, content margin — same on every route?

**FAIL examples (auto-cap at 2):**
- Grid column counts vary between pages with no logic (2-col here, 4-col there) → layout ≤ 2
- Mobile layout is just squeezed desktop (no reflow) → layout ≤ 2
- No shared max-width container across pages → layout = 1

### 11. Information Architecture (can you build a mental model?)
- **5/5**: Navigation maps to what the product does. I can predict where things are before clicking. Related features are grouped. Labels explain themselves. Important things are 1 click deep, not 3.
- **3/5**: I can find things eventually but grouping feels arbitrary. Some features buried in unexpected places. Labels are vague. I memorize paths instead of predicting them.
- **1/5**: Cannot form a mental model. Features scattered across random locations. Same concept appears in multiple places. Structure doesn't match what the product does.

**How to check in code:**
- Does main navigation cover all key destinations? Or are important features in sub-menus/modals?
- Are related items grouped (creation tools together, settings together)?
- Can you predict where a feature lives from nav labels alone?
- Is there a clear organizing principle? (by user type? by action? by content type?)
- Depth check: is important stuff 3 clicks deep while trivial stuff is on the homepage?

**FAIL examples (auto-cap at 2):**
- Important features buried 3+ clicks deep while trivial content is on homepage → IA ≤ 2
- Same concept appears in multiple unrelated places → IA ≤ 2
- Nav labels are vague/internal jargon that users can't predict → IA ≤ 2
- No organizing principle visible (not by action, not by content type, not by user type) → IA = 1

---

## Recommendation Patterns

When suggesting improvements, match these to the product type:

### For SaaS Dashboards
- Bento grid layouts (varied card sizes create rhythm)
- Data visualization accents (even simple bar sparklines add sophistication)
- Compact, scannable tables with row hover states
- Status indicators with color coding
- Keyboard shortcuts badge UI

### For Consumer/Social Products
- Avatar-forward design (user identity visible everywhere)
- Feed patterns with varied content types
- Empty states with personality (illustration + witty copy)
- Pull-to-refresh / infinite scroll done well
- Reaction/emoji UIs

### For Landing Pages / Marketing
- Hero with clear hierarchy (headline > subhead > CTA > social proof)
- Section transitions (background color shifts, not just padding)
- Testimonials with photos and names (not anonymous quotes)
- Feature grids with icons that actually communicate
- Pricing table with the recommended plan highlighted

### For Developer Tools
- Code block styling with syntax highlighting
- Terminal/CLI-inspired UI elements
- Documentation-style navigation (sidebar + content + right TOC)
- Monospace accents in headers or badges
- Copy-to-clipboard on every code snippet

### For Mobile-First / PWA
- Bottom navigation (thumb zone)
- Swipe actions on list items
- Pull-down to refresh
- 44px minimum touch targets
- App-like transitions between views

---

## The IA/VA Convergence Problem (2025-2026)

AI-generated UIs converge on the same information architecture and visual architecture because the training data is the same. The result: every app looks like it was built by the same junior designer who just discovered shadcn.

### Icon Architecture (IA) — "The Lucide Problem"
Every AI-assisted project defaults to the same icon set (Lucide/Heroicons). The icons are fine — they're just the same icons on every product. This creates sameness at the atomic level.

**Detection:**
- Check `package.json` for icon libraries — is it just `lucide-react`?
- Count unique icons used vs total available — most projects use <20 from a set of 1000+
- Are icons doing actual work (wayfinding, status) or decorative filler?

**What to flag:**
- Same 15 icons as every other SaaS (Settings gear, Bell, Search, Home, User, ChevronRight, Plus, X, Check, ArrowLeft, Menu, Star, Heart, Mail, Calendar)
- Icons as filler — stuck next to labels that don't need them
- No icon customization (weight, size variation, fill vs stroke inconsistency)

**What to recommend:**
- If Lucide fits: use it intentionally — fewer icons, larger, with consistent weight. Remove decorative clutter.
- For distinction: custom icon set (even 10-15 key icons), Phosphor (more personality), or illustrated icons for empty/feature states
- Mix approaches: system icons (Lucide) for chrome, custom/illustrated for product identity moments

### Visual Architecture (VA) — "The Layout Problem"
AI generates the same layout patterns because they're the most common in training data. Functional ≠ memorable.

**The convergent patterns (flag when you see them all in one product):**
- Sidebar + main content (every dashboard ever)
- Card grid with equal sizing (Pinterest killed this in 2012, everyone else brought it back)
- Hero → features grid → testimonials → CTA (every landing page)
- Settings page = stacked form sections
- Table with action column on the right
- Modal for everything that could be inline

**These aren't wrong.** They're just the default. A product using ALL of them has zero visual identity.

**What to recommend:**
- Break one major layout expectation per product:
  - Command palette instead of sidebar nav
  - Bento grid (varied sizes) instead of uniform cards
  - Inline expansion instead of modals
  - Kanban/timeline/spatial layouts where appropriate
  - Split pane for detail views instead of navigate-away
- Information density should match user intent:
  - Power users: dense, keyboard-driven, data-forward
  - New users: spacious, guided, progressive disclosure
  - Campus users (students): mobile-first, thumb-zone nav, snackable content, social proof patterns

### Taste vs Function Matrix
```
              Functional    Not Functional
Tasteful      GOAL          Redesign needed
Tasteless     Ship it       Kill it
```

"Functional but tasteless" still ships — but it won't create love. The design-engineer's job is to push toward the top-left quadrant without sacrificing function.

---

## Anti-Slop Checklist

Score 0 (bad) or 1 (good) for each. Total < 5 = high slop risk.

- [ ] Uses a non-default font (not Inter, not system-ui alone)
- [ ] Has at least one color that isn't blue or gray
- [ ] Spacing varies intentionally (not p-4 on everything)
- [ ] Has at least one page layout that isn't "cards in a grid"
- [ ] Interactive elements have hover/active states
- [ ] At least one micro-animation exists (transition, not just `hidden`/`block`)
- [ ] Empty states have personality (not just "No items")
- [ ] Error states give guidance (not just "Something went wrong")
- [ ] Loading states match content shape (not a generic spinner)
- [ ] The product would be recognizable with the logo hidden
- [ ] Icon usage is intentional (not decorative filler on every label)
- [ ] At least one layout breaks the sidebar+cards+table pattern
- [ ] Navigation pattern matches the user's context (mobile thumb zone, power user density, etc.)

---

## Design Build Tiers

### Tier 1: Low-Risk (fix without asking)
| Fix | What | Watch out |
|-----|------|-----------|
| Hardcoded colors → tokens | Replace `bg-[#xxx]` with nearest Tailwind class | Check visual match |
| Missing focus states | Add `focus-visible:ring-2` | Don't double-up |
| Missing alt text | Add descriptive alt | `alt=""` for decorative |
| Inconsistent radius | Pick dominant, replace outliers | Don't touch pills/circles |
| Typography scale | Replace `text-[14px]` with `text-sm` | Check closeness |

### Tier 2: Medium-Risk (read context first)
| Fix | What | Prereq |
|-----|------|--------|
| Loading states | Add Skeleton/Spinner where async loads blind | Know what data loads |
| Empty states | "No X yet" + CTA where `.length === 0` | Know what creates first item |
| Error boundaries | Wrap route segments | Know framework pattern |
| Form validation | Inline error messages | Know validation library |
| Responsive gaps | Fix mobile breakpoints | Test with actual breakpoints |

### Tier 3: Architecture (ask first)
| Fix | What | Why ask |
|-----|------|---------|
| Design token file | Generate/extend tailwind.config | Changes foundation |
| Shared components | Button/Card/Badge with variants | May conflict with existing |
| Layout shell | Consistent sidebar + header + content | Major structural decision |

---

## Design Diagnostic Commands

Run in project root. Adapt extensions to stack.

### Token Consistency
```bash
grep -rn 'bg-\[#\|text-\[#\|border-\[#' --include="*.tsx" | wc -l  # hardcoded colors
grep -rohn "rounded-[a-z]*" --include="*.tsx" | sort | uniq -c | sort -rn  # radius variants
grep -rohn "shadow-[a-z]*" --include="*.tsx" | sort | uniq -c | sort -rn  # shadow variants
```

### State Coverage
```bash
grep -rn "isLoading\|isPending" --include="*.tsx" | grep -E "&&|?" | wc -l  # loading
grep -rn "\.length === 0\|isEmpty\|EmptyState" --include="*.tsx" | wc -l  # empty states
```

### Accessibility
```bash
grep -rn "<img\|<Image" --include="*.tsx" | grep -v "alt=" | wc -l  # images without alt
grep -rn "outline-none" --include="*.tsx" | grep -v "focus-visible\|focus:ring" | wc -l  # stripped focus
grep -rn "onClick" --include="*.tsx" | grep -E "<div|<span" | grep -v "role=" | wc -l  # clickable non-buttons
```
