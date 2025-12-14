# B2B Price List Feature

## Overview

A dedicated `/price-list` page that serves as both a research tool (view, filter, export) and a rapid ordering interface (add to cart directly). Positioned prominently in main navigation.

## Problem

Afida's B2B customers are business owners who value their time. The current e-commerce experience (browse cards → product pages → configure → cart) works well for discovery, but repeat buyers and procurement teams often just want a no-nonsense price table they can scan quickly, export to Excel/PDF for approvals, and order from directly.

## Design Decisions

### Placement
- **Prominent navigation link** — "Price List" in main nav as a first-class way to browse
- Rationale: Signals transparency and efficiency. Product pages remain available for those wanting detail.

### Target Users
- Repeat customers (quick reorders)
- New business prospects (comparing against competitors)
- Procurement teams (sharing pricing for approval)

### Data Structure
- **Flat table, one row per variant** — Every SKU gets its own row
- Strong filters allow narrowing down without complex grouped UI
- Exports cleanly to Excel (no merged cells)

## Page Layout

### Header Section
- Title: "Price List"
- Subtitle: "All prices exclude VAT. Free UK delivery on orders over £100."
- Export buttons: "Download Excel" | "Download PDF"

### Filter Bar (Dropdowns)
- Category (All, Cups & Lids, Napkins, Straws, etc.)
- Material (All, Paper, Bamboo, Bagasse, etc.)
- Size (All, 8oz, 12oz, etc.) — dynamically populated based on category
- Search box for product name/SKU
- "Clear filters" link

Single-select dropdowns — multi-select not needed for this catalog size.

### Table Columns

| Product | SKU | Size | Material | Pack Size | Price/Pack | Price/Unit | Qty | |
|---------|-----|------|----------|-----------|------------|------------|-----|------|
| Double Wall Hot Cups | 12-DWC-W | 12oz | Paper | 500 | £40.81 | £0.082 | [1▾] | [Add] |

**Behaviours:**
- Sortable by clicking column headers (Product, Price/Pack, Price/Unit)
- Filters apply instantly via Turbo Frame (no full page reload)
- Product name links to full product page for those wanting detail
- Quantity: dropdown with values 1, 2, 3, 5, 10 (pack quantities)

### Add to Cart
- "Add" button triggers `CartItemsController#create`
- Cart drawer opens (same pattern as rest of site)
- If product already in cart: increment quantity (no duplicates)
- No stock validation (inventory not tracked)

### Mobile Experience
- Simplified table showing key columns only: Product, Size, Price/Pack, Qty, Add
- Full columns available via export or desktop view
- Maintains "price list" mental model (still a table, not cards)

## Export Functionality

### Excel (.xlsx)
- Same columns as table
- Respects current filters (export what you see)
- Filename: `afida-price-list-2025-12-12.xlsx` (or `afida-{category}-2025-12-12.xlsx` if filtered)

### PDF
- Clean printable A4 landscape format
- Afida branding (logo, contact info in header)
- Same data as Excel
- Respects current filters

### Technical Approach
- Excel: `caxlsx` gem
- PDF: `prawn` gem

## Out of Scope (v1)

- Customer-specific / wholesale pricing (one price list for everyone)
- Bulk quote request feature (use email for large orders)
- Saved lists / reorder templates
- Price history / price drop notifications

## Technical Implementation

### New Files
- `app/controllers/price_list_controller.rb`
- `app/views/price_list/index.html.erb`
- `app/views/price_list/_row.html.erb`

### Routes
```ruby
get "price-list", to: "price_list#index"
get "price-list/export", to: "price_list#export"
```

### Dependencies
- `caxlsx` gem (Excel export)
- `prawn` gem (PDF export)

### Leverages Existing
- `CartItemsController#create` for add-to-cart
- `Product` / `ProductVariant` models and scopes
- Cart drawer Stimulus controller
- Current.cart for session handling
