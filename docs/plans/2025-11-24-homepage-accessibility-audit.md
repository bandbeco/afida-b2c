# Homepage Accessibility Audit - Design Document

**Date:** November 24, 2025
**Scope:** Comprehensive WCAG 2.1 AA audit and implementation for homepage (`app/views/pages/home.html.erb`)
**Approach:** Section-by-section audit with immediate fixes

---

## Objective

Perform a comprehensive accessibility audit of the homepage to:
1. Meet WCAG 2.1 AA compliance standards
2. Improve practical user experience for people with disabilities
3. Implement all identified fixes
4. Document findings and changes

---

## Methodology

### Audit Process (Per Section)

For each section of the homepage, we will:

1. **Identify Issues** across four categories:
   - **Semantic HTML** - Proper heading hierarchy, landmarks, semantic elements
   - **Keyboard Navigation** - Tab order, focus indicators, interactive element accessibility
   - **Screen Reader Support** - ARIA labels, alt text, announcements, context
   - **Visual Accessibility** - Color contrast, text sizing, motion/animation concerns

2. **Document Findings** with:
   - Issue description
   - WCAG 2.1 criterion violated (e.g., 1.3.1 Info and Relationships, 2.4.7 Focus Visible)
   - Severity level (Critical/High/Medium/Low)
   - Recommended fix

3. **Implement Fixes** immediately after documenting each section's issues

4. **Test Fixes** with:
   - Keyboard navigation testing (Tab, Enter, Space, Arrow keys)
   - Screen reader spot-checks (understanding the user experience)
   - Visual inspection (focus indicators, contrast)

### Section Order

1. Hero Section
2. Client Logos Conveyor Belt
3. Featured Products (Bestsellers) Carousel
4. Featured Product (Bio Fibre Straws)
5. Branding Section
6. Categories Section
7. Values Banner (Bottom)

---

## WCAG 2.1 AA Success Criteria Focus

### Perceivable (Principle 1)
- **1.1.1 Non-text Content** - All images have meaningful alt text
- **1.3.1 Info and Relationships** - Semantic HTML structure
- **1.3.2 Meaningful Sequence** - Logical reading/tab order
- **1.4.3 Contrast (Minimum)** - 4.5:1 for normal text, 3:1 for large text/UI components
- **1.4.11 Non-text Contrast** - 3:1 for UI components and graphical objects

### Operable (Principle 2)
- **2.1.1 Keyboard** - All functionality available via keyboard
- **2.1.2 No Keyboard Trap** - Users can navigate away from all elements
- **2.4.3 Focus Order** - Logical and intuitive tab order
- **2.4.7 Focus Visible** - Clear visual focus indicators
- **2.5.3 Label in Name** - Visible labels match accessible names

### Understandable (Principle 3)
- **3.2.1 On Focus** - No context changes on focus
- **3.2.2 On Input** - No unexpected context changes on input
- **3.3.2 Labels or Instructions** - Form inputs have clear labels

### Robust (Principle 4)
- **4.1.2 Name, Role, Value** - Proper ARIA attributes and semantics
- **4.1.3 Status Messages** - Important status changes announced

---

## Baseline Issues (From Lighthouse)

### Critical Issues (0% Score)

1. **Missing `lang` attribute on `<html>`** (WCAG 3.1.1 - Critical)
   - Current: `<html class="h-full bg-base-100...">`
   - Fix: Add `lang="en-GB"`

2. **Heading hierarchy violation** (WCAG 1.3.1 - Medium)
   - Footer jumps from h1 → h6, skipping h2-h5
   - Affects: `app/views/pages/home.html.erb:5520` (footer section)

3. **Interactive elements without accessible names** (WCAG 4.1.2 - Critical)
   - 6 "Quick Add to Cart" buttons missing `aria-label`
   - Logo link (lines 66-68) has no accessible text
   - Instagram icon link missing `aria-label`

4. **Images missing `alt` attributes** (WCAG 1.1.1 - Critical)
   - 10 client logo images in hero section (lines 89-92)

### High Priority Issues

5. **Unsized images causing layout shift** (CLS 0.135 - High)
   - 12 images without explicit width/height
   - Major culprits: Client logos, payment icons
   - Affects WCAG 2.4.7 (Focus Visible) indirectly

---

## Implementation Strategy

### Fix Categories

**Quick Wins (Immediate Impact):**
- Add `lang="en-GB"` to `<html>`
- Add `alt` attributes to all images
- Add `aria-label` to icon-only buttons
- Add `aria-hidden="true"` to decorative elements
- Add skip links for keyboard navigation

**Semantic Improvements:**
- Wrap sections in proper landmarks (`<nav>`, `<main>`, `<section>` with `aria-label`)
- Fix heading hierarchy (footer h6 → h2)
- Use `<figure>` and `<figcaption>` for product images
- Convert generic `<div>` buttons to semantic `<button>` elements

**Interactive Enhancements:**
- Add visible focus indicators (`:focus-visible` styles)
- Ensure keyboard operability (Enter/Space for carousel controls)
- Add ARIA live regions for dynamic content (if needed)
- Carousel: Add pause button, keyboard controls (arrow keys), proper ARIA roles

**Visual/Motion:**
- Verify color contrast ratios (gradient text readability)
- Add `prefers-reduced-motion` media query for animations
- Ensure text over gradients remains readable
- Add explicit dimensions to images (width/height attributes)

---

## Testing Approach

After each section is fixed:

1. **Manual Keyboard Navigation**
   - Tab through entire section
   - Test all interactive elements (Enter/Space)
   - Verify no keyboard traps
   - Check focus indicators are visible

2. **Browser DevTools Inspection**
   - Verify ARIA attributes using Accessibility Tree
   - Check heading structure
   - Validate semantic HTML

3. **Quick Screen Reader Check**
   - Test critical elements with VoiceOver (macOS: Cmd+F5)
   - Verify image alt text is announced
   - Check button labels are descriptive

4. **Visual Inspection**
   - Focus indicators visible on all interactive elements
   - Text contrast acceptable (use browser DevTools)
   - No layout shifts during interaction

---

## Deliverables

1. **Audit Report:** `docs/plans/2025-11-24-homepage-accessibility-audit.md` (this document)
2. **All Code Fixes:** Implemented and tested in `app/views/pages/home.html.erb` and supporting files
3. **Summary of Changes:** Complete list with file:line references

---

## Expected Outcomes

- **Lighthouse Accessibility Score:** Improve from 79% to 95%+
- **Critical Issues:** 0 remaining
- **WCAG 2.1 AA Compliance:** Meet or exceed standards
- **User Experience:** Screen reader users can navigate and understand all content
- **Keyboard Navigation:** All functionality accessible without mouse

---

## Next Steps

After design approval:
1. Create isolated workspace (optional: using git worktrees)
2. Begin Section 1: Hero Section audit
3. Document issues, implement fixes, test
4. Proceed section-by-section through homepage
5. Generate final audit report with summary of changes
6. Commit changes with descriptive message

---

## Notes

- **Lighthouse Baseline:** Performance 82%, Accessibility 79%, Best Practices 100%, SEO 92%
- **Known Issues:** 4 critical, multiple high priority
- **Estimated Duration:** Full audit and implementation (comprehensive approach)
- **Implementation Method:** Direct ERB file edits + CSS additions as needed
