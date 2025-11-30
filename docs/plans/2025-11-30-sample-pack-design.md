# Sample Pack Feature Design

**Date:** 2025-11-30
**Status:** Approved

## Overview

Enable site visitors to request a free sample pack of eco-friendly products, paying only for shipping. The sample pack integrates with the existing cart and checkout flow.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Sample selection | Sample pack only (no individual selection) | Simplest to launch, validates demand |
| Checkout flow | Cart-based (£0.00 product) | Reuses existing infrastructure |
| Mixing with products | Allowed | Better UX, no artificial restrictions |
| Quantity limit | 1 per order | Prevents abuse without complexity |
| Lifetime limit | None | Simple for v1, add later if needed |
| Product identification | Slug convention + constant | Clean, no migration needed |
| Shop visibility | Excluded via `shoppable` scope | Keeps shop focused on sellable products |
| Discovery | Landing page + product page | Marketing flexibility |

## Data Model

**No database changes required.** Sample pack is a regular `Product`:

```
Product:
  name: "Sample Pack"
  slug: "sample-pack"
  product_type: "standard"
  category_id: nil (or assign to a category)

ProductVariant:
  name: "Sample Pack"
  price: 0.00
  sku: "SAMPLE-PACK"
  pac_size: 1
```

### Model Additions

**app/models/product.rb:**

```ruby
SAMPLE_PACK_SLUG = "sample-pack".freeze

def sample_pack?
  slug == SAMPLE_PACK_SLUG
end

scope :shoppable, -> {
  where(product_type: ["standard", "customizable_template"])
    .where.not(slug: SAMPLE_PACK_SLUG)
}
```

## Validation & Cart Logic

### Model Validation

**app/models/cart.rb:**

```ruby
validate :sample_pack_quantity_limit

private

def sample_pack_quantity_limit
  sample_pack_items = cart_items.select { |item| item.product_variant.product.sample_pack? }

  if sample_pack_items.sum(&:quantity) > 1
    errors.add(:base, "Only one sample pack allowed per order")
  end
end
```

### Helper Method

**app/models/cart.rb:**

```ruby
def has_sample_pack?
  cart_items.joins(product_variant: :product)
    .where(products: { slug: Product::SAMPLE_PACK_SLUG })
    .exists?
end
```

### Controller Check

**app/controllers/cart_items_controller.rb:**

```ruby
def create
  product = # ... find product ...

  if product.sample_pack? && Current.cart.has_sample_pack?
    redirect_back fallback_location: cart_path,
      notice: "Sample pack already in your cart"
    return
  end

  # ... existing add-to-cart logic ...
end
```

## UI Changes

### Shop/Category Pages

Use `shoppable` scope to exclude sample pack from listings:

```ruby
# app/controllers/products_controller.rb
@products = Product.shoppable.includes(:active_variants, ...)
```

### Product Page

Hide quantity selector for sample pack:

```erb
<% unless @product.sample_pack? %>
  <%# Existing quantity selector %>
  <select name="quantity">...</select>
<% end %>
```

Show "Free — just pay shipping" instead of £0.00:

```erb
<% if @product.sample_pack? %>
  <span class="text-lg font-semibold text-success">Free — just pay shipping</span>
<% else %>
  <%= format_price(@variant.price) %>
<% end %>
```

### Cart Display

Same treatment for sample pack line items:

```erb
<% if item.product_variant.product.sample_pack? %>
  <span>Free</span>
<% else %>
  <%= format_price(item.price) %>
<% end %>
```

## Samples Landing Page

**Route:** `/samples` (existing, mapped to `PagesController#samples`)

### Controller

**app/controllers/pages_controller.rb:**

```ruby
def samples
  @sample_pack = Product.unscoped.find_by(slug: Product::SAMPLE_PACK_SLUG)
  @variant = @sample_pack&.default_variant
end
```

### View

**app/views/pages/samples.html.erb:**

Marketing-focused landing page with:
- Hero section with value proposition
- "What's Included" section listing sample contents
- Prominent "Add Sample Pack to Cart" CTA
- Graceful fallback if sample pack doesn't exist yet

## Admin & Setup

Creating the sample pack (manual via existing admin):

1. Admin → Products → New
2. Name: "Sample Pack", slug auto-generates to `sample-pack`
3. Add variant: price £0.00, SKU `SAMPLE-PACK`, pac_size 1
4. Upload photos
5. Fill descriptions (what's in the pack)

The existing `sample_eligible` field becomes unused (can repurpose later to document which products are included in the pack).

## Out of Scope (YAGNI)

Keeping v1 simple:

- No lifetime "one per customer" tracking
- No special order type or status for sample orders
- No automated "what's in the box" list from `sample_eligible` products
- No sample-specific email templates (uses standard order confirmation)
- No analytics tracking beyond standard orders

These can be added later based on actual usage patterns.

## Testing Considerations

- Unit tests for `sample_pack?` method and `shoppable` scope
- Cart validation test for quantity limit
- Controller test for "already in cart" check
- System test for add-to-cart flow from landing page
- System test for product page with hidden quantity selector
