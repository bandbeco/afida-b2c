---
type: Plan
description: Task-by-task implementation plan for the dual product_photo/lifestyle_photo system, including migration, model helpers, hover-effect Stimulus controller, and admin form updates.
status: shipped
timestamp: 2025-11-03
---

# Product Photo Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement dual photo system (product_photo and lifestyle_photo) for Products and ProductVariants with hover effects on product cards.

**Architecture:** Replace single `:image` attachment with two attachments (`:product_photo` and `:lifestyle_photo`) using Active Storage. Add smart fallback logic via helper methods. Implement Stimulus controller for hover effect on product cards that transitions from product_photo to lifestyle_photo on mouse hover.

**Tech Stack:** Rails 8, Active Storage, Stimulus.js, TailwindCSS, PostgreSQL

---

## Task 1: Database Migration - Rename image to product_photo

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_rename_image_to_product_photo.rb`

**Step 1: Create migration file**

Run: `rails generate migration RenameImageToProductPhoto`

**Step 2: Write migration**

```ruby
class RenameImageToProductPhoto < ActiveRecord::Migration[8.0]
  def up
    # Rename 'image' attachments to 'product_photo' for Products and ProductVariants
    ActiveStorage::Attachment.where(
      record_type: ['Product', 'ProductVariant'],
      name: 'image'
    ).update_all(name: 'product_photo')
  end

  def down
    # Rollback: rename 'product_photo' back to 'image'
    ActiveStorage::Attachment.where(
      record_type: ['Product', 'ProductVariant'],
      name: 'product_photo'
    ).update_all(name: 'image')
  end
end
```

**Step 3: Run migration**

Run: `rails db:migrate`
Expected: Migration runs successfully

**Step 4: Verify in console**

Run: `rails console`
```ruby
ActiveStorage::Attachment.where(record_type: 'Product').pluck(:name).uniq
# Expected: ["product_photo"] (not "image")
```

**Step 5: Commit**

```bash
git add db/migrate/*_rename_image_to_product_photo.rb db/schema.rb
git commit -m "Add migration to rename image attachments to product_photo

Renames 'image' to 'product_photo' in active_storage_attachments
for Product and ProductVariant records. Supports rollback.

Part of dual photo system implementation."
```

---

## Task 2: Update Product Model - Add photo attachments and helpers

**Files:**
- Modify: `app/models/product.rb:39` (replace has_one_attached :image)
- Test: `test/models/product_test.rb`

**Step 1: Write failing tests**

Add to `test/models/product_test.rb`:

```ruby
test "can attach product_photo" do
  product = products(:pizza_box)
  file = fixture_file_upload('files/product.jpg', 'image/jpeg')

  product.product_photo.attach(file)

  assert product.product_photo.attached?
end

test "can attach lifestyle_photo" do
  product = products(:pizza_box)
  file = fixture_file_upload('files/lifestyle.jpg', 'image/jpeg')

  product.lifestyle_photo.attach(file)

  assert product.lifestyle_photo.attached?
end

test "primary_photo returns product_photo when both attached" do
  product = products(:pizza_box)
  product.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))
  product.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  assert_equal product.product_photo, product.primary_photo
end

test "primary_photo returns lifestyle_photo when only lifestyle attached" do
  product = products(:pizza_box)
  product.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  assert_equal product.lifestyle_photo, product.primary_photo
end

test "primary_photo returns nil when no photos attached" do
  product = products(:pizza_box)

  assert_nil product.primary_photo
end

test "photos returns array of attached photos" do
  product = products(:pizza_box)
  product.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))
  product.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  photos = product.photos

  assert_equal 2, photos.length
  assert_includes photos, product.product_photo
  assert_includes photos, product.lifestyle_photo
end

test "photos returns only attached photos" do
  product = products(:pizza_box)
  product.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))

  photos = product.photos

  assert_equal 1, photos.length
  assert_equal product.product_photo, photos.first
end

test "has_photos? returns true when product_photo attached" do
  product = products(:pizza_box)
  product.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))

  assert product.has_photos?
end

test "has_photos? returns true when lifestyle_photo attached" do
  product = products(:pizza_box)
  product.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  assert product.has_photos?
end

test "has_photos? returns false when no photos attached" do
  product = products(:pizza_box)

  assert_not product.has_photos?
end
```

**Step 2: Create test fixtures**

Create directories and placeholder files:
```bash
mkdir -p test/fixtures/files
touch test/fixtures/files/product.jpg
touch test/fixtures/files/lifestyle.jpg
```

Note: These can be minimal 1x1 pixel images for testing purposes.

**Step 3: Run tests to verify they fail**

Run: `rails test test/models/product_test.rb`
Expected: Multiple FAIL/ERROR with "undefined method `product_photo'"

**Step 4: Update Product model**

In `app/models/product.rb`, replace line 39:
```ruby
# Remove this:
has_one_attached :image

# Add these:
has_one_attached :product_photo
has_one_attached :lifestyle_photo
```

Add helper methods after the attachment declarations:
```ruby
# Returns the primary photo (with smart fallback)
# Priority: product_photo first, then lifestyle_photo
def primary_photo
  product_photo.attached? ? product_photo : lifestyle_photo
end

# Returns all attached photos as an array
# Useful for galleries or carousels on detail pages
def photos
  [product_photo, lifestyle_photo].select(&:attached?)
end

# Check if any photo is available
def has_photos?
  product_photo.attached? || lifestyle_photo.attached?
end
```

Update comment at line 10:
```ruby
# - has_one_attached :product_photo - Main product photo
# - has_one_attached :lifestyle_photo - Lifestyle/context photo
```

**Step 5: Run tests to verify they pass**

Run: `rails test test/models/product_test.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/models/product.rb test/models/product_test.rb test/fixtures/files/
git commit -m "Add product_photo and lifestyle_photo to Product model

- Replace :image with :product_photo and :lifestyle_photo
- Add helper methods: primary_photo, photos, has_photos?
- Add comprehensive model tests
- Update inline documentation

Part of dual photo system implementation."
```

---

## Task 3: Update ProductVariant Model - Add photo attachments and helpers

**Files:**
- Modify: `app/models/product_variant.rb:29` (replace has_one_attached :image)
- Test: `test/models/product_variant_test.rb`

**Step 1: Write failing tests**

Add to `test/models/product_variant_test.rb`:

```ruby
test "can attach product_photo" do
  variant = product_variants(:pizza_box_7_inch)
  file = fixture_file_upload('files/product.jpg', 'image/jpeg')

  variant.product_photo.attach(file)

  assert variant.product_photo.attached?
end

test "can attach lifestyle_photo" do
  variant = product_variants(:pizza_box_7_inch)
  file = fixture_file_upload('files/lifestyle.jpg', 'image/jpeg')

  variant.lifestyle_photo.attach(file)

  assert variant.lifestyle_photo.attached?
end

test "primary_photo returns product_photo when both attached" do
  variant = product_variants(:pizza_box_7_inch)
  variant.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))
  variant.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  assert_equal variant.product_photo, variant.primary_photo
end

test "primary_photo returns lifestyle_photo when only lifestyle attached" do
  variant = product_variants(:pizza_box_7_inch)
  variant.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  assert_equal variant.lifestyle_photo, variant.primary_photo
end

test "primary_photo returns nil when no photos attached" do
  variant = product_variants(:pizza_box_7_inch)

  assert_nil variant.primary_photo
end

test "photos returns array of attached photos" do
  variant = product_variants(:pizza_box_7_inch)
  variant.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))
  variant.lifestyle_photo.attach(fixture_file_upload('files/lifestyle.jpg', 'image/jpeg'))

  photos = variant.photos

  assert_equal 2, photos.length
  assert_includes photos, variant.product_photo
  assert_includes photos, variant.lifestyle_photo
end

test "has_photos? returns true when photos attached" do
  variant = product_variants(:pizza_box_7_inch)
  variant.product_photo.attach(fixture_file_upload('files/product.jpg', 'image/jpeg'))

  assert variant.has_photos?
end

test "has_photos? returns false when no photos attached" do
  variant = product_variants(:pizza_box_7_inch)

  assert_not variant.has_photos?
end
```

**Step 2: Run tests to verify they fail**

Run: `rails test test/models/product_variant_test.rb`
Expected: Multiple FAIL/ERROR

**Step 3: Update ProductVariant model**

In `app/models/product_variant.rb`, replace line 29:
```ruby
# Remove this:
has_one_attached :image

# Add these:
has_one_attached :product_photo
has_one_attached :lifestyle_photo
```

Add helper methods after the attachment declarations:
```ruby
# Returns the primary photo (with smart fallback)
# Priority: product_photo first, then lifestyle_photo
def primary_photo
  product_photo.attached? ? product_photo : lifestyle_photo
end

# Returns all attached photos as an array
def photos
  [product_photo, lifestyle_photo].select(&:attached?)
end

# Check if any photo is available
def has_photos?
  product_photo.attached? || lifestyle_photo.attached?
end
```

Update comment at line 14:
```ruby
# - has_one_attached :product_photo - Variant-specific product photo
# - has_one_attached :lifestyle_photo - Variant-specific lifestyle photo
```

**Step 4: Run tests to verify they pass**

Run: `rails test test/models/product_variant_test.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/models/product_variant.rb test/models/product_variant_test.rb
git commit -m "Add product_photo and lifestyle_photo to ProductVariant model

- Replace :image with :product_photo and :lifestyle_photo
- Add helper methods: primary_photo, photos, has_photos?
- Add comprehensive model tests
- Update inline documentation

Variants manage photos independently (no inheritance from Product).

Part of dual photo system implementation."
```

---

## Task 4: Update Product Views - Replace .image with .product_photo

**Files:**
- Modify: `app/views/products/_product_card.html.erb` (if exists)
- Modify: `app/views/products/show.html.erb` (if exists)
- Search: Find all `.image` references in views

**Step 1: Find all view files referencing .image**

Run: `grep -r "\.image" app/views/ --include="*.erb"`

Expected: List of files with .image references

**Step 2: Update each view file**

For each file found, replace `.image` with `.product_photo`:
- Product cards: Use `.product_photo` for now (hover effect in next task)
- Product detail pages: Use `.product_photo` for main image
- Cart views: Use `.primary_photo` for thumbnails

Example replacements:
```erb
# Before:
<%= image_tag product.image if product.image.attached? %>

# After:
<%= image_tag product.product_photo if product.product_photo.attached? %>

# Or for smart fallback:
<%= image_tag product.primary_photo if product.has_photos? %>
```

**Step 3: Test manually**

Run: `bin/dev`
Visit: http://localhost:3000
Check: Product pages display images correctly

**Step 4: Run system tests**

Run: `rails test:system`
Expected: All tests PASS (or same failures as before if any exist)

**Step 5: Commit**

```bash
git add app/views/
git commit -m "Update product views to use product_photo

Replace .image references with .product_photo in all views.
Use .primary_photo for smart fallback where appropriate.

Part of dual photo system implementation."
```

---

## Task 5: Create Stimulus Controller for Hover Effect

**Files:**
- Create: `app/frontend/javascript/controllers/product_card_hover_controller.js`
- Modify: `app/frontend/javascript/controllers/index.js` (if manual registration needed)

**Step 1: Write Stimulus controller**

Create `app/frontend/javascript/controllers/product_card_hover_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles hover effect on product cards to show lifestyle photo
// Fades from product_photo to lifestyle_photo on mouse enter
// Only activates when both photos are present
export default class extends Controller {
  static targets = ["productPhoto", "lifestylePhoto"]

  connect() {
    // Only enable hover if both photos exist
    if (!this.hasLifestylePhotoTarget) {
      return
    }

    // Set initial state: lifestyle photo hidden
    this.lifestylePhotoTarget.style.opacity = "0"
  }

  mouseenter() {
    if (!this.hasLifestylePhotoTarget) return

    // Fade out product photo, fade in lifestyle photo
    this.productPhotoTarget.style.opacity = "0"
    this.lifestylePhotoTarget.style.opacity = "1"
  }

  mouseleave() {
    if (!this.hasLifestylePhotoTarget) return

    // Fade in product photo, fade out lifestyle photo
    this.productPhotoTarget.style.opacity = "1"
    this.lifestylePhotoTarget.style.opacity = "0"
  }
}
```

**Step 2: Verify controller registration**

Check if Stimulus auto-registers controllers. If not, add to index:
```javascript
import ProductCardHoverController from "./product_card_hover_controller"
application.register("product-card-hover", ProductCardHoverController)
```

**Step 3: Test controller loads**

Run: `bin/dev`
Open browser console and check for errors
Expected: No JavaScript errors

**Step 4: Commit**

```bash
git add app/frontend/javascript/controllers/product_card_hover_controller.js
git commit -m "Add Stimulus controller for product card hover effect

Implements fade transition from product_photo to lifestyle_photo
on mouse hover. Only activates when both photos present.

Part of dual photo system implementation."
```

---

## Task 6: Add CSS Styles for Photo Transitions

**Files:**
- Modify: `app/frontend/stylesheets/application.css` or create component-specific CSS

**Step 1: Add CSS for smooth transitions**

Add to CSS file:

```css
/* Product card image container */
.product-image-container {
  position: relative;
  overflow: hidden;
  aspect-ratio: 1 / 1;
}

/* Base product image styling */
.product-image {
  transition: opacity 0.3s ease-in-out;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

/* Overlay image (lifestyle photo) */
.product-image-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  transition: opacity 0.3s ease-in-out;
}
```

**Step 2: Test CSS loads**

Run: `bin/dev`
Inspect element in browser
Expected: Classes and transitions applied

**Step 3: Commit**

```bash
git add app/frontend/stylesheets/
git commit -m "Add CSS styles for product photo transitions

Adds smooth opacity transitions for hover effect.
Positions lifestyle photo as overlay with absolute positioning.

Part of dual photo system implementation."
```

---

## Task 7: Update Product Card View with Hover Effect

**Files:**
- Modify: `app/views/products/_product_card.html.erb` (or wherever product cards are rendered)

**Step 1: Update product card template**

Replace image section with dual-photo hover structure:

```erb
<div class="product-card"
     data-controller="product-card-hover"
     data-action="mouseenter->product-card-hover#mouseenter mouseleave->product-card-hover#mouseleave">

  <div class="product-image-container">
    <% if product.product_photo.attached? %>
      <%= image_tag product.product_photo.variant(:card),
                    alt: product.name,
                    class: "product-image",
                    data: { product_card_hover_target: "productPhoto" } %>
    <% end %>

    <% if product.lifestyle_photo.attached? %>
      <%= image_tag product.lifestyle_photo.variant(:card),
                    alt: "#{product.name} lifestyle",
                    class: "product-image product-image-overlay",
                    data: { product_card_hover_target: "lifestylePhoto" } %>
    <% end %>
  </div>

  <!-- Rest of product card content -->
</div>
```

**Step 2: Test manually**

Run: `bin/dev`
Visit product listing page
Test:
- Hover over card with both photos → should transition
- Hover over card with only one photo → should stay static

**Step 3: Commit**

```bash
git add app/views/products/
git commit -m "Update product card view with hover effect

Implements dual-photo structure with Stimulus controller.
Shows product_photo by default, transitions to lifestyle_photo
on hover when both are present.

Part of dual photo system implementation."
```

---

## Task 8: Update Admin Forms - Separate Photo Upload Fields

**Files:**
- Modify: `app/views/admin/products/_form.html.erb`
- Modify: `app/views/admin/product_variants/_form.html.erb` (if exists)

**Step 1: Update product form**

In `app/views/admin/products/_form.html.erb`, replace image field:

```erb
<!-- Remove old field: -->
<%= form.file_field :image %>

<!-- Add new fields: -->
<div class="form-group">
  <%= form.label :product_photo, "Product Photo" %>
  <%= form.file_field :product_photo, accept: 'image/*' %>
  <% if form.object.product_photo.attached? %>
    <div class="image-preview">
      <%= image_tag form.object.product_photo.variant(:thumb) %>
    </div>
  <% end %>
</div>

<div class="form-group">
  <%= form.label :lifestyle_photo, "Lifestyle Photo" %>
  <%= form.file_field :lifestyle_photo, accept: 'image/*' %>
  <% if form.object.lifestyle_photo.attached? %>
    <div class="image-preview">
      <%= image_tag form.object.lifestyle_photo.variant(:thumb) %>
    </div>
  <% end %>
</div>
```

**Step 2: Update strong parameters in controller**

In `app/controllers/admin/products_controller.rb`, update params:

```ruby
def product_params
  params.require(:product).permit(
    # ... existing params ...
    :product_photo,
    :lifestyle_photo
    # Remove :image if present
  )
end
```

**Step 3: Test admin upload**

Run: `bin/dev`
Visit: http://localhost:3000/admin/products/new
Test: Upload both photo types
Expected: Both photos save and display

**Step 4: Commit**

```bash
git add app/views/admin/ app/controllers/admin/
git commit -m "Update admin forms for dual photo uploads

Add separate upload fields for product_photo and lifestyle_photo.
Show preview thumbnails for attached photos.
Update strong parameters to permit new photo fields.

Part of dual photo system implementation."
```

---

## Task 9: Add System Tests for Hover Effect

**Files:**
- Create or modify: `test/system/products_test.rb`

**Step 1: Write system test for hover effect**

Add to `test/system/products_test.rb`:

```ruby
test "product card shows hover effect when both photos present" do
  # Setup: Create product with both photos
  product = products(:pizza_box)
  product.product_photo.attach(
    io: File.open(Rails.root.join('test/fixtures/files/product.jpg')),
    filename: 'product.jpg'
  )
  product.lifestyle_photo.attach(
    io: File.open(Rails.root.join('test/fixtures/files/lifestyle.jpg')),
    filename: 'lifestyle.jpg'
  )

  visit products_path

  # Find product card
  product_card = find(".product-card", match: :first)

  # Verify controller is connected
  assert product_card[:'data-controller'].include?('product-card-hover')

  # Verify both images are present
  within(product_card) do
    assert_selector('[data-product-card-hover-target="productPhoto"]')
    assert_selector('[data-product-card-hover-target="lifestylePhoto"]')
  end
end

test "product card shows static image when only product_photo present" do
  # Setup: Create product with only product_photo
  product = products(:paper_cup)
  product.product_photo.attach(
    io: File.open(Rails.root.join('test/fixtures/files/product.jpg')),
    filename: 'product.jpg'
  )

  visit products_path

  product_card = find(".product-card", match: :first)

  within(product_card) do
    assert_selector('[data-product-card-hover-target="productPhoto"]')
    assert_no_selector('[data-product-card-hover-target="lifestylePhoto"]')
  end
end
```

**Step 2: Run system tests**

Run: `rails test:system`
Expected: Tests PASS

**Step 3: Commit**

```bash
git add test/system/
git commit -m "Add system tests for product card hover effect

Tests verify:
- Hover effect present when both photos attached
- Static display when only one photo present
- Stimulus controller properly connected

Part of dual photo system implementation."
```

---

## Task 10: Update Documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/developer_guide.md` (if exists)

**Step 1: Update CLAUDE.md**

Add section about photo management:

```markdown
### Working with Product Photos

Products and variants support two photo types:
- **Product Photo** (`:product_photo`) - Close-up product shot
- **Lifestyle Photo** (`:lifestyle_photo`) - Staged in real-life context

Both photos are optional. Helper methods:
- `product.primary_photo` - Returns product_photo if present, else lifestyle_photo
- `product.photos` - Array of all attached photos
- `product.has_photos?` - Returns true if any photo attached

**Product Cards**: Display product_photo by default, hover shows lifestyle_photo (when both present)

**Admin**: Separate upload fields for each photo type

**Cart/Thumbnails**: Use `primary_photo` for smart fallback
```

**Step 2: Update developer_guide.md if it exists**

Add similar documentation about photo architecture.

**Step 3: Commit**

```bash
git add CLAUDE.md docs/
git commit -m "Update documentation for dual photo system

Documents:
- Two photo types (product_photo, lifestyle_photo)
- Helper methods (primary_photo, photos, has_photos?)
- Usage patterns (cards, admin, thumbnails)
- Hover effect behavior

Part of dual photo system implementation."
```

---

## Task 11: Run Full Test Suite and Verify

**Files:**
- None (verification step)

**Step 1: Run all tests**

Run: `rails test`
Expected: All tests PASS

**Step 2: Run system tests**

Run: `rails test:system`
Expected: All tests PASS

**Step 3: Check test coverage**

Review coverage report in `coverage/index.html`
Expected: Coverage maintained or improved

**Step 4: Manual smoke test**

Run: `bin/dev`
Test:
- [ ] Product listing page shows images
- [ ] Hover effect works on cards with both photos
- [ ] Product detail page shows images
- [ ] Cart shows thumbnails
- [ ] Admin can upload both photo types
- [ ] Admin shows preview of both photos

**Step 5: Commit if any fixes needed**

```bash
git add .
git commit -m "Fix any issues found during verification

[Describe any fixes made]

Part of dual photo system implementation."
```

---

## Task 12: Final Cleanup and Merge Preparation

**Files:**
- None (cleanup step)

**Step 1: Review all changes**

Run: `git log --oneline origin/master..HEAD`
Review commit history for clarity

**Step 2: Check for any remaining .image references**

Run: `grep -r "\.image" app/ --include="*.rb" --include="*.erb"`
Expected: No results (or only intentional references)

**Step 3: Run final checks**

Run:
```bash
rubocop
brakeman
rails test
```

Expected: All pass with no new issues

**Step 4: Push branch**

Run: `git push -u origin feature/product-photos`

**Step 5: Next steps**

Announce: "Implementation complete. Ready to create pull request or merge to master?"

---

## Summary

This plan implements the dual photo system for products and variants:

1. ✅ Database migration (rename image → product_photo)
2. ✅ Model updates (Product and ProductVariant)
3. ✅ Helper methods (primary_photo, photos, has_photos?)
4. ✅ View updates (replace .image references)
5. ✅ Stimulus controller (hover effect)
6. ✅ CSS styles (smooth transitions)
7. ✅ Product card hover implementation
8. ✅ Admin forms (dual upload fields)
9. ✅ System tests (hover behavior)
10. ✅ Documentation updates
11. ✅ Verification and testing
12. ✅ Final cleanup

**Total estimated time**: 2-3 hours
**Commits**: 12 (one per task)
**Test coverage**: Comprehensive (model, system, manual)
