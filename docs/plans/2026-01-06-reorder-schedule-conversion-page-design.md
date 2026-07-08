---
type: Plan
description: Design for a conversion-focused redesign of the reorder schedule setup page, leading with flexibility messaging to reduce commitment anxiety.
status: shipped
timestamp: 2026-01-06
---

# Reorder Schedule Setup Page Redesign

## Overview

Redesign the "Set Up Reorder Schedule" page as a conversion-focused page to increase customer LTV. The current page is functional but transactional—it doesn't persuade users to commit to recurring orders.

## Design Philosophy

**Reassurance-first approach:** Users arrive immediately after completing a purchase. They've just spent money and are being asked to commit to spending more. Commitment anxiety is highest at this moment.

Lead with flexibility messaging ("cancel anytime") to remove the fear barrier, then show convenience benefits.

## Page Structure

### 1. Hero Section

**Headline:**
```
Never Run Out Again
```

**Subhead:**
```
Get this order delivered automatically. Pause, skip, or cancel anytime—you're always in control.
```

**Flexibility badges** (displayed prominently near headline):
- ✓ Cancel anytime
- ✓ Skip or pause deliveries
- ✓ Edit items before each order

These act as "objection killers" visible before scrolling.

### 2. Frequency Selection

**Label:** "How often do you need a refill?" (conversational, not transactional)

**UI:** 2x2 grid of radio cards
- Keep current selection styling (border highlight on selected)
- Add "Most popular" badge on "Every Month" option
- Pre-select "Every Month" as default

**Future discount slot:** Reserve space below frequency selector for potential "Subscribe & save X%" messaging. Structure code to make this trivial to add later—but don't show anything now.

### 3. Order Summary (Compact)

**Collapsed state:**
```
📦 3 items · £114.99 per delivery
[View items ▾]
```

**Expanded state:** Full line-item breakdown (toggle with Stimulus controller)

Keep the page clean while providing transparency on demand.

### 4. How It Works (3-Step Visual)

Horizontal layout with icons/numbers:

```
[1]              [2]                  [3]
Card saved       Reminder email       Confirm with
securely         3 days before        one click
                 each delivery        (or edit first)
```

- Position ABOVE the CTA so users understand the process before committing
- Remove "pause or cancel" step—now covered by hero badges
- Shorter, scannable text

### 5. CTA & Trust Elements

**Primary button:**
```
[ Set Up Automatic Delivery ]
```

Avoid "Continue to Payment Setup"—emphasizes friction (payment) rather than benefit (automatic delivery).

**Trust line** (below button, small muted text):
```
🔒 Card saved securely by Stripe · Cancel anytime
```

## Visual Hierarchy (Top to Bottom)

1. Subtle back link (top left, small)
2. Hero: Headline + subhead + flexibility badges
3. Frequency selector with conversational label
4. Compact order summary (collapsible)
5. "How it works" 3-step visual
6. Primary CTA button
7. Trust line

## Implementation Notes

### Stimulus Controller

Create `order_summary_toggle_controller.js` for expanding/collapsing the order items.

### Future Discount Accommodation

Structure the frequency section with a conditional slot:

```erb
<% if @discount_enabled %>
  <div class="discount-banner">
    Subscribe & save <%= @discount_percentage %>% on every delivery
  </div>
<% end %>
```

### Copy Guidelines

- Use "automatic delivery" not "subscription" (less commitment-heavy)
- Use "refill" not "reorder" (implies necessity)
- Always pair payment mentions with security reassurance

## Success Metrics

- **Primary:** Conversion rate (visitors to setup page → completed setup)
- **Secondary:** Time on page (should decrease with clearer messaging)
- **Tertiary:** Support tickets about cancellation (should remain low or decrease)

## Out of Scope

- Discount/incentive implementation (future feature)
- A/B testing infrastructure
- Analytics event tracking (handled separately)
