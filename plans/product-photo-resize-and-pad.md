# Product Photo Presentation Improvement

## Overview

Replace `resize_to_limit` with `resize_and_pad` using white backgrounds across all customer-facing product photo displays. This creates consistent, professional product presentation with properly framed images that show the full product without aggressive cropping.

**Problem**: Current `resize_to_limit` + `object-cover` CSS causes aggressive cropping on photos that weren't shot with tight framing. Products like wooden forks, pizza boxes, and cups appear awkwardly zoomed in.

**Solution**: Use Active Storage's `resize_and_pad` transformation to create consistent square images with white padding, eliminating CSS cropping while maintaining uniform grid layouts.

## Technical Approach

### Transformation Change

| Context | Current | New |
|---------|---------|-----|
| Default (helper) | `resize_to_limit: [400, 400]` | `resize_and_pad: [400, 400, { background: [255, 255, 255] }]` |
| Product cards | `resize_to_limit: [400, 400]` | `resize_and_pad: [400, 400, { background: [255, 255, 255] }]` |
| Product detail | `resize_to_limit: [800, 800]` | `resize_and_pad: [800, 800, { background: [255, 255, 255] }]` |
| Thumbnails | `resize_to_limit: [400, 400]` (default) | `resize_and_pad: [80, 80, { background: [255, 255, 255] }]` |

### CSS Change

- `object-cover` → `object-contain` (or remove entirely since padding handles sizing)
- Add `bg-white` to figure containers as fallback while images load

### Vips Background Color Format

Vips uses RGB array format (not hex strings):
```ruby
background: [255, 255, 255]  # White
```

## Files to Modify

### Primary Changes

#### 1. `app/helpers/product_helper.rb` (line 60)

Update default variant in `product_photo_tag` helper:

```ruby
# Before
variant_options = options[:variant] || { resize_to_limit: [ 400, 400 ] }

# After
variant_options = options[:variant] || { resize_and_pad: [400, 400, { background: [255, 255, 255] }] }
```

Also update default CSS class (line 58):
```ruby
# Before
css_class = options[:class] || "w-full h-full object-cover"

# After
css_class = options[:class] || "w-full h-full object-contain"
```

#### 2. `app/views/products/_card.html.erb` (lines 3-8)

```erb
<!-- Before -->
<figure class="aspect-square overflow-hidden flex-shrink-0">
  <%= product_photo_tag(product.primary_photo,
                        alt: product.name,
                        class: "w-full h-full object-cover hover:scale-105 transition-transform duration-300",
                        variant: { resize_to_limit: [400, 400] },
                        loading: "lazy") %>
</figure>

<!-- After -->
<figure class="aspect-square bg-white flex-shrink-0 overflow-hidden">
  <%= product_photo_tag(product.primary_photo,
                        alt: product.name,
                        class: "w-full h-full object-contain hover:scale-105 transition-transform duration-300",
                        variant: { resize_and_pad: [400, 400, { background: [255, 255, 255] }] },
                        loading: "lazy") %>
</figure>
```

#### 3. `app/views/products/_standard_product.html.erb` (lines 77-85)

```erb
<!-- Before -->
<figure class="lg:w-1/2">
  <%= product_photo_tag(@selected_variant.primary_photo,
                        alt: @product.name,
                        class: "w-full h-full object-cover",
                        variant: { resize_to_limit: [800, 800] },
                        fetchpriority: "high",
                        width: 800,
                        height: 800,
                        data: { product_options_target: "imageDisplay" }) %>
</figure>

<!-- After -->
<figure class="lg:w-1/2 bg-white">
  <%= product_photo_tag(@selected_variant.primary_photo,
                        alt: @product.name,
                        class: "w-full h-full object-contain",
                        variant: { resize_and_pad: [800, 800, { background: [255, 255, 255] }] },
                        fetchpriority: "high",
                        width: 800,
                        height: 800,
                        data: { product_options_target: "imageDisplay" }) %>
</figure>
```

#### 4. `app/views/products/_product.html.erb` (lines 5-20)

Update both product_photo and lifestyle_photo image tags:

```erb
<!-- Product photo -->
<%= image_tag product.product_photo.variant(resize_and_pad: [400, 400, { background: [255, 255, 255] }]),
              alt: product.name, class: "product-image object-contain", ... %>

<!-- Lifestyle photo -->
<%= image_tag product.lifestyle_photo.variant(resize_and_pad: [400, 400, { background: [255, 255, 255] }]),
              alt: "#{product.name} in use", class: "product-image-overlay object-contain", ... %>
```

### Cart & Order Thumbnails

#### 5. `app/views/cart_items/_cart_item.html.erb` (line ~15)

```erb
<!-- Use default helper (will pick up new resize_and_pad default) -->
<%= product_photo_tag(cart_item.product_variant.primary_photo,
                      alt: cart_item.product_variant.display_name,
                      class: "w-16 h-16 sm:w-20 sm:h-20 rounded-md shadow bg-white object-contain") %>
```

#### 6. `app/views/shared/_drawer_cart_content.html.erb` (line ~17)

```erb
<%= product_photo_tag(cart_item.product_variant.primary_photo,
                      alt: cart_item.product_variant.display_name,
                      class: "w-12 h-12 rounded bg-white object-contain") %>
```

#### 7. `app/views/orders/show.html.erb` (line ~48)

```erb
<%= product_photo_tag(item.product_variant&.primary_photo,
                      alt: item.product_variant&.display_name || "Product",
                      class: "h-16 w-16 rounded-lg bg-white object-contain") %>
```

#### 8. `app/views/orders/confirmation.html.erb`

Same pattern as orders/show.html.erb

#### 9. `app/views/orders/index.html.erb` (line 50)

```erb
<!-- Before -->
<%= image_tag item.product_variant.product_photo.variant(resize_to_fill: [80, 80]),
              class: "h-10 w-10 object-cover rounded-full border-2 border-white" %>

<!-- After -->
<%= product_photo_tag(item.product_variant.primary_photo,
                      variant: { resize_and_pad: [80, 80, { background: [255, 255, 255] }] },
                      class: "h-10 w-10 object-contain rounded-full border-2 border-white bg-white") %>
```

### Secondary Views

#### 10. `app/views/branded_products/_branded_product.html.erb` (lines 9, 19)

```erb
<%= image_tag product.product_photo.variant(resize_and_pad: [400, 400, { background: [255, 255, 255] }]),
              alt: product.name, ... %>
```

#### 11. `app/views/samples/_variant_card.html.erb` (line 53)

```erb
<!-- Before -->
<%= image_tag photo.variant(resize_to_fill: [200, 200]), ... %>

<!-- After -->
<%= image_tag photo.variant(resize_and_pad: [200, 200, { background: [255, 255, 255] }]),
              class: "w-full h-full object-contain", ... %>
```

## Files NOT Modified (Intentionally)

- **Social meta tags** (`og:image`, `twitter:image`) - These have specific aspect ratio requirements for social platforms
- **Admin forms** - Internal use only, cropping is acceptable for small previews
- **JSON API responses** - Used programmatically, don't need visual consistency
- **Google Merchant feed** - Keep existing treatment for shopping ads

## Edge Cases & Fallbacks

### Missing Photos

The existing `product_photo_tag` helper already handles missing photos with an SVG placeholder (lines 74-78 in `product_helper.rb`). No changes needed.

### Transparent PNGs

`resize_and_pad` with `background: [255, 255, 255]` will fill transparent areas with white, which is the desired behavior.

### Non-Square Source Images

`resize_and_pad` will:
1. Resize the image to fit within the target dimensions (preserving aspect ratio)
2. Add white padding to create exact square dimensions
3. Center the image within the padded area (default gravity)

Example: 1200x800 image → resized to 400x267 → padded to 400x400 with white bars top/bottom

### Small Source Images

`resize_and_pad` will upscale small images to fit target dimensions. This may cause some blurriness for very small source images (<400px). Consider adding admin guidance for minimum recommended photo dimensions (800x800px).

## Vips Configuration

### Verify Configuration

Check that Vips is configured in both environments:

**`config/environments/production.rb`** (already set):
```ruby
config.active_storage.variant_processor = :vips
```

**`config/environments/development.rb`** (add if missing):
```ruby
config.active_storage.variant_processor = :vips
```

### Install libvips (if needed)

macOS:
```bash
brew install vips
```

Ubuntu/Debian:
```bash
sudo apt-get install libvips-dev
```

## Testing Plan

### Visual Verification

After implementation, visually verify these pages:

- [ ] Shop page (`/shop`) - Product grid
- [ ] Category page (`/categories/cups-and-lids`) - Product grid
- [ ] Product detail page (`/products/paper-hot-cups`) - Hero image
- [ ] Product with variant selection - Image swap on variant change
- [ ] Cart drawer - Thumbnail images
- [ ] Order confirmation page - Order item thumbnails
- [ ] Order history (`/orders`) - Order list thumbnails
- [ ] Order detail (`/orders/:id`) - Order item thumbnails
- [ ] Samples page (`/samples`) - Sample cards
- [ ] Branded products page - Product cards

### Edge Case Testing

- [ ] Product with only product_photo (no lifestyle)
- [ ] Product with only lifestyle_photo (no product)
- [ ] Product with no photos (placeholder should show)
- [ ] Transparent PNG product photo
- [ ] Portrait orientation source image
- [ ] Landscape orientation source image
- [ ] Very small source image (<200px)

### Performance Verification

- [ ] Verify variants are generated on first request (check server logs)
- [ ] Verify subsequent requests serve cached variants
- [ ] Check image file sizes are reasonable (<200KB for cards, <500KB for detail)

## Acceptance Criteria

- [ ] All product photos display without aggressive cropping
- [ ] All product images have consistent white backgrounds
- [ ] Product grid layouts remain aligned (no layout shifts)
- [ ] Hover effects on product cards still work (lifestyle photo swap)
- [ ] Missing photos show placeholder SVG
- [ ] Cart and order thumbnails use same white background treatment
- [ ] No visual regression on social sharing previews (og:image unchanged)
- [ ] Page load performance not degraded

## Rollback Plan

If issues are discovered post-deployment:

1. Revert helper default back to `resize_to_limit`
2. Revert CSS back to `object-cover`
3. Purge cached variants: `ActiveStorage::VariantRecord.destroy_all`

## References

### Internal Files
- `app/helpers/product_helper.rb:55-80` - Central photo helper
- `app/models/product.rb:106-121` - Photo fallback logic
- `config/environments/production.rb:27` - Vips processor config

### External Documentation
- [Active Storage Variant API](https://api.rubyonrails.org/classes/ActiveStorage/Variant.html)
- [ImageProcessing gem Vips options](https://github.com/janko/image_processing/blob/master/doc/vips.md)
- [Resize Images with Active Storage](https://dev.to/mikerogers0/resize-images-with-active-storage-in-rails-481n)
