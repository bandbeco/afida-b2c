---
type: Guide
description: Codebase orientation for developers, covering data models, cart and checkout flows, authentication, and common tasks.
status: active
timestamp: 2026-07-29
---

# Developer Guide

This guide provides technical documentation for developers working on the Afida e-commerce application.

## Table of Contents

- [Data Models](#data-models)
- [Core Concepts](#core-concepts)
- [Working with Products](#working-with-products)
- [Shopping Cart Flow](#shopping-cart-flow)
- [Checkout & Orders](#checkout--orders)
- [Authentication](#authentication)
- [Common Tasks](#common-tasks)

## Data Models

### Product Hierarchy

```
Category
└── Product (base product, e.g., "Pizza Box - Kraft")
    └── ProductVariant (size options, e.g., "7 inch", "9 inch", "12 inch")
        ├── CartItem (in shopping carts)
        └── OrderItem (in completed orders)
```

### Key Relationships

**Products:**
```ruby
Product
  belongs_to :category
  has_many :variants (ProductVariant)
  has_many :active_variants (only active variants)
  has_one_attached :image
```

**Product Variants:**
```ruby
ProductVariant
  belongs_to :product
  has_many :cart_items
  has_many :order_items
  has_one_attached :image (optional, falls back to product image)

  # Delegates to product:
  # - category, description, meta_title, meta_description, colour
```

**Shopping Cart:**
```ruby
Cart
  belongs_to :user (optional, nil for guest carts)
  has_many :cart_items
  has_many :products (through cart_items)

CartItem
  belongs_to :cart
  belongs_to :product_variant
```

**Orders:**
```ruby
Order
  belongs_to :user (optional, nil for guest orders)
  has_many :order_items

  # Stores shipping details from Stripe Checkout
  # Stores Stripe session ID for reference

OrderItem
  belongs_to :order
  belongs_to :product_variant (optional, nullified if variant deleted)

  # Stores snapshot of product info at time of order
```

## Core Concepts

### Product Variants

**What are variants?**
- Different options of the same base product (sizes, volumes, pack sizes)
- Each variant has its own SKU, price, and stock level
- **Colors = separate products** (different item_group_id for Google Shopping)
- **Sizes = variants** (same item_group_id for Google Shopping)

**Example:**
```ruby
# This is ONE product with 5 variants
product = Product.find_by(name: "Pizza Box - Kraft")
product.variants # => [7", 9", 10", 12", 14"]

# This is a DIFFERENT product (different color)
product2 = Product.find_by(name: "Pizza Box - White")
product2.variants # => [7", 9", 10", 12", 14"]
```

### Default Scopes

**Important:** Many models have default scopes that filter results automatically.

```ruby
# Product default scope - only active products
Product.all                 # Only active products
Product.unscoped.all        # All products including inactive

# ProductVariant default scope - ordered by name
variant.product.variants           # All variants (ordered by name)
variant.product.active_variants    # Only active variants

# Always use active_variants in production code!
```

### Slugs for SEO

Products use slugs for SEO-friendly URLs:
```ruby
product.slug # => "pizza-box-kraft"
product_path(product) # => "/products/pizza-box-kraft"

# Slug generated from: SKU + name + colour
# Example: "PIZB" + "Pizza Box" + "Kraft" => "pizb-pizza-box-kraft"
```

### Current Attributes

The app uses `Current` (ActiveSupport::CurrentAttributes) for request-scoped state:

```ruby
Current.user        # Current logged-in user
Current.session     # Current session
Current.cart        # Current cart (guest or user)
```

These are set by `ApplicationController#set_current_request_details` on each request.

## Working with Products

### Creating Products with Variants

```ruby
# Create product
product = Product.create!(
  name: "Pizza Box - Kraft",
  description: "Eco-friendly pizza boxes",
  category: Category.find_by(name: "Packaging"),
  colour: "Kraft",
  base_sku: "PIZB",
  active: true
)

# Add variants
product.variants.create!(
  sku: "7PIZBKR",
  name: "7 inch",
  price: 15.99,
  active: true
)

product.variants.create!(
  sku: "9PIZBKR",
  name: "9 inch",
  price: 18.99,
  active: true
)
```

### Querying Products

```ruby
# Get all active products in a category
category = Category.find_by(slug: "packaging")
products = category.products # Uses default scope (active only)

# Get featured products
Product.featured

# Get specific product by slug
product = Product.find_by(slug: "pizza-box-kraft")

# Get product with variants preloaded
product = Product.includes(:active_variants).find_by(slug: "pizza-box-kraft")
```

### Working with Variants

```ruby
# Always use active_variants in production
product.active_variants.each do |variant|
  puts "#{variant.name}: £#{variant.price}"
end

# Get default variant (first active variant)
default = product.default_variant

# Get price range
price_range = product.price_range
# Returns: 15.99 (if all same price)
# Or: [15.99, 28.99] (if prices differ)

# Check variant stock
variant.in_stock? # Currently always true (stock tracking TODO)
```

## Shopping Cart Flow

### Guest vs User Carts

**Guest Cart:**
- Created when guest adds first item
- Tracked by `cart_id` stored in session cookie
- `user_id` is nil

**User Cart:**
- Created on first login or when guest cart is merged
- Associated with User record
- Accessible via `Current.cart`

### Cart Operations

**Adding items:**
```ruby
# In CartItemsController
def create
  cart = Current.cart
  variant = ProductVariant.find(params[:product_variant_id])

  # Find or create cart item
  cart_item = cart.cart_items.find_or_initialize_by(
    product_variant: variant
  )

  cart_item.quantity += params[:quantity].to_i
  cart_item.price = variant.price
  cart_item.save!
end
```

**Calculating totals:**
```ruby
cart = Current.cart

# Individual calculations
cart.items_count        # Total quantity
cart.subtotal_amount    # Sum before VAT
cart.vat_amount         # 20% UK VAT
cart.total_amount       # Subtotal + VAT

# Example output:
# items_count: 5
# subtotal_amount: 83.95
# vat_amount: 16.79
# total_amount: 100.74
```

### Cart Merging (on login)

When a user logs in with items in their guest cart:
```ruby
# In SessionsController or similar
def merge_guest_cart_with_user_cart
  guest_cart = Cart.find_by(id: session[:cart_id])
  return unless guest_cart

  user_cart = current_user.cart || current_user.create_cart!

  guest_cart.cart_items.each do |guest_item|
    user_item = user_cart.cart_items.find_or_initialize_by(
      product_variant: guest_item.product_variant
    )
    user_item.quantity += guest_item.quantity
    user_item.price = guest_item.price
    user_item.save!
  end

  guest_cart.destroy
  session[:cart_id] = user_cart.id
end
```

## Checkout & Orders

Two checkout modes share one session builder. Which one a customer gets is
decided by `OnsiteCheckout.enabled?(session)`: the `ONSITE_CHECKOUT` env flag
(read live on every call) is the global switch, and a per-session preview flag
lets you test the on-site mode in production before flipping it globally. Visit
any URL with `?onsite_checkout=1` to turn the preview on for your browser
session, `?onsite_checkout=0` to turn it back off (captured by
`ApplicationController#capture_onsite_checkout_preview`).

- **Hosted** (flag off): `CheckoutsController#create` builds a Checkout
  Session and redirects to `session.url`; Stripe's page collects everything.
- **On-site** (flag on): the same `#create` builds the session with
  `ui_mode: "custom"`, stashes `{client_secret, fingerprint, zone,
  created_at}` in the Rails session, and 303-redirects to `GET /checkout`,
  which renders the checkout page on afida.com. Stripe.js's checkout SDK
  (`app/frontend/javascript/controllers/onsite_checkout_controller.js`) binds
  the page to the session: Payment Element + Shipping Address Element, promo
  codes via `applyPromotionCode`, and a zone guard that compares the typed
  postcode's zone (via `GET /shipping_zone`) against the zone the order was
  priced for. `Checkout::CartFingerprint` invalidates the stash if the cart,
  postcode, or discount changed since `#create`; a stale or expired stash
  (Stripe sessions die at 24h) bounces to the cart.
  See `docs/superpowers/specs/2026-07-28-onsite-checkout-design.md` and
  `docs/adr/0001-onsite-checkout-on-checkout-sessions.md`.

### Session creation (`Checkout::SessionBuilder`)

All money math lives in the Stripe session, built by
`app/services/checkout/session_builder.rb`:

- **Line items** carry the products AND the delivery charge. Shipping rides as
  a taxed line item (not a `shipping_option`) so manual tax rates apply VAT to
  it; it is prepended so it lands in Stripe's first `line_items` page.
- **Shipping price** comes from `ShippingZone.for(delivery_postcode)`: the
  postcode captured on the cart page, resolved typed-field-first
  (`CheckoutsController#delivery_postcode_for`). `#create` refuses to build a
  session for an unknown or undeliverable destination. The priced zone is
  recorded in `metadata.shipping_zone`.
- **Discounts**: a session-carried welcome coupon id is resolved to its
  promotion code and applied via `discounts:`; with no code,
  `allow_promotion_codes` lets the customer type one (on Stripe's page in
  hosted mode, in the on-site promo control in custom mode). Samples-only
  carts refuse all discounts. An invalid coupon falls back to
  `allow_promotion_codes` and is reported via `Result#invalid_discount?`.
- **Mode params** (`ui_mode`/`return_url` vs `success_url`/`cancel_url`, and
  payment method types: hosted is card-only, custom adds Link with wallets
  inside the Payment Element) are isolated in `SessionBuilder#mode_params`;
  everything else is shared by construction. The parity test in
  `test/services/checkout/session_builder_test.rb` pins this.

### After payment

Both modes land on the same success URL with `?session_id=`:
`CheckoutsController#success` retrieves the session (expanding
`collected_information`, `line_items.data.price.product`, and
`payment_intent.payment_method`), guards against
the webhook's duplicate order, creates the order via `Checkout::OrderCreator`,
clears the cart, and sends confirmation emails plus the Telegram notification.
The `checkout.session.completed` webhook
(`app/controllers/webhooks/stripe_controller.rb`) is the fallback that creates
the order if the redirect never arrives. Zero-total orders complete with
`payment_status: "no_payment_required"`; every completion gate accepts both
statuses via `Checkout::COMPLETED_PAYMENT_STATUSES`.

## Authentication

### Rails 8 Built-in Auth

The app uses Rails 8's built-in authentication (bcrypt passwords, cookie-based sessions).

**Key components:**
- `User` model with `has_secure_password`
- `Session` model for tracking sessions
- Encrypted cookie storage
- `Current.user` for accessing current user

**Allowing public access:**
```ruby
class ProductsController < ApplicationController
  allow_unauthenticated_access # Allow guest access

  def index
    @products = Product.all
  end
end
```

**Requiring authentication:**
```ruby
class OrdersController < ApplicationController
  # No allow_unauthenticated_access - requires login

  def index
    @orders = Current.user.orders
  end
end
```

## Common Tasks

### Adding a New Product Attribute

1. **Create migration:**
```bash
rails g migration AddBrandToProducts brand:string
rails db:migrate
```

2. **Update model:**
```ruby
# app/models/product.rb
validates :brand, presence: true
```

3. **Update forms:**
```erb
<!-- app/views/admin/products/_form.html.erb -->
<%= form.text_field :brand %>
```

4. **Update strong params:**
```ruby
# app/controllers/admin/products_controller.rb
def product_params
  params.require(:product).permit(:name, :brand, ...)
end
```

### Adding a Custom Scope

```ruby
# app/models/product.rb
scope :in_stock, -> {
  joins(:active_variants).where("product_variants.stock_quantity > 0").distinct
}

scope :by_price_range, ->(min, max) {
  joins(:active_variants).where(product_variants: { price: min..max }).distinct
}

# Usage:
Product.in_stock
Product.by_price_range(10, 50)
```

### Customizing Google Merchant Feed

Edit `app/services/google_merchant_feed_generator.rb`:

```ruby
# Add brand
xml.tag! "g:brand", product.brand

# Add GTIN (barcode)
xml.tag! "g:gtin", variant.gtin if variant.gtin.present?

# Customize title
xml.title "#{product.name} - #{variant.name} - #{product.colour}"
```

### Running Background Jobs

The app uses Solid Queue for background jobs:

```ruby
# Create a job
class ProcessOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    # Process order...
  end
end

# Enqueue job
ProcessOrderJob.perform_later(order.id)

# Production: Solid Queue runs as a separate process
# Development: Jobs execute inline (no separate process needed)
```

## Testing

### Model Tests

```ruby
# test/models/product_test.rb
test "should generate slug from name and colour" do
  product = Product.new(
    name: "Pizza Box",
    colour: "Kraft",
    category: categories(:one)
  )
  product.valid?
  assert_equal "pizza-box-kraft", product.slug
end
```

### Controller Tests

```ruby
# test/controllers/products_controller_test.rb
test "should show product" do
  product = products(:one)
  get product_url(product)
  assert_response :success
  assert_select "h1", product.name
end
```

### System Tests

```ruby
# test/system/checkout_test.rb
test "completing checkout creates order" do
  visit root_path
  click_on "Add to Cart"
  click_on "Checkout"

  # Fill in Stripe checkout...
  # (Use Stripe test mode)

  assert_text "Order created successfully"
end
```

## Performance Tips

### N+1 Query Prevention

```ruby
# BAD: N+1 queries
@products = Product.all
@products.each do |product|
  product.active_variants.each do |variant|
    puts variant.name
  end
end

# GOOD: Eager load associations
@products = Product.includes(:active_variants).all
@products.each do |product|
  product.active_variants.each do |variant|
    puts variant.name
  end
end
```

### Caching

The app uses Solid Cache (database-backed cache):

```ruby
# Cache expensive operations
@featured_products = Rails.cache.fetch("featured_products", expires_in: 1.hour) do
  Product.featured.includes(:active_variants, :category).limit(8)
end

# Clear cache when products change
# app/models/product.rb
after_commit :clear_featured_cache

def clear_featured_cache
  Rails.cache.delete("featured_products") if featured?
end
```

## Additional Resources

- [Rails Guides](https://guides.rubyonrails.org/)
- [Stripe Ruby Docs](https://stripe.com/docs/api?lang=ruby)
- [Hotwire Handbook](https://hotwired.dev/)
- [TailwindCSS Docs](https://tailwindcss.com/docs)
- [DaisyUI Components](https://daisyui.com/components/)

## Getting Help

- Check the [README](../README.md) for setup and common issues
- Review [CLAUDE.md](../CLAUDE.md) for architecture overview
- Check the [PRD](prd.md) for business requirements
- Browse existing tests for usage examples

## Contributing

When adding features:
1. Write tests first (TDD)
2. Update relevant documentation
3. Run linter: `rubocop -A`
4. Ensure all tests pass: `rails test`
5. Update CHANGELOG (if exists)
