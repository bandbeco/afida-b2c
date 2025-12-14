# Research: Homepage Branding Section Redesign

**Feature**: 013-homepage-branding
**Date**: 2025-12-14

## Research Tasks

### 1. CSS Masonry Layout Implementation

**Question**: What's the best approach for implementing a masonry grid layout in TailwindCSS 4?

**Decision**: Use CSS Columns approach (`columns-2 md:columns-3`)

**Rationale**:
- Native TailwindCSS support via `columns-*` utility classes
- No JavaScript required (pure CSS solution)
- Excellent browser support (CSS columns is as old as flexbox)
- Automatically handles varied image heights
- Simple responsive adjustment with breakpoint prefixes

**Alternatives Considered**:

| Approach | Pros | Cons | Verdict |
|----------|------|------|---------|
| CSS Columns | Native Tailwind, no JS, simple | Items flow top-to-bottom then left-to-right | ✅ Selected |
| CSS Grid with nested columns | More control over exact positioning | Complex markup, manual column distribution | Rejected (over-engineered) |
| JavaScript masonry library (Masonry.js) | Perfect masonry behavior | Additional dependency, JS overhead | Rejected (unnecessary complexity) |
| Native CSS masonry | Future-proof | Not yet supported in all browsers | Rejected (not production-ready) |

**Implementation Pattern**:
```html
<div class="columns-2 md:columns-3 gap-3">
  <div class="break-inside-avoid mb-3">
    <img src="..." class="w-full rounded-xl border-2 border-black" />
  </div>
  <!-- more items -->
</div>
```

**Key Classes**:
- `columns-2` / `columns-3`: Number of columns
- `gap-3`: Gap between columns
- `break-inside-avoid`: Prevents items from breaking across columns
- `mb-3`: Bottom margin matches gap for consistent spacing

---

### 2. Available Branding Images

**Question**: Which customer photos are available for the collage?

**Decision**: Use 6 images from the existing gallery (9 available total)

**Available Images** (in `app/frontend/images/branding/`):

| File | Size | Description (from branding page) |
|------|------|----------------------------------|
| DSC_6621.webp | 490KB | Shakedown cup in hand |
| DSC_6736.webp | 571KB | OOO Koffee grey cup |
| DSC_6770.webp | 620KB | La Gelatiera mint cup |
| DSC_6872.webp | 185KB | Multiple cups in bushes |
| DSC_6898.webp | 206KB | (additional) |
| DSC_7110.webp | 148KB | (additional) |
| DSC_7159.webp | 98KB | (additional) |
| DSC_7193.webp | 120KB | Pastel cups on table |
| DSC_7239.webp | 125KB | Gelato cups with ice cream |

**Selected for Collage** (6 images per spec):
1. DSC_6621.webp - Shakedown cup (strong brand visibility)
2. DSC_6736.webp - OOO Koffee (professional look)
3. DSC_6770.webp - La Gelatiera mint (color contrast)
4. DSC_6872.webp - Multiple cups (variety showcase)
5. DSC_7193.webp - Pastel cups (lifestyle setting)
6. DSC_7239.webp - Gelato cups (product in use)

**Rationale**: These 6 images show variety in: brand styles, cup types, color schemes, and usage contexts. They match what the dedicated branding page currently uses.

---

### 3. Gradient Text Implementation

**Question**: How to implement gradient text for "Your Cup." in TailwindCSS?

**Decision**: Use Tailwind's `bg-clip-text` with gradient utilities

**Implementation**:
```html
<span class="text-transparent bg-clip-text bg-gradient-to-r from-[#00a86b] to-[#79ebc0]">
  Your Cup.
</span>
```

**Key Classes**:
- `text-transparent`: Makes text transparent so gradient shows through
- `bg-clip-text`: Clips background to text shape
- `bg-gradient-to-r`: Right-direction gradient
- `from-[#00a86b]`: Afida green start color
- `to-[#79ebc0]`: Mint green end color

**Browser Support**: Excellent - `background-clip: text` is supported in all modern browsers.

---

### 4. Trust Badge Styling

**Question**: How should trust badges be styled to match neobrutalist design?

**Decision**: Match branding page trust badges with compact sizing

**Existing Pattern** (from `branding.html.erb` lines 96-140):
- Colored backgrounds (mint, pink, yellow, purple)
- `border-2 border-black`
- `rounded-xl`
- `shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]`
- Icon + large number + small label

**Compact Adaptation for Homepage**:
- Reduce padding: `p-3 sm:p-4` (vs `p-4` on branding page)
- Keep same color scheme and shadow treatment
- Horizontal layout on desktop, 2x2 grid on mobile

---

### 5. Responsive Breakpoints

**Question**: What breakpoints should be used for the collage and badges?

**Decision**: Follow Tailwind's default breakpoints

| Breakpoint | Width | Collage Columns | Trust Badges |
|------------|-------|-----------------|--------------|
| Default (mobile) | <640px | 2 columns | 2x2 grid |
| `sm` | ≥640px | 2 columns | 2x2 grid |
| `md` | ≥768px | 3 columns | 4 across |
| `lg` | ≥1024px | 3 columns | 4 across |
| `xl` | ≥1280px | 3 columns | 4 across |

**Rationale**:
- 2 columns on mobile keeps images large enough to appreciate
- 3 columns on tablet+ provides visual density without overwhelming
- Trust badges as 2x2 on mobile ensures readability

---

## Summary

All research questions resolved. No external dependencies required. Implementation uses:
- Pure TailwindCSS utilities (no custom CSS or JS needed)
- Existing image assets (already optimized as WebP)
- Established design patterns from branding page

**Ready for Phase 1**: Data model and quickstart documentation.
