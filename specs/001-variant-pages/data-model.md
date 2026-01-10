# Data Model: Variant-Level Product Pages

**Date**: 2026-01-10
**Feature**: 001-variant-pages

## Overview

This feature adds two columns to the existing `product_variants` table. No new tables are required. The existing `Product` and `ProductVariant` relationship is preserved.

---

## Entity Changes

### ProductVariant (Modified)

**New Columns:**

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| `slug` | string(255) | NOT NULL, UNIQUE, INDEX | URL-friendly identifier for variant pages |
| `search_vector` | tsvector | INDEX (GIN) | Full-text search index |

**Existing Columns (Relevant):**

| Column | Type | Notes |
|--------|------|-------|
| `id` | bigint | Primary key |
| `product_id` | bigint | FK to products |
| `sku` | string | Unique identifier |
| `name` | string | Variant display name (e.g., "single-wall 8oz white") |
| `price` | decimal | Price per pack |
| `pac_size` | integer | Units per pack |
| `active` | boolean | Whether variant is purchasable |

**New Validations:**

```ruby
validates :slug, presence: true, uniqueness: true
```

**New Callbacks:**

```ruby
before_validation :generate_slug, on: :create

def generate_slug
  return if slug.present?
  base = "#{name} #{product.name}".parameterize
  self.slug = ensure_unique_slug(base)
end

private

def ensure_unique_slug(base)
  slug = base
  counter = 2
  while ProductVariant.exists?(slug: slug)
    slug = "#{base}-#{counter}"
    counter += 1
  end
  slug
end
```

---

## Migrations

### Migration 1: Add slug column

```ruby
class AddSlugToProductVariants < ActiveRecord::Migration[8.1]
  def change
    add_column :product_variants, :slug, :string, null: false, default: ""
    add_index :product_variants, :slug, unique: true
  end
end
```

### Migration 2: Add search vector with trigger

```ruby
class AddSearchVectorToProductVariants < ActiveRecord::Migration[8.1]
  def up
    add_column :product_variants, :search_vector, :tsvector
    add_index :product_variants, :search_vector, using: :gin

    execute <<-SQL
      CREATE OR REPLACE FUNCTION product_variants_search_trigger() RETURNS trigger AS $$
      BEGIN
        NEW.search_vector :=
          setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(NEW.sku, '')), 'B');
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER product_variants_search_update
      BEFORE INSERT OR UPDATE ON product_variants
      FOR EACH ROW EXECUTE FUNCTION product_variants_search_trigger();
    SQL

    # Backfill existing records
    ProductVariant.find_each(&:touch)
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS product_variants_search_update ON product_variants;
      DROP FUNCTION IF EXISTS product_variants_search_trigger();
    SQL

    remove_column :product_variants, :search_vector
  end
end
```

### Migration 3: Populate existing slugs

```ruby
class PopulateProductVariantSlugs < ActiveRecord::Migration[8.1]
  def up
    ProductVariant.includes(:product).find_each do |variant|
      base = "#{variant.name} #{variant.product.name}".parameterize
      slug = base
      counter = 2
      while ProductVariant.where.not(id: variant.id).exists?(slug: slug)
        slug = "#{base}-#{counter}"
        counter += 1
      end
      variant.update_column(:slug, slug)
    end

    # Now enforce NOT NULL after populating
    change_column_null :product_variants, :slug, false
  end

  def down
    change_column_null :product_variants, :slug, true
  end
end
```

---

## New Scopes

### ProductVariant Scopes

```ruby
# Full-text search
scope :search, ->(query) {
  return all if query.blank?

  sanitized = sanitize_sql_like(query.to_s.truncate(100, omission: ""))
  where("search_vector @@ plainto_tsquery('english', ?)", sanitized)
    .order(Arel.sql("ts_rank(search_vector, plainto_tsquery('english', #{connection.quote(sanitized)})) DESC"))
}

# Extended search including product and category names
scope :search_extended, ->(query) {
  return all if query.blank?

  sanitized = sanitize_sql_like(query.to_s.truncate(100, omission: ""))
  joins(product: :category)
    .where(
      "product_variants.search_vector @@ plainto_tsquery('english', :q) OR " \
      "products.name ILIKE :like OR " \
      "categories.name ILIKE :like",
      q: sanitized, like: "%#{sanitized}%"
    )
}

# Filter by option values
scope :with_option, ->(option_name, value) {
  return all if value.blank?

  joins(option_values: :product_option)
    .where(product_options: { name: option_name })
    .where(product_option_values: { value: value })
}

scope :with_size, ->(value) { with_option('size', value) }
scope :with_colour, ->(value) { with_option('colour', value) }
scope :with_material, ->(value) { with_option('material', value) }

# Filter by category (via product)
scope :in_category, ->(category_slug) {
  return all if category_slug.blank?

  joins(product: :category)
    .where(categories: { slug: category_slug })
}
```

---

## Model Methods

### ProductVariant New Methods

```ruby
# Display name for UI (includes product context)
def display_name
  "#{name.titleize} #{product.name}"
end

# For URL generation
def to_param
  slug
end

# SEO meta description
def meta_description
  "#{display_name}. #{product.description_short_with_fallback}".truncate(160)
end

# Sibling variants for "See Also" section
def sibling_variants(limit: 8)
  product.active_variants.where.not(id: id).limit(limit)
end
```

---

## Relationships (Existing, Unchanged)

```
Product 1 ──────< ProductVariant
    │                   │
    │                   │
    └── Category        └── VariantOptionValue >─── ProductOptionValue
```

- **Product** has_many **ProductVariant** (existing)
- **ProductVariant** has_many **VariantOptionValue** (existing)
- **VariantOptionValue** belongs_to **ProductOptionValue** (existing)
- **Product** belongs_to **Category** (existing)

---

## Fixture Updates

Update `test/fixtures/product_variants.yml` to include slugs:

```yaml
widget_small:
  product: widget
  sku: WIDGET-S
  name: small
  price: 10.00
  pac_size: 100
  slug: small-widget

widget_large:
  product: widget
  sku: WIDGET-L
  name: large
  price: 15.00
  pac_size: 50
  slug: large-widget
```

---

## Index Summary

| Table | Column | Index Type | Purpose |
|-------|--------|------------|---------|
| product_variants | slug | UNIQUE B-tree | URL lookups, uniqueness |
| product_variants | search_vector | GIN | Full-text search |
