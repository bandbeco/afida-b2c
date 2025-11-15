# Implementation Plan: Quick Add to Cart

**Branch**: `005-quick-add-to-cart` | **Date**: 2025-01-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-quick-add-to-cart/spec.md`

## Summary

Allow store visitors to add standard products to their shopping cart directly from shop and category pages without visiting product detail pages. This feature uses a Turbo Frame modal with variant and quantity selectors, auto-opens the cart drawer on successful add, and intelligently increments existing cart items to prevent duplicates.

## Technical Context

**Language/Version**: Ruby 3.3.0+ / Rails 8.x
**Primary Dependencies**: Vite Rails, Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI
**Storage**: PostgreSQL 14+ (existing `products`, `product_variants`, `carts`, `cart_items` tables)
**Testing**: Rails test framework (Minitest), system tests with Capybara + Selenium
**Target Platform**: Web application (responsive desktop + mobile)
**Project Type**: Rails monolith with Vite frontend (Hotwire architecture)
**Performance Goals**: Modal load <500ms, no N+1 queries, maintain shop page load time <2s
**Constraints**: No client-side state management, server-rendered via Turbo, progressive enhancement
**Scale/Scope**: ~50 products on shop page, single shared modal instance, reuse existing cart logic

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. Test-First Development (TDD)
- **Compliance**: All implementation tasks will follow TDD with tests written first
- **Test Coverage**: System tests for modal flow, controller tests for quick_add action, integration tests for cart updates
- **Red-Green-Refactor**: Tests will fail initially, implementation will make them pass

### ✅ II. SEO & Structured Data
- **Compliance**: No SEO impact - feature is JavaScript enhancement, degrades gracefully
- **Progressive Enhancement**: Quick Add buttons link to product pages when JS disabled
- **No Schema Changes**: Existing product/category pages retain all structured data

### ✅ III. Performance & Scalability
- **Compliance**: Single shared modal prevents DOM bloat, Turbo Frame reduces full page reloads
- **N+1 Prevention**: Product cards already eager-load variants, no additional queries
- **SQL Aggregation**: Cart updates use existing CartItemsController logic (already optimized)
- **Memoization**: Not applicable - modal content is ephemeral

### ✅ IV. Security & Payment Integrity
- **Compliance**: Reuses existing CartItemsController#create with CSRF protection
- **Input Validation**: Variant SKU and quantity validated server-side
- **No New Attack Vectors**: Modal is server-rendered, form submission uses existing Rails security

### ✅ V. Code Quality & Maintainability
- **Compliance**: RuboCop will pass, Stimulus controller follows existing patterns
- **Single Responsibility**: Modal controller handles UI only, cart logic in CartItemsController
- **Explicit Scopes**: Product scope for quick_add_eligible (excludes customizable_template)
- **Reversible Migration**: No database changes required

### ⚠️ Accessibility Requirements (WCAG 2.1 AA)
- **Additional Gate**: Keyboard navigation, screen reader support, focus management
- **Testing**: Manual accessibility audit + automated tools
- **Documentation**: Accessibility testing checklist in Phase 1

**Overall Status**: ✅ PASS - All constitution principles satisfied, no violations to justify

## Project Structure

### Documentation (this feature)

```text
specs/005-quick-add-to-cart/
├── plan.md              # This file (/speckit.plan command output)
├── spec.md              # Feature specification
├── research.md          # Phase 0 output (technology decisions and patterns)
├── data-model.md        # Phase 1 output (no schema changes, documents existing models)
├── quickstart.md        # Phase 1 output (developer onboarding guide)
├── contracts/           # Phase 1 output (API contracts for ProductsController#quick_add)
│   └── quick-add-modal.yaml  # OpenAPI spec for modal endpoint
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
app/
├── controllers/
│   └── products_controller.rb           # Add #quick_add action
├── models/
│   └── product.rb                        # Add scope :quick_add_eligible
├── views/
│   ├── products/
│   │   ├── _card.html.erb               # Add Quick Add button
│   │   ├── quick_add.html.erb           # Modal content (Turbo Frame)
│   │   └── _quick_add_form.html.erb     # Modal form partial
│   └── shared/
│       └── _quick_add_modal.html.erb    # Shared modal container
├── frontend/
│   └── javascript/
│       └── controllers/
│           └── quick_add_modal_controller.js  # Stimulus controller
└── helpers/
    └── products_helper.rb               # Helper methods if needed

test/
├── controllers/
│   └── products_controller_test.rb      # Test #quick_add action
├── models/
│   └── product_test.rb                  # Test quick_add_eligible scope
└── system/
    └── quick_add_test.rb                # End-to-end modal flow tests

config/
└── routes.rb                            # Add products/:id/quick_add route
```

**Structure Decision**: Rails monolith with Vite frontend. Quick Add feature integrates into existing product browsing pages with minimal structural changes. No new models or database migrations required - reuses existing Product, ProductVariant, Cart, and CartItem models.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - this section is empty. All constitution principles are satisfied.

## Phase 0: Research (Outline & Research)

**Purpose**: Resolve technical unknowns and document technology decisions.

### Research Tasks

1. **Turbo Frame Modal Patterns**
   - **Question**: Best practices for single shared modal vs. per-instance modals
   - **Research Scope**: Hotwire documentation, Turbo Frame lifecycle, performance implications
   - **Deliverable**: Decision matrix in research.md with performance/complexity trade-offs

2. **DaisyUI Modal Component Integration**
   - **Question**: How to integrate DaisyUI modal with Turbo Frame updates
   - **Research Scope**: DaisyUI modal component API, Turbo Frame compatibility, CSS transitions
   - **Deliverable**: Code examples for modal open/close with Turbo Stream responses

3. **Accessibility Testing Tools**
   - **Question**: Which tools to use for WCAG 2.1 AA compliance verification
   - **Research Scope**: axe DevTools, WAVE, keyboard navigation testing checklist
   - **Deliverable**: Testing strategy and tool recommendations in research.md

4. **Mobile Bottom-Sheet Pattern**
   - **Question**: CSS techniques for bottom-sheet modal on mobile
   - **Research Scope**: Mobile-first responsive patterns, touch gesture support
   - **Deliverable**: CSS implementation approach for mobile vs. desktop modal

5. **Cart Drawer Integration**
   - **Question**: How to trigger cart drawer open from Turbo Stream response
   - **Research Scope**: Existing cart_drawer_controller.js, Stimulus event system
   - **Deliverable**: Event dispatch pattern for cross-controller communication

### Research Output

**File**: `research.md`

**Structure**:
```markdown
# Quick Add to Cart - Research Findings

## Decision 1: Modal Architecture
- **Chosen**: Single shared modal with Turbo Frame content swapping
- **Rationale**: Performance (1 modal vs. 50 on shop page), memory efficiency, simpler state management
- **Alternatives Considered**: Per-card modals (rejected: DOM bloat), lazy-load modal (rejected: complexity)
- **Implementation Notes**: Modal container in layout, Turbo Frame target, Stimulus controller for UI

## Decision 2: DaisyUI + Turbo Integration
- **Chosen**: DaisyUI modal component with Stimulus controller for open/close
- **Rationale**: Consistent with existing UI patterns, built-in accessibility, minimal custom CSS
- **Alternatives Considered**: Custom modal CSS (rejected: reinventing wheel), Headless UI (rejected: React-focused)
- **Implementation Notes**: Use data-turbo-frame attribute, modal-toggle class, Stimulus actions

## Decision 3: Accessibility Compliance
- **Tools**: axe DevTools (automated), manual keyboard testing, VoiceOver (macOS screen reader)
- **Checklist**: ESC closes modal, Tab cycles focus, Enter submits, aria-label on modal, role="dialog"
- **Implementation Notes**: Focus trap in Stimulus controller, restore focus on close

## Decision 4: Mobile UX
- **Chosen**: CSS media queries for bottom-sheet on mobile (<768px)
- **Rationale**: Native feel on mobile, less screen coverage, familiar pattern
- **Alternatives Considered**: Same modal style on all devices (rejected: poor mobile UX)
- **Implementation Notes**: transform: translateY() on mobile, transition animations

## Decision 5: Cart Drawer Trigger
- **Chosen**: Dispatch custom event from quick_add_modal_controller, listen in cart_drawer_controller
- **Rationale**: Decoupled controllers, reusable pattern, follows Stimulus conventions
- **Alternatives Considered**: Direct controller reference (rejected: tight coupling)
- **Implementation Notes**: window.dispatchEvent(new CustomEvent('cart:updated'))
```

## Phase 1: Design & Contracts

**Purpose**: Define data models, API contracts, and quick-start documentation.

### Deliverable 1: data-model.md

**Content**: Document existing models used by this feature (no schema changes).

```markdown
# Quick Add to Cart - Data Model

## Existing Models (No Changes)

### Product
**Table**: `products`
**Relevant Fields**:
- `id`: Primary key
- `slug`: SEO-friendly URL identifier
- `name`: Product name
- `product_type`: Enum ('standard', 'customizable_template', 'customized_instance')
- `active`: Boolean (only active products shown)

**New Scope**:
```ruby
scope :quick_add_eligible, -> { where(product_type: 'standard') }
```

**Rationale**: Exclude customizable products (too complex for quick add modal)

### ProductVariant
**Table**: `product_variants`
**Relevant Fields**:
- `id`: Primary key
- `product_id`: Foreign key to products
- `sku`: Unique variant identifier
- `name`: Variant name (e.g., "12oz")
- `price`: Pack price in cents
- `pac_size`: Units per pack
- `active`: Boolean (only active variants shown)

**Existing Scopes Used**:
- `active`: Filters active variants only
- `by_position`: Orders variants by position field

### Cart & CartItem
**Tables**: `carts`, `cart_items`
**Existing Logic**: Reused from CartItemsController#create_standard_cart_item
**Behavior**: Find or increment existing cart item, or create new line item

**No Schema Changes Required**: Feature uses existing cart architecture.

## Relationships

```
Product (1) ──< (many) ProductVariant
Cart (1) ──< (many) CartItem >── (1) ProductVariant
```

## Validation Rules

- **Product**: Must be active and quick_add_eligible
- **ProductVariant**: Must be active and belong to selected product
- **Quantity**: Must be multiple of pac_size, range 1-10 packs
```

### Deliverable 2: contracts/quick-add-modal.yaml

**Content**: OpenAPI specification for the quick_add endpoint.

```yaml
openapi: 3.0.0
info:
  title: Quick Add Modal API
  version: 1.0.0
  description: Endpoint for rendering quick add modal content

paths:
  /products/{slug}/quick_add:
    get:
      summary: Render quick add modal for a product
      description: |
        Returns Turbo Frame HTML for quick add modal. Includes variant selector,
        quantity selector, and add to cart form.
      parameters:
        - name: slug
          in: path
          required: true
          schema:
            type: string
          description: Product slug (SEO-friendly identifier)
          example: "single-wall-hot-cup"
      responses:
        '200':
          description: Modal HTML content
          content:
            text/html:
              schema:
                type: string
                example: |
                  <turbo-frame id="quick-add-modal">
                    <!-- Modal content -->
                  </turbo-frame>
        '404':
          description: Product not found or not eligible for quick add
          content:
            text/html:
              schema:
                type: string
                example: |
                  <turbo-frame id="quick-add-modal">
                    <p>Product not available for quick add</p>
                  </turbo-frame>
      tags:
        - Products
        - Quick Add

  /cart/cart_items:
    post:
      summary: Add item to cart (existing endpoint, reused)
      description: |
        Accepts form submission from quick add modal. Existing endpoint
        from CartItemsController with Turbo Stream response.
      requestBody:
        required: true
        content:
          application/x-www-form-urlencoded:
            schema:
              type: object
              properties:
                cart_item[variant_sku]:
                  type: string
                  description: ProductVariant SKU
                  example: "SWC-8OZ-WHT"
                cart_item[quantity]:
                  type: integer
                  description: Quantity in units (multiple of pac_size)
                  example: 50
              required:
                - cart_item[variant_sku]
                - cart_item[quantity]
      responses:
        '201':
          description: Item added to cart (Turbo Stream response)
          content:
            text/vnd.turbo-stream.html:
              schema:
                type: string
                example: |
                  <turbo-stream action="replace" target="quick-add-modal">
                    <!-- Clear modal content -->
                  </turbo-stream>
        '422':
          description: Validation error
          content:
            text/vnd.turbo-stream.html:
              schema:
                type: string
                example: |
                  <turbo-stream action="replace" target="quick-add-modal">
                    <!-- Error message -->
                  </turbo-stream>
      tags:
        - Cart
```

### Deliverable 3: quickstart.md

**Content**: Developer onboarding guide for this feature.

```markdown
# Quick Add to Cart - Developer Quickstart

## Overview

Quick Add allows users to add products to cart from shop/category pages via a modal,
bypassing the product detail page for familiar products.

## Key Files

- **Controller**: `app/controllers/products_controller.rb` (ProductsController#quick_add)
- **Views**:
  - `app/views/products/quick_add.html.erb` (modal content)
  - `app/views/products/_quick_add_form.html.erb` (form partial)
  - `app/views/products/_card.html.erb` (Quick Add button)
- **Frontend**: `app/frontend/javascript/controllers/quick_add_modal_controller.js`
- **Tests**: `test/system/quick_add_test.rb`

## How It Works

1. User clicks "Quick Add" button on product card
2. Link has `data-turbo-frame="quick-add-modal"` attribute
3. Turbo fetches `/products/:slug/quick_add` and replaces modal frame
4. Stimulus controller opens modal (adds `modal-open` class)
5. User selects variant + quantity, submits form
6. CartItemsController#create handles form (existing logic)
7. Turbo Stream response clears modal, triggers cart drawer open

## Running Tests

```bash
# All quick add tests
rails test test/system/quick_add_test.rb

# Specific test
rails test test/system/quick_add_test.rb:10

# With verbose output
rails test test/system/quick_add_test.rb -v
```

## Local Development

```bash
# Start dev server
bin/dev

# Open shop page
open http://localhost:3000/shop

# Click Quick Add on any standard product
# Modal should open with variant/quantity selectors
```

## Debugging Tips

- **Modal not opening**: Check browser console for Stimulus controller connection
- **Form not submitting**: Inspect network tab for Turbo Stream response
- **Cart not updating**: Check CartItemsController#create logs
- **Accessibility issues**: Run axe DevTools browser extension

## Browser Compatibility

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Turbo requires JavaScript enabled
- Progressive enhancement: falls back to product page link

## Accessibility Checklist

- [ ] ESC key closes modal
- [ ] Tab key cycles through modal elements
- [ ] Enter key submits form
- [ ] Focus trapped within modal
- [ ] Screen reader announces modal open/close
- [ ] aria-label on modal element
- [ ] role="dialog" on modal container
```

### Deliverable 4: Update Agent Context

**Action**: Run agent context update script.

```bash
.specify/scripts/bash/update-agent-context.sh claude
```

**Expected Updates to CLAUDE.md**:
- Add "Quick Add to Cart" to architecture overview
- Document Turbo Frame modal pattern
- Note Product.quick_add_eligible scope
- Link to quickstart.md for developers

## Phase 2: Task Breakdown

**Note**: Phase 2 is handled by `/speckit.tasks` command (NOT created by /speckit.plan).

This plan stops here. The next step is to run `/speckit.tasks` to generate bite-sized implementation tasks.

## Appendix: Accessibility Testing

### Manual Testing Checklist

**Keyboard Navigation**:
- [ ] Tab navigates forward through modal elements (variant selector → quantity selector → submit button)
- [ ] Shift+Tab navigates backward
- [ ] ESC closes modal
- [ ] Enter submits form when button focused
- [ ] Focus returns to Quick Add button on modal close

**Screen Reader (VoiceOver on macOS)**:
- [ ] Modal open announced ("Dialog opened")
- [ ] Modal close announced ("Dialog closed")
- [ ] Form elements announced with labels
- [ ] Error messages announced
- [ ] Success state announced

**Focus Management**:
- [ ] Focus moves to modal on open (first interactive element)
- [ ] Focus trapped within modal (Tab at last element cycles to first)
- [ ] Focus restored to trigger button on close

### Automated Tools

1. **axe DevTools** (browser extension)
   - Run on shop page with Quick Add buttons
   - Open modal and scan again
   - Must pass with 0 violations

2. **Lighthouse Accessibility Audit**
   - Score must be ≥95
   - Manual checks for modal interactions

3. **WAVE** (browser extension)
   - Check for ARIA attributes
   - Verify semantic HTML

## Next Steps

1. Run `/speckit.tasks` to generate implementation tasks
2. Implement following TDD (tests first)
3. Run accessibility audit before merging
4. Monitor post-launch metrics (conversion rate, time to cart)
