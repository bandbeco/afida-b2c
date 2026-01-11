# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Rails 8 e-commerce application for selling eco-friendly catering supplies. The application uses Vite for frontend asset bundling with TailwindCSS 4 and DaisyUI for styling, Hotwire (Turbo + Stimulus) for interactivity, Stripe for payments, and PostgreSQL as the database.

## Development Commands

### Initial Setup
```bash
bin/setup               # Install dependencies, setup database, and start server
bin/setup --skip-server # Setup without starting the server
```

### Running the Application
```bash
bin/dev                 # Start Rails server and Vite dev server (uses foreman)
rails server            # Run Rails server only (port 3000)
bin/vite dev            # Run Vite dev server only
```

### Database Commands
```bash
rails db:migrate        # Run pending migrations
rails db:seed           # Seed the database
rails db:prepare        # Create database if needed and run migrations
rails db:reset          # Drop, create, migrate, and seed database
```

### Testing
```bash
rails test              # Run all tests
rails test:system       # Run system tests (uses Capybara + Selenium)
rails test test/models/product_test.rb              # Run a specific test file
rails test test/models/product_test.rb:10           # Run specific test by line number
```

**⚠️ IMPORTANT: Always Use Fixtures in Tests**:
- **ALWAYS** use fixtures (`test/fixtures/*.yml`) instead of creating records manually with `Model.create!`
- Fixtures are loaded once per test run, making tests faster and more consistent
- Reference fixtures using the accessor methods: `users(:one)`, `products(:widget)`, `reorder_schedules(:active_monthly)`
- If a test needs specific data that doesn't exist in fixtures, **add it to the fixture file** rather than creating it inline
- Only modify fixture data within a test when testing specific behavior (e.g., `@user.update!(active: false)`)
- If fixture data interferes with what you're testing, modify it in the test setup rather than deleting fixtures with `delete_all`

**Bad (don't do this):**
```ruby
setup do
  ReorderSchedule.delete_all  # DON'T nuke fixtures
  @schedule = ReorderSchedule.create!(user: users(:one), ...)  # DON'T create inline
end
```

**Good (do this):**
```ruby
setup do
  @schedule = reorder_schedules(:active_monthly)  # USE fixtures
  @user = @schedule.user
end
```

### Code Quality
```bash
rubocop                 # Run RuboCop linter (uses rails-omakase config)
brakeman                # Run security vulnerability scanner
```

### Asset Management
Vite automatically compiles assets during development. For production builds:
```bash
bin/vite build          # Build assets for production
```

### Rails Console
```bash
rails console           # Open Rails console
rails c                 # Shorthand
```

## Architecture Overview

### Frontend Architecture (Vite + Rails)

**Asset Pipeline**: Uses Vite Rails instead of traditional Sprockets/Propshaft
- Entry points: `app/frontend/entrypoints/application.js` and `application.css`
- Assets organized in `app/frontend/` directory (images, fonts, stylesheets, javascript)
- Vite config: `vite.config.mts` with TailwindCSS 4 plugin and Rails integration
- Auto-reload on changes to routes and views

**JavaScript Stack**:
- Hotwire Turbo for SPA-like navigation
- Stimulus controllers for interactive components (`app/frontend/javascript/controllers/`)
  - 27 controllers total, key ones include:
  - `cart_drawer_controller.js` - Shopping cart drawer
  - `carousel_controller.js` - Swiper.js carousel integration
  - `product_options_controller.js` - Product option selection
  - `quick_add_modal_controller.js` - Quick add to cart modal
  - `branded_configurator_controller.js` - Branded product configuration
  - `sample_counter_controller.js` - Sample selection tracking
- Swiper for carousels
- Active Storage for file uploads

**⚠️ IMPORTANT: Registering Stimulus Controllers**:
When creating a new Stimulus controller, you MUST register it in `app/frontend/entrypoints/application.js`. Add it to the `lazyControllers` object:
```javascript
const lazyControllers = {
  // ... existing controllers
  "your-controller": () => import("../javascript/controllers/your_controller")
}
```
Controllers will NOT work if they are not registered. The lazy loading system automatically loads controllers when their `data-controller` attribute is detected in the DOM.

**Styling**:
- TailwindCSS 4 for utility-first styling
- DaisyUI component library for pre-built UI components
- Custom styles in `app/frontend/stylesheets/`
- Pattern backgrounds available via `patterns.css` (see Pattern Backgrounds section below)

### Backend Architecture

**Models**:
- `Product` - Main sellable entity, belongs to category, uses slugs for URLs
  - Has SKU, price, stock, pac_size, dimensions, photos
  - Default scope filters active products and orders by sort_order
  - Optionally belongs to `ProductFamily` for grouping related products
  - `ProductCompatibleLid` - Join table for cup/lid compatibility
- `ProductFamily` - Optional grouping mechanism for related products (e.g., "Single Wall Cups" family containing 8oz, 12oz, 16oz products)
  - Products in same family shown in "See Also" section
- `Category` - Organizes products
- `Cart` / `CartItem` - Shopping cart (supports both guest and user carts)
  - VAT calculation at 20% (UK)
  - Cart can belong to user or be guest cart
- `Order` / `OrderItem` - Completed purchases
  - Stores Stripe session ID
  - Captures shipping details from Stripe Checkout
- `User` / `Session` - Authentication (Rails 8 built-in authentication with bcrypt)
- `Address` - User saved delivery addresses (multiple per user, one default)
- `ReorderSchedule` / `ReorderScheduleItem` - Scheduled automatic reorders (items reference Product)
- `PendingOrder` - Orders awaiting customer confirmation before charging
- `Organization` - B2B customer organizations
- `Current` - ActiveSupport::CurrentAttributes for request-scoped state (user, session, cart)

**Controllers**:
- `PagesController` - Static pages (home, shop, branding, about, contact, terms, privacy, cookies, accessibility)
- `ProductsController` - Product listing and detail pages
- `CategoriesController` - Category pages
- `SamplesController` - Free sample selection pages
- `CartsController` / `CartItemsController` - Shopping cart management
- `CheckoutsController` - Stripe Checkout integration
  - Creates Stripe sessions with line items, shipping, and tax
  - Handles success callback to create orders
  - Uses `Current.cart` for cart state
- `OrdersController` - Order history and details
- `AccountsController` - User account management
- `Account::AddressesController` - Saved address CRUD
- `ReorderSchedulesController` - Scheduled reorder management
- `PendingOrdersController` - Pending order review and confirmation
- `BrandedProductsController` - Custom branded product configurator
- `BlogsController` / `FaqsController` - Content pages
- `Admin::ProductsController` - Admin product management
- `Admin::OrdersController` - Admin order management
- `Admin::BrandedOrdersController` - Admin branded order management
- `FeedsController` - Google Merchant feed generation

**Key Patterns**:
- Uses slugs for SEO-friendly URLs (`Product#to_param` returns slug)
- Products are the main sellable entity (not variants)
- Related products grouped via optional `ProductFamily` association
- Authentication uses Rails 8 built-in patterns with `allow_unauthenticated_access` macro
- Guest carts tracked by cookie, merged on user login
- VAT calculated on checkout (20% UK rate)
- Stripe Checkout for payment processing with shipping address collection

### Database Configuration

**Multi-database setup** for production (Solid Queue, Solid Cache, Solid Cable):
- Primary: Main application data (PostgreSQL)
- Cache: Solid Cache database
- Queue: Solid Queue for background jobs
- Cable: Solid Cable for Action Cable

Development uses single PostgreSQL database: `shop_development`

### Payment Flow (Stripe)

1. User clicks checkout → `CheckoutsController#create`
2. Creates Stripe Checkout Session with:
   - Line items from cart
   - UK VAT (20%) as tax rate
   - Shipping address collection (GB only)
   - Standard and Express shipping options
3. User completes payment on Stripe
4. Stripe redirects to `CheckoutsController#success` with session_id
5. Retrieves Stripe session, creates Order and OrderItems
6. Clears cart and sends confirmation email
7. Prevents duplicate orders by checking `stripe_session_id`

### Email Configuration

- Uses Mailgun gem for transactional emails
- `OrderMailer` - Order confirmation emails
- `RegistrationMailer` - Email verification
- `PasswordsMailer` - Password reset
- `ReorderMailer` - Scheduled reorder notifications (order ready, reminders)

### Third-Party Services

**Required credentials** (stored in Rails encrypted credentials):
- Stripe API keys (test and live)
- Mailgun API credentials
- AWS S3 credentials (for Active Storage in production)

Edit credentials:
```bash
rails credentials:edit
```

## Important File Locations

- Routes: `config/routes.rb`
- Database schema: `db/schema.rb`
- Vite entrypoints: `app/frontend/entrypoints/`
- Stimulus controllers: `app/frontend/javascript/controllers/`
- View components: `app/views/`
- Credentials: `config/credentials.yml.enc` (use `rails credentials:edit`)

## Development Tips

**Key Principles**:
- Only make changes that are directly requested. Keep solutions simple and focused.
- ALWAYS read and understand relevant files before proposing edits. Do not speculate about code you have not inspected.

### Working with Products
- `Product` is the main sellable entity with SKU, price, stock, and photos
- Products require a category and generate slugs automatically from name/SKU/colour
- Products can optionally belong to a `ProductFamily` for grouping
- Use `product.sibling_variants` to get related products in the same family
- Use `product.catalog_products` scope for public-facing product listings
- Price, stock, and pac_size are direct attributes on Product (no variants)

### Working with Product Descriptions

Products use a **three-tier description system** for contextual content display:

**Description Fields**:
- **`description_short`** (10-25 words) - Brief summary for product cards on browse pages
- **`description_standard`** (25-50 words) - Medium paragraph for product page intro (above fold)
- **`description_detailed`** (75-175 words) - Comprehensive content for product page main section (below fold)

**Fallback Helper Methods**:
```ruby
# Use these methods in views (they handle missing descriptions gracefully)
product.description_short_with_fallback    # Returns short, or truncates standard/detailed (15 words)
product.description_standard_with_fallback # Returns standard, or truncates detailed (35 words)
product.description_detailed_with_fallback # Returns detailed (no fallback needed)
```

**Where Each Description Appears**:
- **Short**: Product cards on shop page (`app/views/products/_card.html.erb`) and category pages (`app/views/products/_product.html.erb`)
- **Standard**: Product detail page intro above fold (`app/views/products/_standard_product.html.erb`)
- **Detailed**: Product detail page main content section with "Product Details" heading
- **SEO**: Meta descriptions and structured data use `description_standard_with_fallback`

**Admin Interface**:
- Three separate textarea fields in `app/views/admin/products/_form.html.erb`
- Real-time character counter with color-coded feedback (green/yellow/red)
- Target ranges shown in labels: Short (10-25), Standard (25-50), Detailed (75-175)
- Character counters powered by `character-counter` Stimulus controller

**Best Practices**:
- All three fields are optional (fallback logic handles missing values)
- Use `_with_fallback` methods in views (never access raw fields directly)
- Character count targets are soft recommendations, not hard limits
- CSV data in `lib/data/products.csv` provides template examples

### Working with Product Photos

Products support two photo types:
- **Product Photo** (`:product_photo`) - Close-up product shot
- **Lifestyle Photo** (`:lifestyle_photo`) - Staged in real-life context

Both photos are optional. Helper methods:
- `product.primary_photo` - Returns product_photo if present, else lifestyle_photo
- `product.photos` - Array of all attached photos
- `product.has_photos?` - Returns true if any photo attached

**Product Cards**: Display product_photo by default, hover shows lifestyle_photo (when both present)

**Admin**: Separate upload fields for each photo type

**Cart/Thumbnails**: Use `primary_photo` for smart fallback

### Working with Lid Compatibility

Lid compatibility matches cup products with compatible lid products using a **join table** (`product_compatible_lids`). This ensures accurate matching based on both **material type** (e.g., paper vs plastic) and **size**.

**Use Case**: Cup products define which lid products are compatible with them

**Database**:
- `product_compatible_lids` - Join table between products
  - `product_id` - The cup product
  - `compatible_lid_id` - The compatible lid product
  - `sort_order` - Display order (lower = shown first)
  - `default` - Whether this is the default/recommended lid
- Model: `ProductCompatibleLid`

**Admin Setup**:
1. Edit a cup product in the admin (e.g., "Single Wall Hot Cup")
2. Scroll to "Compatible Lids" section (visible for cup products only)
3. Add compatible lid products from the dropdown
4. Reorder lids by dragging (sort_order)
5. Set one lid as the default (recommended option)
6. Remove lids using the × button

**Helper Methods**:
```ruby
# Get all compatible lid products for a cup
compatible_lids_for_cup_product(cup_product)
# Returns: Array of lid Product objects

# Get matching lids for a specific cup product by size
matching_lids_for_cup_product(cup_product, size)
# Returns: Array of lid Product objects with matching size
```

**Configurator Integration**:
- Branded product configurator uses the join table
- Passes `product_id` + `size` to `/branded_products/compatible_lids`
- Backend filters by product compatibility (material type) THEN by size
- Shows only lids that match both criteria

**Architecture**:
- **Two-level matching**:
  1. Product level: Material type (hot cup → hot lid, cold cup → cold lid)
  2. Size matching: Filter by size option value (8oz cup → 8oz lid)
- **Cup-centric**: Cups define their compatible lids (not vice versa)
- **Flexible**: Easy to add new lids or change compatibility
- **Sortable & Defaultable**: Control display order and recommended option

**Rake Tasks**:
```bash
# Populate default compatibility relationships
rails lid_compatibility:populate

# View current compatibility matrix
rails lid_compatibility:report

# Clear all compatibility data
rails lid_compatibility:clear
```

### Pattern Backgrounds

Subtle repeating background patterns using product illustrations are available for adding visual interest to pages and sections.

**Files**:
- Pattern CSS: `app/frontend/stylesheets/patterns.css`
- Imported in: `app/frontend/entrypoints/application.css`

**Basic Usage**:
```html
<!-- Light grey background (default) -->
<div class="pattern-bg pattern-bg-grey">
  Your content here
</div>

<!-- White background -->
<div class="pattern-bg pattern-bg-white">
  Your content here
</div>

<!-- Apply to entire page -->
<body class="pattern-bg pattern-bg-grey">
  ...
</body>
```

**Available Color Variants**:
- `pattern-bg-grey` - Light grey (#f9fafb) - default
- `pattern-bg-white` - Pure white
- `pattern-bg-warm` - Warm grey (#fafaf9)
- `pattern-bg-cool` - Cool grey (#f8fafc)
- `pattern-bg-custom` - Use with CSS variable for custom color

**Custom Colors**:
```html
<div class="pattern-bg pattern-bg-custom"
     style="--pattern-bg-color: #e0f2fe;">
  Your content
</div>
```

**Opacity Variants**:
- Default: 6% opacity (subtle)
- `pattern-subtle` - Extra subtle (4% opacity)
- `pattern-visible` - More prominent (10% opacity)

**Combining Variants**:
```html
<!-- Extra subtle white background -->
<div class="pattern-bg pattern-subtle pattern-bg-white">
  ...
</div>

<!-- More visible grey background -->
<div class="pattern-bg pattern-visible pattern-bg-grey">
  ...
</div>
```

**Demo Page**:
Visit `/pattern-demo` in development to see all variants and usage examples.

**Pattern Content**:
- Includes all 10 product types (boxes, cups, pizza boxes, napkins, straws, etc.)
- Random positioning, rotation, and scaling for organic appearance
- SVG-based (scalable and crisp at any size)
- Embedded as data URI in CSS (no extra HTTP requests)

**Best Practices**:
- Use sparingly - pattern works best on hero sections or full-page backgrounds
- Choose subtle opacity for content-heavy sections
- Test readability with your content before deploying
- Consider using `pattern-bg-white` with borders for card-like elements

### Working with Cart
- Use `Current.cart` to access current user's cart
- Cart automatically handles guest vs authenticated users
- VAT calculated at `VAT_RATE` (0.2) - defined globally in `config/initializers/vat.rb`
- Cart methods: `items_count`, `subtotal_amount`, `vat_amount`, `total_amount`

### Working with Samples

Free product samples allow customers to try products before buying. Samples are available at `/samples`.

**Data Model**:
- `Product#sample_eligible` - Boolean flag marking products available as samples
- `Product#sample_sku` - Optional custom SKU for sample fulfillment (defaults to `SAMPLE-{sku}`)
- Samples are stored as `CartItem` records with `price = 0`
- **Mutual Exclusivity**: Same product CANNOT exist as both sample and regular item in cart

**Limits & Validation**:
- Maximum 5 samples per cart (`Cart::SAMPLE_LIMIT`)
- `CartItem` validates sample eligibility and limit at database level (race-condition safe)
- Only sample-eligible products can have price=0
- Uniqueness validated on `(cart_id, product_id)` - one entry per product

**Sample vs Regular Item Replacement**:
When adding items, the system enforces mutual exclusivity with asymmetric behavior:
- **Adding sample when regular exists**: No-op (validation error, regular item stays)
- **Adding regular when sample exists**: Sample is removed, regular item added
- Rationale: Customers who add to cart show purchase intent, which supersedes sample request

**Cart Methods**:
```ruby
cart.sample_items                      # Returns cart items with price = 0
cart.sample_count                      # Number of samples in cart
cart.sample_count_for_category(cat)    # Samples in specific category
cart.only_samples?                     # True if cart has only samples
cart.at_sample_limit?                  # True if 5+ samples
```

**Checkout Behavior**:
- Samples-only orders: Special £7.50 shipping rate
- Mixed orders: Samples ship free with regular items
- Order tracks `samples_only?` for fulfillment

**Admin Setup**:
1. Edit a product in admin
2. Check "Sample eligible" checkbox
3. Optionally set custom `sample_sku` for fulfillment tracking

### Scheduled Reorders

Customers can set up automatic recurring orders that are charged on a schedule.

**Data Model**:
- `ReorderSchedule` - The recurring schedule configuration
  - `user_id` - Owner of the schedule
  - `frequency` - Enum: `every_month`, `every_two_months`, `every_three_months`
  - `status` - Enum: `active`, `paused`, `cancelled`
  - `next_scheduled_date` - When the next order will be created
  - `stripe_payment_method_id` - Saved card for off-session charging
  - `card_brand`, `card_last4` - Display info for the saved card
- `ReorderScheduleItem` - Items in the schedule (product + quantity)
- `PendingOrder` - Created 3 days before charge date for customer review
  - `items_snapshot` - JSONB capturing prices at creation time
  - `status` - Enum: `pending`, `confirmed`, `expired`
  - Token-based access (no login required to review/confirm)

**Flow**:
1. User creates schedule from order confirmation page
2. `CreatePendingOrdersJob` runs daily, creates `PendingOrder` 3 days before `next_scheduled_date`
3. User receives email with link to review order
4. User clicks link → lands on review page (`PendingOrdersController#show`)
5. User clicks "Confirm & Pay" → charges card, creates order
6. If payment fails → shows `payment_failed.html.erb` with options to update card

**Token Authentication**:
Pending orders use Rails GlobalID signed tokens for secure, login-free access:
```ruby
pending_order.confirmation_token  # For show/confirm actions (7-day expiry)
pending_order.edit_token          # For edit/update actions (7-day expiry)
```

**Key Files**:
- `app/controllers/reorder_schedules_controller.rb` - Schedule CRUD
- `app/controllers/pending_orders_controller.rb` - Review and confirm pending orders
- `app/services/pending_order_confirmation_service.rb` - Handles payment and order creation
- `app/services/pending_order_snapshot_builder.rb` - Builds price snapshots
- `app/jobs/create_pending_orders_job.rb` - Daily job to create pending orders
- `app/mailers/reorder_mailer.rb` - Email notifications

**Routes**:
```
/reorder-schedules           # List user's schedules
/reorder-schedules/:id       # Show/edit schedule
/reorder-schedules/setup     # Create from order
/pending-orders/:id?token=x  # Review pending order
/pending-orders/:id/confirm  # Confirm and charge
/pending-orders/:id/edit     # Edit items before confirming
```

### User Addresses

Users can save multiple delivery addresses for faster checkout.

**Data Model**:
- `Address` belongs to `User`
- Fields: `nickname`, `recipient_name`, `company_name`, `line1`, `line2`, `city`, `postcode`, `country`, `phone`
- One address per user can be marked as `default`

**Checkout Integration**:
- If user has saved addresses, checkout shows address selector
- Selected address is synced to Stripe Customer for prefill
- User can also choose "Enter a different address" for one-time addresses

**Routes**:
```
/account/addresses           # List addresses
/account/addresses/new       # Add new address
/account/addresses/:id/edit  # Edit address
```

### Pricing Model (Pack vs Unit Pricing)

The application uses a unified pricing model where `subtotal = price × quantity` for all items, but the meaning of `quantity` differs by product type:

**Standard Products** (pack-priced):
- `quantity` = number of packs
- `price` = price per pack
- Example: 2 packs × £16.00/pack = £32.00

**Branded/Configured Products** (unit-priced):
- `quantity` = number of units
- `price` = price per unit
- Example: 5,000 units × £0.18/unit = £900.00

**Duck-typed Interface** (`CartItem`, `OrderItem`):
```ruby
item.pack_priced?  # true if standard product with pac_size > 1
item.pack_price    # price per pack (nil for unit-priced)
item.unit_price    # price per unit (derived from pack_price / pac_size for pack-priced)
item.pac_size      # units per pack
```

**PricingHelper** (`app/helpers/pricing_helper.rb`):
```ruby
# Use in views for consistent display
format_price_display(item)     # "£16.00 / pack" or "£0.1800 / unit"
format_quantity_display(item)  # "2 packs (1,000 units)" or "5,000 units"
```

**Historical Data Preservation**:
- `OrderItem` captures `pac_size` at order time
- This ensures order history displays correctly even if product pac_size changes later
- Always use `order_item.pac_size`, never `order_item.product.pac_size`

**Form Submissions**:
- Standard product forms submit pack count (not unit count)
- Stimulus controllers (`product_options_controller.js`, `compatible_lids_controller.js`) handle this
- Quantity select shows "X packs (Y units)" but submits X

### Authentication
- Uses Rails 8 authentication with Session model
- Allow public access with `allow_unauthenticated_access` in controllers
- Current user available via `Current.user`
- Session stored in encrypted cookie

### Admin Area
- Namespaced under `/admin`
- Manage products and product families
- View and manage orders
- Add authentication checks before deploying to production

### Testing Payments Locally
Use Stripe test mode card numbers:
- Success: `4242 4242 4242 4242`
- Requires authentication: `4000 0025 0000 3155`
- Declined: `4000 0000 0000 9995`

### Testing with Stripe API

Use `StripeTestHelper` for Stripe API mocking in tests:

```ruby
include StripeTestHelper

test "checkout creates order" do
  session = stub_stripe_session_retrieve(payment_status: "paid")
  # Your test code
end
```

**Available helpers:**
- `stub_stripe_session_create` - Stub session creation
- `stub_stripe_session_retrieve` - Stub session retrieval
- `stub_stripe_tax_rate_list` - Stub UK VAT rate lookup
- `stub_stripe_customer_create` - Stub customer creation
- `stub_stripe_customer_update` - Stub customer update
- `stub_stripe_customer_retrieve` - Stub customer retrieval
- `stub_stripe_payment_intent_create` - Stub payment intent creation
- `build_stripe_session` - Build a mock session without stubbing

**Customizing mock data:**
```ruby
# Override default values
session = stub_stripe_session_retrieve(
  payment_status: "paid",
  shipping_name: "John Doe",
  shipping_address: { line1: "123 Main St", city: "London", postal_code: "SW1A 1AA" }
)

# Test error scenarios
Stripe::Checkout::Session.stubs(:create).raises(StripeErrors.card_declined)
```

See `test/support/stripe_test_helper.rb` for full API.

### Google Merchant Feed
- Available at `/feeds/google-merchant.xml`
- Auto-generates product feed for Google Shopping
- Includes product data, pricing, images, and availability

## SEO Implementation

### Overview

Comprehensive SEO implementation with structured data, sitemaps, canonical URLs, and meta tags across all pages.

### Structured Data (JSON-LD)

**Available helpers** (`app/helpers/seo_helper.rb`):

```ruby
# Product structured data with Schema.org Product markup
product_structured_data(product)

# Organization structured data (Afida company info)
organization_structured_data

# Breadcrumb navigation structured data
breadcrumb_structured_data(items)

# Canonical URL tag
canonical_url(url = nil)
```

**Implemented on:**
- Product pages: Product + Breadcrumb structured data
- Branded product pages: Product (AggregateOffer) + Breadcrumb
- Category pages: CollectionPage + Breadcrumb
- All pages: Organization structured data (in head via footer partial)

### Sitemaps

**XML Sitemap:**
- Route: `/sitemap.xml`
- Controller: `SitemapsController`
- Service: `SitemapGeneratorService` (generates sitemap with priorities and change frequencies)
- Includes: Home, static pages, all categories, all products, FAQs

**Robots.txt:**
- Route: `/robots.txt` (dynamic controller)
- Controller: `RobotsController`
- Includes sitemap reference, allows all except `/admin/`, `/cart`, `/checkout`

### Meta Tags

**All pages include:**
- Title tag (via `content_for :title`)
- Meta description (via `content_for :meta_description`)
- Canonical URL (automatic via `application.html.erb`)

**Product and Category pages:**
- Use database fields `meta_title` and `meta_description` when present
- Fallback to generated values when blank
- Products: Falls back to "#{name} | #{category.name} | Afida"
- Categories: Uses `meta_title` and `meta_description` from database

**Home and important pages:**
- Open Graph tags (og:title, og:description, og:type, og:url)
- Twitter Card tags
- Custom optimized titles and descriptions

### SEO Validation

**Rake task:**
```bash
rails seo:validate
```

**What it checks:**
- Products missing custom meta_title or meta_description
- Categories missing meta_title or meta_description
- Displays summary of SEO coverage

### Testing

**System tests:**
- `test/system/seo_test.rb` - Canonical URLs on product/category pages
- `test/system/product_structured_data_test.rb` - Structured data on products
- `test/system/home_page_seo_test.rb` - Home page meta tags

**Integration tests:**
- `test/integration/comprehensive_seo_test.rb` - End-to-end SEO validation
- `test/integration/product_meta_tags_test.rb` - Database field fallback behavior

**Service tests:**
- `test/services/sitemap_generator_service_test.rb` - Sitemap XML generation

**Helper tests:**
- `test/helpers/seo_helper_test.rb` - Structured data helper methods

### Next Steps

After deploying SEO updates:
1. Run `rails seo:validate` to check coverage
2. Test sitemap at `yoursite.com/sitemap.xml`
3. Verify robots.txt at `yoursite.com/robots.txt`
4. Test structured data with [Google Rich Results Test](https://search.google.com/test/rich-results)
5. Submit sitemap to Google Search Console
6. Monitor search performance and rankings

### Configuration

**Required environment variables:**
- `APP_HOST` - Used by sitemap generator (e.g., "afida.com")
- Set to production domain in production environment

**Database fields:**
- Products: `meta_title`, `meta_description` (optional, with fallback)
- Categories: `meta_title`, `meta_description` (required)

## Active Technologies
- Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionDispatch), Rack middleware, PostgreSQL 14+ (001-legacy-url-redirects)
- PostgreSQL 14+ (primary database with `legacy_redirects` table using JSONB for variant parameters) (001-legacy-url-redirects)
- PostgreSQL 14+ (existing `products`, `categories`, `product_variants` tables) (003-shop-page-filters-search)
- Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionView, ActiveSupport), Vite Rails, Stimulus, TailwindCSS 4, DaisyUI (004-product-descriptions)
- PostgreSQL 14+ (existing products table, new columns: description_short, description_standard, description_detailed) (004-product-descriptions)
- Ruby 3.3.0+ / Rails 8.x + Vite Rails, Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI (005-quick-add-to-cart)
- PostgreSQL 14+ (existing `products`, `product_variants`, `carts`, `cart_items` tables) (005-quick-add-to-cart)
- Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionView), Hotwire (Turbo Frames + Stimulus), TailwindCSS 4, DaisyUI, Stripe Checkout (011-variant-samples)
- PostgreSQL 14+ (existing `products`, `product_variants`, `carts`, `cart_items`, `orders`, `order_items` tables) (011-variant-samples)
- Ruby 3.3.0+ / Rails 8.x + Vite Rails, TailwindCSS 4, DaisyUI, Hotwire (Turbo + Stimulus) (013-homepage-branding)
- N/A (no data changes - view-only feature) (013-homepage-branding)
- Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), Stripe Ruby SDK, TailwindCSS 4, DaisyUI (001-sign-up-accounts)
- PostgreSQL 14+ (existing `users`, `orders`, `order_items` tables) (001-sign-up-accounts)
- Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionController, ActionView), Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI, Stripe Ruby SDK (001-user-address-storage)
- PostgreSQL 14+ (new `addresses` table) (001-user-address-storage)
- Ruby 3.3.0+ / Rails 8.x + Rails 8, Hotwire (Turbo + Stimulus), Stripe Ruby SDK, TailwindCSS 4, DaisyUI (014-scheduled-reorder)
- PostgreSQL 14+ (3 new tables: `reorder_schedules`, `reorder_schedule_items`, `pending_orders`) (014-scheduled-reorder)
- Ruby 3.3.0+ / Rails 8.x, JavaScript ES6+ (Stimulus) + Rails 8 (ActiveRecord, ActionView), Vite Rails, Stimulus, TailwindCSS 4, DaisyUI (015-variant-selector)
- PostgreSQL 14+ (existing `products`, `product_variants` tables; new `pricing_tiers` JSONB column) (015-variant-selector)
- Ruby 3.3.0+ / Rails 8.x + Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI (001-reorder-schedule-conversion)
- PostgreSQL (existing `orders`, `order_items`, `reorder_schedules` tables - no schema changes) (001-reorder-schedule-conversion)
- Ruby 3.3.0+ / Rails 8.x + Rails ActiveRecord, PostgreSQL, Hotwire (Turbo + Stimulus), TailwindCSS 4, DaisyUI (001-option-value-labels)
- PostgreSQL 14+ (new `variant_option_values` join table) (001-option-value-labels)
- Ruby 3.4.7, Rails 8.1.1 + Turbo-Rails, Stimulus-Rails, Vite Rails 3.0, Pagy (pagination) (001-variant-pages)
- PostgreSQL 14+ (model restructure: ProductVariant → Product, Product → ProductFamily) (001-variant-pages)

## Recent Changes
- 001-legacy-url-redirects: Added Ruby 3.3.0+ / Rails 8.x + Rails 8 (ActiveRecord, ActionDispatch), Rack middleware, PostgreSQL 14+
