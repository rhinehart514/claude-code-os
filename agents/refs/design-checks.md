# Design Diagnostic Commands

Run these in the project root. Adapt file extensions to the project's stack (detect from package.json first).

## 1. Token Consistency

```bash
# Hardcoded colors (Tailwind arbitrary values)
grep -rn 'bg-\[#\|text-\[#\|border-\[#\|fill-\[#\|stroke-\[#' --include="*.tsx" --include="*.jsx" --include="*.svelte" --include="*.vue" | wc -l

# Hardcoded colors (CSS-in-JS / inline styles)
grep -rn "color:\s*['\"]#\|backgroundColor:\s*['\"]#" --include="*.tsx" --include="*.jsx" | wc -l

# Hardcoded spacing (inline styles with px/rem)
grep -rn "style={{" --include="*.tsx" --include="*.jsx" | grep -E "margin|padding|gap|width|height" | wc -l

# Border radius variants (should be 1-2 patterns)
grep -rohn "rounded-[a-z]*" --include="*.tsx" --include="*.svelte" | sort | uniq -c | sort -rn

# Font size sprawl (arbitrary text sizes)
grep -rn "text-\[" --include="*.tsx" --include="*.svelte" | wc -l

# Shadow variants (should be 1-2 patterns)
grep -rohn "shadow-[a-z]*" --include="*.tsx" --include="*.svelte" | sort | uniq -c | sort -rn
```

## 2. State Coverage

```bash
# Pages/routes (denominator — how many need states)
find . -path "*/app/**/page.*" -o -path "*/pages/**/*.tsx" -o -path "*/routes/**/*.svelte" | grep -v node_modules | wc -l

# Loading patterns (look for JSX conditional rendering, not just variable names)
grep -rn "isLoading\|isPending" --include="*.tsx" --include="*.svelte" | grep -E "&&|?" | wc -l
grep -rn "Skeleton\|Spinner\|Loading" --include="*.tsx" --include="*.svelte" | grep -E "<|import" | wc -l

# Error patterns (JSX error boundaries and conditional error rendering)
grep -rn "isError\|error &&\|error ?" --include="*.tsx" --include="*.svelte" | wc -l
grep -rn "ErrorBoundary\|error\.tsx\|error\.svelte" --include="*.tsx" --include="*.svelte" | wc -l

# Empty state patterns
grep -rn "\.length === 0\|\.length < 1\|isEmpty\|no results\|EmptyState\|nothing here\|get started" --include="*.tsx" --include="*.svelte" | wc -l

# Forms vs validation (ratio matters)
echo "Forms:" && grep -rcn "<form\|<Form" --include="*.tsx" --include="*.svelte" | grep -v ":0$" | wc -l
echo "Validation:" && grep -rcn "formError\|fieldError\|invalid\|validation\|setError\|formState.errors" --include="*.tsx" --include="*.svelte" | grep -v ":0$" | wc -l
```

## 3. Accessibility

```bash
# Images without alt
grep -rn "<img\|<Image" --include="*.tsx" --include="*.svelte" | grep -v "alt=" | wc -l

# Interactive elements without accessible names
grep -rn "<button\|<Button" --include="*.tsx" --include="*.svelte" | grep -v "aria-label\|aria-labelledby\|>.*<" | head -10

# Focus indicators stripped without replacement
grep -rn "outline-none\|focus:outline-none" --include="*.tsx" --include="*.svelte" | grep -v "focus-visible\|focus:ring\|focus-within" | wc -l

# Low-contrast text (light grays that fail WCAG AA)
grep -rn "text-gray-300\|text-gray-400\|text-slate-300\|text-slate-400\|text-neutral-300\|text-neutral-400\|text-zinc-300\|text-zinc-400" --include="*.tsx" --include="*.svelte" | wc -l

# Clickable non-button elements (div/span with onClick, missing role)
grep -rn "onClick" --include="*.tsx" --include="*.jsx" | grep -E "<div|<span" | grep -v "role=" | wc -l

# Touch target size (interactive elements smaller than 44px)
grep -rn "h-6\b\|h-5\b\|h-4\b\|w-6\b\|w-5\b\|w-4\b\|p-1\b" --include="*.tsx" --include="*.svelte" | grep -iE "button|click|link|<a |href" | wc -l
```

## 4. Component Consistency

```bash
# Button variants in use
grep -rohn 'variant="[^"]*"' --include="*.tsx" --include="*.svelte" | sort | uniq -c | sort -rn | head -10

# How many different button implementations?
grep -rln "className.*btn\|className.*button\|<Button\|<button" --include="*.tsx" --include="*.svelte" | wc -l

# Modal/dialog implementations (should be 1 pattern)
grep -rln "Modal\|Dialog\|dialog\|Drawer\|Sheet" --include="*.tsx" --include="*.svelte" | wc -l

# Card-like patterns
grep -rln "card\|Card" --include="*.tsx" --include="*.svelte" | wc -l

# Navigation implementations
grep -rln "nav\b\|Nav\b\|sidebar\|Sidebar\|header\|Header" --include="*.tsx" --include="*.svelte" | wc -l
```

## 5. Visual Craft (manual read)

After running 1-4, read the 5-10 files with most issues. Look for:
- Mixed styling (inline + Tailwind + CSS modules in same file)
- Inconsistent spacing between sibling elements
- Components duplicating structure from other components
- Dev terminology or internal state names in user-facing text
- Dead-end screens (no outbound link or next action)
- Placeholder text left in production code ("Lorem", "TODO", "placeholder")
- z-index chaos (arbitrary z-values without a scale)
