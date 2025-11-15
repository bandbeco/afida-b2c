# Quick Add to Cart - Developer Quickstart

**Feature**: 005-quick-add-to-cart
**Date**: 2025-01-15

## Overview

Quick Add allows users to add standard products to their cart directly from shop/category pages via a modal, bypassing the product detail page for familiar products.

**Key Technologies**:
- Turbo Frame (server-rendered modal content)
- Stimulus (modal open/close, form handling)
- DaisyUI (modal component styling)
- Existing CartItemsController (reused for cart add logic)

---

## Quick Start Guide

### 1. Prerequisites

Ensure development environment is set up:

```bash
# Install dependencies
bundle install
npm install

# Setup database
rails db:prepare

# Start development server
bin/dev
```

### 2. Feature Files

**Controllers**:
- `app/controllers/products_controller.rb` - Add `#quick_add` action

**Models**:
- `app/models/product.rb` - Add `quick_add_eligible` scope

**Views**:
- `app/views/products/_card.html.erb` - Quick Add button on product cards
- `app/views/products/quick_add.html.erb` - Modal content (Turbo Frame)
- `app/views/products/_quick_add_form.html.erb` - Modal form partial
- `app/views/shared/_quick_add_modal.html.erb` - Shared modal container

**Frontend**:
- `app/frontend/javascript/controllers/quick_add_modal_controller.js` - Stimulus controller
- `app/frontend/stylesheets/components/modals.css` - Mobile bottom-sheet styles

**Tests**:
- `test/system/quick_add_test.rb` - End-to-end system tests
- `test/controllers/products_controller_test.rb` - Controller unit tests
- `test/models/product_test.rb` - Model scope tests

**Routes**:
- `config/routes.rb` - Add `products/:id/quick_add` route

### 3. Running the Feature Locally

```bash
# Start development server
bin/dev

# Navigate to shop page
open http://localhost:3000/shop

# Click "Quick Add" button on any standard product
# Modal should open with variant/quantity selectors

# Select options and click "Add to Basket"
# Modal closes, cart drawer opens with updated count
```

### 4. Running Tests

```bash
# All quick add tests
rails test test/system/quick_add_test.rb

# Specific test by line number
rails test test/system/quick_add_test.rb:15

# Controller tests
rails test test/controllers/products_controller_test.rb

# Model scope tests
rails test test/models/product_test.rb

# Verbose output
rails test test/system/quick_add_test.rb -v
```

---

## How It Works

### User Flow

1. User browses shop/category page with product cards
2. User clicks "Quick Add" button on standard product
3. Turbo Frame fetches `/products/:slug/quick_add` endpoint
4. Server renders modal HTML and replaces `quick-add-modal` frame
5. Stimulus controller opens modal (adds `modal-open` class)
6. User selects variant (if multi-variant) and quantity
7. User clicks "Add to Basket" button
8. Form submits to `CartItemsController#create` (existing endpoint)
9. Server responds with Turbo Stream actions:
    - Update basket counter
    - Clear modal content (triggers close)
10. Stimulus controller dispatches `cart:updated` event
11. Cart drawer controller listens and opens drawer

### Technical Architecture

**Turbo Frame Flow**:
```
Product Card
    ↓ (click Quick Add)
GET /products/:slug/quick_add
    ↓ (Turbo Frame request)
ProductsController#quick_add
    ↓ (render Turbo Frame HTML)
<turbo-frame id="quick-add-modal">
  <!-- Modal content -->
</turbo-frame>
    ↓ (Turbo replaces frame)
Stimulus Controller: open()
```

**Form Submission Flow**:
```
Quick Add Form
    ↓ (submit)
POST /cart/cart_items
    ↓ (Turbo Stream request)
CartItemsController#create
    ↓ (render Turbo Stream)
<turbo-stream action="replace" target="quick-add-modal">
  <!-- Clear modal -->
</turbo-stream>
    ↓ (Turbo applies action)
Stimulus Controller: handleSubmitEnd()
    ↓ (dispatch event)
window.dispatchEvent('cart:updated')
    ↓ (cart drawer listens)
Cart Drawer Opens
```

---

## Key Code Snippets

### Product Scope (Model)

```ruby
# app/models/product.rb
scope :quick_add_eligible, -> { where(product_type: 'standard') }
```

### Quick Add Button (View)

```erb
<!-- app/views/products/_card.html.erb -->
<% if product.product_type == 'standard' && product.active_variants.any? %>
  <%= link_to "Quick Add",
              product_quick_add_path(product),
              data: {
                turbo_frame: "quick-add-modal",
                controller: "quick-add-modal",
                action: "turbo:frame-load->quick-add-modal#open"
              },
              class: "btn btn-secondary btn-sm" %>
<% end %>
```

### Controller Action

```ruby
# app/controllers/products_controller.rb
def quick_add
  @product = Product.find_by!(slug: params[:id])

  unless @product.product_type == 'standard'
    redirect_to product_path(@product), alert: "Product not available for quick add"
    return
  end

  @variants = @product.active_variants.by_position

  render layout: false  # Turbo Frame content only
end
```

### Route

```ruby
# config/routes.rb
resources :products, only: [:index, :show], param: :slug do
  member do
    get :quick_add
  end
end
```

### Stimulus Controller

```javascript
// app/frontend/javascript/controllers/quick_add_modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
  }

  open(event) {
    // Modal is already open via modal-open class in server response
    const firstFocusable = this.element.querySelector('select, button')
    firstFocusable?.focus()
  }

  close() {
    // Clear modal content
    this.element.innerHTML = '<turbo-frame id="quick-add-modal"></turbo-frame>'
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      // Dispatch event for cart drawer
      window.dispatchEvent(new CustomEvent('cart:updated'))
      this.close()
    }
  }
}
```

---

## Debugging Tips

### Modal Not Opening

**Symptom**: Clicking Quick Add does nothing

**Check**:
1. Browser console for Stimulus controller connection
   ```
   Stimulus controller connected: quick-add-modal
   ```
2. Network tab for GET request to `/products/:slug/quick_add`
3. Response should return Turbo Frame HTML with `modal-open` class

**Fix**:
- Ensure `data-controller="quick-add-modal"` on Quick Add link
- Ensure `data-turbo-frame="quick-add-modal"` attribute present
- Check `quick_add` action exists in ProductsController

### Form Not Submitting

**Symptom**: Clicking "Add to Basket" does nothing

**Check**:
1. Network tab for POST request to `/cart/cart_items`
2. Form `action` attribute points to `cart_cart_items_path`
3. Turbo Stream response in network tab

**Fix**:
- Ensure form has `method: :post`
- Check CSRF token present in form (Rails handles automatically)
- Verify `CartItemsController#create` returns Turbo Stream format

### Cart Not Updating

**Symptom**: Form submits but cart doesn't update

**Check**:
1. Rails logs for `CartItemsController#create` execution
2. Database for new/updated cart_items record
3. Turbo Stream response includes basket counter update

**Fix**:
- Check `Current.cart` is set (ApplicationController concern)
- Verify cart_item params (variant_sku, quantity)
- Ensure Turbo Stream response targets correct elements

### Cart Drawer Not Opening

**Symptom**: Cart updates but drawer doesn't open

**Check**:
1. Browser console for `cart:updated` event dispatch
2. Cart drawer controller is listening for event
3. Drawer element ID matches (`cart-drawer`)

**Fix**:
- Ensure `window.dispatchEvent()` called in `handleSubmitEnd`
- Check `cart_drawer_controller.js` has event listener
- Verify drawer checkbox element exists (`#cart-drawer`)

### Accessibility Issues

**Symptom**: Keyboard navigation not working

**Check**:
1. Tab key cycles through modal elements
2. ESC key closes modal
3. Focus returns to trigger button on close

**Tools**:
- **axe DevTools**: Browser extension for automated a11y testing
- **WAVE**: Browser extension for ARIA/semantic HTML checks
- **VoiceOver** (macOS): Screen reader testing

**Fix**:
- Ensure `role="dialog"` and `aria-modal="true"` on modal
- Implement focus trap in Stimulus controller
- Test with `Lighthouse > Accessibility` (target score ≥95)

---

## Browser Compatibility

**Supported**:
- Chrome 90+ ✅
- Firefox 88+ ✅
- Safari 14+ ✅
- Edge 90+ ✅

**Not Supported**:
- IE11 ❌ (Turbo not supported)
- Opera Mini ❌ (limited JavaScript)

**Progressive Enhancement**:
- JavaScript disabled: Quick Add button links to product detail page
- Turbo not supported: Falls back to full page reload

---

## Testing Strategy

### System Tests (Capybara + Selenium)

**Purpose**: End-to-end user flows

**Tests**:
- Quick Add button visible on standard products
- Quick Add button hidden on customizable products
- Modal opens with correct product name
- Variant selector appears for multi-variant products
- Quantity selector shows correct options
- Form submission adds item to cart
- Cart drawer opens after successful add
- Keyboard navigation works (Tab, ESC, Enter)

**Example**:
```ruby
# test/system/quick_add_test.rb
test "quick add flow for multi-variant product" do
  visit shop_path

  # Click Quick Add on hot cup product
  click_link "Quick Add", match: :first

  # Modal opens
  assert_selector ".modal.modal-open"
  assert_text "Single Wall Hot Cup"

  # Select variant
  select "12oz", from: "variant_selector"

  # Select quantity
  select "2 packs", from: "cart_item[quantity]"

  # Submit form
  click_button "Add to Basket"

  # Cart drawer opens
  assert_selector "#cart-drawer:checked"

  # Cart item added
  assert_text "Single Wall Hot Cup (12oz)"
  assert_text "2 packs"
end
```

### Controller Tests

**Purpose**: Unit test controller actions

**Tests**:
- `quick_add` action renders modal for standard product
- `quick_add` redirects for customizable product
- `quick_add` returns 404 for invalid slug

**Example**:
```ruby
# test/controllers/products_controller_test.rb
test "quick_add renders modal for standard product" do
  product = products(:hot_cup)  # product_type: 'standard'

  get product_quick_add_path(product)

  assert_response :success
  assert_select "turbo-frame#quick-add-modal"
  assert_select ".modal.modal-open"
  assert_select "h3", text: product.name
end

test "quick_add redirects for customizable product" do
  product = products(:branded_cup)  # product_type: 'customizable_template'

  get product_quick_add_path(product)

  assert_redirected_to product_path(product)
  assert_equal "Product not available for quick add", flash[:alert]
end
```

### Model Tests

**Purpose**: Unit test scopes and methods

**Tests**:
- `quick_add_eligible` scope returns only standard products
- Scope excludes customizable and customized instance products

**Example**:
```ruby
# test/models/product_test.rb
test "quick_add_eligible scope returns only standard products" do
  standard = products(:hot_cup)       # product_type: 'standard'
  customizable = products(:branded_cup)  # product_type: 'customizable_template'

  eligible = Product.quick_add_eligible

  assert_includes eligible, standard
  refute_includes eligible, customizable
end
```

---

## Performance Checklist

- [ ] Single modal instance (not per-card)
- [ ] Product cards eager-load variants (`includes(:active_variants)`)
- [ ] No N+1 queries (verify with Bullet gem)
- [ ] Modal load time <500ms (measure with Chrome DevTools)
- [ ] Shop page load time maintained <2s
- [ ] Mobile bottom-sheet CSS uses GPU-accelerated transforms

**Verify with Bullet Gem**:
```bash
# Development environment has Bullet enabled
rails s

# Navigate to /shop
# Check Rails logs for Bullet warnings
# No N+1 query warnings should appear
```

---

## Accessibility Checklist

### Keyboard Navigation
- [ ] Tab navigates forward through modal elements
- [ ] Shift+Tab navigates backward
- [ ] ESC closes modal
- [ ] Enter submits form when button focused
- [ ] Focus returns to Quick Add button on close

### ARIA Attributes
- [ ] `role="dialog"` on modal container
- [ ] `aria-modal="true"` on modal container
- [ ] `aria-labelledby` points to modal title
- [ ] Form inputs have associated labels

### Screen Reader
- [ ] Modal open announced ("Dialog opened")
- [ ] Modal close announced ("Dialog closed")
- [ ] Form elements announced with labels
- [ ] Error messages announced

### Tools
- [ ] axe DevTools: 0 violations
- [ ] Lighthouse Accessibility: Score ≥95
- [ ] WAVE: No critical errors
- [ ] VoiceOver manual test: Pass

---

## Common Mistakes

### Mistake 1: Forgetting Turbo Frame ID

**Wrong**:
```erb
<%= link_to "Quick Add", product_quick_add_path(product) %>
```

**Correct**:
```erb
<%= link_to "Quick Add",
            product_quick_add_path(product),
            data: { turbo_frame: "quick-add-modal" } %>
```

### Mistake 2: Not Rendering Layout False

**Wrong**:
```ruby
def quick_add
  @product = Product.find_by!(slug: params[:id])
  # Renders with full application layout
end
```

**Correct**:
```ruby
def quick_add
  @product = Product.find_by!(slug: params[:id])
  render layout: false  # Turbo Frame content only
end
```

### Mistake 3: Hardcoding Quantity Options

**Wrong**:
```erb
<select name="cart_item[quantity]">
  <option value="1">1 pack</option>
  <option value="2">2 packs</option>
</select>
```

**Correct**:
```erb
<% pac_size = @product.default_variant.pac_size || 1 %>
<%= select_tag "cart_item[quantity]",
               options_for_select((1..10).map { |n|
                 ["#{n} pack(s) (#{n * pac_size} units)", n * pac_size]
               }) %>
```

### Mistake 4: Not Handling Turbo Submit End

**Wrong**:
```javascript
// Modal never closes after successful submit
export default class extends Controller {
  open() {
    // Modal opens but no close logic
  }
}
```

**Correct**:
```javascript
export default class extends Controller {
  connect() {
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
  }

  handleSubmitEnd(event) {
    if (event.detail.success) {
      this.close()
    }
  }
}
```

---

## Next Steps

1. **Run Tests**: `rails test test/system/quick_add_test.rb`
2. **Check Accessibility**: Run axe DevTools on `/shop` with modal open
3. **Verify Performance**: No N+1 queries with Bullet gem
4. **Manual QA**: Test on Chrome, Safari, Firefox
5. **Mobile Test**: Test on iOS Safari, Chrome Android
6. **Code Review**: Ensure RuboCop and Brakeman pass

---

## Resources

- [Hotwire Turbo Frames](https://turbo.hotwired.dev/handbook/frames)
- [Stimulus Controller Guide](https://stimulus.hotwired.dev/handbook/introduction)
- [DaisyUI Modal Component](https://daisyui.com/components/modal/)
- [WCAG 2.1 AA Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [axe DevTools Documentation](https://www.deque.com/axe/devtools/)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)

---

## Support

For questions or issues:
1. Check browser console for errors
2. Review Rails logs (`log/development.log`)
3. Run tests to verify feature is working
4. Refer to research.md for design decisions
5. Consult data-model.md for database queries
