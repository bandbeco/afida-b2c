# Turbo Streams Contract: Variant-Level Sample Request System

**Date**: 2025-12-01
**Feature**: 011-variant-samples

## Turbo Frame Targets

### Category Expansion Frame

**Frame ID Pattern:** `category_{category_id}`

**Usage in index page:**
```erb
<%= turbo_frame_tag "category_#{category.id}",
                    data: { category_expand_target: "frame" } do %>
  <!-- Initially empty, loaded via lazy loading -->
<% end %>
```

**Loaded content (from /samples/:category_slug):**
```erb
<%= turbo_frame_tag "category_#{@category.id}" do %>
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
    <% @variants.each do |variant| %>
      <%= render "samples/variant_card", variant: variant %>
    <% end %>
  </div>
<% end %>
```

---

### Variant Card Frame

**Frame ID Pattern:** `sample_product_variant_{variant_id}`

**Usage:**
```erb
<%= turbo_frame_tag dom_id(variant, :sample) do %>
  <!-- Variant card with add/remove button -->
<% end %>
```

**States:**

1. **Not in cart:**
```erb
<%= button_to cart_cart_items_path,
              class: "btn btn-outline btn-primary btn-sm",
              data: { turbo_frame: dom_id(variant, :sample) },
              params: { product_variant_id: variant.id, sample: true } do %>
  Add Sample
<% end %>
```

2. **In cart:**
```erb
<%= button_to cart_cart_item_path(cart_item),
              method: :delete,
              class: "btn btn-success btn-sm",
              data: { turbo_frame: dom_id(variant, :sample) } do %>
  <svg><!-- Checkmark --></svg>
  Added
<% end %>
```

3. **At limit (not in cart):**
```erb
<button class="btn btn-disabled btn-sm" disabled>
  Limit Reached
</button>
```

---

## Turbo Stream Actions

### On Sample Add (POST /cart/cart_items with sample=true)

**Streams returned:**

```erb
<%= turbo_stream.replace dom_id(product_variant, :sample),
                         partial: "samples/variant_card",
                         locals: { variant: product_variant } %>

<%= turbo_stream.replace "cart_counter",
                         partial: "shared/cart_counter" %>

<%= turbo_stream.replace "sample_counter",
                         partial: "samples/sample_counter" %>
```

---

### On Sample Remove (DELETE /cart/cart_items/:id)

**Streams returned:**

```erb
<%= turbo_stream.replace dom_id(@cart_item.product_variant, :sample),
                         partial: "samples/variant_card",
                         locals: { variant: @cart_item.product_variant } %>

<%= turbo_stream.replace "cart_counter",
                         partial: "shared/cart_counter" %>

<%= turbo_stream.replace "sample_counter",
                         partial: "samples/sample_counter" %>
```

---

## DOM Target IDs

| Target ID | Description | Updated By |
|-----------|-------------|------------|
| `sample_product_variant_{id}` | Individual variant card | Add/remove sample |
| `cart_counter` | Header cart item count | Add/remove sample |
| `sample_counter` | Sticky sample counter on /samples | Add/remove sample |
| `category_{id}` | Category expansion container | Initial load via Turbo Frame |

---

## Stimulus Controllers

### category-expand

**Element:** Category card
**Targets:** `frame`, `chevron`
**Values:** `url` (String), `expanded` (Boolean)

**Actions:**
- `toggle`: Expand or collapse category
- `expand`: Load Turbo Frame content, rotate chevron
- `collapse`: Hide content, reset chevron

```javascript
// data-controller="category-expand"
// data-category-expand-url-value="/samples/cups"
// data-action="click->category-expand#toggle"
```

---

### sample-counter

**Element:** Sticky counter bar
**Targets:** `count`
**Values:** `count` (Number), `limit` (Number)

**Behavior:**
- Shows when `count > 0`
- Hides when `count == 0`
- Updates via Turbo Stream replace

```javascript
// data-controller="sample-counter"
// data-sample-counter-count-value="3"
// data-sample-counter-limit-value="5"
```
