# Quickstart: Sample Pack Feature

**Date**: 2025-11-30
**Estimated Implementation Time**: 2-4 hours

## Prerequisites

- Rails development environment running
- Existing test suite passing (`rails test`)
- Admin access to create products

## Implementation Order

### 1. Model Layer (30 min)

**File**: `app/models/product.rb`
```ruby
# Add after PROFIT_MARGINS constant
SAMPLE_PACK_SLUG = "sample-pack".freeze

# Add after existing scopes
scope :shoppable, -> {
  where(product_type: ["standard", "customizable_template"])
    .where.not(slug: SAMPLE_PACK_SLUG)
}

# Add instance method
def sample_pack?
  slug == SAMPLE_PACK_SLUG
end
```

**File**: `app/models/cart.rb`
```ruby
# Add validation
validate :sample_pack_quantity_limit

# Add helper method
def has_sample_pack?
  cart_items.joins(product_variant: :product)
    .where(products: { slug: Product::SAMPLE_PACK_SLUG })
    .exists?
end

private

def sample_pack_quantity_limit
  sample_pack_items = cart_items.select { |item|
    item.product_variant.product.sample_pack?
  }

  if sample_pack_items.sum(&:quantity) > 1
    errors.add(:base, "Only one sample pack allowed per order")
  end
end
```

### 2. Controller Layer (20 min)

**File**: `app/controllers/cart_items_controller.rb`
```ruby
# Add at start of create action, after finding product
if @product.sample_pack? && Current.cart.has_sample_pack?
  redirect_back fallback_location: cart_path,
    notice: "Sample pack already in your cart"
  return
end
```

**File**: `app/controllers/pages_controller.rb`
```ruby
def samples
  @sample_pack = Product.unscoped.find_by(slug: Product::SAMPLE_PACK_SLUG)
  @variant = @sample_pack&.default_variant
end
```

### 3. View Layer (45 min)

**File**: `app/views/pages/samples.html.erb`
- Redesign as marketing landing page
- Add hero section, "What's Included", CTA button
- Handle case where sample pack doesn't exist

**File**: `app/views/products/_standard_product.html.erb` (or equivalent)
```erb
<% unless @product.sample_pack? %>
  <%# quantity selector %>
<% end %>

<% if @product.sample_pack? %>
  <span class="text-success font-semibold">Free — just pay shipping</span>
<% else %>
  <%= format_price(@variant.price) %>
<% end %>
```

**File**: `app/views/carts/_cart_item.html.erb` (or equivalent)
```erb
<% if item.product_variant.product.sample_pack? %>
  <span>Free</span>
<% else %>
  <%= format_price(item.price) %>
<% end %>
```

### 4. Update Shop Listings (10 min)

**File**: `app/controllers/products_controller.rb`
```ruby
# Update index action to use shoppable scope
@products = Product.shoppable.includes(:active_variants, ...)
```

### 5. Create Sample Pack Product (via Admin)

1. Go to `/admin/products/new`
2. Name: "Sample Pack"
3. Leave category blank (or create hidden "Samples" category)
4. Save → slug auto-generates to "sample-pack"
5. Add variant: SKU "SAMPLE-PACK", Price £0.00, Pac Size 1
6. Upload product photos
7. Fill descriptions

## Testing Checklist

```bash
# Run all tests
rails test

# Run specific test files (create these first per TDD)
rails test test/models/product_test.rb
rails test test/models/cart_test.rb
rails test test/controllers/cart_items_controller_test.rb
rails test test/system/sample_pack_test.rb
```

## Verification Steps

1. [ ] Visit `/samples` — landing page loads with CTA
2. [ ] Click "Add to Cart" — sample pack added
3. [ ] Visit `/samples` again, click "Add to Cart" — flash message shown
4. [ ] Visit `/products/sample-pack` — product page loads, no quantity selector
5. [ ] Visit `/shop` — sample pack NOT visible
6. [ ] Visit `/cart` — sample pack shows "Free", other items show price
7. [ ] Complete checkout — order created with £0.00 sample pack line item
8. [ ] Try adding quantity > 1 via URL manipulation — validation rejects

## Rollback Steps

If issues arise:

1. Remove sample pack product via admin
2. Revert code changes (git)
3. No database rollback needed (no migrations)
