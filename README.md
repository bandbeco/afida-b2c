# Afida E-Commerce Shop

A modern Rails 8 e-commerce application for selling eco-friendly catering supplies with product variants, Stripe payments, and Google Shopping integration.

## Features

- **Product Management** with variants (size, volume, pack size)
- **Shopping Cart** with VAT calculation (UK 20%)
- **Stripe Checkout** integration with shipping options
- **User Authentication** using Rails 8 built-in auth
- **Order Management** with email notifications
- **Google Merchant** feed for Google Shopping
- **Admin Interface** for product and order management
- **Responsive Design** with TailwindCSS 4 and DaisyUI
- **Modern Frontend** with Vite, Turbo, and Stimulus

## Tech Stack

- **Backend**: Rails 8.0, PostgreSQL
- **Frontend**: Vite, TailwindCSS 4, DaisyUI, Hotwire (Turbo + Stimulus)
- **Payments**: Stripe Checkout
- **Email**: Mailgun
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **Storage**: Active Storage (local dev, S3 production)

## Quick Start

### Prerequisites

- Ruby 3.3.0+
- PostgreSQL 14+
- Node.js 18+
- Yarn or npm

### Installation

1. **Clone the repository**
   ```bash
   git clone git@github.com:bandbeco/afida-b2c.git
   cd afida-b2c
   ```

2. **Install dependencies**
   ```bash
   bin/setup
   ```

   This will:
   - Install Ruby gems
   - Install JavaScript packages
   - Create and setup database
   - Seed initial data
   - Start the development server

3. **Manual setup** (if you prefer)
   ```bash
   bundle install
   yarn install
   rails db:create db:migrate db:seed
   ```

### Running the Application

**Development server** (recommended):
```bash
bin/dev
```
This starts both Rails server (port 3000) and Vite dev server using Foreman.

**Or run servers separately**:
```bash
# Terminal 1
rails server

# Terminal 2
bin/vite dev
```

Visit: http://localhost:3000

## Configuration

### Required Credentials

Edit encrypted credentials:
```bash
rails credentials:edit
```

Add the following:
```yaml
stripe:
  publishable_key: pk_test_...
  secret_key: sk_test_...
  webhook_secret: whsec_...

mailgun:
  api_key: key-...
  domain: mg.yourdomain.com

aws:
  access_key_id: AKIA...
  secret_access_key: ...
  region: eu-west-2
  bucket: your-bucket-name
```

### Environment Variables

Create `.env` for local overrides:
```bash
DATABASE_URL=postgresql://localhost/shop_development
REDIS_URL=redis://localhost:6379/0
RAILS_MAX_THREADS=5
```

## Database

### Schema Overview

**Products & Variants**:
- `products` - Base products with name, description, category
- `product_variants` - SKUs with price, stock for each product option
- `categories` - Product categories

**Shopping & Orders**:
- `carts` / `cart_items` - Shopping cart (guest or user)
- `orders` / `order_items` - Completed purchases
- Stripe session IDs stored for payment tracking

**Authentication**:
- `users` - Customer accounts with bcrypt password
- `sessions` - Encrypted cookie-based sessions

### Migrations

```bash
rails db:migrate              # Run pending migrations
rails db:rollback             # Rollback last migration
rails db:seed                 # Seed database
rails db:reset                # Drop, create, migrate, seed
```

### Product Variants

Products use a variant system where:
- **Colors** = separate products (different item_group_id)
- **Sizes/volumes** = variants of same product (same item_group_id)

See [docs/variant_migration_guide.md](docs/variant_migration_guide.md) for migration details.

## Product Configuration System

This application supports two types of products:

### Standard Products
Products with configurable options (size, color, material) that generate variants automatically.

### Customizable/Branded Products
B2B custom packaging with:
- Interactive configurator (BrandYour-inspired)
- Design file uploads
- Quantity-based pricing tiers
- Organization product instances for reordering

See [docs/BRANDED_PRODUCTS.md](docs/BRANDED_PRODUCTS.md) for detailed documentation.

## Testing

### Run Tests

```bash
rails test                    # Run all tests
rails test:system             # Run system tests
rails test test/models/       # Run model tests only
```

### Test Coverage

Key areas tested:
- Product and variant associations
- Cart calculations (VAT, totals)
- Order creation from cart
- User authentication

## Development

### Code Quality

```bash
rubocop                       # Run linter (rails-omakase config)
rubocop -A                    # Auto-fix issues
brakeman                      # Security scanner
```

### Frontend Development

**Assets location**:
- Entrypoints: `app/frontend/entrypoints/`
- JavaScript: `app/frontend/javascript/`
- Stylesheets: `app/frontend/stylesheets/`
- Images: `app/frontend/images/`

**Stimulus controllers**:
- `carousel_controller.js` - Swiper carousel
- `cart_drawer_controller.js` - Shopping cart drawer

**Vite configuration**: `vite.config.mts`

### Key Rails Patterns

**Current attributes** (`app/models/current.rb`):
```ruby
Current.user        # Current logged-in user
Current.session     # Current session
Current.cart        # Current cart (guest or user)
```

**Product URLs**:
Products use slugs for SEO-friendly URLs via `to_param` override.

**Scopes**:
```ruby
Product.all              # Only active products (default scope)
Product.featured         # Featured products
product.active_variants  # Only active variants
```

## Admin

Access admin at: http://localhost:3000/admin

**Features**:
- Product management (CRUD with variants)
- Order management (view, update status)

**TODO**: Add admin authentication before production deployment!

## Payments (Stripe)

### Test Mode

Use Stripe test cards:
- Success: `4242 4242 4242 4242`
- Requires 3D Secure: `4000 0025 0000 3155`
- Declined: `4000 0000 0000 9995`

### Checkout Flow

1. User clicks checkout → Creates Stripe session
2. Redirects to Stripe Checkout (collects payment + shipping)
3. Returns to success page → Creates Order
4. Sends confirmation email

**Shipping options**:
- Standard (5-7 days): £4.99
- Express (1-2 days): £9.99

**Tax**: 20% UK VAT added automatically

## Google Shopping

### Product Feed

Feed URL: `https://yourdomain.com/feeds/google-merchant.xml`

Setup guide: [docs/google_merchant_setup.md](docs/google_merchant_setup.md)

### Feed Structure

- Each variant has unique SKU as `id`
- Variants share `item_group_id` (based on product base_sku)
- Includes: title, price, availability, link, image

## Deployment

### Production Checklist

- [ ] Set `RAILS_ENV=production`
- [ ] Configure production database
- [ ] Add production credentials (Stripe live keys, AWS, etc.)
- [ ] Configure SMTP for email (Mailgun production)
- [ ] Add admin authentication
- [ ] Set up SSL/HTTPS
- [ ] Configure DNS for domain
- [ ] Run asset precompilation: `bin/vite build`
- [ ] Run migrations: `rails db:migrate`
- [ ] Set up background job processor (Solid Queue)
- [ ] Configure monitoring (error tracking, uptime)

### Asset Compilation

```bash
bin/vite build
rails assets:precompile  # If using Sprockets for any assets
```

## Project Documentation

- [CLAUDE.md](CLAUDE.md) - Guide for Claude Code
- [docs/prd.md](docs/prd.md) - Product Requirements Document
- [docs/tasks.md](docs/tasks.md) - Development task list
- [docs/google_merchant_setup.md](docs/google_merchant_setup.md) - Google Shopping setup
- [docs/variant_migration_guide.md](docs/variant_migration_guide.md) - Variant system migration
- [docs/BRANDED_PRODUCTS.md](docs/BRANDED_PRODUCTS.md) - Branded products system documentation

## Troubleshooting

### Common Issues

**Database connection error**:
```bash
# Check PostgreSQL is running
brew services list

# Restart PostgreSQL
brew services restart postgresql
```

**Vite not compiling assets**:
```bash
# Kill existing Vite process
pkill -f vite

# Clear Vite cache
rm -rf node_modules/.vite

# Restart dev server
bin/dev
```

**Stripe webhook errors (production)**:
- Verify webhook secret in credentials matches Stripe dashboard
- Check webhook endpoint is publicly accessible
- Test with Stripe CLI: `stripe listen --forward-to localhost:3000/webhooks/stripe`

**Missing variant images**:
Products inherit from parent product. Ensure product has attached image.

## Contributing

1. Create feature branch from `main`
2. Make changes with tests
3. Run test suite: `rails test`
4. Run linter: `rubocop`
5. Submit pull request

## License

All rights reserved.