# Design Build Tiers

## Tier 1: Low-Risk (fix without asking)

Safe batch fixes. Won't change behavior or layout. Run build after.

| Fix | What to do | Watch out for |
|-----|-----------|---------------|
| Hardcoded colors → tokens | Replace `bg-[#xxx]` with nearest Tailwind class or CSS var | Check that replacement is visually close enough |
| Missing focus states | Add `focus-visible:ring-2 focus-visible:ring-offset-2` | Don't add to elements that already have focus styling |
| Stripped focus outlines | Replace bare `outline-none` with focus-visible alternative | Check if a custom focus style exists nearby |
| Missing alt text | Add descriptive alt (not "image") | Use `alt=""` for decorative images |
| Inconsistent radius | Pick dominant pattern, replace outliers | Don't touch radius on circles or pills (intentional) |
| Typography scale | Replace `text-[14px]` with `text-sm` | Check that the scale value is close to the arbitrary one |
| Truncation | Add `truncate` or `line-clamp-N` where text overflows | Don't truncate content the user needs to read fully |
| Icon sizing | Normalize to project's icon size (usually h-4/h-5/h-6) | Check icon is inside a wrapper that constrains it |

## Tier 2: Medium-Risk (read context first)

Read the full component. Understand the data flow. Then fix.

| Fix | What to do | Prereq |
|-----|-----------|--------|
| Loading states | Add Skeleton/Spinner where async data loads blind | Know what data is loading, match shape |
| Empty states | Add "No X yet" + CTA where `.length === 0` renders blank | Know what action creates the first item |
| Error boundaries | Wrap route segments with error.tsx/+error.svelte | Know the framework's error boundary pattern |
| Form validation | Add inline error messages to forms | Know validation library (zod, yup, native) |
| Action feedback | Add toast/notification on success/error | Check if a toast system exists, use it |
| Responsive gaps | Fix components that break at mobile widths | Test with actual breakpoints, not guessing |
| Dark mode gaps | Add missing `dark:` variants | Only if dark mode is intentionally supported |

## Tier 3: Architecture (ask first)

These create new files or change patterns. Always confirm with the founder.

| Fix | What to do | Why ask first |
|-----|-----------|---------------|
| Design token file | Generate/extend `tailwind.config` or `tokens.css` | Changes the foundation everything builds on |
| Shared components | Create Button/Card/Badge with variants | May duplicate or conflict with existing components |
| Layout shell | Consistent sidebar + header + content area | Major structural decision |
| Empty state component | Reusable: icon + title + description + CTA | Needs to match product voice |
| Skeleton component | Reusable loading skeleton matching content shapes | Needs to match actual content layout |
| Error component | Reusable error UI with retry | Needs to match error handling strategy |
