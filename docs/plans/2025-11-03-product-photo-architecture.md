---
type: Plan
description: Design document for a dual photo system giving Products and ProductVariants separate product_photo and lifestyle_photo attachments with hover-swap display behavior.
status: shipped
timestamp: 2025-11-03
---

# Product Photo Architecture - Dual Photo System

**Date:** 2025-11-03
**Status:** Approved Design
**Author:** Design brainstorming session

## Overview

This document describes the architecture for supporting two distinct photo types for products and product variants:
- **Product Photo**: Close-up shot of the product itself (clean, isolated)
- **Lifestyle Photo**: Product staged in real-life context/setting

## Business Requirements

### Photo Types
- **Product Photo**: Simple shot of the product, usually close-up, showing details
- **Lifestyle Photo**: Product staged in real-life situation, showing context and usage

### Photo Requirements
- Both photo types are **optional** at the Product and ProductVariant level
- No validation requirements (products can have neither, one, or both photos)
- ProductVariants manage photos independently (no inheritance from parent Product)

### Display Behavior

**Product Listing Pages (Cards):**
- Default display: product_photo
- On hover: Fade to lifestyle_photo (only when both exist)
- If only one photo exists: Static display, no hover effect

**Shopping Cart and Checkout:**
- Show primary photo (product_photo preferred, lifestyle_photo fallback)
- No hover effects

**Product Detail Pages:**
- Display both photos when available
- Use carousel/gallery pattern (existing Swiper.js integration)
- Graceful fallback to single photo if only one type exists

**Admin Interface:**
- Separate upload fields for each photo type
- Preview both photos
- Clear labeling: "Product Photo" and "Lifestyle Photo"

### Fallback Logic
Smart fallback between photo types:
- If product_photo missing → show lifestyle_photo
- If lifestyle_photo missing → show product_photo
- `primary_photo` method returns best available photo

## Architecture Decision

**Chosen Approach:** Direct Active Storage Attachments

**Rationale:**
- Simple, uses Rails conventions
- Easy to query and display
- No additional abstraction layer needed
- Straightforward migration path

**Rejected Alternatives:**
1. Polymorphic Photo model - Too heavy for this use case
2. Single attachment with variants - Raw vs lifestyle are different photos, not treatments

## Technical Design

### Model Changes

**Product Model (app/models/product.rb):**
```ruby
class Product < ApplicationRecord
  # Remove: has_one_attached :image

  # Add:
  has_one_attached :product_photo
  has_one_attached :lifestyle_photo

  # Helper methods
  def primary_photo
    product_photo.attached? ? product_photo : lifestyle_photo
  end

  def photos
    [product_photo, lifestyle_photo].select(&:attached?)
  end

  def has_photos?
    product_photo.attached? || lifestyle_photo.attached?
  end
end
```

**ProductVariant Model (app/models/product_variant.rb):**
```ruby
class ProductVariant < ApplicationRecord
  # Remove: has_one_attached :image

  # Add:
  has_one_attached :product_photo
  has_one_attached :lifestyle_photo

  # Same helper methods as Product
  def primary_photo
    product_photo.attached? ? product_photo : lifestyle_photo
  end

  def photos
    [product_photo, lifestyle_photo].select(&:attached?)
  end

  def has_photos?
    product_photo.attached? || lifestyle_photo.attached?
  end
end
```

### Database Migration

Since app is not live yet, we can use a destructive approach:

**Migration Steps:**
1. Update `active_storage_attachments` table to rename existing attachments:
   ```sql
   UPDATE active_storage_attachments
   SET name = 'product_photo'
   WHERE record_type IN ('Product', 'ProductVariant')
   AND name = 'image';
   ```

2. Update model definitions (remove `:image`, add `:product_photo` and `:lifestyle_photo`)

3. Update all codebase references from `.image` to `.product_photo`

No rollback plan needed - app not live yet.

### Frontend Implementation

**Stimulus Controller - Product Card Hover Effect:**

File: `app/frontend/javascript/controllers/product_card_hover_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productPhoto", "lifestylePhoto"]

  connect() {
    // Only enable if both photos exist
    if (!this.hasLifestylePhotoTarget) {
      return
    }

    // Set initial state
    this.lifestylePhotoTarget.style.opacity = "0"
  }

  mouseenter() {
    if (!this.hasLifestylePhotoTarget) return

    this.productPhotoTarget.style.opacity = "0"
    this.lifestylePhotoTarget.style.opacity = "1"
  }

  mouseleave() {
    if (!this.hasLifestylePhotoTarget) return

    this.productPhotoTarget.style.opacity = "1"
    this.lifestylePhotoTarget.style.opacity = "0"
  }
}
```

**View Implementation - Product Card:**

```erb
<div class="product-card"
     data-controller="product-card-hover"
     data-action="mouseenter->product-card-hover#mouseenter mouseleave->product-card-hover#mouseleave">

  <div class="product-image-container">
    <% if product.product_photo.attached? %>
      <%= image_tag product.product_photo.variant(:card),
                    class: "product-image",
                    data: { product_card_hover_target: "productPhoto" } %>
    <% end %>

    <% if product.lifestyle_photo.attached? %>
      <%= image_tag product.lifestyle_photo.variant(:card),
                    class: "product-image product-image-overlay",
                    data: { product_card_hover_target: "lifestylePhoto" } %>
    <% end %>
  </div>
</div>
```

**CSS Styling:**

```css
.product-image-container {
  position: relative;
  overflow: hidden;
}

.product-image {
  transition: opacity 0.3s ease-in-out;
  width: 100%;
  height: auto;
}

.product-image-overlay {
  position: absolute;
  top: 0;
  left: 0;
  opacity: 0;
}
```

### Active Storage Variants

Define image variants for different display contexts:

```ruby
# In models or config/initializers/active_storage.rb
variants = {
  thumb: { resize_to_limit: [100, 100] },
  card: { resize_to_limit: [400, 400] },
  large: { resize_to_limit: [800, 800] }
}

# Usage in views:
product.product_photo.variant(:card)
product.lifestyle_photo.variant(:large)
```

## Migration Checklist

- [ ] Create database migration to rename 'image' to 'product_photo' in active_storage_attachments
- [ ] Update Product model (remove :image, add :product_photo and :lifestyle_photo, add helper methods)
- [ ] Update ProductVariant model (same changes as Product)
- [ ] Update all view files (.image → .product_photo)
- [ ] Update all controller files
- [ ] Update admin forms (separate fields for each photo type)
- [ ] Create Stimulus controller for hover effect
- [ ] Add CSS for smooth transitions
- [ ] Update test fixtures
- [ ] Update model tests (test new helper methods)
- [ ] Add system tests (hover effect, fallbacks)
- [ ] Update CLAUDE.md documentation
- [ ] Update developer_guide.md (if exists)

## Testing Strategy

### Model Tests
- Test product_photo and lifestyle_photo attachments
- Test primary_photo returns correct photo with fallback
- Test photos returns only attached photos
- Test has_photos? boolean logic
- Test both Product and ProductVariant models

### Controller Tests
- Admin controllers can upload both photo types
- Photos properly associated with records

### System Tests
- Product cards display product_photo by default
- Hover effect shows lifestyle_photo when both exist
- Single photo products show static image (no hover)
- Product detail pages show both photos in gallery
- Cart displays correct thumbnail
- Admin interface uploads/previews both photo types

### Fixture Updates
- Update fixtures to use product_photo
- Create fixtures with both photo types
- Create fixtures with only one photo type for fallback testing

## Documentation Updates

- Update CLAUDE.md with new photo architecture
- Update developer_guide.md with photo management instructions
- Add inline comments in models explaining photo types and helper methods

## Future Considerations

- Add photo metadata (alt text, photographer credits)
- Add photo validation (file size, dimensions)
- Consider additional photo types if needed
- Implement lazy loading for images
- Consider CDN integration for image delivery
