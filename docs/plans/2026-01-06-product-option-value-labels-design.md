# Product Option Value Labels Design

## Problem

The current `option_values` JSONB column on `product_variants` stores raw values like `{"size": "7in", "colour": "cutlery-kit"}`. The UI is tightly coupled to these values, making it difficult to display human-readable labels like "7 inches (30cm)" or "Cutlery Kit".

The `ProductOptionValue` table already has both `value` and `label` columns, but they're not being used properly because variants store values directly in JSONB rather than referencing the table.

## Solution

Replace the JSONB column with a join table that links variants to `ProductOptionValue` records. This provides:

- Clean separation of stored values and display labels
- Referential integrity (can't assign non-existent option values)
- Database-enforced constraint of one value per option per variant
- Simpler querying ("find all 8oz variants" via SQL joins)

## Schema Changes

### New table: `variant_option_values`

```ruby
create_table :variant_option_values do |t|
  t.references :product_variant, null: false, foreign_key: true
  t.references :product_option_value, null: false, foreign_key: true
  t.references :product_option, null: false, foreign_key: true  # denormalized for constraint
  t.timestamps
end

# Prevent duplicate assignments
add_index :variant_option_values,
          [:product_variant_id, :product_option_value_id],
          unique: true,
          name: 'idx_variant_option_values_unique'

# One value per option per variant
add_index :variant_option_values,
          [:product_variant_id, :product_option_id],
          unique: true,
          name: 'idx_variant_one_value_per_option'
```

### Remove column

```ruby
remove_column :product_variants, :option_values, :jsonb
```

### Tables unchanged

- `product_options` - defines option types (size, colour, material)
- `product_option_values` - defines valid values with labels
- `product_option_assignments` - links products to their applicable options

## Model Changes

### New: `VariantOptionValue`

```ruby
class VariantOptionValue < ApplicationRecord
  belongs_to :product_variant
  belongs_to :product_option_value
  belongs_to :product_option

  before_validation :set_product_option_from_value

  validates :product_option_id, uniqueness: {
    scope: :product_variant_id,
    message: "already has a value for this option"
  }

  private

  def set_product_option_from_value
    self.product_option_id = product_option_value&.product_option_id
  end
end
```

### Updated: `ProductVariant`

```ruby
class ProductVariant < ApplicationRecord
  has_many :variant_option_values, dependent: :destroy
  has_many :option_values, through: :variant_option_values,
           source: :product_option_value

  # Returns hash like the old JSONB: { "size" => "8oz", "colour" => "White" }
  def option_values_hash
    variant_option_values.includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        hash[vov.product_option.name] = vov.product_option_value.value
      end
  end

  # Returns hash with labels: { "size" => "8 oz", "colour" => "White" }
  def option_labels_hash
    variant_option_values.includes(product_option_value: :product_option)
      .each_with_object({}) do |vov, hash|
        pov = vov.product_option_value
        hash[vov.product_option.name] = pov.label.presence || pov.value
      end
  end

  # Summary for display: "8 oz, White"
  def options_summary
    option_labels_hash.values.join(", ")
  end
end
```

### Updated: `Product`

```ruby
class Product < ApplicationRecord
  # Returns options with their possible values for this product
  # Only includes options with multiple values across variants
  def available_options
    options_data = Hash.new { |h, k| h[k] = Set.new }

    active_variants.includes(option_values: :product_option).each do |variant|
      variant.option_values.each do |ov|
        options_data[ov.product_option.name] << ov.value
      end
    end

    options_data
      .select { |_, values| values.size > 1 }
      .sort_by { |key, _| PRODUCT_OPTION_PRIORITY.index(key) || 999 }
      .to_h
      .transform_values(&:to_a)
  end

  # Returns variant data for JS selector (unchanged structure)
  def variants_for_selector(variants = nil)
    (variants || active_variants).includes(:option_values).map do |v|
      {
        id: v.id,
        sku: v.sku,
        price: v.price.to_f,
        pac_size: v.pac_size,
        option_values: v.option_values_hash,
        pricing_tiers: v.pricing_tiers,
        image_url: nil
      }
    end
  end
end
```

## Seed File Changes

Update `db/seeds/products_from_csv.rb` to use the join table:

```ruby
# Helper method
def assign_option(variant, option_name, value)
  return if value.blank?

  option_value = ProductOptionValue.joins(:product_option)
    .find_by!(product_options: { name: option_name }, value: value)

  variant.option_values << option_value
end

# Usage (after variant.save!)
assign_option(variant, 'size', variant_data[:size])
assign_option(variant, 'colour', variant_data[:colour])
assign_option(variant, 'material', variant_data[:material])
assign_option(variant, 'type', variant_data[:type])
```

Benefit: Typos like `'8ox'` instead of `'8oz'` fail loudly with `RecordNotFound`.

## View Changes

Replace direct JSONB access with model methods:

```erb
<!-- Before -->
<%= variant.option_values["size"] %>

<!-- After (raw value) -->
<%= variant.option_values_hash["size"] %>

<!-- After (display label) -->
<%= variant.option_labels_hash["size"] %>

<!-- Summary -->
<%= variant.options_summary %>
```

## Files to Delete/Update

### Delete
- `ProductsHelper#option_value_label` - no longer needed

### Update
- `Product#extract_options_from_variants` - replace with `available_options`
- `db/seeds/products_from_csv.rb` - use join table approach
- Views displaying option values - use `option_labels_hash`

## What Stays the Same

- **Variant selector JS** - receives identical data structure via `variants_for_selector`
- **Sparse matrix filtering** - works exactly as before
- **ProductOption tables** - unchanged schema
- **ProductOptionAssignment** - still tracks which options a product uses

## Migration Strategy

Since the site is pre-launch:

1. Create new migration for `variant_option_values` table
2. Create migration to remove `option_values` JSONB column
3. Create `VariantOptionValue` model
4. Update `ProductVariant` model with new associations and methods
5. Update `Product` model methods
6. Update seed files
7. `rails db:reset` to drop and re-seed
8. Update views to use new methods
9. Delete obsolete helper methods

No data migration scripts needed - fresh seed handles everything.
