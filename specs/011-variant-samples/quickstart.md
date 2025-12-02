# Quickstart: Variant-Level Sample Request System

**Date**: 2025-12-01
**Feature**: 011-variant-samples

## Overview

This feature enables visitors to request up to 5 free product variant samples with £7.50 flat shipping (or free with paid orders).

## Key Files to Modify/Create

### New Files

| File | Purpose |
|------|---------|
| `db/migrate/*_add_sample_fields_to_product_variants.rb` | Database migration |
| `app/controllers/samples_controller.rb` | Samples browsing page |
| `app/views/samples/index.html.erb` | Main samples page |
| `app/views/samples/_category_card.html.erb` | Category card partial |
| `app/views/samples/_category_variants.html.erb` | Expanded variants |
| `app/views/samples/_variant_card.html.erb` | Individual variant card |
| `app/views/samples/_sample_counter.html.erb` | Sticky counter bar |
| `app/frontend/javascript/controllers/category_expand_controller.js` | Category toggle |
| `app/frontend/javascript/controllers/sample_counter_controller.js` | Counter visibility |
| `test/controllers/samples_controller_test.rb` | Controller tests |
| `test/system/sample_request_flow_test.rb` | E2E tests |

### Modified Files

| File | Changes |
|------|---------|
| `app/models/product_variant.rb` | Add `sample_eligible` scope, `effective_sample_sku` method |
| `app/models/cart.rb` | Add sample tracking methods |
| `app/models/order.rb` | Add sample detection methods and scope |
| `app/controllers/cart_items_controller.rb` | Handle `sample: true` param |
| `app/controllers/checkouts_controller.rb` | Conditional shipping for samples-only |
| `config/routes.rb` | Add `/samples` routes |
| `config/initializers/shipping.rb` | Add sample shipping option |
| `app/views/admin/product_variants/_form.html.erb` | Sample eligibility fields |
| `app/views/admin/orders/index.html.erb` | Sample badges and filters |
| `app/views/admin/orders/show.html.erb` | Sample indicators |
| `app/views/cart_items/_cart_item.html.erb` | Sample display styling |
| `test/models/product_variant_test.rb` | Sample scope tests |
| `test/models/cart_test.rb` | Sample tracking tests |
| `test/models/order_test.rb` | Sample detection tests |

---

## Implementation Order

### Phase 1: Database & Models (Foundation)

1. **Migration**: Add `sample_eligible` and `sample_sku` to `product_variants`
2. **ProductVariant**: Add scope and `effective_sample_sku` method
3. **Cart**: Add `sample_items`, `sample_count`, `only_samples?`, `at_sample_limit?`
4. **Order**: Add `contains_samples?`, `sample_request?`, `with_samples` scope

### Phase 2: Controller & Routes

5. **Routes**: Add `/samples` routes
6. **SamplesController**: `index` and `category` actions

### Phase 3: Views & Frontend

7. **Samples views**: Index page, category card, variant card, counter
8. **Stimulus controllers**: Category expand, sample counter
9. **Cart item handling**: Modify `CartItemsController#create` for samples

### Phase 4: Checkout Integration

10. **Shipping module**: Add sample-only shipping option
11. **CheckoutsController**: Conditional shipping logic

### Phase 5: Cart Display

12. **Cart item partial**: Show "Free" and "(Sample)" for samples

### Phase 6: Admin UI

13. **Variant form**: Sample eligibility fields
14. **Orders index**: Sample badges and filters
15. **Order show**: Sample indicators

### Phase 7: Testing

16. **Model tests**: All new scopes and methods
17. **Controller tests**: Samples and cart items
18. **System tests**: Full E2E flow

---

## Testing Commands

```bash
# Run all tests
rails test

# Run specific test files
rails test test/models/product_variant_test.rb
rails test test/models/cart_test.rb
rails test test/models/order_test.rb
rails test test/controllers/samples_controller_test.rb
rails test test/controllers/cart_items_controller_test.rb

# Run system tests
rails test:system

# Run linter
rubocop

# Run security scanner
brakeman
```

---

## Key Patterns to Follow

### Sample Addition (CartItemsController)

```ruby
def create_sample_cart_item
  product_variant = ProductVariant.find(params[:product_variant_id])

  unless product_variant.sample_eligible?
    return redirect_to samples_path, alert: "This product is not available as a sample."
  end

  if @cart.at_sample_limit?
    return redirect_to samples_path, notice: "You've reached the maximum of #{Cart::SAMPLE_LIMIT} samples."
  end

  if @cart.cart_items.exists?(product_variant: product_variant)
    return redirect_to samples_path, notice: "This sample is already in your cart."
  end

  @cart_item = @cart.cart_items.build(
    product_variant: product_variant,
    quantity: 1,
    price: 0
  )

  # ... save and respond with Turbo Streams
end
```

### Shipping Logic (CheckoutsController)

```ruby
shipping_options = if Current.cart.only_samples?
  [Shipping.sample_only_shipping_option]
else
  Shipping.stripe_shipping_options
end
```

### Turbo Frame Pattern (Views)

```erb
<%# Category expansion %>
<%= turbo_frame_tag "category_#{category.id}" do %>
  <!-- Content loaded lazily -->
<% end %>

<%# Variant card with inline update %>
<%= turbo_frame_tag dom_id(variant, :sample) do %>
  <!-- Add/remove button -->
<% end %>
```

---

## Verification Checklist

After implementation, verify:

- [ ] `/samples` page shows categories with sample-eligible variants
- [ ] Clicking category expands inline with variants
- [ ] Can add up to 5 samples to cart
- [ ] 6th sample blocked with "Limit Reached"
- [ ] Samples show as "Free (Sample)" in cart
- [ ] Samples-only checkout shows £7.50 shipping
- [ ] Mixed cart uses standard shipping (samples free)
- [ ] Admin can toggle sample eligibility on variants
- [ ] Admin sees sample badges on orders
- [ ] All tests pass
- [ ] RuboCop passes
- [ ] Brakeman passes
