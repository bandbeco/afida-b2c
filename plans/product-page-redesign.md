# Product Page Redesign Plan

## Overview

Redesign the product detail page (`_standard_product.html.erb`) to remove the card wrapper and create a cleaner, more modern layout that balances "clean & minimal" aesthetics with "practical & functional" B2B usability.

## Design Decisions

| Element | Current | New |
|---------|---------|-----|
| Layout wrapper | `card lg:card-side shadow-sm` | No card, open layout |
| Free delivery | Small text at bottom of purchase section | Prominent badge next to price |
| Image container | `figure` inside card, 50% width | Standalone section, natural proportions |
| Compatible lids | Vertical stack of lid options | Horizontal mini-carousel with quick-add |
| Mobile purchase | Scrolls off screen | Sticky bottom bar with price + Add to Cart |
| Product details | Inside card, cramped | Full-width sections below purchase zone |
| Add-ons/Related | N/A | New section with pattern background |
| Background | Card on base-100 | Pure white page |

## Visual Layout

### Desktop (lg+)

```
┌─────────────────────────────────────────────────────────────────┐
│  Breadcrumbs: Home > Cups & Lids > Single Wall Hot Cups         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐                                           │
│  │                  │    SINGLE WALL HOT CUPS                   │
│  │                  │    £16.00 / pack · FREE DELIVERY OVER £100│
│  │    PRODUCT       │    White · SKU: SWC-8OZ                   │
│  │    IMAGE         │                                           │
│  │    800x800       │    Short description here...              │
│  │                  │                                           │
│  │    (white bg,    │    Select size:                           │
│  │    no border)    │    [8oz] [12oz] [16oz]                    │
│  │                  │                                           │
│  └──────────────────┘    Select quantity:                       │
│                          [1 pack (500 units) ▼]                 │
│                                                                  │
│                          ─────────────────────────────          │
│                          Add a matching lid          ← →        │
│                          ┌─────┐ ┌─────┐ ┌─────┐               │
│                          │ Lid │ │ Lid │ │ Lid │ ...           │
│                          │ +   │ │ +   │ │ +   │               │
│                          └─────┘ └─────┘ └─────┘               │
│                          ─────────────────────────────          │
│                                                                  │
│                          Delivered in 2-3 working days          │
│                          Total (excl. VAT): £16.00              │
│                          [████████ Add to Cart ████████]        │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ABOUT OUR SINGLE WALL HOT CUPS                                 │
│  ───────────────────────────────                                │
│  Detailed description paragraph here. Full width, more          │
│  readable. Multiple paragraphs supported...                     │
│                                                                  │
│  SPECIFICATIONS                                                  │
│  ──────────────                                                 │
│  Material: Paper │ Capacity: 8oz │ Pack Size: 500 │ ...        │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░  COMPLETE YOUR ORDER                              ← →   ░░  │
│  ░░  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      ░░  │
│  ░░  │ Related │ │ Related │ │ Related │ │ Related │ ...  ░░  │
│  ░░  │ Product │ │ Product │ │ Product │ │ Product │      ░░  │
│  ░░  │   +     │ │   +     │ │   +     │ │   +     │      ░░  │
│  ░░  └─────────┘ └─────────┘ └─────────┘ └─────────┘      ░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────────────────────────────────┘
```

### Mobile

```
┌─────────────────────────┐
│  Breadcrumbs            │
├─────────────────────────┤
│  ┌───────────────────┐  │
│  │                   │  │
│  │   PRODUCT IMAGE   │  │
│  │   (full width)    │  │
│  │                   │  │
│  └───────────────────┘  │
│                         │
│  SINGLE WALL HOT CUPS   │
│  £16.00 / pack          │
│  FREE DELIVERY OVER £100│
│                         │
│  Select size:           │
│  [8oz] [12oz] [16oz]    │
│                         │
│  Select quantity:       │
│  [1 pack (500 units) ▼] │
│                         │
│  Add a matching lid →   │
│  [Lid] [Lid] [Lid] →    │
│                         │
│  (scrollable content)   │
│                         │
├─────────────────────────┤
│ £16.00 [Add to Cart]    │ ← sticky bottom bar
└─────────────────────────┘
```

## Implementation Tasks

### Phase 1: Remove Card Wrapper & Restructure Layout

#### T1.1: Update main layout structure
**File:** `app/views/products/_standard_product.html.erb`
**Changes:**
- Remove `card lg:card-side bg-base-100 shadow-sm` wrapper
- Replace with flexbox/grid layout: `flex flex-col lg:flex-row gap-8 lg:gap-12`
- Image section: `lg:w-1/2` with `bg-white` and proper sizing
- Content section: `lg:w-1/2` with natural flow

**Current (lines 71-76):**
```erb
<div class="card lg:card-side bg-base-100 shadow-sm"
     data-controller="product-options"
     ...>
  <figure class="lg:w-1/2 bg-white">
```

**New:**
```erb
<div class="flex flex-col lg:flex-row gap-8 lg:gap-12"
     data-controller="product-options"
     ...>
  <div class="lg:w-1/2 flex-shrink-0">
    <div class="bg-white rounded-lg overflow-hidden">
```

#### T1.2: Update content section structure
**File:** `app/views/products/_standard_product.html.erb`
**Changes:**
- Remove `card-body` class
- Use standard padding/spacing utilities
- Adjust text alignment classes

**Current (line 88):**
```erb
<div class="card-body p-4 sm:p-8 lg:w-1/2 text-center lg:text-left">
```

**New:**
```erb
<div class="lg:w-1/2 text-center lg:text-left">
```

### Phase 2: Free Delivery Badge

#### T2.1: Add free delivery badge next to price
**File:** `app/views/products/_standard_product.html.erb`
**Location:** After price display (around line 93-99)

**Add after price:**
```erb
<div class="flex items-center justify-center lg:justify-start gap-2 flex-wrap">
  <p class="text-xl text-black" data-product-options-target="unitPriceDisplay">
    <% if @has_url_selection %>
      <%= number_to_currency(@selected_variant.price) %> / pack
    <% else %>
      from <%= number_to_currency(@min_price) %> / pack
    <% end %>
  </p>
  <span class="text-sm font-medium text-primary">· FREE DELIVERY OVER £100</span>
</div>
```

#### T2.2: Remove old free delivery text
**File:** `app/views/products/_standard_product.html.erb`
**Location:** Line 219
**Change:** Remove the duplicate free delivery text from the total section

### Phase 3: Compatible Lids Mini-Carousel

#### T3.1: Create lid carousel partial
**File:** `app/views/products/_compatible_lid_card.html.erb` (new)
**Content:**
```erb
<%# Compact lid card for carousel %>
<div class="flex-shrink-0 w-32 border border-base-200 rounded-lg p-2 bg-white">
  <% if lid_variant.primary_photo&.attached? %>
    <%= image_tag lid_variant.primary_photo.variant(resize_and_pad: [100, 100, { background: [255, 255, 255] }]),
                  alt: lid_variant.product.name,
                  class: "w-full h-20 object-contain",
                  loading: "lazy" %>
  <% end %>
  <p class="text-xs font-medium truncate mt-1"><%= lid_variant.product.name %></p>
  <p class="text-xs text-base-content/60"><%= number_to_currency(lid_variant.unit_price) %>/unit</p>
  <button type="button"
          class="btn btn-circle btn-sm btn-primary mt-2"
          data-action="click->compatible-lids#addLid"
          data-lid-sku="<%= lid_variant.sku %>">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
    </svg>
  </button>
</div>
```

#### T3.2: Update compatible lids section to carousel layout
**File:** `app/views/products/_standard_product.html.erb`
**Location:** Lines 184-207 (compatible lids section)

**New structure:**
```erb
<% if @product.name.downcase.include?('cup') && !@product.name.downcase.include?('lid') && @product.has_compatible_lids? %>
  <div class="mt-4"
       data-controller="compatible-lids"
       data-compatible-lids-product-id-value="<%= @product.id %>"
       data-action="...">

    <div class="flex items-center justify-between mb-3">
      <h3 class="text-sm font-semibold">Add a matching lid</h3>
      <div class="flex gap-1">
        <button class="btn btn-ghost btn-xs btn-circle" data-action="compatible-lids#scrollLeft">←</button>
        <button class="btn btn-ghost btn-xs btn-circle" data-action="compatible-lids#scrollRight">→</button>
      </div>
    </div>

    <div data-compatible-lids-target="container"
         class="flex gap-3 overflow-x-auto pb-2 scrollbar-hide">
      <!-- Lid cards loaded dynamically -->
    </div>
  </div>
<% end %>
```

#### T3.3: Update compatible_lids_controller.js for carousel
**File:** `app/frontend/javascript/controllers/compatible_lids_controller.js`
**Changes:**
- Add `scrollLeft()` and `scrollRight()` actions
- Update render method to use compact card format
- Add smooth scroll behavior

### Phase 4: Mobile Sticky Add-to-Cart Bar

#### T4.1: Add sticky bottom bar for mobile
**File:** `app/views/products/_standard_product.html.erb`
**Location:** After main content, before drawer

```erb
<!-- Mobile sticky Add to Cart bar -->
<div class="fixed bottom-0 left-0 right-0 bg-white border-t border-base-200 p-3 lg:hidden z-40"
     data-product-options-target="mobileBar">
  <div class="flex items-center justify-between gap-4">
    <div>
      <p class="text-lg font-semibold" data-product-options-target="mobilePriceDisplay">
        <%= number_to_currency(@selected_variant.price) %>
      </p>
    </div>
    <button type="button"
            class="btn btn-primary flex-1 max-w-xs"
            data-action="click->product-options#submitForm">
      Add to Cart
    </button>
  </div>
</div>
```

#### T4.2: Add bottom padding to prevent content hiding behind sticky bar
**File:** `app/views/products/_standard_product.html.erb`
**Change:** Add `pb-20 lg:pb-0` to main container on mobile

#### T4.3: Update product_options_controller.js
**File:** `app/frontend/javascript/controllers/product_options_controller.js`
**Changes:**
- Add `mobileBarTarget` and `mobilePriceDisplayTarget`
- Add `submitForm()` action to trigger form submission
- Update price display to sync with mobile bar

### Phase 5: Product Details Section (Full Width)

#### T5.1: Move specs and details outside card area
**File:** `app/views/products/_standard_product.html.erb`
**Changes:**
- Move specs table and detailed description outside the flex container
- Make them full-width with proper spacing
- Add section dividers

**New structure after purchase zone:**
```erb
</div> <!-- End of flex row -->

<!-- Product Details Section -->
<div class="mt-12 space-y-8">
  <% if @product.description_detailed_with_fallback.present? %>
    <section>
      <h2 class="text-xl font-semibold mb-4">About Our <%= @product.name %></h2>
      <div class="prose prose-lg max-w-none text-base-content/80">
        <%= simple_format(@product.description_detailed_with_fallback) %>
      </div>
    </section>
  <% end %>

  <% if @selected_variant.variant_attributes.any? %>
    <section>
      <h2 class="text-xl font-semibold mb-4">Specifications</h2>
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        <% @selected_variant.variant_attributes.each do |key, value| %>
          <div class="bg-base-100 rounded-lg p-3">
            <p class="text-xs text-base-content/60 uppercase tracking-wide"><%= key.to_s.humanize %></p>
            <p class="font-medium"><%= value %></p>
          </div>
        <% end %>
      </div>
    </section>
  <% end %>
</div>
```

### Phase 6: Related Products / Add-ons Section

#### T6.1: Create related products section with pattern background
**File:** `app/views/products/_standard_product.html.erb`
**Location:** After product details, before drawer

```erb
<!-- Complete Your Order Section -->
<section class="mt-12 -mx-4 sm:-mx-6 lg:-mx-8 px-4 sm:px-6 lg:px-8 py-8 pattern-bg pattern-bg-grey pattern-subtle">
  <div class="container mx-auto">
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-xl font-semibold">Complete your order</h2>
      <div class="flex gap-1">
        <button class="btn btn-ghost btn-sm btn-circle" data-action="related-products#scrollLeft">←</button>
        <button class="btn btn-ghost btn-sm btn-circle" data-action="related-products#scrollRight">→</button>
      </div>
    </div>

    <div class="flex gap-4 overflow-x-auto pb-4 scrollbar-hide"
         data-controller="related-products">
      <% @related_products&.each do |product| %>
        <%= render "products/related_product_card", product: product %>
      <% end %>
    </div>
  </div>
</section>
```

#### T6.2: Create related product card partial
**File:** `app/views/products/_related_product_card.html.erb` (new)

```erb
<div class="flex-shrink-0 w-48 bg-white rounded-lg border border-base-200 overflow-hidden">
  <% if product.primary_photo&.attached? %>
    <%= link_to product_path(product) do %>
      <%= image_tag product.primary_photo.variant(resize_and_pad: [150, 150, { background: [255, 255, 255] }]),
                    alt: product.name,
                    class: "w-full h-32 object-contain bg-white",
                    loading: "lazy" %>
    <% end %>
  <% end %>
  <div class="p-3">
    <%= link_to product_path(product), class: "font-medium text-sm hover:text-primary line-clamp-2" do %>
      <%= product.name %>
    <% end %>
    <p class="text-sm text-base-content/60 mt-1">
      from <%= number_to_currency(product.min_price) %>/unit
    </p>
    <button type="button"
            class="btn btn-circle btn-sm btn-primary mt-2"
            data-action="click->related-products#quickAdd"
            data-product-id="<%= product.id %>">
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
      </svg>
    </button>
  </div>
</div>
```

#### T6.3: Add related products to controller
**File:** `app/controllers/products_controller.rb`
**Method:** `show`
**Add:**
```ruby
@related_products = @product.category.products
                            .where.not(id: @product.id)
                            .active
                            .limit(8)
```

#### T6.4: Create related_products_controller.js
**File:** `app/frontend/javascript/controllers/related_products_controller.js` (new)
**Features:**
- `scrollLeft()` / `scrollRight()` for carousel navigation
- `quickAdd()` for adding product to cart (redirects to product page or adds default variant)

### Phase 7: Scrollbar Hiding & Polish

#### T7.1: Add scrollbar-hide utility
**File:** `app/frontend/stylesheets/application.css`
**Add:**
```css
/* Hide scrollbar but keep functionality */
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
```

#### T7.2: Final spacing and alignment adjustments
Review all sections for consistent spacing using Tailwind's spacing scale.

## Files Changed Summary

| File | Action |
|------|--------|
| `app/views/products/_standard_product.html.erb` | Major refactor |
| `app/views/products/_compatible_lid_card.html.erb` | New |
| `app/views/products/_related_product_card.html.erb` | New |
| `app/controllers/products_controller.rb` | Add related products |
| `app/frontend/javascript/controllers/compatible_lids_controller.js` | Add carousel scroll |
| `app/frontend/javascript/controllers/product_options_controller.js` | Add mobile bar support |
| `app/frontend/javascript/controllers/related_products_controller.js` | New |
| `app/frontend/stylesheets/application.css` | Add scrollbar-hide |
| `app/frontend/entrypoints/application.js` | Register new controller |

## Testing Checklist

- [ ] Desktop: Layout displays correctly without card wrapper
- [ ] Desktop: Free delivery badge visible next to price
- [ ] Desktop: Compatible lids carousel scrolls horizontally
- [ ] Desktop: Related products carousel scrolls horizontally
- [ ] Desktop: Product details section displays full-width
- [ ] Mobile: Sticky Add to Cart bar appears at bottom
- [ ] Mobile: Sticky bar price updates when variant changes
- [ ] Mobile: Sticky bar Add to Cart button works
- [ ] Mobile: Content not hidden behind sticky bar
- [ ] All: Variant selection still works correctly
- [ ] All: Add to Cart flow still works
- [ ] All: Compatible lids still load dynamically
- [ ] All: Cart drawer opens after adding items

## Rollback Plan

If issues arise, the original template can be restored from git:
```bash
git checkout HEAD -- app/views/products/_standard_product.html.erb
```

New files can be deleted without impact on existing functionality.
