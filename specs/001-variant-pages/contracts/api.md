# API Contracts: Variant-Level Product Pages

**Date**: 2026-01-10
**Feature**: 001-variant-pages

## Overview

This document defines the HTTP endpoints for the variant-level product pages feature. All endpoints follow Rails conventions and return HTML (with Turbo Frame support) unless otherwise noted.

---

## Endpoints

### 1. Variant Page

**Show a single product variant**

```
GET /products/:slug
```

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| slug | string | Yes | URL-friendly variant identifier |

**Response:** HTML page with variant details

**Example:**
```
GET /products/8oz-single-wall-white-coffee-cups
```

**Response Content:**
- Variant photo, name, price, SKU
- Quantity selector
- Add to cart button
- Product details section
- "See also" related variants
- Breadcrumb navigation
- Structured data (JSON-LD)

**Error Responses:**

| Status | Condition |
|--------|-----------|
| 404 | Variant with slug not found |
| 404 | Variant exists but is inactive |

---

### 2. Shop Page (All Variants)

**List all product variants with filtering**

```
GET /shop
```

**Parameters (all optional):**

| Name | Type | Description |
|------|------|-------------|
| q | string | Search query |
| category | string | Category slug filter |
| size | string | Size option value filter |
| colour | string | Colour option value filter |
| material | string | Material option value filter |
| sort | string | Sort order (name_asc, name_desc, price_asc, price_desc) |

**Response:** HTML page with variant cards grid

**Example:**
```
GET /shop?category=cups-and-lids&size=8oz&sort=price_asc
```

**Turbo Frame Support:**
When requested with `Turbo-Frame: variants-grid` header, returns only the grid content for partial updates.

---

### 3. Category Page

**List variants in a specific category**

```
GET /categories/:slug
```

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| slug | string | Yes | Category slug |

Plus same optional filter params as shop page (excluding category).

**Response:** HTML page with variant cards for that category

**Example:**
```
GET /categories/cups-and-lids?size=12oz
```

---

### 4. Search Results (Header Dropdown)

**Search variants for header dropdown**

```
GET /search
```

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| q | string | Yes | Search query (min 2 chars) |

**Response:** HTML partial with top 5 matching variants

**Headers:**
- `Turbo-Frame: search-results` - Returns partial for dropdown

**Example:**
```
GET /search?q=8oz%20cup
```

**Response Content:**
- Up to 5 variant cards (compact format)
- "View all results" link to `/shop?q=...`
- "No results" message if empty

**Error Responses:**

| Status | Condition |
|--------|-----------|
| 200 | Query too short (returns empty state) |

---

### 5. Add to Cart (Existing, Updated)

**Add variant to cart**

```
POST /cart/cart_items
```

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cart_item[variant_sku] | string | Yes | Variant SKU |
| cart_item[quantity] | integer | Yes | Number of packs |

**Response:** Turbo Stream updating cart drawer

**Note:** This endpoint already exists. No changes needed.

---

## Filter Values Endpoint (Optional)

**Get available filter values**

If dynamic filter dropdowns are needed:

```
GET /shop/filters
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| category | string | Limit values to category |

**Response:** JSON with available filter values

```json
{
  "categories": [
    { "slug": "cups-and-lids", "name": "Cups & Lids", "count": 25 }
  ],
  "sizes": [
    { "value": "8oz", "label": "8oz", "count": 5 },
    { "value": "12oz", "label": "12oz", "count": 8 }
  ],
  "colours": [
    { "value": "white", "label": "White", "count": 15 },
    { "value": "kraft", "label": "Kraft", "count": 10 }
  ],
  "materials": [
    { "value": "single-wall", "label": "Single Wall", "count": 6 },
    { "value": "double-wall", "label": "Double Wall", "count": 4 }
  ]
}
```

**Note:** This endpoint is optional. Initial implementation can use static filter values derived from option types.

---

## URL Examples

| Action | URL |
|--------|-----|
| View 8oz white cup | `/products/8oz-single-wall-white-coffee-cups` |
| Shop all | `/shop` |
| Shop cups only | `/shop?category=cups-and-lids` |
| Shop 8oz cups | `/shop?category=cups-and-lids&size=8oz` |
| Search for "napkin" | `/shop?q=napkin` |
| Category page | `/categories/cups-and-lids` |
| Search dropdown | `/search?q=pizza` |

---

## Turbo Frames

| Frame ID | Location | Purpose |
|----------|----------|---------|
| `variants-grid` | Shop/Category pages | Product grid updates without full reload |
| `search-results` | Header | Search dropdown results |
| `cart-drawer` | Global | Cart updates (existing) |

---

## Route Configuration

```ruby
# config/routes.rb

# Search endpoint (before products to avoid slug collision)
get 'search', to: 'search#index'

# Variant pages (catches slug-based URLs)
get 'products/:slug', to: 'product_variants#show', as: :product_variant

# Shop page with filtering
get 'shop', to: 'products#index', as: :shop
get 'shop/filters', to: 'products#filters', as: :shop_filters  # Optional

# Category pages (existing)
resources :categories, only: [:show], param: :slug
```
