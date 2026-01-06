# Research: Reorder Schedule Conversion Page

**Feature**: 001-reorder-schedule-conversion
**Date**: 2026-01-06

## 1. Stimulus Expand/Collapse Patterns

### Decision
Use a simple Stimulus controller with `data-action="click->order-summary-toggle#toggle"` pattern and CSS classes for showing/hiding content.

### Rationale
- Stimulus provides lightweight, declarative JavaScript that integrates naturally with Rails views
- The project already uses this pattern extensively (see `category_expand_controller.js`, `slide_in_controller.js`)
- No need for external libraries or complex state management

### Implementation Pattern

```javascript
// order_summary_toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "buttonText"]
  static classes = ["hidden"]

  toggle() {
    this.contentTarget.classList.toggle(this.hiddenClass)
    this.iconTarget.classList.toggle("rotate-180")
    this.buttonTextTarget.textContent =
      this.contentTarget.classList.contains(this.hiddenClass)
        ? "View items"
        : "Hide items"
  }
}
```

### Alternatives Considered
- **DaisyUI Collapse component**: Rejected because it requires specific HTML structure that doesn't match our compact summary design
- **Details/Summary HTML elements**: Considered but lacks fine-grained control over styling and animation

---

## 2. Progressive Enhancement (No-JavaScript Fallback)

### Decision
Use `<noscript>` to show expanded content by default when JavaScript is disabled.

### Rationale
- Constitution principle III (Performance & Scalability) and accessibility best practices require graceful degradation
- Users without JavaScript should still see all order information
- Simple CSS-based solution that doesn't require server-side detection

### Implementation Pattern

```erb
<%# Default: hidden (JS will handle toggle) %>
<div data-order-summary-toggle-target="content" class="hidden">
  <%# Full order items here %>
</div>

<%# Fallback: show content when JS disabled %>
<noscript>
  <style>
    [data-order-summary-toggle-target="content"] { display: block !important; }
    [data-order-summary-toggle-target="icon"],
    [data-order-summary-toggle-target="buttonText"] { display: none; }
  </style>
</noscript>
```

### Alternatives Considered
- **Server-side JS detection**: Rejected as overly complex for this use case
- **CSS-only toggle with checkbox hack**: Rejected due to accessibility concerns with screen readers

---

## 3. DaisyUI Badge Components

### Decision
Use DaisyUI `badge` class with `badge-primary` or `badge-success` variant for "Most popular" indicator.

### Rationale
- Project already uses DaisyUI extensively
- Badge component provides consistent styling with the rest of the UI
- Supports responsive sizing (`badge-sm`, `badge-md`)

### Implementation Pattern

```erb
<div class="p-4 border-2 border-base-200 rounded-lg text-center transition-all peer-checked:border-primary peer-checked:bg-primary/5 relative">
  <% if frequency == 'every_month' %>
    <span class="badge badge-primary badge-sm absolute -top-2 left-1/2 -translate-x-1/2">
      Most popular
    </span>
  <% end %>
  <span class="block font-medium"><%= frequency.titleize.gsub('_', ' ') %></span>
</div>
```

### Alternatives Considered
- **Custom CSS badge**: Rejected to maintain consistency with DaisyUI design system
- **Separate badge above grid**: Rejected because badge should be visually associated with the specific option

---

## 4. Flexibility Badges Layout

### Decision
Use inline-flex items with checkmark icons, displayed horizontally on desktop and wrapped on mobile.

### Rationale
- "Cancel anytime" messaging needs to be scannable at a glance
- Checkmarks provide positive visual reinforcement
- Responsive layout ensures readability on all screen sizes

### Implementation Pattern

```erb
<div class="flex flex-wrap gap-x-6 gap-y-2 justify-center text-sm text-base-content/80">
  <div class="flex items-center gap-2">
    <svg class="w-4 h-4 text-success"><%# Checkmark %></svg>
    <span>Cancel anytime</span>
  </div>
  <div class="flex items-center gap-2">
    <svg class="w-4 h-4 text-success"><%# Checkmark %></svg>
    <span>Skip or pause deliveries</span>
  </div>
  <div class="flex items-center gap-2">
    <svg class="w-4 h-4 text-success"><%# Checkmark %></svg>
    <span>Edit items before each order</span>
  </div>
</div>
```

---

## 5. Trust Messaging Pattern

### Decision
Use lock icon (SVG) with muted text styling for trust line below CTA.

### Rationale
- Lock icon is universally recognized for security
- Stripe brand mention adds credibility
- Muted styling keeps focus on CTA while providing reassurance

### Implementation Pattern

```erb
<p class="text-center text-sm text-base-content/60 mt-3 flex items-center justify-center gap-2">
  <svg class="w-4 h-4"><%# Lock icon %></svg>
  Card saved securely by Stripe · Cancel anytime
</p>
```

---

## 6. Future Discount Slot

### Decision
Add an empty conditional div in the frequency section that can be populated later.

### Rationale
- Spec requirement FR-011 requires accommodation for future discount without layout changes
- Empty conditional renders nothing, zero visual impact
- Simple boolean flag enables feature when ready

### Implementation Pattern

```erb
<% if defined?(@discount_enabled) && @discount_enabled %>
  <div class="bg-success/10 border border-success/20 rounded-lg p-3 text-center text-sm mb-4">
    <span class="font-medium text-success">Subscribe & save <%= @discount_percentage %>%</span>
    on every delivery
  </div>
<% end %>
```

---

## Summary

All research questions resolved. No blocking issues identified. Implementation can proceed using standard Rails/Stimulus/DaisyUI patterns already established in the codebase.
