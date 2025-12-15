# Branding Page Redesign

## Overview

Transform the plain `/branding` page into a full landing page experience that showcases the custom branded double wall cup service.

## Key Information

- **Product:** Double wall coffee cups (only product available for branding currently)
- **Minimum order:** 1,000 units
- **Turnaround:** 20 business days
- **Setup fees:** None
- **Production:** UK-based
- **Process:** Self-service configurator (customers design online, add to cart)

## Page Structure

### Section 1: Hero

**Layout:** Full-width split design
- Left: Bold headline + subtext + primary CTA
- Right: Hero image (`branding.webp` or branded cup photo)

**Content:**
- Headline: "Your Brand. Your Cup."
- Subtext: "Custom branded double wall coffee cups, designed by you. No setup fees, UK production, delivered in 20 business days."
- CTA: "Start Branding" → `branded_products_path`

**Style:** Neobrutalist, continues homepage aesthetic (pink/mint accents, bold shadows)

### Section 2: Trust Badges

**Layout:** 4-column horizontal row, directly below hero

**Badges:**
1. UK flag icon | "UK" | "Production"
2. Box icon | "1,000" | "Minimum units"
3. Clock icon | "20 days" | "Turnaround"
4. Checkmark icon | "£0" | "Setup fees"

**Style:** Colored cards (alternating mint/pink), black borders, neobrutalist shadow

**Responsive:** 2x2 grid on tablet/mobile

### Section 3: How It Works

**Layout:** 3-step horizontal timeline with connecting line

**Headline:** "From Design to Doorstep"

**Steps:**
1. **Design** - "Use our configurator to upload your logo and preview it on your cups"
2. **Order** - "Add to cart and checkout - no quotes, no waiting"
3. **Receive** - "UK-printed and delivered to your door in 20 business days"

**CTA:** "Start Branding →"

**Style:** Large numbered circles, dotted connecting line

### Section 4: Product Showcase

**Layout:** Gallery grid (3 columns desktop, 2 tablet, 1 mobile)

**Headline:** "Branded to Perfection"
**Subtext:** "See how businesses like yours are making their mark"

**Content:** 4-6 photos of real branded double wall cups

**Style:**
- Hover: subtle zoom + shadow lift
- Neobrutalist: slight rotation on some, chunky borders

### Section 5: Why Choose Us

**Layout:** Benefit cards or list

**Headline:** "Why Afida?"

**Benefits:**
1. **No Setup Fees** - "Your first order costs the same as your hundredth. No hidden charges, no artwork fees."
2. **Low Minimums** - "Start from just 1,000 cups. Perfect for testing your brand or smaller venues."
3. **Fast UK Production** - "Printed in the UK and delivered in 20 business days. No overseas shipping delays."
4. **Eco-Friendly** - "Double wall cups made from sustainable materials. Look good, feel good."

**Style:** Cards with icons, accent color highlights

### Section 6: Social Proof

**Layout:** Client logos bar

**Headline:** "Trusted by Leading Brands"

**Implementation:** Reuse `_client_logos` partial from homepage

**Style:** Grayscale logos, color on hover

### Section 7: Final CTA

**Layout:** Full-width colored section (bold pink)

**Headline:** "Ready to Brand Your Cups?"
**Subtext:** "Design your custom double wall cups in minutes. No setup fees, delivered in 20 days."

**CTA:** "Start Branding" → `branded_products_path`
**Secondary:** "Have questions? Contact us" → contact page

**Style:** Bold, attention-grabbing, neobrutalist button with shadow

## Visual Assets Required

- `branding.webp` (existing)
- 4-6 branded cup photos (confirmed available)
- Client logos (existing partial)
- Icons for trust badges and benefits (SVG, inline)

## Technical Notes

- Single ERB file: `app/views/pages/branding.html.erb`
- Uses existing TailwindCSS 4 + DaisyUI
- Follows neobrutalist style from homepage
- Links to existing `branded_products_path` configurator
- Reuses `_client_logos` partial
