# Data Model: Product Descriptions Enhancement

**Feature**: 004-product-descriptions
**Date**: 2025-11-15

## Overview

This feature adds three new text columns to the existing `products` table and removes the old `description` column. No new tables or relationships are introduced.

## Database Schema Changes

### Modified Table: `products`

**Columns Removed**:
- `description` (text) - Replaced by three new columns

**Columns Added**:
- `description_short` (text, nullable) - Brief 10-20 word summary
- `description_standard` (text, nullable) - Medium 30-40 word paragraph
- `description_detailed` (text, nullable) - Comprehensive 100-150 word content

**Migration Details**:
```ruby
# Migration: ReplaceProductDescriptionWithThreeFields
# Direction: up
# - Add three new text columns (description_short, description_standard, description_detailed)
# - Populate from lib/data/products.csv via SKU lookup
# - Remove old description column

# Direction: down
# - Add back description column
# - Copy description_standard to description (best fallback)
# - Remove three new columns
```

**Constraints**:
- All three new fields are nullable (allow blank for optional content)
- No length limits (PostgreSQL text type)
- No unique constraints
- No foreign keys

**Indexes**:
- No new indexes needed (description fields not used in WHERE clauses)

## Entities

### Product (Enhanced)

**Purpose**: Represents a product in the e-commerce catalog with multi-tier descriptions for different contexts

**New Attributes**:

| Attribute | Type | Nullable | Default | Description |
|-----------|------|----------|---------|-------------|
| description_short | text | Yes | NULL | Brief 10-20 word summary for product cards on browse pages |
| description_standard | text | Yes | NULL | Medium 30-40 word paragraph for product page intro above fold |
| description_detailed | text | Yes | NULL | Comprehensive 100-150 word content for product page main section |

**Removed Attributes**:

| Attribute | Type | Nullable | Migration Strategy |
|-----------|------|----------|-------------------|
| description | text | Yes | Data migrated to three new fields from CSV; down migration restores from description_standard |

**Existing Attributes** (unchanged):
- `id`, `name`, `sku`, `slug`, `category_id`, `active`, `featured`, `position`, `meta_title`, `meta_description`, etc.

**Relationships** (unchanged):
- `belongs_to :category`
- `has_many :variants` (ProductVariant)
- `has_many :active_variants`
- `has_one_attached :product_photo`
- `has_one_attached :lifestyle_photo`

**Business Rules**:

1. **Fallback Logic** (new):
   - If `description_short` is blank, truncate `description_standard` to ~15 words
   - If `description_standard` is blank, truncate `description_detailed` to ~35 words
   - If all three are blank, return nil or default message

2. **Character Count Guidelines** (soft recommendations, not enforced):
   - Short: 10-25 words (target ~20)
   - Standard: 25-50 words (target ~35)
   - Detailed: 75-175 words (target ~125)

3. **SEO Integration** (new):
   - Use `description_standard` for meta description when `meta_description` is blank
   - Fallback chain: custom `meta_description` → `description_standard` → generated default

**State Transitions**: N/A (no state machine)

**Validation Rules** (unchanged):
- `name` and `category` still required
- Descriptions are optional (no presence validation)
- XSS protection via Rails auto-escaping (no additional sanitization needed)

## Data Migration

### Source Data

**File**: `lib/data/products.csv`

**Relevant Columns**:
- `sku` - Unique identifier for product matching
- `description_short` - Short description text
- `description_standard` - Standard description text
- `description_detailed` - Detailed description text

**Migration Logic**:
1. Parse CSV file using Ruby CSV library
2. Build lookup hash: `{ sku => { short:, standard:, detailed: } }`
3. Iterate through products using `find_each` (batch processing)
4. Match by SKU and update using `update_columns` (skip callbacks)
5. Log warnings for products missing CSV data (if any)

**Data Volume**: ~50 products

**Migration Performance**: <5 seconds (small dataset, single table update)

**Rollback Strategy**: Down migration copies `description_standard` back to `description` column

## Model Methods

### New Helper Methods (Product model)

```ruby
# Returns short description with fallback to truncated standard/detailed
def description_short_with_fallback
  return description_short if description_short.present?
  return truncate_to_words(description_standard, 15) if description_standard.present?
  truncate_to_words(description_detailed, 15) if description_detailed.present?
end

# Returns standard description with fallback to truncated detailed
def description_standard_with_fallback
  return description_standard if description_standard.present?
  truncate_to_words(description_detailed, 35) if description_detailed.present?
end

# Returns detailed description (no fallback needed - longest form)
def description_detailed_with_fallback
  description_detailed
end

private

# Truncates text to N words, adds ellipsis if truncated
def truncate_to_words(text, word_count)
  return nil if text.blank?
  words = text.split
  return text if words.length <= word_count
  words.first(word_count).join(" ") + "..."
end
```

## View Integration Points

### Shop Page (`app/views/pages/shop.html.erb`)
- **Display**: `product.description_short_with_fallback`
- **Location**: Below product name on product card
- **Styling**: Text-sm, gray-600 (secondary text)

### Category Pages (`app/views/categories/show.html.erb`)
- **Display**: `product.description_short_with_fallback`
- **Location**: Below product name on product card
- **Styling**: Text-sm, gray-600 (secondary text)

### Product Detail Page (`app/views/products/show.html.erb`)
- **Display (intro)**: `product.description_standard_with_fallback`
- **Location**: Above fold, prominent intro paragraph
- **Styling**: Text-lg, gray-700, mb-6

- **Display (details)**: `product.description_detailed_with_fallback` via `simple_format` helper
- **Location**: Below fold in "Product Details" section
- **Styling**: Prose, prose-lg (Tailwind typography)

### Admin Form (`app/views/admin/products/_form.html.erb`)
- **Fields**: Three separate textareas
- **Labels**: "Short Description (10-25 words)", "Standard Description (25-50 words)", "Detailed Description (75-175 words)"
- **Stimulus Controller**: `character-counter` attached to each textarea
- **Visual Feedback**: Color-coded character count (green/yellow/red)

## SEO Helper Integration

### SEO Helper Update (`app/helpers/seo_helper.rb`)

**Current behavior**:
```ruby
def meta_description
  content_for(:meta_description) || "Default description"
end
```

**Updated behavior** (for product pages):
```ruby
def meta_description
  return content_for(:meta_description) if content_for(:meta_description).present?
  return @product.meta_description if @product&.meta_description.present?
  return @product.description_standard_with_fallback if @product&.description_standard_with_fallback.present?
  "Default description"
end
```

## Testing Coverage

### Model Tests (`test/models/product_test.rb`)
- Test `description_short_with_fallback` with all present
- Test `description_short_with_fallback` with short blank, standard present
- Test `description_short_with_fallback` with short/standard blank, detailed present
- Test `description_short_with_fallback` with all blank (returns nil)
- Test `description_standard_with_fallback` with standard present
- Test `description_standard_with_fallback` with standard blank, detailed present
- Test `truncate_to_words` private method logic

### Migration Tests (`test/db/migrate/replace_product_description_with_three_fields_test.rb`)
- Test up migration adds three columns
- Test up migration removes old description column
- Test up migration populates data from CSV
- Test down migration restores description column
- Test down migration removes three new columns

### System Tests
- `test/system/shop_descriptions_test.rb` - Verify short descriptions on shop page
- `test/system/category_descriptions_test.rb` - Verify short descriptions on category pages
- `test/system/product_descriptions_test.rb` - Verify standard + detailed on product pages
- `test/system/admin_product_descriptions_test.rb` - Verify admin form with character counters

### Helper Tests (`test/helpers/seo_helper_test.rb`)
- Test meta description uses `description_standard` when `meta_description` blank
- Test meta description uses custom `meta_description` when present
- Test meta description fallback chain

## Summary

This is a straightforward database enhancement adding three text columns to an existing table. No new entities, relationships, or complex data structures. Migration is reversible and data-driven from CSV. Model methods provide clean fallback logic for views. All changes maintain existing functionality while enhancing content display capabilities.
