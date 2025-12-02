# Routes Contract: Variant-Level Sample Request System

**Date**: 2025-12-01
**Feature**: 011-variant-samples

## New Routes

### Public Routes

| Method | Path | Controller#Action | Description |
|--------|------|-------------------|-------------|
| GET | `/samples` | `samples#index` | Samples browsing page with category cards |
| GET | `/samples/:category_slug` | `samples#category` | Turbo Frame: variants for specific category |

### Existing Routes (Modified Behavior)

| Method | Path | Controller#Action | Changes |
|--------|------|-------------------|---------|
| POST | `/cart/cart_items` | `cart_items#create` | Add `sample: true` param handling |
| DELETE | `/cart/cart_items/:id` | `cart_items#destroy` | No changes (works for samples) |
| POST | `/checkout` | `checkouts#create` | Conditional shipping for samples-only |

---

## Route Definitions

```ruby
# config/routes.rb additions

resources :samples, only: [:index] do
  collection do
    get ":category_slug", action: :category, as: :category
  end
end
```

**Generated helpers:**
- `samples_path` → `/samples`
- `category_samples_path(category_slug)` → `/samples/:category_slug`

---

## Request/Response Contracts

### GET /samples

**Request:**
```
GET /samples HTTP/1.1
Accept: text/html
```

**Response:** HTML page with category cards

**Data provided to view:**
```ruby
@categories = Category.joins(products: :variants)
                      .where(product_variants: { sample_eligible: true, active: true })
                      .distinct
                      .order(:position)
```

---

### GET /samples/:category_slug (Turbo Frame)

**Request:**
```
GET /samples/cups HTTP/1.1
Accept: text/html
Turbo-Frame: category_123
```

**Response:** Turbo Frame with variant cards

**Data provided to view:**
```ruby
@category = Category.find_by!(slug: params[:category_slug])
@variants = ProductVariant.sample_eligible
                          .joins(:product)
                          .where(products: { category_id: @category.id, active: true })
                          .where(active: true)
                          .includes(product: { product_photo_attachment: :blob })
```

---

### POST /cart/cart_items (Sample Addition)

**Request:**
```
POST /cart/cart_items HTTP/1.1
Content-Type: application/x-www-form-urlencoded

product_variant_id=456&sample=true
```

**Success Response (Turbo Stream):**
```html
<turbo-stream action="replace" target="sample_product_variant_456">
  <!-- Updated variant card showing "Added" state -->
</turbo-stream>
<turbo-stream action="replace" target="cart_counter">
  <!-- Updated cart counter -->
</turbo-stream>
<turbo-stream action="replace" target="sample_counter">
  <!-- Updated sample counter -->
</turbo-stream>
```

**Error Responses:**

| Condition | Response |
|-----------|----------|
| Variant not sample-eligible | Redirect with alert: "This product is not available as a sample." |
| Sample limit reached | Redirect with notice: "You've reached the maximum of 5 samples." |
| Already in cart | Redirect with notice: "This sample is already in your cart." |

---

### POST /checkout (Samples-Only)

**Behavior Change:**

When `cart.only_samples?` returns `true`:
- Shipping options: Single option "Sample Delivery" at £7.50
- Line items: All items with `unit_amount: 0`
- Tax: Applied only to shipping

**Shipping options returned:**
```ruby
if cart.only_samples?
  [{
    shipping_rate_data: {
      type: "fixed_amount",
      fixed_amount: { amount: 750, currency: "gbp" },
      display_name: "Sample Delivery",
      delivery_estimate: {
        minimum: { unit: "business_day", value: 3 },
        maximum: { unit: "business_day", value: 5 }
      }
    }
  }]
else
  Shipping.stripe_shipping_options  # Standard + Express
end
```

---

## Admin Routes (No Changes)

Existing admin routes continue to work:
- `GET /admin/products/:product_id/variants/:id/edit` - Now shows sample fields
- `PATCH /admin/products/:product_id/variants/:id` - Now accepts `sample_eligible`, `sample_sku` params
- `GET /admin/orders` - Now shows sample badges and accepts `filter` param
