---
type: Plan
description: Plan to consolidate duplicate color/size product variants into single products with options by re-seeding the catalog from a CSV file.
status: shipped
timestamp: 2025-10-22
---

# Product Consolidation Using Product Options

> **For Claude:** This plan consolidates duplicate products (e.g., "Single Wall Cups White" + "Single Wall Cups Black") into single products with Color and Size options.

**Goal:** Transform catalog from color/size-based products to option-based products with generated variants, using the existing Product Options system.

**Data Source:** `/Users/laurentcurau/Desktop/catalog_products - catalog_products.csv.csv`

**Architecture:** Use existing ProductOption, ProductOptionValue, ProductOptionAssignment, and ProductVariantGeneratorService from product configuration system.

**Strategy:** Fresh start - Delete all existing products, re-seed from CSV with proper option structure.

---

## Phase 1: Analyze CSV and Create Seed Generator

### Task 1: Create CSV parser and product grouping logic

**Goal:** Parse CSV and group variants by product (ignoring color/size differences in product name)

**Files:**
- Create: `lib/tasks/seed_from_csv.rake`
- Create: `app/services/product_seed_generator.rb`

**Implementation:**

```ruby
# app/services/product_seed_generator.rb
class ProductSeedGenerator
  def initialize(csv_path)
    @csv_path = csv_path
    @products = {}
  end

  def parse
    CSV.foreach(@csv_path, headers: true) do |row|
      # Normalize product name (remove color suffix)
      base_name = normalize_product_name(row['product'])

      @products[base_name] ||= {
        name: base_name,
        category: row['category'],
        meta_title: row['meta_title'],
        meta_description: row['meta_description'],
        base_slug: row['slug (URL)'],
        material: row['material'],
        variants: []
      }

      @products[base_name][:variants] << {
        variant_type: row['variant'],
        size: extract_size(row['variant']),
        colour: row['colour'],
        sku: row['sku'],
        price: parse_price(row['price']),
        pac_size: row['pac_size'].to_i
      }
    end

    @products
  end

  private

  def normalize_product_name(name)
    # Remove color suffixes: " - White", " - Black", " - Kraft"
    name.gsub(/ - (White|Black|Kraft|Natural\/Beige|Clear)$/, '')
  end

  def extract_size(variant_text)
    # Extract size from variant column
    # Examples: "12oz/340ml" → "12oz", "Large" → "Large"
    return nil if variant_text == 'Standard'
    variant_text
  end

  def parse_price(price_str)
    return 0 if price_str.blank?
    price_str.gsub('£', '').gsub(',', '').to_f
  end
end
```

**Commit:**
```bash
git commit -m "Add CSV parser for product consolidation

Parses catalog CSV and groups variants by product.
Extracts size and color as options.
Normalizes product names (removes color suffix).

Foundation for product options-based seeding."
```

---

### Task 2: Create consolidated seed file generator

**Files:**
- Create: `db/seeds/products_from_csv.rb`

**Implementation:**

```ruby
# db/seeds/products_from_csv.rb
require 'csv'
require_relative '../../app/services/product_seed_generator'

puts 'Generating products from CSV...'

generator = ProductSeedGenerator.new(Rails.root.join('Desktop', 'catalog_products - catalog_products.csv.csv'))
products_data = generator.parse

# Get or create options
size_option = ProductOption.find_by(name: 'Size')
color_option = ProductOption.find_by(name: 'Color')

products_data.each do |base_name, data|
  # Skip if only one variant and it's "Standard" (no options needed)
  if data[:variants].length == 1 && data[:variants].first[:variant_type] == 'Standard'
    create_simple_product(data)
    next
  end

  # Create product with options
  product = create_product_with_options(data, size_option, color_option)

  # Generate all variants
  generate_variants_for_product(product, data[:variants])
end

def create_simple_product(data)
  variant = data[:variants].first

  product = Product.find_or_create_by!(slug: data[:base_slug]) do |p|
    p.name = data[:name]
    p.category = Category.find_by(slug: data[:category])
    p.meta_title = data[:meta_title]
    p.meta_description = data[:meta_description]
    p.material = data[:material]
    p.active = true
    p.product_type = 'standard'
  end

  product.variants.find_or_create_by!(sku: variant[:sku]) do |v|
    v.name = 'Standard'
    v.price = variant[:price]
    v.pac_size = variant[:pac_size]
    v.stock_quantity = 10000
    v.active = true
  end
end

def create_product_with_options(data, size_option, color_option)
  # Determine unique sizes and colors
  sizes = data[:variants].map { |v| v[:size] }.compact.uniq
  colors = data[:variants].map { |v| v[:colour] }.uniq

  # Create product
  product = Product.find_or_create_by!(slug: data[:base_slug]) do |p|
    p.name = data[:name]
    p.category = Category.find_by(slug: data[:category])
    p.meta_title = data[:meta_title]
    p.meta_description = data[:meta_description]
    p.material = data[:material]
    p.active = true
    p.product_type = 'standard'
  end

  # Assign options
  if sizes.length > 1 && size_option
    product.option_assignments.find_or_create_by!(product_option: size_option) do |a|
      a.position = 1
    end
  end

  if colors.length > 1 && color_option
    product.option_assignments.find_or_create_by!(product_option: color_option) do |a|
      a.position = 2
    end
  end

  product
end

def generate_variants_for_product(product, variants_data)
  variants_data.each do |variant_data|
    option_values = {}
    option_values['Size'] = variant_data[:size] if variant_data[:size]
    option_values['Color'] = variant_data[:colour]

    variant = product.variants.find_or_create_by!(sku: variant_data[:sku]) do |v|
      v.name = [variant_data[:size], variant_data[:colour]].compact.join(' ')
      v.price = variant_data[:price]
      v.pac_size = variant_data[:pac_size]
      v.stock_quantity = 10000
      v.option_values = option_values
      v.active = true
    end
  end
end

puts "✓ Consolidated products created"
puts "Products: #{Product.standard.count}"
puts "Variants: #{ProductVariant.count}"
```

**Commit:**
```bash
git commit -m "Add CSV-based consolidated product seeding

Reads catalog CSV and creates products with options:
- Groups variants by base product name
- Assigns Size and Color options where applicable
- Generates variants with option_values
- Simple products (one variant) created without options

Ready to replace existing seed structure."
```

---

## Phase 2: Database Reset and Re-seed

### Task 3: Backup and reset database

**Warning:** This deletes all existing product data!

```bash
# Backup current database (optional)
pg_dump shop_development > backup_$(date +%Y%m%d).sql

# Reset database
rails db:reset

# This will:
# 1. Drop database
# 2. Create database
# 3. Run all migrations
# 4. Run db/seeds.rb
```

### Task 4: Update seeds.rb to use CSV

**Files:**
- Modify: `db/seeds.rb`

Replace product YAML seeding with CSV seeding:

```ruby
# Remove old YAML-based product seeding
# Add CSV-based seeding

# Load categories first (keep existing)
# Load product options (keep existing)
# Load branded product pricing (keep existing)

# NEW: Load products from CSV
load Rails.root.join('db', 'seeds', 'products_from_csv.rb')
```

**Commit:**
```bash
git commit -m "Update seeds to use CSV for product data

Replaced YAML-based product seeds with CSV parser.
Products now properly structured with options.

Run: rails db:reset to apply new structure."
```

---

## Phase 3: Verification and Testing

### Task 5: Verify product structure

**Check:**
- Single product for "Single Wall Paper Hot Cup" (not separate White/Black)
- Product has Color option assigned
- Variants have option_values: `{Size: "8oz", Color: "White"}`
- Lids have proper Size option

**Test queries:**
```ruby
# Should return 1 product, not 2
Product.where("name LIKE ?", "%Single Wall%").count

# Should have variants for each color/size combo
product = Product.find_by(name: "Single Wall Paper Hot Cup")
product.variants.count # Should be 5 (4oz, 8oz, 12oz, 16oz, 20oz × White + Black variants)

# Should have options assigned
product.options.pluck(:name) # Should include "Size", "Color"
```

### Task 6: Update product display views

**Files:**
- Modify: `app/views/products/_standard_product.html.erb`

The view already handles option_values, but verify:
- Variant selector shows "8oz White", "8oz Black", etc.
- Cart displays show option combinations
- Product pages group by base product correctly

**Commit:**
```bash
git commit -m "Verify and adjust product displays for consolidated structure

All views working with new option-based structure.
Variant selectors show size × color combinations.

Product consolidation complete."
```

---

## Phase 4: Production Deployment

### Task 7: Deploy to production with reset

**Warning:** This will delete production product data!

```bash
# On production via Kamal
kamal app exec 'bin/rails db:reset'

# This runs:
# - db:drop
# - db:create
# - db:migrate
# - db:seed (with new CSV-based structure)
```

**Verification:**
- Check product count is correct
- Verify all categories exist
- Test configurator still works
- Verify lids matching works

---

## Summary

This plan transforms your catalog from:
- **Old**: 50+ products (many duplicates with color/size differences)
- **New**: ~25 products with proper option assignments

**Benefits:**
- Cleaner product catalog
- Easier to manage (one product vs many)
- Better UX (customers select options, not hunt for colored versions)
- Ready for future options (Material, Finish, etc.)
- Uses infrastructure we already built

**Estimated time:** 2-3 hours
**Risk:** Medium (deletes existing data, but you're pre-launch)
**Reward:** Proper product architecture from day one

---

## Next Session Tasks

1. Implement ProductSeedGenerator service
2. Create products_from_csv.rb seed
3. Test locally with db:reset
4. Verify all features still work
5. Deploy to production with reset

The Product Options system is ready - we just need to use it!
