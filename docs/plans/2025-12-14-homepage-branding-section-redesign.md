# Homepage Branding Section Redesign

## Overview

Redesign the homepage branding section to be bolder and more compelling, drawing inspiration from the dedicated branding page (`app/views/pages/branding.html.erb`). The goal is to drive clicks, sell the branding service, and build trust — all in one section.

## Goals

1. **Drive clicks** to the branding page / configurator
2. **Sell the service** with concrete value props
3. **Build trust** through real customer photos and specific numbers

## Design Direction

**"Mini branding page"** — a condensed but impactful version of the full branding landing page.

**Key principle:** Lead with visuals (photo collage), support with text.

## Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│              FULL-WIDTH MASONRY PHOTO COLLAGE               │
│                    (6 customer photos)                      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Your Brand.                              │
│                    Your Cup.  (gradient)                    │
│                                                             │
│   No setup fees. UK production. Delivered in 20 days.       │
│                                                             │
│     [UK]     [1,000 min]     [20 days]     [£0]            │
│                                                             │
│                  [ Start Designing ]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Section 1: Masonry Photo Collage

### Layout

- **CSS Grid** with defined rows/columns for masonry effect
- **3 columns on desktop**, 2 columns on mobile
- Some photos span 2 rows for visual variety
- Full bleed to section edges (no container padding on collage)

### Desktop Grid Structure

```
┌─────────┬─────────┬─────────┐
│  TALL   │  SHORT  │  SHORT  │
│   1     ├─────────┼─────────┤
│         │  SHORT  │  TALL   │
├─────────┤    4    │   5     │
│  SHORT  ├─────────┤         │
│   3     │  SHORT  │         │
│         │    6    │         │
└─────────┴─────────┴─────────┘
```

### Photos

Using existing images from branding page gallery:

1. `images/branding/DSC_6621.webp` — Shakedown cup in hand
2. `images/branding/DSC_6736.webp` — OOO Koffee grey cup
3. `images/branding/DSC_6770.webp` — La Gelatiera mint cup
4. `images/branding/DSC_6872.webp` — Multiple cups in bushes
5. `images/branding/DSC_7193.webp` — Pastel cups on table
6. `images/branding/DSC_7239.webp` — Gelato cups with ice cream

### Photo Styling (Neobrutalist)

- `border-2 border-black`
- `rounded-xl`
- `overflow-hidden`
- Hover: `group-hover:scale-105 transition-transform duration-300`
- Gap: `gap-2` or `gap-3`

## Section 2: Text Content

### Headline

```html
<h2>
  Your Brand.<br>
  <span class="gradient">Your Cup.</span>
</h2>
```

- `text-4xl sm:text-5xl font-black`
- "Your Cup." uses gradient: `bg-gradient-to-r from-[#00a86b] to-[#79ebc0]`
- `text-transparent bg-clip-text` for gradient text effect
- Centered

### Supporting Line

```
No setup fees. UK production. Delivered in 20 business days.
```

- `text-lg sm:text-xl`
- `text-neutral-700`
- Centered
- Concise summary of key value props

## Section 3: Trust Badges

Horizontal row of 4 badges (same style as branding page, but compact):

| Badge | Visual | Value | Label |
|-------|--------|-------|-------|
| UK Production | 🇬🇧 emoji | UK | Production |
| Minimum Order | Box icon | 1,000 | Minimum units |
| Turnaround | Clock icon | 20 days | Turnaround |
| Setup Fees | Checkmark icon | £0 | Setup fees |

### Badge Styling

- Colored backgrounds (matching branding page: mint, pink, yellow, purple)
- `border-2 border-black`
- `rounded-xl`
- `shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]`
- Compact padding: `p-3 sm:p-4`

### Layout

- Desktop: 4 badges in a row (`grid-cols-4`)
- Mobile: 2x2 grid (`grid-cols-2`)

## Section 4: CTA

```html
<%= link_to branded_products_path, class: "btn btn-primary btn-lg shadow-lg shadow-black/20" do %>
  Start Designing
<% end %>
```

- Primary button style
- Centered below trust badges
- Matches branding page hero CTA

## Background

- Keep the pink: `bg-[#ffb7c5]`
- Maintains brand consistency with branding page
- `rounded-3xl` container (matching current section)

## Responsive Behavior

### Desktop (lg+)

- 3-column masonry collage
- Trust badges: 4 across in single row
- Padding: `py-16` or `py-24`

### Tablet (md)

- 3-column collage (slightly reduced height)
- Trust badges: 4 across (tighter spacing)

### Mobile (< md)

- 2-column masonry collage
- Trust badges: 2x2 grid
- Headline naturally stacks
- Padding: `py-12`

## File to Modify

`app/views/pages/partials/_branding.html.erb`

## Success Criteria

- [ ] Collage displays 6 customer photos in masonry layout
- [ ] "Your Brand. Your Cup." headline with gradient
- [ ] 4 trust badges with concrete numbers
- [ ] "Start Designing" CTA links to `/branded_products`
- [ ] Responsive: works on mobile, tablet, desktop
- [ ] Maintains neobrutalist design language (borders, shadows, bold colors)
