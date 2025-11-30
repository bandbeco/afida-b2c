# API Contracts: Sample Pack Feature

**Date**: 2025-11-30

## Overview

No new API endpoints required. The sample pack feature uses existing endpoints with modified behavior.

## Modified Endpoints

### POST /cart_items

**Existing endpoint** with added guard clause for sample pack.

**New Behavior**:
- If product is sample pack AND cart already has sample pack:
  - Redirect back with flash: "Sample pack already in your cart"
  - HTTP 302 redirect

**Request** (unchanged):
```
POST /cart_items
Content-Type: application/x-www-form-urlencoded

product_variant_id=123&quantity=1
```

**Response when sample pack already in cart**:
```
HTTP/1.1 302 Found
Location: [previous page or /cart]
Set-Cookie: flash[notice]="Sample pack already in your cart"
```

### GET /samples

**Existing route**, updated controller action.

**Response**: HTML page with sample pack product data embedded.

**Data loaded**:
```ruby
@sample_pack = Product.unscoped.find_by(slug: "sample-pack")
@variant = @sample_pack&.default_variant
```

### GET /products/:slug

**Existing endpoint**, works unchanged for sample pack.

**Special rendering for sample pack**:
- Quantity selector hidden
- Price displays "Free — just pay shipping"

## Unchanged Endpoints

The following endpoints work unchanged:

- `GET /shop` — Uses `shoppable` scope (excludes sample pack)
- `GET /cart` — Displays sample pack as "Free"
- `POST /checkouts` — Processes sample pack as £0.00 line item
- `GET /checkouts/success` — Creates order with sample pack item

## Internal Contracts

### Product.sample_pack?

```ruby
# Input: none (instance method)
# Output: boolean

product.sample_pack?
# => true if slug == "sample-pack"
# => false otherwise
```

### Cart.has_sample_pack?

```ruby
# Input: none (instance method)
# Output: boolean

cart.has_sample_pack?
# => true if any cart_item's product has slug "sample-pack"
# => false otherwise
```

### Product.shoppable (scope)

```ruby
# Input: none (class method/scope)
# Output: ActiveRecord::Relation

Product.shoppable
# => Products where:
#    - product_type IN ("standard", "customizable_template")
#    - slug != "sample-pack"
```
