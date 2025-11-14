# API Contract: Shop Page Endpoint

**Feature**: Shop Page - Product Listing with Filters and Search
**Branch**: `003-shop-page-filters-search`
**Date**: 2025-01-14

## Overview

This document defines the HTTP API contract for the shop page endpoint. The shop page is a server-rendered HTML page with Turbo Frame support for dynamic filtering.

---

## Endpoint: GET /shop

**Purpose**: Display all products with optional filtering, search, and sorting

**Route**: `GET /shop`

**Controller**: `PagesController#shop`

**Authentication**: None (public endpoint)

**Content Types**:
- Initial load: `text/html` (full page)
- Turbo Frame requests: `text/html` (partial content, Turbo Frame only)

---

## Request Parameters

All parameters are **optional** and passed via query string:

| Parameter | Type | Required | Default | Description | Validation |
|-----------|------|----------|---------|-------------|------------|
| `category_id` | Integer | No | `nil` | Filter by category ID | Must be valid category ID or omitted |
| `q` | String | No | `nil` | Search query (name/SKU/colour) | Max 100 characters, sanitized for SQL |
| `sort` | String | No | `"relevance"` | Sort option | Must be one of: `relevance`, `price_asc`, `price_desc`, `name_asc` |
| `page` | Integer | No | `1` | Page number for pagination | Must be >= 1 |

---

## Response Format

### Success Response (200 OK)

**Initial Page Load** (no Turbo Frame header):

```html
<!DOCTYPE html>
<html>
<head>
  <title>Shop Eco-Friendly Catering Supplies | Afida</title>
  <link rel="canonical" href="https://afida.co.uk/shop">
  <meta name="description" content="Browse our complete range...">
</head>
<body>
  <!-- Header, Navigation -->

  <div class="container">
    <h1>Shop All Products</h1>

    <!-- Filter Sidebar (outside Turbo Frame) -->
    <aside class="filters">
      <form data-turbo-frame="products" data-turbo-action="replace">
        <!-- Category Filter -->
        <fieldset>
          <legend>Category</legend>
          <label>
            <input type="radio" name="category_id" value="">
            All Products (50)
          </label>
          <label>
            <input type="radio" name="category_id" value="1">
            Pizza Boxes (12)
          </label>
          <!-- More categories... -->
        </fieldset>

        <!-- Search Input -->
        <input type="search" name="q" placeholder="Search products..."
               data-controller="search" data-action="input->search#debounce">

        <!-- Sort Dropdown -->
        <select name="sort" data-action="change->form#submit">
          <option value="relevance">Relevance</option>
          <option value="price_asc">Price: Low to High</option>
          <option value="price_desc">Price: High to Low</option>
          <option value="name_asc">Name: A-Z</option>
        </select>
      </form>
    </aside>

    <!-- Product Grid (inside Turbo Frame) -->
    <turbo-frame id="products" data-turbo-action="replace">
      <div class="product-grid">
        <!-- Product Card 1 -->
        <div class="product-card">
          <a href="/products/pizza-box-kraft">
            <img src="..." alt="Pizza Box Kraft">
            <h3>Pizza Box Kraft</h3>
            <p>Pizza Boxes</p>
            <p>From £0.50 - £1.20</p>
          </a>
        </div>
        <!-- More product cards... -->
      </div>

      <!-- Pagination -->
      <nav class="pagination">
        <a href="/shop?page=1">1</a>
        <a href="/shop?page=2">2</a>
        <!-- More page links... -->
      </nav>
    </turbo-frame>
  </div>

  <!-- Footer -->
</body>
</html>
```

**Turbo Frame Response** (when `Turbo-Frame: products` header present):

```html
<turbo-frame id="products" data-turbo-action="replace">
  <div class="product-grid">
    <!-- Product cards (only matching filter criteria) -->
  </div>

  <!-- Pagination (updated for current filter state) -->
  <nav class="pagination">
    <a href="/shop?category_id=1&q=pizza&sort=price_asc&page=1">1</a>
    <a href="/shop?category_id=1&q=pizza&sort=price_asc&page=2">2</a>
  </nav>
</turbo-frame>
```

---

## Example Requests

### 1. Initial Page Load (All Products)

**Request**:
```
GET /shop HTTP/1.1
Host: afida.co.uk
Accept: text/html
```

**Response**:
```
200 OK
Content-Type: text/html

<!-- Full HTML page with all products (page 1) -->
```

---

### 2. Filter by Category

**Request**:
```
GET /shop?category_id=3 HTTP/1.1
Host: afida.co.uk
Accept: text/html
Turbo-Frame: products
```

**Response**:
```
200 OK
Content-Type: text/html

<turbo-frame id="products">
  <!-- Only products in category ID 3 -->
</turbo-frame>
```

---

### 3. Search Products

**Request**:
```
GET /shop?q=pizza HTTP/1.1
Host: afida.co.uk
Accept: text/html
Turbo-Frame: products
```

**Response**:
```
200 OK
Content-Type: text/html

<turbo-frame id="products">
  <!-- Products matching "pizza" in name/SKU/colour -->
</turbo-frame>
```

---

### 4. Combined Filters (Category + Search + Sort)

**Request**:
```
GET /shop?category_id=3&q=8oz&sort=price_asc&page=1 HTTP/1.1
Host: afida.co.uk
Accept: text/html
Turbo-Frame: products
```

**Response**:
```
200 OK
Content-Type: text/html

<turbo-frame id="products">
  <!-- Products in category 3, matching "8oz", sorted by price ascending, page 1 -->
</turbo-frame>
```

---

### 5. Pagination

**Request**:
```
GET /shop?page=2 HTTP/1.1
Host: afida.co.uk
Accept: text/html
Turbo-Frame: products
```

**Response**:
```
200 OK
Content-Type: text/html

<turbo-frame id="products">
  <!-- Products 25-48 (page 2 of 24 per page) -->
</turbo-frame>
```

---

## Error Responses

### Invalid Category ID (404 Not Found)

**Request**:
```
GET /shop?category_id=999
```

**Response**:
```
200 OK
Content-Type: text/html

<!-- Page loads normally, but shows "No products found" message -->
<!-- Does NOT return 404 - gracefully handles invalid filters -->
```

**Rationale**: Invalid filters return empty results, not errors. User can clear filter to recover.

---

### Invalid Sort Parameter (Ignored)

**Request**:
```
GET /shop?sort=invalid_sort
```

**Response**:
```
200 OK
Content-Type: text/html

<!-- Falls back to default sort (relevance) -->
<!-- Does NOT return error - uses safe default -->
```

**Rationale**: Invalid params are ignored, defaults applied. Better UX than error messages.

---

### Invalid Page Number (Handled by Pagy)

**Request**:
```
GET /shop?page=999
```

**Response**:
```
200 OK
Content-Type: text/html

<!-- Shows last valid page (Pagy overflow handling) -->
<!-- OR shows "No products found" if no pages exist -->
```

**Rationale**: Pagy gem handles overflow gracefully (configurable behavior).

---

## Response Data Contract

### Product Card Data

Each product card in the grid contains:

| Field | Type | Source | Example |
|-------|------|--------|---------|
| Product Name | String | `product.name` | "Pizza Box Kraft" |
| Category | String | `product.category.name` | "Pizza Boxes" |
| Photo | Image URL | `product.primary_photo` | "/rails/active_storage/blobs/..." |
| Price Range | String | Calculated from `product.active_variants` | "From £0.50 - £1.20" |
| Detail Link | URL | `product_path(product.slug)` | "/products/pizza-box-kraft" |

**Price Display Logic**:
- Single variant: `"£#{price}"`
- Multiple variants (same price): `"£#{price}"`
- Multiple variants (different prices): `"From £#{min} - £#{max}"`

---

### Empty State

When no products match filters:

```html
<turbo-frame id="products">
  <div class="empty-state">
    <p>No products found matching your search.</p>
    <a href="/shop" class="btn">Clear Filters</a>
  </div>
</turbo-frame>
```

---

## Controller Implementation Contract

### PagesController#shop

**Responsibilities**:
1. Parse and sanitize query parameters
2. Apply filters/search/sort to Product model
3. Paginate results using Pagy
4. Eager load associations to prevent N+1 queries
5. Render full page or Turbo Frame based on request headers

**Pseudo-code**:
```ruby
def shop
  @categories = Category.all.order(:position)

  @products = Product
    .includes(:category, :active_variants,
              product_photo_attachment: :blob,
              lifestyle_photo_attachment: :blob)
    .in_category(params[:category_id])
    .search(params[:q])
    .sorted(params[:sort])

  @pagy, @products = pagy(@products, items: 24)

  # Turbo Frame requests render only the frame content
  if turbo_frame_request?
    render partial: 'products_frame', locals: { products: @products, pagy: @pagy }
  else
    # Full page render includes layout
    render :shop
  end
end
```

---

## URL State Contract

**All filter state is persisted in URL query parameters** to support:
- Bookmarking filtered views
- Sharing filtered links
- Browser back/forward navigation
- SEO crawlability (search engines can index filtered pages)

**URL Examples**:
```
/shop                                  # All products
/shop?category_id=3                    # Category filter
/shop?q=pizza                          # Search
/shop?sort=price_asc                   # Sort
/shop?category_id=3&q=8oz&sort=name_asc&page=2  # Combined filters
```

**URL Update Mechanism**:
- Turbo Frame with `data-turbo-action="replace"` updates browser URL
- No JavaScript required - Turbo handles URL updates
- Fallback: Form submission (POST converted to GET) updates URL naturally

---

## Performance Contract

**Query Performance**:
- Maximum 5 database queries per request (with eager loading)
- Page load < 2 seconds for 50+ products
- Filter update < 500ms (Turbo Frame only)

**Database Queries** (with eager loading):
1. Load categories for filter sidebar: `SELECT * FROM categories ORDER BY position`
2. Load products with filters: `SELECT * FROM products WHERE ... LIMIT 24 OFFSET 0`
3. Eager load categories: `SELECT * FROM categories WHERE id IN (...)`
4. Eager load variants: `SELECT * FROM product_variants WHERE product_id IN (...) AND active = true`
5. Eager load photos: `SELECT * FROM active_storage_attachments WHERE ...`

**Without Eager Loading** (N+1 problem):
- 1 + 24 + 24 + 24 = **73 queries** for 24 products ❌

**With Eager Loading**:
- **5 queries** regardless of product count ✅

---

## SEO Contract

**Meta Tags**:
- Title: `"Shop Eco-Friendly Catering Supplies | Afida"`
- Description: `"Browse our complete range of eco-friendly catering supplies..."`
- Canonical URL: `https://afida.co.uk/shop` (always points to base /shop URL)

**Filter State in Title** (optional enhancement):
- With category filter: `"Cups - Shop | Afida"`
- With search: `"Search: pizza - Shop | Afida"`

**Structured Data**:
- Organization schema (site-wide)
- Breadcrumb schema: `Home > Shop`
- No Product schema on listing page (reserved for detail pages)

**Robots**:
- Allow indexing of base /shop page
- Consider noindex on filtered pages (avoid duplicate content)
- OR use canonical URL to consolidate SEO value

---

## Accessibility Contract

**ARIA Labels**:
- Search input: `aria-label="Search products"`
- Filter form: `<form role="search">`
- Product grid: `role="list"` with `role="listitem"` on cards
- Pagination: `<nav aria-label="Pagination">`

**Keyboard Navigation**:
- All filters accessible via keyboard (radio buttons, search input, select dropdown)
- Pagination links keyboard-accessible
- Product cards are links (keyboard-accessible)

**Screen Reader Support**:
- Empty state announces "No products found"
- Page number announced: "Page 2 of 5"
- Filter updates announce result count: "Showing 12 products"

---

## Browser Compatibility

**Supported Browsers**:
- Chrome 90+ (Turbo Frame support)
- Firefox 88+ (Turbo Frame support)
- Safari 14+ (Turbo Frame support)
- Edge 90+ (Turbo Frame support)

**Graceful Degradation**:
- Without JavaScript: Form submissions work via full page reload
- Without Turbo: Filters work via standard form POST (converted to GET)
- Without CSS: Semantic HTML ensures readable content

---

## Summary

**Endpoint**: `GET /shop`

**Request Params**: `category_id`, `q`, `sort`, `page` (all optional)

**Response**: HTML (full page or Turbo Frame)

**Performance**: Max 5 queries, < 2s page load, < 500ms filter update

**SEO**: Server-side rendering, canonical URLs, meta tags

**Accessibility**: ARIA labels, keyboard navigation, screen reader support

All API contracts are complete. Ready to proceed to quickstart documentation.
