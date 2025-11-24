# Afida Bold Design System

## Aesthetic Direction

**Concept**: Bold Editorial Brutalism meets Eco-Modern
- High-contrast color blocking with environmental consciousness
- Geometric precision with organic eco-friendly messaging
- Maximalist borders and typography, minimalist layouts

**What Makes This Unforgettable**: The juxtaposition of ultra-bold 4px black borders and massive typography with sustainable, eco-friendly brand messaging creates tension that demands attention.

## Typography

### Font Pairing (Distinctive & Unexpected)

**Display Font**: **Outfit**
- Weights: 700 (Bold), 800 (Extra Bold), 900 (Black)
- Usage: Hero headings, section titles, category names, product titles
- Character: Geometric, ultra-bold, modern, highly legible
- Why: Bold and distinctive geometric sans, different from mockup's Outfit/Rubik pairing, creates strong visual hierarchy

**Body Font**: **Plus Jakarta Sans**
- Weights: 400 (Regular), 500 (Medium), 600 (Semi-Bold), 700 (Bold)
- Usage: Body text, descriptions, buttons, navigation links
- Character: Friendly, modern, excellent readability
- Why: Balances the boldness of Clash Display with approachability

**Fallback**: System fonts for performance
- Display fallback: `'Outfit', 'Arial Black', sans-serif`
- Body fallback: `'Plus Jakarta Sans', -apple-system, system-ui, sans-serif`

### Typography Scale

```css
--text-xs: clamp(0.75rem, 0.7rem + 0.25vw, 0.875rem);     /* 12-14px */
--text-sm: clamp(0.875rem, 0.8rem + 0.375vw, 1rem);        /* 14-16px */
--text-base: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);      /* 16-18px */
--text-lg: clamp(1.125rem, 1rem + 0.625vw, 1.5rem);        /* 18-24px */
--text-xl: clamp(1.5rem, 1.2rem + 1.5vw, 2.5rem);          /* 24-40px */
--text-2xl: clamp(2rem, 1.5rem + 2.5vw, 3.5rem);           /* 32-56px */
--text-3xl: clamp(2.5rem, 1.75rem + 3.75vw, 5rem);         /* 40-80px */
--text-hero: clamp(3rem, 2rem + 5vw, 8rem);                /* 48-128px */
```

## Color Palette

### Brand Colors

**Primary (Turquoise)**: `#7FFFD4` (aquamarine from mockup)
- Usage: Headers, hero sections, accent backgrounds, hover states
- DaisyUI variable: `--p`

**Secondary (Pink)**: `#FFB6C1` (light pink from mockup)
- Usage: Accent sections, CTAs, highlights, links
- DaisyUI variable: `--s`

**Accent (Deep Pink)**: `#FF6B9D` (current secondary, slightly darker)
- Usage: Important CTAs, sale badges, urgent messaging
- DaisyUI variable: `--a`

### Base Colors

**Black**: `#000000`
- Usage: Text, borders (4px), footer background, featured sections
- Creates maximum contrast

**White**: `#FFFFFF`
- Usage: Text on dark backgrounds, card backgrounds, clean sections

**Neutral Grays**:
- `--gray-50`: `#F9FAFB` (subtle backgrounds)
- `--gray-100`: `#F3F4F6` (hover states)
- `--gray-900`: `#111827` (softer than pure black for some text)

## Borders & Shapes

**Signature Border**: 4px solid black (`border-bold` utility class)
- Applied to: Headers, cards, buttons, dropdowns, featured sections
- Creates strong geometric definition

**Border Radius**: Minimal to sharp
- Cards: 0px (sharp) or 4px (subtle)
- Buttons: 0px (sharp geometric)
- Images: 8px (slight softness for product photos)
- Inputs: 4px

## Spacing System

**Generous but Controlled**:
- Section padding: `py-16 md:py-24 lg:py-32`
- Card padding: `p-6 md:p-8`
- Element spacing: `gap-4 md:gap-6 lg:gap-8`

## Animations & Motion

**Philosophy**: One orchestrated moment beats scattered micro-interactions

**Page Load**: Staggered reveals
- Hero: Fade + slide up (0ms delay)
- Subheading: Fade + slide up (150ms delay)
- CTA: Fade + scale (300ms delay)

**Scroll Triggers**: Intersection observer for sections
- Features: Fade + slide up (staggered by item)
- Product cards: Fade + lift (staggered grid)

**Hover States**: Color transitions (300ms ease)
- Buttons: Background black → turquoise
- Cards: Background white → black, text white → turquoise
- Links: Color turquoise → pink

**NO**: Scale transforms on hover (reserve for special moments)
**YES**: Color transitions, subtle shadows

## Component Patterns

### Buttons
- **Primary**: Black background, white text, 4px border, sharp corners
- **Hover**: Turquoise background, black text
- **Secondary**: White background, black border/text
- **Hover**: Black background, white text

### Cards
- **Default**: White background, 4px black border, minimal radius
- **Hover**: Black background, turquoise text, icon filter change

### Dropdowns
- White background, 4px black border
- Hover items: Turquoise background, black text
- Minimal padding, clean typography

### Inputs
- 4px black border on focus
- White background
- Bold labels (600 weight)

## Backgrounds & Textures

**Pattern Usage**: Subtle texture at low opacity
- Cross/plus pattern (from mockup) at 6-10% opacity
- Applied to: Hero, colored sections
- Creates depth without overwhelming

**Gradient Accents**: Avoid
- Keep color blocks pure for maximum boldness

**Photos**:
- Product photos: Clean white backgrounds or lifestyle
- Slight border (4px) on featured images

## Accessibility Considerations

**Contrast Ratios**:
- Black on white: 21:1 (AAA)
- White on turquoise (#7FFFD4): 1.49:1 (FAIL) → Use black text on turquoise
- Black on turquoise: 14.08:1 (AAA) ✓
- White on pink (#FFB6C1): 1.82:1 (FAIL) → Use black text on pink
- Black on pink: 11.55:1 (AAA) ✓

**ALL CAPS Usage**: Sparingly
- Hero headings: YES
- Section headings: YES
- Navigation: MAYBE (test readability)
- Body text: NO
- Buttons: YES

**Focus States**:
- 4px border in accent color
- Clear visual indication for keyboard navigation

## Key Differentiators from Generic AI Design

❌ **Avoiding**:
- Inter, Roboto, Space Grotesk fonts
- Purple gradients on white
- Rounded pill buttons everywhere
- Soft shadows and subtle borders
- Predictable grid layouts

✅ **Embracing**:
- Outfit + Plus Jakarta Sans (distinctive pairing different from mockup)
- Bold turquoise/pink/black color blocking
- Sharp geometric borders (4px)
- High contrast and strong visual hierarchy
- Unexpected typography scale (8rem hero headings)
- Intentional ALL CAPS for impact
- Brutalist meets editorial aesthetic

## Implementation Notes

- Start with DaisyUI custom theme for foundation
- Selective component rewrites for maximum impact (hero, nav, features)
- Mobile-first responsive (clamp() for fluid typography)
- CSS custom properties for consistency
- Performance: font-display: swap, optimized loading
