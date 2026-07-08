---
type: Plan
description: Design document for admin controls to manage category and product display order using acts_as_list and up/down arrow ordering pages.
status: shipped
timestamp: 2025-11-08
---

# Admin Ordering Controls Design

**Date:** 2025-11-08
**Status:** Approved
**Author:** Claude Code

## Overview

Add admin controls for managing the display order of categories and products. Admins will use dedicated ordering pages with up/down arrow buttons to control the sequence in which categories appear site-wide and products appear within each category.

## Requirements

- **Categories:** Global ordering controls (all categories ordered site-wide)
- **Products:** Category-scoped ordering (each category has independent product ordering)
- **UI Approach:** Up/down arrow buttons on dedicated ordering pages
- **UX:** Simple, works on all devices, provides instant visual feedback

## Architecture

### Gem Selection

Use **acts_as_list** gem for position management:
- Battle-tested solution for ordered lists
- Automatic position maintenance (1, 2, 3...)
- Provides `move_higher`, `move_lower`, `move_to_top`, `move_to_bottom` methods
- Handles edge cases (top/bottom boundaries, item deletion, insertion)

### Database Schema

**Categories Table Changes:**
1. Add `position` integer column (not null, default: 0)
2. Add index on `position` for performance
3. Backfill existing categories with sequential positions (based on current name order)

**Products Table Changes:**
1. Rename `sort_order` column to `position` (follows acts_as_list conventions)
2. Add composite index on `(category_id, position)` for scoped ordering performance
3. Backfill products within each category with sequential positions

**Migration Strategy:**
- Single migration to add category position column
- Single migration to rename product sort_order to position and add composite index
- Data backfill scripts in migrations ensure no nulls or gaps

### Model Layer

**Category Model:**
```ruby
class Category < ApplicationRecord
  acts_as_list

  has_many :products
  # ... existing code unchanged
end
```

**Product Model:**
```ruby
class Product < ApplicationRecord
  acts_as_list scope: :category_id

  # Update default scope to use position
  default_scope { where(active: true).order(:category_id, :position) }

  belongs_to :category
  # ... existing code unchanged
end
```

**Key Points:**
- Categories: Global position (1-N across all categories)
- Products: Scoped position (1-N within each category)
- acts_as_list automatically maintains sequential positions
- Moving items updates only affected positions

### Routes

```ruby
namespace :admin do
  resources :categories do
    collection do
      get :order
    end
    member do
      patch :move_higher
      patch :move_lower
    end
  end

  resources :products do
    collection do
      get :order
    end
    member do
      patch :move_higher
      patch :move_lower
    end
  end
end
```

**New Routes:**
- `GET /admin/categories/order` - Category ordering page
- `PATCH /admin/categories/:id/move_higher` - Move category up
- `PATCH /admin/categories/:id/move_lower` - Move category down
- `GET /admin/products/order` - Product ordering page (with category filter)
- `PATCH /admin/products/:id/move_higher` - Move product up within category
- `PATCH /admin/products/:id/move_lower` - Move product down within category

### Controller Implementation

**Admin::CategoriesController:**
```ruby
def order
  @categories = Category.order(:position)
end

def move_higher
  @category = Category.find_by!(slug: params[:id])
  @category.move_higher
  @categories = Category.order(:position)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to order_admin_categories_path }
  end
end

def move_lower
  @category = Category.find_by!(slug: params[:id])
  @category.move_lower
  @categories = Category.order(:position)

  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to order_admin_categories_path }
  end
end
```

**Admin::ProductsController:**
```ruby
def order
  @selected_category = if params[:category_id]
    Category.find(params[:category_id])
  else
    Category.order(:position).first
  end

  @products = @selected_category.products.unscoped
    .where(category_id: @selected_category.id)
    .order(:position)
  @categories = Category.order(:position)
end

def move_higher
  @product = Product.find_by!(slug: params[:id])
  @product.move_higher
  redirect_to order_admin_products_path(category_id: @product.category_id)
end

def move_lower
  @product = Product.find_by!(slug: params[:id])
  @product.move_lower
  redirect_to order_admin_products_path(category_id: @product.category_id)
end
```

**Key Points:**
- Simple controller actions - let acts_as_list handle position logic
- Turbo Stream responses for instant updates
- Category filter preserved in redirects for products
- Use unscoped queries where needed to bypass default scope

### View Layer

**Categories Ordering Page (`app/views/admin/categories/order.html.erb`):**
- Link back to categories index
- Table layout: Position | Name | Actions
- Up/down arrow buttons (disabled at boundaries)
- Turbo Frame wraps the table for live updates

**Products Ordering Page (`app/views/admin/products/order.html.erb`):**
- Category dropdown filter at top
- Turbo Frame around category selector
- Turbo Frame around product list
- Table layout: Position | Name | SKU | Actions
- Up/down arrow buttons (disabled at boundaries)

**Turbo Stream Template (`move_higher.turbo_stream.erb`, `move_lower.turbo_stream.erb`):**
- Replace entire list Turbo Frame with updated ordering
- Instant visual feedback without page reload

**Index Page Links:**
- Add "Reorder Categories" button to `/admin/categories`
- Add "Reorder Products" button to `/admin/products`

**Visual Design:**
- DaisyUI table components
- Small ghost buttons for arrows (btn-sm btn-ghost)
- Up arrow: ↑ (or chevron-up icon)
- Down arrow: ↓ (or chevron-down icon)
- Disabled state styling for boundary arrows

### Frontend Behavior

**Category Ordering:**
1. Admin visits `/admin/categories/order`
2. Sees all categories in position order
3. Clicks up/down arrow
4. Turbo Stream updates the list instantly
5. Positions automatically renumbered by acts_as_list

**Product Ordering:**
1. Admin visits `/admin/products/order`
2. Selects category from dropdown (defaults to first category)
3. Sees products from that category only
4. Clicks up/down arrow
5. Page reloads with updated ordering (Turbo Drive provides smooth transition)
6. Selected category preserved in URL

**Stimulus Controller (if needed for category filter):**
- Handle category dropdown change
- Navigate to order path with category_id param
- Turbo Drive handles the navigation smoothly

## Testing Strategy

**Model Tests:**
- Category position management (move_higher, move_lower)
- Product position scoped to category
- Position renumbering when items deleted
- Boundary conditions (can't move top item higher, bottom item lower)

**Integration Tests:**
- Categories ordering page renders correctly
- Products ordering page renders with category filter
- Move actions update positions correctly
- Turbo Stream responses work

**System Tests:**
- End-to-end category reordering flow
- End-to-end product reordering flow
- Category filter switching
- Boundary button states (disabled at top/bottom)

## Migration Path

**Phase 1: Database Setup**
1. Add acts_as_list gem to Gemfile
2. Migration: Add position to categories
3. Migration: Rename sort_order to position on products, add composite index
4. Update all references to sort_order in codebase

**Phase 2: Model Implementation**
1. Add acts_as_list to Category model
2. Add acts_as_list to Product model with scope
3. Update default scopes to use position

**Phase 3: Controller & Routes**
1. Add new routes for ordering pages and move actions
2. Implement controller actions
3. Update strong parameters if needed

**Phase 4: Views**
1. Create ordering page templates
2. Create Turbo Stream templates
3. Add links from index pages
4. Style with DaisyUI

**Phase 5: Testing**
1. Write model tests
2. Write integration tests
3. Write system tests
4. Manual QA testing

## Benefits

- **Intuitive:** Up/down arrows are universally understood
- **Simple:** Acts_as_list handles all complexity
- **Fast:** Turbo Streams provide instant feedback
- **Maintainable:** Convention-based approach, minimal custom code
- **Flexible:** Category-scoped products allow independent ordering
- **Reliable:** Battle-tested gem handles edge cases

## Future Enhancements

- Drag-and-drop ordering (keeps arrow buttons as fallback)
- Bulk reordering tools (set multiple positions at once)
- Position preview before saving
- Keyboard shortcuts (Ctrl+Up/Down to reorder)
