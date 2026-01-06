# Implementation Plan: Reorder Schedule Conversion Page Redesign

**Branch**: `001-reorder-schedule-conversion` | **Date**: 2026-01-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-reorder-schedule-conversion/spec.md`

## Summary

Redesign the Set Up Reorder Schedule page as a conversion-focused page to increase customer LTV. The redesign follows a reassurance-first approach where flexibility messaging ("Cancel anytime", "Skip or pause deliveries", "Edit items before each order") is prominently displayed to remove commitment anxiety. The page structure is: Hero with benefits → Frequency selection → Compact collapsible order summary → 3-step "How it works" → CTA with trust messaging.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL (existing `orders`, `order_items`, `reorder_schedules` tables - no schema changes)
**Testing**: Rails test framework with Minitest, fixtures, system tests with Capybara
**Target Platform**: Web (responsive, 320px+ screens)
**Project Type**: Web application (Rails monolith with Vite frontend)
**Performance Goals**: Page load under 2 seconds, no layout shift on expand/collapse
**Constraints**: Must work without JavaScript for expand/collapse (graceful degradation)
**Scale/Scope**: View-only changes to single page template + 1 new Stimulus controller

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Test-First Development | ✅ PASS | System tests required for user flows; fixtures for order data |
| II. SEO & Structured Data | ✅ N/A | Internal authenticated page, not public-facing |
| III. Performance & Scalability | ✅ PASS | No new queries; existing eager loading sufficient |
| IV. Security & Payment Integrity | ✅ PASS | No changes to payment flow or data handling |
| V. Code Quality & Maintainability | ✅ PASS | Standard Rails/Stimulus patterns; RuboCop compliance |
| Technology Constraints | ✅ PASS | Hotwire patterns only, no client-side state frameworks |

**Gate Result**: PASS - No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-reorder-schedule-conversion/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: Research findings
├── quickstart.md        # Phase 1: Implementation guide
└── checklists/
    └── requirements.md  # Spec quality checklist
```

### Source Code (repository root)

```text
app/
├── views/
│   └── reorder_schedules/
│       └── setup.html.erb           # MODIFY: Complete page redesign
├── frontend/
│   ├── javascript/
│   │   └── controllers/
│   │       └── order_summary_toggle_controller.js  # NEW: Expand/collapse
│   └── entrypoints/
│       └── application.js           # MODIFY: Register new controller
└── helpers/
    └── reorder_schedules_helper.rb  # NEW: View helpers (pluralize items, etc.)

test/
├── system/
│   └── reorder_schedule_setup_test.rb  # NEW: System tests for page
└── helpers/
    └── reorder_schedules_helper_test.rb  # NEW: Helper tests
```

**Structure Decision**: Standard Rails MVC with Stimulus for interactivity. Single view template modification plus one new Stimulus controller. No backend changes required.

## Complexity Tracking

> No violations - table not required.

---

## Phase 0: Research

### Research Tasks

1. **Stimulus expand/collapse patterns**: Best practices for accessible toggle behavior
2. **Progressive enhancement**: Ensuring page works without JavaScript
3. **DaisyUI badge components**: Available styling for "Most popular" indicator

### Findings

See [research.md](./research.md) for detailed findings.

---

## Phase 1: Design

### Component Breakdown

**1. Hero Section**
- Headline: "Never Run Out Again"
- Subhead with flexibility promise
- Flexibility badges (3 checkmark items)

**2. Frequency Selector**
- 2x2 grid with radio buttons (existing pattern)
- "Most popular" badge on "Every Month"
- Pre-selected default
- Future discount slot (empty div placeholder)

**3. Order Summary (Collapsible)**
- Compact view: Icon + "X items · £Y per delivery" + expand button
- Expanded view: Full line-item breakdown
- Stimulus controller for toggle behavior
- `<noscript>` fallback shows expanded by default

**4. How It Works (3-Step)**
- Horizontal layout with numbered steps
- Brief copy for each step
- Positioned above CTA

**5. CTA Section**
- Primary button: "Set Up Automatic Delivery"
- Trust line below: Lock icon + "Card saved securely by Stripe · Cancel anytime"

### Data Flow

```
User arrives → Page renders with:
  - @order (existing)
  - @frequencies (existing)
  - @order.order_items.count (new helper method)
  - @order.total_amount (existing)

User clicks expand → Stimulus toggles visibility (no server round-trip)
User selects frequency → Radio updates form value (existing behavior)
User clicks CTA → Form submits (existing flow, unchanged)
```

### API Contracts

No new API endpoints required. This is a view-only redesign using existing controller actions:
- `GET /reorder-schedules/setup?order_id=X` (existing)
- `POST /reorder-schedules` (existing)

### Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `app/views/reorder_schedules/setup.html.erb` | MODIFY | Complete page redesign |
| `app/frontend/javascript/controllers/order_summary_toggle_controller.js` | CREATE | Expand/collapse toggle |
| `app/frontend/entrypoints/application.js` | MODIFY | Register new controller |
| `app/helpers/reorder_schedules_helper.rb` | CREATE | View helper for item pluralization |
| `test/system/reorder_schedule_setup_test.rb` | CREATE | System tests |
| `test/helpers/reorder_schedules_helper_test.rb` | CREATE | Helper unit tests |

---

## Phase 2: Task Generation

Task generation handled by `/speckit.tasks` command.
