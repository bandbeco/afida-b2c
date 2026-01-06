# Quickstart: Reorder Schedule Conversion Page

**Feature**: 001-reorder-schedule-conversion
**Date**: 2026-01-06

## Overview

This guide provides implementation instructions for redesigning the Set Up Reorder Schedule page as a conversion-focused page.

## Prerequisites

- Rails development environment running (`bin/dev`)
- Existing order with items (for testing)
- User account with saved address

## Files to Create/Modify

### 1. Stimulus Controller (NEW)

**File**: `app/frontend/javascript/controllers/order_summary_toggle_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon", "buttonText"]
  static classes = ["hidden"]

  connect() {
    // Ensure hidden class is applied on connect
    if (!this.contentTarget.classList.contains(this.hiddenClass)) {
      this.contentTarget.classList.add(this.hiddenClass)
    }
  }

  toggle() {
    const isHidden = this.contentTarget.classList.toggle(this.hiddenClass)
    this.iconTarget.classList.toggle("rotate-180")
    this.buttonTextTarget.textContent = isHidden ? "View items" : "Hide items"
  }
}
```

### 2. Register Controller (MODIFY)

**File**: `app/frontend/entrypoints/application.js`

Add to the `lazyControllers` object:

```javascript
const lazyControllers = {
  // ... existing controllers
  "order-summary-toggle": () => import("../javascript/controllers/order_summary_toggle_controller")
}
```

### 3. View Helper (NEW)

**File**: `app/helpers/reorder_schedules_helper.rb`

```ruby
# frozen_string_literal: true

module ReorderSchedulesHelper
  def order_items_summary(order)
    count = order.order_items.size
    total = number_to_currency(order.total_amount, unit: "£")
    "#{pluralize(count, 'item')} · #{total} per delivery"
  end
end
```

### 4. View Template (MODIFY)

**File**: `app/views/reorder_schedules/setup.html.erb`

See implementation tasks for full template. Key sections:

1. **Hero Section**: Headline + flexibility badges
2. **Frequency Selector**: 2x2 grid with "Most popular" badge
3. **Order Summary**: Collapsible with Stimulus controller
4. **How It Works**: 3-step horizontal layout
5. **CTA Section**: Button + trust line

## Testing

### System Test

**File**: `test/system/reorder_schedule_setup_test.rb`

Test these scenarios:
1. Page displays flexibility messaging prominently
2. Frequency selector works with "Most popular" indicator
3. Order summary expand/collapse functions
4. CTA button text and trust messaging present
5. Form submission works correctly

### Helper Test

**File**: `test/helpers/reorder_schedules_helper_test.rb`

Test these scenarios:
1. `order_items_summary` returns correct pluralization for 1 item
2. `order_items_summary` returns correct pluralization for multiple items
3. `order_items_summary` formats currency correctly

## Development Workflow

1. **Write tests first** (TDD per constitution)
2. Create Stimulus controller
3. Register controller in application.js
4. Create view helper
5. Modify view template
6. Run tests to verify
7. Run RuboCop for linting
8. Manual browser testing

## Verification Checklist

- [ ] Flexibility badges visible without scrolling
- [ ] "Every Month" pre-selected with "Most popular" badge
- [ ] Order summary expands/collapses correctly
- [ ] Order summary shows expanded when JS disabled
- [ ] "How it works" shows 3 steps
- [ ] CTA reads "Set Up Automatic Delivery"
- [ ] Trust line shows below CTA
- [ ] Form submits correctly to existing endpoint
- [ ] Page is responsive (320px+)
- [ ] All tests pass
- [ ] RuboCop passes
