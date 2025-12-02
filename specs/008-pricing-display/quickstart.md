# Quickstart: Pricing Display Consolidation

**Feature**: 008-pricing-display
**Date**: 2025-11-26

## Overview

This feature centralizes pricing display logic for order items. Standard products show pack pricing with unit breakdown; branded products show unit pricing only.

## Key Files to Understand

Before implementing, read these files in order:

1. **`app/models/cart_item.rb`** - Current working implementation (lines 33-47)
   - Shows how `configured?`, `unit_price`, and pack calculations work

2. **`app/views/cart_items/_cart_item.html.erb`** - Current correct display (lines 35-50)
   - Shows the conditional logic we're extracting into a helper

3. **`app/models/order_item.rb`** - Target for model changes
   - Note: `create_from_cart_item` method stores `unit_price` (needs changing)

4. **`app/views/orders/show.html.erb`** - Target for view fix (line 66)
   - Currently shows "£X.XX each" - needs `format_price_display`

5. **`app/services/order_pdf_generator.rb`** - PDF display fix (line 94)
   - Uses `format_currency(item.price)` - needs pricing context

## Implementation Sequence

### Step 1: Database Migration
```bash
rails generate migration AddPacSizeToOrderItems pac_size:integer
rails db:migrate
```

### Step 2: OrderItem Model
Add to `app/models/order_item.rb`:
```ruby
def pack_priced?
  !configured? && pac_size.present? && pac_size > 1
end

def pack_price
  pack_priced? ? price : nil
end

def unit_price
  pack_priced? ? (price / pac_size) : price
end
```

Update `create_from_cart_item`:
```ruby
price: cart_item.price,  # Changed from unit_price
pac_size: cart_item.product_variant.pac_size,  # New field
```

### Step 3: CartItem Model
Add to `app/models/cart_item.rb`:
```ruby
def pack_priced?
  !configured? && product_variant.pac_size.present? && product_variant.pac_size > 1
end

def pack_price
  pack_priced? ? price : nil
end
```

### Step 4: PricingHelper
Create `app/helpers/pricing_helper.rb`:
```ruby
module PricingHelper
  def format_price_display(item)
    if item.pack_priced?
      pack = number_to_currency(item.pack_price, unit: "£")
      unit = number_to_currency(item.unit_price, unit: "£", precision: 4)
      "#{pack} / pack (#{unit} / unit)"
    else
      unit = number_to_currency(item.unit_price, unit: "£", precision: 4)
      "#{unit} / unit"
    end
  end
end
```

### Step 5: Update Views
Replace pricing display in each view with:
```erb
<%= format_price_display(item) %>
```

### Step 6: Update PDF Generator
Include helper and use `format_price_display`:
```ruby
include PricingHelper
# In add_items_table:
format_price_display(item)  # instead of format_currency(item.price)
```

## Testing Verification

Run these commands to verify:
```bash
# Run all tests
rails test

# Run specific model tests
rails test test/models/order_item_test.rb
rails test test/models/cart_item_test.rb

# Run helper tests
rails test test/helpers/pricing_helper_test.rb

# Run system tests for visual verification
rails test:system
```

## Manual Testing Checklist

1. **Cart with standard product**:
   - Add product with pac_size > 1
   - Verify display: "£X.XX / pack (£X.XXXX / unit)"

2. **Cart with branded product**:
   - Configure a branded product
   - Verify display: "£X.XXXX / unit"

3. **Complete checkout**:
   - Order show page displays correct pricing
   - Admin order view displays correct pricing
   - PDF attachment shows correct pricing

## Common Pitfalls

1. **Forgetting to update `create_from_cart_item`**: The model methods won't help if we're still storing unit price.

2. **PDF helper access**: Prawn services don't auto-include helpers. Must explicitly `include PricingHelper`.

3. **Precision mismatch**: Use `precision: 4` for unit prices to avoid misleading display (£0.03 vs £0.0320).

4. **Null pac_size handling**: Always check `pac_size.present?` before comparing to avoid nil errors.
