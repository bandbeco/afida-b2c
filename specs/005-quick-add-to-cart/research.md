# Quick Add to Cart - Research Findings

**Date**: 2025-01-15
**Branch**: `005-quick-add-to-cart`

## Overview

This document captures technology decisions, best practices, and implementation patterns for the Quick Add to Cart feature. All NEEDS CLARIFICATION items from Technical Context have been resolved.

## Decision 1: Modal Architecture

**Question**: Single shared modal vs. per-card modal instances?

### Chosen Solution
**Single shared modal with Turbo Frame content swapping**

### Rationale
- **Performance**: Shop page has ~50 products. Single modal = ~2KB HTML vs. 50 modals = ~100KB
- **Memory efficiency**: Lower memory footprint, especially on mobile devices
- **Simpler state management**: Only one modal can be open at a time (user intent)
- **Turbo Frame pattern**: Server renders content on-demand, ensuring data freshness

### Alternatives Considered

**Option A: Per-card modal instances**
- **Rejected**: DOM bloat. 50 hidden modals significantly increases page size and memory
- **Downside**: Slower initial page load, higher memory consumption on mobile
- **When to use**: Small number of products (<10), static content

**Option B: Lazy-load modal on first click**
- **Rejected**: Added complexity without significant benefit
- **Downside**: First click requires modal creation (delay), subsequent clicks reuse instance
- **When to use**: Very large product catalogs (100+ products per page)

### Implementation Notes

**Modal Container** (single instance in layout):
```erb
<!-- app/views/layouts/application.html.erb -->
<turbo-frame id="quick-add-modal" class="modal"></turbo-frame>
```

**Quick Add Button** (per product card):
```erb
<!-- app/views/products/_card.html.erb -->
<%= link_to "Quick Add",
            product_quick_add_path(product),
            data: {
              turbo_frame: "quick-add-modal",
              controller: "quick-add-modal",
              action: "turbo:frame-load->quick-add-modal#open"
            },
            class: "btn btn-secondary" %>
```

**Controller Action**:
```ruby
# app/controllers/products_controller.rb
def quick_add
  @product = Product.find_by!(slug: params[:id])
  render layout: false  # Turbo Frame content only
end
```

---

## Decision 2: DaisyUI Modal + Turbo Integration

**Question**: How to integrate DaisyUI modal component with Turbo Frame updates?

### Chosen Solution
**DaisyUI modal component with Stimulus controller for open/close**

### Rationale
- **Consistency**: Matches existing UI patterns across application
- **Built-in accessibility**: DaisyUI modals have aria attributes and keyboard support
- **Minimal custom CSS**: Leverage battle-tested component library
- **Turbo compatibility**: DaisyUI classes (modal-open, modal-toggle) work with Turbo Frame

### Alternatives Considered

**Option A: Custom modal CSS from scratch**
- **Rejected**: Reinventing the wheel, higher maintenance burden
- **Downside**: Must implement accessibility, browser testing, responsive design manually
- **When to use**: Highly custom modal requirements not supported by DaisyUI

**Option B: Headless UI or Radix UI**
- **Rejected**: React-focused libraries, poor fit for Rails + Hotwire
- **Downside**: Requires additional JavaScript framework layer
- **When to use**: React/Vue frontend with complex component composition needs

### Implementation Notes

**Modal Template**:
```erb
<!-- app/views/products/quick_add.html.erb -->
<turbo-frame id="quick-add-modal">
  <div class="modal modal-open" role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <div class="modal-box">
      <h3 id="modal-title" class="font-bold text-lg"><%= @product.name %></h3>

      <%= render "quick_add_form", product: @product %>

      <div class="modal-action">
        <button type="button" class="btn" data-action="click->quick-add-modal#close">
          Cancel
        </button>
      </div>
    </div>
  </div>
</turbo-frame>
```

**Stimulus Controller**:
```javascript
// app/frontend/javascript/controllers/quick_add_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    // Modal is already open via modal-open class in server response
    // Focus first interactive element
    this.element.querySelector('select, button').focus()
  }

  close(event) {
    // Clear modal content via Turbo Frame
    Turbo.visit(this.element.querySelector('turbo-frame').src, {
      frame: "quick-add-modal",
      action: "replace"
    })
  }
}
```

---

## Decision 3: Accessibility Compliance (WCAG 2.1 AA)

**Question**: Which tools and testing strategy for accessibility compliance?

### Chosen Solution
**Hybrid approach: Automated tools + manual testing**

### Tools

**1. axe DevTools (Browser Extension)**
- **Purpose**: Automated accessibility scanning
- **Coverage**: ~57% of WCAG issues detectable automatically
- **Usage**: Run on shop page and with modal open
- **Pass criteria**: 0 violations, 0 serious issues

**2. Manual Keyboard Testing**
- **Purpose**: Verify all interactive elements keyboard-accessible
- **Coverage**: Modal navigation, focus management, escape key
- **Checklist**: Tab, Shift+Tab, Enter, ESC, focus trap, focus restoration

**3. VoiceOver Screen Reader (macOS)**
- **Purpose**: Verify screen reader announcements
- **Coverage**: Modal open/close, form labels, error messages
- **Testing**: Navigate modal using VO+Arrow keys, verify announcements

**4. Lighthouse Accessibility Audit**
- **Purpose**: Automated scoring and best practices
- **Pass criteria**: Score ≥95 (manual modal testing required)
- **Usage**: Run via Chrome DevTools on shop page

### Implementation Checklist

**Keyboard Navigation**:
- [x] Tab/Shift+Tab cycles through interactive elements
- [x] ESC key closes modal
- [x] Enter key submits form when focused
- [x] Focus trapped within modal (Tab at last element → first element)
- [x] Focus restored to Quick Add button on modal close

**ARIA Attributes**:
- [x] `role="dialog"` on modal container
- [x] `aria-modal="true"` on modal container
- [x] `aria-labelledby` points to modal title
- [x] `aria-label` on form inputs (or associated `<label>` elements)

**Focus Management (Stimulus Controller)**:
```javascript
export default class extends Controller {
  static targets = ["focusTrap"]

  connect() {
    this.previouslyFocusedElement = null
  }

  open(event) {
    // Store previously focused element
    this.previouslyFocusedElement = document.activeElement

    // Focus first interactive element in modal
    const firstFocusable = this.element.querySelector('select, input, button')
    firstFocusable?.focus()

    // Trap focus
    this.element.addEventListener('keydown', this.trapFocus.bind(this))
  }

  close() {
    // Restore focus to trigger button
    this.previouslyFocusedElement?.focus()

    // Remove focus trap
    this.element.removeEventListener('keydown', this.trapFocus.bind(this))
  }

  trapFocus(event) {
    if (event.key !== 'Tab') return

    const focusableElements = this.element.querySelectorAll(
      'select, input, button, [href], [tabindex]:not([tabindex="-1"])'
    )
    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (event.shiftKey && document.activeElement === firstElement) {
      event.preventDefault()
      lastElement.focus()
    } else if (!event.shiftKey && document.activeElement === lastElement) {
      event.preventDefault()
      firstElement.focus()
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
}
```

---

## Decision 4: Mobile Bottom-Sheet Pattern

**Question**: How to implement bottom-sheet modal on mobile devices?

### Chosen Solution
**CSS media queries with transform animations**

### Rationale
- **Native feel**: Bottom sheets are familiar mobile UI pattern
- **Less screen coverage**: Leaves top of screen visible (context)
- **Thumb-friendly**: Controls at bottom of screen within thumb reach
- **Simple implementation**: Pure CSS, no JavaScript gestures needed (initial version)

### Implementation

**CSS** (`app/frontend/stylesheets/components/modals.css`):
```css
/* Desktop: Center modal */
@media (min-width: 768px) {
  .quick-add-modal .modal-box {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    max-width: 500px;
    border-radius: 1rem;
  }
}

/* Mobile: Bottom sheet */
@media (max-width: 767px) {
  .quick-add-modal .modal-box {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    transform: translateY(0);
    max-width: 100%;
    border-radius: 1rem 1rem 0 0;
    max-height: 85vh;
    overflow-y: auto;
  }

  /* Slide-up animation */
  .quick-add-modal.modal-open .modal-box {
    animation: slide-up 0.3s ease-out;
  }

  @keyframes slide-up {
    from {
      transform: translateY(100%);
    }
    to {
      transform: translateY(0);
    }
  }
}
```

**Touch Gestures (Future Enhancement)**:
- Swipe down to close (requires JavaScript)
- Pull-to-refresh disabled within modal
- Touch target size ≥44x44pt for buttons

### Alternatives Considered

**Option A: Same modal style on all devices**
- **Rejected**: Poor mobile UX, covers entire screen
- **When to use**: Desktop-only applications

**Option B: Native mobile sheet component**
- **Rejected**: Requires additional JavaScript library
- **When to use**: Complex mobile app with many bottom sheets

---

## Decision 5: Cart Drawer Integration

**Question**: How to trigger cart drawer open after successful add?

### Chosen Solution
**Custom event dispatch from quick_add_modal_controller → cart_drawer_controller**

### Rationale
- **Decoupled controllers**: No direct references, easier to test and maintain
- **Reusable pattern**: Can trigger cart drawer from other features
- **Stimulus conventions**: Event-based communication is idiomatic Stimulus pattern
- **Turbo Stream compatible**: Works with Turbo's async form submissions

### Implementation

**Quick Add Modal Controller** (dispatch event):
```javascript
// app/frontend/javascript/controllers/quick_add_modal_controller.js
export default class extends Controller {
  connect() {
    // Listen for Turbo Stream responses
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      // Dispatch custom event
      window.dispatchEvent(new CustomEvent('cart:updated', {
        detail: { source: 'quick_add' }
      }))

      // Close modal
      this.close()
    }
  }
}
```

**Cart Drawer Controller** (listen for event):
```javascript
// app/frontend/javascript/controllers/cart_drawer_controller.js
export default class extends Controller {
  connect() {
    // Listen for cart update events
    window.addEventListener('cart:updated', this.handleCartUpdated.bind(this))
  }

  disconnect() {
    window.removeEventListener('cart:updated', this.handleCartUpdated.bind(this))
  }

  handleCartUpdated(event) {
    // Open cart drawer
    this.open()
  }

  open() {
    document.getElementById('cart-drawer').checked = true
  }
}
```

### Alternatives Considered

**Option A: Direct controller reference**
```javascript
// Rejected: Tight coupling
const cartDrawer = this.application.getControllerForElementAndIdentifier(
  document.querySelector('[data-controller="cart-drawer"]'),
  'cart-drawer'
)
cartDrawer.open()
```
- **Rejected**: Tight coupling, brittle (depends on DOM structure)
- **When to use**: Parent-child controller relationships only

**Option B: Stimulus Targets**
- **Rejected**: Requires controllers to be in same element hierarchy
- **When to use**: Components with clear parent-child relationships

---

## Decision 6: Form Submission & Turbo Streams

**Question**: How to handle form submission and modal closure?

### Chosen Solution
**Reuse existing CartItemsController#create with Turbo Stream response**

### Implementation

**Form** (in modal):
```erb
<!-- app/views/products/_quick_add_form.html.erb -->
<%= form_with url: cart_cart_items_path,
              method: :post,
              data: {
                controller: "quick-add-form",
                action: "turbo:submit-end->quick-add-modal#handleSubmitEnd"
              } do |f| %>

  <%= hidden_field_tag "cart_item[variant_sku]",
                       @product.default_variant.sku,
                       data: { quick_add_form_target: "variantSku" } %>

  <% if @product.active_variants.count > 1 %>
    <div class="form-control">
      <label class="label">Select variant:</label>
      <%= select_tag "variant_selector",
                     options_from_collection_for_select(@product.active_variants, :sku, :name),
                     data: { action: "change->quick-add-form#updateVariant" },
                     class: "select select-bordered" %>
    </div>
  <% end %>

  <div class="form-control">
    <label class="label">Select quantity:</label>
    <%= select_tag "cart_item[quantity]",
                   options_for_select((1..10).map { |n| ["#{n} pack(s)", n * @product.default_variant.pac_size] }),
                   class: "select select-bordered" %>
  </div>

  <%= f.submit "Add to Basket", class: "btn btn-primary w-full mt-4" %>
<% end %>
```

**Controller Response**:
```ruby
# app/controllers/cart_items_controller.rb
def create
  # ... existing logic ...

  if @cart_item.save
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          # Update cart counter
          turbo_stream.replace("basket_counter", partial: "shared/basket_counter"),
          # Clear modal (triggers close via Stimulus)
          turbo_stream.replace("quick-add-modal", "<turbo-frame id='quick-add-modal'></turbo-frame>")
        ]
      end
      format.html { redirect_to cart_path }
    end
  end
end
```

---

## Performance Considerations

### Page Load Impact
- **Single modal**: +2KB HTML (negligible)
- **No N+1 queries**: Product cards already eager-load variants
- **Turbo Frame**: On-demand modal content (not included in initial page load)

### Modal Load Time
- **Target**: <500ms from click to modal display
- **Server response**: ~100-200ms (simple template render)
- **Network latency**: ~50-100ms (localhost/CDN)
- **Browser render**: ~50-100ms (small HTML fragment)
- **Total**: ~200-400ms (within budget)

### Mobile Optimization
- **Touch targets**: Minimum 44x44pt (WCAG requirement)
- **Bottom sheet**: Reduces scrolling on small screens
- **Quantity selector**: Dropdown (not freeform input) prevents keyboard issues

---

## Security Considerations

### No New Attack Vectors
- **CSRF protection**: Rails handles via `form_with` helper
- **Input validation**: Reuses existing CartItemsController logic
- **XSS prevention**: ERB templates escape output by default
- **SQL injection**: Uses ActiveRecord (parameterized queries)

### Progressive Enhancement
- **JavaScript disabled**: Quick Add button links to product detail page
- **Fallback route**: `href="/products/:slug"` on Quick Add link
- **No functionality loss**: Full feature available on product page

---

## Browser Compatibility

**Supported Browsers**:
- Chrome 90+ (Turbo, CSS Grid, ES6)
- Firefox 88+ (Turbo, CSS Grid, ES6)
- Safari 14+ (Turbo, CSS Grid, ES6)
- Edge 90+ (Chromium-based)

**Unsupported**:
- IE11 (end-of-life, no Turbo support)
- Opera Mini (limited JavaScript)

**Testing Strategy**:
- Primary: Chrome (development)
- Secondary: Safari (iOS), Firefox (QA)
- Mobile: Safari iOS 14+, Chrome Android 90+

---

## Summary

All technical decisions resolved:
- ✅ Single shared modal with Turbo Frame
- ✅ DaisyUI modal component with Stimulus controller
- ✅ Accessibility compliance (axe + manual testing)
- ✅ Mobile bottom-sheet pattern (CSS media queries)
- ✅ Event-based cart drawer integration
- ✅ Reuse existing cart controller logic

**Next Phase**: Generate data-model.md, API contracts, and quickstart guide (Phase 1).
